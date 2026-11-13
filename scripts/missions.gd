class_name Missions
extends Node3D
## المهمات الجانبية + النجوم المخفية.

const TYPE_COLOR := {
	"taxi": Color(1.0, 0.8, 0.1), "delivery": Color(1.0, 0.45, 0.15), "race": Color(0.95, 0.2, 0.25),
	"parking": Color(0.3, 0.6, 1.0), "cat": Color(0.85, 0.4, 0.9),
}
const TYPE_NAME := {"taxi": "تاكسي", "delivery": "توصيل", "race": "سباق", "parking": "اصطفاف", "cat": "قطة"}
const NEEDS_CAR := ["taxi", "delivery", "race", "parking"]
const STAR_REWARD := 25

var defs: Array = []
var markers := {}
var active := {}
var step := 0
var timer := -1.0
var elapsed := 0.0
var countdown := 0.0
var target = null           # Vector3 أو null
var objective := ""
var near = null             # المهمة القريبة (dictionary) أو null
var star_nodes: Array = []
var star_total := 0

var _rng := RandomNumberGenerator.new()
var _beacon: Node3D
var _npc: CharacterRig
var _cat: Node3D
var _cat_carried := false
var _spot: MeshInstance3D
var _spot_xf := Transform3D.IDENTITY
var _hold := 0.0
var _pts: Array = []
var _meow := 0.0
var _beacon_shader: Shader
var _t := 0.0
var _last_cd := 0


func setup() -> void:
	_rng.randomize()
	_beacon_shader = load("res://shaders/beacon.gdshader")
	var bc := func(x: int, z: int, o: Vector3) -> Vector3: return City.block_center(x, z) + o
	defs = [
		{"id": "taxi1", "type": "taxi", "title": "مشوار تاكسي", "pos": bc.call(5, 5, Vector3(27, 0, 8))},
		{"id": "taxi2", "type": "taxi", "title": "مشوار تاكسي", "pos": bc.call(1, 3, Vector3(0, 0, 27))},
		{"id": "del1", "type": "delivery", "title": "توصيل طلبات المطعم", "pos": bc.call(3, 6, Vector3(0, 0, -27))},
		{"id": "del2", "type": "delivery", "title": "توصيل طلبات السوق", "pos": bc.call(7, 2, Vector3(-27, 0, 0))},
		{"id": "race1", "type": "race", "title": "سباق وسط المدينة", "pos": bc.call(4, 5, Vector3(27, 0, 0)),
			"nodes": [Vector2i(5, 5), Vector2i(5, 3), Vector2i(7, 3), Vector2i(7, 6), Vector2i(5, 6)]},
		{"id": "race2", "type": "race", "title": "سباق الكورنيش", "pos": bc.call(1, 8, Vector3(0, 0, 27)),
			"nodes": [Vector2i(2, 9), Vector2i(9, 9), Vector2i(9, 7), Vector2i(4, 7), Vector2i(4, 9), Vector2i(2, 9)]},
		{"id": "race3", "type": "race", "title": "رالي الصحراء", "pos": bc.call(0, 0, Vector3(-27, 0, 0)),
			"points": [Vector3(-400, 0, -250), Vector3(-455, 0, -330), Vector3(-380, 0, -455), Vector3(-150, 0, -440), Vector3(150, 0, -455),
				Vector3(420, 0, -420), Vector3(440, 0, -150), Vector3(410, 0, 120), Vector3(342, 0, 250)]},
		{"id": "park1", "type": "parking", "title": "تحدي الاصطفاف", "pos": bc.call(5, 4, Vector3(-27, 0, 0))},
		{"id": "park2", "type": "parking", "title": "تحدي الاصطفاف", "pos": bc.call(1, 7, Vector3(27, 0, 0))},
		{"id": "cat1", "type": "cat", "title": "القطة الضائعة", "pos": bc.call(3, 4, Vector3(7, 0, 7))},
		{"id": "cat2", "type": "cat", "title": "القطة الضائعة", "pos": bc.call(7, 6, Vector3(-7, 0, 7))},
	]
	for d in defs:
		var m := _make_beacon(TYPE_COLOR[d["type"]], 3.0, 9.0)
		m.position = d["pos"]
		var l := Label3D.new()
		l.font = Game.font_bold
		l.font_size = 72
		l.pixel_size = 0.014
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 18
		l.modulate = TYPE_COLOR[d["type"]].lightened(0.5)
		l.position.y = 4.2
		l.text = d["title"]
		l.visibility_range_end = 120.0
		l.name = "label"
		m.add_child(l)
		if d["type"] == "cat":
			var owner_rig := CharacterRig.new()
			m.add_child(owner_rig)
			owner_rig.build(3)
			owner_rig.position = Vector3(1.6, 0, 0)
			owner_rig.name = "owner"
		add_child(m)
		markers[d["id"]] = m
	_beacon = _make_beacon(Color(1.0, 0.95, 0.3), 4.0, 60.0)
	_beacon.visible = false
	add_child(_beacon)
	_make_stars()


