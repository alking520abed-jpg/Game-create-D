class_name Combat
extends Node3D
## القتال: الأعداء، المقذوفات، الليزر، الانفجارات، المؤثرات، والأشياء القابلة للتدمير.

class Prop:
	extends StaticBody3D
	var hp := 30.0
	var explosive := false
	var size := 1.2

	func setup(p_explosive: bool) -> void:
		explosive = p_explosive
		collision_layer = 1
		collision_mask = 0
		var mi := MeshInstance3D.new()
		var cs := CollisionShape3D.new()
		var m := StandardMaterial3D.new()
		if explosive:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.45
			cm.bottom_radius = 0.45
			cm.height = 1.2
			cm.radial_segments = 10
			mi.mesh = cm
			var sh := CylinderShape3D.new()
			sh.radius = 0.45
			sh.height = 1.2
			cs.shape = sh
			m.albedo_color = Color(0.85, 0.15, 0.1)
			m.metallic = 0.5
			m.roughness = 0.4
			hp = 15.0
			mi.position.y = 0.6
			cs.position.y = 0.6
		else:
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * size
			mi.mesh = bm
			var sh := BoxShape3D.new()
			sh.size = Vector3.ONE * size
			cs.shape = sh
			m.albedo_color = Color(0.62, 0.45, 0.25)
			m.roughness = 0.9
			mi.position.y = size * 0.5
			cs.position.y = size * 0.5
		mi.material_override = m
		add_child(mi)
		add_child(cs)

var enemies: Array = []
var props: Array = []
var _shots: Array = []
var _rng := RandomNumberGenerator.new()
var _texts := 0

static var _soft: Texture2D
static var _pmat: StandardMaterial3D
static var _mats := {}


static func soft_tex() -> Texture2D:
	if _soft == null:
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
		_soft = gt
	return _soft


