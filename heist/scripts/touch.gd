class_name TouchControls
extends Control
## أزرار اللمس: عصا حركة عائمة يساراً، سحب للنظر يميناً، وأزرار دائرية بأسمائها.

const BTN := {
	"fire": {"off": Vector2(-175, -190), "r": 72.0, "label": "نار", "col": Color(0.95, 0.3, 0.25), "hold": true},
	"jump": {"off": Vector2(-72, -92), "r": 44.0, "label": "قفز", "col": Color(0.4, 0.7, 1.0)},
	"aim": {"off": Vector2(-325, -112), "r": 52.0, "label": "تصويب", "col": Color(1.0, 0.8, 0.3)},
	"crouch": {"off": Vector2(-322, -246), "r": 42.0, "label": "انخفاض", "col": Color(0.75, 0.78, 0.85)},
	"reload": {"off": Vector2(-200, -352), "r": 44.0, "label": "تلقيم", "col": Color(0.5, 0.9, 0.55)},
	"next_weapon": {"off": Vector2(-76, -330), "r": 44.0, "label": "سلاح", "col": Color(0.75, 0.78, 0.85)},
	"interact": {"off": Vector2(-350, -388), "r": 54.0, "label": "تفاعل", "col": Color(1.0, 0.82, 0.25), "ctx": true},
	"pause": {"off": Vector2(-56, 54), "r": 34.0, "label": "II", "col": Color(0.85, 0.87, 0.92), "top": true},
}

var _touch := {}      # index -> {"kind": "joy"/"look"/"btn", "id": ...}
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_on := false
var _down := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _center(id: String) -> Vector2:
	var b: Dictionary = BTN[id]
	var off: Vector2 = b["off"]
	var x := size.x + off.x
	if Game.settings["lefty"] and id != "pause":
		x = -off.x
	return Vector2(x, off.y if b.get("top", false) else size.y + off.y)


func _visible_btn(id: String) -> bool:
	if BTN[id].get("ctx", false):
		return Game.player != null and Game.player.interact_target != null
	return true


func _hit(pos: Vector2) -> String:
	for id in BTN:
		if _visible_btn(id) and pos.distance_to(_center(id)) < BTN[id]["r"] * 1.15:
			return id
	return ""


func _release_all() -> void:
	_touch.clear()
	_joy_on = false
	Game.joy = Vector2.ZERO
	for id in _down.keys():
		Game.held[id] = false
	_down.clear()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if Game.state != Game.State.PLAYING:
		if not _touch.is_empty():
			_release_all()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _hit(event.position)
			var joy_side: bool = (event.position.x < size.x * 0.42) != bool(Game.settings["lefty"])
			if id != "":
				_touch[event.index] = {"kind": "btn", "id": id}
				_down[id] = true
				if BTN[id].get("hold", false):
					Game.held[id] = true
				else:
					Game.tap(id)
			elif joy_side and not _joy_on:
				_touch[event.index] = {"kind": "joy"}
				_joy_on = true
				_joy_origin = event.position
				_joy_pos = event.position
			else:
				_touch[event.index] = {"kind": "look"}
		elif _touch.has(event.index):
			var t: Dictionary = _touch[event.index]
			if t["kind"] == "joy":
				_joy_on = false
				Game.joy = Vector2.ZERO
			elif t["kind"] == "btn":
				_down.erase(t["id"])
				Game.held[t["id"]] = false
			_touch.erase(event.index)
		queue_redraw()
	elif event is InputEventScreenDrag and _touch.has(event.index):
		var t2: Dictionary = _touch[event.index]
		if t2["kind"] == "joy":
			_joy_pos = event.position
			var v := (_joy_pos - _joy_origin) / 90.0
			if v.length() > 1.0:
				v = v.normalized()
			Game.joy = v if v.length() > 0.12 else Vector2.ZERO
			queue_redraw()
		elif t2["kind"] == "look" or (t2["kind"] == "btn" and t2["id"] == "fire"):
			Game.look_delta += event.relative * 1.6


func _process(_d: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if Game.state != Game.State.PLAYING:
		return
	var f := Game.font_bold
	for id in BTN:
		if not _visible_btn(id):
			continue
		var b: Dictionary = BTN[id]
		var c := _center(id)
		var r: float = b["r"]
		var on: bool = _down.has(id) or (id == "aim" and Game.player and Game.player.ads) or (id == "crouch" and Game.player and Game.player.crouching)
		var col: Color = b["col"]
		draw_circle(c, r, Color(0.05, 0.07, 0.1, 0.42 if not on else 0.7))
		draw_arc(c, r, 0, TAU, 40, Color(col.r, col.g, col.b, 0.9 if on else 0.6), 4.0 if on else 3.0, true)
		var fs := int(clamp(r * 0.42, 16, 30))
		var w := f.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, c + Vector2(-w / 2, fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.r, col.g, col.b, 0.95))
	# العصا
	var jc := _joy_origin if _joy_on else Vector2(170.0 if not Game.settings["lefty"] else size.x - 170.0, size.y - 170.0)
	draw_circle(jc, 92.0, Color(0.05, 0.07, 0.1, 0.25 if not _joy_on else 0.4))
	draw_arc(jc, 92.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(jc + Game.joy * 80.0, 40.0, Color(0.9, 0.92, 1.0, 0.55 if _joy_on else 0.3))
