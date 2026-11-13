class_name TouchControls
extends Control
## أزرار اللمس: عصا تحريك + أزرار واضحة بأسماء عربية.

signal look(delta: Vector2)

class TBtn:
	extends Control
	var kind := ""
	var label := ""
	var col := Color.WHITE
	var action := ""
	var hold := false
	var radius := 60.0
	var pressed := false
	var touch_idx := -1
	var pulse := false
	var dim := false        # مقفل
	var lit := false        # مفعّل حالياً
	var _t := 0.0

	func setup(p_kind: String, p_label: String, p_col: Color, p_action: String, p_hold: bool, p_radius: float) -> TBtn:
		kind = p_kind
		label = p_label
		col = p_col
		action = p_action
		hold = p_hold
		radius = p_radius
		size = Vector2(radius * 2, radius * 2)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return self

	func place(center: Vector2) -> void:
		position = center - Vector2(radius, radius)

	func hit(p: Vector2) -> bool:
		return visible and p.distance_to(position + Vector2(radius, radius)) <= radius * 1.12

	func _process(delta: float) -> void:
		if pulse and visible:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var c := Vector2(radius, radius)
		var r := radius
		if pulse:
			r = radius * (0.94 + 0.06 * sin(_t * 6.0))
		if kind == "form":
			var a: float = 0.3 if dim else 1.0
			draw_circle(c, r, Color(col.r, col.g, col.b, 0.85) if (lit or pressed) else Color(0.04, 0.06, 0.1, 0.55))
			draw_arc(c, r - 2.0, 0, TAU, 40, Color(col.r, col.g, col.b, a), 4.0, true)
			var tc := Color(0.05, 0.05, 0.08) if lit else Color(1, 1, 1, a)
			draw_string(Game.font_bold, Vector2(0, c.y + r * 0.2), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, int(r * 0.5), tc)
			if dim:
				draw_rect(Rect2(c + Vector2(-r * 0.22, r * 0.38), Vector2(r * 0.44, r * 0.32)), Color(1, 1, 1, 0.6))
				draw_arc(c + Vector2(0, r * 0.38), r * 0.16, PI, TAU, 10, Color(1, 1, 1, 0.6), 3.0)
			return
		draw_circle(c, r, Color(col.r, col.g, col.b, 0.8) if pressed else Color(0.04, 0.06, 0.1, 0.5))
		if pulse and not pressed:
			draw_circle(c, r, Color(col.r, col.g, col.b, 0.35))
		draw_arc(c, r - 3.0, 0, TAU, 48, col, 5.0, true)
		var ic := Color.WHITE
		var has_label := label != ""
		var icon_c := c + Vector2(0, -r * 0.2) if has_label else c
		TouchControls.draw_icon(self, kind, icon_c, r * (0.36 if has_label else 0.5), ic)
		if has_label:
			var fs := int(max(15.0, r * 0.34))
			draw_string(Game.font_bold, Vector2(0, c.y + r * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, fs, Color.WHITE)


var buttons := {}
var joy_center := Vector2(190, 530)
var joy_r := 105.0
var joy_idx := -1
var joy_knob := Vector2.ZERO
var look_idx := -1
var in_car := false
var _last_size := Vector2.ZERO


static func draw_icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	match kind:
		"attack":
			var pts2 := PackedVector2Array()
			for i in 16:
				var a2 := TAU * i / 16.0
				var r2 := s * 1.15 if i % 2 == 0 else s * 0.6
				pts2.append(c + Vector2(cos(a2), sin(a2)) * r2)
			ci.draw_colored_polygon(pts2, col)
			ci.draw_circle(c, s * 0.3, Color(0, 0, 0, 0.45))
		"special":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.35, -s * 1.15), c + Vector2(-s * 0.7, s * 0.15), c + Vector2(-s * 0.05, s * 0.15), c + Vector2(-s * 0.35, s * 1.15), c + Vector2(s * 0.7, -s * 0.2), c + Vector2(s * 0.05, -s * 0.2)]), col)
		"up":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.5), c + Vector2(-s, s * 0.5)]), col)
		"down":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s), c + Vector2(s, -s * 0.5), c + Vector2(-s, -s * 0.5)]), col)
		"form":
			ci.draw_arc(c, s * 0.9, 0.4, TAU - 0.4, 20, col, s * 0.25, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.3, -s * 0.5), c + Vector2(s * 0.5, -s * 0.6), c + Vector2(s * 1.0, s * 0.15)]), col)
		"jump":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.9, 0), c + Vector2(s * 0.35, 0), c + Vector2(s * 0.35, s), c + Vector2(-s * 0.35, s), c + Vector2(-s * 0.35, 0), c + Vector2(-s * 0.9, 0)]), col)
		"gas":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, s * 0.1), c + Vector2(-s, s * 0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.25), Vector2(s * 0.8, s * 0.3)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, s * 0.7), Vector2(s * 0.8, s * 0.2)), col)
		"brake":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s), c + Vector2(s, -s * 0.1), c + Vector2(-s, -s * 0.1)]), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.55), Vector2(s * 0.8, s * 0.3)), col)
		"left":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(s * 0.6, -s), c + Vector2(s * 0.6, s)]), col)
		"right":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s * 0.6, -s), c + Vector2(-s * 0.6, s)]), col)
		"run":
			for k in 2:
				var o := Vector2(-s * 0.55 + k * s * 0.8, 0)
				ci.draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.3, -s * 0.8), c + o + Vector2(s * 0.4, 0), c + o + Vector2(-s * 0.3, s * 0.8)]), col, s * 0.3, true)
		"enter", "buy":
			# سيارة صغيرة
			ci.draw_rect(Rect2(c + Vector2(-s * 1.1, -s * 0.1), Vector2(s * 2.2, s * 0.6)), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.1), c + Vector2(-s * 0.35, -s * 0.7), c + Vector2(s * 0.4, -s * 0.7), c + Vector2(s * 0.7, -s * 0.1)]), col)
			ci.draw_circle(c + Vector2(-s * 0.6, s * 0.55), s * 0.3, col)
			ci.draw_circle(c + Vector2(s * 0.6, s * 0.55), s * 0.3, col)
			ci.draw_circle(c + Vector2(-s * 0.6, s * 0.55), s * 0.12, Color(0, 0, 0, 0.6))
			ci.draw_circle(c + Vector2(s * 0.6, s * 0.55), s * 0.12, Color(0, 0, 0, 0.6))
		"exit":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.9, -s), Vector2(s * 0.9, s * 2.0)), col, false, s * 0.22)
			ci.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.7, 0), col, s * 0.26)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.15, 0), c + Vector2(s * 0.55, -s * 0.5), c + Vector2(s * 0.55, s * 0.5)]), col)
		"hand":
			ci.draw_arc(c, s * 0.95, 0, TAU, 32, col, s * 0.2, true)
			ci.draw_string(Game.font_bold, c + Vector2(-s, s * 0.5), "P", HORIZONTAL_ALIGNMENT_CENTER, s * 2, int(s * 1.3), col)
		"horn":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.35), c + Vector2(-s * 0.4, -s * 0.35), c + Vector2(s * 0.2, -s * 0.9), c + Vector2(s * 0.2, s * 0.9), c + Vector2(-s * 0.4, s * 0.35), c + Vector2(-s, s * 0.35)]), col)
			ci.draw_arc(c + Vector2(s * 0.2, 0), s * 0.55, -0.9, 0.9, 12, col, s * 0.16, true)
			ci.draw_arc(c + Vector2(s * 0.2, 0), s * 0.95, -0.9, 0.9, 12, col, s * 0.16, true)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 0.8), Vector2(s * 0.5, s * 1.6)), col)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.8), Vector2(s * 0.5, s * 1.6)), col)
		"cam":
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.55), Vector2(s * 2.0, s * 1.3)), col)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.4, -s * 0.85), Vector2(s * 0.8, s * 0.35)), col)
			ci.draw_circle(c + Vector2(0, s * 0.1), s * 0.42, Color(0, 0, 0, 0.6))
		"mission":
			var pts := PackedVector2Array()
			for i in 10:
				var a := TAU * i / 10.0 - PI / 2
				var r := s * 1.1 if i % 2 == 0 else s * 0.48
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			ci.draw_colored_polygon(pts, col)
		"joy":
			ci.draw_circle(c, s * 0.5, col)
			for k in 4:
				var d := Vector2.RIGHT.rotated(k * PI / 2)
				var n := d.rotated(PI / 2)
				ci.draw_colored_polygon(PackedVector2Array([c + d * s * 1.2, c + d * s * 0.75 + n * s * 0.3, c + d * s * 0.75 - n * s * 0.3]), col)
		"drag":
			ci.draw_arc(c, s * 0.9, -2.6, -0.5, 16, col, s * 0.2, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.05, -s * 0.1), c + Vector2(s * 0.45, -s * 0.5), c + Vector2(s * 0.95, -s * 0.85)]), col)
			ci.draw_circle(c + Vector2(0, s * 0.35), s * 0.3, col)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var green := Color(0.25, 0.85, 0.4)
	var red := Color(0.95, 0.3, 0.25)
	var blue := Color(0.3, 0.65, 1.0)
	var yellow := Color(1.0, 0.8, 0.2)
	var grey := Color(0.8, 0.82, 0.88)
	_add("jump", "قفز", blue, "jump", false, 62)
	_add("run", "جري", green, "run", true, 58)
	_add("attack", "هجوم", red, "attack", true, 86)
	_add("special", "قدرة", Color(1.0, 0.5, 0.9), "special", false, 60)
	_add("up", "صعود", blue, "fly_up", true, 58)
	_add("down", "نزول", blue, "fly_down", true, 60)
	for i in 5:
		var fm: Dictionary = Player.FORMS[i + 1]
		_add("form%d" % (i + 1), fm["name"], fm["color"], "form%d" % (i + 1), false, 42)
		buttons["form%d" % (i + 1)].kind = "form"
	_add("enter", "اركب", yellow, "interact", false, 64)
	_add("mission", "ابدأ المهمة", Color(1.0, 0.5, 0.9), "mission", false, 70)
	_add("left", "يسار", grey, "steer_left", true, 84)
	_add("right", "يمين", grey, "steer_right", true, 84)
	_add("gas", "بنزين", green, "gas", true, 90)
	_add("brake", "فرامل", red, "brake", true, 74)
	_add("hand", "يدوي", yellow, "handbrake", true, 54)
	_add("horn", "زمور", grey, "horn", false, 52)
	_add("exit", "انزل", yellow, "interact", false, 56)
	_add("pause", "", grey, "pause", false, 34)
	_add("cam", "", grey, "cam", false, 34)
	buttons["mission"].pulse = true
	buttons["enter"].pulse = true


