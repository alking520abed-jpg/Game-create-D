class_name Menu
extends CanvasLayer
## القوائم: الرئيسية، الفصول، الإعدادات، الشرح، الإيقاف، الإحاطة قبل المهمة، ونهاية الفصل.

const QUALITY := ["منخفضة (أسرع)", "متوسطة", "عالية (أجمل)"]
const DIFF := ["سهل", "عادي", "صعب"]
const GOLD := Color(0.92, 0.74, 0.3)

var dim: ColorRect
var screens := {}
var _back := "main"
var stats_lbl: Label
var set_btns := {}
var brief_title: Label
var brief_text: Label
var brief_view: SubViewport
var brief_model: Node3D
var brief_start: Button
var end_title: Label
var end_text: Label
var end_next: Button
var chapter_box: VBoxContainer
var continue_btn: Button
var _type_full := ""
var _type_t := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	dim = ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_build_main()
	_build_chapters()
	_build_settings()
	_build_help()
	_build_pause()
	_build_briefing()
	_build_end()
	_build_loading()
	Game.state_changed.connect(_on_state)
	show_screen("")


func _screen(n: String, sep := 12) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(vb)
	screens[n] = cc
	return vb


func _btn(text: String, col: Color, cb: Callable, w := 420, h := 64, fs := 28) -> Button:
	var b := UI.button(text, col, fs)
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


func _build_main() -> void:
	var vb := _screen("main", 10)
	vb.add_child(UI.outline(UI.label("الخزنة", 120, GOLD), 26, Color(0.03, 0.05, 0.08)))
	vb.add_child(UI.outline(UI.label("خطة واحدة • ستة فصول • لا مجال للخطأ", 28, Color(0.9, 0.92, 0.95)), 12))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 12)
	vb.add_child(sp)
	continue_btn = _btn("متابعة", Color(0.15, 0.55, 0.3), func(): Game.main.goto_chapter(Game.unlocked), 440, 78, 34)
	vb.add_child(continue_btn)
	vb.add_child(_btn("لعبة جديدة", Color(0.6, 0.42, 0.1), func(): Game.main.goto_chapter(0), 440, 62))
	vb.add_child(_btn("اختيار الفصل", Color(0.12, 0.4, 0.65), func(): _refresh_chapters(); show_screen("chapters"), 440, 62))
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_RTL
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(_btn("شرح الأزرار", Color(0.2, 0.26, 0.34), func(): _open_sub("help", "main"), 214, 58, 24))
	row.add_child(_btn("الإعدادات", Color(0.2, 0.26, 0.34), func(): _open_sub("settings", "main"), 214, 58, 24))
	vb.add_child(row)
	if not Game.is_mobile:
		vb.add_child(_btn("خروج", Color(0.45, 0.16, 0.16), func(): get_tree().quit(), 440, 54, 24))
	stats_lbl = UI.outline(UI.label("", 20, Color(1, 1, 1, 0.85)), 8)
	vb.add_child(stats_lbl)


func _build_chapters() -> void:
	var vb := _screen("chapters", 10)
	vb.add_child(UI.outline(UI.label("الفصول", 60, GOLD), 16))
	chapter_box = VBoxContainer.new()
	chapter_box.add_theme_constant_override("separation", 8)
	vb.add_child(chapter_box)
	vb.add_child(_btn("رجوع", Color(0.2, 0.26, 0.34), func(): show_screen("main"), 300, 56, 24))


func _refresh_chapters() -> void:
	for c in chapter_box.get_children():
		c.queue_free()
	for i in Game.CHAPTERS.size():
		var open: bool = i <= Game.unlocked
		var txt := "الفصل %d: %s" % [i + 1, Game.CHAPTERS[i]]
		if Game.best.has(i):
			txt += "   ★ %d" % Game.best[i]
		if not open:
			txt += "   (مقفل)"
		var b := _btn(txt, Color(0.12, 0.4, 0.65) if open else Color(0.18, 0.19, 0.22), func(): Game.main.goto_chapter(i), 560, 58, 24)
		b.disabled = not open
		chapter_box.add_child(b)


