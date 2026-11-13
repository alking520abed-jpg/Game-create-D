extends Node3D
## المشهد الرئيسي: يبني العالم ويدير اللعب.

const AI_COUNT := [8, 13, 18]
const PED_COUNT := [8, 14, 22]

var city: City
var daynight: DayNight
var cam: CameraRig
var player: Player
var missions: Missions
var hud: HUD
var menu: Menu
var peds: Array = []
var abandoned: Array = []
var start_car: Car
var _tick := 0.0
var _edge_cd := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Game.main = self
	Game.cars = []
	Game.car = null
	Game.state = Game.State.MENU
	city = City.new()
	add_child(city)
	city.build()
	Game.city = city
	daynight = DayNight.new()
	add_child(daynight)
	cam = CameraRig.new()
	add_child(cam)
	Game.cam = cam
	player = Player.new()
	add_child(player)
	player.global_position = city.start_pos
	Game.player = player
	_spawn_cars()
	missions = Missions.new()
	add_child(missions)
	Game.missions = missions
	missions.setup()
	hud = HUD.new()
	add_child(hud)
	hud.touch.look.connect(cam.look)
	menu = Menu.new()
	add_child(menu)
	Game.settings_changed.connect(_on_settings)
	Game.skin_changed.connect(_on_skin)
	_on_settings()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest" or a == "--simtest":
			add_child(load("res://tools/%s.gd" % a.substr(2)).new())


func _notification(what: int) -> void:
	# زر الرجوع في الأندرويد + الحفظ عند الخروج من التطبيق
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if Game.state == Game.State.PLAYING:
			menu.open_pause()
		elif Game.state == Game.State.PAUSED:
			menu.resume()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		Game.save_game()
		if Game.state == Game.State.PLAYING and what == NOTIFICATION_APPLICATION_PAUSED:
			menu.open_pause()


func _new_car(id: String, col: Color) -> Car:
	var c := Car.new()
	add_child(c)
	c.setup(id, col)
	Game.cars.append(c)
	return c


func _rand_color() -> Color:
	return Color(Car.COLORS[_rng.randi() % Car.COLORS.size()])


func _rand_type() -> String:
	var r := _rng.randf()
	if r < 0.5:
		return "sedan"
	if r < 0.7:
		return "taxi"
	if r < 0.88:
		return "pickup"
	return "suv"


func _spawn_cars() -> void:
	var sc := _new_car("sedan", Color("c0392b"))
	sc.global_position = city.start_car["pos"]
	sc.rotation.y = city.start_car["yaw"]
	sc.apply_skin(Game.skin)
	start_car = sc
	for s in city.parked_spots:
		var id := _rand_type()
		var c := _new_car(id, Color("f1c40f") if id == "taxi" else _rand_color())
		c.global_position = s["pos"]
		c.rotation.y = s["yaw"]
	var show := [["suv", 1500, Color("2e8b57")], ["sport", 3500, Color("e67e22")], ["super", 8000, Color("d4af37")]]
	for i in city.showroom_spots.size():
		var s = city.showroom_spots[i]
		var c := _new_car(show[i][0], show[i][2])
		c.global_position = s["pos"]
		c.rotation.y = s["yaw"]
		c.set_price(show[i][1])


func _spawn_ai(near: Vector3, min_d: float, max_d: float, car: Car = null) -> void:
	for tries in 14:
		var lane := City.random_lane(_rng)
		var p: Vector3 = lane["pos"]
		var d := p.distance_to(near)
		if d < min_d or d > max_d:
			continue
		var ok := true
		for o in Game.cars:
			if o != car and o.global_position.distance_to(p) < 16.0:
				ok = false
				break
		if not ok:
			continue
		if car == null:
			var id := _rand_type()
			if id == "suv":
				id = "sedan"
			car = _new_car(id, Color("f1c40f") if id == "taxi" else _rand_color())
		car.ai_start(lane)
		return


## السكن المختار يُطبَّق على السيارة التي تقودها (أو سيارتك عند نقطة البداية)
func _on_skin() -> void:
	if Game.car != null:
		Game.car.apply_skin(Game.skin)
	elif is_instance_valid(start_car):
		start_car.apply_skin(Game.skin)


func _on_settings() -> void:
	daynight.apply_quality()
	var q: int = Game.settings["quality"]
	# المشاة
	while peds.size() < PED_COUNT[q]:
		var p := Pedestrian.new()
		add_child(p)
		p.place_near(Game.pos() if Game.player else city.start_pos, 15.0, 160.0)
		peds.append(p)
	while peds.size() > PED_COUNT[q]:
		peds.pop_back().queue_free()


