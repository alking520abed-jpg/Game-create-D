class_name Pedestrian
extends Node3D
## مشاة يتجولون على الأرصفة، يحيّون اللاعب ويبتعدون عن السيارات.

const GREET := ["السلام عليكم", "مرحبا!", "أهلاً وسهلاً", "كيف الحال؟", "يوم جميل!", "هلا والله", "صباح الخير"]

var rig: CharacterRig
var block := Vector2i.ZERO
var corner := Vector2i(1, 1)
var target := Vector3.ZERO
var walk_speed := 1.4
var flee_t := 0.0
var flee_dir := Vector3.ZERO
var _check := 0.0
var _greet_cd := 0.0
var _bubble: Label3D
var _bubble_t := 0.0
var _rng := RandomNumberGenerator.new()
var _pause := 0.0


func _ready() -> void:
	_rng.randomize()
	rig = CharacterRig.new()
	add_child(rig)
	rig.build(_rng.randi() % 4, _rng)
	var s := _rng.randf_range(0.92, 1.06)
	rig.scale = Vector3(s, s, s)
	walk_speed = _rng.randf_range(1.1, 1.7)
	_bubble = Label3D.new()
	_bubble.font = Game.font_bold
	_bubble.font_size = 56
	_bubble.pixel_size = 0.008
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.outline_size = 16
	_bubble.position.y = 2.25
	_bubble.visible = false
	_bubble.no_depth_test = true
	add_child(_bubble)


static func corner_pos(b: Vector2i, c: Vector2i) -> Vector3:
	return City.block_center(b.x, b.y) + Vector3(c.x * 27.0, 0, c.y * 27.0)


func place_near(p: Vector3, min_d: float, max_d: float) -> void:
	for tries in 20:
		var b := Vector2i(_rng.randi_range(0, City.N - 1), _rng.randi_range(0, City.N - 1))
		var c := Vector2i([-1, 1][_rng.randi() % 2], [-1, 1][_rng.randi() % 2])
		var q := corner_pos(b, c)
		var d := q.distance_to(p)
		if (d >= min_d and d <= max_d) or tries == 19:
			block = b
			corner = c
			global_position = q
			_next()
			# ابدأ من نقطة عشوائية على الطريق
			global_position = q.lerp(target, _rng.randf())
			return


func _next() -> void:
	if _rng.randf() < 0.3:
		# اعبر الشارع للبلوك المجاور
		var ax := _rng.randi() % 2
		var nb := block
		var nc := corner
		if ax == 0:
			nb.x += corner.x
			nc.x = -corner.x
		else:
			nb.y += corner.y
			nc.y = -corner.y
		if nb.x >= 0 and nb.x < City.N and nb.y >= 0 and nb.y < City.N:
			block = nb
			corner = nc
			target = corner_pos(block, corner)
			return
	if _rng.randf() < 0.5:
		corner = Vector2i(-corner.x, corner.y)
	else:
		corner = Vector2i(corner.x, -corner.y)
	target = corner_pos(block, corner)
	if _rng.randf() < 0.15:
		_pause = _rng.randf_range(1.5, 5.0)


func say(t: String) -> void:
	_bubble.text = t
	_bubble.visible = true
	_bubble_t = 2.6


func _process(delta: float) -> void:
	var pp := Game.pos()
	var dist := global_position.distance_to(pp)
	if dist > 140.0:
		return
	if _bubble_t > 0.0:
		_bubble_t -= delta
		if _bubble_t <= 0.0:
			_bubble.visible = false
	_check -= delta
	_greet_cd -= delta
	if _check <= 0.0:
		_check = 0.15
		if dist < 14.0 and Game.car != null and abs(Game.car.speed) > 3.0:
			var c = Game.car
			var rel: Vector3 = global_position - c.global_position
			var f: Vector3 = -c.global_transform.basis.z * sign(c.speed)
			if rel.dot(f) > -1.0 and abs(rel.dot(c.global_transform.basis.x)) < 3.0:
				var side: float = sign(rel.dot(c.global_transform.basis.x))
				if side == 0.0:
					side = 1.0
				flee_dir = c.global_transform.basis.x * side
				flee_t = 0.55
				rig.wave = 0.8
				if _greet_cd < 0.0:
					say(["انتبه!", "على مهلك!", "يا ساتر!"][_rng.randi() % 3])
					_greet_cd = 6.0
		elif dist < 3.2 and Game.car == null and _greet_cd < 0.0:
			_greet_cd = 14.0
			rig.wave = 1.6
			_pause = 1.8
			say(GREET[_rng.randi() % GREET.size()])
			var to := pp - global_position
			rig.rotation.y = atan2(-to.x, -to.z)
	var sp := 0.0
	if flee_t > 0.0:
		flee_t -= delta
		global_position += flee_dir * 6.5 * delta
		rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-flee_dir.x, -flee_dir.z), min(1.0, delta * 15.0))
		sp = 6.5
	elif _pause > 0.0:
		_pause -= delta
	else:
		var to := target - global_position
		to.y = 0
		if to.length() < 0.4:
			_next()
		else:
			var d := to.normalized()
			global_position += d * walk_speed * delta
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-d.x, -d.z), min(1.0, delta * 8.0))
			sp = walk_speed
	rig.animate(sp, delta)
