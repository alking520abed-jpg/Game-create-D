extends Node
## الحالة العامة للعبة: النقود، الحفظ، الإعدادات، الأزرار.

signal money_changed
signal toast(text: String, color: Color)
signal banner(title: String, sub: String, color: Color)
signal state_changed
signal settings_changed

enum State { MENU, PLAYING, PAUSED, CUTSCENE }

const SAVE_PATH := "user://save.cfg"

var state: int = State.MENU
var money := 0
var stars := {}
var done := {}
var best := {}
var owned := {}
var settings := {"quality": 1, "sound": true, "music": true}
var help_seen := false

# --- البطل الخارق ---
const MAX_HP := 100.0
const MAX_ENERGY := 100.0
var hp := MAX_HP
var energy := MAX_ENERGY
var unlocked := 0        # عدد الهيئات المفتوحة (0..5)
var chapter := 0         # الفصل الحالي من القصة
var choice := ""         # اختيار اللاعب في القصة: "mercy" أو "justice"
var kills := 0
var combat = null
var story = null

var main: Node = null
var player = null
var car = null          # السيارة التي يقودها اللاعب (أو null)
var city = null
var missions = null
var cam = null
var cars: Array = []
var night := 0.0        # 0 نهار .. 1 ليل
var joy := Vector2.ZERO # عصا اللمس
var font_bold: FontVariation
var font: Font
var near_car = null     # أقرب سيارة يمكن ركوبها
var _taps := {}
const ONE_SHOT := ["jump", "interact", "mission", "horn", "cam", "pause", "special", "morph", "form1", "form2", "form3", "form4", "form5", "revert", "skip"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = load("res://fonts/Cairo.ttf")
	font_bold = FontVariation.new()
	font_bold.base_font = font
	font_bold.variation_opentype = {"wght": 800}
	_setup_input()
	load_game()


func _setup_input() -> void:
	var map := {
		"gas": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"handbrake": [KEY_SPACE],
		"run": [KEY_SHIFT],
		"interact": [KEY_E],
		"mission": [KEY_F, KEY_ENTER],
		"horn": [KEY_H],
		"cam": [KEY_C],
		"pause": [KEY_ESCAPE, KEY_P],
		"attack": [KEY_J],
		"special": [KEY_K],
		"morph": [KEY_TAB],
		"form1": [KEY_1], "form2": [KEY_2], "form3": [KEY_3], "form4": [KEY_4], "form5": [KEY_5],
		"revert": [KEY_R, KEY_0],
		"fly_up": [KEY_SPACE],
		"fly_down": [KEY_Q, KEY_CTRL],
		"skip": [KEY_ENTER, KEY_SPACE],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		for a in ONE_SHOT:
			if event.is_action_pressed(a):
				tap(a)


func _process(delta: float) -> void:
	for a in _taps.keys():
		_taps[a] -= delta
		if _taps[a] <= 0.0:
			_taps.erase(a)


## ضغطة واحدة (من اللمس أو الكيبورد)
func tap(a: String) -> void:
	_taps[a] = 0.2


func consume(a: String) -> bool:
	if _taps.has(a):
		_taps.erase(a)
		return true
	return false


func pos() -> Vector3:
	## موقع اللاعب الحالي (على قدميه أو في السيارة)
	if car != null:
		return car.global_position
	if player != null:
		return player.global_position
	return Vector3.ZERO


func add_money(n: int) -> void:
	money = max(0, money + n)
	money_changed.emit()
	save_game()


func notify(text: String, color := Color.WHITE) -> void:
	toast.emit(text, color)


func set_state(s: int) -> void:
	state = s
	get_tree().paused = (s == State.PAUSED)
	state_changed.emit()


func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("g", "money", money)
	cf.set_value("g", "stars", stars)
	cf.set_value("g", "done", done)
	cf.set_value("g", "best", best)
	cf.set_value("g", "owned", owned)
	cf.set_value("g", "settings", settings)
	cf.set_value("g", "help_seen", help_seen)
	cf.set_value("g", "unlocked", unlocked)
	cf.set_value("g", "chapter", chapter)
	cf.set_value("g", "choice", choice)
	cf.set_value("g", "kills", kills)
	cf.save(SAVE_PATH)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		if OS.has_feature("mobile"):
			settings["quality"] = 1
		return
	money = cf.get_value("g", "money", 0)
	stars = cf.get_value("g", "stars", {})
	done = cf.get_value("g", "done", {})
	best = cf.get_value("g", "best", {})
	owned = cf.get_value("g", "owned", {})
	var s = cf.get_value("g", "settings", {})
	for k in s:
		settings[k] = s[k]
	help_seen = cf.get_value("g", "help_seen", false)
	unlocked = cf.get_value("g", "unlocked", 0)
	chapter = cf.get_value("g", "chapter", 0)
	choice = cf.get_value("g", "choice", "")
	kills = cf.get_value("g", "kills", 0)


func reset_save() -> void:
	money = 0
	stars = {}
	done = {}
	best = {}
	owned = {}
	unlocked = 0
	chapter = 0
	choice = ""
	kills = 0
	hp = MAX_HP
	energy = MAX_ENERGY
	save_game()
	money_changed.emit()
