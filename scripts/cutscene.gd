class_name Cutscene
extends CanvasLayer
## مشاهد سينمائية: أشرطة سوداء، كاميرا متحركة، حوار عربي يُكتب حرفاً حرفاً، واختيارات.
##
## كل خطوة قاموس:
##   who   : اسم المتكلم (اختياري)
##   text  : النص
##   col   : لون اسم المتكلم
##   cam   : {from, look, to, look_to, dur} لقطة كاميرا (اختياري — تبقى اللقطة السابقة)
##   fn    : دالة تُنفَّذ عند بداية الخطوة (اختياري)
##   choice: [[نص, مفتاح], [نص, مفتاح]] — يخزَّن المفتاح في Game.choice

signal finished

var active := false
var auto := false           # للاختبار الآلي: يتخطى كل شيء فوراً
var auto_choice := 0
var _steps: Array = []
var _i := -1
var _chars := 0.0
var _done: Callable
var _hold := 0.0

var root: Control
var top_bar: ColorRect
var bot_bar: ColorRect
var name_lbl: Label
var text_lbl: Label
var hint_lbl: Label
var skip_btn: Button
var choice_box: VBoxContainer
var fade: ColorRect


func _ready() -> void:
	layer = 4
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	top_bar = ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 84)
	top_bar.size.y = 84
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)
	bot_bar = ColorRect.new()
	bot_bar.color = Color(0, 0, 0, 0.92)
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = -210
	bot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bot_bar)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 90
	vb.offset_right = -90
	vb.offset_top = 14
	vb.offset_bottom = -10
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_bar.add_child(vb)
	name_lbl = UI.label("", 30, Color(1.0, 0.86, 0.35))
	vb.add_child(name_lbl)
	text_lbl = UI.label("", 30, Color.WHITE, false)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	vb.add_child(text_lbl)
	hint_lbl = UI.label("المس الشاشة للمتابعة ◀", 20, Color(1, 1, 1, 0.6))
	vb.add_child(hint_lbl)
	skip_btn = UI.button("تخطي المشهد", Color(0.25, 0.25, 0.3), 22)
	skip_btn.custom_minimum_size = Vector2(190, 52)
	skip_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_btn.position = Vector2(-18, 16)
	skip_btn.pressed.connect(skip_all)
	root.add_child(skip_btn)
	choice_box = VBoxContainer.new()
	choice_box.set_anchors_preset(Control.PRESET_CENTER)
	choice_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	choice_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	choice_box.add_theme_constant_override("separation", 18)
	root.add_child(choice_box)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	root.visible = false


func play(steps: Array, on_done := Callable()) -> void:
	_steps = steps
	_done = on_done
	_i = -1
	active = true
	root.visible = true
	Game.joy = Vector2.ZERO
	Game.set_state(Game.State.CUTSCENE)
	fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.5)
	_next()


func _next() -> void:
	_i += 1
	if _i >= _steps.size():
		_finish()
		return
	var s: Dictionary = _steps[_i]
	if s.has("fn"):
		(s["fn"] as Callable).call()
	if s.has("cam") and Game.cam:
		var c: Dictionary = s["cam"]
		Game.cam.shot(c["from"], c["look"], c.get("to"), c.get("look_to"), c.get("dur", 5.0))
	name_lbl.text = s.get("who", "")
	name_lbl.add_theme_color_override("font_color", s.get("col", Color(1.0, 0.86, 0.35)))
	text_lbl.text = s.get("text", "")
	if s.has("text_fn"):
		text_lbl.text = (s["text_fn"] as Callable).call()
	text_lbl.visible_characters = 0
	_chars = 0.0
	_hold = 0.25
	for c in choice_box.get_children():
		c.queue_free()
	hint_lbl.visible = not s.has("choice")
	if s.has("sfx"):
		Sfx.play(s["sfx"], -4.0)
	if auto:
		if s.has("choice"):
			_choose(s["choice"][auto_choice][1])
		else:
			_next()


func _show_choices() -> void:
	var s: Dictionary = _steps[_i]
	if choice_box.get_child_count() > 0:
		return
	var cols := [Color(0.15, 0.55, 0.35), Color(0.6, 0.25, 0.2)]
	var n := 0
	for ch in s["choice"]:
		var b := UI.button(ch[0], cols[n % 2], 28)
		b.custom_minimum_size = Vector2(760, 84)
		var key: String = ch[1]
		b.pressed.connect(func(): _choose(key))
		choice_box.add_child(b)
		n += 1


func _choose(key: String) -> void:
	Game.choice = key
	Game.save_game()
	_next()


func _finish() -> void:
	active = false
	root.visible = false
	if Game.cam:
		Game.cam.end_cine()
	Game.set_state(Game.State.PLAYING)
	var d := _done
	_done = Callable()
	finished.emit()
	if d.is_valid():
		d.call()


func skip_all() -> void:
	if not active:
		return
	if _i >= 0 and _i < _steps.size() and _steps[_i].has("choice"):
		text_lbl.visible_characters = -1
		_show_choices()
		return
	# نفّذ دوال الخطوات المتبقية وتوقّف عند أي اختيار حتى لا تنكسر القصة
	var j := _i + 1
	while j < _steps.size():
		var s: Dictionary = _steps[j]
		if s.has("choice"):
			_i = j - 1
			_next()
			return
		if s.has("fn"):
			(s["fn"] as Callable).call()
		j += 1
	_finish()


func _advance() -> void:
	if not active or _hold > 0.0 or _i < 0 or _i >= _steps.size():
		return
	var s: Dictionary = _steps[_i]
	if text_lbl.visible_characters >= 0 and text_lbl.visible_characters < text_lbl.text.length():
		text_lbl.visible_characters = -1
		_chars = 9999.0
		if s.has("choice"):
			_show_choices()
		return
	if s.has("choice"):
		_show_choices()
		return
	Sfx.play("click", -12.0)
	_next()


func _process(delta: float) -> void:
	if not active:
		return
	_hold -= delta
	if text_lbl.visible_characters >= 0:
		_chars += delta * 42.0
		if int(_chars) >= text_lbl.text.length():
			text_lbl.visible_characters = -1
			if _i >= 0 and _i < _steps.size() and _steps[_i].has("choice"):
				_show_choices()
		else:
			text_lbl.visible_characters = int(_chars)
	if Game.consume("skip"):
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch and event.pressed:
		_advance()
