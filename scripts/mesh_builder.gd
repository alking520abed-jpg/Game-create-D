class_name MeshBuilder
extends RefCounted
## أداة لبناء المجسمات بالكود (بدون أي ملفات خارجية).

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var xf := Transform3D.IDENTITY


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, ref: Vector3) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	ref = xf * ref
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - ref) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	# Godot: الوجه الأمامي باتجاه عقارب الساعة
	verts.append(a); verts.append(c); verts.append(b)
	for i in 3:
		norms.append(n)
		cols.append(col)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, ref: Vector3) -> void:
	tri(a, b, c, col, ref)
	tri(a, c, d, col, ref)


func box(center: Vector3, size: Vector3, col: Color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				p.append(center + basis * Vector3(sx * h.x, sy * h.y, sz * h.z))
	# index = sx*4 + sy*2 + sz
	quad(p[0], p[1], p[3], p[2], col, center)
	quad(p[4], p[5], p[7], p[6], col, center)
	quad(p[0], p[1], p[5], p[4], col, center)
	quad(p[2], p[3], p[7], p[6], col, center)
	quad(p[0], p[2], p[6], p[4], col, center)
	quad(p[1], p[3], p[7], p[5], col, center)


## مخروط/أسطوانة بين نقطتين
func cyl(p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, col: Color, caps := true) -> void:
	var axis := (p1 - p0).normalized()
	var u := axis.cross(Vector3.RIGHT)
	if u.length() < 0.01:
		u = axis.cross(Vector3.FORWARD)
	u = u.normalized()
	var v := axis.cross(u).normalized()
	var mid := (p0 + p1) * 0.5
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		quad(p0 + d0 * r0, p0 + d1 * r0, p1 + d1 * r1, p1 + d0 * r1, col, mid)
		if caps:
			if r0 > 0.001:
				tri(p0, p0 + d0 * r0, p0 + d1 * r0, col, mid)
			if r1 > 0.001:
				tri(p1, p1 + d0 * r1, p1 + d1 * r1, col, mid)


func sphere(c: Vector3, r: float, col: Color, rings := 4, segs := 7, scl := Vector3.ONE, col_bottom = null) -> void:
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in segs:
			var a0 := TAU * j / segs
			var a1 := TAU * (j + 1) / segs
			var p00 := c + Vector3(sin(t0) * cos(a0), cos(t0), sin(t0) * sin(a0)) * r * scl
			var p01 := c + Vector3(sin(t0) * cos(a1), cos(t0), sin(t0) * sin(a1)) * r * scl
			var p10 := c + Vector3(sin(t1) * cos(a0), cos(t1), sin(t1) * sin(a0)) * r * scl
			var p11 := c + Vector3(sin(t1) * cos(a1), cos(t1), sin(t1) * sin(a1)) * r * scl
			var cc := col
			if col_bottom != null:
				cc = col.lerp(col_bottom, float(i) / max(1, rings - 1))
			quad(p00, p01, p11, p10, cc, c)


## بثق مضلع جانبي (z,y) على عرض x
func extrude(profile: Array, x0: float, x1: float, col: Color) -> void:
	var cen := Vector2.ZERO
	for p in profile:
		cen += p
	cen /= profile.size()
	var ref := Vector3((x0 + x1) * 0.5, cen.y, cen.x)
	var n := profile.size()
	for i in n:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % n]
		quad(Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), Vector3(x1, b.y, b.x), Vector3(x1, a.y, a.x), col, ref)
		tri(Vector3(x0, cen.y, cen.x), Vector3(x0, a.y, a.x), Vector3(x0, b.y, b.x), col, ref)
		tri(Vector3(x1, cen.y, cen.x), Vector3(x1, a.y, a.x), Vector3(x1, b.y, b.x), col, ref)


## هرم ناقص بين مستطيلين (سفلي وعلوي)
func frustum(y0: float, y1: float, z0a: float, z0b: float, w0: float, z1a: float, z1b: float, w1: float, col: Color) -> void:
	var b := [Vector3(-w0 / 2, y0, z0a), Vector3(w0 / 2, y0, z0a), Vector3(w0 / 2, y0, z0b), Vector3(-w0 / 2, y0, z0b)]
	var t := [Vector3(-w1 / 2, y1, z1a), Vector3(w1 / 2, y1, z1a), Vector3(w1 / 2, y1, z1b), Vector3(-w1 / 2, y1, z1b)]
	var ref := Vector3(0, (y0 + y1) / 2, (z0a + z0b + z1a + z1b) / 4)
	for i in 4:
		quad(b[i], b[(i + 1) % 4], t[(i + 1) % 4], t[i], col, ref)
	quad(t[0], t[1], t[2], t[3], col, ref)
	quad(b[0], b[1], b[2], b[3], col, ref)


func commit(material: Material = null, mesh: ArrayMesh = null) -> ArrayMesh:
	if mesh == null:
		mesh = ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if material:
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


static func vc_material(rough := 0.9, metal := 0.0, double_sided := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func emissive(col: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m
