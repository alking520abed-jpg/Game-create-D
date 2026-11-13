extends Node
## الحالة العامة: التقدم، الإعدادات، الأزرار، الإشارات المشتركة.

signal state_changed
signal settings_changed
signal subtitle(speaker: String, text: String, time: float)
signal objective_changed(text: String)
signal toast(text: String, color: Color)
signal hit_marker(kill: bool, head: bool)
signal player_hurt(from: Vector3)

enum State { MENU, BRIEFING, PLAYING, PAUSED, CUTSCENE, DEAD, WIN }

const SAVE_PATH := "user://heist.cfg"
const CHAPTERS := ["الدخول", "غرفة التحكم", "الخزنة", "الذهب", "الحصار", "الهروب"]

var state: int = State.MENU
var chapter := 0            # الفصل الحالي
var unlocked := 0           # أعلى فصل مفتوح
var best := {}              # أفضل نتيجة لكل فصل
var settings := {"quality": 1, "sound": true, "music": true, "sens": 1.0, "difficulty": 1, "aim_assist": true, "lefty": false}
var stats := {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "time": 0.0, "gold": 0}

var main: Node = null
var player = null
var world = null
var story = null
var hud = null
var font: Font
var font_bold: FontVariation
var joy := Vector2.ZERO       # عصا الحركة (لمس)
var look_delta := Vector2.ZERO # سحب الكاميرا (لمس)
var held := {}                # أزرار اللمس المضغوطة
var _taps := {}
var is_mobile := false
var test_mode := false
var pending_start := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_mobile = OS.has_feature("mobile")
	font = load("res://fonts/Cairo.ttf")
	font_bold = FontVariation.new()
	font_bold.base_font = font
	font_bold.variation_opentype = {"wght": 800}
	_setup_input()
	load_game()


func _setup_input() -> void:
	var map := {
		"fwd": [KEY_W, KEY_UP], "back": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "crouch": [KEY_CTRL, KEY_C], "sprint": [KEY_SHIFT], "reload": [KEY_R], "interact": [KEY_E, KEY_F],
		"next_weapon": [KEY_Q], "pause": [KEY_ESCAPE, KEY_P], "w1": [KEY_1], "w2": [KEY_2], "w3": [KEY_3], "w4": [KEY_4],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in ["fire", "aim"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT if a == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(a, mb)


func _process(delta: float) -> void:
	for a in _taps.keys():
		_taps[a] -= delta
		if _taps[a] <= 0.0:
			_taps.erase(a)
	if state == State.PLAYING:
		stats["time"] += delta


## ضغطة واحدة من اللمس
func tap(a: String) -> void:
	_taps[a] = 0.25


func consume(a: String) -> bool:
	if _taps.has(a):
		_taps.erase(a)
		return true
	return InputMap.has_action(a) and Input.is_action_just_pressed(a)


func is_held(a: String) -> bool:
	return held.get(a, false) or (InputMap.has_action(a) and Input.is_action_pressed(a))


func set_state(s: int) -> void:
	state = s
	get_tree().paused = (s == State.PAUSED)
	state_changed.emit()


func say(speaker: String, text: String, time := 0.0) -> void:
	if time <= 0.0:
		time = clamp(1.6 + text.length() * 0.055, 2.2, 7.0)
	subtitle.emit(speaker, text, time)


func notify(text: String, color := Color.WHITE) -> void:
	toast.emit(text, color)


func difficulty_mul() -> float:
	return [0.6, 1.0, 1.5][settings["difficulty"]]


func reset_stats() -> void:
	stats = {"shots": 0, "hits": 0, "kills": 0, "heads": 0, "time": 0.0, "gold": 0}


func complete_chapter(i: int) -> void:
	unlocked = max(unlocked, min(i + 1, CHAPTERS.size() - 1))
	var acc: float = 0.0 if stats["shots"] == 0 else float(stats["hits"]) / stats["shots"]
	var score := int(stats["kills"] * 100 + stats["heads"] * 50 + acc * 1000 + stats["gold"] * 250 + max(0.0, 600.0 - stats["time"]) * 2)
	if score > best.get(i, 0):
		best[i] = score
	save_game()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "unlocked", unlocked)
	cf.set_value("g", "best", best)
	cf.set_value("g", "settings", settings)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	unlocked = cf.get_value("g", "unlocked", 0)
	best = cf.get_value("g", "best", {})
	var s = cf.get_value("g", "settings", {})
	for k in s:
		if settings.has(k):
			settings[k] = s[k]
