class_name Enemy
extends Actor
## حارس / شرطي / قوات خاصة: حراسة، كشف اللاعب، مطاردة عبر الملاحة، وإطلاق نار على دفعات.

signal died(e)

enum St { GUARD, COMBAT }

const TYPES := {
	"guard": {"chars": ["guard_a", "guard_b", "guard_c"], "hp": 60.0, "gun": "pistol", "acc": 0.40, "dmg": 8.0, "burst": [1, 2], "rate": 0.42, "speed": 3.4, "range": 14.0, "name": "حارس", "pause": [0.9, 1.8]},
	"police": {"chars": ["police_a", "police_b"], "hp": 85.0, "gun": "smg", "acc": 0.34, "dmg": 6.0, "burst": [3, 5], "rate": 0.12, "speed": 3.9, "range": 15.0, "name": "شرطي", "pause": [1.0, 1.9]},
	"swat": {"chars": ["swat_a"], "hp": 140.0, "gun": "rifle", "acc": 0.42, "dmg": 9.0, "burst": [3, 4], "rate": 0.11, "speed": 4.2, "range": 18.0, "name": "قوات خاصة", "pause": [0.8, 1.6]},
	"boss": {"chars": ["swat_a"], "hp": 700.0, "gun": "rifle", "acc": 0.5, "dmg": 11.0, "burst": [5, 8], "rate": 0.1, "speed": 3.2, "range": 20.0, "name": "قائد القوة", "pause": [0.7, 1.2]},
}

var kind := "guard"
var def := {}
var st: int = St.GUARD
var target: Node3D
var post := Vector3.ZERO
var patrol: Array = []
var _pi := 0
var _think := 0.0
var _mode := 0          # 0 تقدّم، 1 إطلاق
var _move_to := Vector3.ZERO
var _burst := 0
var _shot_cd := 0.0
var _pause := 0.0
var _stun := 0.0
var _see_t := 0.0
var _dead_t := 0.0
var _wait := 0.0
var _rng := RandomNumberGenerator.new()


func init(k: String, pos: Vector3, yaw := 0.0) -> void:
	kind = k
	def = TYPES[k]
	team = Team.ENEMY
	_rng.randomize()
	hp = def["hp"] * (0.8 + 0.2 * Game.difficulty_mul())
	max_hp = hp
	display_name = def["name"]
	setup(def["chars"][_rng.randi() % def["chars"].size()], def["gun"])
	if k == "boss":
		model.scale = Vector3(1.12, 1.12, 1.12)
	global_position = pos
	post = pos
	rotation.y = yaw
	_face_yaw = yaw
	_think = _rng.randf_range(0.0, 0.5)


func alert(shout := true) -> void:
	if st == St.COMBAT or dead:
		return
	st = St.COMBAT
	_pause = _rng.randf_range(0.35, 0.8)
	_think = 0.0
	if shout and Game.world:
		Game.world.noise(global_position, 13.0)


func _pick_target() -> void:
	var p = Game.player
	target = p
	if Game.world and _rng.randf() < 0.3:
		var best := 1e9
		for c in Game.world.crew:
			var d: float = c.global_position.distance_to(global_position)
			if d < best and d < 18.0 and can_see(c.chest()):
				best = d
				target = c
			if p and d > global_position.distance_to(p.global_position):
				target = p


func _target_point() -> Vector3:
	if target == Game.player:
		return Game.player.chest()
	return target.chest()


func _physics_process(delta: float) -> void:
	if dead:
		_dead_t += delta
		_apply_move(Vector3.ZERO, delta)
		if _dead_t > 2.6:
			set_physics_process(false)
		return
	if Game.state != Game.State.PLAYING or Game.player == null:
		stand(delta)
		return
	if _stun > 0.0:
		_stun -= delta
		stand(delta)
		return
	if st == St.GUARD:
		_guard(delta)
	else:
		_combat(delta)


