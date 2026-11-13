class_name Builder
extends RefCounted
## يبني هندسة المرحلة: صناديق وأسطوانات ودرج مع إحداثيات خامة حقيقية وتصادم،
## ويجمع كل منطقة + خامة في مجسم واحد لتخفيف الرسم.

const FACES := [
	[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],
	[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
	[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],
	[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
]

var zone := "main"
var root: Node3D
var _surf := {}      # "zone|mat" -> {v, n, uv, c, t}
var _bodies := {}    # zone -> StaticBody3D
var _shapes := {}
var lights: Array = []


func _init(parent: Node3D) -> void:
	root = parent


func _s(mat: String) -> Dictionary:
	var k := zone + "|" + mat
	if not _surf.has(k):
		_surf[k] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "t": PackedFloat32Array()}
	return _surf[k]


func _body() -> StaticBody3D:
	if not _bodies.has(zone):
		var b := StaticBody3D.new()
		b.name = "col_" + zone
		b.collision_layer = 1
		b.collision_mask = 0
		root.add_child(b)
		_bodies[zone] = b
	return _bodies[zone]


func collider(center: Vector3, size: Vector3, basis := Basis.IDENTITY, layer := 1) -> CollisionShape3D:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _shapes.has(key):
		var bs := BoxShape3D.new()
		bs.size = size
		_shapes[key] = bs
	var cs := CollisionShape3D.new()
	cs.shape = _shapes[key]
	cs.transform = Transform3D(basis, center)
	if layer == 1:
		_body().add_child(cs)
	else:
		var b := StaticBody3D.new()
		b.collision_layer = layer
		b.collision_mask = 0
		root.add_child(b)
		b.add_child(cs)
	return cs


func _quad(s: Dictionary, p: Array, n: Vector3, u: Vector3, uvs: Array, cols: Array) -> void:
	for i in [0, 2, 1, 0, 3, 2]:
		s["v"].append(p[i])
		s["n"].append(n)
		s["uv"].append(uvs[i])
		s["c"].append(cols[i])
		s["t"].append(u.x); s["t"].append(u.y); s["t"].append(u.z); s["t"].append(1.0)


## صندوق. ao: تدرّج تظليل عمودي للجدران. tint: لون ضرب.
func box(center: Vector3, size: Vector3, mat: String, collide := true, ao := false, basis := Basis.IDENTITY, tint := Color.WHITE, uv_scale := 1.0) -> void:
	var s := _s(mat)
	var h := size * 0.5
	var us := Mats.uv_size(mat) * uv_scale
	for f in FACES:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hn: float = abs(n.dot(h))
		var hu: float = abs(u.dot(h))
		var hv: float = abs(v.dot(h))
		var p := []
		var uvs := []
		var cols := []
		for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			var lp: Vector3 = n * hn + u * hu * k[0] + v * hv * k[1]
			var wp: Vector3 = center + basis * lp
			p.append(wp)
			var ref: Vector3 = wp if basis == Basis.IDENTITY else center + lp
			uvs.append(Vector2(ref.dot(u), -ref.dot(v)) / us)
			var c := tint
			if ao:
				if n.y == 0.0:
					c = tint * (0.62 if k[1] < 0 else 0.92)
				elif n.y < 0.0:
					c = tint * 0.8
				c.a = 1.0
			cols.append(c)
		_quad(s, p, basis * n, basis * u, uvs, cols)
	if collide:
		collider(center, size, basis)


func box2(a: Vector3, b: Vector3, mat: String, collide := true, ao := false, tint := Color.WHITE) -> void:
	box((a + b) * 0.5, (b - a).abs(), mat, collide, ao, Basis.IDENTITY, tint)


## أسطوانة/عمود بين نقطتين
func cyl(p0: Vector3, p1: Vector3, r: float, mat: String, sides := 12, collide := true, tint := Color.WHITE, r1 := -1.0) -> void:
	if r1 < 0.0:
		r1 = r
	var s := _s(mat)
	var axis := (p1 - p0).normalized()
	var ux := axis.cross(Vector3.UP if abs(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var vx := axis.cross(ux).normalized()
	var us := Mats.uv_size(mat)
	var length := p0.distance_to(p1)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := ux * cos(a0) + vx * sin(a0)
		var d1 := ux * cos(a1) + vx * sin(a1)
		var n := (d0 + d1).normalized()
		var tan := (d1 - d0).normalized()
		var pts := [p0 + d0 * r, p0 + d1 * r, p1 + d1 * r1, p1 + d0 * r1]
		var c0 := tint * 0.7
		c0.a = 1.0
		var uvs := [Vector2(a0 * r / us, 0), Vector2(a1 * r / us, 0), Vector2(a1 * r / us, -length / us), Vector2(a0 * r / us, -length / us)]
		# ترتيب الرؤوس ليكون الوجه للخارج
		var fn: Vector3 = (pts[1] - pts[0]).cross(pts[3] - pts[0])
		if fn.dot(n) > 0.0:
			_quad(s, pts, n, tan, uvs, [c0, c0, tint, tint])
		else:
			_quad(s, [pts[1], pts[0], pts[3], pts[2]], n, -tan, [uvs[1], uvs[0], uvs[3], uvs[2]], [c0, c0, tint, tint])
		# الأغطية
		for cap in [[p0, d0 * r, d1 * r, -axis], [p1, d0 * r1, d1 * r1, axis]]:
			var cc: Vector3 = cap[0]
			var tri := [cc, cc + cap[1], cc + cap[2]]
			var cn: Vector3 = cap[3]
			if (tri[1] - tri[0]).cross(tri[2] - tri[0]).dot(cn) > 0.0:
				tri = [cc, cc + cap[2], cc + cap[1]]
			for q in tri:
				s["v"].append(q)
				s["n"].append(cn)
				s["uv"].append(Vector2(q.dot(ux), q.dot(vx)) / us)
				s["c"].append(tint)
				s["t"].append(ux.x); s["t"].append(ux.y); s["t"].append(ux.z); s["t"].append(1.0)
	if collide:
		var mid := (p0 + p1) * 0.5
		var rr: float = max(r, r1)
		if abs(axis.y) > 0.9:
			collider(mid, Vector3(rr * 1.7, length, rr * 1.7))
		else:
			var b := Basis(ux, axis, vx)
			collider(mid, Vector3(rr * 1.7, length, rr * 1.7), b)


## درج مستقيم: يبدأ من bottom (وسط الحافة السفلى) ويصعد باتجاه dir. تصادم مائل ناعم.
func stairs(bottom: Vector3, dir: Vector3, width: float, rise: float, run: float, mat: String, side_mat := "") -> void:
	dir = dir.normalized()
	var right := dir.cross(Vector3.UP).normalized()
	var steps := int(round(rise / 0.2))
	var sh := rise / steps
	var sd := run / steps
	var basis := Basis(right, Vector3.UP, -dir)
	for i in steps:
		var c := bottom + dir * (sd * (i + 0.5)) + Vector3.UP * (sh * (i + 1) * 0.5)
		box(c, Vector3(width, sh * (i + 1), sd), mat, false, false, basis)
	# منحدر التصادم
	var length := sqrt(rise * rise + run * run)
	var ang := atan2(rise, run)
	var rb := basis * Basis(Vector3.RIGHT, ang)
	var mid := bottom + dir * (run * 0.5) + Vector3.UP * (rise * 0.5)
	var nrm := rb * Vector3.UP
	collider(mid - nrm * 0.15, Vector3(width, 0.3, length), rb)
	if side_mat != "":
		for sx in [-1.0, 1.0]:
			var rc: Vector3 = mid + right * sx * (width * 0.5 + 0.04) + nrm * 0.55
			box(rc, Vector3(0.06, 1.0, length), side_mat, true, false, rb)


## جدار على محور X عند z ثابت، مع فتحات أبواب [[x0, x1, ارتفاع]]
func wall_x(z: float, x0: float, x1: float, y0: float, y1: float, mat: String, openings := [], t := 0.4) -> void:
	var cuts := openings.duplicate()
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var x := x0
	for o in cuts:
		if o[0] > x:
			box2(Vector3(x, y0, z - t / 2), Vector3(o[0], y1, z + t / 2), mat, true, true)
		if y0 + o[2] < y1:
			box2(Vector3(o[0], y0 + o[2], z - t / 2), Vector3(o[1], y1, z + t / 2), mat, true, true)
		x = o[1]
	if x < x1:
		box2(Vector3(x, y0, z - t / 2), Vector3(x1, y1, z + t / 2), mat, true, true)


func wall_z(x: float, z0: float, z1: float, y0: float, y1: float, mat: String, openings := [], t := 0.4) -> void:
	var cuts := openings.duplicate()
	cuts.sort_custom(func(a, b): return a[0] < b[0])
	var z := z0
	for o in cuts:
		if o[0] > z:
			box2(Vector3(x - t / 2, y0, z), Vector3(x + t / 2, y1, o[0]), mat, true, true)
		if y0 + o[2] < y1:
			box2(Vector3(x - t / 2, y0 + o[2], o[0]), Vector3(x + t / 2, y1, o[1]), mat, true, true)
		z = o[1]
	if z < z1:
		box2(Vector3(x - t / 2, y0, z), Vector3(x + t / 2, y1, z1), mat, true, true)


## بلاطة أفقية (أرضية أو سقف) سطحها العلوي عند y
func slab(x0: float, z0: float, x1: float, z1: float, y: float, mat: String, thick := 0.4, collide := true) -> void:
	box2(Vector3(x0, y - thick, z0), Vector3(x1, y, z1), mat, collide, false)


func light(pos: Vector3, color := Color(1.0, 0.95, 0.85), energy := 1.6, rng := 11.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	l.shadow_enabled = false
	l.light_specular = 0.4
	root.add_child(l)
	lights.append(l)
	return l


func label(text: String, pos: Vector3, yaw := 0.0, size := 0.6, color := Color.WHITE, lit := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_bold
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation.y = yaw
	l.shaded = lit
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	root.add_child(l)
	return l


func commit() -> void:
	for k in _surf:
		var s: Dictionary = _surf[k]
		if s["v"].is_empty():
			continue
		var parts: PackedStringArray = k.split("|")
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		arr[Mesh.ARRAY_COLOR] = s["c"]
		arr[Mesh.ARRAY_TANGENT] = s["t"]
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, Mats.get_mat(parts[1]))
		var mi := MeshInstance3D.new()
		mi.name = k.replace("|", "_").replace("#", "c").replace(":", "_")
		mi.mesh = mesh
		if parts[1] == "glass" or parts[1].begins_with("emit"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	_surf.clear()
