class_name Story
extends Node
## سيناريو اللعبة: ستة فصول، كل فصل سلسلة أهداف وحوارات وموجات أعداء.

const ENG := "المهندس"
const NASR := "نسر"
const THURAYA := "ثريا"
const SHIHAB := "شهاب"

const BRIEFS := [
	"اسمعوني جيداً. بنك الاتحاد الوطني يحتفظ في قبوه بأربعين سبيكة ذهب تعود لأناس نهبوا البلد قبلنا.\n\nدخلتم رصيف التحميل متنكرين بشاحنة الصيانة. في الطابق الأرضي ستة حراس مسلحين.\n\n• حيّدوا الحراس قبل أن يستوعبوا ما يجري.\n• أقفلوا أبواب البنك من لوحة التحكم عند المدخل.\n• الرهائن خط أحمر: لا أحد يلمسهم.",
	"الإنذار الصامت اشتغل قبل أوانه — أحد الحراس ضغطه وهو يسقط.\n\nغرفة الأمن في الطابق العلوي ترسل الصور مباشرة إلى مركز الشرطة. أمامك دقائق قبل أن يعرفوا عددنا ومواقعنا.\n\n• اصعد الدرج الكبير وعطّل غرفة الأمن.\n• في خزانة السلاح هناك شوزن — خذه.\n• المدير العام يحمل بطاقة الخزنة. أحضرها.",
	"البطاقة تفتح البوابة الخارجية فقط. باب الخزنة نفسه فولاذ بسماكة نصف متر، وله موعد مع مثقابنا الحراري.\n\nالقبو تحرسه نخبة حراس البنك. وبعد أن يبدأ المثقاب، ستكون الشرطة قد طوّقت المبنى وستحاول الدخول من الكراج.\n\n• نظّف القبو.\n• ثبّت المثقاب على باب الخزنة واحمِه حتى ينتهي.\n• إن تعطّل المثقاب أعد تشغيله فوراً.",
	"ها هي. أربعون سبيكة… لكن وزنها لا يسمح إلا بأربع حقائب.\n\nشهاب يفتح الآن ثغرة في جدار غرفة المضخات نحو نفق الصرف القديم. انقلوا الحقائب إليه واحدة واحدة.\n\n• احمل حقيبة من الخزنة وأوصلها إلى غرفة المضخات.\n• وأنت تحمل الذهب حركتك أبطأ — دع نسر وثريا يغطّيانك.\n• الشرطة ستضغط من الكراج ومن الدرج.",
	"مفاوضهم أنهى المكالمة. هذا يعني شيئاً واحداً: القوات الخاصة ستقتحم.\n\nسيأتون من الباب الرئيسي أولاً، ثم من الممر الخلفي، ثم من الشرفات. وقائدهم لا يدخل إلا في النهاية.\n\n• اصمد في الصالة ثلاث موجات حتى يفتح شهاب النفق.\n• استخدم الأعمدة والكاونتر ساتراً.\n• الرهائن خلفكم — انتبه لرصاصك.",
	"النفق مفتوح. انتهى وقتنا في هذا المبنى.\n\nانزلوا إلى غرفة المضخات واعبروا نفق الصرف حتى القناة حيث تنتظرنا الشاحنة. الشرطة اكتشفت النفق من الطرف الآخر، فتوقعوا مقاومة.\n\n• لديك أربع دقائق قبل أن يُغرقوا المبنى بالغاز.\n• لا تتوقف. لا تلتفت.\n• نلتقي عند الشاحنة.",
]

var token := 0
var failed := false
var w: Node
var bank: Bank
var hostage_hits := 0
var _drill: Node3D
var _time_left := -1.0
var _time_label := ""
var _time_total := 1.0


func _ready() -> void:
	w = get_parent()


func _process(delta: float) -> void:
	if _time_left > 0.0 and Game.state == Game.State.PLAYING:
		_time_left -= delta
		Game.hud.set_task("%s  %d:%02d" % [_time_label, int(_time_left) / 60, int(_time_left) % 60], _time_left / _time_total)
		if _time_left <= 0.0:
			fail("انتهى الوقت")


# ---------------------------------------------------------------- أدوات
func _alive(t: int) -> bool:
	return t == token and not failed and is_inside_tree() and Game.state != Game.State.DEAD


func _wait(t: int, sec: float) -> bool:
	var e := 0.0
	while e < sec:
		await get_tree().physics_frame
		if not _alive(t):
			return false
		if Game.state == Game.State.PLAYING or Game.state == Game.State.CUTSCENE:
			e += get_physics_process_delta_time()
	return true


