extends Node
## اختبار آلي: يشغّل اللعبة ويلتقط صوراً (يعمل فقط مع --autotest).

var dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dir = OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://shots"
	DirAccess.make_dir_recursive_absolute(dir)
	_run()


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + n + ".png")
	print("shot ", n)


func wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout


func _run() -> void:
	var m = Game.main
	await wait(2.0)
	await shot("01_menu")
	Game.help_seen = false
	m.start_game()
	await wait(0.5)
	await shot("02_help")
	m.menu._close_sub()
	await wait(1.5)
	await shot("03_foot")
	Game.joy = Vector2(0.3, -1)
	await wait(1.2)
	await shot("04_run")
	Game.joy = Vector2.ZERO
	# قرب السيارة
	m.player.global_position = m.city.start_car["pos"] + Vector3(-2.6, 0.1, 0)
	await wait(0.6)
	await shot("05_near_car")
	Game.tap("interact")
	await wait(0.4)
	var car = Game.car
	print("in car: ", car != null)
	car.global_position = City.node_pos(5, 6) + Vector3(-City.LANE, 0, -20)
	car.rotation.y = 0
	m.cam.snap()
	Input.action_press("gas")
	await wait(3.0)
	await shot("06_drive")
	print("speed ", car.speed, " pos ", car.global_position)
	Input.action_press("steer_right")
	await wait(1.0)
	Input.action_release("steer_right")
	await wait(1.5)
	await shot("07_drive2")
	Input.action_release("gas")
	# مهمة تاكسي
	car.velocity = Vector3.ZERO
	car.global_position = m.missions.defs[0]["pos"] + Vector3(4, 0, 0)
	m.cam.snap()
	await wait(0.6)
	await shot("08_mission_prompt")
	Game.tap("mission")
	await wait(1.0)
	await shot("09_mission")
	print("mission active: ", m.missions.is_active(), " target ", m.missions.target)
	m.missions.cancel()
	# الليل
	m.daynight.hour = 21.5
	car.global_position = City.node_pos(4, 4) + Vector3(-City.LANE, 0, 60)
	car.rotation.y = 0
	m.cam.snap()
	Input.action_press("gas")
	await wait(2.5)
	await shot("10_night")
	Input.action_release("gas")
	# الغروب عند الشاطئ
	m.daynight.hour = 18.0
	car.velocity = Vector3.ZERO
	car.global_position = Vector3(60, 0, 370)
	car.rotation.y = -1.2
	m.cam.snap()
	m.cam.yaw = 2.6
	await wait(1.5)
	await shot("11_beach")
	# منظر عام
	m.daynight.hour = 10.0
	Game.tap("interact")
	await wait(0.3)
	m.player.global_position = City.block_center(2, 5) + Vector3(0, 0.1, 30)
	m.cam.snap()
	m.cam.yaw = 0.0
	await wait(1.2)
	await shot("12_mosque")
	m.player.global_position = City.block_center(6, 3) + Vector3(0, 0.1, 18)
	m.cam.snap()
	m.cam.yaw = 0.3
	await wait(1.0)
	await shot("13_showroom")
	m.player.global_position = City.block_center(3, 4) + Vector3(12, 0.1, 14)
	m.cam.snap()
	m.cam.yaw = 0.8
	await wait(1.0)
	await shot("14_park")
	Game.tap("pause")
	await wait(0.4)
	await shot("15_pause")
	print("fps ", Engine.get_frames_per_second(), " cars ", Game.cars.size())
	print("draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
