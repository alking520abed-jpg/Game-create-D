class_name Player
extends CharacterBody3D
## البطل «سيف»: يمشي كإنسان ويتحوّل إلى خمس هيئات خارقة، لكل هيئة هجوم وقدرة خاصة.

const GRAVITY := 19.0

## الهيئة 0 هي الإنسان. الباقي تُفتح مع تقدّم القصة.
const FORMS := [
	{"id": "saif", "name": "سيف", "model": "saif", "walk": 3.4, "run": 7.2, "jump": 6.5, "radius": 0.33, "armor": 1.0,
		"atk": "melee", "dmg": 9.0, "range": 1.7, "knock": 4.0, "cd": 0.55, "color": Color(0.9, 0.9, 0.95),
		"atk_name": "لكمة", "sp_name": "", "desc": "هيئتك البشرية — تركب السيارات وتستعيد الطاقة"},
	{"id": "jalmood", "name": "جلمود", "model": "stan", "walk": 3.2, "run": 6.4, "jump": 9.5, "radius": 0.8, "armor": 0.4,
		"atk": "melee", "dmg": 42.0, "range": 3.4, "knock": 15.0, "cd": 0.62, "color": Color(0.35, 0.85, 0.75),
		"sp": "slam", "sp_cd": 6.0, "atk_name": "قبضة حديدية", "sp_name": "زلزال", "desc": "قوة ساحقة ودرع ثقيل"},
	{"id": "wameed", "name": "وميض", "model": "leela", "walk": 6.0, "run": 21.0, "jump": 11.0, "radius": 0.5, "armor": 0.85,
		"atk": "slash", "dmg": 24.0, "range": 3.0, "knock": 6.0, "cd": 0.3, "color": Color(1.0, 0.92, 0.3),
		"sp": "chain", "sp_cd": 5.0, "atk_name": "نصل خاطف", "sp_name": "صاعقة متسلسلة", "desc": "سرعة خارقة وصواعق"},
	{"id": "laheeb", "name": "لهيب", "model": "dragon", "walk": 8.0, "run": 16.0, "jump": 0.0, "radius": 0.6, "armor": 0.8, "fly": true,
		"atk": "fireball", "dmg": 28.0, "range": 60.0, "knock": 7.0, "cd": 0.42, "color": Color(1.0, 0.45, 0.15),
		"sp": "barrage", "sp_cd": 7.0, "atk_name": "كرة نار", "sp_name": "وابل اللهب", "desc": "يطير ويقذف النار"},
	{"id": "nabd", "name": "نبض", "model": "robot", "walk": 3.6, "run": 7.6, "jump": 8.0, "radius": 0.5, "armor": 0.7,
		"atk": "laser", "dmg": 20.0, "range": 48.0, "knock": 3.0, "cd": 0.3, "color": Color(0.35, 0.75, 1.0),
		"sp": "shield", "sp_cd": 10.0, "atk_name": "شعاع ليزر", "sp_name": "درع نبضي", "desc": "ليزر بعيد المدى ودرع لا يُخترق"},
	{"id": "tayf", "name": "طيف", "model": "skeleton", "walk": 4.0, "run": 8.6, "jump": 8.5, "radius": 0.36, "armor": 0.9,
		"atk": "drain", "dmg": 30.0, "range": 2.4, "knock": 5.0, "cd": 0.5, "color": Color(0.7, 0.55, 1.0),
		"sp": "vanish", "sp_cd": 11.0, "atk_name": "لمسة الطيف", "sp_name": "اختفاء", "desc": "يختفي ويمتص حياة الأعداء"},
]
const DRAIN := 1.6          # استهلاك الطاقة في الثانية أثناء التحوّل
const REGEN := 6.5          # استعادة الطاقة كإنسان
const MORPH_COST := 10.0

var rig: CharacterRig
var in_car = null
var form := 0
var invisible := 0.0
var shield := 0.0
var dead := false
var atk_cd := 0.0
var sp_cd := 0.0
var morph_cd := 0.0
var combat_t := 0.0         # وقت منذ آخر إصابة
var backstab := false
var _face := 0.0
var _cs: CollisionShape3D
var _cap: CapsuleShape3D
var _bubble: MeshInstance3D
var _aura: CPUParticles3D
var _dash := Vector3.ZERO
var _dead_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	_cs = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cs.shape = _cap
	add_child(_cs)
	rig = CharacterRig.new()
	add_child(rig)
	rig.set_model("saif")
	_fit_capsule()
	# فقاعة الدرع
	_bubble = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 10
	_bubble.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.3, 0.75, 1.0, 0.28)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bubble.material_override = bm
	_bubble.visible = false
	add_child(_bubble)
	_aura = Combat.make_particles(Color.WHITE, 18, 0.7, 0.35)
	_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_aura.emission_sphere_radius = 0.8
	_aura.gravity = Vector3(0, 2.5, 0)
	_aura.initial_velocity_min = 0.2
	_aura.initial_velocity_max = 0.8
	_aura.local_coords = false
	_aura.emitting = false
	add_child(_aura)


