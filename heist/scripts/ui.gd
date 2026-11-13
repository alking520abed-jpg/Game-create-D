class_name UI
extends RefCounted
## أدوات مساعدة للواجهة.


static func box(bg: Color, radius := 16, border := Color(0, 0, 0, 0), bw := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, fsize := 24, col := Color.WHITE, bold := true, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.font_bold if bold else Game.font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outline(l: Label, size := 8, col := Color(0, 0, 0, 0.85)) -> Label:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", col)
	return l


static func panel(bg := Color(0.04, 0.07, 0.12, 0.72), radius := 16, pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, Color(1, 1, 1, 0.25), 2, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func button(text: String, col := Color(0.12, 0.45, 0.75), fsize := 28) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 66)
	b.add_theme_font_override("font", Game.font_bold)
	b.add_theme_font_size_override("font_size", fsize)
	b.add_theme_stylebox_override("normal", box(col, 18, Color(1, 1, 1, 0.35), 2))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.15), 18, Color(1, 1, 1, 0.6), 2))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.25), 18, Color(1, 1, 1, 0.6), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func(): Audio.play("click", -6.0))
	return b