func _make_beacon(col: Color, radius: float, height: float) -> Node3D:
	var n := Node3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 20
	var mat := ShaderMaterial.new()
	mat.shader = _beacon_shader
	mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 0.5))
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position.y = height / 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.18
	tm.outer_radius = radius + 0.12
	tm.rings = 24
	tm.ring_segments = 6
	var ring := MeshInstance3D.new()
	ring.mesh = tm
	ring.material_override = MeshBuilder.emissive(col, 2.2)
	ring.position.y = 0.12
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	return n


func _star_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var pts: Array = []
	for i in 10:
		var a := TAU * i / 10.0 - PI / 2
		var r := 0.62 if i % 2 == 0 else 0.27
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0))
	for i in 10:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[(i + 1) % 10]
		mb.tri(p0, p1, Vector3(0, 0, 0.2), Color(1, 0.85, 0.2), Vector3.ZERO)
		mb.tri(p0, p1, Vector3(0, 0, -0.2), Color(1, 0.78, 0.15), Vector3.ZERO)
	var m := MeshBuilder.vc_material(0.3, 0.6)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.1)
	m.emission_energy_multiplier = 0.9
	return mb.commit(m)


func _make_stars() -> void:
	var mesh := _star_mesh()
	var spots: Array = Game.city.star_spots
	star_total = min(spots.size(), 50)
	for i in star_total:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = spots[i]
		mi.visibility_range_end = 160.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = not Game.stars.has(i)
		add_child(mi)
		star_nodes.append(mi)


func refresh_stars() -> void:
	for i in star_nodes.size():
		star_nodes[i].visible = not Game.stars.has(i)


func is_active() -> bool:
	return not active.is_empty()


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	_t += delta
	var pp := Game.pos()
	# النجوم
	for i in star_nodes.size():
		var s: MeshInstance3D = star_nodes[i]
		if not s.visible:
			continue
		s.rotation.y = _t * 2.0 + i
		s.position.y = 1.25 + sin(_t * 2.5 + i) * 0.15
		var dx := s.position.x - pp.x
		var dz := s.position.z - pp.z
		if dx * dx + dz * dz < 7.5:
			s.visible = false
			Game.stars[i] = true
			Game.add_money(STAR_REWARD)
			Sfx.play("star", -3.0)
			Game.notify("نجمة! %d / %d   (+%d ريال)" % [Game.stars.size(), star_total, STAR_REWARD], Color(1, 0.85, 0.3))
			if Game.stars.size() == star_total:
				Game.add_money(2000)
				Game.banner.emit("جمعت كل النجوم!", "+2000 ريال مكافأة", Color(1, 0.85, 0.3))
	# البحث عن مهمة قريبة
	near = null
	if active.is_empty():
		if Game.story and (Game.story.active or Game.story.near):
			return
		for d in defs:
			if pp.distance_to(d["pos"]) < 7.5:
				near = d
				break
		if near != null and Game.consume("mission"):
			start(near)
		return
	_run(delta, pp)


