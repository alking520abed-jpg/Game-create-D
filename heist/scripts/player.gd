class_name Player
extends CharacterBody3D
## اللاعب من منظور الشخص الأول: حركة، نظر، أسلحة حقيقية (رصاص بالمسح، ارتداد، تلقيم)، تفاعل، وحمل الذهب.

signal weapon_changed
signal ammo_changed
signal health_changed

const EYE := 1.62
const EYE_CROUCH := 1.05
const VM_HIP := Vector3(0.115, -0.105, 0.03)
const VM_ADS := Vector3(0.0, -0.035, 0.07)

var head: Node3D
var cam: Camera3D
var yaw := 0.0
var pitch := 0.0
var hp := 100.0
var armor := 0.0
var dead := false
var crouching := false
var carrying := false
var ads := false
var ads_k := 0.0
var inv := {}                 # id -> {mag, reserve}
var cur := "pistol"
var interact_target: Interactable
var interact_progress := 0.0
var _interacting := false

var _cd := 0.0
var _reload_t := 0.0
var _reload_total := 0.0
var _switch_t := 0.0
var _kick := 0.0
var _kick_side := 0.0
var _hurt_t := 99.0
var _step := 0.0
var _bob := 0.0
var _eye := EYE
var _spread_add := 0.0
var _fire_latch := false
var _mouse_captured := false
var _land_v := 0.0

# مجسم اليدين (جسم اللاعب نفسه تحت الكاميرا)
var vm_root: Node3D
var vm: Node3D
var vm_anim: AnimationPlayer
var vm_skel: Skeleton3D
var vm_gun: Node3D
var vm_att: Node3D
var vm_muzzle: Node3D
var _vm_cur := ""


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 16 | 32
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.78
	cs.shape = cap
	cs.position.y = 0.89
	add_child(cs)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.04
	cam.far = 220.0
	head.add_child(cam)
	cam.current = true
	_build_vm()
	give("pistol", true)


func _build_vm() -> void:
	Actor.libs()
	vm_root = Node3D.new()
	cam.add_child(vm_root)
	vm = load("res://chars/crew_suhail.gltf").instantiate()
	vm.rotation.y = PI
	var eh: float = Actor._meta.get("crew_suhail", {}).get("eye", 1.63)
	vm.position = Vector3(0, -eh, 0.02)
	vm_root.add_child(vm)
	vm_skel = vm.find_child("GeneralSkeleton", true, false)
	for mi in vm_skel.get_children():
		if mi is MeshInstance3D:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.extra_cull_margin = 4.0
			# الرأس وملحقاته لا تُرسم في منظور الشخص الأول
			if mi.name.begins_with("mask") or mi.name in ["short02", "low-poly", "eyebrow001", "eyelashes01"]:
				mi.visible = false
	vm_anim = AnimationPlayer.new()
	vm.add_child(vm_anim)
	vm_anim.add_animation_library("a", Actor._libs[0])
	vm_anim.add_animation_library("b", Actor._libs[1])
	_vm_play("Pistol_Aim_Neutral")
	var hb := vm_skel.find_bone("Head")
	if hb >= 0:
		vm_skel.set_bone_pose_scale(hb, Vector3(0.001, 0.001, 0.001))


func _vm_play(n: String, speed := 1.0, blend := 0.12, restart := false) -> void:
	if _vm_cur == n and not restart and vm_anim.is_playing():
		return
	_vm_cur = n
	if restart:
		vm_anim.stop()
	vm_anim.play("a/" + n, blend, speed)


func _equip_vm() -> void:
	if vm_att:
		vm_att.queue_free()
	var r := Actor.attach_gun(vm_skel, cur)
	vm_att = r[0]
	vm_gun = r[1]
	vm_muzzle = r[2]
	for c in vm_gun.find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.extra_cull_margin = 4.0


# ---------------------------------------------------------------- المخزون
func give(id: String, equip_now := false) -> void:
	var d: Dictionary = Weapons.DEFS[id]
	if inv.has(id):
		inv[id]["reserve"] = min(inv[id]["reserve"] + d["mag"] * 2, d["reserve"] * 2)
	else:
		inv[id] = {"mag": d["mag"], "reserve": d["reserve"]}
	if equip_now or inv.size() == 1:
		equip(id)
	ammo_changed.emit()


func equip(id: String) -> void:
	if not inv.has(id) or (id == cur and vm_gun):
		return
	cur = id
	_reload_t = 0.0
	_switch_t = 0.35
	_equip_vm()
	Audio.play("switch", -6.0)
	weapon_changed.emit()
	ammo_changed.emit()


