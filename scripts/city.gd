class_name City
extends Node3D
## يبني المدينة كاملة بالكود: شوارع، عمارات، حدائق، مسجد، برج، شاطئ، صحراء...

const N := 9
const CELL := 72.0
const HALF := 324.0
const ROAD_HALF := 7.0
const LOT := 25.0
const BOUND := 500.0
const SEA_Z := 400.0
const LANE := 3.4

enum { T_BUILD, T_PARK, T_PARKING, T_PLAZA, T_TOWER, T_MOSQUE, T_SHOWROOM, T_START }

const SPECIAL := {
	Vector2i(4, 4): T_TOWER, Vector2i(5, 5): T_START, Vector2i(2, 5): T_MOSQUE, Vector2i(6, 3): T_SHOWROOM,
	Vector2i(3, 4): T_PARK, Vector2i(1, 1): T_PARK, Vector2i(7, 6): T_PARK, Vector2i(4, 7): T_PARK, Vector2i(7, 0): T_PARK,
	Vector2i(5, 4): T_PARKING, Vector2i(2, 2): T_PARKING, Vector2i(6, 7): T_PARKING, Vector2i(1, 7): T_PARKING,
	Vector2i(3, 6): T_PLAZA, Vector2i(7, 2): T_PLAZA, Vector2i(0, 4): T_PLAZA,
}
const WALLS := ["e8dcc4", "d9c3a0", "f2ede4", "c9a27e", "b8c4cf", "9fb3c8", "e3b98f", "cfd6d9", "d4a373", "f0e2c0", "c7b299", "a9bcc4"]
const SIGNS := ["مطعم الواحة", "بقالة", "مقهى", "صيدلية", "مخبز", "حلويات", "مكتبة", "ملابس", "عصائر طازجة", "خضار وفواكه", "حلاق", "ألعاب", "بنك", "فندق", "مشاوي", "شاورما", "عطور", "جوالات"]

var rng := RandomNumberGenerator.new()
var parked_spots: Array = []     # {pos, yaw}
var free_stalls: Array = []      # {pos, yaw}
var showroom_spots: Array = []
var star_spots: Array = []
var park_centers: Array = []
var start_pos := Vector3.ZERO
var start_car := {}
var build_mat: ShaderMaterial
var water_mat: ShaderMaterial
var ground_mat: ShaderMaterial
var lamp_mat: StandardMaterial3D
var body: StaticBody3D

var _bx: Array = []   # box transforms
var _bc: Array = []   # colors
var _bd: Array = []   # custom
var _palms: Array = []
var _trees: Array = []
var _lamps: Array = []
var _props := MeshBuilder.new()
var _glow := MeshBuilder.new()
var _signs := 0


static func node_pos(i: int, j: int) -> Vector3:
	return Vector3(-HALF + i * CELL, 0, -HALF + j * CELL)


static func block_center(bx: int, bz: int) -> Vector3:
	return Vector3(-HALF + (bx + 0.5) * CELL, 0, -HALF + (bz + 0.5) * CELL)


static func block_type_at(b: Vector2i) -> int:
	return SPECIAL.get(b, T_BUILD)


## 0 = شارع، 1 = داخل المدينة، 2 = رمل
static func surface_at(p: Vector3) -> int:
	var gx := p.x + HALF
	var gz := p.z + HALF
	var dx: float = abs(gx - clamp(round(gx / CELL), 0, N) * CELL)
	var dz: float = abs(gz - clamp(round(gz / CELL), 0, N) * CELL)
	if (dx < ROAD_HALF and abs(p.z) < HALF + 7.0) or (dz < ROAD_HALF and abs(p.x) < HALF + 7.0):
		return 0
	if abs(p.x) < HALF + 11.0 and abs(p.z) < HALF + 11.0:
		return 1
	return 2


static func right_of(d: Vector3) -> Vector3:
	return Vector3(-d.z, 0, d.x)


## نقطة على مسار السير بين تقاطعين
static func lane_point(a: Vector2i, b: Vector2i, t: float) -> Dictionary:
	var pa := node_pos(a.x, a.y)
	var pb := node_pos(b.x, b.y)
	var d := (pb - pa).normalized()
	return {"pos": pa.lerp(pb, t) + right_of(d) * LANE, "dir": d, "a": a, "b": b}


static func neighbors(a: Vector2i) -> Array:
	var out := []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var b: Vector2i = a + d
		if b.x >= 0 and b.x <= N and b.y >= 0 and b.y <= N:
			out.append(b)
	return out


static func random_lane(r: RandomNumberGenerator) -> Dictionary:
	var a := Vector2i(r.randi_range(0, N), r.randi_range(0, N))
	var nb := neighbors(a)
	var b: Vector2i = nb[r.randi() % nb.size()]
	return lane_point(a, b, r.randf_range(0.25, 0.75))


static func random_sidewalk(r: RandomNumberGenerator) -> Vector3:
	var l := random_lane(r)
	return l["pos"] + right_of(l["dir"]) * (9.2 - LANE)


