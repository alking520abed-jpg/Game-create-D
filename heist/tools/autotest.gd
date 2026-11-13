extends Node
## لقطات آلية من اللعبة (--autotest). SHOT_DIR يحدد مجلد الحفظ، SHOT_CH الفصل.

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
	var ch := int(OS.get_environment("SHOT_CH")) if OS.get_environment("SHOT_CH") != "" else -1
	if not Game.pending_start and Game.state == Game.State.MENU and ch >= 0 and not Game.has_meta("shot_started"):
		Game.set_meta("shot_started", true)
		await wait(1.0)
		await shot("00_menu")
		m.goto_chapter(ch)
		return
	if ch < 0:
		await wait(1.5)
		await shot("00_menu")
		get_tree().quit()
		return
	await wait(1.0)
	await shot("c%d_01_brief" % ch)
	m.start_play()
	await wait(1.5)
	await shot("c%d_02_start" % ch)
	var p: Player = Game.player
	# نظرة حول المكان
	for i in 3:
		p.set_look(p.yaw + PI / 2)
		await wait(0.4)
		await shot("c%d_03_look%d" % [ch, i])
	p.ads = true
	await wait(0.5)
	await shot("c%d_04_ads" % ch)
	p.ads = false
	Game.held["fire"] = true
	await wait(0.12)
	await shot("c%d_05_fire" % ch)
	Game.held["fire"] = false
	# قرب أقرب عدو
	if m.enemies.size() > 0:
		var e: Enemy = m.enemies[0]
		var back := e.global_transform.basis.z
		p.global_position = e.global_position - back * 5.0
		p.velocity = Vector3.ZERO
		var to := e.global_position - p.global_position
		p.set_look(atan2(-to.x, -to.z))
		await wait(0.25)
		await shot("c%d_06_enemy" % ch)
		await wait(2.0)
		await shot("c%d_07_combat" % ch)
	print("fps ", Engine.get_frames_per_second(), " draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