func start(d: Dictionary) -> void:
	if NEEDS_CAR.has(d["type"]) and Game.car == null:
		Game.notify("تحتاج سيارة لهذه المهمة — اركب سيارة وارجع", Color(1, 0.6, 0.4))
		Sfx.play("fail", -10.0)
		return
	active = d
	step = 0
	timer = -1.0
	elapsed = 0.0
	countdown = 0.0
	_hold = 0.0
	for id in markers:
		markers[id].visible = false
	Sfx.play("beep")
	var pp := Game.pos()
	match d["type"]:
		"taxi":
			var p := _lane_far(pp, 110, 260)
			_set_target(p["pos"])
			_npc = CharacterRig.new()
			add_child(_npc)
			_npc.build(_rng.randi() % 4)
			_npc.position = p["pos"] + City.right_of(p["dir"]) * 5.6
			var look: Vector3 = -City.right_of(p["dir"])
			_npc.rotation.y = atan2(-look.x, -look.z)
			objective = "اذهب إلى الراكب وتوقف عنده"
		"delivery":
			_pts = []
			var from := pp
			for i in 3:
				var p := _lane_far(from, 140, 300)
				_pts.append(p["pos"])
				from = p["pos"]
			_set_target(_pts[0])
			timer = pp.distance_to(_pts[0]) / 7.0 + 25.0
			objective = "وصّل الطلب 1 من 3"
		"race":
			_pts = []
			if d.has("nodes"):
				var nodes: Array = d["nodes"]
				for i in nodes.size() - 1:
					var a: Vector2i = nodes[i]
					var b: Vector2i = nodes[i + 1]
					var stp := Vector2i(sign(b.x - a.x), sign(b.y - a.y))
					var c := a
					while c != b:
						c += stp
						_pts.append(City.node_pos(c.x, c.y))
				_pts.push_front(City.node_pos(nodes[0].x, nodes[0].y))
			else:
				_pts = d["points"].duplicate()
			var total := pp.distance_to(_pts[0])
			for i in _pts.size() - 1:
				total += _pts[i].distance_to(_pts[i + 1])
			timer = total / (13.5 if d.has("nodes") else 11.0) + 12.0
			countdown = 3.5
			_last_cd = 4
			_set_target(_pts[0])
			objective = "استعد..."
		"parking":
			var best = null
			var stalls: Array = Game.city.free_stalls
			for tries in 40:
				var s = stalls[_rng.randi() % stalls.size()]
				var dd: float = pp.distance_to(s["pos"])
				if dd > 90 and dd < 420:
					best = s
					break
			if best == null:
				best = stalls[_rng.randi() % stalls.size()]
			_spot_xf = Transform3D(Basis(Vector3.UP, best["yaw"]), best["pos"])
			_spot = MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = Vector2(2.5, 5.2)
			qm.orientation = PlaneMesh.FACE_Y
			_spot.mesh = qm
			var sm := MeshBuilder.emissive(Color(0.2, 1.0, 0.4), 1.5)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.albedo_color = Color(0.2, 1.0, 0.4, 0.55)
			_spot.material_override = sm
			_spot.transform = _spot_xf
			_spot.position.y = 0.06
			add_child(_spot)
			_set_target(best["pos"])
			timer = pp.distance_to(best["pos"]) / 7.0 + 45.0
			objective = "اصطف داخل المربع الأخضر بدقة"
		"cat":
			var spot := pp
			for tries in 40:
				var q := City.random_sidewalk(_rng)
				var dd := q.distance_to(pp)
				if dd > 110 and dd < 280:
					spot = q
					break
			_cat = _make_cat()
			_cat.position = spot
			add_child(_cat)
			_cat_carried = false
			var off := Vector3(_rng.randf_range(-18, 18), 0, _rng.randf_range(-18, 18))
			_set_target(spot + off)
			objective = "ابحث عن القطة قرب العلامة (اسمع المواء)"
	Game.banner.emit(d["title"], objective, TYPE_COLOR[d["type"]])