func _add(kind: String, label: String, col: Color, action: String, hold: bool, r: float) -> void:
	var b := TBtn.new().setup(kind, label, col, action, hold, r)
	add_child(b)
	buttons[kind] = b


func _layout() -> void:
	var s := size
	_last_size = s
	var W := s.x
	var H := s.y
	joy_center = Vector2(185, H - 185)
	buttons["attack"].place(Vector2(W - 130, H - 140))
	buttons["jump"].place(Vector2(W - 312, H - 98))
	buttons["down"].place(Vector2(W - 312, H - 98))
	buttons["special"].place(Vector2(W - 285, H - 248))
	buttons["enter"].place(Vector2(W - 112, H - 318))
	buttons["up"].place(Vector2(W - 112, H - 318))
	buttons["run"].place(Vector2(-500, -500))
	for i in 5:
		buttons["form%d" % (i + 1)].place(Vector2(W * 0.5 - 196 + i * 92 + 14, H - 54))
	buttons["left"].place(Vector2(125, H - 140))
	buttons["right"].place(Vector2(320, H - 140))
	buttons["gas"].place(Vector2(W - 135, H - 150))
	buttons["brake"].place(Vector2(W - 325, H - 115))
	buttons["hand"].place(Vector2(W - 300, H - 270))
	buttons["horn"].place(Vector2(W - 110, H - 320))
	buttons["exit"].place(Vector2(W - 480, H - 85))
	buttons["mission"].place(Vector2(W - 455, H - 215))
	buttons["pause"].place(Vector2(W - 50, 118))
	buttons["cam"].place(Vector2(W - 132, 118))


