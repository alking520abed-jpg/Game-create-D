class_name FX
extends RefCounted
## مؤثرات بصرية: خطوط الرصاص، وميض الفوهة، الارتطام، الانفجار.

static var _tracer_mat: StandardMaterial3D
static var _flash_tex: Texture2D
static var _spark_mat: StandardMaterial3D
static var _decal_mat: StandardMaterial3D
static var _decals: Array = []


static func _radial() -> Texture2D:
	if _flash_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 64
		gt.height = 64
		_flash_tex = gt
	return _flash_tex


static func tracer(parent: Node, from: Vector3, to: Vector3, col := Color(1.0, 0.85, 0.5)) -> void:
	var d := from.distance_to(to)
	if d < 0.5:
		return
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Color(1.0, 0.85, 0.5, 0.75)
		_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tracer_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, min(d, 14.0))
	bm.material = _tracer_mat
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := (to - from) / d
	mi.look_at_from_position(from + dir * (bm.size.z * 0.5), to, Vector3.UP if abs(dir.y) < 0.98 else Vector3.RIGHT)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to - dir * (bm.size.z * 0.5), min(0.12, d / 160.0))
	tw.tween_callback(mi.queue_free)


static func flash(parent: Node3D, energy := 2.5) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.45)
	l.light_energy = energy
	l.omni_range = 7.0
	parent.add_child(l)
	var s := Sprite3D.new()
	s.texture = _radial()
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.modulate = Color(1.0, 0.85, 0.5, 0.95)
	s.pixel_size = 0.004 * randf_range(0.8, 1.3)
	s.shaded = false
	s.no_depth_test = false
	parent.add_child(s)
	var tw := l.create_tween()
	tw.tween_interval(0.045)
	tw.tween_callback(l.queue_free)
	tw.tween_callback(s.queue_free)


static func impact(parent: Node, pos: Vector3, normal: Vector3, flesh := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8 if not flesh else 10
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 40.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -7, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.vertex_color_use_as_albedo = true
		_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	qm.material = _spark_mat
	p.mesh = qm
	p.color = Color(0.45, 0.05, 0.05) if flesh else Color(0.85, 0.8, 0.7)
	parent.add_child(p)
	p.global_position = pos + normal * 0.03
	p.create_tween().tween_callback(p.queue_free).set_delay(0.6)
	if flesh:
		return
	# أثر الرصاصة
	if _decal_mat == null:
		_decal_mat = StandardMaterial3D.new()
		_decal_mat.albedo_texture = _radial()
		_decal_mat.albedo_color = Color(0.03, 0.03, 0.03, 0.9)
		_decal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_decal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var d := MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.11, 0.11)
	dq.material = _decal_mat
	d.mesh = dq
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(d)
	d.global_position = pos + normal * 0.012
	if abs(normal.y) > 0.98:
		d.rotation.x = -PI / 2 * sign(normal.y)
	else:
		d.look_at(pos - normal, Vector3.UP)
		d.rotate_object_local(Vector3.UP, PI)
	_decals.append(d)
	while _decals.size() > 40:
		var o = _decals.pop_front()
		if is_instance_valid(o):
			o.queue_free()


static func explosion(parent: Node, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 8.0
	l.omni_range = 22.0
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 60
	p.lifetime = 1.2
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -3, 0)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 4.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 0.4)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _radial()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = m
	p.mesh = qm
	var gr := Gradient.new()
	gr.set_color(0, Color(1.0, 0.75, 0.3, 0.9))
	gr.set_color(1, Color(0.15, 0.14, 0.13, 0.0))
	p.color_ramp = gr
	parent.add_child(p)
	p.global_position = pos
	p.create_tween().tween_callback(p.queue_free).set_delay(1.6)
	Audio.play_at("explosion", pos, 6.0)


static func clear() -> void:
	_decals.clear()
