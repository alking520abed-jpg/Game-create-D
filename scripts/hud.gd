class_name HUD
extends CanvasLayer
## واجهة اللعب: النقود، النجوم، المهمة، السرعة، الإشعارات.

class Icon:
	extends Control
	var kind := "coin"

	func _init(k: String, s := 34.0) -> void:
		kind = k
		custom_minimum_size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r: float = min(size.x, size.y) / 2 - 1
		if kind == "coin":
			draw_circle(c, r, Color(0.85, 0.6, 0.1))
			draw_circle(c, r * 0.78, Color(1.0, 0.82, 0.25))
			draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.45), Vector2(r * 0.24, r * 0.9)), Color(0.85, 0.6, 0.1))
		else:
			TouchControls.draw_icon(self, "mission", c, r * 0.9, Color(1.0, 0.82, 0.25))

class Arrow:
	extends Control
	var angle := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(44, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var f := Vector2(sin(angle), -cos(angle))
		var n := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([c + f * 20, c - f * 12 + n * 13, c - f * 5, c - f * 12 - n * 13]), Color(1.0, 0.92, 0.2))

var root: Control
var touch: TouchControls
var minimap: Minimap
var money_lbl: Label
var star_lbl: Label
var clock_lbl: Label
var m_panel: PanelContainer
var m_title: Label
var m_obj: Label
var m_timer: Label
var m_dist: Label
var m_arrow: Arrow
var speed_lbl: Label
var hint_lbl: Label
var toasts: VBoxContainer
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var count_lbl: Label
var _banner_tw: Tween
var _shown_money := 0.0


func _ready() -> void:
	layer = 1
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	touch = TouchControls.new()
	root.add_child(touch)
	# الخريطة
	minimap = Minimap.new()
	minimap.position = Vector2(16, 16)
	minimap.size = Vector2(196, 196)
	root.add_child(minimap)
	clock_lbl = UI.outline(UI.label("09:00", 22))
	clock_lbl.position = Vector2(16, 214)
	clock_lbl.size = Vector2(196, 30)
	root.add_child(clock_lbl)
	# النقود والنجوم
	var mp := UI.panel()
	mp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mp.position = Vector2(-16, 14)
	root.add_child(mp)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(hb)
	star_lbl = UI.label("0/0", 26)
	hb.add_child(star_lbl)
	hb.add_child(Icon.new("star"))
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(14, 0)
	hb.add_child(sep)
	money_lbl = UI.label("0 ريال", 26, Color(1, 0.9, 0.5))
	hb.add_child(money_lbl)
	hb.add_child(Icon.new("coin"))
	# لوحة المهمة
	m_panel = UI.panel(Color(0.04, 0.07, 0.12, 0.78))
	m_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	m_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	m_panel.position.y = 12
	m_panel.custom_minimum_size = Vector2(470, 0)
	root.add_child(m_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m_panel.add_child(vb)
	m_title = UI.label("", 24, Color(1, 0.85, 0.3))
	vb.add_child(m_title)
	m_obj = UI.label("", 22)
	m_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(m_obj)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(row)
	m_timer = UI.label("", 30, Color(0.5, 1.0, 0.6))
	row.add_child(m_timer)
	m_arrow = Arrow.new()
	row.add_child(m_arrow)
	m_dist = UI.label("", 26)
	row.add_child(m_dist)
	# السرعة والتلميحات
	speed_lbl = UI.outline(UI.label("", 34), 10)
	speed_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	speed_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	speed_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	speed_lbl.position.y = -52
	root.add_child(speed_lbl)
	hint_lbl = UI.outline(UI.label("", 24, Color(1, 0.95, 0.7)), 10)
	hint_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_lbl.position.y = -112
	root.add_child(hint_lbl)
	# الإشعارات
	toasts = VBoxContainer.new()
	toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.position.y = 345
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)
	# اللافتة الكبيرة
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.position.y = 205
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	banner_title = UI.outline(UI.label("", 60), 16)
	banner_box.add_child(banner_title)
	banner_sub = UI.outline(UI.label("", 30), 12)
	banner_box.add_child(banner_sub)
	count_lbl = UI.outline(UI.label("", 150, Color(1, 0.9, 0.3)), 24)
	count_lbl.set_anchors_preset(Control.PRESET_CENTER)
	count_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	count_lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(count_lbl)
	Game.toast.connect(_on_toast)
	Game.banner.connect(_on_banner)
	_shown_money = Game.money