func f() -> Dictionary:
	return FORMS[form]


func flying() -> bool:
	return f().get("fly", false)


func height() -> float:
	return rig.height


func _fit_capsule() -> void:
	var r: float = f()["radius"]
	var h: float = max(rig.height * (0.75 if flying() else 0.96), r * 2.0 + 0.1)
	_cap.radius = r
	_cap.height = h
	_cs.position.y = h * 0.5
	if _bubble:
		_bubble.scale = Vector3.ONE * max(1.4, rig.height * 0.8)
		_bubble.position.y = rig.height * 0.5
	if _aura:
		_aura.position.y = rig.height * 0.5
		_aura.emission_sphere_radius = max(0.6, rig.height * 0.4)


# ---------------- التحوّل ----------------

func can_morph(i: int) -> String:
	if i < 1 or i >= FORMS.size():
		return "?"
	if i > Game.unlocked:
		return "هذه الهيئة لم تُفتح بعد — تابع القصة"
	if in_car != null:
		return "انزل من السيارة أولاً"
	if dead:
		return "…"
	if Game.energy < MORPH_COST + 2.0:
		return "طاقة السوار ضعيفة — انتظر قليلاً"
	return ""


func morph(i: int) -> bool:
	if i == form:
		revert()
		return false
	if morph_cd > 0.0:
		return false
	var why := can_morph(i)
	if why != "":
		Game.notify(why, Color(1, 0.7, 0.4))
		Sfx.play("fail", -10.0)
		return false
	Game.energy -= MORPH_COST
	_set_form(i)
	Game.banner.emit(f()["name"], f()["desc"], f()["color"])
	return true


func revert(silent := false) -> void:
	if form == 0:
		return
	_set_form(0)
	if not silent:
		Game.notify("عدت إلى هيئتك البشرية")


func _set_form(i: int) -> void:
	form = i
	invisible = 0.0
	shield = 0.0
	backstab = false
	rig.ghost(false)
	_bubble.visible = false
	rig.set_model(f()["model"])
	_fit_capsule()
	morph_cd = 0.6
	atk_cd = 0.25
	sp_cd = 0.0
	motion_mode = MOTION_MODE_FLOATING if flying() else MOTION_MODE_GROUNDED
	if flying():
		global_position.y += 1.2
		velocity.y = 3.0
	_aura.color = f()["color"]
	_aura.emitting = i != 0
	if Game.combat:
		Game.combat.fx_burst(global_position + Vector3(0, rig.height * 0.5, 0), f()["color"], 2.2 + rig.height * 0.4)
		Game.combat.fx_ring(global_position, 4.0, f()["color"])
	Sfx.play("morph", -3.0, 1.0 if i != 0 else 0.7)
	if Game.cam:
		Game.cam.shake(0.25)


# ---------------- الحركة ----------------