func _until(t: int, cond: Callable) -> bool:
	while true:
		await get_tree().physics_frame
		if not _alive(t):
			return false
		if Game.state == Game.State.PLAYING and cond.call():
			return true
	return false


func obj(text: String, pos = null) -> void:
	Game.objective_changed.emit(text)
	Game.hud.waypoint = pos
	if text != "":
		Audio.play("objective", -10.0)


func _reach(t: int, pos: Vector3, r := 3.0) -> bool:
	Game.hud.waypoint = pos + Vector3(0, 1.2, 0)
	return await _until(t, func():
		var p: Vector3 = Game.player.global_position
		return Vector2(p.x - pos.x, p.z - pos.z).length() < r and abs(p.y - pos.y) < 2.6)


func _use(t: int, pos: Vector3, prompt: String, hold: float) -> bool:
	var it := Interactable.new(prompt, hold)
	w.add_child(it)
	it.global_position = pos
	Game.hud.waypoint = pos
	var st := [false]
	it.done.connect(func(): st[0] = true)
	var ok := await _until(t, func(): return st[0])
	if not ok and is_instance_valid(it):
		it.queue_free()
	return ok


func _dead_all(list: Array) -> bool:
	for e in list:
		if is_instance_valid(e) and not e.dead:
			return false
	return true


func _nearest_alive(list: Array):
	var best = null
	var bd := 1e9
	for e in list:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(Game.player.global_position)
			if d < bd:
				bd = d
				best = e
	return best


## انتظر موت كل القائمة مع تحديث العداد والمؤشّر
func _clear(t: int, list: Array, text: String) -> bool:
	var total := list.size()
	var last := -1
	while true:
		await get_tree().physics_frame
		if not _alive(t):
			return false
		var left := 0
		for e in list:
			if is_instance_valid(e) and not e.dead:
				left += 1
		if left != last:
			last = left
			Game.objective_changed.emit("%s (%d/%d)" % [text, total - left, total])
		var n = _nearest_alive(list)
		Game.hud.waypoint = n.global_position + Vector3(0, 2.1, 0) if n else null
		if left == 0:
			return true
	return false


func timer(label: String, sec: float) -> void:
	_time_label = label
	_time_left = sec
	_time_total = sec


func timer_stop() -> void:
	_time_left = -1.0
	Game.hud.set_task("", 0.0)


func fail(reason: String) -> void:
	if failed or Game.state == Game.State.WIN:
		return
	failed = true
	Game.set_state(Game.State.DEAD)
	Audio.play("fail")
	Game.main.menu.show_end(false, "فشلت المهمة", reason)


func hostage_down() -> void:
	fail("أصبتَ أحد الرهائن. قاعدتنا الأولى: لا يتأذى بريء.")


func _complete(t: int, line: String, final := false) -> void:
	if not _alive(t):
		return
	timer_stop()
	obj("")
	Game.complete_chapter(Game.chapter)
	Game.set_state(Game.State.WIN)
	Audio.play("objective")
	Audio.music("music_tense")
	var s: Dictionary = Game.stats
	var acc := 0 if s["shots"] == 0 else int(100.0 * s["hits"] / s["shots"])
	var text := "%s\n\nالأعداء المحيَّدون: %d   •   إصابات الرأس: %d\nالدقة: %d%%   •   الوقت: %d:%02d\nالنقاط: %d" % [line, s["kills"], s["heads"], acc, int(s["time"]) / 60, int(s["time"]) % 60, Game.best.get(Game.chapter, 0)]
	if final:
		text += "\n\nأربع حقائب من الذهب، وطاقم كامل، ولا رهينة أصيبت.\nشكراً لأنك لعبت «الخزنة»."
	Game.main.menu.show_end(true, "النهاية" if final else "اكتمل الفصل %d" % (Game.chapter + 1), text, final)


func _crew(n: String) -> Crew:
	for c in w.crew:
		if c.display_name == n:
			return c
	return null


func _spawn_wave(kinds: Array, at: Vector3, spread := 2.0) -> Array:
	var out := []
	for i in kinds.size():
		var p := at + Vector3(randf_range(-spread, spread), 0, randf_range(-spread, spread))
		p = NavigationServer3D.map_get_closest_point(w.get_world_3d().navigation_map, p)
		out.append(w.spawn_enemy(kinds[i], p, 0.0, true))
	return out


