"""Resize CC0 ambientCG materials into the project. usage: textures.py <src_dir> <out_dir>"""
import os, sys, glob
from PIL import Image
MAP = {"marble": "Marble012", "marble2": "Marble006", "woodfloor": "WoodFloor051", "wood": "Wood049", "concrete": "Concrete034",
       "vault": "MetalPlates006", "carpet": "Carpet016", "plaster": "PaintedPlaster017", "tiles": "Tiles107", "asphalt": "Asphalt031",
       "bricks": "Bricks105", "gold": "Metal048A", "steel": "Metal032", "terrazzo": "Terrazzo013", "paving": "PavingStones070"}
src, out = sys.argv[1], sys.argv[2]
for name, aid in MAP.items():
    for suf, tag, size in (("Color", "c", 1024), ("NormalGL", "n", 1024), ("Roughness", "r", 512)):
        fs = glob.glob(os.path.join(src, aid, "*_%s.jpg" % suf))
        if not fs:
            print("missing", name, suf)
            continue
        im = Image.open(fs[0]).convert("RGB" if tag != "r" else "L").resize((size, size), Image.LANCZOS)
        im.save(os.path.join(out, "%s_%s.jpg" % (name, tag)), quality=88)
print("ok")

# واجهة مبانٍ ليلية (نوافذ مضيئة عشوائياً) تُرسم بالكود
import random
from PIL import ImageDraw
rnd = random.Random(3)
W = 1024
fa = Image.new("RGB", (W, W), (46, 50, 58))
fe = Image.new("RGB", (W, W), (0, 0, 0))
da, de = ImageDraw.Draw(fa), ImageDraw.Draw(fe)
cols, rows = 8, 12
cw, rh = W / cols, W / rows
for r in range(rows):
    da.rectangle([0, r * rh, W, r * rh + 6], fill=(36, 39, 46))
    for c in range(cols):
        x0, y0, x1, y1 = c * cw + 22, r * rh + 18, (c + 1) * cw - 22, (r + 1) * rh - 14
        lit = rnd.random() < 0.38
        da.rectangle([x0, y0, x1, y1], fill=(60, 74, 92) if not lit else (150, 130, 90))
        da.rectangle([x0, y0, x1, y0 + 4], fill=(28, 30, 36))
        if lit:
            warm = rnd.choice([(255, 214, 140), (255, 236, 190), (190, 220, 255)])
            de.rectangle([x0, y0, x1, y1], fill=warm)
            if rnd.random() < 0.5:
                de.rectangle([x0, y0, x1, y0 + (y1 - y0) * rnd.uniform(0.2, 0.6)], fill=tuple(int(v * 0.45) for v in warm))
fa.save(os.path.join(out, "facade.jpg"), quality=88)
fe.save(os.path.join(out, "facade_e.jpg"), quality=88)
print("facade ok")