func _physics_process(delta: float) -> void:
	if in_car != null:
		Game.energy = min(Game.MAX_ENERGY, Game.energy + REGEN * delta)
		return
	if Game.state != Game.State.PLAYING:
		if Game.state == Game.State.CUTSCENE:
			rig.animate(0.0, delta)
		return
	atk_cd -= delta
	sp_cd -= delta
	morph_cd -= delta
	combat_t += delta
	if dead:
		_dead_t -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y -= GRAVITY * delta
		move_and_slide()
		if _dead_t <= 0.0:
			_respawn()
		return
	_timers(delta)
	for k in 5:
		if Game.consume("form%d" % (k + 1)):
			morph(k + 1)
	if Game.consume("revert"):
		revert()
	var fm := f()
	var iv := Game.joy
	iv.x += Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	iv.y += Input.get_action_strength("brake") - Input.get_action_strength("gas")
	if iv.length() > 1.0:
		iv = iv.normalized()
	var yaw: float = Game.cam.yaw if Game.cam else 0.0
	var dir := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
	var running: bool = Input.is_action_pressed("run") or iv.length() > 0.8 or form != 0
	var sp: float = (fm["run"] if running else fm["walk"]) * min(1.0, iv.length() * 1.25)
	var target: Vector3 = dir.normalized() * sp if iv.length() > 0.08 else Vector3.ZERO
	var acc: float = (14.0 if is_on_floor() or flying() else 5.0) * max(1.0, fm["run"] / 8.0)
	velocity.x = move_toward(velocity.x, target.x, acc * delta * 2.0)
	velocity.z = move_toward(velocity.z, target.z, acc * delta * 2.0)
	if flying():
		var vy := Input.get_action_strength("fly_up") - Input.get_action_strength("fly_down")
		velocity.y = move_toward(velocity.y, vy * 11.0, 40.0 * delta)
		if global_position.y > 150.0 and velocity.y > 0.0:
			velocity.y = 0.0
		Game.consume("jump")
	elif is_on_floor():
		if Game.consume("jump"):
			velocity.y = fm["jump"]
			Sfx.play("jump", -8.0)
	else:
		velocity.y -= GRAVITY * delta
	if _dash.length() > 0.5:
		velocity.x += _dash.x
		velocity.z += _dash.z
		_dash = _dash.move_toward(Vector3.ZERO, 90.0 * delta)
	move_and_slide()
	global_position.x = clamp(global_position.x, -City.BOUND + 2.0, City.BOUND - 2.0)
	global_position.z = clamp(global_position.z, -City.BOUND + 2.0, 560.0)
	if flying() and global_position.y < 0.2:
		global_position.y = 0.2
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3 and rig.busy <= 0.0:
		_face = atan2(-velocity.x, -velocity.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, _face, min(1.0, delta * 12.0))
	rig.animate(hs, delta, is_on_floor(), fm["walk"] + 1.2, fm["walk"] * 0.55, fm["run"] * 0.9)
	if global_position.y < -5.0:
		global_position.y = 2.0
	# الهجوم والقدرة الخاصة
	if Input.is_action_pressed("attack") and atk_cd <= 0.0:
		_attack()
	if Game.consume("special"):
		_special()


func _timers(delta: float) -> void:
	if form != 0:
		Game.energy -= DRAIN * delta * (0.7 if Game.choice == "mercy" else 1.0)
		if Game.energy <= 0.0:
			Game.energy = 0.0
			revert(true)
			Game.notify("نفدت طاقة السوار! عدت إلى هيئتك البشرية", Color(1, 0.6, 0.4))
	else:
		Game.energy = min(Game.MAX_ENERGY, Game.energy + REGEN * delta)
	if combat_t > 6.0 and Game.hp < Game.MAX_HP:
		Game.hp = min(Game.MAX_HP, Game.hp + 5.0 * delta)
	if invisible > 0.0:
		invisible -= delta
		if invisible <= 0.0:
			rig.ghost(false)
			backstab = false
			Game.notify("انتهى الاختفاء")
	if shield > 0.0:
		shield -= delta
		_bubble.visible = shield > 0.0 and (shield > 1.0 or fmod(shield, 0.2) > 0.1)


# ---------------- القتال ----------------

func _aim(max_range: float, cone := 0.2) -> Dictionary:
	## يعيد {dir, target, origin}: اتجاه التصويب نحو أقرب عدو أو للأمام
	var origin := global_position + Vector3(0, rig.height * 0.6, 0)
	var fwd := Vector3(-sin(_face), 0, -cos(_face))
	var t = Game.combat.nearest_enemy(global_position, max_range, fwd, cone)
	if t != null:
		var tp: Vector3 = t.center()
		var d := tp - origin
		_face = atan2(-d.x, -d.z)
		rig.rotation.y = _face
		return {"dir": d.normalized(), "target": t, "origin": origin}
	if f()["atk"] in ["fireball", "laser"] and Game.cam:
		var cy: float = Game.cam.yaw
		var cp: float = Game.cam.pitch
		var d2 := Vector3(-sin(cy) * cos(cp), -sin(cp) * 0.6 if flying() else 0.0, -cos(cy) * cos(cp)).normalized()
		_face = cy
		rig.rotation.y = _face
		return {"dir": d2, "target": null, "origin": origin}
	return {"dir": fwd, "target": null, "origin": origin}


