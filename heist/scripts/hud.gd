class_name HUD
extends CanvasLayer
## واجهة اللعب: التصويب، الصحة، الذخيرة، الهدف ومؤشّره، الترجمة، التنبيهات، وأزرار اللمس.

var touch: TouchControls
var cross: Control
var hp_bar: ProgressBar
var ar_bar: ProgressBar
var ammo_lbl: Label
var weapon_lbl: Label
var obj_lbl: Label
var obj_panel: PanelContainer
var sub_panel: PanelContainer
var sub_name: Label
var sub_text: Label
var toast_lbl: Label
var prompt_panel: PanelContainer
var prompt_lbl: Label
var prompt_bar: ProgressBar
var task_panel: PanelContainer
var task_lbl: Label
var task_bar: ProgressBar
var way: Control
var way_lbl: Label
var vignette: ColorRect
var bars: Array = []
var root: Control

var waypoint = null       # Vector3 أو null
var _hit_t := 0.0
var _hit_kill := false
var _hurt := 0.0
var _hurt_dir := 0.0
var _toast_t := 0.0
var _sub_q: Array = []
var _sub_t := 0.0
var _letter := 0.0
var _letter_target := 0.0


func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform float low = 0.0;\nvoid fragment(){ float d = distance(UV, vec2(0.5)); float v = smoothstep(0.25, 0.75, d); COLOR = vec4(0.75, 0.02, 0.02, v * clamp(amount + low, 0.0, 0.85)); }"
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vignette.material = sm
	root.add_child(vignette)
	cross = Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	root.add_child(cross)
	# الصحة والدرع
	var hp_box := VBoxContainer.new()
	hp_box.position = Vector2(24, 20)
	hp_box.custom_minimum_size = Vector2(250, 0)
	hp_box.add_theme_constant_override("separation", 5)
	root.add_child(hp_box)
	hp_bar = _bar(Color(0.85, 0.2, 0.2), 20)
	ar_bar = _bar(Color(0.3, 0.55, 0.95), 10)
	hp_box.add_child(hp_bar)
	hp_box.add_child(ar_bar)
	# الذخيرة
	var am := VBoxContainer.new()
	am.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	am.position = Vector2(-330, 16)
	am.custom_minimum_size = Vector2(220, 0)
	am.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(am)
	ammo_lbl = UI.outline(UI.label("12 / 60", 40, Color.WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT), 10)
	weapon_lbl = UI.outline(UI.label("مسدس", 20, Color(1.0, 0.85, 0.4), true, HORIZONTAL_ALIGNMENT_RIGHT), 8)
	am.add_child(ammo_lbl)
	am.add_child(weapon_lbl)
	# الهدف
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-330, 14)
	top.custom_minimum_size = Vector2(660, 0)
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	obj_panel = UI.panel(Color(0.03, 0.05, 0.08, 0.6), 12, 8)
	obj_lbl = UI.label("", 22, Color(1.0, 0.9, 0.55))
	obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_panel.add_child(obj_lbl)
	top.add_child(obj_panel)
	task_panel = UI.panel(Color(0.03, 0.05, 0.08, 0.6), 12, 8)
	var tv := VBoxContainer.new()
	task_panel.add_child(tv)
	task_lbl = UI.label("", 18)
	task_bar = _bar(Color(1.0, 0.75, 0.2), 14)
	tv.add_child(task_lbl)
	tv.add_child(task_bar)
	top.add_child(task_panel)
	task_panel.visible = false
	toast_lbl = UI.outline(UI.label("", 24), 10)
	top.add_child(toast_lbl)
	# مؤشّر الهدف
	way = Control.new()
	way.mouse_filter = Control.MOUSE_FILTER_IGNORE
	way.draw.connect(func():
		way.draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)]), Color(1.0, 0.8, 0.2, 0.95))
		way.draw_polyline(PackedVector2Array([Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0), Vector2(0, -16)]), Color(0.1, 0.08, 0.02), 2.0))
	root.add_child(way)
	way_lbl = UI.outline(UI.label("", 18, Color(1.0, 0.9, 0.5)), 8)
	way_lbl.position = Vector2(-40, 18)
	way_lbl.custom_minimum_size = Vector2(80, 0)
	way.add_child(way_lbl)
	# التفاعل
	prompt_panel = UI.panel(Color(0.03, 0.05, 0.08, 0.7), 14, 10)
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER)
	prompt_panel.position = Vector2(-200, 70)
	prompt_panel.custom_minimum_size = Vector2(400, 0)
	var pv := VBoxContainer.new()
	prompt_panel.add_child(pv)
	prompt_lbl = UI.label("", 22, Color(1.0, 0.85, 0.35))
	prompt_bar = _bar(Color(1.0, 0.8, 0.25), 10)
	pv.add_child(prompt_lbl)
	pv.add_child(prompt_bar)
	root.add_child(prompt_panel)
	# الترجمة
	sub_panel = UI.panel(Color(0.02, 0.03, 0.05, 0.72), 14, 10)
	sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_panel.position = Vector2(-380, -150)
	sub_panel.custom_minimum_size = Vector2(760, 0)
	sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sub_panel.add_child(sv)
	sub_name = UI.label("", 18, Color(0.4, 0.85, 0.9))
	sub_text = UI.label("", 24, Color.WHITE, false)
	sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sv.add_child(sub_name)
	sv.add_child(sub_text)
	root.add_child(sub_panel)
	sub_panel.visible = false
	# أشرطة سينمائية
	for i in 2:
		var cr := ColorRect.new()
		cr.color = Color.BLACK
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cr.set_anchors_preset(Control.PRESET_TOP_WIDE if i == 0 else Control.PRESET_BOTTOM_WIDE)
		if i == 1:
			cr.grow_vertical = Control.GROW_DIRECTION_BEGIN
		add_child(cr)
		bars.append(cr)
	touch = TouchControls.new()
	add_child(touch)
	touch.visible = Game.is_mobile or OS.get_cmdline_user_args().has("--touch")
	Game.subtitle.connect(_on_sub)
	Game.objective_changed.connect(func(t): obj_lbl.text = t; obj_panel.visible = t != "")
	Game.toast.connect(func(t, c): toast_lbl.text = t; toast_lbl.add_theme_color_override("font_color", c); _toast_t = 2.6)
	Game.hit_marker.connect(func(k, _h): _hit_t = 0.22; _hit_kill = k)
	Game.player_hurt.connect(_on_hurt)
	Game.state_changed.connect(_on_state)
	obj_panel.visible = false
	_on_state()