func _build_settings() -> void:
	var vb := _screen("settings", 8)
	vb.add_child(UI.outline(UI.label("الإعدادات", 56, GOLD), 16))
	var defs := [
		["quality", func(): Game.settings["quality"] = (Game.settings["quality"] + 1) % 3],
		["difficulty", func(): Game.settings["difficulty"] = (Game.settings["difficulty"] + 1) % 3],
		["sens", func(): Game.settings["sens"] = 0.5 if Game.settings["sens"] >= 1.99 else Game.settings["sens"] + 0.25],
		["aim_assist", func(): Game.settings["aim_assist"] = not Game.settings["aim_assist"]],
		["sound", func(): Game.settings["sound"] = not Game.settings["sound"]],
		["music", func(): Game.settings["music"] = not Game.settings["music"]],
		["lefty", func(): Game.settings["lefty"] = not Game.settings["lefty"]],
	]
	for d in defs:
		var cb: Callable = d[1]
		var b := _btn("", Color(0.12, 0.4, 0.65), func(): cb.call(); _apply_settings(), 520, 54, 24)
		set_btns[d[0]] = b
		vb.add_child(b)
	vb.add_child(_btn("رجوع", Color(0.15, 0.55, 0.3), func(): show_screen(_back), 520, 58, 26))
	_refresh_settings()


func _onoff(v: bool) -> String:
	return "مفعّل" if v else "متوقف"


func _refresh_settings() -> void:
	var s: Dictionary = Game.settings
	set_btns["quality"].text = "جودة الرسوم: " + QUALITY[s["quality"]]
	set_btns["difficulty"].text = "الصعوبة: " + DIFF[s["difficulty"]]
	set_btns["sens"].text = "حساسية النظر: %d%%" % int(s["sens"] * 100)
	set_btns["aim_assist"].text = "مساعدة التصويب: " + _onoff(s["aim_assist"])
	set_btns["sound"].text = "الأصوات: " + _onoff(s["sound"])
	set_btns["music"].text = "الموسيقى: " + _onoff(s["music"])
	set_btns["lefty"].text = "وضع اليد اليسرى: " + _onoff(s["lefty"])


func _apply_settings() -> void:
	_refresh_settings()
	Game.save_game()
	Game.settings_changed.emit()