func _attack() -> void:
	var fm := f()
	atk_cd = fm["cd"]
	var c: Combat = Game.combat
	var dmg: float = fm["dmg"]
	if backstab:
		dmg *= 3.0
	match fm["atk"]:
		"melee", "drain":
			var a := _aim(fm["range"] + 3.0, -0.2)
			var d: Vector3 = a["dir"]
			d.y = 0.0
			d = d.normalized()
			rig.action("attack", 1.5 if form == 0 else 1.25)
			Sfx.play("swing", -8.0, 0.8 if form == 1 else 1.1)
			var rng: float = fm["range"]
			var kn: float = fm["knock"]
			var drain: bool = fm["atk"] == "drain"
			var col: Color = fm["color"]
			get_tree().create_timer(0.16, false).timeout.connect(func():
				if dead:
					return
				var at := global_position + d * rng * 0.55 + Vector3(0, rig.height * 0.5, 0)
				var n: int = c.hit_enemies(at, rng * 0.75, dmg, d * kn + Vector3(0, kn * 0.25, 0))
				c.hit_cars(at, rng * 0.7, dmg * 0.8, d * kn * 0.6)
				c.hit_props(at, rng * 0.75, dmg)
				if n > 0:
					Sfx.play("hit", -4.0, 0.7 if form == 1 else 1.0)
					c.fx_burst(at, col, 0.9)
					if form == 1:
						Game.cam.shake(0.25)
					if drain:
						Game.hp = min(Game.MAX_HP, Game.hp + dmg * 0.35 * n)
				if backstab:
					_end_invis()
			)
		"slash":
			var a := _aim(9.0, -0.3)
			var d: Vector3 = a["dir"]
			d.y = 0.0
			d = d.normalized()
			rig.action("slash", 1.9)
			_dash = d * 16.0
			Sfx.play("swing", -6.0, 1.6)
			var at := global_position + d * 2.2 + Vector3(0, 1.2, 0)
			c.fx_slash(at, d, fm["color"])
			var n: int = c.hit_enemies(at, 2.8, dmg, d * fm["knock"])
			c.hit_cars(at, 2.4, dmg * 0.5, d * 3.0)
			c.hit_props(at, 2.8, dmg)
			if n > 0:
				Sfx.play("hit", -5.0, 1.4)
		"fireball":
			var a := _aim(fm["range"], 0.35)
			rig.action("attack", 1.6)
			Sfx.play("fire", -6.0)
			c.projectile(a["origin"] + a["dir"] * 1.2, a["dir"], 46.0, dmg, 0, Color(1.0, 0.5, 0.1), 3.2, 0.45)
		"laser":
			var a := _aim(fm["range"], 0.5)
			rig.action("shoot", 2.2)
			Sfx.play("laser", -7.0)
			c.laser(a["origin"], a["dir"], fm["range"], dmg, fm["color"], a["dir"] * fm["knock"])


