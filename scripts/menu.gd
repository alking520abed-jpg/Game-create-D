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
var skins_box: Control
var _back_to := ""
var _reset_armed := false
# شاشة السكنات
var _sk_view: SubViewport
var _sk_pivot: Node3D
var _sk_model: Node3D
var _sk_btns := {}
var _sk_sel := "stock"
var _sk_car := "sedan"
var _sk_col := Color("c0392b")
var _sk_name: Label
var _sk_money: Label
var _sk_action: Button


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
	_build_skins()
	show_screen("main")


func _process(delta: float) -> void:
	if skins_box.visible:
		_sk_pivot.rotation.y += delta * 0.7


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
	var t := UI.outline(UI.label("مدينة النخيل", 96, Color(1.0, 0.86, 0.35)), 22, Color(0.05, 0.15, 0.2))
	vb.add_child(t)
	var st := UI.outline(UI.label("عالم مفتوح • سيارات • مهمات", 30), 12)
	vb.add_child(st)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	vb.add_child(sp)
	var b1 := UI.button("ابدأ اللعب", Color(0.15, 0.6, 0.3), 34)
	b1.custom_minimum_size = Vector2(420, 82)
	b1.pressed.connect(func(): Game.main.start_game())
	var bs := UI.button("سكنات السيارة", Color(0.5, 0.28, 0.7))
	bs.custom_minimum_size = Vector2(420, 66)
	bs.pressed.connect(func(): open_skins("main"))
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 12)
	var b2 := UI.button("شرح الأزرار", Color(0.12, 0.45, 0.75), 24)
	b2.pressed.connect(func(): open_help("main"))
	var b3 := UI.button("الإعدادات", Color(0.12, 0.45, 0.75), 24)
	b3.pressed.connect(func(): open_settings("main"))
	for b in [b2, b3]:
		b.custom_minimum_size = Vector2(204, 62)
		row.add_child(b)
	for b in [b1, bs, row]:
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
		["سكنات السيارة", Color(0.5, 0.28, 0.7), func(): open_skins("pause")],
		["الإعدادات", Color(0.12, 0.45, 0.75), func(): open_settings("pause")],
		["إلغاء المهمة الحالية", Color(0.6, 0.4, 0.15), func(): Game.missions.cancel(); resume()],
		["أنا عالق! أرجعني للساحة", Color(0.6, 0.4, 0.15), func(): Game.main.unstuck(); resume()],
		["القائمة الرئيسية", Color(0.5, 0.2, 0.2), func(): Game.main.to_menu()],
	]
	for d in defs:
		var b := UI.button(d[0], d[1])
		b.custom_minimum_size = Vector2(420, 58)
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
		["jump", "قفز", blue, "قفز"],
		["run", "جري", green, "جري: اضغط مطوّلاً للركض"],
		["enter", "اركب", yellow, "اركب: يظهر قرب أي سيارة لتقودها"],
		["mission", "مهمة", pink, "ابدأ المهمة: يظهر عند الدوائر الملوّنة"],
		["pause", "", grey, "إيقاف مؤقت وفتح القائمة"],
	]
	var car := [
		["left", "يسار", grey, "يسار / يمين: توجيه السيارة"],
		["gas", "بنزين", green, "بنزين: اضغط مطوّلاً للسير للأمام"],
		["brake", "فرامل", red, "فرامل: توقّف، وبعد الوقوف رجوع للخلف"],
		["hand", "يدوي", yellow, "فرملة اليد: للانعطاف الحاد والتفحيط"],
		["horn", "زمور", grey, "زمور"],
		["exit", "انزل", yellow, "انزل: اخرج من السيارة (بعد التوقف)"],
		["cam", "", grey, "الكاميرا: قرّب أو بعّد المنظر"],
	]
	for data in [["على الأقدام", foot], ["في السيارة", car]]:
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


# ---------------- السكنات ----------------

func _build_skins() -> void:
	var vb := _center_box(10)
	skins_box = vb.get_meta("root")
	vb.add_child(UI.outline(UI.label("سكنات السيارة", 44, Color(1.0, 0.86, 0.35)), 14))
	_sk_money = UI.outline(UI.label("", 24), 10)
	vb.add_child(_sk_money)
	var cols := HBoxContainer.new()
	cols.layout_direction = Control.LAYOUT_DIRECTION_RTL
	cols.add_theme_constant_override("separation", 22)
	vb.add_child(cols)
	# قائمة السكنات
	var grid := GridContainer.new()
	grid.columns = 2
	grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cols.add_child(grid)
	for sk in Car.SKINS:
		var id: String = sk["id"]
		var b := UI.button("", Color(0.2, 0.22, 0.26), 22)
		b.custom_minimum_size = Vector2(250, 84)
		b.pressed.connect(func(): _sk_pick(id))
		grid.add_child(b)
		_sk_btns[id] = b
	# المعاينة ثلاثية الأبعاد
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	cols.add_child(side)
	var p := UI.panel(Color(0.04, 0.08, 0.14, 0.9), 18, 6)
	side.add_child(p)
	_sk_view = SubViewport.new()
	_sk_view.size = Vector2i(1000, 600)
	_sk_view.own_world_3d = true
	_sk_view.transparent_bg = true
	_sk_view.msaa_3d = Viewport.MSAA_2X
	_sk_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sk_view)
	var tr := TextureRect.new()
	tr.texture = _sk_view.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(500, 300)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tr)
	_build_sk_world()
	_sk_name = UI.outline(UI.label("", 28), 10)
	side.add_child(_sk_name)
	_sk_action = UI.button("", Color(0.15, 0.6, 0.3), 28)
	_sk_action.custom_minimum_size = Vector2(500, 64)
	_sk_action.pressed.connect(_sk_do)
	side.add_child(_sk_action)
	var back := UI.button("رجوع", Color(0.12, 0.45, 0.75), 24)
	back.custom_minimum_size = Vector2(300, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_close_sub)
	vb.add_child(back)


