class_name Menu
extends CanvasLayer
## القوائم: الرئيسية، الإيقاف، شرح الأزرار، الإعدادات.

const QUALITY := ["منخفضة (أسرع)", "متوسطة", "عالية (أجمل)"]

var dim: ColorRect
var main_box: Control
var pause_box: Control
var help_box: Control
var settings_box: Control
var stats_lbl: Label
var q_btn: Button
var s_btn: Button
var mu_btn: Button
var reset_btn: Button
var _back_to := ""
var _reset_armed := false


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.1, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build_main()
	_build_pause()
	_build_help()
	_build_settings()
	show_screen("main")


func _center_box(sep := 14) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(vb)
	vb.set_meta("root", cc)
	return vb


func _build_main() -> void:
	var vb := _center_box()
	main_box = vb.get_meta("root")
	var t := UI.outline(UI.label("حارس النخيل", 96, Color(1.0, 0.86, 0.35)), 22, Color(0.05, 0.15, 0.2))
	vb.add_child(t)
	var st := UI.outline(UI.label("بطل خارق • خمس هيئات • قصة عربية • عالم مفتوح", 30), 12)
	vb.add_child(st)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(sp)
	var b1 := UI.button("ابدأ اللعب", Color(0.15, 0.6, 0.3), 34)
	b1.custom_minimum_size = Vector2(420, 82)
	b1.pressed.connect(func(): Game.main.start_game())
	var b2 := UI.button("شرح الأزرار")
	b2.pressed.connect(func(): open_help("main"))
	var b3 := UI.button("الإعدادات")
	b3.pressed.connect(func(): open_settings("main"))
	for b in [b1, b2, b3]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(b)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var b4 := UI.button("خروج", Color(0.5, 0.2, 0.2))
		b4.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b4.pressed.connect(func(): get_tree().quit())
		vb.add_child(b4)
	stats_lbl = UI.outline(UI.label("", 24, Color(1, 1, 1, 0.95)), 10)
	vb.add_child(stats_lbl)


func _build_pause() -> void:
	var vb := _center_box()
	pause_box = vb.get_meta("root")
	vb.add_child(UI.outline(UI.label("إيقاف مؤقت", 64, Color(1.0, 0.86, 0.35)), 16))
	var defs := [
		["متابعة اللعب", Color(0.15, 0.6, 0.3), func(): resume()],
		["شرح الأزرار", Color(0.12, 0.45, 0.75), func(): open_help("pause")],
		["الإعدادات", Color(0.12, 0.45, 0.75), func(): open_settings("pause")],
		["إلغاء المهمة الجانبية", Color(0.6, 0.4, 0.15), func(): Game.missions.cancel(); resume()],
		["أنا عالق! أرجعني للساحة", Color(0.6, 0.4, 0.15), func(): Game.main.unstuck(); resume()],
		["القائمة الرئيسية", Color(0.5, 0.2, 0.2), func(): Game.main.to_menu()],
	]
	for d in defs:
		var b := UI.button(d[0], d[1])
		b.custom_minimum_size = Vector2(420, 62)
		b.pressed.connect(d[2])
		vb.add_child(b)


func _help_row(kind: String, label: String, col: Color, text: String) -> Control:
	var hb := HBoxContainer.new()
	hb.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hb.add_theme_constant_override("separation", 12)
	var b := TouchControls.TBtn.new().setup(kind, label, col, "", false, 28)
	b.set_process(false)
	hb.add_child(b)
	var l := UI.label(text, 20, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hb.add_child(l)
	return hb


func _build_help() -> void:
	var vb := _center_box(4)
	help_box = vb.get_meta("root")
	vb.add_child(UI.outline(UI.label("شرح الأزرار", 36, Color(1.0, 0.86, 0.35)), 14))
	var cols := HBoxContainer.new()
	cols.layout_direction = Control.LAYOUT_DIRECTION_RTL
	cols.add_theme_constant_override("separation", 22)
	vb.add_child(cols)
	var green := Color(0.25, 0.85, 0.4)
	var red := Color(0.95, 0.3, 0.25)
	var blue := Color(0.3, 0.65, 1.0)
	var yellow := Color(1.0, 0.8, 0.2)
	var grey := Color(0.8, 0.82, 0.88)
	var pink := Color(1.0, 0.5, 0.9)
	var foot := [
		["joy", "", blue, "العصا (يسار الشاشة): حرّك الشخصية"],
		["drag", "", grey, "اسحب بإصبعك على الشاشة: تدوير الكاميرا"],
		["attack", "هجوم", red, "هجوم: اضغط مطوّلاً — يصوّب تلقائياً نحو أقرب عدو"],
		["special", "قدرة", pink, "القدرة الخاصة للهيئة الحالية (تحتاج شحناً)"],
		["form", "تحوّل", Color(0.75, 0.5, 1.0), "أزرار الهيئات ١–٥ أسفل الشاشة: اضغط لتتحوّل، واضغط نفس الزر لتعود بشراً"],
		["jump", "قفز", blue, "قفز — ومع «لهيب»: صعود / نزول للطيران"],
		["enter", "اركب", yellow, "اركب: يظهر قرب أي سيارة (بهيئتك البشرية فقط)"],
		["mission", "مهمة", pink, "ابدأ: يظهر عند عمود القصة البنفسجي والدوائر الملوّنة"],
	]
	var car := [
		["left", "يسار", grey, "يسار / يمين: توجيه السيارة"],
		["gas", "بنزين", green, "بنزين: اضغط مطوّلاً للسير للأمام"],
		["brake", "فرامل", red, "فرامل: توقّف، وبعد الوقوف رجوع للخلف"],
		["hand", "يدوي", yellow, "فرملة اليد: للانعطاف الحاد والتفحيط"],
		["horn", "زمور", grey, "زمور"],
		["exit", "انزل", yellow, "انزل: اخرج من السيارة (بعد التوقف)"],
		["pause", "", grey, "إيقاف مؤقت — و«الكاميرا» بجانبه لتقريب المنظر"],
	]
	for data in [["البطل", foot], ["في السيارة", car]]:
		var p := UI.panel(Color(0.04, 0.08, 0.14, 0.9), 18, 10)
		p.custom_minimum_size = Vector2(560, 0)
		cols.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		v.add_child(UI.label(data[0], 24, Color(0.5, 0.9, 1.0)))
		for r in data[1]:
			v.add_child(_help_row(r[0], r[1], r[2], r[3]))
	var ok := UI.button("فهمت، يلا نلعب!", Color(0.15, 0.6, 0.3), 28)
	ok.custom_minimum_size = Vector2(380, 58)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_close_sub)
	vb.add_child(ok)