func next_weapon() -> void:
	var have := []
	for w in Weapons.ORDER:
		if inv.has(w):
			have.append(w)
	if have.size() < 2:
		return
	equip(have[(have.find(cur) + 1) % have.size()])


func take_pickup(kind: String) -> bool:
	if kind.begins_with("weapon:"):
		var id := kind.substr(7)
		var had := inv.has(id)
		give(id, not had)
		Game.notify(("سلاح جديد: " if not had else "ذخيرة: ") + Weapons.DEFS[id]["name"], Color(0.5, 0.85, 1.0))
		Audio.play("pickup")
		return true
	match kind:
		"ammo":
			var d: Dictionary = Weapons.DEFS[cur]
			if inv[cur]["reserve"] >= d["reserve"] * 2:
				return false
			for w in inv:
				inv[w]["reserve"] = min(inv[w]["reserve"] + Weapons.DEFS[w]["mag"], Weapons.DEFS[w]["reserve"] * 2)
			Game.notify("+ ذخيرة", Color(1.0, 0.85, 0.4))
		"med":
			if hp >= 100.0:
				return false
			hp = min(100.0, hp + 50.0)
			Game.notify("+ إسعافات", Color(0.5, 1.0, 0.6))
			health_changed.emit()
		"armor":
			if armor >= 100.0:
				return false
			armor = min(100.0, armor + 60.0)
			Game.notify("+ سترة واقية", Color(0.6, 0.75, 1.0))
			health_changed.emit()
	Audio.play("pickup")
	ammo_changed.emit()
	return true


# ---------------------------------------------------------------- معلومات
func eye_pos() -> Vector3:
	return head.global_position


func chest() -> Vector3:
	return global_position + Vector3(0, _eye * 0.75, 0)


func speed_now() -> float:
	return Vector2(velocity.x, velocity.z).length()


func set_look(y: float, p := 0.0) -> void:
	yaw = y
	pitch = p
	rotation.y = yaw
	head.rotation.x = pitch


func capture_mouse(on: bool) -> void:
	if Game.is_mobile or Game.test_mode:
		return
	_mouse_captured = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_captured and Game.state == Game.State.PLAYING:
		Game.look_delta += event.relative * 0.55


# ---------------------------------------------------------------- الحلقة الرئيسية
func _physics_process(delta: float) -> void:
	if Game.state != Game.State.PLAYING or dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= 14.0 * delta
			move_and_slide()
		_fire_latch = Game.is_held("fire")
		Game.look_delta = Vector2.ZERO
		return
	_look(delta)
	_move(delta)
	_weapons(delta)
	_interact(delta)
	_regen(delta)
	_view(delta)


func _look(delta: float) -> void:
	var sens: float = 0.0042 * Game.settings["sens"] * lerp(1.0, 0.55, ads_k)
	var ld := Game.look_delta
	Game.look_delta = Vector2.ZERO
	yaw -= ld.x * sens
	pitch = clamp(pitch - ld.y * sens, -1.45, 1.45)
	# ارتداد السلاح يرفع النظر ثم يهدأ
	_kick = move_toward(_kick, 0.0, delta * (6.0 + _kick * 30.0) * 0.02)
	rotation.y = yaw + _kick_side
	head.rotation.x = pitch + _kick
	_kick_side = move_toward(_kick_side, 0.0, delta * 0.2)


func _move(delta: float) -> void:
	var inp := Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), Input.get_action_strength("back") - Input.get_action_strength("fwd"))
	inp += Game.joy
	if inp.length() > 1.0:
		inp = inp.normalized()
	if Game.consume("crouch"):
		crouching = not crouching
	var sprint := (Game.is_held("sprint") or Game.joy.length() > 0.92) and inp.y < -0.5 and not ads and not crouching and not carrying
	var speed := 4.4
	if sprint:
		speed = 6.6
	if crouching:
		speed = 2.3
	if ads:
		speed = min(speed, 2.6)
	if carrying:
		speed = min(speed, 3.0)
	var dir := (global_transform.basis * Vector3(inp.x, 0, inp.y))
	dir.y = 0.0
	var acc := 40.0 if is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, dir.x * speed, acc * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, acc * delta)
	if is_on_floor():
		if _land_v < -6.0:
			Audio.play("step1", -2.0, 0.7)
		_land_v = 0.0
		if Game.consume("jump") and not carrying:
			velocity.y = 4.6
			crouching = false
	else:
		velocity.y -= 14.0 * delta
		_land_v = velocity.y
	move_and_slide()
	if global_position.y < -30.0:
		global_position = Vector3(0, 0.2, 8)
	# الخطوات
	var hs := speed_now()
	if is_on_floor() and hs > 1.0:
		_step += hs * delta
		_bob += hs * delta * 1.9
		if _step > (2.3 if not sprint else 2.7):
			_step = 0.0
			Audio.play("step%d" % (1 + randi() % 4), -13.0 if crouching else -8.0)
	_eye = move_toward(_eye, EYE_CROUCH if crouching else EYE, delta * 3.5)
	head.position.y = _eye + (sin(_bob * 2.0) * 0.022 * clamp(hs / 4.4, 0.0, 1.3) if is_on_floor() else 0.0)


