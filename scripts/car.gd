class_name Car
extends CharacterBody3D
## سيارة: مجسم مبني بالكود + قيادة أركيد + ذكاء اصطناعي للمرور.

enum Mode { PARKED, AI, PLAYER }

const SPECS := {
	"sedan": {"name": "سيدان", "len": 4.5, "wid": 1.85, "clear": 0.3, "belt": 0.9, "top": 1.42, "hood": 1.25, "trunk": 0.95, "inf": 0.65, "inr": 0.5, "topw": 0.78, "wr": 0.34, "max": 38.0, "accel": 11.0, "grip": 7.0, "offroad": 0.55},
	"taxi": {"name": "تاكسي", "len": 4.5, "wid": 1.85, "clear": 0.3, "belt": 0.9, "top": 1.42, "hood": 1.25, "trunk": 0.95, "inf": 0.65, "inr": 0.5, "topw": 0.78, "wr": 0.34, "max": 38.0, "accel": 11.5, "grip": 7.0, "offroad": 0.55},
	"sport": {"name": "رياضية", "len": 4.5, "wid": 1.98, "clear": 0.22, "belt": 0.74, "top": 1.16, "hood": 1.5, "trunk": 0.85, "inf": 0.8, "inr": 0.75, "topw": 0.72, "wr": 0.35, "max": 58.0, "accel": 19.0, "grip": 8.5, "offroad": 0.4},
	"super": {"name": "خارقة", "len": 4.6, "wid": 2.04, "clear": 0.2, "belt": 0.7, "top": 1.08, "hood": 1.45, "trunk": 1.1, "inf": 0.9, "inr": 0.9, "topw": 0.68, "wr": 0.36, "max": 72.0, "accel": 26.0, "grip": 9.5, "offroad": 0.35},
	"suv": {"name": "جيب", "len": 4.7, "wid": 2.0, "clear": 0.46, "belt": 1.15, "top": 1.88, "hood": 1.25, "trunk": 0.12, "inf": 0.35, "inr": 0.12, "topw": 0.88, "wr": 0.44, "max": 44.0, "accel": 13.0, "grip": 6.5, "offroad": 1.0},
	"pickup": {"name": "بيك أب", "len": 5.1, "wid": 1.95, "clear": 0.42, "belt": 1.05, "top": 1.72, "hood": 1.3, "trunk": 2.05, "inf": 0.4, "inr": 0.15, "topw": 0.86, "wr": 0.42, "max": 37.0, "accel": 10.0, "grip": 6.0, "offroad": 0.9},
}
const COLORS := ["c0392b", "2a6fb8", "f2f2f2", "1d1f24", "8e9aa6", "2e8b57", "e67e22", "6c3fa0", "d4b483", "14808a"]

static var _meshes := {}
static var _wheels := {}
static var _mats := {}
static var _dust_tex: Texture2D

var spec_id := "sedan"
var spec := {}
var color := Color.WHITE
var mode: int = Mode.PARKED
var speed := 0.0
var steer := 0.0
var lateral := 0.0
var price := 0
var body: Node3D
var front_pivots: Array = []
var wheel_meshes: Array = []
var _spin := 0.0
var _tag: Label3D
var _light: SpotLight3D
var _dust: CPUParticles3D
var _horn_cd := 0.0

# الذكاء الاصطناعي
var ai_a := Vector2i.ZERO
var ai_b := Vector2i.ZERO
var ai_c := Vector2i.ZERO
var ai_stage := 0
var ai_cruise := 11.0
var blocked_t := 0.0
var _ignore_ai := 0.0
var _rng := RandomNumberGenerator.new()


static func mat(n: String) -> Material:
	if _mats.is_empty():
		var p := MeshBuilder.vc_material(0.38, 0.2)
		_mats["paint"] = p
		var g := StandardMaterial3D.new()
		g.albedo_color = Color(0.06, 0.09, 0.13)
		g.roughness = 0.08
		g.metallic = 0.7
		_mats["glass"] = g
		_mats["head"] = MeshBuilder.emissive(Color(1.0, 0.97, 0.85), 0.6)
		_mats["tail"] = MeshBuilder.emissive(Color(0.9, 0.05, 0.05), 0.8)
		_mats["tire"] = MeshBuilder.vc_material(0.8, 0.1)
	return _mats[n]


