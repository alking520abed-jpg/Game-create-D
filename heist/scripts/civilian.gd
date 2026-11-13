class_name Civilian
extends Actor
## مدني / رهينة: يقف أو يجلس، وعند الخطر ينخفض أرضاً. إيذاؤه يُفشل المهمة.

var panic := false
var idle_anim := "Idle"
var _rng := RandomNumberGenerator.new()


func init(cname: String, pos: Vector3, yaw := 0.0, idle := "Idle") -> void:
	team = Team.CIVIL
	_rng.randomize()
	hp = 40.0
	setup(cname)
	global_position = pos
	rotation.y = yaw
	_face_yaw = yaw
	idle_anim = idle
	play(idle_anim)
	anim.seek(_rng.randf_range(0.0, 1.5))
	set_physics_process(false)


func set_panic(on := true) -> void:
	if dead:
		return
	panic = on
	play("Crouch_Idle" if on else idle_anim, _rng.randf_range(0.85, 1.1), 0.5)


func on_hurt(_from: Vector3, _by_player: bool) -> void:
	set_panic(true)


func die(by_player := true, head := false) -> void:
	super.die(by_player, head)
	if by_player and Game.story:
		Game.story.hostage_down()