func _build_settings() -> void:
	var vb := _center_box()
	settings_box = vb.get_meta("root")
	vb.add_child(UI.outline(UI.label("الإعدادات", 56, Color(1.0, 0.86, 0.35)), 16))
	q_btn = UI.button("")
	q_btn.pressed.connect(func():
		Game.settings["quality"] = (Game.settings["quality"] + 1) % 3
		_apply_settings())
	s_btn = UI.button("")
	s_btn.pressed.connect(func():
		Game.settings["sound"] = not Game.settings["sound"]
		_apply_settings())
	mu_btn = UI.button("")
	mu_btn.pressed.connect(func():
		Game.settings["music"] = not Game.settings["music"]
		_apply_settings())
	reset_btn = UI.button("مسح التقدم والبدء من جديد", Color(0.5, 0.2, 0.2), 24)
	reset_btn.pressed.connect(func():
		if _reset_armed:
			Game.reset_save()
			Game.missions.refresh_stars()
			reset_btn.text = "تم المسح ✓"
			_reset_armed = false
		else:
			_reset_armed = true
			reset_btn.text = "متأكد؟ اضغط مرة ثانية للمسح")
	var back := UI.button("رجوع", Color(0.15, 0.6, 0.3))
	back.pressed.connect(_close_sub)
	for b in [q_btn, s_btn, mu_btn, reset_btn, back]:
		b.custom_minimum_size = Vector2(460, 64)
		vb.add_child(b)
	_refresh_settings()


func _refresh_settings() -> void:
	q_btn.text = "جودة الرسوم: " + QUALITY[Game.settings["quality"]]
	s_btn.text = "الأصوات: " + ("مفعّلة" if Game.settings["sound"] else "متوقفة")
	mu_btn.text = "الموسيقى: " + ("مفعّلة" if Game.settings["music"] else "متوقفة")


func _apply_settings() -> void:
	_refresh_settings()
	Game.save_game()
	Game.settings_changed.emit()
	Sfx.update_music()


func show_screen(n: String) -> void:
	main_box.visible = n == "main"
	pause_box.visible = n == "pause"
	help_box.visible = n == "help"
	settings_box.visible = n == "settings"
	dim.visible = n != "" and n != "main"
	if n == "main" and Game.missions != null:
		stats_lbl.text = "القصة: %d/7   •   النقود: %d ريال   •   النجوم: %d/%d   •   المهمات الجانبية: %d/%d" % [min(Game.chapter, 7), Game.money, Game.stars.size(), Game.missions.star_total, Game.missions.done_count(), Game.missions.defs.size()]


func open_pause() -> void:
	Game.set_state(Game.State.PAUSED)
	show_screen("pause")


func resume() -> void:
	show_screen("")
	Game.set_state(Game.State.PLAYING)


func open_help(back: String) -> void:
	_back_to = back
	show_screen("help")


func open_settings(back: String) -> void:
	_back_to = back
	_reset_armed = false
	reset_btn.text = "مسح التقدم والبدء من جديد"
	show_screen("settings")


func _close_sub() -> void:
	if _back_to == "play":
		Game.help_seen = true
		Game.save_game()
		resume()
	else:
		show_screen(_back_to)