static func set_night(n: float) -> void:
	mat("head")
	_mats["head"].emission_energy_multiplier = 0.5 + n * 3.5
	_mats["tail"].emission_energy_multiplier = 0.6 + n * 2.0


static func body_mesh(id: String, col: Color) -> ArrayMesh:
	var key := id + col.to_html()
	if _meshes.has(key):
		return _meshes[key]
	var s: Dictionary = SPECS[id]
	var L: float = s["len"]
	var W: float = s["wid"]
	var hl := L / 2
	var cl: float = s["clear"]
	var belt: float = s["belt"]
	var top: float = s["top"]
	var wr: float = s["wr"]
	var dark := Color(0.09, 0.09, 0.1)
	var mb := MeshBuilder.new()
	var gl := MeshBuilder.new()
	var hd := MeshBuilder.new()
	var tl := MeshBuilder.new()
	var z0: float = -hl + s["hood"]
	var z1: float = hl - s["trunk"]
	var prof := [Vector2(-hl, cl + 0.08), Vector2(-hl, belt - 0.24), Vector2(-hl + 0.22, belt - 0.09), Vector2(z0, belt),
		Vector2(z1, belt), Vector2(hl - 0.12, belt - 0.04), Vector2(hl, belt - 0.22), Vector2(hl, cl + 0.08), Vector2(hl - 0.3, cl), Vector2(-hl + 0.3, cl)]
	mb.extrude(prof, -W / 2, W / 2, col)
	var tz0: float = z0 + s["inf"]
	var tz1: float = z1 - s["inr"]
	var tw: float = W * s["topw"]
	gl.frustum(belt - 0.01, top, z0 + 0.05, z1 - 0.05, W - 0.14, tz0, tz1, tw, Color.WHITE)
	mb.box(Vector3(0, top + 0.025, (tz0 + tz1) / 2), Vector3(tw + 0.06, 0.07, tz1 - tz0 + 0.08), col)
	# عمود وسطي + أعمدة الزوايا
	var zc := (tz0 + tz1) / 2 + 0.1
	for sx in [-1.0, 1.0]:
		mb.quad(Vector3(sx * (W / 2 - 0.06), belt, zc - 0.07), Vector3(sx * (W / 2 - 0.06), belt, zc + 0.07),
			Vector3(sx * (tw / 2 + 0.012), top, zc + 0.07), Vector3(sx * (tw / 2 + 0.012), top, zc - 0.07), col, Vector3(0, 1, zc))
		# مرايا
		mb.box(Vector3(sx * (W / 2 + 0.07), belt + 0.08, z0 + 0.3), Vector3(0.14, 0.1, 0.18), col)
		# أقواس العجلات
		for wz in [-L * 0.3, L * 0.3]:
			mb.cyl(Vector3(sx * (W / 2 - 0.4), wr, wz), Vector3(sx * (W / 2 + 0.012), wr, wz), wr + 0.09, wr + 0.09, 10, dark)
		# خط سفلي
		mb.box(Vector3(sx * W / 2, cl + 0.1, 0), Vector3(0.03, 0.14, L * 0.5), dark)
	# صدامات وشبك
	mb.box(Vector3(0, cl + 0.16, -hl + 0.02), Vector3(W + 0.06, 0.2, 0.22), dark)
	mb.box(Vector3(0, cl + 0.16, hl - 0.02), Vector3(W + 0.06, 0.2, 0.22), dark)
	mb.box(Vector3(0, belt - 0.42, -hl - 0.012), Vector3(W * 0.5, 0.16, 0.04), dark)
	mb.box(Vector3(0, cl + 0.42, hl + 0.012), Vector3(0.5, 0.13, 0.03), Color(0.95, 0.95, 0.9))
	for sx in [-1.0, 1.0]:
		hd.box(Vector3(sx * (W / 2 - 0.32), belt - 0.3, -hl - 0.005), Vector3(0.44, 0.14, 0.06), Color.WHITE)
		tl.box(Vector3(sx * (W / 2 - 0.3), belt - 0.26, hl + 0.005), Vector3(0.46, 0.12, 0.06), Color.WHITE)
	match id:
		"taxi":
			hd.box(Vector3(0, top + 0.16, (tz0 + tz1) / 2), Vector3(0.6, 0.2, 0.26), Color.WHITE)
			for sx in [-1.0, 1.0]:
				for k in 8:
					if k % 2 == 0:
						mb.box(Vector3(sx * (W / 2 + 0.005), belt - 0.2, -1.4 + k * 0.4), Vector3(0.02, 0.14, 0.4), dark)
		"sport", "super":
			mb.box(Vector3(0, belt + 0.3, hl - 0.22), Vector3(W * 0.92, 0.05, 0.36), dark if id == "sport" else col)
			for sx in [-1.0, 1.0]:
				mb.box(Vector3(sx * W * 0.34, belt + 0.14, hl - 0.22), Vector3(0.06, 0.3, 0.2), dark)
			mb.box(Vector3(0, belt + 0.012, -hl + 0.75), Vector3(0.5, 0.03, 0.9), dark)
		"suv":
			for sx in [-1.0, 1.0]:
				mb.box(Vector3(sx * (tw / 2 - 0.08), top + 0.12, (tz0 + tz1) / 2), Vector3(0.06, 0.06, (tz1 - tz0) * 0.85), dark)
			mb.cyl(Vector3(0, belt - 0.1, hl + 0.02), Vector3(0, belt - 0.1, hl + 0.26), 0.4, 0.4, 10, dark)
		"pickup":
			var bz := (z1 + hl) / 2
			var bl: float = hl - z1
			mb.box(Vector3(0, belt + 0.008, bz), Vector3(W - 0.3, 0.02, bl - 0.25), dark)
			for sx in [-1.0, 1.0]:
				mb.box(Vector3(sx * (W / 2 - 0.07), belt + 0.14, bz), Vector3(0.14, 0.28, bl - 0.05), col)
			mb.box(Vector3(0, belt + 0.14, hl - 0.07), Vector3(W, 0.28, 0.14), col)
	var mesh := mb.commit(mat("paint"))
	gl.commit(mat("glass"), mesh)
	hd.commit(mat("head"), mesh)
	tl.commit(mat("tail"), mesh)
	_meshes[key] = mesh
	return mesh


