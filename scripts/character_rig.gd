class_name CharacterRig
extends Node3D
## شخصية من مجسم جاهز (FBX) مع هيكل عظمي وأنيميشن حقيقي.
## المجسمات من Quaternius برخصة CC0 — لا توجد أي شخصية مبنية بالكود.

const DIR := "res://models/"

## لكل مجسم: الملف، الطول بالمتر، خامة (إن وجدت)، أسماء الأنيميشن
const HUMAN := {"idle": "Idle", "walk": "Walk", "run": "Walk", "attack": "Punch", "special": "Shoot_OneHanded", "shoot": "Shoot_OneHanded", "hit": "RecieveHit", "death": "Defeat", "wave": "Victory", "pick": "PickUp"}
const MECH := {"idle": "Idle", "walk": "Walk", "run": "Run", "attack": "Punch", "attack2": "Kick", "special": "Jump", "shoot": "Shoot", "slash": "SwordSlash", "hit": "HitRecieve_1", "death": "Death", "wave": "Hello", "jump": "Jump"}
const MODELS := {
	"saif": {"file": "Casual_Male", "h": 1.8, "a": HUMAN},
	"layla": {"file": "Casual_Female", "h": 1.72, "a": HUMAN},
	"doctor": {"file": "Doctor_Male_Old", "h": 1.78, "a": HUMAN},
	"civ1": {"file": "Casual2_Male", "h": 1.8, "a": HUMAN},
	"civ2": {"file": "Casual2_Female", "h": 1.7, "a": HUMAN},
	"civ3": {"file": "Casual3_Male", "h": 1.82, "a": HUMAN},
	"civ4": {"file": "Casual3_Female", "h": 1.7, "a": HUMAN},
	"civ5": {"file": "Worker_Male", "h": 1.8, "a": HUMAN},
	"civ6": {"file": "OldClassy_Male", "h": 1.76, "a": HUMAN},
	"civ7": {"file": "OldClassy_Female", "h": 1.68, "a": HUMAN},
	"civ8": {"file": "Suit_Female", "h": 1.72, "a": HUMAN},
	"civ9": {"file": "Casual_Female", "h": 1.7, "a": HUMAN},
	"thug": {"file": "Suit_Male", "h": 1.85, "a": HUMAN},
	"soldier": {"file": "Soldier_Male", "h": 1.85, "a": HUMAN},
	"mutant": {"file": "Zombie_Male", "h": 1.95, "a": HUMAN},
	"stan": {"file": "Stan", "h": 3.3, "tex": "Stan_Texture", "a": MECH},
	"leela": {"file": "Leela", "h": 2.7, "tex": "Leela_Texture", "a": MECH},
	"george": {"file": "George", "h": 4.6, "tex": "George_Texture", "a": MECH},
	"mike": {"file": "Mike", "h": 6.0, "tex": "Mike_Texture", "a": MECH},
	"robot": {"file": "Robot", "h": 2.2, "a": {"idle": "Robot_Idle", "walk": "Robot_Walking", "run": "Robot_Running", "attack": "Robot_Punch", "special": "Robot_Jump", "shoot": "Robot_Punch", "hit": "Robot_No", "death": "Robot_Death", "wave": "Robot_Wave", "jump": "Robot_Jump"}},
	"skeleton": {"file": "Skeleton", "h": 2.05, "a": {"idle": "Skeleton_Idle", "walk": "Skeleton_Running", "run": "Skeleton_Running", "attack": "Skeleton_Attack", "special": "Skeleton_Spawn", "hit": "Skeleton_Idle", "death": "Skeleton_Death"}},
	"dragon": {"file": "Dragon", "h": 2.5, "lift": 0.7, "a": {"idle": "Dragon_Flying", "walk": "Dragon_Flying", "run": "Dragon_Flying", "attack": "Dragon_Attack", "special": "Dragon_Attack2", "hit": "Dragon_Hit", "death": "Dragon_Death"}},
	"bat": {"file": "Bat", "h": 1.5, "lift": 0.2, "a": {"idle": "Bat_Flying", "walk": "Bat_Flying", "run": "Bat_Flying", "attack": "Bat_Attack", "special": "Bat_Attack2", "hit": "Bat_Hit", "death": "Bat_Death"}},
}
const CIVS := ["civ1", "civ2", "civ3", "civ4", "civ5", "civ6", "civ7", "civ8", "civ9", "layla", "saif"]
const LOOPS := ["idle", "walk", "run"]

static var _cache := {}      # id -> {scene, scale, off}
static var _mats := {}

var model_id := ""
var model: Node3D
var ap: AnimationPlayer
var height := 1.8
var wave := 0.0: set = _set_wave
var busy := 0.0             # وقت متبقٍ لحركة لمرة واحدة
var dead := false
var _cur := ""
var _names := {}
var _meshes: Array[MeshInstance3D] = []
var _ghost := false
var _flash := 0.0
var _tint_mat: StandardMaterial3D


static func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect(c, out)


static func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null


