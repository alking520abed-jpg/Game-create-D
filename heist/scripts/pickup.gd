class_name Pickup
extends Node3D
## غنيمة على الأرض: ذخيرة، إسعاف، درع، أو سلاح.

var kind := "ammo"
var _t := 0.0
var _mi: Node3D


func init(k: String, pos: Vector3) -> void:
	kind = k
	position = pos
	var col := Color(0.9, 0.75, 0.2)
	if k.begins_with("weapon:"):
		_mi = load("res://weapons/gun_%s.glb" % k.substr(7)).instantiate()
		_mi.rotation_degrees = Vector3(0, 0, 80)
		add_child(_mi)
		col = Color(0.4, 0.8, 1.0)
	else:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.2, 0.2) if k == "ammo" else Vector3(0.34, 0.24, 0.24)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = {"ammo": Color(0.35, 0.4, 0.2), "med": Color(0.9, 0.9, 0.9), "armor": Color(0.2, 0.3, 0.5)}[k]
		mat.roughness = 0.6
		bm.material = mat
		m.mesh = bm
		add_child(m)
		_mi = m
		if k == "med":
			col = Color(0.3, 1.0, 0.4)
			for sz in [Vector3(0.2, 0.06, 0.26), Vector3(0.06, 0.2, 0.26)]:
				var c := MeshInstance3D.new()
				var cb := BoxMesh.new()
				cb.size = sz
				var cm := StandardMaterial3D.new()
				cm.albedo_color = Color(0.8, 0.1, 0.1)
				cb.material = cm
				c.mesh = cb
				m.add_child(c)
		elif k == "armor":
			col = Color(0.4, 0.6, 1.0)
	_mi.position.y = 0.45
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 0.6
	l.omni_range = 2.5
	l.position.y = 0.5
	add_child(l)


func _process(delta: float) -> void:
	_t += delta
	_mi.rotation.y += delta * 1.6
	_mi.position.y = 0.45 + sin(_t * 2.5) * 0.06
	var p = Game.player
	if p and Game.state == Game.State.PLAYING and p.global_position.distance_to(global_position) < 1.5:
		if p.take_pickup(kind):
			queue_free()