static func wheel_mesh(r: float) -> ArrayMesh:
	var key := snappedf(r, 0.01)
	if _wheels.has(key):
		return _wheels[key]
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), r, r, 12, Color(0.06, 0.06, 0.07))
	mb.cyl(Vector3(-0.14, 0, 0), Vector3(0.14, 0, 0), r * 0.62, r * 0.62, 5, Color(0.75, 0.76, 0.8))
	mb.cyl(Vector3(-0.15, 0, 0), Vector3(0.15, 0, 0), r * 0.2, r * 0.2, 6, Color(0.3, 0.3, 0.33))
	var m := mb.commit(mat("tire"))
	_wheels[key] = m
	return m


func setup(id: String, col: Color) -> void:
	spec_id = id
	spec = SPECS[id]
	color = col
	_rng.randomize()
	collision_layer = 2
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(spec["wid"], 1.1, spec["len"])
	cs.shape = bs
	cs.position.y = 0.85
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = body_mesh(id, col)
	mi.visibility_range_end = 260.0
	body.add_child(mi)
	var wr: float = spec["wr"]
	var wm := wheel_mesh(wr)
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			var piv := Node3D.new()
			piv.position = Vector3(sx * (spec["wid"] / 2 - 0.15), wr, sz * spec["len"] * 0.3)
			add_child(piv)
			var w := MeshInstance3D.new()
			w.mesh = wm
			w.visibility_range_end = 120.0
			piv.add_child(w)
			wheel_meshes.append(w)
			if sz < 0:
				front_pivots.append(piv)
	set_mode(Mode.PARKED)


