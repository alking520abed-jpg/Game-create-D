class_name CharacterRig
extends Node3D
## شخصية مبنية بالكود مع أنيميشن إجرائي (مشي، جري، قفز، تلويح).

const SKINS := ["f1c9a5", "e0ac7e", "c68f5e", "a8703f", "8a5a33"]
const SHIRTS := ["d94f3d", "2f7fc1", "3aa76d", "e2b23a", "7d4fb8", "e8e8e8", "2b2b33", "e57fa0", "1f9e9e"]
const PANTS := ["2c3e5a", "3b3b40", "5a4632", "1f2a44", "6b6b70"]

var style := 0          # 0 شاب، 1 ثوب وشماغ، 2 عباية وحجاب، 3 بنت/فستان
var phase := 0.0
var wave := 0.0
var l_arm: Node3D
var r_arm: Node3D
var l_leg: Node3D
var r_leg: Node3D
var torso: Node3D
var head: Node3D
var _t := 0.0

static var _mesh_cache := {}
static var _mat_cache := {}


static func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var k := c.to_html() + str(rough)
	if not _mat_cache.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mat_cache[k] = m
	return _mat_cache[k]


static func _capsule(r: float, h: float) -> Mesh:
	var k := "c%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(k):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 8
		m.rings = 3
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func _sphere(r: float) -> Mesh:
	var k := "s%.3f" % r
	if not _mesh_cache.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2
		m.radial_segments = 10
		m.rings = 6
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func _box(s: Vector3) -> Mesh:
	var k := "b" + str(s)
	if not _mesh_cache.has(k):
		var m := BoxMesh.new()
		m.size = s
		_mesh_cache[k] = m
	return _mesh_cache[k]