func _cutscene(t: int, shots: Array) -> bool:
	## shots: [[from, to, look, dur, speaker, text]]
	Game.set_state(Game.State.CUTSCENE)
	var cam: Camera3D = w.menu_cam
	cam.current = true
	for s in shots:
		cam.position = s[0]
		cam.look_at(s[2])
		if s[5] != "":
			Game.say(s[4], s[5], s[3] - 0.2)
		var tw := create_tween()
		tw.tween_property(cam, "position", s[1], s[3])
		var e := 0.0
		while e < s[3]:
			await get_tree().process_frame
			if t != token or not is_inside_tree():
				return false
			cam.look_at(s[2])
			e += get_process_delta_time()
			if Game.consume("interact") or Game.consume("jump") or Game.is_held("fire"):
				e = s[3]
				tw.kill()
	Game.player.cam.current = true
	Game.set_state(Game.State.PLAYING)
	return true


# ---------------------------------------------------------------- تجهيز العالم لكل فصل
func prepare(ch: int) -> void:
	bank = w.bank
	var p: Player = Game.player
	var pts: Dictionary = bank.pts
	p.give("smg")
	if ch >= 2:
		p.give("shotgun")
	if ch >= 4:
		p.give("rifle")
	p.equip("smg")
	# المدنيون
	var civ_chars := ["civ_m1", "civ_f1", "civ_m2", "civ_f2", "civ_f1", "civ_m1", "teller_f", "teller_f"]
	var idles := ["Idle", "Idle_Talking", "Idle", "Idle_Talking", "Idle", "Idle", "Idle", "Idle"]
	for i in bank.hostage_spots.size():
		var hs: Array = bank.hostage_spots[i]
		var c: Civilian = w.spawn_civ(civ_chars[i], hs[0], hs[1], idles[i])
		if ch >= 1:
			c.set_panic(true)
	match ch:
		0:
			p.global_position = pts["start"]
			p.set_look(PI)
			w.spawn_crew("crew_nasr", NASR, Vector3(15.2, 0, -20.8), PI)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(17.6, 0, -21.2), PI)
			w.spawn_crew("crew_shihab", SHIHAB, Vector3(18.8, 0, -23.0), PI)
		1:
			p.global_position = Vector3(0, 0, 10)
			p.set_look(0.0)
			w.spawn_crew("crew_nasr", NASR, Vector3(-6, 0, 16), PI)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(6, 0, 14), PI)
			w.spawn_crew("crew_shihab", SHIHAB, Vector3(0, 0, 3.5), 0.0)
			w.spawn_civ("manager", pts["manager_spot"], 0.0, "Idle")
		2:
			p.global_position = Vector3(0, Bank.U, -8)
			p.set_look(PI / 2)
			w.spawn_crew("crew_nasr", NASR, Vector3(-3, Bank.U, -8), PI / 2)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(3, Bank.U, -8), PI / 2)
			w.spawn_crew("crew_shihab", SHIHAB, Vector3(0, 0, 3.5), 0.0)
		3:
			bank.open_gate("vault", true)
			bank.open_gate("garage", true)
			p.global_position = Vector3(0, Bank.B, -12.5)
			p.set_look(0.0)
			w.spawn_crew("crew_nasr", NASR, Vector3(-4.5, Bank.B, -3.4), PI)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(-16.5, Bank.B, 1.5), 0.0)
			w.spawn_crew("crew_shihab", SHIHAB, Vector3(-21.5, Bank.B, 12.5), -PI / 2)
			bank.set_police(true)
		4:
			bank.open_gate("vault", true)
			bank.open_gate("garage", true)
			p.global_position = Vector3(0, 0, 1.5)
			p.set_look(PI)
			w.spawn_crew("crew_nasr", NASR, Vector3(-8.0, 0, 6.2), PI)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(8.0, 0, 6.2), PI)
			bank.set_police(true)
		5:
			bank.open_gate("vault", true)
			bank.open_gate("garage", true)
			bank.open_gate("front", true)
			p.global_position = Vector3(0, 0, -3.5)
			p.set_look(0.0)
			w.spawn_crew("crew_nasr", NASR, Vector3(-2.5, 0, -3.5), 0.0)
			w.spawn_crew("crew_thuraya", THURAYA, Vector3(2.5, 0, -3.5), 0.0)
			w.spawn_crew("crew_shihab", SHIHAB, Vector3(-20.5, Bank.B, 12.0), 0.0)
			bank.set_police(true)
	p.health_changed.emit()


func run(ch: int) -> void:
	token += 1
	failed = false
	Audio.music("music_tense")
	call("_ch%d" % ch, token)