func _lane_far(from: Vector3, min_d: float, max_d: float) -> Dictionary:
	var p := City.random_lane(_rng)
	for tries in 50:
		var d: float = from.distance_to(p["pos"])
		if d >= min_d and d <= max_d:
			break
		p = City.random_lane(_rng)
	return p


func _set_target(p) -> void:
	target = p
	_beacon.visible = p != null
	if p != null:
		_beacon.position = Vector3(p.x, 0, p.z)


func _run(delta: float, pp: Vector3) -> void:
	var d := active
	var car = Game.car
	var sp: float = abs(car.speed) if car != null else 0.0
	if countdown > 0.0:
		countdown -= delta
		var c := int(ceil(countdown - 0.5))
		if c != _last_cd:
			_last_cd = c
			Sfx.play("go" if c <= 0 else "beep")
			if c <= 0:
				objective = "انطلق! اعبر كل البوابات"
		if countdown > 0.5 and car != null:
			car.velocity = Vector3.ZERO
			car.speed = 0.0
		return
	elapsed += delta
	if timer >= 0.0:
		timer -= delta
		if timer <= 0.0:
			fail("انتهى الوقت!")
			return
	var dist: float = Vector2(pp.x - target.x, pp.z - target.z).length() if target != null else 9999.0
	match d["type"]:
		"taxi":
			if step == 0:
				if _npc and dist < 40.0:
					_npc.wave = 0.5
				if _npc:
					_npc.animate(0.0, delta)
				if car == null:
					objective = "اركب سيارة لتوصيل الراكب"
				else:
					objective = "اذهب إلى الراكب وتوقف عنده"
					if dist < 7.5 and sp < 2.0:
						_npc.queue_free()
						_npc = null
						Sfx.play("door")
						var p := _lane_far(pp, 260, 520)
						_set_target(p["pos"])
						timer = pp.distance_to(p["pos"]) / 8.0 + 28.0
						step = 1
						objective = "وصّل الراكب قبل انتهاء الوقت"
						Game.notify("الراكب: «على الوجهة لو سمحت، أنا مستعجل!»")
			else:
				if car == null:
					objective = "ارجع للسيارة! الراكب ينتظر"
				elif dist < 7.5 and sp < 2.0:
					complete(180 + int(timer) * 4)
		"delivery":
			if dist < 7.0 and sp < 3.0:
				step += 1
				Sfx.play("coin")
				if step >= 3:
					complete(280 + int(timer) * 3)
				else:
					_set_target(_pts[step])
					timer += pp.distance_to(_pts[step]) / 7.5 + 12.0
					objective = "وصّل الطلب %d من 3" % (step + 1)
					Game.notify("تم التسليم! شكراً لك")
		"race":
			objective = "البوابة %d / %d" % [step + 1, _pts.size()]
			if dist < 11.0:
				step += 1
				Sfx.play("coin", -4.0)
				if step >= _pts.size():
					var id: String = d["id"]
					var rec: bool = not Game.best.has(id) or elapsed < Game.best[id]
					if rec:
						Game.best[id] = elapsed
					complete(350 + int(timer) * 6, ("رقم قياسي جديد! " if rec else "") + "الوقت: %.1f ث" % elapsed)
				else:
					_set_target(_pts[step])
		"parking":
			if car != null:
				var loc: Vector3 = _spot_xf.affine_inverse() * car.global_position
				var ad: float = abs(wrapf(car.rotation.y - _spot_xf.basis.get_euler().y, -PI / 2, PI / 2))
				var ok: bool = abs(loc.x) < 0.75 and abs(loc.z) < 1.0 and ad < 0.28
				if ok and sp < 0.5:
					_hold += delta
					if _hold > 0.8:
						complete(160 + int(timer) * 3)
				else:
					_hold = 0.0
					if abs(loc.x) < 1.5 and abs(loc.z) < 2.6:
						objective = "عدّل وقفتك: استقم داخل المربع وتوقف"
					else:
						objective = "اصطف داخل المربع الأخضر بدقة"
		"cat":
			_meow -= delta
			var cd: float = pp.distance_to(_cat.position)
			if step == 0:
				_cat.rotation.y += delta * 0.6
				_cat.position.y = abs(sin(_t * 3.0)) * 0.08
				if cd < 45.0 and _meow < 0.0:
					_meow = 2.6
					Sfx.play("meow", lerp(-2.0, -22.0, cd / 45.0))
				if cd < 2.6:
					step = 1
					Sfx.play("meow")
					Sfx.play("coin", -6.0)
					_set_target(d["pos"])
					objective = "أعد القطة إلى صاحبتها"
					Game.notify("وجدت القطة! مياااو")
			else:
				# القطة تتبع اللاعب
				_cat.visible = car == null
				var to := pp - _cat.position
				to.y = 0
				if to.length() > 1.6:
					var v: Vector3 = to.normalized() * min(9.0, to.length() * 3.0)
					_cat.position += v * delta
					_cat.rotation.y = atan2(-to.x, -to.z)
					_cat.position.y = abs(sin(_t * 12.0)) * 0.18
				else:
					_cat.position.y = 0.0
				if car != null:
					_cat.position = pp
				if dist < 5.0:
					complete(220)