func set_price(p: int) -> void:
	price = p
	if p > 0 and not Game.owned.has(spec_id):
		_tag = Label3D.new()
		_tag.font = Game.font_bold
		_tag.font_size = 64
		_tag.pixel_size = 0.012
		_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_tag.text = "%s\n%d ريال" % [spec["name"], p]
		_tag.modulate = Color(1, 0.9, 0.3)
		_tag.outline_size = 14
		_tag.position.y = 3.0
		_tag.visibility_range_end = 70.0
		add_child(_tag)


func locked() -> bool:
	return price > 0 and not Game.owned.has(spec_id)


func unlock() -> void:
	Game.owned[spec_id] = true
	if _tag:
		_tag.queue_free()
		_tag = null


func set_mode(m: int) -> void:
	mode = m
	match m:
		Mode.PLAYER:
			collision_mask = 1 | 2
		Mode.AI:
			collision_mask = 1 | 4
		Mode.PARKED:
			collision_mask = 1 | 2
	set_physics_process(true)
	_fx(m == Mode.PLAYER)


func _fx(on: bool) -> void:
	if on:
		if _light == null:
			_light = SpotLight3D.new()
			_light.position = Vector3(0, 0.9, -spec["len"] / 2 - 0.1)
			_light.rotation.x = -0.12
			_light.spot_range = 55.0
			_light.spot_angle = 40.0
			_light.light_color = Color(1.0, 0.95, 0.8)
			_light.shadow_enabled = false
			add_child(_light)
			_dust = CPUParticles3D.new()
			_dust.position = Vector3(0, 0.25, spec["len"] / 2 - 0.4)
			_dust.amount = 26
			_dust.lifetime = 0.9
			_dust.local_coords = false
			_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			_dust.emission_box_extents = Vector3(0.9, 0.05, 0.2)
			_dust.direction = Vector3(0, 1, 0.5)
			_dust.spread = 35.0
			_dust.gravity = Vector3(0, 0.6, 0)
			_dust.initial_velocity_min = 0.6
			_dust.initial_velocity_max = 2.2
			_dust.scale_amount_min = 0.7
			_dust.scale_amount_max = 1.8
			var cv := Curve.new()
			cv.add_point(Vector2(0, 0.4))
			cv.add_point(Vector2(1, 1.6))
			_dust.scale_amount_curve = cv
			var gr := Gradient.new()
			gr.set_color(0, Color(1, 1, 1, 0.55))
			gr.set_color(1, Color(1, 1, 1, 0.0))
			_dust.color_ramp = gr
			var qm := QuadMesh.new()
			qm.size = Vector2(1.2, 1.2)
			var dm := StandardMaterial3D.new()
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			dm.vertex_color_use_as_albedo = true
			if _dust_tex == null:
				var g2 := Gradient.new()
				g2.set_color(0, Color(1, 1, 1, 1))
				g2.set_color(1, Color(1, 1, 1, 0))
				var gt := GradientTexture2D.new()
				gt.gradient = g2
				gt.fill = GradientTexture2D.FILL_RADIAL
				gt.fill_from = Vector2(0.5, 0.5)
				gt.fill_to = Vector2(1.0, 0.5)
				gt.width = 64
				gt.height = 64
				_dust_tex = gt
			dm.albedo_texture = _dust_tex
			qm.material = dm
			_dust.mesh = qm
			_dust.emitting = false
			add_child(_dust)
		_light.visible = true
	else:
		if _light:
			_light.visible = false
		if _dust:
			_dust.emitting = false