func start_game() -> void:
	menu.show_screen("")
	Game.set_state(Game.State.PLAYING)
	cam.snap()
	if not Game.help_seen:
		Game.set_state(Game.State.PAUSED)
		menu.open_help("play")
	else:
		Game.banner.emit("مدينة النخيل", "اركب سيارة وانطلق نحو الدوائر الملوّنة لبدء المهمات", Color(1.0, 0.86, 0.35))


func to_menu() -> void:
	Game.save_game()
	Game.set_state(Game.State.MENU)
	Sfx.engine_set(false)
	menu.show_screen("main")


func unstuck() -> void:
	if Game.car != null:
		Game.car.global_position = city.start_car["pos"] + Vector3(0, 0, 8)
		Game.car.velocity = Vector3.ZERO
		Game.car.speed = 0.0
	else:
		player.global_position = city.start_pos
		player.velocity = Vector3.ZERO
	cam.snap()


func _interact() -> void:
	if Game.car != null:
		var c: Car = Game.car
		if abs(c.speed) > 4.0:
			Game.notify("خفّف السرعة أولاً ثم انزل", Color(1, 0.7, 0.4))
			return
		c.set_mode(Car.Mode.PARKED)
		Game.car = null
		player.exit_car()
		Sfx.play("door")
		if not abandoned.has(c):
			abandoned.append(c)
	elif Game.near_car != null:
		var c: Car = Game.near_car
		if c.locked():
			if Game.money >= c.price:
				c.unlock()
				Game.add_money(-c.price)
				Sfx.play("success")
				Game.banner.emit("مبروك السيارة!", "اشتريت: " + c.spec["name"], Color(0.4, 1.0, 0.5))
			else:
				Game.notify("تحتاج %d ريال — أنجز مهمات لتجمع النقود" % c.price, Color(1, 0.6, 0.4))
				Sfx.play("fail", -10.0)
			return
		player.enter_car(c)
		c.apply_skin(Game.skin)
		c.set_mode(Car.Mode.PLAYER)
		Game.car = c
		abandoned.erase(c)
		Sfx.play("door")


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		Sfx.engine_set(false)
		if Game.state == Game.State.PAUSED and Game.consume("pause") and menu.pause_box.visible:
			menu.resume()
		return
	# أقرب سيارة
	Game.near_car = null
	if Game.car == null:
		var best := 4.4
		for c in Game.cars:
			var d: float = c.global_position.distance_to(player.global_position)
			if d < best and abs(c.speed) < 6.0:
				best = d
				Game.near_car = c
	if Game.consume("interact"):
		_interact()
	if Game.consume("cam"):
		cam.toggle_mode()
	if Game.consume("pause"):
		menu.open_pause()
		return
	if Game.car != null:
		var c: Car = Game.car
		Sfx.engine_set(true, abs(c.speed) / c.spec["max"], Input.get_action_strength("gas"))
	else:
		Sfx.engine_set(false)
	# حدود الخريطة
	_edge_cd -= delta
	var pp := Game.pos()
	if _edge_cd < 0.0 and (abs(pp.x) > City.BOUND - 8 or pp.z < -City.BOUND + 8):
		_edge_cd = 6.0
		Game.notify("وصلت نهاية الخريطة — ارجع نحو المدينة")
	_tick += delta
	if _tick > 0.7:
		_tick = 0.0
		_manage(pp)


func _manage(pp: Vector3) -> void:
	var q: int = Game.settings["quality"]
	var ai := 0
	for c in Game.cars:
		if c.mode == Car.Mode.AI:
			ai += 1
			if c.global_position.distance_to(pp) > 280.0:
				_spawn_ai(pp, 110.0, 250.0, c)
	if ai < AI_COUNT[q]:
		_spawn_ai(pp, 60.0 if Game.cars.size() < 60 and _tick == 0.0 and ai < 3 else 110.0, 260.0)
	# السيارات المتروكة البعيدة
	for c in abandoned.duplicate():
		if c.global_position.distance_to(pp) > 240.0 and (abandoned.size() > 2 or c.global_position.distance_to(pp) > 420.0):
			if c.price > 0:
				abandoned.erase(c)
				continue
			abandoned.erase(c)
			Game.cars.erase(c)
			c.queue_free()
	for p in peds:
		if p.global_position.distance_to(pp) > 190.0:
			p.place_near(pp, 60.0, 150.0)