func _bar(col: Color, h: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, h)
	b.max_value = 100.0
	b.add_theme_stylebox_override("background", UI.box(Color(0, 0, 0, 0.55), 6, Color(1, 1, 1, 0.3), 1, 0))
	b.add_theme_stylebox_override("fill", UI.box(col, 6, Color(0, 0, 0, 0), 0, 0))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _on_state() -> void:
	var play: bool = Game.state == Game.State.PLAYING
	root.visible = play or Game.state == Game.State.CUTSCENE or Game.state == Game.State.PAUSED
	cross.visible = play
	_letter_target = 1.0 if Game.state == Game.State.CUTSCENE else 0.0


func _on_sub(speaker: String, text: String, time: float) -> void:
	_sub_q.append([speaker, text, time])


func _on_hurt(from: Vector3) -> void:
	_hurt = min(1.0, _hurt + 0.45)
	var p = Game.player
	if p:
		var to: Vector3 = from - p.global_position
		var local: Vector3 = p.global_transform.basis.inverse() * to
		_hurt_dir = atan2(local.x, -local.z)


func set_task(text: String, value: float) -> void:
	task_panel.visible = text != ""
	task_lbl.text = text
	task_bar.value = value * 100.0


func _draw_cross() -> void:
	var p = Game.player
	if p == null:
		return
	var c := cross.size * 0.5
	var d: Dictionary = Weapons.DEFS[p.cur]
	var spread: float = lerp(float(d["spread"]), float(d["ads_spread"]), p.ads_k) + p._spread_add + clamp(p.speed_now() * 0.25, 0.0, 1.6)
	var gap: float = 5.0 + spread * 6.0
	var col := Color(1, 1, 1, 0.9)
	if p._reload_t > 0.0:
		cross.draw_arc(c, 22.0, -PI / 2, -PI / 2 + TAU * (1.0 - p._reload_t / max(0.1, p._reload_total)), 32, Color(1.0, 0.85, 0.3, 0.9), 3.0, true)
	else:
		for v in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			cross.draw_line(c + v * gap, c + v * (gap + 9.0), Color(0, 0, 0, 0.6), 4.0)
			cross.draw_line(c + v * gap, c + v * (gap + 9.0), col, 2.0)
		cross.draw_circle(c, 1.6, col)
	if _hit_t > 0.0:
		var hc := Color(1.0, 0.25, 0.2, 1.0) if _hit_kill else Color(1, 1, 1, 1)
		hc.a = _hit_t / 0.22
		for v in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			cross.draw_line(c + v * 9.0, c + v * 18.0, hc, 3.0)
	if _hurt > 0.05:
		cross.draw_arc(c, 120.0, _hurt_dir - PI / 2 - 0.35, _hurt_dir - PI / 2 + 0.35, 16, Color(1.0, 0.15, 0.1, _hurt), 8.0, true)