func _build_help() -> void:
	var vb := _screen("help", 8)
	vb.add_child(UI.outline(UI.label("شرح الأزرار", 48, GOLD), 14))
	var p := UI.panel(Color(0.04, 0.07, 0.11, 0.92), 18, 18)
	p.custom_minimum_size = Vector2(900, 0)
	vb.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var rows := [
		["العصا (يسار الشاشة)", "الحركة — ادفعها للآخر للأمام لتركض"],
		["اسحب يمين الشاشة", "تدوير النظر والتصويب"],
		["نار", "إطلاق النار (اضغط مطوّلاً للأسلحة الرشاشة) — تستطيع السحب عليه للتصويب أثناء الإطلاق"],
		["تصويب", "تقريب المنظار: دقة أعلى وحركة أبطأ"],
		["تلقيم / سلاح", "تعبئة المخزن / التبديل بين الأسلحة"],
		["انخفاض / قفز", "الانخفاض يصعّب إصابتك ورؤيتك"],
		["تفاعل", "يظهر قرب الأشياء المضيئة: لوحات، خزنة، ذهب"],
		["المعيّن الأصفر", "يدلّك على مكان الهدف والمسافة إليه"],
		["تحذير", "لا تؤذِ الرهائن — إصابتهم تُفشل المهمة"],
	]
	for r in rows:
		var hb := HBoxContainer.new()
		hb.layout_direction = Control.LAYOUT_DIRECTION_RTL
		hb.add_theme_constant_override("separation", 16)
		var a := UI.label(r[0], 22, Color(1.0, 0.85, 0.4), true, HORIZONTAL_ALIGNMENT_RIGHT)
		a.custom_minimum_size = Vector2(250, 0)
		var b := UI.label(r[1], 20, Color.WHITE, false, HORIZONTAL_ALIGNMENT_RIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hb.add_child(a)
		hb.add_child(b)
		v.add_child(hb)
	v.add_child(UI.label("على الكمبيوتر: WASD حركة • الفأرة نظر وإطلاق • زر يمين تصويب • R تلقيم • Q سلاح • E تفاعل • Ctrl انخفاض • Shift ركض", 16, Color(0.7, 0.8, 0.9), false))
	vb.add_child(_btn("فهمت", Color(0.15, 0.55, 0.3), func(): show_screen(_back), 320, 58, 26))


func _build_pause() -> void:
	var vb := _screen("pause", 12)
	vb.add_child(UI.outline(UI.label("إيقاف مؤقت", 60, GOLD), 16))
	vb.add_child(_btn("متابعة", Color(0.15, 0.55, 0.3), func(): resume()))
	vb.add_child(_btn("إعادة الفصل", Color(0.6, 0.42, 0.1), func(): Game.main.goto_chapter(Game.chapter)))
	vb.add_child(_btn("شرح الأزرار", Color(0.2, 0.26, 0.34), func(): _open_sub("help", "pause")))
	vb.add_child(_btn("الإعدادات", Color(0.2, 0.26, 0.34), func(): _open_sub("settings", "pause")))
	vb.add_child(_btn("القائمة الرئيسية", Color(0.45, 0.16, 0.16), func(): Game.main.to_menu()))


func _build_briefing() -> void:
	var vb := _screen("briefing", 12)
	var hb := HBoxContainer.new()
	hb.layout_direction = Control.LAYOUT_DIRECTION_RTL
	hb.add_theme_constant_override("separation", 24)
	vb.add_child(hb)
	# صورة «المهندس» ثلاثية الأبعاد
	var pp := UI.panel(Color(0.03, 0.05, 0.08, 0.95), 18, 6)
	hb.add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	brief_view = SubViewport.new()
	brief_view.size = Vector2i(560, 720)
	brief_view.own_world_3d = true
	brief_view.transparent_bg = true
	brief_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(brief_view)
	var tr := TextureRect.new()
	tr.texture = brief_view.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(300, 386)
	pv.add_child(tr)
	pv.add_child(UI.label("المهندس", 24, Color(0.4, 0.85, 0.9)))
	pv.add_child(UI.label("العقل المدبّر", 16, Color(0.7, 0.75, 0.8), false))
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = e
	brief_view.add_child(we)
	var l := DirectionalLight3D.new()
	l.rotation_degrees = Vector3(-30, 140, 0)
	l.light_color = Color(1.0, 0.85, 0.7)
	l.light_energy = 1.4
	brief_view.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 24.0
	cam.position = Vector3(0.05, 1.5, 2.3)
	brief_view.add_child(cam)
	cam.look_at(Vector3(0, 1.42, 0))
	# النص
	var tp := UI.panel(Color(0.03, 0.05, 0.08, 0.95), 18, 22)
	tp.custom_minimum_size = Vector2(720, 430)
	hb.add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 12)
	tp.add_child(tv)
	brief_title = UI.label("", 40, GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
	tv.add_child(brief_title)
	brief_text = UI.label("", 22, Color(0.93, 0.94, 0.96), false, HORIZONTAL_ALIGNMENT_RIGHT)
	brief_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tv.add_child(brief_text)
	brief_start = _btn("ابدأ المهمة", Color(0.15, 0.55, 0.3), func(): Game.main.start_play(), 420, 72, 32)
	vb.add_child(brief_start)


func _build_end() -> void:
	var vb := _screen("end", 14)
	end_title = UI.outline(UI.label("", 64, GOLD), 16)
	vb.add_child(end_title)
	var p := UI.panel(Color(0.03, 0.05, 0.08, 0.92), 18, 22)
	p.custom_minimum_size = Vector2(640, 0)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(p)
	end_text = UI.label("", 24, Color.WHITE, false)
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(end_text)
	end_next = _btn("", Color(0.15, 0.55, 0.3), func(): pass, 440, 72, 30)
	vb.add_child(end_next)
	vb.add_child(_btn("القائمة الرئيسية", Color(0.2, 0.26, 0.34), func(): Game.main.to_menu(), 440, 56, 24))


func _build_loading() -> void:
	var vb := _screen("loading")
	vb.add_child(UI.outline(UI.label("جارٍ التحميل…", 48, GOLD), 14))


func _on_state() -> void:
	if Game.state == Game.State.DEAD:
		await get_tree().create_timer(1.2, true).timeout
		if Game.state == Game.State.DEAD:
			show_end(false, "سقطتَ في العملية", "الخطة لا تحتمل الأخطاء. خذ نفساً وأعد المحاولة.")


func show_screen(n: String) -> void:
	for k in screens:
		screens[k].visible = k == n
	dim.visible = n != "" and n != "main"
	brief_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if n == "briefing" else SubViewport.UPDATE_DISABLED
	if n == "main":
		continue_btn.visible = Game.unlocked > 0
		continue_btn.text = "متابعة — الفصل %d: %s" % [Game.unlocked + 1, Game.CHAPTERS[Game.unlocked]]
		var total := 0
		for k in Game.best:
			total += Game.best[k]
		stats_lbl.text = "" if total == 0 else "مجموع نقاطك: %d" % total


func show_loading() -> void:
	show_screen("loading")


func _open_sub(n: String, back: String) -> void:
	_back = back
	show_screen(n)


func open_pause() -> void:
	if Game.state != Game.State.PLAYING:
		return
	Game.set_state(Game.State.PAUSED)
	Game.player.capture_mouse(false)
	show_screen("pause")


func resume() -> void:
	show_screen("")
	Game.set_state(Game.State.PLAYING)
	Game.player.capture_mouse(true)


func show_briefing(ch: int) -> void:
	if brief_model == null:
		Actor.libs()
		brief_model = load("res://chars/engineer.gltf").instantiate()
		brief_view.add_child(brief_model)
		var ap := AnimationPlayer.new()
		brief_model.add_child(ap)
		ap.add_animation_library("a", Actor._libs[0])
		ap.play("a/Idle_Talking")
	brief_title.text = "الفصل %d — %s" % [ch + 1, Game.CHAPTERS[ch]]
	_type_full = Story.BRIEFS[ch]
	_type_t = 0.0
	brief_text.text = _type_full
	brief_text.visible_characters = 0
	show_screen("briefing")
	Audio.music("music_tense")


func show_end(win: bool, title: String, text: String, final := false) -> void:
	end_title.text = title
	end_title.add_theme_color_override("font_color", GOLD if win else Color(0.9, 0.3, 0.25))
	end_text.text = text
	for c in end_next.pressed.get_connections():
		end_next.pressed.disconnect(c["callable"])
	end_next.visible = true
	if not win:
		end_next.text = "أعد المحاولة"
		end_next.pressed.connect(func(): Game.main.goto_chapter(Game.chapter))
	elif final:
		end_next.visible = false
	else:
		end_next.text = "الفصل التالي"
		end_next.pressed.connect(func(): Game.main.goto_chapter(Game.chapter + 1))
	if Game.player:
		Game.player.capture_mouse(false)
	show_screen("end")


func _process(delta: float) -> void:
	if screens["briefing"].visible and brief_text.visible_characters < _type_full.length():
		_type_t += delta * 55.0
		brief_text.visible_characters = int(_type_t)
