class_name Enemy
extends CharacterBody3D
## عدو بذكاء بسيط: يطارد البطل، يضرب عن قرب أو يطلق النار، ويموت بأنيميشن.

signal died(e)

const KINDS := {
	"thug": {"name": "بلطجي", "model": "thug", "hp": 40.0, "speed": 4.4, "melee": 7.0, "range": 1.9, "cd": 1.1, "r": 0.4, "reward": 15},
	"soldier": {"name": "جندي أفق", "model": "soldier", "hp": 55.0, "speed": 3.9, "shoot": 7.0, "keep": 14.0, "cd": 1.5, "r": 0.4, "reward": 25},
	"mutant": {"name": "متحوّل", "model": "mutant", "hp": 95.0, "speed": 6.3, "melee": 11.0, "range": 2.0, "cd": 0.9, "r": 0.45, "reward": 35},
	"bat": {"name": "خفاش التجارب", "model": "bat", "hp": 32.0, "speed": 10.0, "melee": 6.0, "range": 2.4, "cd": 1.2, "r": 0.7, "reward": 20, "fly": true},
	"mech": {"name": "آلي الحراسة", "model": "george", "hp": 650.0, "speed": 3.5, "melee": 20.0, "range": 4.8, "cd": 1.9, "rocket": 14.0, "r": 1.5, "reward": 300, "boss": true},
	"boss": {"name": "راكان — الدرع الأعظم", "model": "mike", "hp": 1500.0, "speed": 3.2, "melee": 26.0, "range": 5.8, "cd": 2.0, "rocket": 16.0, "r": 1.9, "reward": 1000, "boss": true},
}

var kind := "thug"
var k := {}
var rig: CharacterRig
var hp := 40.0
var max_hp := 40.0
var hit_r := 0.4
var dead := false
var alert := true
var stun := 0.0
var sight := 28.0
var passive := false        # لا يهاجم (للمشاهد)
var _cd := 1.0
var _rocket_cd := 3.0
var _kv := Vector3.ZERO
var _dead_t := 0.0
var _bar: MeshInstance3D
var _bar_bg: MeshInstance3D
var _strafe := 1.0
var _strafe_t := 0.0
var _rng := RandomNumberGenerator.new()
var _seen := 0.0


