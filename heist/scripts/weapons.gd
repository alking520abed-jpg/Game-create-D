class_name Weapons
extends RefCounted
## تعريف الأسلحة.

const DEFS := {
	"pistol": {"name": "مسدس", "mag": 12, "reserve": 60, "dmg": 26.0, "rate": 0.17, "auto": false, "spread": 0.9, "ads_spread": 0.25, "recoil": 1.5, "reload": 1.3, "pellets": 1, "sound": "shot_pistol", "range": 60.0, "head": 2.2},
	"smg": {"name": "رشاش قصير", "mag": 30, "reserve": 150, "dmg": 17.0, "rate": 0.075, "auto": true, "spread": 1.7, "ads_spread": 0.7, "recoil": 0.85, "reload": 1.8, "pellets": 1, "sound": "shot_smg", "range": 50.0, "head": 1.8},
	"shotgun": {"name": "شوزن", "mag": 6, "reserve": 30, "dmg": 13.0, "rate": 0.8, "auto": false, "spread": 4.2, "ads_spread": 3.2, "recoil": 5.0, "reload": 2.4, "pellets": 9, "sound": "shot_shotgun", "range": 26.0, "head": 1.4},
	"rifle": {"name": "بندقية هجومية", "mag": 30, "reserve": 120, "dmg": 30.0, "rate": 0.1, "auto": true, "spread": 1.2, "ads_spread": 0.3, "recoil": 1.25, "reload": 2.1, "pellets": 1, "sound": "shot_rifle", "range": 90.0, "head": 2.0},
}
const ORDER := ["pistol", "smg", "shotgun", "rifle"]
const MUZZLE := {
	"pistol": {"pos": Vector3(0, 0.068, -0.19)},
	"smg": {"pos": Vector3(0, 0.066, -0.31)},
	"shotgun": {"pos": Vector3(0, 0.035, -0.73)},
	"rifle": {"pos": Vector3(0, 0.109, -0.63)},
}