func _special() -> void:
	var fm := f()
	if not fm.has("sp"):
		Game.notify("تحوّل إلى إحدى الهيئات لتستخدم قدرة خاصة", Color(1, 0.8, 0.5))
		return
	if sp_cd > 0.0:
		Game.notify("القدرة تُشحن… %d ث" % int(ceil(sp_cd)), Color(1, 0.8, 0.5))
		return
	var c: Combat = Game.combat
	var col: Color = fm["color"]
	match fm["sp"]:
		"slam":
			rig.action("special", 1.3)
			if is_on_floor():
				velocity.y = 8.5
			Sfx.play("swing", -3.0, 0.5)
			get_tree().create_timer(0.55, false).timeout.connect(func():
				if dead or form != 1:
					return
				var p := global_position
				c.fx_ring(p, 11.0, col)
				c.fx_burst(p + Vector3(0, 0.5, 0), Color(0.75, 0.65, 0.5), 5.0)
				c.hit_enemies(p, 10.0, 75.0, Vector3(0, 9, 0), 18.0, 1.2)
				c.hit_cars(p, 10.0, 120.0, Vector3(0, 0, 0), 14.0)
				c.hit_props(p, 10.0, 200.0)
				Sfx.play("boom", 0.0, 0.8)
				Game.cam.shake(0.9)
			)
		"chain":
			var list: Array = c.enemies_near(global_position, 24.0, 6)
			if list.is_empty():
				Game.notify("لا يوجد أعداء قريبون للصاعقة", Color(1, 0.8, 0.5))
				return
			rig.action("shoot", 1.6)
			var from := global_position + Vector3(0, rig.height * 0.7, 0)
			for e in list:
				var to: Vector3 = e.center()
				c.fx_beam(from, to, col, 0.35, 0.22)
				c.fx_burst(to, col, 1.2)
				e.take_damage(48.0, (to - from).normalized() * 5.0, 1.6)
				from = to
			Sfx.play("zap", -2.0)
			Game.cam.shake(0.4)
		"barrage":
			var a := _aim(70.0, 0.2)
			rig.action("special", 1.2)
			Sfx.play("fire", -2.0, 0.7)
			var base: Vector3 = a["dir"]
			var right := base.cross(Vector3.UP).normalized()
			for i in 7:
				var off := (i - 3) * 0.085
				var d := (base + right * off + Vector3(0, abs(off) * 0.25, 0)).normalized()
				c.projectile(a["origin"] + d * 1.4, d, 40.0 + i % 2 * 6.0, 26.0, 0, Color(1.0, 0.35, 0.05), 4.5, 0.6)
		"shield":
			shield = 5.5
			_bubble.visible = true
			rig.action("special", 1.4)
			var p := global_position
			c.fx_ring(p, 9.0, col)
			c.hit_enemies(p, 9.0, 36.0, Vector3(0, 5, 0), 16.0, 0.8)
			c.hit_props(p, 9.0, 100.0)
			Sfx.play("zap", -3.0, 0.6)
			Game.notify("الدرع النبضي مُفعّل — لا شيء يؤذيك الآن", col)
		"vanish":
			invisible = 7.0
			backstab = true
			rig.ghost(true)
			rig.action("special", 2.4)
			c.fx_burst(global_position + Vector3(0, 1, 0), col, 2.0)
			Sfx.play("vanish", -3.0)
			Game.notify("أنت مختفٍ — ضربتك القادمة مضاعفة ثلاث مرات", col)
	sp_cd = fm["sp_cd"]


func _end_invis() -> void:
	invisible = 0.0
	backstab = false
	rig.ghost(false)


## إصابة البطل
func hurt(dmg: float, from: Vector3) -> void:
	if dead or shield > 0.0 or Game.state != Game.State.PLAYING:
		return
	if in_car != null:
		dmg *= 0.5
	dmg *= f()["armor"]
	Game.hp -= dmg
	combat_t = 0.0
	rig.flash(Color(1, 0.15, 0.1, 0.6), 0.15)
	Sfx.play("hurt", -6.0)
	if Game.cam:
		Game.cam.shake(clamp(dmg * 0.03, 0.1, 0.6))
	if in_car == null and not flying():
		var d := global_position - from
		d.y = 0.0
		_dash = d.normalized() * min(8.0, dmg * 0.5)
	if Game.hp <= 0.0:
		_die()


func _die() -> void:
	Game.hp = 0.0
	dead = true
	_dead_t = 3.0
	if in_car != null:
		Game.main.force_exit_car()
	if form != 0:
		_set_form(0)
	_aura.emitting = false
	rig.die()
	Sfx.play("fail", -2.0)
	Game.banner.emit("سقطت!", "السوار يعيدك… حاول مرة أخرى", Color(1, 0.35, 0.3))
	if Game.story:
		Game.story.on_player_down()


func _respawn() -> void:
	dead = false
	Game.hp = Game.MAX_HP
	Game.energy = Game.MAX_ENERGY
	rig.revive()
	velocity = Vector3.ZERO
	var p: Vector3 = Game.story.respawn_point() if Game.story else Game.city.start_pos
	global_position = p
	shield = 2.5
	_bubble.visible = true
	if Game.cam:
		Game.cam.snap()


# ---------------- السيارات ----------------

func enter_car(car) -> void:
	in_car = car
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO


func exit_car() -> void:
	var car = in_car
	in_car = null
	var b: Basis = car.global_transform.basis
	var base: Vector3 = car.global_position
	var spots := [-b.x * 1.9, b.x * 1.9, b.z * 3.2, -b.z * 3.2]
	var space := get_world_3d().direct_space_state
	var chosen: Vector3 = base + spots[0]
	for s in spots:
		var p: Vector3 = base + s + Vector3(0, 1.0, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.4
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.collision_mask = 1 | 2
		if space.intersect_shape(q, 1).is_empty():
			chosen = base + s
			break
	global_position = Vector3(chosen.x, 0.05, chosen.z)
	_face = car.rotation.y
	rig.rotation.y = _face
	visible = true
	collision_layer = 4
	collision_mask = 1 | 2
