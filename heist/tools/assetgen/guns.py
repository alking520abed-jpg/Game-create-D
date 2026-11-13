"""Convert CC0 Quaternius gun OBJs to game-ready GLB: barrel along -Z, +Y up, origin at the grip, metres."""
import bpy, sys, os, math, json
from mathutils import Vector, Matrix
src, out = sys.argv[sys.argv.index('--') + 1:][:2]
JOBS = {"pistol": ("Pistol_1", 0.215), "smg": ("SubmachineGun_3", 0.56), "shotgun": ("Shotgun_1", 0.98), "rifle": ("AssaultRifle2_1", 0.88)}
LOOK = {"Black": ((0.05, 0.05, 0.055), 0.2, 0.55), "Black2": ((0.035, 0.035, 0.04), 0.2, 0.6), "DarkMetal": ((0.10, 0.10, 0.11), 0.85, 0.38),
        "Metal": ((0.16, 0.16, 0.17), 0.9, 0.32), "LightMetal": ((0.32, 0.32, 0.34), 0.9, 0.28), "Grey": ((0.09, 0.09, 0.10), 0.5, 0.5),
        "DarkWood": ((0.16, 0.09, 0.05), 0.0, 0.55), "Wood": ((0.28, 0.16, 0.08), 0.0, 0.5),
        "Main": ((0.06, 0.06, 0.065), 0.6, 0.45), "MainDark": ((0.035, 0.035, 0.04), 0.3, 0.6), "MainLight": ((0.14, 0.14, 0.15), 0.85, 0.35)}
os.makedirs(out, exist_ok=True)
meta = {}
for key, (n, length) in JOBS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath=os.path.join(src, n + '.obj'))
    obs = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.context.view_layer.objects.active = obs[0]
    for o in obs:
        o.select_set(True)
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    me = ob.data
    xs = [v.co.x for v in me.vertices]
    sc = length / (max(xs) - min(xs))
    # barrel +X -> +Y (so glTF gets -Z), scale to metres
    M = Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Scale(sc, 4)
    me.transform(M)
    me.update()
    ys = [v.co.y for v in me.vertices]
    front = [v.co for v in me.vertices if v.co.y > max(ys) - 0.01]
    mz = sum(c.z for c in front) / len(front)
    for m in bpy.data.materials:
        base = m.name.split('.')[0]
        if base in LOOK and m.use_nodes:
            col, metal, rough = LOOK[base]
            b = m.node_tree.nodes['Principled BSDF']
            b.inputs['Base Color'].default_value = (*col, 1)
            b.inputs['Metallic'].default_value = metal
            b.inputs['Roughness'].default_value = rough
    for p in me.polygons:
        p.use_smooth = False
    ob.name = key
    meta[key] = {"muzzle": [0.0, round(mz, 4), round(-max(ys), 4)], "rear": round(-min(ys), 4),
                 "top": round(max(v.co.z for v in me.vertices), 4), "bottom": round(min(v.co.z for v in me.vertices), 4)}
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "gun_%s.glb" % key), export_format='GLB', export_yup=True, export_apply=True)
    print("GUN", key, meta[key])
json.dump(meta, open(os.path.join(out, "guns.json"), "w"), indent=1)