func _weapons(delta: float) -> void:
	_cd -= delta
	_switch_t -= delta
	_spread_add = move_toward(_spread_add, 0.0, delta * 5.0)
	var d: Dictionary = Weapons.DEFS[cur]
	var st: Dictionary = inv[cur]
	if Game.consume("aim"):
		ads = not ads
	if Input.is_action_just_released("aim") and not Game.is_mobile:
		pass
	if Game.consume("next_weapon"):
		next_weapon()
	for i in 4:
		if Input.is_action_just_pressed("w%d" % (i + 1)) and inv.has(Weapons.ORDER[i]):
			equip(Weapons.ORDER[i])
	if _reload_t > 0.0:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var need: int = d["mag"] - st["mag"]
			var take: int = min(need, st["reserve"])
			st["mag"] += take
			st["reserve"] -= take
			ammo_changed.emit()
			_vm_play("Pistol_Aim_Neutral")
		return
	if Game.consume("reload") and st["mag"] < d["mag"] and st["reserve"] > 0:
		start_reload()
		return
	var firing := Game.is_held("fire")
	var want: bool = firing and (d["auto"] or not _fire_latch)
	_fire_latch = firing
	if want and _cd <= 0.0 and _switch_t <= 0.0 and not _interacting:
		if st["mag"] <= 0:
			if st["reserve"] > 0:
				start_reload()
			else:
				Audio.play("empty", -4.0)
				_cd = 0.3
				Game.notify("لا توجد ذخيرة! بدّل السلاح", Color(1, 0.5, 0.4))
			return
		fire()


func start_reload() -> void:
	var d: Dictionary = Weapons.DEFS[cur]
	_reload_total = d["reload"]
	_reload_t = _reload_total
	ads = false
	Audio.play("reload", -3.0, 1.3 / d["reload"] * 1.0 if false else 1.0)
	_vm_play("Pistol_Reload", 1.7 / d["reload"], 0.1, true)


func fire() -> void:
	var d: Dictionary = Weapons.DEFS[cur]
	inv[cur]["mag"] -= 1
	_cd = d["rate"]
	ammo_changed.emit()
	Audio.play(d["sound"], -1.0)
	if cur == "shotgun":
		get_tree().create_timer(0.3).timeout.connect(func(): Audio.play("pump", -5.0))
	FX.flash(vm_muzzle, 2.2)
	if Game.world:
		Game.world.noise(global_position, 28.0)
	Game.stats["shots"] += 1
	var spread: float = lerp(float(d["spread"]), float(d["ads_spread"]), ads_k) + _spread_add + clamp(speed_now() * 0.25, 0.0, 1.6) * (1.0 - ads_k * 0.5)
	if crouching:
		spread *= 0.75
	_spread_add = min(_spread_add + d["recoil"] * 0.35, 3.0)
	var origin := cam.global_position
	var aim := -cam.global_transform.basis.z
	# مساعدة التصويب: الرصاصة تميل قليلاً نحو أقرب عدو من مركز الشاشة
	if Game.settings["aim_assist"] and Game.world:
		var best := deg_to_rad(2.2 if not ads else 3.2) * (1.6 if Game.is_mobile else 1.0)
		for e in Game.world.enemies:
			if e.dead:
				continue
			var to: Vector3 = e.chest() - origin
			var ang := aim.angle_to(to)
			if ang < best and to.length() < d["range"] and _clear(origin, e.chest()):
				best = ang
				aim = aim.slerp(to.normalized(), 0.75)
	var any_hit := false
	var kill := false
	var headshot := false
	var space := get_world_3d().direct_space_state
	for i in d["pellets"]:
		var sp := deg_to_rad(spread)
		var dir := aim.rotated(cam.global_transform.basis.x, randfn(0.0, sp * 0.5)).rotated(cam.global_transform.basis.y, randfn(0.0, sp * 0.5))
		var to: Vector3 = origin + dir * float(d["range"])
		var q := PhysicsRayQueryParameters3D.create(origin, to, 1 | 4 | 8 | 32)
		var r := space.intersect_ray(q)
		var end: Vector3 = to
		if not r.is_empty():
			end = r["position"]
			var col = r["collider"]
			if col is Actor:
				var a: Actor = col
				var is_head: bool = end.y > a.global_position.y + a.eye_h - 0.2
				var dmg: float = d["dmg"] * (d["head"] if is_head else 1.0)
				dmg *= clamp(1.25 - origin.distance_to(end) / d["range"], 0.45, 1.0)
				var was_dead := a.dead
				a.hurt(dmg, global_position, is_head, true)
				FX.impact(get_parent(), end, r["normal"], true)
				if a.team == Actor.Team.ENEMY:
					any_hit = true
					headshot = headshot or is_head
					if a.dead and not was_dead:
						kill = true
			else:
				FX.impact(get_parent(), end, r["normal"])
				if i == 0:
					Audio.play_at("impact" if randf() < 0.8 else "ricochet", end, -6.0)
		if i < 3:
			FX.tracer(get_parent(), vm_muzzle.global_position, end)
	if any_hit:
		Game.stats["hits"] += 1
		Game.hit_marker.emit(kill, headshot)
		Audio.play("kill" if kill else "hit", -8.0)
	# الارتداد
	_kick += deg_to_rad(d["recoil"]) * (0.6 if ads else 1.0)
	_kick_side += deg_to_rad(randf_range(-0.35, 0.35) * d["recoil"])
	if not d["auto"]:
		_vm_play("Pistol_Shoot", 1.8, 0.03, true)