func _guard(delta: float) -> void:
	if patrol.size() > 1:
		if _wait > 0.0:
			_wait -= delta
			stand(delta)
			play("Idle")
		elif nav_move(patrol[_pi], 1.5, delta):
			_pi = (_pi + 1) % patrol.size()
			_wait = _rng.randf_range(1.5, 4.0)
		else:
			play("Walk")
	else:
		stand(delta)
		play("Idle")
	# الكشف
	_think -= delta
	if _think <= 0.0:
		_think = 0.2
		var p = Game.player
		var to: Vector3 = p.global_position - global_position
		var d := to.length()
		var fwd := -global_transform.basis.z
		var front := fwd.dot(to.normalized()) > 0.25
		var sight := 9.0 if p.crouching else 20.0
		if d < sight and (front or d < 3.0) and can_see(p.eye_pos()):
			_see_t += 0.2
			if _see_t > (0.5 if d > 8.0 else 0.2):
				alert()
		else:
			_see_t = max(0.0, _see_t - 0.1)


func _combat(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		_pick_target()
	var tp := _target_point()
	var d := global_position.distance_to(target.global_position)
	_think -= delta
	if _think <= 0.0:
		_think = _rng.randf_range(1.2, 2.4)
		_pick_target()
		tp = _target_point()
		var los := can_see(tp)
		var rng: float = def["range"]
		if los and d <= rng:
			_mode = 1
			if _rng.randf() < 0.32:
				# تحرك جانبي إلى نقطة قريبة
				var side := global_transform.basis.x * (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(2.0, 4.0)
				_move_to = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, global_position + side)
				_mode = 2
		else:
			_mode = 0
			var back := (global_position - target.global_position).normalized()
			var want: Vector3 = target.global_position + back * (rng * 0.45 if los else 1.5)
			_move_to = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, want)
	if _mode == 0 or _mode == 2:
		var arrived := nav_move(_move_to, def["speed"] if _mode == 0 else def["speed"] * 0.7, delta)
		play("Jog_Fwd", 1.1)
		if arrived:
			_mode = 1
			_think = min(_think, 0.4)
		if _mode == 0 and d <= def["range"] * 0.8 and can_see(tp):
			_mode = 1
		return
	# وضع الإطلاق
	stand(delta)
	face_to(target.global_position, delta, 10.0)
	_shot_cd -= delta
	_pause -= delta
	if _burst <= 0:
		play("Pistol_Idle")
		if _pause <= 0.0:
			_burst = _rng.randi_range(def["burst"][0], def["burst"][1])
	elif _shot_cd <= 0.0:
		_shot_cd = def["rate"]
		_burst -= 1
		if _burst <= 0:
			var pz: Array = def["pause"]
			_pause = _rng.randf_range(pz[0], pz[1]) / (0.7 + 0.3 * Game.difficulty_mul())
		_fire(tp, d)


func _fire(tp: Vector3, d: float) -> void:
	if not can_see(tp, 60.0):
		_burst = 0
		_think = 0.0
		return
	anim.stop()
	_cur = ""
	play("Pistol_Shoot", 1.6, 0.05)
	var from := muzzle.global_position if muzzle else eye()
	Audio.play_at("shot_enemy", from, 2.0)
	FX.flash(muzzle if muzzle else self, 1.6)
	var acc: float = def["acc"] * (0.75 + 0.25 * Game.difficulty_mul())
	acc *= clamp(1.3 - d / (def["range"] * 2.0), 0.3, 1.0)
	var hit := false
	if target == Game.player:
		var p = Game.player
		if p.crouching:
			acc *= 0.75
		if p.speed_now() > 4.0:
			acc *= 0.8
		hit = _rng.randf() < acc
		if hit:
			p.hurt(def["dmg"] * (0.7 + 0.3 * Game.difficulty_mul()), global_position)
	else:
		hit = _rng.randf() < acc
		if hit:
			target.hurt(def["dmg"], global_position, false, false)
	var end := tp
	if not hit:
		var off := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.6, 0.9), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(0.5, 1.2)
		var dir := (tp + off - from).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0, 1 | 32)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		end = r["position"] if not r.is_empty() else from + dir * 60.0
		if not r.is_empty() and _rng.randf() < 0.5:
			FX.impact(get_parent(), r["position"], r["normal"])
	FX.tracer(get_parent(), from, end)


func on_hurt(_from: Vector3, _by_player: bool) -> void:
	alert()
	if kind != "boss" and _rng.randf() < 0.6:
		_stun = 0.28
		anim.stop()
		_cur = ""
		play("Hit_Chest", 1.2, 0.05)


func die(by_player := true, head := false) -> void:
	super.die(by_player, head)
	if by_player:
		Game.stats["kills"] += 1
		if head:
			Game.stats["heads"] += 1
	if Game.world:
		Game.world.on_enemy_died(self)
	died.emit(self)