func build() -> void:
	rng.seed = 20240
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_ground()
	for bx in N:
		for bz in N:
			_block(bx, bz)
	_streets()
	_beach()
	_desert()
	_bounds()
	_finish()


func _col(shape: Shape3D, pos: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)


func _col_box(center: Vector3, size: Vector3, yaw := 0.0) -> void:
	var s := BoxShape3D.new()
	s.size = size
	_col(s, center, yaw)


func _col_cyl(pos: Vector3, r: float, h: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = r
	s.height = h
	_col(s, pos + Vector3(0, h / 2, 0))


func _add_box(center: Vector3, size: Vector3, color: Color, seed := -1.0, collide := false) -> void:
	_bx.append(Transform3D(Basis.from_scale(size), center))
	_bc.append(color)
	_bd.append(Color(size.x, size.y, size.z, seed))
	if collide:
		_col_box(center, size)


func _ground() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_R8)
	for bx in N:
		for bz in N:
			var t: int = block_type_at(Vector2i(bx, bz))
			img.set_pixel(bx, bz, Color(t / 255.0, 0, 0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	mat.set_shader_parameter("block_tex", ImageTexture.create_from_image(img))
	ground_mat = mat
	var pm := PlaneMesh.new()
	pm.size = Vector2(2600, 1300 + SEA_Z + 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(0, 0, (SEA_Z + 0.5 - 1300) / 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_col(WorldBoundaryShape3D.new(), Vector3.ZERO)
	# البحر
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var wm := PlaneMesh.new()
	wm.size = Vector2(2600, 1000)
	var wi := MeshInstance3D.new()
	wi.mesh = wm
	wi.material_override = water_mat
	wi.position = Vector3(0, 0.03, SEA_Z + 500)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)


func _wall_color() -> Color:
	var c := Color(WALLS[rng.randi() % WALLS.size()])
	return c.darkened(rng.randf() * 0.12)


func _building(c: Vector3, sx: float, h: float, sz: float, face: Vector2 = Vector2.ZERO) -> void:
	var col := _wall_color()
	var seed := rng.randf() * 50.0
	_add_box(Vector3(c.x, h / 2, c.z), Vector3(sx, h, sz), col, seed, true)
	var top := h
	if h > 26.0 and rng.randf() < 0.6:
		var h2 := h * rng.randf_range(0.2, 0.4)
		_add_box(Vector3(c.x, h + h2 / 2, c.z), Vector3(sx * 0.68, h2, sz * 0.68), col.lightened(0.06), seed + 1.0)
		top = h + h2
		if rng.randf() < 0.5:
			_add_box(Vector3(c.x, top + 4.0, c.z), Vector3(0.35, 8.0, 0.35), Color(0.7, 0.7, 0.72))
	else:
		# خزانات ومكيفات على السطح
		for i in rng.randi_range(1, 3):
			var o := Vector3(rng.randf_range(-sx * 0.3, sx * 0.3), 0, rng.randf_range(-sz * 0.3, sz * 0.3))
			var s := Vector3(rng.randf_range(1.2, 2.6), rng.randf_range(1.0, 2.2), rng.randf_range(1.2, 2.6))
			_add_box(Vector3(c.x, h + s.y / 2, c.z) + o, s, Color(0.82, 0.82, 0.8) if rng.randf() < 0.6 else Color(0.35, 0.4, 0.46))
	# حافة السطح
	_add_box(Vector3(c.x, h + 0.25, c.z), Vector3(sx + 0.5, 0.5, sz + 0.5), col.darkened(0.25))
	if face != Vector2.ZERO and _signs < 60 and rng.randf() < 0.75:
		_sign(c, sx, sz, face, SIGNS[rng.randi() % SIGNS.size()])


func _sign(c: Vector3, sx: float, sz: float, face: Vector2, text: String, y := 4.15, size := 1.0) -> void:
	_signs += 1
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_bold
	l.font_size = 72
	l.pixel_size = 0.0125 * size
	l.outline_size = 0
	l.modulate = Color(1, 0.97, 0.85)
	l.visibility_range_end = 110.0
	l.double_sided = false
	var w: float = (text.length() * 0.55 + 1.2) * size
	var bcol := Color.from_hsv(rng.randf(), 0.65, 0.45)
	if abs(face.x) > 0.5:
		l.position = Vector3(c.x + face.x * (sx / 2 + 0.22), y, c.z)
		l.rotation.y = PI / 2 * face.x
		_add_box(Vector3(c.x + face.x * (sx / 2 + 0.08), y, c.z), Vector3(0.2, 1.3 * size, w), bcol)
	else:
		l.position = Vector3(c.x, y, c.z + face.y * (sz / 2 + 0.22))
		l.rotation.y = 0.0 if face.y > 0 else PI
		_add_box(Vector3(c.x, y, c.z + face.y * (sz / 2 + 0.08)), Vector3(w, 1.3 * size, 0.2), bcol)
	add_child(l)


func _block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var t := block_type_at(Vector2i(bx, bz))
	match t:
		T_BUILD:
			_block_buildings(bx, bz, c)
		T_PARK:
			_block_park(c)
		T_PARKING:
			_block_parking(c)
		T_PLAZA, T_START:
			_block_plaza(c, t == T_START)
		T_TOWER:
			_block_tower(c)
		T_MOSQUE:
			_block_mosque(c)
		T_SHOWROOM:
			_block_showroom(c)


func _block_buildings(bx: int, bz: int, c: Vector3) -> void:
	var dist: int = max(abs(bx - 4), abs(bz - 4))
	var hmax: float = [72.0, 56.0, 36.0, 22.0, 14.0][dist]
	var hmin: float = [34.0, 22.0, 12.0, 8.0, 6.5][dist]
	var layout := rng.randi() % 4
	if layout <= 1:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var w := rng.randf_range(19.0, 23.0)
				var d := rng.randf_range(19.0, 23.0)
				var face := Vector2(sx, 0) if rng.randf() < 0.5 else Vector2(0, sz)
				_building(c + Vector3(sx * (LOT - w / 2), 0, sz * (LOT - d / 2)), w, rng.randf_range(hmin, hmax), d, face)
		if rng.randf() < 0.6:
			star_spots.append(c + Vector3(0, 1.2, 0))
	elif layout == 2:
		var along_x := rng.randf() < 0.5
		for s in [-1.0, 1.0]:
			var d := rng.randf_range(19.0, 22.0)
			if along_x:
				_building(c + Vector3(0, 0, s * (LOT - d / 2)), 50.0, rng.randf_range(hmin, hmax * 0.8), d, Vector2(0, s))
			else:
				_building(c + Vector3(s * (LOT - d / 2), 0, 0), d, rng.randf_range(hmin, hmax * 0.8), 50.0, Vector2(s, 0))
	else:
		var col := _wall_color()
		var seed := rng.randf() * 50.0
		var hb := rng.randf_range(7.0, 10.0)
		_add_box(Vector3(c.x, hb / 2, c.z), Vector3(48, hb, 48), col, seed, true)
		_add_box(Vector3(c.x, hb + 0.25, c.z), Vector3(48.5, 0.5, 48.5), col.darkened(0.25))
		var ht := rng.randf_range(hmin, hmax)
		var o := Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		_add_box(Vector3(c.x, hb + ht / 2, c.z) + o, Vector3(24, ht, 24), col.lightened(0.08), seed + 3.0)
		_sign(c, 48, 48, Vector2(0, 1), "مركز تسوق" if rng.randf() < 0.5 else "سوق المدينة", 5.2, 1.6)


func _tree(p: Vector3, s := 1.0, collide := true) -> void:
	_trees.append([p, s])
	if collide:
		_col_cyl(p, 0.3, 3.0)


func _palm(p: Vector3, s := 1.0, collide := true) -> void:
	_palms.append([p, s])
	if collide:
		_col_cyl(p, 0.3, 4.0)


func _bench(p: Vector3, yaw: float) -> void:
	_props.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var wood := Color(0.5, 0.32, 0.18)
	_props.box(Vector3(0, 0.45, 0), Vector3(1.8, 0.1, 0.5), wood)
	_props.box(Vector3(0, 0.8, -0.24), Vector3(1.8, 0.5, 0.08), wood)
	_props.box(Vector3(-0.8, 0.22, 0), Vector3(0.1, 0.45, 0.45), Color(0.2, 0.2, 0.22))
	_props.box(Vector3(0.8, 0.22, 0), Vector3(0.1, 0.45, 0.45), Color(0.2, 0.2, 0.22))
	_props.xf = Transform3D.IDENTITY


func _fountain(c: Vector3) -> void:
	var stone := Color(0.8, 0.77, 0.7)
	_props.cyl(c, c + Vector3(0, 0.7, 0), 4.0, 4.0, 14, stone)
	_props.cyl(c + Vector3(0, 0.7, 0), c + Vector3(0, 0.72, 0), 3.6, 3.6, 14, Color(0.2, 0.6, 0.8))
	_props.cyl(c + Vector3(0, 0.7, 0), c + Vector3(0, 2.2, 0), 0.5, 0.35, 8, stone)
	_props.cyl(c + Vector3(0, 2.2, 0), c + Vector3(0, 2.5, 0), 1.6, 1.8, 10, stone)
	_props.cyl(c + Vector3(0, 2.5, 0), c + Vector3(0, 2.52, 0), 1.6, 1.6, 10, Color(0.25, 0.65, 0.85))
	_props.cyl(c + Vector3(0, 2.5, 0), c + Vector3(0, 3.4, 0), 0.22, 0.1, 6, stone)
	_col_cyl(c, 4.0, 1.0)


func _block_park(c: Vector3) -> void:
	park_centers.append(c)
	_fountain(c)
	for i in 4:
		var a := PI / 4 + i * PI / 2
		_bench(c + Vector3(cos(a), 0, sin(a)) * 7.0, -a + PI / 2 + PI)
	var n := 0
	while n < 16:
		var o := Vector3(rng.randf_range(-22, 22), 0, rng.randf_range(-22, 22))
		if min(abs(o.x), abs(o.z)) < 3.2 or o.length() < 12.0:
			continue
		if rng.randf() < 0.25:
			_palm(c + o, rng.randf_range(0.8, 1.1))
		else:
			_tree(c + o, rng.randf_range(0.8, 1.4))
		n += 1
	# ورود
	for i in 14:
		var o := Vector3(rng.randf_range(-23, 23), 0, rng.randf_range(-23, 23))
		if min(abs(o.x), abs(o.z)) < 2.5 or o.length() < 6.0:
			continue
		_props.sphere(c + o + Vector3(0, 0.3, 0), 0.6, Color.from_hsv(rng.randf(), 0.7, 0.9), 3, 6, Vector3(1, 0.6, 1), Color(0.15, 0.4, 0.12))
	star_spots.append(c + Vector3(18, 1.2, -18))
	star_spots.append(c + Vector3(-17, 1.2, 15))


func _block_parking(c: Vector3) -> void:
	for row in [-18.25, -6.75, 6.75, 18.25]:
		for i in range(-7, 8):
			var p := c + Vector3(i * 3.0, 0, row)
			var yaw := 0.0 if (row < -10 or (row > 0 and row < 10)) else PI
			var e := {"pos": p, "yaw": yaw}
			if rng.randf() < 0.24:
				parked_spots.append(e)
			elif abs(i) < 6:
				free_stalls.append(e)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_lamps.append([c + Vector3(sx * 24, 0, sz * 24), 0.0 if sx < 0 else PI])
	star_spots.append(c + Vector3(0, 1.2, 0))


func _kiosk(p: Vector3, yaw: float) -> void:
	_props.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var col := Color.from_hsv(rng.randf(), 0.55, 0.85)
	_props.box(Vector3(0, 1.3, 0), Vector3(3.6, 2.6, 3.0), Color(0.9, 0.88, 0.8))
	_props.box(Vector3(0, 1.5, 1.52), Vector3(2.8, 1.0, 0.06), Color(0.1, 0.15, 0.2))
	_props.box(Vector3(0, 2.75, 0.5), Vector3(4.2, 0.18, 4.4), col, Basis(Vector3.RIGHT, 0.15))
	_props.box(Vector3(0, 0.95, 1.7), Vector3(3.0, 0.1, 0.5), Color(0.5, 0.32, 0.18))
	_props.xf = Transform3D.IDENTITY
	_col_box(p + Vector3(0, 1.3, 0), Vector3(3.6, 2.6, 3.0), yaw)


func _block_plaza(c: Vector3, is_start: bool) -> void:
	for i in 8:
		var a := i * TAU / 8 + 0.4
		_palm(c + Vector3(cos(a), 0, sin(a)) * 19.0, rng.randf_range(0.9, 1.15))
	for i in 4:
		var a := i * PI / 2
		_bench(c + Vector3(cos(a), 0, sin(a)) * 11.0, -a + PI / 2 + PI)
	if is_start:
		start_pos = c + Vector3(0, 0.1, 6)
		start_car = {"pos": c + Vector3(6, 0, 0), "yaw": 0.0}
		_kiosk(c + Vector3(-14, 0, -14), 0.6)
		star_spots.append(c + Vector3(-8, 1.2, 14))
	else:
		_fountain(c)
		_kiosk(c + Vector3(15, 0, -15), -0.7)
		_kiosk(c + Vector3(-15, 0, 15), 2.4)
		star_spots.append(c + Vector3(16, 1.2, 16))


func _block_tower(c: Vector3) -> void:
	var glass := Color(0.75, 0.82, 0.88)
	_add_box(c + Vector3(0, 6, 0), Vector3(34, 12, 34), Color(0.85, 0.83, 0.78), 0.1, true)
	_add_box(c + Vector3(0, 12 + 45, 0), Vector3(22, 90, 22), glass, 0.1)
	_add_box(c + Vector3(0, 102 + 12, 0), Vector3(15, 24, 15), glass.lightened(0.1), 0.1)
	_add_box(c + Vector3(0, 126 + 5, 0), Vector3(8, 10, 8), glass, 0.1)
	_props.cyl(c + Vector3(0, 136, 0), c + Vector3(0, 166, 0), 1.2, 0.05, 6, Color(0.8, 0.8, 0.85))
	_glow.sphere(c + Vector3(0, 166, 0), 0.9, Color(1, 0.2, 0.15), 3, 6)
	_sign(c, 34, 34, Vector2(0, 1), "برج النخيل", 9.0, 2.2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_palm(c + Vector3(sx * 21.5, 0, sz * 21.5), 1.2)
	star_spots.append(c + Vector3(0, 1.2, 21))


func _block_mosque(c: Vector3) -> void:
	var cream := Color(0.93, 0.89, 0.78)
	var teal := Color(0.1, 0.5, 0.52)
	var gold := Color(0.85, 0.68, 0.22)
	var m := _props
	m.box(c + Vector3(0, 4.5, -4), Vector3(26, 9, 24), cream)
	m.box(c + Vector3(0, 9.3, -4), Vector3(27, 0.6, 25), teal)
	m.cyl(c + Vector3(0, 9, -4), c + Vector3(0, 11.5, -4), 7.2, 7.2, 12, cream)
	m.sphere(c + Vector3(0, 11.5, -4), 7.0, teal, 5, 12, Vector3(1, 1.05, 1), teal.darkened(0.25))
	m.cyl(c + Vector3(0, 18.6, -4), c + Vector3(0, 21.0, -4), 0.18, 0.05, 5, gold)
	# المدخل والنوافذ
	m.box(c + Vector3(0, 3.0, 8.05), Vector3(4.0, 6.0, 0.3), Color(0.35, 0.22, 0.12))
	m.cyl(c + Vector3(0, 6.0, 8.05), c + Vector3(0, 6.0, 8.2), 2.0, 2.0, 10, Color(0.35, 0.22, 0.12))
	for i in [-2, -1, 1, 2]:
		m.box(c + Vector3(i * 4.6, 4.2, 8.03), Vector3(1.6, 3.6, 0.2), teal.darkened(0.4))
		m.box(c + Vector3(13.03, 4.2, -4 + i * 4.6), Vector3(0.2, 3.6, 1.6), teal.darkened(0.4))
		m.box(c + Vector3(-13.03, 4.2, -4 + i * 4.6), Vector3(0.2, 3.6, 1.6), teal.darkened(0.4))
	_col_box(c + Vector3(0, 4.5, -4), Vector3(26, 9, 24))
	for sx in [-1.0, 1.0]:
		var b := c + Vector3(sx * 15.5, 0, 9.5)
		m.cyl(b, b + Vector3(0, 20, 0), 1.5, 1.2, 8, cream)
		m.cyl(b + Vector3(0, 20, 0), b + Vector3(0, 20.8, 0), 2.1, 2.1, 8, teal)
		m.cyl(b + Vector3(0, 20.8, 0), b + Vector3(0, 25, 0), 1.0, 1.0, 8, cream)
		m.cyl(b + Vector3(0, 25, 0), b + Vector3(0, 30, 0), 1.3, 0.05, 8, teal)
		m.cyl(b + Vector3(0, 30, 0), b + Vector3(0, 31.5, 0), 0.12, 0.04, 5, gold)
		_glow.cyl(b + Vector3(0, 21.2, 0), b + Vector3(0, 22.2, 0), 1.03, 1.03, 8, Color(0.5, 1.0, 0.6), false)
		_col_cyl(b, 1.5, 20)
	for i in 5:
		_palm(c + Vector3(-22 + i * 11, 0, 20), 1.0)
	star_spots.append(c + Vector3(0, 1.2, -21))


func _block_showroom(c: Vector3) -> void:
	_add_box(c + Vector3(0, 4, -12), Vector3(44, 8, 20), Color(0.9, 0.9, 0.92), 0.1, true)
	_add_box(c + Vector3(0, 8.3, -12), Vector3(45, 0.6, 21), Color(0.75, 0.1, 0.1))
	_sign(c + Vector3(0, 0, -12), 44, 20, Vector2(0, 1), "معرض السيارات", 6.2, 2.0)
	for i in 3:
		var p := c + Vector3((i - 1) * 11.0, 0, 9)
		showroom_spots.append({"pos": p, "yaw": PI})
		_props.cyl(p, p + Vector3(0, 0.02, 0), 4.2, 4.2, 16, Color(0.75, 0.1, 0.1))
	for sx in [-1.0, 1.0]:
		_palm(c + Vector3(sx * 22, 0, 20), 1.1)
		_lamps.append([c + Vector3(sx * 16, 0, 18), 0.0 if sx < 0 else PI])


func _streets() -> void:
	for i in N + 1:
		for j in N:
			var mid := (j + 0.5) * CELL - HALF
			var line := i * CELL - HALF
			# شوارع عمودية (على محور z)
			_lamps.append([Vector3(line + 8.3, 0, mid + 15), PI])
			_lamps.append([Vector3(line - 8.3, 0, mid - 15), 0.0])
			# شوارع أفقية
			_lamps.append([Vector3(mid + 15, 0, line + 8.3), PI / 2])
			_lamps.append([Vector3(mid - 15, 0, line - 8.3), -PI / 2])
			# نخيل على الشوارع الرئيسية والكورنيش
			if i == 4 or i == 5:
				for k in range(-2, 3):
					if k == 0:
						continue
					_palm(Vector3(line + 9.7, 0, mid + k * 9.0), rng.randf_range(0.85, 1.05), false)
					_palm(Vector3(line - 9.7, 0, mid + k * 9.0), rng.randf_range(0.85, 1.05), false)
			if i == N:
				for k in range(-2, 3):
					_palm(Vector3(mid + k * 11.0, 0, line + 9.7), rng.randf_range(0.9, 1.15), false)
	for i in 26:
		star_spots.append(random_sidewalk(rng) + Vector3(0, 1.2, 0))


func _umbrella(p: Vector3, col: Color) -> void:
	_props.cyl(p, p + Vector3(0, 2.4, 0), 0.05, 0.05, 5, Color(0.9, 0.9, 0.9))
	_props.cyl(p + Vector3(0, 2.1, 0), p + Vector3(0, 2.8, 0), 2.0, 0.05, 8, col)
	_props.box(p + Vector3(1.2, 0.3, 0.4), Vector3(0.7, 0.12, 1.9), Color(0.95, 0.95, 0.9))
	_props.box(p + Vector3(-1.2, 0.3, 0.4), Vector3(0.7, 0.12, 1.9), Color(0.95, 0.95, 0.9))


func _beach() -> void:
	for i in 34:
		var p := Vector3(rng.randf_range(-440, 440), 0, rng.randf_range(346, 388))
		if abs(p.x - 100.0) < 8.0:
			continue
		if rng.randf() < 0.45:
			_palm(p, rng.randf_range(0.9, 1.3))
		else:
			_umbrella(p, Color.from_hsv(rng.randf(), 0.7, 0.95))
	# الرصيف البحري
	var wood := Color(0.52, 0.36, 0.2)
	_props.box(Vector3(100, -0.03, 440), Vector3(7, 0.2, 100), wood)
	for k in 11:
		var z := 392.0 + k * 9.6
		for sx in [-1.0, 1.0]:
			_props.cyl(Vector3(100 + sx * 3.4, -1, z), Vector3(100 + sx * 3.4, 1.1, z), 0.14, 0.14, 5, wood.darkened(0.3))
	for sx in [-1.0, 1.0]:
		_props.box(Vector3(100 + sx * 3.4, 1.0, 444), Vector3(0.1, 0.1, 92), wood.darkened(0.2))
		_col_box(Vector3(100 + sx * 3.9, 1, 445), Vector3(0.6, 2, 94))
	_col_box(Vector3(100, 1, 490.5), Vector3(9, 2, 0.6))
	_lamps.append([Vector3(96.8, 0, 488), 0.0])
	star_spots.append(Vector3(100, 1.2, 484))
	# المنارة
	var lp := Vector3(-380, 0, 384)
	for k in 5:
		var r0 := 3.2 - k * 0.35
		_props.cyl(lp + Vector3(0, k * 5.0, 0), lp + Vector3(0, k * 5.0 + 5.0, 0), r0, r0 - 0.35, 10, Color(0.95, 0.95, 0.92) if k % 2 == 0 else Color(0.8, 0.15, 0.12), false)
	_props.cyl(lp + Vector3(0, 25, 0), lp + Vector3(0, 25.5, 0), 2.4, 2.4, 10, Color(0.25, 0.25, 0.28))
	_glow.cyl(lp + Vector3(0, 25.5, 0), lp + Vector3(0, 27.5, 0), 1.2, 1.2, 8, Color(1, 0.95, 0.6))
	_props.cyl(lp + Vector3(0, 27.5, 0), lp + Vector3(0, 29.5, 0), 1.8, 0.05, 10, Color(0.8, 0.15, 0.12))
	_col_cyl(lp, 3.2, 12)
	star_spots.append(lp + Vector3(0, 1.2, -6))
	star_spots.append(Vector3(300, 1.2, 380))
	star_spots.append(Vector3(-150, 1.2, 372))


func _camel(p: Vector3, yaw: float) -> void:
	var m := _props
	m.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var c := Color(0.76, 0.58, 0.36)
	var d := c.darkened(0.2)
	m.sphere(Vector3(0, 1.75, 0), 1.0, c, 4, 7, Vector3(0.55, 0.6, 1.15), d)
	m.sphere(Vector3(0, 2.3, 0.1), 0.5, c, 3, 6, Vector3(0.8, 1.0, 1.0))
	m.cyl(Vector3(0, 1.9, -0.95), Vector3(0, 2.95, -1.45), 0.26, 0.18, 6, c)
	m.sphere(Vector3(0, 3.0, -1.7), 0.3, c, 3, 6, Vector3(0.75, 0.75, 1.4))
	for sx in [-0.3, 0.3]:
		for sz in [-0.75, 0.75]:
			m.cyl(Vector3(sx, 1.45, sz), Vector3(sx, 0, sz), 0.15, 0.1, 5, d)
	m.cyl(Vector3(0, 1.8, 1.1), Vector3(0, 1.1, 1.35), 0.05, 0.03, 4, d)
	m.xf = Transform3D.IDENTITY
	_col_cyl(p, 0.9, 2.5)


func _tent(p: Vector3, yaw: float) -> void:
	var m := _props
	m.xf = Transform3D(Basis(Vector3.UP, yaw), p)
	var prof := [Vector2(-3.5, 0), Vector2(-2.6, 2.0), Vector2(0, 3.0), Vector2(2.6, 2.0), Vector2(3.5, 0)]
	for k in 6:
		var x0 := -4.5 + k * 1.5
		m.extrude(prof, x0, x0 + 1.5, Color(0.92, 0.9, 0.85) if k % 2 == 0 else Color(0.25, 0.2, 0.18))
	m.box(Vector3(4.56, 1.1, 0), Vector3(0.1, 2.2, 1.8), Color(0.6, 0.12, 0.1))
	m.xf = Transform3D.IDENTITY
	_col_box(p + Vector3(0, 1.2, 0), Vector3(9, 2.4, 6), yaw)


func _desert() -> void:
	# الواحة
	var o := Vector3(-410, 0, -400)
	_props.cyl(o, o + Vector3(0, 0.05, 0), 13, 13, 18, Color(0.15, 0.55, 0.7))
	_props.cyl(o + Vector3(0, -0.02, 0), o + Vector3(0, 0.03, 0), 15, 15, 18, Color(0.35, 0.5, 0.2))
	for i in 16:
		var a := rng.randf() * TAU
		_palm(o + Vector3(cos(a), 0, sin(a)) * rng.randf_range(15, 30), rng.randf_range(0.9, 1.4))
	_tent(o + Vector3(34, 0, 10), 0.4)
	_tent(o + Vector3(30, 0, -18), -0.5)
	_camel(o + Vector3(22, 0, 26), 1.0)
	_camel(o + Vector3(18, 0, 31), 2.2)
	_camel(Vector3(420, 0, -250), -0.6)
	star_spots.append(o + Vector3(0, 1.2, 18))
	star_spots.append(o + Vector3(40, 1.2, -4))
	# صخور ونخيل متفرق
	for i in 70:
		var p := Vector3(rng.randf_range(-490, 490), 0, rng.randf_range(-490, 330))
		if surface_at(p) != 2 or abs(p.x) < HALF + 25 and abs(p.z) < HALF + 25:
			continue
		if rng.randf() < 0.3:
			_palm(p, rng.randf_range(0.8, 1.3))
		else:
			var r := rng.randf_range(1.0, 3.5)
			_props.sphere(p + Vector3(0, r * 0.2, 0), r, Color(0.55, 0.45, 0.35).darkened(rng.randf() * 0.3), 3, 5, Vector3(1, 0.6, rng.randf_range(0.7, 1.3)))
			_col_cyl(p, r * 0.8, r * 0.7)
	star_spots.append(Vector3(430, 1.2, -420))
	star_spots.append(Vector3(440, 1.2, 100))
	star_spots.append(Vector3(-440, 1.2, 60))
	star_spots.append(Vector3(0, 1.2, -450))
	# الجبال البعيدة
	var mb := MeshBuilder.new()
	for i in 46:
		var a := PI + rng.randf_range(-0.12, PI + 0.12)
		var r := rng.randf_range(680, 1050)
		var p := Vector3(cos(a) * r, -5, sin(a) * r * 0.9 - 60)
		var h := rng.randf_range(70, 210)
		var w := h * rng.randf_range(1.1, 1.9)
		var c := Color(0.62, 0.46, 0.33).lerp(Color(0.45, 0.36, 0.34), rng.randf())
		mb.cyl(p, p + Vector3(rng.randf_range(-20, 20), h, 0), w, 0.5, 7, c, false)
	for i in 4:
		var p := Vector3(rng.randf_range(-700, 700), -3, rng.randf_range(650, 900))
		mb.cyl(p, p + Vector3(0, rng.randf_range(20, 45), 0), rng.randf_range(50, 110), 1.0, 7, Color(0.45, 0.5, 0.3), false)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit(MeshBuilder.vc_material(1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _bounds() -> void:
	_col_box(Vector3(-BOUND - 5, 10, 0), Vector3(10, 40, 1200))
	_col_box(Vector3(BOUND + 5, 10, 0), Vector3(10, 40, 1200))
	_col_box(Vector3(0, 10, -BOUND - 5), Vector3(1200, 40, 10))
	# حاجز البحر مع فتحة للرصيف البحري
	_col_box(Vector3(-203.5 - 100, 10, 399), Vector3(800 - 7, 40, 4))
	_col_box(Vector3(103.5 + 300, 10, 399), Vector3(600, 40, 4))


func _multi(mesh: Mesh, xfs: Array, colors = null, customs = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors != null
	mm.use_custom_data = customs != null
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		if colors != null:
			mm.set_instance_color(i, colors[i])
		if customs != null:
			mm.set_instance_custom_data(i, customs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


func _palm_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var h := 7.0
	for i in 5:
		var t0 := i / 5.0
		var t1 := (i + 1) / 5.0
		var a := Vector3(sin(t0 * 1.2) * 0.7, t0 * h, 0)
		var b := Vector3(sin(t1 * 1.2) * 0.7, t1 * h, 0)
		mb.cyl(a, b, lerp(0.3, 0.17, t0), lerp(0.3, 0.17, t1), 6, Color(0.42, 0.3, 0.18) if i % 2 == 0 else Color(0.36, 0.25, 0.15), false)
	var top := Vector3(sin(1.2) * 0.7, h, 0)
	for k in 10:
		var ang := TAU * k / 10.0 + (0.3 if k % 2 == 0 else 0.0)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := dir.cross(Vector3.UP)
		var lift := 1.3 if k % 2 == 0 else 0.7
		var prev := top
		var pw := 0.2
		for s in 5:
			var u := (s + 1) / 5.0
			var pt := top + dir * (u * 3.4) + Vector3.UP * (sin(u * PI * 0.7) * lift - u * u * 2.1)
			var w: float = lerp(0.6, 0.04, u)
			var g := Color(0.16, 0.5, 0.14).lerp(Color(0.32, 0.62, 0.16), u)
			if k % 2 == 1:
				g = g.darkened(0.15)
			var mid := (prev + pt) * 0.5
			mb.quad(prev - side * pw, prev + side * pw, pt + side * w, pt - side * w, g, mid - Vector3.UP)
			prev = pt
			pw = w
	mb.sphere(top - Vector3(0, 0.3, 0), 0.38, Color(0.35, 0.22, 0.1), 3, 5)
	return mb.commit(MeshBuilder.vc_material(1.0, 0.0, true))


func _tree_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.cyl(Vector3.ZERO, Vector3(0, 2.4, 0), 0.26, 0.18, 6, Color(0.36, 0.24, 0.14), false)
	var g := Color(0.2, 0.52, 0.16)
	mb.sphere(Vector3(0, 3.6, 0), 1.9, g.lightened(0.1), 4, 7, Vector3(1, 0.85, 1), g.darkened(0.3))
	mb.sphere(Vector3(1.0, 3.0, 0.5), 1.3, g, 3, 6, Vector3(1, 0.8, 1), g.darkened(0.3))
	mb.sphere(Vector3(-0.9, 3.1, -0.6), 1.35, g.lightened(0.04), 3, 6, Vector3(1, 0.8, 1), g.darkened(0.3))
	return mb.commit(MeshBuilder.vc_material(1.0))


func _finish() -> void:
	# العمارات
	build_mat = ShaderMaterial.new()
	build_mat.shader = load("res://shaders/building.gdshader")
	var bm := BoxMesh.new()
	bm.material = build_mat
	_multi(bm, _bx, _bc, _bd)
	# الأشجار والنخيل
	var xf: Array = []
	var cl: Array = []
	for e in _palms:
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * e[1]), e[0]))
		cl.append(Color(1, 1, 1).darkened(rng.randf() * 0.2))
	_multi(_palm_mesh(), xf, cl)
	xf = []
	cl = []
	for e in _trees:
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * e[1]), e[0]))
		cl.append(Color.from_hsv(rng.randf_range(0.0, 0.12), rng.randf_range(0.0, 0.25), rng.randf_range(0.8, 1.0)))
	_multi(_tree_mesh(), xf, cl)
	# أعمدة الإنارة
	var lm := MeshBuilder.new()
	var grey := Color(0.25, 0.27, 0.3)
	lm.cyl(Vector3.ZERO, Vector3(0, 7, 0), 0.13, 0.08, 6, grey, false)
	lm.box(Vector3(0.8, 6.95, 0), Vector3(1.8, 0.1, 0.12), grey)
	lm.box(Vector3(1.5, 6.9, 0), Vector3(0.9, 0.16, 0.4), grey)
	xf = []
	var hx: Array = []
	for e in _lamps:
		var t := Transform3D(Basis(Vector3.UP, e[1]), e[0])
		xf.append(t)
		hx.append(t * Transform3D(Basis.IDENTITY, Vector3(1.5, 6.79, 0)))
	var lmi := _multi(lm.commit(MeshBuilder.vc_material(0.6, 0.3)), xf)
	lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp_mat = MeshBuilder.emissive(Color(1.0, 0.86, 0.6), 0.0)
	var hb := BoxMesh.new()
	hb.size = Vector3(0.8, 0.08, 0.32)
	hb.material = lamp_mat
	var hmi := _multi(hb, hx)
	hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# بقية المجسمات
	var pi := MeshInstance3D.new()
	pi.mesh = _props.commit(MeshBuilder.vc_material(0.85))
	add_child(pi)
	var gi := MeshInstance3D.new()
	var gm := MeshBuilder.vc_material(0.5)
	gm.emission_enabled = true
	gm.emission = Color(1, 0.9, 0.7)
	gm.emission_energy_multiplier = 1.2
	gm.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	gi.mesh = _glow.commit(gm)
	add_child(gi)
	_bx.clear(); _bc.clear(); _bd.clear()


func set_night(n: float) -> void:
	build_mat.set_shader_parameter("night", n)
	water_mat.set_shader_parameter("night", n)
	ground_mat.set_shader_parameter("night", n)
	lamp_mat.emission_energy_multiplier = n * 3.5
	lamp_mat.albedo_color = Color(0.5, 0.5, 0.5).lerp(Color(1.0, 0.86, 0.6), n)
