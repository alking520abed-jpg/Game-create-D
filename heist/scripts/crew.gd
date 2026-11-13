class_name Crew
extends Actor
## أحد أفراد الطاقم: يثبت في موقعه أو يتبع اللاعب، ويشتبك مع الأعداء.

var post := Vector3.ZERO
var follow := false
var slot := 0
var _target: Enemy
var _scan := 0.0
var _shot_cd := 0.0
var _hit_cd := 0.0
var _rng := RandomNumberGenerator.new()


func init(cname: String, dname: String, pos: Vector3, yaw := 0.0) -> void:
	team = Team.CREW
	display_name = dname
	_rng.randomize()
	setup(cname, "smg")
	global_position = pos
	post = pos
	rotation.y = yaw
	_face_yaw = yaw


func go(p: Vector3) -> void:
	post = p
	follow = false


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or Game.player == null:
		stand(delta)
		play("Pistol_Idle" if _target else "Idle")
		return
	_hit_cd -= delta
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.4
		_target = null
		var best := 26.0
		for e in Game.world.enemies:
			if e.dead or e.st != Enemy.St.COMBAT:
				continue
			var d: float = e.global_position.distance_to(global_position)
			if d < best and can_see(e.chest()):
				best = d
				_target = e
	if _target and is_instance_valid(_target) and not _target.dead:
		stand(delta)
		face_to(_target.global_position, delta, 10.0)
		_shot_cd -= delta
		if _shot_cd <= 0.0:
			_shot_cd = _rng.randf_range(0.35, 0.8)
			anim.stop()
			_cur = ""
			play("Pistol_Shoot", 1.5, 0.05)
			var from := muzzle.global_position
			Audio.play_at("shot_smg", from, -5.0)
			FX.flash(muzzle, 1.4)
			var hit := _rng.randf() < 0.45
			var end := _target.chest()
			if hit:
				_target.hurt(13.0, global_position, false, false)
			else:
				end += Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(-0.4, 0.8), _rng.randf_range(-0.8, 0.8))
			FX.tracer(get_parent(), from, end, Color(0.6, 0.9, 1.0))
		elif not anim.is_playing():
			play("Pistol_Idle")
		return
	var dest := post
	if follow:
		var p = Game.player
		var back: Vector3 = p.global_transform.basis.z
		var side: Vector3 = p.global_transform.basis.x * (float(slot) - 1.0) * 1.6
		dest = p.global_position + back * 2.6 + side
		if global_position.distance_to(p.global_position) < 4.0:
			stand(delta)
			play("Idle")
			return
	if global_position.distance_to(dest) > 1.3:
		var far := global_position.distance_to(dest) > 6.0
		nav_move(dest, 4.6 if far else 2.6, delta)
		play("Jog_Fwd" if far else "Walk", 1.1)
		# لا يعلق بعيداً عن اللاعب
		if follow and global_position.distance_to(Game.player.global_position) > 38.0:
			global_position = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, Game.player.global_position - Game.player.global_transform.basis.z * -3.0)
	else:
		stand(delta)
		play("Idle")


func hurt(_dmg: float, _from: Vector3, _head := false, by_player := true) -> void:
	if by_player and _hit_cd <= 0.0:
		_hit_cd = 4.0
		Game.say(display_name, ["انتبه! أنا من فريقك!", "وجّه سلاحك للعدو!", "هل جننت؟ أنا معك!"][_rng.randi() % 3])