func _part(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(col)
	mi.position = pos
	mi.scale = scl
	mi.visibility_range_end = 130.0
	parent.add_child(mi)
	return mi


func build(p_style: int, rng: RandomNumberGenerator = null, hero := false) -> void:
	style = p_style
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var skin := Color(SKINS[rng.randi() % SKINS.size()])
	var shirt := Color(SHIRTS[rng.randi() % SHIRTS.size()])
	var pants := Color(PANTS[rng.randi() % PANTS.size()])
	var hair := Color(0.1, 0.08, 0.07) if rng.randf() < 0.8 else Color(0.35, 0.22, 0.12)
	var shoes := Color(0.15, 0.15, 0.17)
	if hero:
		skin = Color("e0ac7e")
		shirt = Color("e8452c")
		pants = Color("26334d")
		shoes = Color(0.95, 0.95, 0.95)
	if style == 1:
		shirt = Color(0.96, 0.96, 0.94)
		pants = shirt
	elif style == 2:
		shirt = [Color(0.1, 0.1, 0.12), Color(0.2, 0.15, 0.3), Color(0.1, 0.25, 0.3), Color(0.35, 0.12, 0.18)][rng.randi() % 4]
		pants = shirt
	elif style == 3:
		pants = shirt.darkened(0.1)

	torso = Node3D.new()
	torso.position.y = 0.92
	add_child(torso)
	_part(torso, _capsule(0.21, 0.62), shirt, Vector3(0, 0.3, 0), Vector3(1.05, 1, 0.72))
	if hero:
		# سترة بلون مختلف + حقيبة ظهر
		_part(torso, _box(Vector3(0.44, 0.08, 0.3)), Color(0.95, 0.95, 0.95), Vector3(0, 0.25, 0))
		_part(torso, _box(Vector3(0.3, 0.36, 0.14)), Color(0.15, 0.35, 0.6), Vector3(0, 0.33, 0.2))
	# الرأس
	head = Node3D.new()
	head.position.y = 0.72
	torso.add_child(head)
	_part(head, _sphere(0.17), skin, Vector3(0, 0.08, 0), Vector3(1, 1.08, 1))
	_part(head, _capsule(0.07, 0.18), skin, Vector3(0, -0.1, 0))
	var eye := Color(0.08, 0.06, 0.05)
	_part(head, _sphere(0.025), eye, Vector3(-0.065, 0.1, -0.15))
	_part(head, _sphere(0.025), eye, Vector3(0.065, 0.1, -0.15))
	match style:
		0:
			_part(head, _sphere(0.18), hair, Vector3(0, 0.14, 0.03), Vector3(1.02, 0.75, 1.02))
			if hero or rng.randf() < 0.3:
				var cap := Color("1f6fd0") if hero else shirt.darkened(0.2)
				_part(head, _sphere(0.185), cap, Vector3(0, 0.17, 0.02), Vector3(1.03, 0.62, 1.03))
				_part(head, _box(Vector3(0.24, 0.025, 0.16)), cap, Vector3(0, 0.17, -0.2))
		1:
			# شماغ وعقال
			var red := rng.randf() < 0.6
			var gh := Color(0.85, 0.2, 0.2) if red else Color(0.97, 0.97, 0.95)
			_part(head, _sphere(0.19), gh, Vector3(0, 0.13, 0.03), Vector3(1.05, 0.85, 1.08))
			_part(head, _box(Vector3(0.36, 0.3, 0.06)), gh, Vector3(0, -0.06, 0.16))
			_part(head, _box(Vector3(0.05, 0.3, 0.2)), gh, Vector3(-0.18, -0.06, 0.06))
			_part(head, _box(Vector3(0.05, 0.3, 0.2)), gh, Vector3(0.18, -0.06, 0.06))
			var ag := CylinderMesh.new()
			ag.top_radius = 0.175
			ag.bottom_radius = 0.175
			ag.height = 0.035
			ag.radial_segments = 10
			_part(head, ag, Color(0.05, 0.05, 0.05), Vector3(0, 0.21, 0.02))
		2:
			var hj: Color = [shirt, Color(0.9, 0.85, 0.8), Color(0.75, 0.55, 0.6), Color(0.5, 0.6, 0.75)][rng.randi() % 4]
			_part(head, _sphere(0.2), hj, Vector3(0, 0.1, 0.035), Vector3(1.05, 1.1, 1.05))
			_part(head, _capsule(0.13, 0.3), hj, Vector3(0, -0.12, 0.02), Vector3(1.3, 1, 1))
		3:
			_part(head, _sphere(0.185), hair, Vector3(0, 0.13, 0.04), Vector3(1.05, 0.85, 1.05))
			_part(head, _capsule(0.09, 0.4), hair, Vector3(0, -0.12, 0.14), Vector3(1.4, 1, 0.7))
	# الأذرع
	l_arm = _limb(torso, Vector3(-0.27, 0.56, 0), shirt, skin, 0.065, 0.58, style == 0 and not hero and rng.randf() < 0.6)
	r_arm = _limb(torso, Vector3(0.27, 0.56, 0), shirt, skin, 0.065, 0.58, false)
	# الأرجل
	l_leg = _limb(self, Vector3(-0.11, 0.9, 0), pants, shoes, 0.085, 0.86, false, true)
	r_leg = _limb(self, Vector3(0.11, 0.9, 0), pants, shoes, 0.085, 0.86, false, true)
	if style == 1 or style == 2 or style == 3:
		# ثوب / عباية / فستان
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.3 if style != 3 else 0.36
		cm.height = 0.82 if style != 3 else 0.55
		cm.radial_segments = 10
		var sk := _part(torso, cm, shirt if style != 3 else shirt, Vector3(0, -0.36 if style != 3 else -0.22, 0), Vector3(1, 1, 0.8))
		sk.name = "skirt"


func _limb(parent: Node3D, pos: Vector3, col: Color, end_col: Color, r: float, length: float, short_sleeve := false, is_leg := false) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_part(pivot, _capsule(r, length), end_col if short_sleeve else col, Vector3(0, -length / 2 + r, 0))
	if short_sleeve:
		_part(pivot, _capsule(r * 1.15, length * 0.45), col, Vector3(0, -length * 0.16, 0))
	if is_leg:
		_part(pivot, _box(Vector3(0.14, 0.09, 0.27)), end_col, Vector3(0, -length + r * 0.6, -0.05))
	else:
		_part(pivot, _sphere(r * 1.05), end_col, Vector3(0, -length + r * 1.6, 0))
	return pivot


## speed: السرعة الأفقية (م/ث) — on_floor: هل هو على الأرض
func animate(speed: float, delta: float, on_floor := true, sitting := false) -> void:
	_t += delta
	if sitting:
		l_leg.rotation.x = 1.4
		r_leg.rotation.x = 1.4
		l_arm.rotation.x = 0.7
		r_arm.rotation.x = 0.7
		return
	var amp: float = clamp(speed / 3.0, 0.0, 1.0)
	var run: float = clamp((speed - 3.5) / 3.0, 0.0, 1.0)
	phase += delta * (5.0 + speed * 1.6) * (1.0 if speed > 0.15 else 0.0)
	var s := sin(phase)
	var leg_a: float = (0.55 + run * 0.4) * amp
	var arm_a: float = (0.45 + run * 0.6) * amp
	var ll := s * leg_a
	var rl := -s * leg_a
	var la := -s * arm_a
	var ra := s * arm_a
	var bob: float = abs(cos(phase)) * 0.05 * amp
	var lean := run * 0.22
	if not on_floor:
		ll = 0.5
		rl = -0.35
		la = -2.4
		ra = -2.4
		bob = 0.0
	elif speed < 0.15:
		# تنفّس خفيف وهو واقف
		bob = sin(_t * 2.0) * 0.012
		la = sin(_t * 1.3) * 0.04
		ra = -la
	var k: float = min(1.0, delta * 14.0)
	l_leg.rotation.x = lerp(l_leg.rotation.x, ll, k)
	r_leg.rotation.x = lerp(r_leg.rotation.x, rl, k)
	if wave > 0.0:
		wave -= delta
		ra = 0.0
		r_arm.rotation.z = lerp(r_arm.rotation.z, 2.6 + sin(_t * 12.0) * 0.35, k)
	else:
		r_arm.rotation.z = lerp(r_arm.rotation.z, 0.06 + run * 0.1, k)
	l_arm.rotation.z = -0.06 - run * 0.1
	l_arm.rotation.x = lerp(l_arm.rotation.x, la, k)
	r_arm.rotation.x = lerp(r_arm.rotation.x, ra, k)
	torso.position.y = 0.92 + bob
	torso.rotation.x = lerp(torso.rotation.x, -lean, k)
	torso.rotation.y = s * 0.12 * amp
	head.rotation.y = -s * 0.08 * amp