# ================================================================ الفصل ١: الدخول
func _ch0(t: int) -> void:
	var pts: Dictionary = bank.pts
	var guards := []
	var g: Enemy = w.spawn_enemy("guard", Vector3(-10, 0, -8), PI / 2)
	g.patrol = [Vector3(-12, 0, -8), Vector3(11, 0, -8)]
	guards.append(g)
	guards.append(w.spawn_enemy("guard", Vector3(-9.5, 0, 3.0), 0.0))
	guards.append(w.spawn_enemy("guard", Vector3(9.5, 0, 4.0), 0.0))
	guards.append(w.spawn_enemy("guard", Vector3(-3.5, 0, 18.0), 0.0))
	guards.append(w.spawn_enemy("guard", Vector3(3.5, 0, 18.5), 0.0))
	g = w.spawn_enemy("guard", Vector3(-18, 0, 0.5), -PI / 2)
	g.patrol = [Vector3(-18, 0, 2.0), Vector3(-18, 0, 14.0)]
	guards.append(g)
	if not Game.test_mode:
		if not await _cutscene(t, [
			[Vector3(-26, 3, 46), Vector3(-14, 4, 42), Vector3(0, 5, 22), 5.0, ENG, "بنك الاتحاد الوطني. أربعون سبيكة ذهب تنام تحت أقدام موظفين لا يعرفون ما في القبو."],
			[Vector3(9.5, 2.6, -13.5), Vector3(11.5, 2.2, -16.5), Vector3(16.5, 1.2, -22), 4.5, ENG, "شاحنة الصيانة أدخلتكم رصيف التحميل. من هنا لا رجوع."]]):
			return
	for c in w.crew:
		c.follow = true
	Game.say(ENG, "سهيل، أنت تقود. ستة حراس في الطابق الأرضي. أسقطوهم بسرعة.")
	Game.say(NASR, "خلفك يا سهيل. تحرّك.")
	if not await _clear(t, guards, "حيّد حراس الطابق الأرضي"):
		return
	Audio.music("music_tense")
	Game.say(NASR, "الطابق نظيف.")
	Game.say(ENG, "جميل. الآن أقفلوا الأبواب قبل أن يخرج أحد.")
	obj("أقفل أبواب البنك من لوحة التحكم", pts["lock_panel"])
	if not await _use(t, pts["lock_panel"], "إقفال أبواب البنك", 2.0):
		return
	Audio.play_at("door", pts["lobby_door_in"], 4.0, 0.6)
	for c in w.civs:
		c.set_panic(true)
	_crew(NASR).go(Vector3(-6, 0, 16))
	_crew(THURAYA).go(Vector3(6, 0, 14))
	_crew(SHIHAB).go(Vector3(0, 0, 3.5))
	Game.say(THURAYA, "الجميع على الأرض! التزموا الهدوء ولن يتأذى أحد.")
	if not await _wait(t, 3.5):
		return
	Game.say(ENG, "المرحلة الأولى انتهت. البنك لنا… مؤقتاً.")
	if not await _wait(t, 3.0):
		return
	_complete(t, "أحكمتم السيطرة على الصالة وأقفلتم الأبواب.")


# ================================================================ الفصل ٢: غرفة التحكم
func _ch1(t: int) -> void:
	var pts: Dictionary = bank.pts
	bank.set_alarm(true)
	Audio.loop_at("alarm", "alarm_loop", Vector3(0, 6, 0), -6.0)
	var U := Bank.U
	var list := []
	list.append(w.spawn_enemy("guard", Vector3(-12, U, 2), PI))
	list.append(w.spawn_enemy("guard", Vector3(3, U, -4), PI))
	list.append(w.spawn_enemy("guard", Vector3(-10, U, -8), -PI / 2))
	list.append(w.spawn_enemy("guard", Vector3(12, U, -8), PI / 2))
	list.append(w.spawn_enemy("guard", Vector3(13, U, -22), PI))
	list.append(w.spawn_enemy("guard", Vector3(19, U, -17), PI))
	var body := []
	body.append(w.spawn_enemy("guard", Vector3(-3, U, -17), PI))
	body.append(w.spawn_enemy("guard", Vector3(3.5, U, -19), PI))
	Game.say(ENG, "الإنذار اشتغل! غرفة الأمن في الطابق العلوي ترسل صورنا للشرطة. عطّلها حالاً.")
	timer("قبل وصول صوركم للشرطة", 210.0)
	obj("اصعد وعطّل غرفة الأمن", pts["console"])
	if not await _use(t, pts["console"], "تعطيل الكاميرات والإنذار", 3.0):
		return
	timer_stop()
	bank.set_alarm(false)
	Audio.stop_loop("alarm")
	Audio.play("objective")
	Game.say(THURAYA, "الكاميرات عمياء والإنذار صامت. أحسنت.")
	w.spawn_pickup("weapon:shotgun", pts["gun_locker"] - Vector3(0, 1.0, 0) + Vector3(0.6, 0, 0))
	w.spawn_pickup("armor", pts["security_room"] + Vector3(3, 0, 2))
	Game.say(ENG, "في خزانة السلاح شوزن. خذه، ثم اذهب إلى مكتب المدير العام وأحضر بطاقة الخزنة.")
	obj("خذ بطاقة الخزنة من المدير العام", pts["manager_spot"] + Vector3(0, 1.3, 0))
	if not await _use(t, pts["manager_spot"] + Vector3(0, 1.2, 0.6), "أخذ بطاقة الخزنة", 1.5):
		return
	Audio.play("pickup")
	Game.say("المدير العام", "خذوها… خذوا كل شيء، فقط لا تؤذوا الموظفين.")
	Game.say(ENG, "البطاقة معنا. انزلوا إلى القبو.")
	if not await _wait(t, 4.5):
		return
	_complete(t, "عطّلتَ غرفة الأمن وحصلتَ على بطاقة الخزنة.")


