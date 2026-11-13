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
	# الجزء الأول يختبر القيادة والمهمات الجانبية في وضع اللعب الحر (بعد القصة)
	Game.chapter = Story.CHAPTERS
	Game.unlocked = 5
	m.story._ambient_t = 1e9
	Engine.time_scale = 4.0
	await wait(0.5)
	m.start_game()
	await wait(1.0)
	if OS.get_cmdline_user_args().has("--quick"):
		await _hero(m)
		print("RESULT fails=", fails)
		get_tree().quit(1 if fails > 0 else 0)
		return
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
	await _hero(m)
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


func _kill_all() -> void:
	for e in Game.combat.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			e.take_damage(99999.0)


func _hero(m) -> void:
	var pl: Player = m.player
	var c: Combat = Game.combat
	var st: Story = m.story
	var base := City.block_center(4, 5) + Vector3(0, 0, 33)   # وسط شارع فارغ
	print("== التحوّل ==")
	put(base)
	await wait(0.3)
	for i in range(1, 6):
		Game.energy = 100.0
		pl.morph_cd = 0.0
		pl.morph(i)
		await wait(0.3)
		check(pl.form == i and pl.rig.model_id == Player.FORMS[i]["model"] and pl.rig.ap != null, "هيئة %s (مجسم %s)" % [Player.FORMS[i]["name"], pl.rig.model_id])
	pl.revert(true)
	check(pl.form == 0 and pl.rig.model_id == "saif", "العودة للهيئة البشرية")
	check(pl.rig.has_anim("walk") and pl.rig.has_anim("attack") and pl.rig.has_anim("death"), "أنيميشن البطل موجود")
	print("== جلمود: لكمة وزلزال ==")
	pl.morph_cd = 0.0
	pl.morph(1)
	pl._face = 0.0
	var e1 := c.spawn("thug", base + Vector3(0, 0.1, -2.5))
	e1.passive = true
	Input.action_press("attack")
	await wait(1.2)
	Input.action_release("attack")
	check(e1.dead or e1.hp < 40.0, "اللكمة تصيب العدو (hp=%.0f)" % e1.hp)
	_kill_all()
	var grp := []
	for i in 3:
		var g := c.spawn("soldier", base + Vector3(cos(i * 2.1) * 5.0, 0.1, sin(i * 2.1) * 5.0))
		g.passive = true
		grp.append(g)
	Game.tap("special")
	await wait(1.6)
	var hurt := 0
	for g in grp:
		if g.dead or g.hp < 55.0:
			hurt += 1
	check(hurt == 3, "الزلزال يصيب كل من حوله (%d/3)" % hurt)
	_kill_all()
	print("== تدمير سيارة ==")
	var car2: Car = m._new_car("sedan", Color.WHITE)
	car2.global_position = base + Vector3(4.5, 0, 0)
	pl.sp_cd = 0.0
	Game.tap("special")
	await wait(1.6)
	check(car2.mode == Car.Mode.WRECK, "السيارة انفجرت وصارت حطاماً")
	print("== لهيب: طيران وكرات نار ==")
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(3)
	put(base + Vector3(0, 0, 12))
	Input.action_press("fly_up")
	await wait(1.0)
	Input.action_release("fly_up")
	check(pl.global_position.y > 4.0, "الطيران: الارتفاع %.1f م" % pl.global_position.y)
	var e2 := c.spawn("soldier", pl.global_position + Vector3(0, -pl.global_position.y + 0.1, -18))
	e2.passive = true
	pl._face = 0.0
	Input.action_press("attack")
	await wait(2.0)
	Input.action_release("attack")
	check(e2.dead or e2.hp < 55.0, "كرة النار تصيب من الجو (hp=%.0f)" % e2.hp)
	_kill_all()
	Input.action_press("fly_down")
	await wait(1.5)
	Input.action_release("fly_down")
	print("== نبض: ليزر ودرع ==")
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(4)
	put(base)
	await wait(0.4)
	var e3 := c.spawn("thug", base + Vector3(-15, 0.1, 3))   # على امتداد الشارع
	e3.passive = true
	pl._face = PI / 2
	Input.action_press("attack")
	await wait(1.5)
	Input.action_release("attack")
	check(e3.dead, "الليزر يقتل عن بعد (hp=%.0f، بُعد=%.1f)" % [e3.hp, e3.global_position.distance_to(pl.global_position)])
	Game.tap("special")
	await wait(0.3)
	var hp0 := Game.hp
	pl.hurt(50.0, base)
	check(pl.shield > 0.0 and Game.hp == hp0, "الدرع يمنع الضرر")
	print("== وميض: سرعة وصاعقة ==")
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(2)
	put(base)
	var p1: Vector3 = pl.global_position
	Game.cam.yaw = PI / 2
	Game.joy = Vector2(0, -1)
	await wait(1.5)
	Game.joy = Vector2.ZERO
	var run_d := pl.global_position.distance_to(p1)
	check(run_d > 22.0, "سرعة وميض: %.0f م في 1.5 ث" % run_d)
	for i in 3:
		c.spawn("thug", pl.global_position + Vector3(4 + i * 3, 0.1, 3)).passive = true
	await wait(0.2)
	Game.tap("special")
	await wait(0.5)
	check(c.alive() == 0, "الصاعقة المتسلسلة تقتل الثلاثة (بقي %d)" % c.alive())
	print("== طيف: اختفاء ==")
	Game.energy = 100.0
	pl.morph_cd = 0.0
	pl.morph(5)
	put(base)
	await wait(0.3)
	Game.tap("special")
	await wait(0.3)
	var e4 := c.spawn("soldier", base + Vector3(0, 0.1, -8), false)
	await wait(1.5)
	check(pl.invisible > 0.0 and not e4.alert, "الحارس لا يرى الطيف")
	_kill_all()
	pl.revert(true)
	print("== الأعداء يؤذون البطل، والسقوط والعودة ==")
	Game.hp = 100.0
	put(base)
	c.spawn("mutant", base + Vector3(0, 0.1, -3))
	await wait(3.0)
	check(Game.hp < 100.0, "المتحوّل يضرب البطل (hp=%.0f)" % Game.hp)
	Game.hp = 1.0
	await wait(2.5)
	check(pl.dead, "البطل يسقط عند انتهاء الصحة")
	_kill_all()
	await wait(4.0)
	check(not pl.dead and Game.hp == Game.MAX_HP, "يعود البطل بصحة كاملة")
	print("== القصة: الفصول السبعة ==")
	Game.chapter = 0
	Game.unlocked = 0
	Game.choice = ""
	st.cut.auto = true
	await wait(1.0)
	check(st.active and Game.unlocked == 1 and c.alive() == 4, "الفصل 1 بدأ: جلمود مفتوح و%d بلطجية" % c.alive())
	check(st.objective != "", "الهدف ظاهر: " + st.objective)
	_kill_all()
	await wait(2.4)
	check(Game.chapter == 1 and not st.active, "اكتمل الفصل 1")
	for ch in range(1, 7):
		put(st.marker_pos(ch))
		await wait(0.5)
		check(st.near, "عمود الفصل %d قريب" % (ch + 1))
		Game.tap("mission")
		await wait(0.8)
		check(st.active and Game.chapter == ch, "بدأ الفصل %d: %s" % [ch + 1, Story.TITLES[ch]])
		match ch:
			2:
				check(st._devices.size() == 4 and st.timer > 0.0, "أربعة أجهزة ومؤقت")
				for d in st._devices.duplicate():
					c.hit_props(d.global_position + Vector3(0, 0.6, 0), 1.0, 999.0)
					await wait(0.3)
			3:
				_kill_all()
				await wait(0.6)
				check(c.alive() == 6, "السرب الثاني (%d)" % c.alive())
				_kill_all()
			4:
				check(st.boss != null and st.boss.kind == "mech", "آلي الحراسة موجود")
				_kill_all()
			5:
				check(Game.unlocked == 5, "طيف مفتوح")
				pl.morph_cd = 0.0
				pl.morph(5)
				Game.tap("special")
				await wait(0.3)
				put(st.DEPOT)
				await wait(2.6)
				check(not st._spotted, "تسلّل دون أن يُكشف")
			6:
				check(st.boss != null and st.boss.kind == "boss", "راكان موجود")
				st.boss.take_damage(st.boss.max_hp * 0.4)
				await wait(0.4)
				check(c.alive() > 1, "موجة تعزيزات (%d)" % c.alive())
				_kill_all()
				await wait(0.4)
				_kill_all()
			_:
				_kill_all()
		await wait(2.6)
		check(Game.chapter == ch + 1 and not st.active, "اكتمل الفصل %d" % (ch + 1))
	check(Game.unlocked == 5 and Game.choice != "", "كل الهيئات مفتوحة والاختيار محفوظ (%s)" % Game.choice)
	st.cut.auto = false
	st._ambient_t = 1e9
	Game.hp = Game.MAX_HP
	print("== جرائم الشوارع ==")
	put(City.block_center(4, 5) + Vector3(0, 0, 33))
	st._ambient_t = 0.0
	await wait(0.5)
	check(c.alive() >= 2, "ظهرت عصابة قريبة (%d)" % c.alive())
	_kill_all()
	st._ambient_t = 1e9
	await wait(0.5)