func _make_cat() -> Node3D:
	var mb := MeshBuilder.new()
	var c := Color(0.95, 0.6, 0.2)
	var w := Color(0.98, 0.95, 0.9)
	mb.sphere(Vector3(0, 0.3, 0), 0.22, c, 4, 7, Vector3(0.8, 0.8, 1.5), w)
	mb.sphere(Vector3(0, 0.46, -0.36), 0.16, c, 4, 7)
	mb.cyl(Vector3(-0.09, 0.56, -0.36), Vector3(-0.1, 0.72, -0.36), 0.06, 0.0, 4, c)
	mb.cyl(Vector3(0.09, 0.56, -0.36), Vector3(0.1, 0.72, -0.36), 0.06, 0.0, 4, c)
	mb.cyl(Vector3(0, 0.35, 0.3), Vector3(0, 0.75, 0.42), 0.04, 0.03, 5, c)
	for sx in [-0.1, 0.1]:
		for sz in [-0.2, 0.2]:
			mb.cyl(Vector3(sx, 0.2, sz), Vector3(sx, 0, sz), 0.045, 0.04, 5, w)
	mb.sphere(Vector3(-0.06, 0.5, -0.5), 0.025, Color(0.05, 0.2, 0.1), 2, 4)
	mb.sphere(Vector3(0.06, 0.5, -0.5), 0.025, Color(0.05, 0.2, 0.1), 2, 4)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit(MeshBuilder.vc_material(0.9))
	var n := Node3D.new()
	n.add_child(mi)
	n.scale = Vector3(1.5, 1.5, 1.5)
	return n


func _cleanup() -> void:
	if _npc:
		_npc.queue_free()
		_npc = null
	if _cat:
		_cat.queue_free()
		_cat = null
	if _spot:
		_spot.queue_free()
		_spot = null
	_set_target(null)
	active = {}
	timer = -1.0
	countdown = 0.0
	for id in markers:
		markers[id].visible = true


func complete(reward: int, extra := "") -> void:
	var id: String = active["id"]
	Game.done[id] = Game.done.get(id, 0) + 1
	Game.add_money(reward)
	Sfx.play("success")
	Game.banner.emit("تمت المهمة!", "+%d ريال   %s" % [reward, extra], Color(0.4, 1.0, 0.5))
	_cleanup()


func fail(why: String) -> void:
	Sfx.play("fail")
	Game.banner.emit("فشلت المهمة", why, Color(1.0, 0.4, 0.35))
	_cleanup()


func cancel() -> void:
	if is_active():
		Game.notify("تم إلغاء المهمة")
		_cleanup()


func done_count() -> int:
	var n := 0
	for d in defs:
		if Game.done.has(d["id"]):
			n += 1
	return n