# ================================================================ الفصل ٣: الخزنة
func _build_drill(pos: Vector3) -> void:
	_drill = Node3D.new()
	w.add_child(_drill)
	_drill.global_position = pos
	var db := Builder.new(_drill)
	db.cyl(Vector3(0, 0, 0.9), Vector3(0, 0, 0.1), 0.16, "#c9411e:0.4:0.5", 12, false)
	db.cyl(Vector3(0, 0, 0.1), Vector3(0, 0, -0.35), 0.05, "steel", 8, false)
	db.box(Vector3(0, 0.22, 0.7), Vector3(0.3, 0.14, 0.3), "#22262d:0.5:0.4", false)
	for sx in [-1.0, 1.0]:
		db.cyl(Vector3(sx * 0.12, -0.1, 0.5), Vector3(sx * 0.6, -1.2, 1.0), 0.03, "steel_dark", 6, false)
	db.cyl(Vector3(0, -0.1, 0.85), Vector3(0, -1.2, 1.5), 0.03, "steel_dark", 6, false)
	db.commit()
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.15)
	l.light_energy = 2.5
	l.omni_range = 5.0
	l.position = Vector3(0, 0, -0.3)
	l.name = "glow"
	_drill.add_child(l)
	var sp := CPUParticles3D.new()
	sp.name = "sparks"
	sp.amount = 24
	sp.lifetime = 0.5
	sp.position = Vector3(0, 0, -0.32)
	sp.direction = Vector3(0, 0.3, 1)
	sp.spread = 50.0
	sp.initial_velocity_min = 2.0
	sp.initial_velocity_max = 5.0
	sp.gravity = Vector3(0, -9, 0)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.03, 0.03)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.75, 0.3)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = m
	sp.mesh = qm
	_drill.add_child(sp)


func _drill_on(on: bool) -> void:
	_drill.get_node("sparks").emitting = on
	_drill.get_node("glow").visible = on
	if on:
		Audio.loop_at("drill", "drill_loop", _drill.global_position, 2.0)
	else:
		Audio.stop_loop("drill")


