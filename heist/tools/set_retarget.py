#!/usr/bin/env python3
"""Point every character / animation scene's skeleton at its BoneMap so Godot retargets them
to the shared humanoid profile (run after adding new glTF files, then re-import)."""
import glob, re, sys, os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
JOBS = [("chars/*.gltf.import", "Armature/Skeleton3D", "res://anim/bonemap_mh.tres"),
        ("anim/ual1.glb.import", "Rig/Skeleton3D", "res://anim/bonemap_def.tres"),
        ("anim/ual2.glb.import", "Armature/Skeleton3D", "res://anim/bonemap_ue.tres")]
for pat, path, bm in JOBS:
    for f in glob.glob(pat):
        s = open(f, encoding="utf-8").read()
        sub = '_subresources={\n"nodes": {\n"PATH:%s": {\n"retarget/bone_map": Resource("%s"),\n"retarget/rest_fixer/fix_silhouette/enable": true,\n"retarget/rest_fixer/fix_silhouette/threshold": 0.0\n}\n}\n}\n' % (path, bm)
        s2 = re.sub(r"_subresources=\{.*\}\n", lambda m: sub, s, flags=re.S)
        if s2 != s:
            open(f, "w", encoding="utf-8").write(s2)
            print("patched", f)
