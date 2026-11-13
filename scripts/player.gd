class_name Player
extends CharacterBody3D
## اللاعب على قدميه.

const WALK := 3.4
const RUN := 7.2
const JUMP := 6.5
const GRAVITY := 19.0

var rig: CharacterRig
var in_car = null
var _face := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	rig = CharacterRig.new()
	add_child(rig)
	rig.build(0, null, true)


func _physics_process(delta: float) -> void:
	if in_car != null or Game.state != Game.State.PLAYING:
		return
	var iv := Game.joy
	iv.x += Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	iv.y += Input.get_action_strength("brake") - Input.get_action_strength("gas")
	if iv.length() > 1.0:
		iv = iv.normalized()
	var yaw: float = Game.cam.yaw if Game.cam else 0.0
	var dir := Vector3(iv.x, 0, iv.y).rotated(Vector3.UP, yaw)
	var running := Input.is_action_pressed("run") or iv.length() > 0.93
	var sp: float = (RUN if running else WALK) * min(1.0, iv.length() * 1.25)
	var target: Vector3 = dir.normalized() * sp if iv.length() > 0.08 else Vector3.ZERO
	var acc := 14.0 if is_on_floor() else 4.0
	velocity.x = move_toward(velocity.x, target.x, acc * delta * 2.0)
	velocity.z = move_toward(velocity.z, target.z, acc * delta * 2.0)
	if is_on_floor():
		if Game.consume("jump"):
			velocity.y = JUMP
			Sfx.play("jump", -8.0)
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs > 0.3:
		_face = atan2(-velocity.x, -velocity.z)
	rig.rotation.y = lerp_angle(rig.rotation.y, _face, min(1.0, delta * 12.0))
	rig.animate(hs, delta, is_on_floor())
	if global_position.y < -5.0:
		global_position.y = 2.0


func enter_car(car) -> void:
	in_car = car
	visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO


func exit_car() -> void:
	var car = in_car
	in_car = null
	var b: Basis = car.global_transform.basis
	var base: Vector3 = car.global_position
	var spots := [-b.x * 1.9, b.x * 1.9, b.z * 3.2, -b.z * 3.2]
	var space := get_world_3d().direct_space_state
	var chosen: Vector3 = base + spots[0]
	for s in spots:
		var p: Vector3 = base + s + Vector3(0, 1.0, 0)
		var q := PhysicsShapeQueryParameters3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 0.4
		q.shape = sh
		q.transform = Transform3D(Basis.IDENTITY, p)
		q.collision_mask = 1 | 2
		if space.intersect_shape(q, 1).is_empty():
			chosen = base + s
			break
	global_position = Vector3(chosen.x, 0.05, chosen.z)
	_face = car.rotation.y
	rig.rotation.y = _face
	visible = true
	collision_layer = 4
	collision_mask = 1 | 2