func _physics_process(delta: float) -> void:
	if Game.state == Game.State.MENU and mode != Mode.AI:
		return
	_horn_cd -= delta
	match mode:
		Mode.PARKED:
			if abs(speed) < 0.05 and abs(lateral) < 0.05:
				velocity = Vector3.ZERO
				speed = 0.0
				set_physics_process(false)
				return
			_move(0.0, 0.0, true, delta)
		Mode.PLAYER:
			var th := Input.get_action_strength("gas") - Input.get_action_strength("brake")
			var st := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
			if abs(Game.joy.x) > 0.15:
				st = clamp(st + Game.joy.x * 1.2, -1.0, 1.0)
			if Game.state != Game.State.PLAYING:
				th = 0.0
				st = 0.0
			_move(th, st, Input.is_action_pressed("handbrake"), delta)
			if Game.consume("horn"):
				Sfx.play("horn", -4.0)
			_light.light_energy = Game.night * 7.0
			var surf := City.surface_at(global_position)
			var dusty: bool = (surf == 2 and abs(speed) > 4.0) or abs(lateral) > 4.0
			_dust.emitting = dusty
			if dusty:
				_dust.color = Color(0.85, 0.72, 0.5) if surf == 2 else Color(0.8, 0.8, 0.8)
		Mode.AI:
			_ai(delta)


func _move(th: float, st: float, hb: bool, delta: float, no_reverse := false) -> void:
	steer = move_toward(steer, st, delta * 3.6)
	var pre := velocity
	var b := global_transform.basis
	var vf0 := velocity.dot(-b.z)
	var sf: float = clamp(abs(vf0) / 6.0, 0.0, 1.0) * sign(vf0)
	var turn: float = steer * sf * 2.15 / (1.0 + abs(vf0) / 30.0) * (1.4 if hb else 1.0)
	rotation.y -= turn * delta
	b = global_transform.basis
	var fwd := -b.z
	var right := b.x
	var vf := velocity.dot(fwd)
	var vl := velocity.dot(right)
	var surf := City.surface_at(global_position)
	var maxs: float = spec["max"] * (1.0 if surf < 2 else spec["offroad"])
	var acc: float = spec["accel"]
	if th > 0.0:
		if vf < -0.5:
			vf += 26.0 * delta
		else:
			var k: float = clamp(vf / maxs, 0.0, 1.0)
			vf += acc * th * (1.0 - k * k * k) * delta
	elif th < 0.0:
		if vf > 0.5:
			vf -= 30.0 * delta * -th
		elif no_reverse:
			vf = move_toward(vf, 0.0, 30.0 * delta)
		else:
			vf = max(vf - acc * 0.7 * delta, -maxs * 0.3)
	else:
		vf = move_toward(vf, 0.0, (1.5 + abs(vf) * 0.12) * delta)
	if vf > maxs:
		vf = move_toward(vf, maxs, 14.0 * delta)
	if hb:
		vf = move_toward(vf, 0.0, 13.0 * delta)
	var grip: float = spec["grip"] * (0.22 if hb else 1.0) * (0.55 if surf == 2 else 1.0)
	vl *= exp(-grip * delta)
	velocity = fwd * vf + right * vl
	move_and_slide()
	global_position.y = 0.0
	velocity.y = 0.0
	speed = velocity.dot(fwd)
	lateral = velocity.dot(right)
	if mode == Mode.PLAYER and (pre - velocity).length() > 7.0 and get_slide_collision_count() > 0:
		Sfx.play("door", -2.0, 0.7)
	# حركة العجلات والهيكل
	var wr: float = spec["wr"]
	_spin += speed / wr * delta
	for w in wheel_meshes:
		w.rotation.x = -_spin
	for p in front_pivots:
		p.rotation.y = -steer * 0.5
	var kk: float = min(1.0, delta * 6.0)
	body.rotation.z = lerp(body.rotation.z, clamp(steer * sf * abs(vf) * 0.004 + vl * 0.012, -0.09, 0.09), kk)
	body.rotation.x = lerp(body.rotation.x, clamp((vf - vf0) / max(delta, 0.001) * 0.0035, -0.05, 0.05), kk)