## تحديث الأزرار الظاهرة حسب الحالة
func update_state(p_in_car: bool, can_enter: bool, enter_label: String, mission_prompt: bool) -> void:
	if size != _last_size:
		_layout()
	if p_in_car != in_car:
		in_car = p_in_car
		_release_all()
		queue_redraw()
	var pl: Player = Game.player
	var fly: bool = pl != null and pl.flying() and not in_car
	var fidx: int = pl.form if pl != null else 0
	buttons["run"].visible = false
	buttons["jump"].visible = not in_car and not fly
	buttons["up"].visible = fly
	buttons["down"].visible = fly
	buttons["attack"].visible = not in_car
	var sb: TBtn = buttons["special"]
	sb.visible = not in_car and fidx != 0
	if sb.visible:
		var txt: String = Player.FORMS[fidx]["sp_name"]
		if pl.sp_cd > 0.0:
			txt = "%d ث" % int(ceil(pl.sp_cd))
		if sb.label != txt or sb.col != Player.FORMS[fidx]["color"]:
			sb.label = txt
			sb.col = Player.FORMS[fidx]["color"]
			sb.queue_redraw()
	for i in 5:
		var fb: TBtn = buttons["form%d" % (i + 1)]
		fb.visible = not in_car and Game.unlocked > 0
		var d: bool = i + 1 > Game.unlocked
		var l: bool = fidx == i + 1
		if fb.dim != d or fb.lit != l:
			fb.dim = d
			fb.lit = l
			fb.queue_redraw()
	for k in ["left", "right", "gas", "brake", "hand", "horn", "exit"]:
		buttons[k].visible = in_car
	var e: TBtn = buttons["enter"]
	e.visible = not in_car and can_enter and not fly
	if e.label != enter_label:
		e.label = enter_label
		e.kind = "buy" if enter_label != "اركب" else "enter"
		e.queue_redraw()
	buttons["mission"].visible = mission_prompt