func setup(p_kind: String) -> void:
	kind = p_kind
	k = KINDS[kind]
	_rng.randomize()
	hp = k["hp"]
	max_hp = hp
	hit_r = k["r"]
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 0.3
	if k.get("fly", false):
		motion_mode = MOTION_MODE_FLOATING
	rig = CharacterRig.new()
	add_child(rig)
	rig.set_model(k["model"])
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = min(hit_r, 0.9)
	cap.height = max(rig.height * 0.9, cap.radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	# شريط الصحة
	_bar_bg = _quad(Color(0, 0, 0, 0.6), 1.3, 0.16)
	_bar = _quad(Color(0.95, 0.2, 0.15, 1.0), 1.26, 0.11)
	_bar.position.z = 0.0
	_bar_bg.visible = false
	_bar.visible = false
	_cd = _rng.randf_range(0.6, 1.6)
	_strafe = 1.0 if _rng.randf() < 0.5 else -1.0


func _quad(col: Color, w: float, h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	mi.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.no_depth_test = true
	m.render_priority = 1 if col.r > 0.5 else 0
	mi.material_override = m
	mi.position.y = rig.height + 0.45
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func center() -> Vector3:
	return global_position + Vector3(0, rig.height * 0.55, 0)


func is_boss() -> bool:
	return k.get("boss", false)


func take_damage(dmg: float, knock := Vector3.ZERO, p_stun := 0.0) -> void:
	if dead:
		return
	hp -= dmg
	alert = true
	_seen = 8.0
	rig.flash()
	if Game.combat:
		Game.combat.fx_text(center() + Vector3(0, rig.height * 0.4, 0), str(int(round(dmg))), Color(1, 0.9, 0.3))
	if is_boss():
		knock *= 0.12
		p_stun *= 0.25
	_kv += knock
	stun = max(stun, p_stun)
	if not is_boss() and rig.busy <= 0.1:
		rig.action("hit", 1.6)
	if not is_boss():
		_bar.visible = true
		_bar_bg.visible = true
		_bar.scale.x = clamp(hp / max_hp, 0.02, 1.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	_dead_t = 2.6
	collision_layer = 0
	collision_mask = 1
	_bar.visible = false
	_bar_bg.visible = false
	rig.tint(null)
	rig.die()
	Game.kills += 1
	Game.energy = min(Game.MAX_ENERGY, Game.energy + (25.0 if is_boss() else 7.0))
	if k["reward"] > 0:
		Game.add_money(k["reward"])
	Sfx.play("down", -6.0, 0.6 if is_boss() else 1.0)
	if is_boss() and Game.combat:
		Game.combat.explode(center(), 7.0, 0.0, 0)
	died.emit(self)


func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		if Game.state == Game.State.CUTSCENE:
			rig.animate(0.0, delta)
		return
	if dead:
		_dead_t -= delta
		velocity = Vector3(0, velocity.y - 19.0 * delta, 0)
		if k.get("fly", false) or not is_on_floor():
			move_and_slide()
		rig.animate(0.0, delta)
		if _dead_t <= 0.0:
			if Game.combat:
				Game.combat.enemies.erase(self)
				Game.combat.fx_burst(center(), Color(0.6, 0.6, 0.65), 1.2, 0.4, false)
			queue_free()
		return
	var pl: Player = Game.player
	var tp: Vector3 = Game.pos()
	var to := tp - global_position
	var dist := Vector2(to.x, to.z).length()
	if dist > 150.0:
		return
	_cd -= delta
	_rocket_cd -= delta
	var fly: bool = k.get("fly", false)
	var move := Vector3.ZERO
	var visible_target: bool = pl != null and not pl.dead and pl.invisible <= 0.0
	if visible_target and (alert or dist < sight):
		alert = true
		_seen = 6.0
	else:
		_seen -= delta
	var aware := alert and _seen > 0.0 and not passive
	if stun > 0.0:
		stun -= delta
		rig.tint(Color(1.0, 0.95, 0.4, 0.35) if stun > 0.0 else null)
	elif aware:
		var d := Vector3(to.x, 0, to.z).normalized()
		var face := atan2(-d.x, -d.z)
		rig.rotation.y = lerp_angle(rig.rotation.y, face, min(1.0, delta * 9.0))
		var sp: float = k["speed"]
		if k.has("shoot"):
			var keep: float = k["keep"]
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe_t = _rng.randf_range(1.2, 3.0)
				_strafe = -_strafe
			if dist > keep + 5.0:
				move = d * sp
			elif dist < keep - 6.0:
				move = -d * sp * 0.8
			else:
				move = City.right_of(d) * _strafe * sp * 0.45
			if _cd <= 0.0 and dist < 38.0 and visible_target:
				_cd = k["cd"] * _rng.randf_range(0.85, 1.3)
				rig.action("shoot", 1.3)
				var from := global_position + Vector3(0, rig.height * 0.72, 0) + d * 0.6
				var aim := (tp + Vector3(0, pl.height() * 0.55 if Game.car == null else 0.9, 0) - from).normalized()
				aim = (aim + Vector3(_rng.randf_range(-0.045, 0.045), _rng.randf_range(-0.02, 0.03), _rng.randf_range(-0.045, 0.045))).normalized()
				Game.combat.projectile(from, aim, 34.0, k["shoot"], 1, Color(1.0, 0.85, 0.3), 0.0, 0.14)
				Sfx.play("shot", -10.0, _rng.randf_range(0.9, 1.1))
		else:
			var rng: float = k["range"]
			var reach: float = rng * 0.75 + (pl.f()["radius"] if pl else 0.3)
			var dy: float = abs(to.y) if not fly else 0.0
			if dist > reach:
				if rig.busy <= 0.0 or is_boss():
					move = d * sp
			if dist <= reach + 0.5 and dy < rng + 1.5 and _cd <= 0.0 and visible_target:
				_cd = k["cd"] * _rng.randf_range(0.9, 1.2)
				var dur := rig.action("attack", 1.0 if is_boss() else 1.3)
				var dmg: float = k["melee"]
				var me := self
				get_tree().create_timer(max(0.18, dur * 0.4), false).timeout.connect(func():
					if not is_instance_valid(me) or dead or stun > 0.0:
						return
					var t2: Vector3 = Game.pos() - global_position
					if Vector2(t2.x, t2.z).length() <= reach + 1.4 and abs(t2.y) < rng + 2.5:
						Game.player.hurt(dmg, global_position)
						if is_boss():
							Game.combat.fx_ring(global_position, rng + 1.0, Color(1, 0.5, 0.2))
							Game.cam.shake(0.5)
				)
			if k.has("rocket") and _rocket_cd <= 0.0 and dist > 7.0 and dist < 70.0 and visible_target:
				_rocket_cd = _rng.randf_range(2.6, 4.2) * (0.7 if hp < max_hp * 0.4 else 1.0)
				rig.action("shoot", 1.0)
				var from2 := global_position + Vector3(0, rig.height * 0.7, 0) + d * 1.5
				var aim2 := (tp + Vector3(0, 0.6, 0) - from2).normalized()
				Game.combat.projectile(from2, aim2, 24.0, k["rocket"], 1, Color(1.0, 0.3, 0.15), 4.5, 0.35)
				Sfx.play("fire", -4.0, 0.6)
	if fly:
		var want_y: float = (tp.y + 1.6) if aware else 3.0
		velocity.y = clamp((want_y - global_position.y) * 2.5, -8.0, 8.0)
	elif is_on_floor():
		velocity.y = max(_kv.y, 0.0)
	else:
		velocity.y -= 19.0 * delta
	velocity.x = move.x + _kv.x
	velocity.z = move.z + _kv.z
	_kv = _kv.move_toward(Vector3.ZERO, 26.0 * delta)
	_kv.y = 0.0
	move_and_slide()
	if global_position.y < -3.0:
		global_position.y = 1.0
	rig.animate(Vector2(move.x, move.z).length(), delta, true, 99.0 if kind != "mutant" and not is_boss() else 3.0, 1.6 if not is_boss() else 2.6, k["speed"])
