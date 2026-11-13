"""The cast of the heist game. Run: python cast.py -- <out_dir> [names...]"""
import json
import os
import sys
from mkhuman import build, macro, face_variation

TEAL = (0.05, 0.33, 0.36)
NAVY = (0.07, 0.10, 0.20)
BLACK = (0.035, 0.037, 0.045)
DARK_HAIR = (0.06, 0.045, 0.035)
BROWN_HAIR = (0.20, 0.12, 0.07)
GREY_HAIR = (0.45, 0.44, 0.43)
ARAB = {"caucasian": 0.75, "asian": 0.1, "african": 0.15}


def person(gender, seed, age=0.1, muscle=0.2, weight=0.0, race=None, strength=0.55):
    m = macro(gender, age, race or ARAB, muscle, weight)
    m.update(face_variation(seed, strength))
    return m


def crew(seed, gender="male", hair="short02", hair_tint=DARK_HAIR, masked=True, **kw):
    skin = "young_caucasian_%s" % gender
    c = {"morph": person(gender, seed, **kw), "skin": skin, "skin_gain": 0.92, "eyes": "brown", "eyebrows": "eyebrow001",
         "hair": {"id": hair, "tint": hair_tint, "variant": "dark" if hair_tint == DARK_HAIR else "brown"},
         "clothes": [{"id": "male_worksuit01", "tint": TEAL, "sat_only": True, "variant": "crew"}, {"id": "shoes03"}]}
    if masked:
        c["mask"] = {"color": (0.93, 0.91, 0.86), "accent": (0.05, 0.05, 0.06), "rough": 0.22}
    return c


def guard(seed, hair="short03", **kw):
    return {"morph": person("male", seed, **kw), "skin": "middleage_caucasian_male" if kw.get("age", 0) > 0.3 else "young_caucasian_male2",
            "skin_gain": 0.92, "eyes": "brown", "eyebrows": "eyebrow003", "hair": {"id": hair, "tint": DARK_HAIR, "variant": "dark"},
            "clothes": [{"id": "male_casualsuit01", "tint": NAVY, "variant": "guard"}, {"id": "shoes04"}]}


def police(seed, swat=False, **kw):
    c = {"morph": person("male", seed, muscle=0.5, **kw), "skin": "young_caucasian_male", "skin_gain": 0.92, "eyes": "brown",
         "eyebrows": "eyebrow002", "helmet": (0.05, 0.06, 0.08) if swat else (0.06, 0.09, 0.2),
         "clothes": [{"id": "male_casualsuit01", "tint": BLACK if swat else (0.05, 0.07, 0.15), "variant": "swat" if swat else "police",
                      "vest": (0.045, 0.05, 0.06) if swat else (0.07, 0.09, 0.14)}, {"id": "shoes03"}]}
    if swat:
        c["mask"] = {"color": (0.04, 0.04, 0.05), "rough": 0.9}
    return c


CAST = {
    # الطاقم
    "crew_suhail": crew(11, muscle=0.35),
    "crew_nasr": crew(12, hair="short04", muscle=0.9, weight=0.35),
    "crew_thuraya": crew(13, gender="female", hair="ponytail01", hair_tint=BROWN_HAIR, muscle=0.1),
    "crew_shihab": crew(14, hair="short01", muscle=0.0, weight=-0.3),
    "crew_thuraya_face": crew(13, gender="female", hair="ponytail01", hair_tint=BROWN_HAIR, muscle=0.1, masked=False),
    "crew_nasr_face": crew(12, hair="short04", muscle=0.9, weight=0.35, masked=False),
    "engineer": {"morph": person("male", 21, age=0.45, muscle=0.0), "skin": "middleage_caucasian_male", "skin_gain": 0.95, "eyes": "brown",
                 "eyebrows": "eyebrow004", "hair": {"id": "short03", "tint": GREY_HAIR, "variant": "grey"},
                 "clothes": [{"id": "male_elegantsuit01"}, {"id": "shoes04"}]},
    # الأمن والشرطة
    "guard_a": guard(31, age=0.15, weight=0.2),
    "guard_b": guard(32, hair="short04", age=0.5, weight=0.5, muscle=0.0),
    "guard_c": guard(33, hair="short01", age=0.05, muscle=0.5),
    "police_a": police(41),
    "police_b": police(42, weight=0.3),
    "swat_a": police(43, swat=True),
    # المدنيون
    "manager": {"morph": person("male", 51, age=0.7, muscle=-0.2, weight=0.5), "skin": "old_caucasian_male", "eyes": "brown",
                "eyebrows": "eyebrow005", "hair": {"id": "short03", "tint": GREY_HAIR, "variant": "grey"},
                "clothes": [{"id": "male_elegantsuit01"}, {"id": "shoes04"}]},
    "teller_f": {"morph": person("female", 52, age=0.1), "skin": "young_caucasian_female", "eyes": "brown", "eyebrows": "eyebrow006",
                 "hair": {"id": "bob01", "tint": DARK_HAIR, "variant": "dark"},
                 "clothes": [{"id": "female_elegantsuit01"}, {"id": "shoes02"}]},
    "civ_m1": {"morph": person("male", 53, age=0.2, weight=0.3), "skin": "young_caucasian_male2", "eyes": "brown", "eyebrows": "eyebrow007",
               "hair": {"id": "short01", "tint": BROWN_HAIR, "variant": "brown"},
               "clothes": [{"id": "male_casualsuit03"}, {"id": "shoes01"}]},
    "civ_m2": {"morph": person("male", 54, age=0.6, weight=0.1, race={"african": 0.8, "caucasian": 0.2}), "skin": "middleage_african_male", "eyes": "brown",
               "eyebrows": "eyebrow008", "hair": {"id": "afro01", "tint": DARK_HAIR, "variant": "dark"},
               "clothes": [{"id": "male_casualsuit05"}, {"id": "shoes05"}]},
    "civ_f1": {"morph": person("female", 55, age=0.15), "skin": "young_caucasian_female2", "eyes": "brown", "eyebrows": "eyebrow009",
               "hair": {"id": "long01", "tint": DARK_HAIR, "variant": "dark"},
               "clothes": [{"id": "female_casualsuit01"}, {"id": "shoes06"}]},
    "civ_f2": {"morph": person("female", 56, age=0.5, weight=0.3), "skin": "middleage_caucasian_female", "eyes": "brown", "eyebrows": "eyebrow010",
               "hair": {"id": "bob02", "tint": BROWN_HAIR, "variant": "brown"},
               "clothes": [{"id": "female_casualsuit02"}, {"id": "shoes02"}]},
}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    out = args[0]
    meta = {}
    mp = os.path.join(out, "cast.json")
    if os.path.exists(mp):
        meta = json.load(open(mp))
    for name, cfg in CAST.items():
        if len(args) > 1 and name not in args[1:]:
            continue
        meta[name] = build(name, out, cfg)
    json.dump(meta, open(mp, "w"), indent=1)