func _clear(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | 32)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _interact(delta: float) -> void:
	# أقرب شيء قابل للتفاعل أمام اللاعب
	var best: Interactable = null
	var bd := 1e9
	for n in get_tree().get_nodes_in_group("interact"):
		var it: Interactable = n
		if not it.enabled:
			continue
		var to: Vector3 = it.global_position - eye_pos()
		var d := to.length()
		if d < it.radius and d < bd and (-cam.global_transform.basis.z).dot(to.normalized()) > 0.35:
			bd = d
			best = it
	if best != interact_target:
		interact_target = best
		_interacting = false
		interact_progress = 0.0
	if interact_target == null:
		return
	if Game.consume("interact"):
		_interacting = true
	if _interacting:
		if interact_target.hold_time <= 0.0:
			interact_progress = 1.0
		else:
			interact_progress += delta / interact_target.hold_time
		if interact_progress >= 1.0:
			var it2 := interact_target
			interact_target = null
			_interacting = false
			interact_progress = 0.0
			Audio.play("click")
			it2.complete()


func _regen(delta: float) -> void:
	_hurt_t += delta
	if _hurt_t > 5.0 and hp < 45.0:
		hp = min(45.0, hp + delta * 6.0)
		health_changed.emit()


func _view(delta: float) -> void:
	ads_k = move_toward(ads_k, 1.0 if ads else 0.0, delta * 7.0)
	cam.fov = lerp(70.0, 50.0, ads_k)
	var hs := speed_now()
	var sway: Vector3 = Vector3(sin(_bob) * 0.006, abs(cos(_bob)) * 0.005, 0.0) * clamp(hs / 4.0, 0.0, 1.4) * (1.0 - ads_k * 0.8)
	var base: Vector3 = VM_HIP.lerp(VM_ADS, ads_k)
	var dip := 0.0
	if _switch_t > 0.0:
		dip = _switch_t / 0.35 * 0.25
	if carrying:
		dip = 0.5
	var kick_z: float = clamp(_cd / max(0.05, Weapons.DEFS[cur]["rate"]), 0.0, 1.0) * 0.035 * (0.5 if Weapons.DEFS[cur]["auto"] else 1.0)
	vm_root.position = vm_root.position.lerp(base + sway + Vector3(0, -dip, kick_z), min(1.0, delta * 18.0))
	vm_root.rotation.x = lerp(vm_root.rotation.x, _kick * 0.6 - dip * 0.8, min(1.0, delta * 18.0))


# ---------------------------------------------------------------- الإصابة
func hurt(dmg: float, from: Vector3, _head := false, _by_player := false) -> void:
	if dead or Game.state != Game.State.PLAYING:
		return
	if armor > 0.0:
		var ab: float = min(armor, dmg * 0.6)
		armor -= ab
		dmg -= ab
	hp -= dmg
	_hurt_t = 0.0
	_kick += deg_to_rad(randf_range(0.4, 1.0))
	Audio.play("hurt", -6.0)
	Game.player_hurt.emit(from)
	health_changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		ads = false
		Game.set_state(Game.State.DEAD)
		capture_mouse(false)
		var tw := create_tween()
		tw.tween_property(head, "position:y", 0.35, 0.7)
		tw.parallel().tween_property(head, "rotation:z", 0.9, 0.7)