# ---------------- المرور ----------------

func ai_start(lane: Dictionary) -> void:
	ai_a = lane["a"]
	ai_b = lane["b"]
	ai_stage = 0
	global_position = lane["pos"]
	var d: Vector3 = lane["dir"]
	rotation.y = atan2(-d.x, -d.z)
	velocity = d * 6.0
	speed = 6.0
	ai_cruise = _rng.randf_range(9.0, 13.5)
	blocked_t = 0.0
	set_mode(Mode.AI)


func _ai(delta: float) -> void:
	var pos := global_position
	var pa := City.node_pos(ai_a.x, ai_a.y)
	var pb := City.node_pos(ai_b.x, ai_b.y)
	var d := (pb - pa).normalized()
	var r := City.right_of(d)
	var tgt: Vector3
	var slow := false
	if ai_stage == 0:
		var along := (pos - pa).dot(d)
		var seg := pa.distance_to(pb)
		var end := seg - 11.0
		tgt = pa + d * min(along + 9.0, end + 2.0) + r * City.LANE
		if along > end - 14.0:
			slow = true
		if along >= end:
			var nb := City.neighbors(ai_b)
			var opts := []
			for n in nb:
				if n != ai_a:
					opts.append(n)
			# فضّل السير للأمام
			var straight := ai_b + (ai_b - ai_a)
			if opts.has(straight) and _rng.randf() < 0.5:
				ai_c = straight
			else:
				ai_c = opts[_rng.randi() % opts.size()]
			ai_stage = 1
	if ai_stage == 1:
		var pc := City.node_pos(ai_c.x, ai_c.y)
		var nd := (pc - pb).normalized()
		tgt = pb + nd * 11.0 + City.right_of(nd) * City.LANE
		slow = true
		if (tgt - pos).dot(nd) < 1.0:
			ai_a = ai_b
			ai_b = ai_c
			ai_stage = 0
	var to := tgt - pos
	var want := atan2(-to.x, -to.z)
	var diff := wrapf(want - rotation.y, -PI, PI)
	var st: float = clamp(-diff * 2.2, -1.0, 1.0)
	var cruise := ai_cruise * (0.5 if slow else 1.0)
	if abs(diff) > 0.5:
		cruise = min(cruise, 4.5)
	# هل يوجد عائق أمامي؟
	var fwd := -global_transform.basis.z
	var rgt := global_transform.basis.x
	var look: float = 7.0 + max(speed, 0.0) * 0.9
	var blocked := false
	var by_ai := false
	_ignore_ai -= delta
	for o in Game.cars:
		if o == self or not is_instance_valid(o):
			continue
		if o.mode == Mode.AI and _ignore_ai > 0.0:
			continue
		var rel: Vector3 = o.global_position - pos
		var fd := rel.dot(fwd)
		if fd > 0.5 and fd < look and abs(rel.dot(rgt)) < 2.1:
			blocked = true
			by_ai = o.mode == Mode.AI
			break
	if not blocked and Game.player != null and Game.car == null:
		var rel2: Vector3 = Game.player.global_position - pos
		var fd2 := rel2.dot(fwd)
		if fd2 > 0.0 and fd2 < look and abs(rel2.dot(rgt)) < 1.8:
			blocked = true
	var th := 0.0
	if blocked:
		th = -1.0
		blocked_t += delta
		if by_ai and blocked_t > 5.0:
			_ignore_ai = 3.5
			blocked_t = 0.0
		if blocked_t > 6.0 and _horn_cd < 0.0 and pos.distance_to(Game.pos()) < 30.0:
			Sfx.play("horn", -14.0, 1.15)
			_horn_cd = 5.0
	else:
		blocked_t = max(0.0, blocked_t - delta)
		if speed < cruise - 0.5:
			th = 0.55
		elif speed > cruise + 1.5:
			th = -0.6
	_move(th, st, false, delta, true)
