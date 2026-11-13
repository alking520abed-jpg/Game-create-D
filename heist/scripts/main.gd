extends Node3D
## المشهد الرئيسي: يبني العالم ويدير الشخصيات والفصول.

var bank: Bank
var player: Player
var hud: HUD
var menu: Menu
var story: Story
var env: Environment
var sun: DirectionalLight3D
var enemies: Array = []
var crew: Array = []
var civs: Array = []
var menu_cam: Camera3D
var _mt := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Game.main = self
	Game.world = self
	Actor.corpses.clear()
	FX.clear()
	Audio.stop_all_loops()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest" or a == "--simtest":
			Game.test_mode = true
	_environment()
	bank = Bank.new()
	add_child(bank)
	bank.build()
	player = Player.new()
	add_child(player)
	player.global_position = bank.pts["start"]
	Game.player = player
	menu_cam = Camera3D.new()
	menu_cam.fov = 60.0
	add_child(menu_cam)
	story = Story.new()
	add_child(story)
	Game.story = story
	hud = HUD.new()
	add_child(hud)
	Game.hud = hud
	menu = Menu.new()
	add_child(menu)
	Game.settings_changed.connect(apply_quality)
	apply_quality()
	if Game.test_mode:
		for a in OS.get_cmdline_user_args():
			if a == "--autotest" or a == "--simtest":
				add_child(load("res://tools/%s.gd" % a.substr(2)).new())
	if Game.pending_start:
		Game.pending_start = false
		begin_chapter()
	else:
		Game.set_state(Game.State.MENU)
		menu_cam.current = true
		bank.set_police(true)
		Audio.music("music_tense")
		menu.show_screen("main")


func _environment() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.05, 0.08, 0.2)
	sm.sky_horizon_color = Color(0.62, 0.38, 0.3)
	sm.ground_horizon_color = Color(0.3, 0.22, 0.22)
	sm.ground_bottom_color = Color(0.05, 0.05, 0.07)
	sm.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.76, 0.74)
	env.ambient_light_energy = 0.62
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.15
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.3, 0.33)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, -152, 0)
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.3
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.06
	add_child(sun)


func apply_quality() -> void:
	var q: int = Game.settings["quality"]
	sun.visible = q > 0
	sun.shadow_enabled = q > 0
	env.ambient_light_energy = 0.75 if q == 0 else 0.62
	env.glow_enabled = q > 0
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	get_viewport().scaling_3d_scale = [0.7, 0.85, 1.0][q]
	get_viewport().msaa_3d = Viewport.MSAA_2X if q == 2 else Viewport.MSAA_DISABLED


# ---------------------------------------------------------------- الفصول
func goto_chapter(i: int) -> void:
	Game.chapter = clamp(i, 0, Game.CHAPTERS.size() - 1)
	Game.pending_start = true
	Game.set_state(Game.State.MENU)
	menu.show_loading()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()


func begin_chapter() -> void:
	bank.set_police(false)
	player.cam.current = true
	story.prepare(Game.chapter)
	Game.set_state(Game.State.BRIEFING)
	menu.show_briefing(Game.chapter)


func start_play() -> void:
	menu.show_screen("")
	Game.reset_stats()
	Game.set_state(Game.State.PLAYING)
	player.capture_mouse(true)
	story.run(Game.chapter)


func to_menu() -> void:
	Game.pending_start = false
	Game.set_state(Game.State.MENU)
	player.capture_mouse(false)
	get_tree().reload_current_scene()


# ---------------------------------------------------------------- الشخصيات
func spawn_enemy(kind: String, pos: Vector3, yaw := 0.0, alerted := false) -> Enemy:
	var e := Enemy.new()
	add_child(e)
	e.init(kind, pos, yaw)
	enemies.append(e)
	if alerted:
		e.alert(false)
	return e


func spawn_crew(cname: String, dname: String, pos: Vector3, yaw := 0.0) -> Crew:
	var c := Crew.new()
	add_child(c)
	c.init(cname, dname, pos, yaw)
	c.slot = crew.size()
	crew.append(c)
	return c


func spawn_civ(cname: String, pos: Vector3, yaw := 0.0, idle := "Idle") -> Civilian:
	var c := Civilian.new()
	add_child(c)
	c.init(cname, pos, yaw, idle)
	civs.append(c)
	return c


func spawn_pickup(kind: String, pos: Vector3) -> Pickup:
	var p := Pickup.new()
	add_child(p)
	p.init(kind, pos)
	return p


func alive_enemies() -> int:
	var n := 0
	for e in enemies:
		if not e.dead:
			n += 1
	return n


## ضجيج (طلقة، صراخ): ينبّه الحراس القريبين ويُفزع المدنيين
func noise(pos: Vector3, radius: float) -> void:
	for e in enemies:
		if not e.dead and e.st == Enemy.St.GUARD and e.global_position.distance_to(pos) < radius and abs(e.global_position.y - pos.y) < 4.0:
			e.alert(false)
	for c in civs:
		if not c.dead and not c.panic and c.global_position.distance_to(pos) < radius:
			c.set_panic(true)


func on_enemy_died(e: Enemy) -> void:
	var r := _rng.randf()
	var p := e.global_position
	if e.kind == "boss":
		spawn_pickup("med", p + Vector3(0.5, 0, 0))
		spawn_pickup("armor", p + Vector3(-0.5, 0, 0))
	elif r < 0.5:
		spawn_pickup("ammo", p)
	elif r < 0.64:
		spawn_pickup("med", p)
	elif r < 0.72:
		spawn_pickup("armor", p)
	enemies.erase(e)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if Game.state == Game.State.PLAYING:
			menu.open_pause()
		elif Game.state == Game.State.PAUSED:
			menu.resume()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		Game.save_game()
		if Game.state == Game.State.PLAYING:
			menu.open_pause()


func _process(delta: float) -> void:
	if Game.state == Game.State.MENU:
		_mt += delta * 0.05
		menu_cam.position = Vector3(sin(_mt) * 20.0, 5.0 + sin(_mt * 0.7) * 1.5, 40.0)
		menu_cam.look_at(Vector3(0, 5.0, 22.0))
	elif Game.state == Game.State.PLAYING:
		if Game.consume("pause"):
			menu.open_pause()
	elif Game.state == Game.State.PAUSED:
		if Game.consume("pause"):
			menu.resume()