func _ch2(t: int) -> void:
	var pts: Dictionary = bank.pts
	var B := Bank.B
	for c in w.crew:
		c.follow = true
	_crew(SHIHAB).follow = false
	var list := []
	list.append(w.spawn_enemy("guard", Vector3(-18, B, -1), 0.0))
	list.append(w.spawn_enemy("guard", Vector3(18, B, -1), 0.0))
	list.append(w.spawn_enemy("guard", Vector3(-8, B, 0.8), -PI / 2))
	list.append(w.spawn_enemy("guard", Vector3(8, B, 0.8), PI / 2))
	list.append(w.spawn_enemy("police", Vector3(0, B, -5), PI))
	list.append(w.spawn_enemy("police", Vector3(2, B, 12), 0.0))
	Game.say(ENG, "القبو تحت الجناحين. انزل الدرج عند «الخزنة ↓» ونظّف المحيط.")
	if not await _clear(t, list, "انزل إلى القبو ونظّف محيط الخزنة"):
		return
	Game.say(NASR, "القبو لنا.")
	obj("ثبّت المثقاب الحراري على باب الخزنة", pts["drill"])
	if not await _use(t, pts["drill"], "تثبيت المثقاب الحراري", 3.0):
		return
	_build_drill(pts["drill"] + Vector3(0, 0, 0.45))
	_drill_on(true)
	_crew(NASR).go(Vector3(-4.5, B, -3.3))
	_crew(THURAYA).go(Vector3(4.5, B, -3.3))
	Game.say(SHIHAB, "المثقاب يعمل! يحتاج دقيقتين تقريباً.")
	if not await _wait(t, 5.0):
		return
	bank.set_police(true)
	bank.open_gate("garage")
	Audio.loop_at("siren", "siren_loop", Vector3(0, 0, 30), -4.0)
	Audio.music("music_action")
	Game.say(ENG, "الشرطة طوّقت المبنى وفتحت باب الكراج. احمِ المثقاب مهما كلّف!")
	obj("احمِ المثقاب حتى يفتح الخزنة", pts["drill"])
	var prog := 0.0
	var total := 105.0
	var next_wave := 2.0
	var jams := [0.36, 0.7]
	var wave_i := 0
	while prog < 1.0:
		await get_tree().physics_frame
		if not _alive(t):
			_drill_on(false)
			return
		if Game.state != Game.State.PLAYING:
			continue
		var dt := get_physics_process_delta_time()
		prog += dt / total
		Game.hud.set_task("تقدّم المثقاب", prog)
		next_wave -= dt
		if next_wave <= 0.0 and w.alive_enemies() < 6:
			next_wave = 13.0
			wave_i += 1
			var kinds := ["police", "police"]
			if wave_i >= 3:
				kinds.append("police")
			if wave_i >= 5:
				kinds.append("swat")
			var from: Vector3 = pts["garage_spawn"] if wave_i % 3 != 0 else pts["stairs_e_bottom"]
			_spawn_wave(kinds, from)
		if not jams.is_empty() and prog >= jams[0]:
			jams.pop_front()
			_drill_on(false)
			Audio.play("fail", -6.0)
			Game.say(SHIHAB, "المثقاب تعطّل! أعد تشغيله بسرعة!")
			obj("أعد تشغيل المثقاب!", pts["drill"])
			if not await _use(t, pts["drill"] + Vector3(0, 0, 0.9), "إعادة تشغيل المثقاب", 1.5):
				_drill_on(false)
				return
			_drill_on(true)
			obj("احمِ المثقاب حتى يفتح الخزنة", pts["drill"])
	_drill_on(false)
	Game.hud.set_task("", 0.0)
	_drill.queue_free()
	FX.explosion(w, pts["drill"])
	bank.open_gate("vault")
	Audio.music("music_tense")
	Game.say(SHIHAB, "انفتحت! الخزنة مفتوحة!")
	Game.say(ENG, "ها قد وصلنا إلى قلب البنك.")
	if not await _wait(t, 5.0):
		return
	_complete(t, "اخترق المثقاب نصف متر من الفولاذ. الخزنة مفتوحة.")


# ================================================================ الفصل ٤: الذهب
func _ch3(t: int) -> void:
	var pts: Dictionary = bank.pts
	var B := Bank.B
	w.spawn_pickup("weapon:rifle", Vector3(-7.5, B, -12.5))
	w.spawn_pickup("armor", Vector3(7.5, B, -12.5))
	w.spawn_pickup("med", pts["armory"])
	Audio.loop_at("siren", "siren_loop", Vector3(0, 0, 30), -6.0)
	Game.say(ENG, "أربعون سبيكة… ولا وقت إلا لأربع حقائب. بندقية الحرس على يسارك، خذها.")
	Game.say(SHIHAB, "أنا في غرفة المضخات أفتح الثغرة. أحضروا الذهب إليّ!")
	for i in 4:
		obj("املأ حقيبة ذهب (%d/4)" % (i + 1), pts["gold%d" % i])
		if not await _use(t, pts["gold%d" % i] + Vector3(0, 0.9, -0.6), "تعبئة حقيبة ذهب", 1.6):
			return
		Game.player.carrying = true
		Audio.play("cash")
		Audio.music("music_action")
		var kinds := ["police", "police"]
		if i >= 1:
			kinds.append("police")
		if i >= 2:
			kinds.append("swat")
		if i >= 3:
			kinds.append("swat")
		_spawn_wave(kinds, pts["garage_spawn"] if i % 2 == 0 else pts["stairs_e_bottom"])
		if i == 0:
			Game.say(NASR, "شرطة من الكراج! امضِ يا سهيل، نحن نغطّيك!")
		obj("أوصل الحقيبة إلى غرفة المضخات (%d/4)" % (i + 1), pts["tunnel_mouth"])
		if not await _reach(t, pts["tunnel_mouth"], 2.8):
			return
		Game.player.carrying = false
		Game.stats["gold"] += 1
		Audio.play("cash")
		Game.notify("حقيبة ذهب في النفق: %d/4" % (i + 1), Color(1.0, 0.85, 0.3))
		if i == 1:
			Game.say(SHIHAB, "نصف الطريق! الجدار بدأ يتشقق.")
		if i < 3 and randf() < 0.7:
			w.spawn_pickup("ammo", pts["vault_lobby"] + Vector3(randf_range(-3, 3), 0, randf_range(-2, 2)))
	Audio.music("music_tense")
	Game.say(SHIHAB, "أربع حقائب! لكن النفق يحتاج دقائق بعد.")
	Game.say(ENG, "والقوات الخاصة تتجمع عند الباب الرئيسي. اصعدوا إلى الصالة… الآن.")
	if not await _wait(t, 6.0):
		return
	_complete(t, "أربع حقائب ذهب جاهزة عند فوهة النفق.")


