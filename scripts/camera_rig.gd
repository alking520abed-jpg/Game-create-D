class_name CameraRig
extends Node3D
## كاميرا تتبع اللاعب أو السيارة، مع تدوير باللمس.

var yaw := 0.0
var pitch := 0.3
var arm: SpringArm3D
var cam: Camera3D
var dist := 5.0
var _manual := 0.0
var _mode := 0
var _menu_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arm = SpringArm3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	arm.shape = sh
	arm.collision_mask = 1
	arm.spring_length = dist
	arm.margin = 0.2
	add_child(arm)
	cam = Camera3D.new()
	cam.far = 1400.0
	cam.near = 0.15
	cam.fov = 68.0
	arm.add_child(cam)
	cam.make_current()


func look(delta_px: Vector2) -> void:
	yaw -= delta_px.x * 0.0052
	pitch = clamp(pitch + delta_px.y * 0.004, -0.25, 1.2)
	_manual = 2.0


func toggle_mode() -> void:
	_mode = (_mode + 1) % 3


func _process(delta: float) -> void:
	if Game.state == Game.State.MENU:
		_menu_t += delta
		var a := _menu_t * 0.06 + 0.9
		global_position = Vector3(36, 3, 36)
		yaw = a
		pitch = 0.32
		arm.spring_length = 150.0
		arm.collision_mask = 0
		arm.rotation = Vector3(-pitch, yaw, 0)
		return
	if get_tree().paused:
		return
	arm.collision_mask = 1
	var car = Game.car
	var target: Vector3
	var want := 5.0
	if car != null:
		target = car.global_position + Vector3(0, 1.6, 0)
		want = [8.5, 12.5, 5.5][_mode] + abs(car.speed) * 0.06
		_manual -= delta
		if _manual <= 0.0 and abs(car.speed) > 1.5:
			var back := 0.0 if car.speed > -2.0 else PI
			yaw = lerp_angle(yaw, car.rotation.y + back, min(1.0, delta * 3.2))
			pitch = lerp(pitch, [0.26, 0.42, 0.2][_mode], min(1.0, delta * 2.0))
		cam.fov = lerp(cam.fov, 68.0 + clamp(abs(car.speed), 0.0, 45.0) * 0.3, min(1.0, delta * 3.0))
	elif Game.player != null:
		target = Game.player.global_position + Vector3(0, 1.55, 0)
		want = [5.0, 7.5, 3.2][_mode]
		cam.fov = lerp(cam.fov, 68.0, min(1.0, delta * 3.0))
	else:
		return
	dist = lerp(dist, want, min(1.0, delta * 4.0))
	arm.spring_length = dist
	global_position = global_position.lerp(target, min(1.0, delta * 14.0))
	arm.rotation = Vector3(-pitch, yaw, 0)


func snap() -> void:
	if Game.car != null:
		global_position = Game.car.global_position + Vector3(0, 1.6, 0)
		yaw = Game.car.rotation.y
	elif Game.player != null:
		global_position = Game.player.global_position + Vector3(0, 1.55, 0)
