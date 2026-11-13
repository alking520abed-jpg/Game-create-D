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


func put(p: Vector3, yaw := 0.0) -> void:
	var pl: Player = Game.player
	pl.global_position = p + Vector3(0, 0.15, 0)
	pl.velocity = Vector3.ZERO
	pl._face = yaw
	pl.rig.rotation.y = yaw
	Game.cam.yaw = yaw
	Game.cam.pitch = 0.22
	Game.cam.snap()


func _run() -> void:
	var m = Game.main
	var pl: Player = m.player
	var c: Combat = Game.combat
	var st: Story = m.story
	Game.reset_save()
	Game.help_seen = true
	await wait(2.0)
	await shot("01_menu")
	# المشهد الافتتاحي
	m.start_game()
	await wait(2.5)
	await shot("02_intro_oasis")
	for i in 2:
		st.cut._advance()
		await wait(0.4)
		st.cut._advance()
		await wait(1.6)
	await shot("03_intro_saif")
	for i in 3:
		st.cut._advance()
		await wait(0.4)
		st.cut._advance()
		await wait(1.6)
	await shot("04_intro_plaza")
	st.cut.skip_all()
	await wait(1.2)
	await shot("05_ch1_start")
	# جلمود يقاتل
	pl.morph(1)
	await wait(1.0)
	await shot("06_jalmood")
	Game.joy = Vector2(0, -1)
	await wait(1.0)
	Game.joy = Vector2.ZERO
	Input.action_press("attack")
	await wait(0.5)
	await shot("07_punch")
	await wait(0.6)
	Input.action_release("attack")
	Game.tap("special")
	await wait(0.75)
	await shot("08_slam")
	await wait(1.0)
	for e in c.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	await wait(1.0)
	await shot("09_outro")
	st.cut.skip_all()
	await wait(3.5)
	# بقية الهيئات في لعب حر
	Game.chapter = 7
	Game.unlocked = 5
	st._ambient_t = 1e9
	var base := City.node_pos(4, 6) + Vector3(20, 0, 0)
	put(base, PI / 2)
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(2)
	for i in 4:
		c.spawn("soldier", base + Vector3(-14 - i * 3, 0.1, (i % 2) * 4 - 2))
	await wait(1.2)
	await shot("10_wameed")
	Game.tap("special")
	await wait(0.12)
	await shot("11_chain")
	await wait(0.5)
	for e in c.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(4)
	for i in 3:
		c.spawn("mutant", base + Vector3(-18 - i * 3, 0.1, i * 3 - 3))
	await wait(1.0)
	Input.action_press("attack")
	await wait(0.34)
	await shot("12_nabd_laser")
	Input.action_release("attack")
	Game.tap("special")
	await wait(0.4)
	await shot("13_shield")
	for e in c.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(5)
	await wait(1.0)
	await shot("14_tayf")
	Game.tap("special")
	await wait(0.8)
	await shot("15_vanish")
	# لهيب يطير
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(3)
	put(City.node_pos(4, 5) + Vector3(0, 0, 20), 0.0)
	Input.action_press("fly_up")
	Game.joy = Vector2(0, -1)
	await wait(2.2)
	Input.action_release("fly_up")
	Game.cam.pitch = 0.45
	await wait(0.6)
	await shot("16_laheeb_fly")
	for i in 3:
		c.spawn("thug", pl.global_position * Vector3(1, 0, 1) + Vector3(i * 3 - 3, 0.1, -30))
	Input.action_press("attack")
	await wait(1.0)
	await shot("17_fireballs")
	Input.action_release("attack")
	Game.joy = Vector2.ZERO
	for e in c.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(9999.0)
	pl.revert(true)
	await wait(1.5)
	# الزعيم الأخير
	Game.chapter = 6
	Game.hp = 100.0
	put(st.marker_pos(6))
	await wait(0.5)
	await shot("18_marker")
	Game.tap("mission")
	await wait(2.5)
	await shot("19_boss_intro")
	st.cut.skip_all()
	await wait(1.0)
	pl.morph(1)
	Game.cam.yaw = 0.0
	await wait(1.5)
	await shot("20_boss_fight")
	print("fps ", Engine.get_frames_per_second(), " cars ", Game.cars.size())
	print("draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	Game.reset_save()
	get_tree().quit()