# ================================================================ الفصل ٥: الحصار
func _ch4(t: int) -> void:
	var pts: Dictionary = bank.pts
	Audio.loop_at("siren", "siren_loop", Vector3(0, 0, 30), -3.0)
	w.spawn_pickup("armor", Vector3(-6, 0, -3.8))
	w.spawn_pickup("med", Vector3(6, 0, -3.8))
	w.spawn_pickup("ammo", Vector3(0, 0, -3.8))
	Game.say(ENG, "انتهت المفاوضات. سيقتحمون من الباب الرئيسي خلال ثوانٍ. خذوا سواتركم!")
	obj("استعد: خذ ساتراً خلف الأعمدة", pts["lobby"])
	if not await _wait(t, 7.0):
		return
	bank.open_gate("front")
	FX.explosion(w, Vector3(0, 1.5, 22.0))
	Audio.play_at("glass", Vector3(0, 2, 22), 4.0)
	Audio.music("music_action")
	var front := Vector3(0, 0, 26.5)
	# الموجة الأولى
	Game.hud.set_task("النفق: شهاب يحفر", 0.1)
	var wave := _spawn_wave(["police", "police", "police", "police", "police"], front, 3.0)
	Game.say(NASR, "اقتحموا! أطلقوا النار!")
	if not await _clear(t, wave, "الموجة الأولى: اصمد في الصالة"):
		return
	Game.hud.set_task("النفق: شهاب يحفر", 0.4)
	Game.say(THURAYA, "الموجة الأولى سقطت. أعيدوا التلقيم!")
	w.spawn_pickup("ammo", Vector3(-3, 0, 6))
	w.spawn_pickup("med", Vector3(3, 0, 6))
	if not await _wait(t, 7.0):
		return
	# الموجة الثانية: الأمام + الممر الخلفي
	Game.say(ENG, "انتبهوا! فرقة ثانية تلتف من الممر الخلفي!")
	wave = _spawn_wave(["police", "police", "swat"], front, 3.0)
	wave.append_array(_spawn_wave(["police", "swat"], Vector3(16, 0, -12.5), 1.5))
	wave.append_array(_spawn_wave(["police"], Vector3(-16, 0, -8), 1.0))
	if not await _clear(t, wave, "الموجة الثانية: من الأمام والخلف"):
		return
	Game.hud.set_task("النفق: شهاب يحفر", 0.7)
	Game.say(SHIHAB, "أحتاج دقيقة واحدة فقط! اصمدوا!")
	w.spawn_pickup("ammo", Vector3(0, 0, 9))
	w.spawn_pickup("armor", Vector3(-3, 0, 2))
	w.spawn_pickup("med", Vector3(3, 0, 2))
	if not await _wait(t, 7.0):
		return
	# الموجة الثالثة: الشرفات + القائد
	Game.say(ENG, "القوات الخاصة على الشرفات! وقائدهم يدخل من الباب!")
	wave = _spawn_wave(["swat", "swat"], Vector3(-19, Bank.U, 2), 1.5)
	wave.append_array(_spawn_wave(["swat", "swat"], Vector3(19, Bank.U, 2), 1.5))
	wave.append_array(_spawn_wave(["swat", "police", "police"], front, 3.0))
	var boss: Enemy = w.spawn_enemy("boss", front + Vector3(0, 0, 2), PI, true)
	wave.append(boss)
	var last := -1.0
	while not _dead_all(wave):
		await get_tree().physics_frame
		if not _alive(t):
			return
		if is_instance_valid(boss) and not boss.dead:
			if boss.hp != last:
				last = boss.hp
				Game.hud.set_task("قائد القوة", boss.hp / boss.max_hp)
			Game.hud.waypoint = boss.global_position + Vector3(0, 2.3, 0)
			Game.objective_changed.emit("الموجة الأخيرة: أسقط قائد القوة")
		else:
			var n = _nearest_alive(wave)
			Game.hud.waypoint = n.global_position + Vector3(0, 2.1, 0) if n else null
			Game.hud.set_task("", 0.0)
			Game.objective_changed.emit("نظّف ما تبقّى من القوة")
	Audio.music("music_tense")
	Game.hud.set_task("", 0.0)
	Game.say(SHIHAB, "النفق مفتوح! انزلوا الآن!")
	Game.say(ENG, "سقط قائدهم… لن يجرؤوا على الدخول لدقائق. هذه فرصتنا الوحيدة.")
	if not await _wait(t, 6.0):
		return
	_complete(t, "صمدتم أمام ثلاث موجات وأسقطتم قائد القوة.")