static func glow_mat(col: Color, alpha := 1.0) -> StandardMaterial3D:
	var k := col.to_html() + str(alpha)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(col.r, col.g, col.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[k] = m
	return _mats[k]


static func make_particles(col: Color, amount: int, life: float, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.color = col
	if _pmat == null:
		_pmat = StandardMaterial3D.new()
		_pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_pmat.vertex_color_use_as_albedo = true
		_pmat.albedo_texture = soft_tex()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	qm.material = _pmat
	p.mesh = qm
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = gr
	return p


func _ready() -> void:
	_rng.randomize()
	Game.combat = self


# ---------------- الأعداء ----------------

func spawn(kind: String, pos: Vector3, alert := true) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.setup(kind)
	e.global_position = pos
	e.alert = alert
	enemies.append(e)
	return e


func clear_enemies() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()


func alive() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dead:
			n += 1
	return n


func nearest_enemy(pos: Vector3, max_range: float, fwd := Vector3.ZERO, cone := -1.0):
	var best = null
	var best_d := max_range
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.global_position - pos
		var d := to.length()
		if d > max_range:
			continue
		if fwd != Vector3.ZERO and d > 2.5:
			var t2 := Vector3(to.x, 0, to.z).normalized()
			if t2.dot(fwd) < cone:
				continue
		if d < best_d:
			best_d = d
			best = e
	return best


func enemies_near(pos: Vector3, max_range: float, limit: int) -> Array:
	var list := []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) <= max_range:
			list.append(e)
	list.sort_custom(func(a, b): return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	if list.size() > limit:
		list.resize(limit)
	return list


func hit_enemies(center: Vector3, radius: float, dmg: float, knock := Vector3.ZERO, radial := 0.0, stun := 0.0) -> int:
	var n := 0
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var c: Vector3 = e.center()
		if c.distance_to(center) <= radius + e.hit_r:
			var k := knock
			if radial > 0.0:
				var out := c - center
				out.y = 0.0
				k += out.normalized() * radial
			e.take_damage(dmg, k, stun)
			n += 1
	return n


func hit_cars(center: Vector3, radius: float, dmg: float, knock := Vector3.ZERO, radial := 0.0) -> int:
	var n := 0
	for c in Game.cars.duplicate():
		if not is_instance_valid(c):
			continue
		var cp: Vector3 = c.global_position + Vector3(0, 0.8, 0)
		if cp.distance_to(center) <= radius + 1.6:
			var k := knock
			if radial > 0.0:
				var out := cp - center
				out.y = 0.0
				k += out.normalized() * radial
			c.damage(dmg, k)
			n += 1
	return n


func hit_props(center: Vector3, radius: float, dmg: float) -> void:
	for p in props.duplicate():
		if not is_instance_valid(p):
			props.erase(p)
			continue
		if (p.global_position + Vector3(0, 0.6, 0)).distance_to(center) <= radius + 0.8:
			p.hp -= dmg
			if p.hp <= 0.0:
				_break_prop(p)


func spawn_prop(pos: Vector3, explosive := false) -> void:
	var p := Prop.new()
	add_child(p)
	p.setup(explosive)
	p.global_position = pos
	p.rotation.y = _rng.randf() * TAU
	props.append(p)


func _break_prop(p) -> void:
	props.erase(p)
	var pos: Vector3 = p.global_position + Vector3(0, 0.6, 0)
	var ex: bool = p.explosive
	p.queue_free()
	if ex:
		explode(pos, 6.0, 55.0, 0)
	else:
		fx_burst(pos, Color(0.75, 0.55, 0.3), 1.6)
		Sfx.play("crash", -8.0, 1.3)


# ---------------- الانفجارات والمقذوفات ----------------

## team: 0 = البطل يؤذي الأعداء، 1 = الأعداء يؤذون البطل
func explode(pos: Vector3, radius: float, dmg: float, team: int) -> void:
	fx_burst(pos, Color(1.0, 0.55, 0.15), radius * 0.9)
	fx_burst(pos + Vector3(0, 0.6, 0), Color(0.25, 0.22, 0.2), radius * 0.7, 1.2, false)
	fx_ring(Vector3(pos.x, max(pos.y - 1.0, 0.05), pos.z), radius, Color(1.0, 0.7, 0.3))
	Sfx.play("boom", -2.0, _rng.randf_range(0.85, 1.15))
	var pp: Vector3 = Game.pos()
	if Game.cam:
		Game.cam.shake(clamp(1.2 - pp.distance_to(pos) / 40.0, 0.0, 0.9))
	if team == 0:
		hit_enemies(pos, radius, dmg, Vector3(0, 5, 0), 10.0)
	elif Game.player and (pp + Vector3(0, 1, 0)).distance_to(pos) < radius + 0.6:
		Game.player.hurt(dmg, pos)
	hit_cars(pos, radius * 0.8, dmg * 1.2, Vector3.ZERO, 8.0)
	hit_props(pos, radius, dmg)


func projectile(from: Vector3, dir: Vector3, speed: float, dmg: float, team: int, col: Color, boom := 0.0, size := 0.3) -> void:
	var n := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	n.mesh = sm
	n.material_override = glow_mat(col.lightened(0.35))
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.global_position = from
	var tr := make_particles(col, 14, 0.35, size * 2.4)
	tr.local_coords = false
	tr.gravity = Vector3.ZERO
	tr.initial_velocity_max = 0.4
	n.add_child(tr)
	_shots.append({"n": n, "v": dir.normalized() * speed, "dmg": dmg, "team": team, "boom": boom, "life": 3.0, "r": size, "col": col})


func _physics_process(delta: float) -> void:
	if _shots.is_empty() or Game.state != Game.State.PLAYING:
		return
	var space := get_world_3d().direct_space_state
	for s in _shots.duplicate():
		var n: MeshInstance3D = s["n"]
		var a := n.global_position
		var b: Vector3 = a + s["v"] * delta
		s["life"] -= delta
		var hit := false
		var hp := b
		var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 2)
		var res := space.intersect_ray(q)
		var car = null
		if not res.is_empty():
			hit = true
			hp = res["position"]
			if res["collider"] is Car:
				car = res["collider"]
		if not hit and b.y < 0.05:
			hit = true
			hp = Vector3(b.x, 0.05, b.z)
		var victim = null
		if not hit:
			if s["team"] == 0:
				for e in enemies:
					if is_instance_valid(e) and not e.dead and e.center().distance_to(b) < e.hit_r + s["r"] + 0.35:
						victim = e
						hit = true
						break
			elif Game.player and not Game.player.dead:
				var pc: Vector3 = Game.pos() + Vector3(0, 1.0, 0)
				if pc.distance_to(b) < 1.0 + s["r"]:
					hit = true
					victim = Game.player
		if hit or s["life"] <= 0.0:
			if hit:
				if s["boom"] > 0.0:
					explode(hp, s["boom"], s["dmg"], s["team"])
				else:
					fx_burst(hp, s["col"], 0.7)
					if victim is Enemy:
						victim.take_damage(s["dmg"], s["v"].normalized() * 4.0)
					elif victim != null:
						victim.hurt(s["dmg"], a)
					if car != null and s["team"] == 0:
						car.damage(s["dmg"], s["v"].normalized() * 2.0)
			_shots.erase(s)
			n.queue_free()
		else:
			n.global_position = b


func laser(origin: Vector3, dir: Vector3, max_range: float, dmg: float, col: Color, knock := Vector3.ZERO) -> void:
	var space := get_world_3d().direct_space_state
	var end := origin + dir * max_range
	var q := PhysicsRayQueryParameters3D.create(origin, end, 1 | 2)
	var res := space.intersect_ray(q)
	var limit := max_range
	var car = null
	if not res.is_empty():
		limit = origin.distance_to(res["position"])
		if res["collider"] is Car:
			car = res["collider"]
	var best = null
	var best_t := limit
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector3 = e.center() - origin
		var t := to.dot(dir)
		if t < 0.0 or t > best_t:
			continue
		if (to - dir * t).length() < e.hit_r + 0.55:
			best = e
			best_t = t
	var hp := origin + dir * best_t
	fx_beam(origin, hp, col, 0.14, 0.12)
	fx_burst(hp, col, 0.8)
	if best != null:
		best.take_damage(dmg, knock)
	elif car != null:
		car.damage(dmg, dir * 2.0)
	else:
		hit_props(hp, 0.6, dmg)


# ---------------- المؤثرات ----------------

func fx_burst(pos: Vector3, col: Color, size := 1.0, life := 0.5, flash := true) -> void:
	var p := make_particles(col, 12, life, size * 0.7)
	p.one_shot = true
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = size * 1.2
	p.initial_velocity_max = size * 3.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(life + 0.3, false).timeout.connect(p.queue_free)
	if flash:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		sm.radial_segments = 10
		sm.rings = 5
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(col.r, col.g, col.b, 0.7).lightened(0.3)
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.global_position = pos
		m.scale = Vector3.ONE * size * 0.4
		var tw := m.create_tween()
		tw.tween_property(m, "scale", Vector3.ONE * size * 1.9, 0.22)
		tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
		tw.tween_callback(m.queue_free)


func fx_ring(pos: Vector3, radius: float, col: Color) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 28
	tm.ring_segments = 4
	m.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, 0.85)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos + Vector3(0, 0.15, 0)
	m.scale = Vector3(0.5, 0.4, 0.5)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius, 0.4, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(m.queue_free)