func _on_toast(text: String, color: Color) -> void:
	var p := UI.panel(Color(0.04, 0.07, 0.12, 0.8), 14, 8)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(UI.label(text, 24, color))
	toasts.add_child(p)
	if toasts.get_child_count() > 3:
		toasts.get_child(0).queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func _on_banner(title: String, sub: String, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	if _banner_tw:
		_banner_tw.kill()
	banner_box.modulate.a = 0.0
	banner_box.scale = Vector2(0.8, 0.8)
	banner_box.pivot_offset = banner_box.size / 2
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	_banner_tw.parallel().tween_property(banner_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_interval(2.6)
	_banner_tw.tween_property(banner_box, "modulate:a", 0.0, 0.6)


func _process(delta: float) -> void:
	root.visible = Game.state == Game.State.PLAYING
	if not root.visible:
		return
	var ms: Missions = Game.missions
	var car = Game.car
	var nc = Game.near_car
	var label := "اركب"
	if nc != null and nc.locked():
		label = "اشترِ"
	touch.update_state(car != null, nc != null, label, ms.near != null)
	_shown_money = lerp(_shown_money, float(Game.money), min(1.0, delta * 8.0))
	if abs(_shown_money - Game.money) < 1.0:
		_shown_money = Game.money
	money_lbl.text = "%d ريال" % int(round(_shown_money))
	star_lbl.text = "%d/%d" % [Game.stars.size(), ms.star_total]
	clock_lbl.text = Game.main.daynight.clock_text()
	# المهمة
	if ms.is_active():
		m_panel.visible = true
		m_title.text = ms.active["title"]
		m_obj.text = ms.objective
		m_timer.visible = ms.timer >= 0.0 and ms.countdown <= 0.0
		if m_timer.visible:
			m_timer.text = "%d:%02d" % [int(ms.timer) / 60, int(ms.timer) % 60]
			m_timer.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if ms.timer < 10.0 else Color(0.5, 1.0, 0.6))
		if ms.target != null:
			var pp := Game.pos()
			var to: Vector3 = ms.target - pp
			m_dist.text = "%d م" % int(Vector2(to.x, to.z).length())
			var yaw: float = Game.cam.yaw
			var f := to.x * -sin(yaw) + to.z * -cos(yaw)
			var r := to.x * cos(yaw) + to.z * -sin(yaw)
			m_arrow.angle = atan2(r, f)
			m_arrow.queue_redraw()
			m_arrow.visible = true
			m_dist.visible = true
		else:
			m_arrow.visible = false
			m_dist.visible = false
	else:
		m_panel.visible = false
	if ms.countdown > 0.0:
		var c := int(ceil(ms.countdown - 0.5))
		count_lbl.text = str(c) if c > 0 else "انطلق!"
	else:
		count_lbl.text = ""
	# السرعة والتلميح
	if car != null:
		speed_lbl.text = "%d كم/س" % int(abs(car.speed) * 3.6)
	else:
		speed_lbl.text = ""
	var hint := ""
	if car == null and nc != null:
		if nc.locked():
			hint = "%s — السعر %d ريال. اضغط «اشترِ»" % [nc.spec["name"], nc.price]
		else:
			hint = "اضغط «اركب» لقيادة السيارة (%s)" % nc.spec["name"]
	if ms.near != null:
		hint = "%s — اضغط «ابدأ المهمة»" % ms.near["title"]
	hint_lbl.text = hint