# ================================================================ الفصل ٦: الهروب
func _ch5(t: int) -> void:
	var pts: Dictionary = bank.pts
	var B := Bank.B
	for c in w.crew:
		c.follow = true
	_crew(SHIHAB).follow = false
	Audio.loop_at("siren", "siren_loop", Vector3(0, 0, 30), -3.0)
	Audio.music("music_action")
	bank.set_alarm(true)
	timer("قبل إغراق المبنى بالغاز", 240.0)
	Game.say(ENG, "اتركوا كل شيء وانزلوا إلى غرفة المضخات. أربع دقائق!")
	_spawn_wave(["swat", "swat", "police"], Vector3(0, 0, 25), 2.5)
	w.spawn_enemy("police", Vector3(-17, B, -1), 0.0)
	w.spawn_enemy("police", Vector3(-6, B, 1), -PI / 2)
	w.spawn_enemy("police", Vector3(4, B, 2), PI / 2)
	obj("انزل إلى غرفة المضخات في القبو", pts["mech"])
	if not await _reach(t, pts["mech"], 3.5):
		return
	Game.say(SHIHAB, "ابتعدوا عن الجدار! ثلاثة… اثنان…")
	if not await _wait(t, 2.2):
		return
	FX.explosion(w, Vector3(-23.5, B + 1.4, 14.0))
	bank.open_gate("tunnel")
	_crew(SHIHAB).follow = true
	w.spawn_pickup("ammo", Vector3(-27, B, 14))
	w.spawn_pickup("med", Vector3(-29, B, 14))
	var tun := []
	tun.append(w.spawn_enemy("police", Vector3(-41, B, 14.5), -PI / 2))
	tun.append(w.spawn_enemy("police", Vector3(-51, B, 13.5), -PI / 2))
	tun.append(w.spawn_enemy("police", Vector3(-59.7, B, -6), PI))
	tun.append(w.spawn_enemy("swat", Vector3(-59.7, B, -24), PI))
	obj("اعبر نفق الصرف", pts["tunnel_mid"])
	if not await _reach(t, pts["tunnel_mid"], 3.0):
		return
	Game.say(THURAYA, "أسمع أصواتاً في الأمام… اكتشفوا النفق!")
	var canal := []
	canal.append(w.spawn_enemy("swat", Vector3(-55, B, -47), 0.0))
	canal.append(w.spawn_enemy("swat", Vector3(-66, B, -46), 0.0))
	canal.append(w.spawn_enemy("police", Vector3(-53, B, -55), 0.0))
	canal.append(w.spawn_enemy("police", Vector3(-68, B, -56), 0.0))
	canal.append(w.spawn_enemy("swat", Vector3(-58, B, -58), 0.0))
	obj("تابع حتى القناة", pts["canal"])
	if not await _reach(t, pts["canal"], 3.0):
		return
	Game.say(NASR, "الشاحنة هناك! نظّفوا القناة!")
	if not await _clear(t, canal, "نظّف القناة حول الشاحنة"):
		return
	timer_stop()
	bank.set_alarm(false)
	obj("اصعد الشاحنة", pts["truck"])
	if not await _use(t, pts["truck"] + Vector3(0, 1.2, 0), "الصعود إلى الشاحنة", 1.0):
		return
	Audio.music("music_tense")
	Audio.stop_all_loops()
	Game.complete_chapter(Game.chapter)
	await _cutscene(t, [
		[Vector3(-52, B + 2.5, -43), Vector3(-55, B + 4.0, -45), Vector3(-64, B + 1.2, -52), 5.5, ENG, "أربع حقائب من الذهب… وطاقم كامل… ولا قطرة دم بريئة."],
		[Vector3(-60, B + 6.0, -58), Vector3(-60, B + 11.0, -60), Vector3(-64, B + 1.0, -52), 6.0, ENG, "قالوا إن هذه الخزنة لا تُفتح. كل خزنة تُفتح… إن عرفتَ من أين تبدأ."]])
	Game.set_state(Game.State.PLAYING)
	_complete(t, "خرجتم بالذهب قبل أن يُطبق الحصار.", true)
