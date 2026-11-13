class_name Interactable
extends Node3D
## شيء يتفاعل معه اللاعب (مع زمن ضغط اختياري) ويظهر فوقه مؤشّر.

signal done

var prompt := "تفاعل"
var hold_time := 0.0
var enabled := true
var radius := 2.6
var once := true
var _icon: Sprite3D
var _t := 0.0


func _init(p_prompt := "تفاعل", p_hold := 0.0) -> void:
	prompt = p_prompt
	hold_time = p_hold
	add_to_group("interact")


func _ready() -> void:
	_icon = Sprite3D.new()
	_icon.texture = FX._radial()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.modulate = Color(1.0, 0.8, 0.25, 0.9)
	_icon.pixel_size = 0.0045
	_icon.no_depth_test = true
	_icon.fixed_size = false
	_icon.position.y = 0.25
	add_child(_icon)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.3)
	l.light_energy = 0.7
	l.omni_range = 3.0
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	_icon.visible = enabled
	_icon.position.y = 0.25 + sin(_t * 3.0) * 0.06
	var s := 1.0 + sin(_t * 5.0) * 0.12
	_icon.scale = Vector3(s, s, s)


func complete() -> void:
	if once:
		enabled = false
	done.emit()
	if once:
		queue_free()