func _build_sk_world() -> void:
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.45, 0.6, 0.85)
	sm.sky_horizon_color = Color(0.85, 0.88, 0.92)
	sm.ground_horizon_color = Color(0.5, 0.5, 0.52)
	sm.ground_bottom_color = Color(0.2, 0.2, 0.22)
	var sky := Sky.new()
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_sk_view.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = 1.25
	_sk_view.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	cam.position = Vector3(0, 2.6, 8.6)
	_sk_view.add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))
	_sk_pivot = Node3D.new()
	_sk_pivot.rotation.y = 2.4
	_sk_view.add_child(_sk_pivot)
	# منصة العرض
	var mb := MeshBuilder.new()
	mb.cyl(Vector3(0, -0.14, 0), Vector3(0, -0.02, 0), 3.5, 3.4, 40, Color(0.16, 0.18, 0.22))
	mb.cyl(Vector3(0, -0.02, 0), Vector3(0, 0.0, 0), 3.4, 3.4, 40, Color(0.26, 0.29, 0.34))
	var plat := MeshInstance3D.new()
	plat.mesh = mb.commit(MeshBuilder.vc_material(0.7, 0.1))
	_sk_pivot.add_child(plat)


func _sk_status(id: String) -> String:
	if Game.skin == id:
		return "مُختار ✓"
	if Game.has_skin(id):
		return "مملوك"
	return "%d ريال" % Car.skin_def(id)["price"]


func _sk_refresh() -> void:
	_sk_money.text = "نقودك: %d ريال" % Game.money
	for sk in Car.SKINS:
		var id: String = sk["id"]
		var b: Button = _sk_btns[id]
		b.text = "%s\n%s" % [sk["name"], _sk_status(id)]
		var col: Color = Color(sk["col"]) if sk.has("col") else _sk_col
		# لون الزر من لون السكن، مع تعتيم خفيف ليبقى النص مقروءاً
		col = col.darkened(0.25) if col.get_luminance() > 0.35 else col.lightened(0.08)
		var cur: bool = id == _sk_sel
		var acc := Color(1, 1, 1, 0.3)
		for k in ["neon", "stripes", "side", "roof"]:
			if sk.has(k):
				acc = Color(sk[k])
				break
		b.add_theme_stylebox_override("normal", UI.box(col, 16, Color(1.0, 0.86, 0.35) if cur else acc, 5 if cur else 3))
		b.add_theme_stylebox_override("hover", UI.box(col.lightened(0.1), 16, Color(1.0, 0.86, 0.35) if cur else acc, 5 if cur else 3))
		b.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.2), 16, Color(1.0, 0.86, 0.35), 5))
		b.add_theme_constant_override("outline_size", 8)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("line_spacing", -8)
	var sel := Car.skin_def(_sk_sel)
	_sk_name.text = "%s  •  %s" % [sel["name"], Car.SPECS[_sk_car]["name"]]
	var green := Color(0.15, 0.6, 0.3)
	if Game.skin == _sk_sel:
		_sk_set_action("مُختار ✓", Color(0.25, 0.3, 0.36), true)
	elif Game.has_skin(_sk_sel):
		_sk_set_action("اختيار هذا السكن", green, false)
	elif Game.money >= sel["price"]:
		_sk_set_action("شراء بـ %d ريال" % sel["price"], Color(0.75, 0.55, 0.1), false)
	else:
		_sk_set_action("ينقصك %d ريال — أنجز مهمات" % (sel["price"] - Game.money), Color(0.5, 0.2, 0.2), true)


func _sk_set_action(text: String, col: Color, off: bool) -> void:
	_sk_action.text = text
	_sk_action.disabled = off
	for st in ["normal", "hover", "disabled"]:
		_sk_action.add_theme_stylebox_override(st, UI.box(col.lightened(0.15) if st == "hover" else col, 18, Color(1, 1, 1, 0.35), 2))
	_sk_action.add_theme_stylebox_override("pressed", UI.box(col.darkened(0.25), 18, Color(1, 1, 1, 0.6), 2))
	_sk_action.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.85))


func _sk_pick(id: String) -> void:
	_sk_sel = id
	if _sk_model:
		_sk_model.queue_free()
	_sk_model = Car.display_model(_sk_car, _sk_col, id)
	_sk_pivot.add_child(_sk_model)
	_sk_refresh()


func _sk_do() -> void:
	var had := Game.has_skin(_sk_sel)
	if Game.buy_skin(_sk_sel):
		if not had:
			Sfx.play("success")
	_sk_refresh()


func open_skins(back: String) -> void:
	_back_to = back
	# نعرض السيارة التي تقودها الآن، وإلا سيارتك عند نقطة البداية
	var c = Game.car
	if c == null and Game.main != null and is_instance_valid(Game.main.start_car):
		c = Game.main.start_car
	if c != null:
		_sk_car = c.spec_id
		_sk_col = c.color
	show_screen("skins")
	_sk_pick(Game.skin)


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
	skins_box.visible = n == "skins"
	_sk_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if n == "skins" else SubViewport.UPDATE_DISABLED
	dim.visible = n != "" and n != "main"
	if n == "main" and Game.missions != null:
		stats_lbl.text = "النقود: %d ريال   •   النجوم: %d/%d   •   المهمات المنجزة: %d/%d" % [Game.money, Game.stars.size(), Game.missions.star_total, Game.missions.done_count(), Game.missions.defs.size()]


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