func _release_all() -> void:
	for k in buttons:
		var b: TBtn = buttons[k]
		if b.pressed:
			b.pressed = false
			b.touch_idx = -1
			if b.hold:
				Input.action_release(b.action)
			b.queue_redraw()
	joy_idx = -1
	look_idx = -1
	Game.joy = Vector2.ZERO
	joy_knob = Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release_all()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or Game.state != Game.State.PLAYING:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = make_input_local(event).position
		if event.pressed:
			for k in buttons:
				var b: TBtn = buttons[k]
				if b.touch_idx == -1 and b.hit(p):
					b.pressed = true
					b.touch_idx = event.index
					if b.hold:
						Input.action_press(b.action)
					else:
						Game.tap(b.action)
					b.queue_redraw()
					return
			if not in_car and joy_idx == -1 and p.distance_to(joy_center) < joy_r * 1.9:
				joy_idx = event.index
				_joy(p)
			elif look_idx == -1:
				look_idx = event.index
		else:
			for k in buttons:
				var b: TBtn = buttons[k]
				if b.touch_idx == event.index:
					b.pressed = false
					b.touch_idx = -1
					if b.hold:
						Input.action_release(b.action)
					b.queue_redraw()
			if event.index == joy_idx:
				joy_idx = -1
				Game.joy = Vector2.ZERO
				joy_knob = Vector2.ZERO
				queue_redraw()
			if event.index == look_idx:
				look_idx = -1
	elif event is InputEventScreenDrag:
		if event.index == joy_idx:
			_joy(make_input_local(event).position)
		elif event.index == look_idx:
			look.emit(event.relative)


func _joy(p: Vector2) -> void:
	var v := (p - joy_center) / joy_r
	if v.length() > 1.0:
		v = v.normalized()
	joy_knob = v
	Game.joy = v if v.length() > 0.12 else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if in_car:
		return
	draw_circle(joy_center, joy_r, Color(0.04, 0.06, 0.1, 0.4))
	draw_arc(joy_center, joy_r - 2, 0, TAU, 56, Color(0.85, 0.9, 1.0, 0.8), 4.0, true)
	draw_icon(self, "joy", joy_center, joy_r * 0.72, Color(1, 1, 1, 0.22))
	var kp := joy_center + joy_knob * joy_r * 0.75
	draw_circle(kp, joy_r * 0.42, Color(0.3, 0.65, 1.0, 0.85))
	draw_arc(kp, joy_r * 0.42, 0, TAU, 32, Color.WHITE, 3.0, true)
	draw_string(Game.font_bold, Vector2(joy_center.x - 100, joy_center.y + joy_r + 30), "تحريك", HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color(1, 1, 1, 0.9))
