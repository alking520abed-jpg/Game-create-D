class_name Actor
extends CharacterBody3D
## أساس كل شخصية بشرية: المجسم، الحركات، السلاح في اليد، الملاحة، الإصابة والموت.

enum Team { ENEMY, CREW, CIVIL }

const GUN_XF := {
	"pistol": [Vector3(0.0, 0.085, 0.03), Vector3(-90, 0, 0)],
	"smg": [Vector3(0.0, 0.085, 0.03), Vector3(-90, 0, 0)],
	"shotgun": [Vector3(0.0, 0.085, 0.03), Vector3(-90, 0, 0)],
	"rifle": [Vector3(0.0, 0.085, 0.03), Vector3(-90, 0, 0)],
}

static var _libs: Array = []
static var _meta := {}
static var corpses: Array = []

var char_name := ""
var display_name := ""
var team: int = Team.ENEMY
var hp := 100.0
var max_hp := 100.0
var dead := false
var eye_h := 1.6
var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var gun: Node3D
var gun_id := ""
var muzzle: Node3D
var agent: NavigationAgent3D
var _cur := ""
var _face_yaw := 0.0
var _repath := 0.0
var _nav_target := Vector3.INF


static func libs() -> Array:
	if _libs.is_empty():
		for p in ["res://anim/ual1.glb", "res://anim/ual2.glb"]:
			var inst: Node = load(p).instantiate()
			_libs.append(inst.get_node("AnimationPlayer").get_animation_library(""))
			inst.free()
		var f := FileAccess.open("res://chars/cast.json", FileAccess.READ)
		if f:
			_meta = JSON.parse_string(f.get_as_text())
	return _libs


static func attach_gun(skeleton: Skeleton3D, id: String) -> Array:
	var ba := BoneAttachment3D.new()
	ba.bone_name = "RightHand"
	skeleton.add_child(ba)
	var g: Node3D = load("res://weapons/gun_%s.glb" % id).instantiate()
	g.position = GUN_XF[id][0]
	g.rotation_degrees = GUN_XF[id][1]
	ba.add_child(g)
	var mz := Node3D.new()
	var md: Dictionary = Weapons.MUZZLE.get(id, {})
	mz.position = md.get("pos", Vector3(0, 0.07, -0.3))
	g.add_child(mz)
	return [ba, g, mz]


func setup(cname: String, gun_name := "") -> void:
	char_name = cname
	libs()
	if _meta.has(cname):
		eye_h = _meta[cname]["eye"]
	model = load("res://chars/%s.gltf" % cname).instantiate()
	add_child(model)
	model.rotation.y = PI   # المجسم يواجه +Z، والحركة عندنا باتجاه -Z
	skel = model.find_child("GeneralSkeleton", true, false)
	anim = AnimationPlayer.new()
	model.add_child(anim)
	anim.add_animation_library("a", _libs[0])
	anim.add_animation_library("b", _libs[1])
	anim.playback_default_blend_time = 0.2
	for mi in skel.get_children():
		if mi is MeshInstance3D:
			mi.visibility_range_end = 70.0
			if Game.settings["quality"] == 0:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = eye_h + 0.14
	cs.shape = cap
	cs.position.y = cap.height / 2
	add_child(cs)
	collision_layer = 4 if team == Team.ENEMY else 8
	collision_mask = 1 | 32
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 0.8
	agent.radius = 0.4
	agent.height = 1.8
	agent.avoidance_enabled = false
	add_child(agent)
	if gun_name != "":
		gun_id = gun_name
		var r := attach_gun(skel, gun_name)
		gun = r[1]
		muzzle = r[2]
	_face_yaw = rotation.y
	play("Idle")


func play(n: String, speed := 1.0, blend := 0.2) -> void:
	if _cur == n and anim.is_playing():
		anim.speed_scale = speed
		return
	_cur = n
	var full := ("a/" if _libs[0].has_animation(n) else "b/") + n
	anim.play(full, blend, speed)


func eye() -> Vector3:
	return global_position + Vector3(0, eye_h, 0)


func chest() -> Vector3:
	return global_position + Vector3(0, eye_h * 0.75, 0)


func face_to(target: Vector3, delta: float, rate := 9.0) -> void:
	var d := target - global_position
	if Vector2(d.x, d.z).length() > 0.05:
		_face_yaw = atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, _face_yaw, min(1.0, delta * rate))


## يتحرك نحو الهدف عبر شبكة الملاحة. يرجع true عند الوصول.
func nav_move(target: Vector3, speed: float, delta: float, face_move := true) -> bool:
	_repath -= delta
	if _nav_target.distance_to(target) > 0.8 or _repath <= 0.0:
		_nav_target = target
		agent.target_position = target
		_repath = 0.6
	var arrived := agent.is_navigation_finished() or global_position.distance_to(target) < 0.9
	var vel := Vector3.ZERO
	if not arrived:
		var nxt := agent.get_next_path_position()
		var d := nxt - global_position
		d.y = 0.0
		if d.length() > 0.05:
			vel = d.normalized() * speed
			if face_move:
				face_to(global_position + d, delta)
	_apply_move(vel, delta)
	return arrived


func stand(delta: float) -> void:
	_apply_move(Vector3.ZERO, delta)


func _apply_move(vel: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, vel.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, vel.z, 30.0 * delta)
	if is_on_floor():
		velocity.y = -1.0
	else:
		velocity.y -= 14.0 * delta
	move_and_slide()


## هل يوجد خط رؤية بين عيني هذه الشخصية والنقطة؟
func can_see(point: Vector3, max_dist := 45.0) -> bool:
	var from := eye()
	if from.distance_to(point) > max_dist:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, point, 1 | 32)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func hurt(dmg: float, from: Vector3, head := false, by_player := true) -> void:
	if dead:
		return
	hp -= dmg
	on_hurt(from, by_player)
	if hp <= 0.0:
		die(by_player, head)


func on_hurt(_from: Vector3, _by_player: bool) -> void:
	pass


func die(_by_player := true, _head := false) -> void:
	dead = true
	collision_layer = 0
	collision_mask = 1
	set_physics_process(true)
	play("Death01", 1.1, 0.1)
	Audio.play_at("body", global_position, -4.0)
	if gun:
		gun.visible = true
	corpses.append(self)
	while corpses.size() > 10:
		var c = corpses.pop_front()
		if is_instance_valid(c):
			c.queue_free()