static func _rel_xf(n: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != root:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t


## holder: عقدة داخل الشجرة لقياس المجسم بدقة (القطع المربوطة بالعظام تأخذ مكانها الصحيح فقط داخل الشجرة)
static func _info(id: String, holder: Node = null) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var d: Dictionary = MODELS[id]
	var scene: PackedScene = load(DIR + d["file"] + ".fbx")
	var tmp: Node3D = scene.instantiate()
	if holder != null and holder.is_inside_tree():
		holder.add_child(tmp)
	var ms: Array = []
	_collect(tmp, ms)
	var box := AABB()
	var first := true
	for m in ms:
		var xf: Transform3D = _rel_xf(m, tmp)
		if tmp.is_inside_tree():
			xf = tmp.global_transform.affine_inverse() * (m as MeshInstance3D).global_transform
		var a: AABB = xf * (m as MeshInstance3D).get_aabb()
		box = a if first else box.merge(a)
		first = false
	if tmp.get_parent() != null:
		tmp.get_parent().remove_child(tmp)
	tmp.free()
	var s: float = d["h"] / max(box.size.y, 0.001)
	var info := {"scene": scene, "scale": s, "off": -box.position.y * s + d.get("lift", 0.0)}
	_cache[id] = info
	return info


static func preload_all(ids: Array, holder: Node = null) -> void:
	for id in ids:
		_info(id, holder)


## توافق مع الكود القديم: اختيار شخصية مدنية عشوائية أو البطل
func build(_style: int, rng: RandomNumberGenerator = null, hero := false) -> void:
	if hero:
		set_model("saif")
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	set_model(CIVS[rng.randi() % (CIVS.size() - 2)])


func set_model(id: String) -> void:
	if id == model_id:
		return
	if model != null:
		model.queue_free()
		remove_child(model)
	model_id = id
	var d: Dictionary = MODELS[id]
	var info := _info(id, self)
	height = d["h"]
	model = (info["scene"] as PackedScene).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * info["scale"]
	model.position.y = info["off"]
	model.rotation.y = PI   # المجسمات تواجه +Z واللعبة تتحرك نحو -Z
	_meshes.clear()
	var ms: Array = []
	_collect(model, ms)
	for m in ms:
		var mi: MeshInstance3D = m
		mi.extra_cull_margin = 4.0 / info["scale"]
		mi.visibility_range_end = 170.0
		_meshes.append(mi)
		if d.has("tex"):
			var k: String = d["tex"]
			if not _mats.has(k):
				var sm := StandardMaterial3D.new()
				sm.albedo_texture = load(DIR + k + ".png")
				sm.roughness = 0.7
				sm.metallic = 0.25
				_mats[k] = sm
			for s in mi.mesh.get_surface_count():
				mi.set_surface_override_material(s, _mats[k])
	ap = _find_ap(model)
	_names.clear()
	_cur = ""
	busy = 0.0
	dead = false
	if ap != null:
		var list := ap.get_animation_list()
		for key in d["a"]:
			var want: String = d["a"][key]
			for an in list:
				if an == want or an.ends_with("|" + want):
					_names[key] = an
					if key in LOOPS:
						ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
					break
	if _ghost:
		_apply_ghost()
	play("idle")


func has_anim(key: String) -> bool:
	return _names.has(key)


func play(key: String, speed := 1.0, blend := 0.18) -> void:
	if ap == null or not _names.has(key):
		return
	ap.play(_names[key], blend, speed)
	_cur = key


## حركة لمرة واحدة (ضربة، إصابة...). ترجع مدتها بالثواني.
func action(key: String, speed := 1.0) -> float:
	if ap == null or dead or not _names.has(key):
		return 0.0
	var n: String = _names[key]
	ap.stop()
	ap.play(n, 0.08, speed)
	_cur = key
	busy = ap.get_animation(n).length / speed
	return busy


func die() -> void:
	if dead:
		return
	dead = true
	busy = 9999.0
	if ap != null and _names.has("death"):
		ap.play(_names["death"], 0.1)
		_cur = "death"


func revive() -> void:
	dead = false
	busy = 0.0
	play("idle")


func _set_wave(v: float) -> void:
	wave = v
	if v > 0.0 and busy <= 0.0 and not dead:
		action("wave", 1.3)


## تحديث أنيميشن الحركة حسب السرعة (م/ث)
func animate(hs: float, delta: float, _on_floor := true, run_at := 4.8, walk_ref := 1.6, run_ref := 6.5) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_overlay(null)
	if dead:
		return
	if busy > 0.0:
		busy -= delta
		return
	if hs < 0.25:
		play("idle")
	elif hs < run_at:
		play("walk", clamp(hs / walk_ref, 0.6, 2.2))
	else:
		play("run", clamp(hs / run_ref, 0.8, 2.6) * (1.7 if _names.get("run", "") == _names.get("walk", "-") else 1.0))


# ---------------- مؤثرات على المجسم ----------------

func _set_overlay(m: Material) -> void:
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = m


static func _overlay(col: Color) -> StandardMaterial3D:
	var k := "ov" + col.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		_mats[k] = m
	return _mats[k]


## وميض عند الإصابة
func flash(col := Color(1, 1, 1, 0.75), t := 0.12) -> void:
	_flash = t
	_set_overlay(_overlay(col))


## تلوين ثابت (تجميد مثلاً). null لإزالته.
func tint(col) -> void:
	_flash = 0.0
	_set_overlay(null if col == null else _overlay(col))


## هيئة شبحية شبه شفافة
func ghost(on: bool) -> void:
	_ghost = on
	_apply_ghost()


func _apply_ghost() -> void:
	if not _mats.has("ghost"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.55, 0.85, 1.0, 0.28)
		m.emission_enabled = true
		m.emission = Color(0.3, 0.6, 1.0)
		m.emission_energy_multiplier = 0.6
		m.cull_mode = BaseMaterial3D.CULL_BACK
		_mats["ghost"] = m
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_override = _mats["ghost"] if _ghost else null
