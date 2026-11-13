"""Build rigged, clothed humans from the CC0 MakeHuman data files and export glTF.

Own implementation of the MakeHuman pipeline (targets, mhclo fitting, rig, weights);
bpy is only used to assemble the scene and write glTF.
"""
import gzip
import json
import os
import sys
import random
import numpy as np
from PIL import Image
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "mpfb_x", "data")
ASSETS = os.path.join(HERE, "assets")
S = 0.1  # decimetres -> metres


def to_bl(p):
    return Vector((p[0] * S, -p[2] * S, p[1] * S))


# ---------------------------------------------------------------- base mesh
class Obj:
    def __init__(self, path):
        self.v, self.vt, self.faces, self.groups = [], [], [], []
        g = ""
        with open(path) as f:
            for line in f:
                if line.startswith("v "):
                    self.v.append([float(x) for x in line.split()[1:4]])
                elif line.startswith("vt "):
                    self.vt.append([float(x) for x in line.split()[1:3]])
                elif line.startswith("g "):
                    g = line.split()[1]
                elif line.startswith("f "):
                    vs, ts = [], []
                    for c in line.split()[1:]:
                        p = c.split("/")
                        vs.append(int(p[0]) - 1)
                        ts.append(int(p[1]) - 1 if len(p) > 1 and p[1] else 0)
                    self.faces.append((vs, ts))
                    self.groups.append(g)
        self.v = np.array(self.v, dtype=np.float64)


_base = None
_targets = {}


def base():
    global _base
    if _base is None:
        _base = Obj(os.path.join(DATA, "3dobjs", "base.obj"))
    return _base


def target(rel):
    if rel not in _targets:
        idx, d = [], []
        with gzip.open(os.path.join(DATA, "targets", rel + ".target.gz"), "rt") as f:
            for line in f:
                p = line.split()
                if len(p) == 4 and not line.startswith("#"):
                    idx.append(int(p[0]))
                    d.append([float(p[1]), float(p[2]), float(p[3])])
        _targets[rel] = (np.array(idx, dtype=np.int64), np.array(d, dtype=np.float64).reshape(-1, 3))
    return _targets[rel]


def morph(spec):
    """spec: {target_rel_path: weight} -> morphed base vertex array"""
    v = base().v.copy()
    for rel, w in spec.items():
        idx, d = target(rel)
        v[idx] += d * w
    return v


def macro(gender="male", age=0.0, race=None, muscle=0.0, weight=0.0):
    """age 0 (young) .. 1 (old); muscle/weight in -1..1. race: dict like {"caucasian": 1.0}"""
    out = {}
    for an, aw in (("young", 1.0 - age), ("old", age)):
        if aw > 0.0:
            for k, w in _macro1(gender, an, race, muscle, weight).items():
                out[k] = out.get(k, 0.0) + w * aw
    return out


def _macro1(gender, age, race, muscle, weight):
    race = race or {"caucasian": 1.0}
    out = {}
    mw = {"min": max(0.0, -muscle), "average": 1.0 - abs(muscle), "max": max(0.0, muscle)}
    ww = {"min": max(0.0, -weight), "average": 1.0 - abs(weight), "max": max(0.0, weight)}
    for mk, mv in mw.items():
        for wk, wv in ww.items():
            if mv * wv > 0.0:
                out["macrodetails/universal-%s-%s-%smuscle-%sweight" % (gender, age, mk, wk)] = mv * wv
    for r, w in race.items():
        out["macrodetails/%s-%s-%s" % (r, gender, age)] = w
    return out


# ---------------------------------------------------------------- rig
def joint_positions(v):
    b = base()
    cubes = {}
    for (vs, _), g in zip(b.faces, b.groups):
        if g.startswith("joint-"):
            cubes.setdefault(g, set()).update(vs)
    return {g: v[sorted(ix)].mean(axis=0) for g, ix in cubes.items()}


def bone_point(spec, v, joints):
    st = spec.get("strategy")
    if st == "CUBE" and spec.get("cube_name") in joints:
        return to_bl(joints[spec["cube_name"]])
    if st == "VERTEX":
        return to_bl(v[spec["vertex_index"]])
    if st == "MEAN":
        return to_bl(v[spec["vertex_indices"]].mean(axis=0))
    return Vector(spec["default_position"])


