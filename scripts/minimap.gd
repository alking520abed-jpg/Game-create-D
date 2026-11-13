class_name Minimap
extends Control
## خريطة صغيرة: الشوارع، المهمات، الهدف، واللاعب.

const RANGE := 190.0
const BLOCK_COL := [Color(0.72, 0.7, 0.66), Color(0.32, 0.62, 0.28), Color(0.4, 0.4, 0.44), Color(0.8, 0.7, 0.5), Color(0.6, 0.75, 0.85), Color(0.3, 0.7, 0.65), Color(0.85, 0.4, 0.35), Color(0.8, 0.7, 0.5)]
var _t := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var pp := Game.pos()
	var c := size / 2
	var sc := size.x / (2.0 * RANGE)
	var to_map := func(p: Vector3) -> Vector2: return c + Vector2(p.x - pp.x, p.z - pp.z) * sc
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.86, 0.74, 0.5))
	# البحر
	var sea: Vector2 = to_map.call(Vector3(-2000, 0, City.SEA_Z))
	draw_rect(Rect2(Vector2(0, sea.y), Vector2(size.x, size.y)), Color(0.15, 0.5, 0.7))
	# المدينة (لون الشوارع)
	var h := City.HALF + 7.0
	var a: Vector2 = to_map.call(Vector3(-h, 0, -h))
	draw_rect(Rect2(a, Vector2(h * 2, h * 2) * sc), Color(0.2, 0.21, 0.24))
	for bx in City.N:
		for bz in City.N:
			var bc := City.block_center(bx, bz)
			if abs(bc.x - pp.x) > RANGE + 40 or abs(bc.z - pp.z) > RANGE + 40:
				continue
			var t: int = City.block_type_at(Vector2i(bx, bz))
			var p0: Vector2 = to_map.call(bc - Vector3(29, 0, 29))
			draw_rect(Rect2(p0, Vector2(58, 58) * sc), BLOCK_COL[t])
	draw_rect(Rect2(to_map.call(Vector3(96.5, 0, 392)), Vector2(7, 98) * sc), Color(0.5, 0.35, 0.2))
	var ms = Game.missions
	if ms != null:
		if not ms.is_active():
			for d in ms.defs:
				var p: Vector2 = to_map.call(d["pos"])
				if Rect2(Vector2.ZERO, size).has_point(p):
					draw_circle(p, 7.0, Color.BLACK)
					draw_circle(p, 5.5, Missions.TYPE_COLOR[d["type"]])
		elif ms.target != null:
			var p: Vector2 = to_map.call(ms.target)
			var q := p.clamp(Vector2(10, 10), size - Vector2(10, 10))
			var r := 8.0 + sin(_t * 6.0) * 2.5
			draw_circle(q, r + 2.0, Color.BLACK)
			draw_circle(q, r, Color(1.0, 0.92, 0.2))
	# القصة والأعداء
	var st = Game.story
	if st != null:
		if st.marker.visible:
			var mp: Vector2 = to_map.call(st.marker.position)
			var mq := mp.clamp(Vector2(10, 10), size - Vector2(10, 10))
			var rr := 7.0 + sin(_t * 5.0) * 2.0
			draw_circle(mq, rr + 2.0, Color.BLACK)
			draw_circle(mq, rr, Color(0.8, 0.45, 1.0))
		elif st.active and st.target != null:
			var tp: Vector2 = to_map.call(st.target)
			var tq := tp.clamp(Vector2(10, 10), size - Vector2(10, 10))
			draw_circle(tq, 9.0, Color.BLACK)
			draw_circle(tq, 7.0, Color(1.0, 0.92, 0.2))
	if Game.combat != null:
		for e in Game.combat.enemies:
			if is_instance_valid(e) and not e.dead:
				var ep: Vector2 = to_map.call(e.global_position)
				if Rect2(Vector2.ZERO, size).has_point(ep):
					draw_circle(ep, 5.0 if e.is_boss() else 3.5, Color(1.0, 0.15, 0.1))
	# اللاعب
	var yaw: float = Game.car.rotation.y if Game.car != null else (Game.player.rig.rotation.y if Game.player != null else 0.0)
	var f := Vector2(-sin(yaw), -cos(yaw))
	var n := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([c + f * 11.0, c - f * 7.0 + n * 7.0, c - f * 3.0, c - f * 7.0 - n * 7.0])
	draw_colored_polygon(tri, Color.WHITE)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color(0.1, 0.3, 0.8), 2.5, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.9), false, 4.0)
	draw_string(Game.font_bold, Vector2(0, 18), "ش", HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.9))