func _process(delta: float) -> void:
	_letter = move_toward(_letter, _letter_target, delta * 2.5)
	var vh := get_viewport().get_visible_rect().size.y
	for b in bars:
		b.custom_minimum_size.y = vh * 0.11 * _letter
		b.size.y = vh * 0.11 * _letter
		b.visible = _letter > 0.01
	bars[1].position.y = vh - bars[1].size.y
	# الترجمة
	_sub_t -= delta
	if _sub_t <= 0.0:
		if _sub_q.is_empty():
			sub_panel.visible = false
		else:
			var s: Array = _sub_q.pop_front()
			sub_name.text = s[0]
			sub_name.visible = s[0] != ""
			sub_text.text = s[1]
			_sub_t = s[2]
			sub_panel.visible = true
			sub_panel.reset_size()
	var p = Game.player
	if p == null or not root.visible:
		return
	_hit_t = max(0.0, _hit_t - delta)
	_hurt = max(0.0, _hurt - delta * 0.7)
	_toast_t -= delta
	toast_lbl.modulate.a = clamp(_toast_t, 0.0, 1.0)
	hp_bar.value = p.hp
	ar_bar.value = p.armor
	ar_bar.visible = p.armor > 0.5
	var st: Dictionary = p.inv[p.cur]
	ammo_lbl.text = "%d / %d" % [st["mag"], st["reserve"]]
	ammo_lbl.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if st["mag"] <= Weapons.DEFS[p.cur]["mag"] / 4 else Color.WHITE)
	weapon_lbl.text = Weapons.DEFS[p.cur]["name"] + ("  •  يحمل الذهب" if p.carrying else "")
	var sm: ShaderMaterial = vignette.material
	sm.set_shader_parameter("amount", _hurt * 0.7)
	sm.set_shader_parameter("low", clamp((40.0 - p.hp) / 40.0, 0.0, 1.0) * 0.45)
	cross.queue_redraw()
	# التفاعل
	var it: Interactable = p.interact_target
	prompt_panel.visible = it != null and Game.state == Game.State.PLAYING
	if it:
		prompt_lbl.text = ("اضغط «تفاعل»: " if touch.visible else "[E]  ") + it.prompt
		prompt_bar.visible = it.hold_time > 0.0 and p.interact_progress > 0.0
		prompt_bar.value = p.interact_progress * 100.0
	# مؤشّر الهدف
	way.visible = waypoint != null and Game.state == Game.State.PLAYING
	if way.visible:
		var cam: Camera3D = p.cam
		var wp: Vector3 = waypoint
		var vs := get_viewport().get_visible_rect().size
		var sp := cam.unproject_position(wp)
		var behind := cam.is_position_behind(wp)
		if behind:
			sp = vs - sp
			sp.y = vs.y - 90.0
		sp.x = clamp(sp.x, 60.0, vs.x - 60.0)
		sp.y = clamp(sp.y, 110.0, vs.y - 120.0)
		way.position = sp
		way_lbl.text = "%d م" % int(p.global_position.distance_to(wp))