def build_armature(name, v, rig="game_engine"):
    bones = json.load(open(os.path.join(DATA, "rigs", "standard", "rig.%s.json" % rig)))
    joints = joint_positions(v)
    arm = bpy.data.armatures.new(name + "_rig")
    ob = bpy.data.objects.new("Armature", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    done = {}
    pending = dict(bones)
    while pending:
        for bn in list(pending):
            bd = pending[bn]
            par = bd.get("parent") or ""
            if par and par not in done:
                continue
            eb = arm.edit_bones.new(bn)
            eb.head = bone_point(bd["head"], v, joints)
            eb.tail = bone_point(bd["tail"], v, joints)
            if (eb.tail - eb.head).length < 1e-4:
                eb.tail = eb.head + Vector((0, 0, 0.02))
            eb.roll = bd.get("roll", 0.0)
            if par:
                eb.parent = done[par]
            done[bn] = eb
            del pending[bn]
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def base_weights(rig="game_engine"):
    w = json.load(open(os.path.join(DATA, "rigs", "standard", "weights.%s.json" % rig)))["weights"]
    per = {}
    for bone, lst in w.items():
        for vi, wt in lst:
            per.setdefault(vi, {})[bone] = wt
    return per


# ---------------------------------------------------------------- clothes
def read_mhclo(path):
    info = {"dir": os.path.dirname(path), "verts": [], "delete": set()}
    mode = ""
    with open(path) as f:
        for line in f:
            p = line.split()
            if not p or p[0].startswith("#"):
                continue
            if p[0] == "verts":
                mode = "verts"
                continue
            if p[0] == "delete_verts":
                mode = "delete"
                continue
            if mode == "verts" and (p[0].lstrip("-").replace(".", "").isdigit()):
                info["verts"].append([float(x) for x in p])
                continue
            if mode == "delete" and (p[0].isdigit()):
                i = 0
                while i < len(p):
                    if i + 2 < len(p) and p[i + 1] == "-":
                        info["delete"].update(range(int(p[i]), int(p[i + 2]) + 1))
                        i += 3
                    else:
                        info["delete"].add(int(p[i]))
                        i += 1
                continue
            if mode == "delete":
                mode = ""
            info[p[0]] = p[1:]
    return info


def fit_mhclo(info, v, weights):
    def scale(key, axis):
        if key not in info:
            return 1.0
        a, b, den = int(info[key][0]), int(info[key][1]), float(info[key][2])
        return abs(v[a][axis] - v[b][axis]) / den
    sc = np.array([scale("x_scale", 0), scale("y_scale", 1), scale("z_scale", 2)])
    pos, wts = [], []
    for row in info["verts"]:
        if len(row) == 1:
            i = int(row[0])
            pos.append(v[i])
            wts.append(dict(weights.get(i, {})))
        else:
            i = [int(row[0]), int(row[1]), int(row[2])]
            bw = row[3:6]
            pos.append(v[i[0]] * bw[0] + v[i[1]] * bw[1] + v[i[2]] * bw[2] + np.array(row[6:9]) * sc)
            acc = {}
            for vi, w in zip(i, bw):
                for bone, x in weights.get(vi, {}).items():
                    acc[bone] = acc.get(bone, 0.0) + x * w
            wts.append(acc)
    return np.array(pos), wts


def read_mhmat(path):
    d = {"dir": os.path.dirname(path)}
    with open(path) as f:
        for line in f:
            p = line.split()
            if len(p) >= 2 and not p[0].startswith("#"):
                d.setdefault(p[0], p[1:])
    return d


# ---------------------------------------------------------------- textures
def texture(src, out_dir, name, size=1024, tint=None, alpha=False, gain=1.0, bg=None, sat_only=False, desat=0.0):
    """Copy/resize/tint a texture into out_dir, return its path.
    tint: (r,g,b) 0..1 -> desaturate and recolor keeping shading detail."""
    ext = ".png" if alpha else ".jpg"
    dst = os.path.join(out_dir, name + ext)
    if os.path.exists(dst):
        return dst
    im = Image.open(src).convert("RGBA")
    if max(im.size) > size:
        im = im.resize((size, size), Image.LANCZOS)
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb = a[..., :3]
    if bg is not None:
        rgb = rgb * a[..., 3:4] + np.array(bg, dtype=np.float32) * (1.0 - a[..., 3:4])
    lum = (rgb * np.array([0.299, 0.587, 0.114])).sum(axis=-1, keepdims=True)
    if desat > 0.0:
        rgb = rgb * (1.0 - desat) + lum * desat
    if tint is not None:
        mask = a[..., 3:4] > 0.5 if alpha else np.ones_like(lum, dtype=bool)
        if sat_only:
            sat = rgb.max(axis=-1, keepdims=True) - rgb.min(axis=-1, keepdims=True)
            k = np.clip((sat - 0.10) / 0.12, 0, 1)
            sel = mask & (k > 0.5)
            mean = float(lum[sel].mean()) if sel.any() else 0.5
            new = np.clip(lum / max(mean, 1e-3) * np.array(tint, dtype=np.float32), 0, 1)
            rgb = rgb * (1.0 - k) + new * k
        else:
            mean = float(lum[mask].mean()) if mask.any() else 0.5
            rgb = np.clip(lum / max(mean, 1e-3) * np.array(tint, dtype=np.float32), 0, 1)
    rgb = np.clip(rgb * gain, 0, 1)
    out = np.concatenate([rgb, a[..., 3:4]], axis=-1)
    im2 = Image.fromarray((out * 255).astype(np.uint8), "RGBA")
    if alpha:
        im2.save(dst)
    else:
        im2.convert("RGB").save(dst, quality=90)
    return dst


def make_material(name, diffuse=None, normal=None, color=(0.8, 0.8, 0.8), alpha=False, rough=0.7, spec=0.3):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = 0.0
    if diffuse:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(diffuse, check_existing=True)
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            m.blend_method = "HASHED"
            m.surface_render_method = "DITHERED"
    if normal:
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(normal, check_existing=True)
        tex.image.colorspace_settings.name = "Non-Color"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    m.use_backface_culling = not alpha
    return m


# ---------------------------------------------------------------- mesh assembly
def make_mesh(name, verts, faces, uvs, wts, arm, mat):
    """verts: Nx3 (MH coords), faces: [(vidx list, uvidx list)], uvs: list, wts: per-vertex {bone: w}"""
    used = sorted({i for f in faces for i in f[0]})
    remap = {old: new for new, old in enumerate(used)}
    me = bpy.data.meshes.new(name)
    me.from_pydata([to_bl(verts[i]) for i in used], [], [[remap[i] for i in f[0]] for f in faces])
    uvl = me.uv_layers.new(name="UVMap")
    k = 0
    for f in faces:
        for t in f[1]:
            uvl.data[k].uv = uvs[t] if t < len(uvs) else (0.0, 0.0)
            k += 1
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    groups = {}
    for old in used:
        w = wts[old] if isinstance(wts, list) else wts.get(old, {})
        top = sorted(w.items(), key=lambda x: -x[1])[:4]
        tot = sum(x[1] for x in top)
        if tot <= 0:
            top, tot = [("head", 1.0)], 1.0
        for bone, x in top:
            if bone not in groups:
                groups[bone] = ob.vertex_groups.new(name=bone)
            groups[bone].add([remap[old]], x / tot, "REPLACE")
    ob.parent = arm
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return ob


def face_variation(seed, strength=0.5):
    """Random but deterministic face-shape targets so every character has their own face."""
    rnd = random.Random(seed)
    out = {}
    for d, n in (("nose", 4), ("chin", 2), ("cheek", 2), ("head", 3), ("mouth", 3), ("forehead", 1), ("eyes", 3)):
        names = sorted(f[:-10] for f in os.listdir(os.path.join(DATA, "targets", d)) if f.endswith(".target.gz") and not f.startswith("r-"))
        for nm in rnd.sample(names, n):
            w = rnd.uniform(0.25, 1.0) * strength
            out["%s/%s" % (d, nm)] = w
            if nm.startswith("l-") and os.path.exists(os.path.join(DATA, "targets", d, "r-" + nm[2:] + ".target.gz")):
                out["%s/r-%s" % (d, nm[2:])] = w
    return out


def vertex_normals(pos, faces):
    n = np.zeros_like(pos)
    for vs, _ in faces:
        p = pos[vs]
        fn = np.cross(p[1] - p[0], p[2] - p[0])
        n[vs] += fn
    ln = np.linalg.norm(n, axis=1, keepdims=True)
    return n / np.maximum(ln, 1e-9)


def plain_material(name, color, rough=0.5, metal=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.use_backface_culling = False
    return m


def shell(name, pos, faces, uvs, wts, sel, offset, mat, arm, skip_face=None):
    """Gear that hugs the body: selected vertices pushed out along their normals."""
    nrm = vertex_normals(pos, faces)
    p2 = pos + nrm * offset
    keep = [f for f in faces if all(sel[i] for i in f[0]) and not (skip_face and skip_face(pos[f[0]].mean(axis=0)))]
    if not keep:
        return None
    return make_mesh(name, p2, keep, uvs, wts, arm, mat)


def wsum(wts, i, bones):
    w = wts[i] if isinstance(wts, list) else wts.get(i, {})
    tot = sum(w.values()) or 1.0
    return sum(w.get(b, 0.0) for b in bones) / tot


def build(name, out_dir, cfg):
    """cfg keys: morph, skin, skin_gain, eyes, eyebrows, hair {id,tint},
    clothes [ {id, tint, sat_only, gain, variant, vest: color} ], mask {color, accent}, helmet color"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tex_dir = os.path.join(out_dir, "tex")
    os.makedirs(tex_dir, exist_ok=True)
    b = base()
    v = morph(cfg["morph"])
    body_faces_all = [f for f, g in zip(b.faces, b.groups) if not g.startswith(("helper-", "joint-"))]
    body_idx = sorted({i for f in body_faces_all for i in f[0]})
    v[:, 1] -= v[body_idx, 1].min()
    arm = build_armature(name, v)
    weights = base_weights()
    joints = joint_positions(v)
    eye = (joints["joint-l-eye"] + joints["joint-r-eye"]) / 2.0
    parts = []
    delete = set()
    items = list(cfg.get("clothes", []))
    items.append({"path": "eyes/low-poly/low-poly", "kind": "eyes"})
    if cfg.get("eyebrows"):
        items.append({"path": "eyebrows/%s/%s" % (cfg["eyebrows"], cfg["eyebrows"]), "kind": "brows"})
    items.append({"path": "eyelashes/eyelashes01/eyelashes01", "kind": "brows"})
    if cfg.get("hair") and not cfg.get("helmet"):
        h = cfg["hair"]
        items.append({"path": "hair/%s/%s" % (h["id"], h["id"]), "kind": "hair", "tint": h.get("tint"), "variant": h.get("variant")})
    for it in items:
        path = it.get("path") or "clothes/%s/%s" % (it["id"], it["id"])
        info = read_mhclo(os.path.join(ASSETS, path + ".mhclo"))
        pos, wts = fit_mhclo(info, v, weights)
        ob = Obj(os.path.join(info["dir"], info["obj_file"][0]))
        kind = it.get("kind", "clothes")
        if kind not in ("eyes", "brows", "hair"):
            delete |= info["delete"]
        alpha = kind in ("brows", "hair")
        tname = os.path.basename(path)
        suffix = ("_" + it["variant"]) if it.get("variant") else ""
        if kind == "eyes":
            ec = cfg.get("eyes", "brown")
            src = os.path.join(ASSETS, "eyes", "materials", "%s_eye.png" % ec)
            diff = texture(src, tex_dir, "eye_" + ec, 256, alpha=False, bg=(0.93, 0.92, 0.9), desat=0.45, gain=0.9)
            mat = make_material("eye_" + ec, diff, rough=0.15)
        else:
            mm = read_mhmat(os.path.join(info["dir"], info["material"][0]))
            diff = norm = None
            if "diffuseTexture" in mm:
                diff = texture(os.path.join(mm["dir"], mm["diffuseTexture"][0]), tex_dir, tname + suffix,
                               512 if alpha else 1024, tint=it.get("tint"), alpha=alpha, gain=it.get("gain", 1.0),
                               sat_only=it.get("sat_only", False))
            if "normalmapTexture" in mm and not alpha:
                norm = texture(os.path.join(mm["dir"], mm["normalmapTexture"][0]), tex_dir, tname + "_n", 1024)
            mat = make_material(tname + suffix, diff, norm, alpha=alpha, rough=0.85 if kind != "hair" else 0.55)
        parts.append(make_mesh(tname, pos, ob.faces, ob.vt, wts, arm, mat))
        if it.get("vest"):
            torso = ("spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r")
            y0 = joints["joint-l-upper-leg"][1] + 1.0
            y1 = joints["joint-l-shoulder"][1] + 0.3
            arms = ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "neck_01", "head")
            sel = [y0 < pos[i][1] < y1 and wsum(wts, i, arms) < 0.22 for i in range(len(pos))]
            o = shell("vest", pos, ob.faces, ob.vt, wts, sel, 0.16, plain_material("vest_%02x%02x%02x" % tuple(int(c * 255) for c in it["vest"]), it["vest"], 0.9), arm)
            if o:
                parts.append(o)
    # body
    skin = cfg["skin"]
    mm = None
    for fn in os.listdir(os.path.join(ASSETS, "skins", skin)):
        if fn.endswith(".mhmat"):
            mm = read_mhmat(os.path.join(ASSETS, "skins", skin, fn))
    sv = cfg.get("skin_variant", "")
    diff = texture(os.path.join(mm["dir"], mm["diffuseTexture"][0]), tex_dir, "skin_" + skin + sv, 1024, gain=cfg.get("skin_gain", 1.0))
    mat = make_material("skin_" + skin + sv, diff, rough=0.55)
    faces = [f for f in body_faces_all if not any(i in delete for i in f[0])]
    parts.append(make_mesh("body", v, faces, b.vt, weights, arm, mat))
    headw = [wsum(weights, i, ("head",)) > 0.5 for i in range(len(v))]
    if cfg.get("mask"):
        mk = cfg["mask"]
        sel = [headw[i] and eye[1] - 1.26 < v[i][1] < eye[1] + 0.78 and v[i][2] > eye[2] - 0.6 and abs(v[i][0] - eye[0]) < 0.74 for i in range(len(v))]

        def hole(c):
            return any(((c[0] - joints[j][0]) / 0.19) ** 2 + ((c[1] - joints[j][1]) / 0.105) ** 2 < 1.0 for j in ("joint-l-eye", "joint-r-eye")) and c[2] > eye[2]
        o = shell("mask", v, body_faces_all, b.vt, weights, sel, 0.07, plain_material("mask_base_%02x%02x%02x" % tuple(int(c * 255) for c in mk["color"]), mk["color"], mk.get("rough", 0.25)), arm, hole)
        parts.append(o)
        if mk.get("accent"):
            sel2 = [sel[i] and abs(v[i][1] - eye[1] - 0.02) < 0.21 for i in range(len(v))]
            o = shell("mask_band", v, body_faces_all, b.vt, weights, sel2, 0.082, plain_material("mask_band", mk["accent"], 0.4), arm, hole)
            if o:
                parts.append(o)
            sel3 = [sel[i] and abs(abs(v[i][0] - eye[0]) - 0.33) < 0.075 and v[i][1] < eye[1] - 0.1 for i in range(len(v))]
            o = shell("mask_lines", v, body_faces_all, b.vt, weights, sel3, 0.084, plain_material("mask_gold", mk.get("accent2", (0.83, 0.62, 0.2)), 0.3, 0.8), arm, hole)
            if o:
                parts.append(o)
    if cfg.get("helmet"):
        sel = [headw[i] and (v[i][1] > eye[1] + 0.34 or (v[i][2] < eye[2] - 0.8 and v[i][1] > eye[1] - 0.3)) and
               not (v[i][2] > eye[2] - 0.35 and v[i][1] < eye[1] + 0.42) for i in range(len(v))]
        o = shell("helmet", v, body_faces_all, b.vt, weights, sel, 0.24, plain_material("helmet_%02x%02x%02x" % tuple(int(c * 255) for c in cfg["helmet"]), cfg["helmet"], 0.45), arm)
        if o:
            parts.append(o)
    height = (v[body_idx, 1].max()) * S
    # lighter meshes for phones
    for o in parts:
        ratio = {"body": 0.5, "low-poly": 1.0, "eyelashes01": 1.0, "mask": 1.0, "mask_band": 1.0, "mask_lines": 1.0, "helmet": 1.0}.get(o.name, 0.45)
        if o.name.startswith("eyebrow") or ratio >= 1.0 or len(o.data.polygons) < 600:
            continue
        mod = o.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        o.modifiers.move(len(o.modifiers) - 1, 0)
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
            bpy.ops.object.modifier_apply(modifier="Decimate")
    out = os.path.join(out_dir, name + ".gltf")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLTF_SEPARATE", export_keep_originals=True,
                              export_apply=False, export_yup=True, export_skins=True, export_animations=False,
                              export_materials="EXPORT", export_tangents=False, export_normals=True,
                              export_texcoords=True, use_selection=False)
    tris = sum(len(p.vertices) - 2 for o in parts for p in o.data.polygons)
    print("BUILT %s height=%.2fm eye=%.2fm tris=%d parts=%d" % (name, height, eye[1] * S, tris, len(parts)))
    return {"height": height, "eye": eye[1] * S}
