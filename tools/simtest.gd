extends Node
## اختبار منطق اللعب بدون رسم (--simtest).

var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, false).timeout


func check(cond: bool, what: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func put(p: Vector3, yaw := 0.0) -> void:
	var c = Game.car
	if c != null:
		c.global_position = Vector3(p.x, 0, p.z)
		c.rotation.y = yaw
		c.velocity = Vector3.ZERO
		c.speed = 0.0
	else:
		Game.player.global_position = Vector3(p.x, 0.1, p.z)
		Game.player.velocity = Vector3.ZERO


func _run() -> void:
	var m = Game.main
	var ms: Missions = m.missions
	Game.reset_save()
	Game.help_seen = true
	Engine.time_scale = 4.0
	await wait(0.5)
	m.start_game()
	await wait(1.0)
	print("== مشي وقفز ==")
	var p0: Vector3 = m.player.global_position
	Game.joy = Vector2(0, -1)
	await wait(2.0)
	Game.joy = Vector2.ZERO
	check(m.player.global_position.distance_to(p0) > 5.0, "اللاعب يمشي: %.1f م" % m.player.global_position.distance_to(p0))
	Game.tap("jump")
	await wait(0.25)
	check(m.player.global_position.y > 0.3, "القفز")
	await wait(1.5)
	print("== مهمة تحتاج سيارة بدون سيارة ==")
	put(ms.defs[0]["pos"])
	await wait(0.5)
	check(ms.near != null, "المهمة القريبة ظاهرة")
	Game.tap("mission")
	await wait(0.5)
	check(not ms.is_active(), "لا تبدأ بدون سيارة")
	print("== القطة (على الأقدام) ==")
	put(ms.defs[9]["pos"])
	await wait(0.5)
	Game.tap("mission")
	await wait(0.5)
	check(ms.is_active() and ms.active["type"] == "cat", "بدأت مهمة القطة")
	put(ms._cat.position + Vector3(1, 0, 0))
	await wait(0.6)
	check(ms.step == 1, "وجد القطة")
	put(ms.defs[9]["pos"] + Vector3(2, 0, 0))
	await wait(0.6)
	check(not ms.is_active() and Game.money >= 220, "اكتملت مهمة القطة، النقود=%d" % Game.money)
	print("== ركوب وقيادة ==")
	put(m.city.start_car["pos"] + Vector3(-2.5, 0, 0))
	await wait(0.4)
	check(Game.near_car != null, "السيارة القريبة")
	Game.tap("interact")
	await wait(0.4)
	check(Game.car != null, "ركب السيارة")
	var car = Game.car
	put(City.node_pos(5, 6) + Vector3(-City.LANE, 0, -20))
	Input.action_press("gas")
	await wait(4.0)
	check(car.speed > 20.0, "السرعة %.0f كم/س" % (car.speed * 3.6))
	Input.action_press("steer_left")
	var y0: float = car.rotation.y
	await wait(0.6)
	Input.action_release("steer_left")
	check(car.rotation.y > y0 + 0.2, "الانعطاف يساراً")
	Input.action_release("gas")
	Input.action_press("brake")
	await wait(2.5)
	Input.action_release("brake")
	check(car.speed < 3.0, "الفرامل (%.1f)" % car.speed)
	Input.action_press("brake")
	await wait(2.0)
	Input.action_release("brake")
	check(car.speed < -1.0, "الرجوع للخلف (%.1f)" % car.speed)
	print("== تاكسي ==")
	put(ms.defs[0]["pos"] + Vector3(3, 0, 0))
	await wait(0.5)
	Game.tap("mission")
	await wait(0.5)
	check(ms.is_active() and ms.active["type"] == "taxi", "بدأ التاكسي")
	put(ms.target)
	await wait(0.5)
	check(ms.step == 1 and ms.timer > 0, "ركب الراكب، الوقت=%.0f" % ms.timer)
	var money0 := Game.money
	put(ms.target)
	await wait(0.5)
	check(not ms.is_active() and Game.money > money0, "اكتمل التاكسي +%d" % (Game.money - money0))
	print("== توصيل ==")
	put(ms.defs[2]["pos"] + Vector3(0, 0, -3))
	await wait(0.5)
	Game.tap("mission")
	await wait(0.5)
	check(ms.is_active() and ms.active["type"] == "delivery", "بدأ التوصيل")
	for i in 3:
		put(ms.target)
		await wait(0.5)
	check(not ms.is_active(), "اكتمل التوصيل، النقود=%d" % Game.money)
	print("== سباقات ==")
	for ri in [4, 5, 6]:
		put(ms.defs[ri]["pos"] + Vector3(2, 0, 0))
		await wait(0.5)
		Game.tap("mission")
		await wait(0.5)
		check(ms.is_active() and ms.countdown > 0, "عد تنازلي " + ms.active["title"])
		await wait(4.0)
		var n := ms._pts.size()
		for i in n:
			if ms.is_active():
				put(ms.target)
				await wait(0.3)
		check(not ms.is_active() and Game.best.has(ms.defs[ri]["id"]), "اكتمل السباق (%d بوابة)" % n)
	print("== اصطفاف ==")
	put(ms.defs[7]["pos"] + Vector3(-2, 0, 0))
	await wait(0.5)
	Game.tap("mission")
	await wait(0.5)
	check(ms.is_active() and ms.active["type"] == "parking", "بدأ الاصطفاف")
	put(ms._spot_xf.origin + Vector3(0.3, 0, 0.3), ms._spot_xf.basis.get_euler().y + PI + 0.1)
	await wait(1.6)
	check(not ms.is_active(), "اكتمل الاصطفاف")
	print("== فشل بالوقت ==")
	put(ms.defs[3]["pos"] + Vector3(-3, 0, 0))
	await wait(0.5)
	Game.tap("mission")
	await wait(0.5)
	ms.timer = 0.3
	await wait(0.8)
	check(not ms.is_active(), "تفشل المهمة عند انتهاء الوقت")
	print("== نجمة ==")
	var s0 := Game.stars.size()
	put(ms.star_nodes[3].position)
	await wait(0.4)
	check(Game.stars.size() == s0 + 1, "جمع نجمة")
	print("== نزول وشراء ==")
	Game.tap("interact")
	await wait(0.4)
	check(Game.car == null and m.player.visible, "نزل من السيارة")
	var sp = m.city.showroom_spots[0]
	put(sp["pos"] + Vector3(2.6, 0, 0))
	await wait(0.4)
	check(Game.near_car != null and Game.near_car.locked(), "سيارة المعرض مقفلة")
	Game.money = 100
	Game.tap("interact")
	await wait(0.4)
	check(Game.car == null, "لا شراء بدون نقود")
	Game.money = 2000
	Game.tap("interact")
	await wait(0.4)
	check(Game.money == 500 and Game.owned.has("suv"), "اشترى الجيب")
	Game.tap("interact")
	await wait(0.4)
	check(Game.car != null and Game.car.spec_id == "suv", "ركب الجيب")
	Game.tap("interact")
	await wait(0.4)
	print("== المرور لمدة 90 ثانية ==")
	put(City.block_center(4, 5) + Vector3(0, 0, 0))
	var start := {}
	for c in Game.cars:
		if c.mode == Car.Mode.AI:
			start[c] = c.global_position
	await wait(90.0)
	var ai := 0
	var stuck := 0
	var off := 0
	var moved := 0
	for c in Game.cars:
		if c.mode == Car.Mode.AI:
			ai += 1
			if abs(c.speed) < 0.3:
				stuck += 1
			if City.surface_at(c.global_position) != 0:
				off += 1
			if start.has(c) and c.global_position.distance_to(start[c]) > 100.0:
				moved += 1
	print("  AI=%d واقفة=%d خارج الشارع=%d تحركت>100م=%d مشاة=%d" % [ai, stuck, off, moved, m.peds.size()])
	check(ai >= 10, "عدد سيارات المرور")
	check(stuck <= 3, "السيارات الواقفة قليلة")
	check(off <= 1, "السيارات على الشارع")
	Game.tap("pause")
	await wait(0.1)
	check(Game.state == Game.State.PAUSED, "الإيقاف المؤقت")
	m.menu.resume()
	Game.reset_save()
	print("RESULT fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