func fx_beam(a: Vector3, b: Vector3, col: Color, life := 0.15, width := 0.12) -> void:
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, 1.0)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col.lightened(0.4)
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = (a + b) * 0.5
	var d := (b - a) / len
	var up := Vector3.UP if abs(d.y) < 0.95 else Vector3.RIGHT
	m.look_at(b, up)
	m.scale = Vector3(1, 1, len)
	var tw := m.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.parallel().tween_property(m, "scale", Vector3(0.2, 0.2, len), life)
	tw.tween_callback(m.queue_free)


func fx_slash(pos: Vector3, dir: Vector3, col: Color) -> void:
	var right := dir.cross(Vector3.UP).normalized()
	fx_beam(pos - right * 2.2 + Vector3(0, 0.5, 0), pos + right * 2.2 - Vector3(0, 0.5, 0), col, 0.18, 0.2)
	fx_beam(pos - right * 2.0 - Vector3(0, 0.4, 0), pos + right * 2.0 + Vector3(0, 0.4, 0), col, 0.22, 0.14)


func fx_text(pos: Vector3, text: String, col: Color) -> void:
	if _texts > 10:
		return
	_texts += 1
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_bold
	l.font_size = 64
	l.pixel_size = 0.011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = col
	l.outline_size = 14
	add_child(l)
	l.global_position = pos + Vector3(_rng.randf_range(-0.4, 0.4), 0.3, _rng.randf_range(-0.4, 0.4))
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.6, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_texts -= 1
		l.queue_free()
	)
