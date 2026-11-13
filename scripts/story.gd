class_name Story
extends Node3D
## القصة: سبعة فصول بمشاهد سينمائية وحوار عربي، تفتح الهيئات الخمس تباعاً.

const TITLES := ["العاصفة", "جنود أفق", "سباق مع الصاعقة", "سماء المدينة", "الاختيار", "تسلّل", "المواجهة"]
const CHAPTERS := 7
const GOLD := Color(1.0, 0.86, 0.35)
const C_SAIF := Color(0.5, 0.8, 1.0)
const C_LAYLA := Color(1.0, 0.6, 0.8)
const C_BRACELET := Color(0.6, 1.0, 0.85)
const C_ENEMY := Color(1.0, 0.45, 0.4)
const C_DOC := Color(0.8, 0.9, 0.6)

var active := false
var objective := ""
var target = null            # Vector3 أو null
var timer := -1.0
var boss: Enemy = null
var near := false
var cut: Cutscene
var marker: Node3D
var actors: Array = []
var _label: Label3D
var _stage := 0
var _wave := 0
var _devices: Array = []
var _hold := 0.0
var _await_respawn := false
var _ambient_t := 25.0
var _spotted := false
var _busy := false           # مشهد أو انتقال جارٍ
var _rng := RandomNumberGenerator.new()
var S := Vector3.ZERO        # ساحة البداية
var T := Vector3.ZERO        # برج النخيل
var OASIS := Vector3(-410, 0, -400)
var DEPOT := Vector3.ZERO


func _ready() -> void:
	_rng.randomize()
	Game.story = self
	S = City.block_center(5, 5)
	T = City.block_center(4, 4)
	DEPOT = City.block_center(6, 7)
	cut = Cutscene.new()
	add_child(cut)
	marker = Game.missions._make_beacon(Color(0.75, 0.4, 1.0), 2.0, 16.0)
	add_child(marker)
	_label = Label3D.new()
	_label.font = Game.font_bold
	_label.font_size = 80
	_label.pixel_size = 0.016
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 20
	_label.modulate = Color(0.9, 0.75, 1.0)
	_label.position.y = 5.0
	_label.visibility_range_end = 160.0
	marker.add_child(_label)
	_refresh_marker()


func marker_pos(ch: int) -> Vector3:
	match ch:
		0: return S + Vector3(0, 0, 6)
		1: return T + Vector3(-27, 0, 27)
		2: return City.block_center(3, 4) + Vector3(0, 0, 27)
		3: return Vector3(100, 0, 384)
		4: return City.block_center(7, 2) + Vector3(-27, 0, 27)
		5: return DEPOT + Vector3(-44, 0, 0)
		_: return T + Vector3(27, 0, 27)


func _refresh_marker() -> void:
	var show := not active and Game.chapter > 0 and Game.chapter < CHAPTERS
	marker.visible = show
	if show:
		marker.position = marker_pos(Game.chapter)
		_label.text = "الفصل %d: %s" % [Game.chapter + 1, TITLES[Game.chapter]]


func next_title() -> String:
	if Game.chapter >= CHAPTERS:
		return ""
	return "الفصل %d: %s" % [Game.chapter + 1, TITLES[Game.chapter]]


func respawn_point() -> Vector3:
	if active:
		return marker_pos(Game.chapter) + Vector3(0, 0.2, 0)
	return Game.city.start_pos


func on_player_down() -> void:
	if active:
		_await_respawn = true


# ---------------- أدوات ----------------

func _actor(model: String, pos: Vector3, look_at_p: Vector3) -> CharacterRig:
	var a := CharacterRig.new()
	add_child(a)
	a.set_model(model)
	a.position = pos
	var d := look_at_p - pos
	a.rotation.y = atan2(-d.x, -d.z)
	actors.append(a)
	return a


func _clear_actors() -> void:
	for a in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()


func _cam(from: Vector3, look: Vector3, to = null, dur := 6.0, look_to = null) -> Dictionary:
	return {"from": from, "look": look, "to": to, "look_to": look_to, "dur": dur}


func _say(who: String, text: String, col := GOLD, cam = null, fn = null) -> Dictionary:
	var d := {"who": who, "text": text, "col": col}
	if cam != null:
		d["cam"] = cam
	if fn != null:
		d["fn"] = fn
	return d


func _ring(center: Vector3, r: float, i: int, n: int, phase := 0.0) -> Vector3:
	var a: float = TAU * i / max(n, 1) + phase
	return center + Vector3(cos(a) * r, 0.1, sin(a) * r)


func _spawn_group(kinds: Array, center: Vector3, r: float, alert := true, phase := 0.0) -> Array:
	var out := []
	for i in kinds.size():
		var p := _ring(center, r + _rng.randf_range(-1.0, 1.0), i, kinds.size(), phase)
		if kinds[i] == "bat":
			p.y = _rng.randf_range(9.0, 20.0)
		out.append(Game.combat.spawn(kinds[i], p, alert))
	return out


func _place_player(p: Vector3, yaw := 0.0) -> void:
	var pl: Player = Game.player
	if Game.car != null:
		Game.main.force_exit_car()
	pl.global_position = p + Vector3(0, 0.15, 0)
	pl.velocity = Vector3.ZERO
	pl._face = yaw
	pl.rig.rotation.y = yaw
	Game.cam.yaw = yaw
	Game.cam.pitch = 0.28


func _unlock(n: int) -> void:
	if Game.unlocked < n:
		Game.unlocked = n
		var fm: Dictionary = Player.FORMS[n]
		Game.banner.emit("هيئة جديدة: " + fm["name"], "%s — %s / %s" % [fm["desc"], fm["atk_name"], fm["sp_name"]], fm["color"])
		Sfx.play("success")
	Game.save_game()


# ---------------- التشغيل ----------------

func begin_intro() -> void:
	## يُستدعى عند أول لعب
	if Game.chapter == 0 and not active:
		start_chapter()


func start_chapter() -> void:
	if active or Game.chapter >= CHAPTERS:
		return
	if Game.missions.is_active():
		Game.missions.cancel()
	active = true
	_busy = true
	_stage = 0
	_wave = 0
	_spotted = false
	timer = -1.0
	target = null
	boss = null
	objective = ""
	marker.visible = false
	Game.player.revert(true)
	Game.hp = Game.MAX_HP
	Game.energy = Game.MAX_ENERGY
	Game.combat.clear_enemies()
	cut.play(_intro(Game.chapter), _after_intro)


func _after_intro() -> void:
	_clear_actors()
	_busy = false
	Game.banner.emit("الفصل %d" % (Game.chapter + 1), TITLES[Game.chapter], GOLD)
	_begin_stage()


func _process(delta: float) -> void:
	if Game.state != Game.State.PLAYING:
		return
	var pp: Vector3 = Game.pos()
	if not active:
		near = false
		marker.visible = Game.chapter > 0 and Game.chapter < CHAPTERS
		if marker.visible:
			marker.position = marker_pos(Game.chapter)
			_label.text = next_title()
			near = pp.distance_to(marker.position) < 6.5 and not Game.missions.is_active()
			if near and Game.consume("mission"):
				start_chapter()
				return
		if Game.chapter > 0:
			_ambient(delta, pp)
		return
	near = false
	if _busy:
		return
	if _await_respawn:
		if not Game.player.dead:
			_await_respawn = false
			_begin_stage()
		return
	if timer >= 0.0:
		timer -= delta
		if timer <= 0.0:
			timer = -1.0
			Sfx.play("fail")
			Game.banner.emit("انتهى الوقت!", "حاول مرة أخرى", Color(1, 0.4, 0.3))
			_place_player(marker_pos(Game.chapter))
			_begin_stage()
			return
	_update(delta, pp)


# ---------------- المراحل ----------------

func _begin_stage() -> void:
	Game.combat.clear_enemies()
	for d in _devices:
		if is_instance_valid(d):
			Game.combat.props.erase(d)
			d.queue_free()
	_devices.clear()
	boss = null
	timer = -1.0
	_wave = 0
	_hold = 0.0
	_spotted = false
	target = null
	var c: Combat = Game.combat
	match Game.chapter:
		0:
			_unlock(1)
			_spawn_group(["thug", "thug", "thug", "thug"], S + Vector3(0, 0, -12), 6.0)
			for i in 4:
				c.spawn_prop(_ring(S + Vector3(8, 0, -14), 2.2, i, 4) - Vector3(0, 0.1, 0), i == 0)
			objective = "اضغط «تحوّل» واختر جلمود، ثم اهزم البلطجية"
			target = S + Vector3(0, 0, -12)
		1:
			_spawn_group(["soldier", "soldier", "soldier", "thug", "soldier", "thug", "soldier", "soldier"], T, 26.0, true, 0.6)
			for i in 5:
				c.spawn_prop(_ring(T, 23.0, i, 5, 1.1) - Vector3(0, 0.1, 0), i % 2 == 0)
			objective = "اهزم جنود «أفق» حول برج النخيل"
			target = T + Vector3(0, 0, 26)
		2:
			_unlock(2)
			var spots := [City.block_center(3, 6) + Vector3(8, 0, 8), DEPOT + Vector3(0, 0, -6), City.block_center(7, 2) + Vector3(8, 0, 8), City.block_center(2, 2) + Vector3(0, 0, 6)]
			for sp in spots:
				c.spawn_prop(sp, true)
				var dv = c.props[c.props.size() - 1]
				dv.hp = 55.0
				dv.scale = Vector3(1.7, 2.2, 1.7)
				var b: Node3D = Game.missions._make_beacon(Color(1.0, 0.3, 0.2), 1.6, 30.0)
				dv.add_child(b)
				b.scale = Vector3(1.0 / 1.7, 1.0 / 2.2, 1.0 / 1.7)
				_devices.append(dv)
				_spawn_group(["soldier", "soldier"], sp, 7.0, false, _rng.randf() * TAU)
			timer = 190.0
			objective = "تحوّل إلى وميض ودمّر أجهزة الشفط الأربعة قبل انتهاء الوقت"
		3:
			_unlock(3)
			_spawn_group(["bat", "bat", "bat", "bat", "bat"], Vector3(100, 0, 440), 18.0)
			objective = "تحوّل إلى لهيب، طِر فوق البحر وأسقط خفافيش التجارب"
			target = Vector3(100, 12, 440)
		4:
			var c4 := City.block_center(7, 2)
			var m := c.spawn("mech", c4 + Vector3(-10, 0.2, -6))
			boss = m
			_spawn_group(["soldier", "soldier", "soldier", "soldier"], c4, 16.0, true, 0.4)
			for i in 4:
				c.spawn_prop(_ring(c4, 21.0, i, 4, 0.2) - Vector3(0, 0.1, 0), true)
			objective = "حطّم آلي الحراسة وجنوده لتصل إلى د. منصور"
			target = c4
		5:
			_unlock(5)
			var kinds := ["soldier", "soldier", "soldier", "soldier", "soldier", "soldier"]
			var gs := _spawn_group(kinds, DEPOT, 13.0, false, 0.3)
			for g in gs:
				g.sight = 13.0
			objective = "تحوّل إلى طيف، اختفِ، وتسلّل إلى جهاز التحكم دون أن يراك الحرّاس"
			target = DEPOT
		_:
			var b := c.spawn("boss", T + Vector3(27, 0.2, 2))
			boss = b
			for i in 6:
				c.spawn_prop(_ring(T + Vector3(27, 0, 20), 9.0, i, 6) - Vector3(0, 0.1, 0), i % 2 == 0)
			objective = "اهزم راكان في درعه الأعظم!"
			target = null


func _alive_non_boss() -> int:
	var n := 0
	for e in Game.combat.enemies:
		if is_instance_valid(e) and not e.dead and not e.is_boss():
			n += 1
	return n


func _update(delta: float, pp: Vector3) -> void:
	var c: Combat = Game.combat
	match Game.chapter:
		0:
			var left := c.alive()
			objective = "اهزم البلطجية — بقي %d" % left if Game.player.form != 0 else "اضغط «تحوّل» واختر جلمود، ثم اهزم البلطجية"
			var e = c.nearest_enemy(pp, 200.0)
			target = e.global_position if e != null else null
			if left == 0:
				_win()
		1:
			var left := c.alive()
			objective = "اهزم جنود «أفق» — بقي %d" % left
			var e = c.nearest_enemy(pp, 300.0)
			target = e.global_position if e != null else null
			if left == 0:
				_win()
		2:
			var left := 0
			var best := 1e9
			target = null
			for d in _devices:
				if is_instance_valid(d):
					left += 1
					var dd := pp.distance_to(d.global_position)
					if dd < best:
						best = dd
						target = d.global_position
			if left < 4 - _wave:
				_wave = 4 - left
				Game.energy = min(Game.MAX_ENERGY, Game.energy + 35.0)
				timer += 12.0
				if left > 0:
					Game.notify("جهاز مدمَّر! بقي %d  (+طاقة، +12 ث)" % left, Color(0.5, 1.0, 0.6))
			objective = "دمّر أجهزة الشفط — بقي %d" % left
			if left == 0:
				_win()
		3:
			var left := c.alive()
			if left == 0 and _wave == 0:
				_wave = 1
				_spawn_group(["bat", "bat", "bat", "bat", "bat", "bat"], Vector3(60, 0, 455), 24.0)
				Game.notify("سرب ثانٍ قادم من البحر!", Color(1, 0.7, 0.4))
				left = 6
			objective = "أسقط خفافيش التجارب — بقي %d" % (left + (6 if _wave == 0 else 0))
			var e = c.nearest_enemy(pp, 400.0)
			target = e.global_position if e != null else null
			if left == 0 and _wave == 1:
				_win()
		4:
			var left := c.alive()
			objective = "حطّم آلي الحراسة وجنوده — بقي %d" % left
			var e = c.nearest_enemy(pp, 300.0)
			target = e.global_position if e != null else null
			if left == 0:
				_win()
		5:
			if not _spotted:
				for e in c.enemies:
					if is_instance_valid(e) and not e.dead and e.alert:
						_spotted = true
						break
				if _spotted:
					Sfx.play("fail", -4.0)
					Game.banner.emit("انكشفت!", "اهزم الحرّاس والتعزيزات ثم عُد للجهاز", Color(1, 0.4, 0.3))
					_spawn_group(["mutant", "mutant", "mutant"], DEPOT + Vector3(30, 0, 0), 4.0)
					for e in c.enemies:
						if is_instance_valid(e):
							e.alert = true
							e.sight = 28.0
			if _spotted and c.alive() > 0:
				objective = "انكشفت! اهزم الحرّاس — بقي %d" % c.alive()
				_hold = 0.0
				var e = c.nearest_enemy(pp, 300.0)
				target = e.global_position if e != null else DEPOT
			else:
				target = DEPOT
				var dd := Vector2(pp.x - DEPOT.x, pp.z - DEPOT.z).length()
				if dd < 3.5:
					_hold += delta
					objective = "جارٍ اختراق جهاز التحكم… %d%%" % int(clamp(_hold / 2.0, 0.0, 1.0) * 100.0)
					if _hold >= 2.0:
						_win()
				else:
					_hold = 0.0
					objective = "تسلّل إلى جهاز التحكم وسط الساحة" if not _spotted else "قف عند جهاز التحكم لاختراقه"
		_:
			if boss != null and is_instance_valid(boss) and not boss.dead:
				var fr: float = boss.hp / boss.max_hp
				target = boss.global_position
				if _wave == 0 and fr < 0.66:
					_wave = 1
					Game.notify("راكان: «أيها الجنود! اسحقوه!»", C_ENEMY)
					_spawn_group(["soldier", "soldier", "soldier", "mutant"], boss.global_position, 12.0)
				elif _wave == 1 and fr < 0.33:
					_wave = 2
					Game.notify("راكان: «لن تأخذ ما هو لي!»", C_ENEMY)
					_spawn_group(["mutant", "mutant", "soldier", "soldier", "bat", "bat"], boss.global_position, 13.0)
				objective = "اهزم راكان في درعه الأعظم!"
			else:
				if c.alive() == 0:
					_win()
				else:
					objective = "اقضِ على من تبقّى — %d" % c.alive()
					var e = c.nearest_enemy(pp, 300.0)
					target = e.global_position if e != null else null


func _win() -> void:
	_busy = true
	timer = -1.0
	target = null
	objective = "أحسنت!"
	Sfx.play("success")
	var ch := Game.chapter
	# مهلة قصيرة ليكتمل سقوط آخر عدو قبل المشهد
	get_tree().create_timer(1.4, false).timeout.connect(func():
		if not active or Game.chapter != ch:
			return
		Game.player.revert(true)
		Game.combat.clear_enemies()
		cut.play(_outro(ch), func(): _after_outro(ch))
	)


func _after_outro(ch: int) -> void:
	_clear_actors()
	Game.combat.clear_enemies()
	for d in _devices:
		if is_instance_valid(d):
			d.queue_free()
	_devices.clear()
	boss = null
	active = false
	_busy = false
	objective = ""
	var rewards := [200, 400, 500, 600, 800, 800, 3000]
	var r: int = rewards[ch]
	if ch == 4 and Game.choice == "justice":
		r += 600
	Game.chapter = ch + 1
	Game.add_money(r)
	Game.hp = Game.MAX_HP
	Game.energy = Game.MAX_ENERGY
	match ch:
		0:
			Game.banner.emit("اكتمل الفصل الأول", "+%d ريال — اتجه إلى العمود البنفسجي لمتابعة القصة" % r, GOLD)
		1:
			_unlock(2)
		2:
			_unlock(3)
		3:
			_unlock(4)
		4:
			_unlock(5)
		5:
			Game.banner.emit("اكتمل الفصل السادس", "+%d ريال — راكان ينتظرك عند برج النخيل" % r, GOLD)
		_:
			Game.banner.emit("النهاية", "مدينة النخيل بأمان. شكراً للعب! — المدينة مفتوحة لك الآن", GOLD)
	Game.save_game()
	_refresh_marker()
	_ambient_t = 30.0


# ---------------- جرائم الشوارع (لعب حر) ----------------

func _ambient(delta: float, pp: Vector3) -> void:
	_ambient_t -= delta
	if _ambient_t > 0.0:
		return
	_ambient_t = _rng.randf_range(38.0, 60.0)
	var c: Combat = Game.combat
	if c.alive() >= 4 or Game.missions.is_active() or City.surface_at(pp) == 2:
		return
	for tries in 120:
		var p := City.random_sidewalk(_rng)
		var d := p.distance_to(pp)
		if d < 45.0 or d > 95.0:
			continue
		var pool := ["thug", "thug", "thug"]
		if Game.chapter >= 2:
			pool = ["thug", "soldier", "thug", "soldier"]
		if Game.chapter >= 5:
			pool = ["soldier", "mutant", "thug", "soldier", "mutant"]
		var kinds := []
		for i in _rng.randi_range(2, 4):
			kinds.append(pool[_rng.randi() % pool.size()])
		var gs := _spawn_group(kinds, p, 2.5, false)
		for g in gs:
			g.sight = 22.0
		Game.notify("بلاغ: عصابة تثير الفوضى قربك — انظر النقاط الحمراء في الخريطة", Color(1, 0.6, 0.45))
		Sfx.play("alert", -6.0)
		return


# ---------------- المشاهد ----------------

func _intro(ch: int) -> Array:
	var st := []
	match ch:
		0:
			var o := OASIS
			st = [
				_say("", "قبل ثلاث ليالٍ، ضربت الصحراءَ عاصفةٌ لم يرَ أهل مدينة النخيل مثلها منذ مئة عام.", GOLD,
					_cam(o + Vector3(70, 30, 60), o, o + Vector3(40, 14, 40), 9.0),
					func(): _actor("saif", o + Vector3(17, 0, 3), o)),
				_say("", "وحين هدأت الرمال، انكشف عند الواحة القديمة شيءٌ ظلّ مدفوناً ألف سنة.", GOLD,
					_cam(o + Vector3(30, 5, 14), o + Vector3(17, 1.2, 3), o + Vector3(22, 2.2, 7), 8.0)),
				_say("سيف", "سوار؟… دافئ كأنه حيّ. من يترك شيئاً كهذا في الرمل؟", C_SAIF,
					_cam(o + Vector3(12.6, 1.7, 0.6), o + Vector3(17, 1.3, 3), o + Vector3(13.8, 1.55, 1.4), 7.0),
					func(): actors[0].action("pick")),
				_say("السوار", "خمسةُ حرّاسٍ ينامون فيّ يا ابن المدينة. أيقِظهم… فمدينتك ستحتاجهم قبل الفجر.", C_BRACELET,
					_cam(o + Vector3(14.6, 1.2, 4.6), o + Vector3(17, 1.3, 3), o + Vector3(13.2, 2.6, 6.0), 8.0),
					func(): Game.combat.fx_ring(o + Vector3(17, 0, 3), 5.0, C_BRACELET)),
				_say("سيف", "من… من يتكلم؟!", C_SAIF, null, func(): actors[0].action("hit")),
				_say("ليلى (على الهاتف)", "سيف! أين أنت؟ عصابة تهجم على الناس في الساحة تحت بيتنا! تعال بسرعة!", C_LAYLA,
					_cam(S + Vector3(14, 6, 16), S + Vector3(0, 1, -10), S + Vector3(9, 3, 9), 8.0),
					func():
						_spawn_group(["thug", "thug", "thug", "thug"], S + Vector3(0, 0, -12), 6.0)
						_actor("layla", S + Vector3(-9, 0, 10), S + Vector3(0, 0, -12))
						_place_player(S + Vector3(0, 0, 8), 0.0)),
				_say("بلطجي", "هاتوا كل ما في جيوبكم! هذه الساحة صارت لنا!", C_ENEMY,
					_cam(S + Vector3(4, 1.8, -6), S + Vector3(0, 1.4, -12), S + Vector3(2, 2.0, -7), 6.0)),
				_say("السوار", "ضع يدك عليّ يا سيف… ونادِ الحارس الأول: جلمود.", C_BRACELET,
					_cam(S + Vector3(2.5, 1.8, 11), S + Vector3(0, 1.3, 8), S + Vector3(1.6, 1.6, 10), 6.0)),
			]
		1:
			st = [
				_say("ليلى", "سيف، انظر إلى البرج. هؤلاء ليسوا شرطة… على ستراتهم شعار «أفق للطاقة».", C_LAYLA,
					_cam(T + Vector3(-50, 12, 55), T + Vector3(0, 30, 0), T + Vector3(-36, 6, 40), 8.0),
					func():
						_spawn_group(["soldier", "soldier", "soldier", "thug", "soldier", "thug", "soldier", "soldier"], T, 26.0, true, 0.6)
						_actor("layla", marker_pos(1) + Vector3(-2, 0, 2), T)),
				_say("جندي أفق", "المنطقة مغلقة بأمر السيد راكان. ارجع من حيث جئت!", C_ENEMY,
					_cam(T + Vector3(-14, 2, 30), T + Vector3(-22, 1.5, 14), T + Vector3(-16, 2.2, 26), 6.0)),
				_say("سيف", "راكان… صاحب أكبر شركة في المدينة. لماذا يحتاج جيشاً عند برجٍ فارغ؟", C_SAIF,
					_cam(marker_pos(1) + Vector3(3, 1.8, 4), marker_pos(1) + Vector3(0, 1.4, 0), null, 6.0)),
				_say("السوار", "هو يبحث عني. لقد حفر الصحراء عشر سنين ليجدني… وأنت سبقته بليلة واحدة.", C_BRACELET),
			]
		2:
			var pk := City.block_center(3, 4)
			st = [
				_say("ليلى", "اخترقتُ لاسلكي «أفق». زرعوا أربعة أجهزة شفط في أنحاء المدينة.", C_LAYLA,
					_cam(pk + Vector3(20, 40, 60), pk, pk + Vector3(-20, 60, 80), 9.0),
					func(): _actor("layla", marker_pos(2) + Vector3(-2, 0, 1.5), marker_pos(2))),
				_say("ليلى", "إن اشتغلت الأربعة معاً ستسحب كل كهرباء المدينة نحو البرج… وتنطفئ النخيل كلها.", C_LAYLA,
					_cam(City.block_center(3, 6) + Vector3(16, 5, 16), City.block_center(3, 6) + Vector3(8, 2, 8), null, 6.0)),
				_say("سيف", "أربعة أجهزة في أربع جهات؟ لن ألحق حتى بالسيارة.", C_SAIF,
					_cam(marker_pos(2) + Vector3(3, 1.8, 4), marker_pos(2) + Vector3(0, 1.4, 0), null, 6.0)),
				_say("السوار", "إذن لا تركب. اركض… الحارس الثاني أسرع من البرق نفسه: وميض.", C_BRACELET, null,
					func(): Game.combat.fx_ring(marker_pos(2), 5.0, Color(1.0, 0.92, 0.3))),
			]
		3:
			st = [
				_say("ليلى", "شيء يطير فوق الرصيف البحري… ليست طيوراً. الصيادون هربوا كلهم.", C_LAYLA,
					_cam(Vector3(130, 6, 380), Vector3(100, 14, 440), Vector3(120, 10, 400), 8.0),
					func(): _spawn_group(["bat", "bat", "bat", "bat", "bat"], Vector3(100, 0, 440), 18.0)),
				_say("ليلى", "خفافيش بحجم إنسان. تجارب «أفق» أفلتت من منصّتهم في البحر.", C_LAYLA,
					_cam(Vector3(104, 12, 424), Vector3(100, 14, 440), Vector3(96, 16, 428), 6.0)),
				_say("سيف", "وكيف أصل إليها؟ أنا لا أطير.", C_SAIF,
					_cam(marker_pos(3) + Vector3(3, 1.8, -4), marker_pos(3) + Vector3(0, 1.4, 0), null, 6.0)),
				_say("السوار", "أنت لا. لكن الحارس الثالث وُلد في النار وعاش في السماء: لهيب.", C_BRACELET, null,
					func(): Game.combat.fx_ring(marker_pos(3), 5.0, Color(1.0, 0.45, 0.15))),
			]
		4:
			var c4 := City.block_center(7, 2)
			st = [
				_say("ليلى", "وجدته! د. منصور، كبير علماء «أفق». يحاولون تهريبه من الساحة الشرقية.", C_LAYLA,
					_cam(c4 + Vector3(-30, 14, 34), c4, c4 + Vector3(-20, 8, 24), 8.0),
					func():
						Game.combat.spawn("mech", c4 + Vector3(-10, 0.2, -6))
						_spawn_group(["soldier", "soldier", "soldier", "soldier"], c4, 16.0, true, 0.4)
						_actor("doctor", c4 + Vector3(4, 0, -4), c4 + Vector3(-20, 0, 20))),
				_say("د. منصور", "أرجوكم… لا أريد أن أكمل هذا العمل. دعوني أذهب!", C_DOC,
					_cam(c4 + Vector3(6.5, 1.8, -1), c4 + Vector3(4, 1.4, -4), null, 6.0)),
				_say("جندي أفق", "اصمت يا دكتور. شغّلوا آلي الحراسة — أحدهم يقترب!", C_ENEMY,
					_cam(c4 + Vector3(-2, 3, 4), c4 + Vector3(-10, 3, -6), c4 + Vector3(-4, 4, 2), 6.0)),
				_say("السوار", "ذلك الحديد لا يشعر بالضربات. استخدم كل من أيقظتَ من الحرّاس.", C_BRACELET),
			]
		5:
			st = [
				_say("ليلى", "جهاز التحكم بكل آليّات «أفق» في مستودعهم جنوب المدينة. ستة حرّاس، وكلهم متيقّظون.", C_LAYLA,
					_cam(DEPOT + Vector3(-40, 22, 36), DEPOT, DEPOT + Vector3(-28, 12, 26), 8.0),
					func():
						var gs := _spawn_group(["soldier", "soldier", "soldier", "soldier", "soldier", "soldier"], DEPOT, 13.0, false, 0.3)
						for g in gs:
							g.sight = 0.0),
				_say("ليلى", "إن رأوك سيطلبون تعزيزات… ومتحوّلوهم ليسوا كالجنود.", C_LAYLA,
					_cam(DEPOT + Vector3(10, 2, 14), DEPOT + Vector3(0, 1.4, 0), DEPOT + Vector3(6, 2.4, 10), 6.0)),
				_say("سيف", "إذن يجب ألا يراني أحد.", C_SAIF,
					_cam(marker_pos(5) + Vector3(-3, 1.8, 4), marker_pos(5) + Vector3(0, 1.4, 0), null, 5.0)),
				_say("السوار", "الحارس الخامس لا يُرى ولا يُسمع… ولا يرحم من يدير له ظهره: طيف.", C_BRACELET, null,
					func(): Game.combat.fx_ring(marker_pos(5), 5.0, Color(0.7, 0.55, 1.0))),
			]
		_:
			var bp := T + Vector3(27, 0, 2)
			st = [
				_say("راكان", "عشر سنين وأنا أقلب الصحراء حجراً حجراً… ثم يلتقطه ولدٌ خرج يتمشّى بعد العاصفة!", C_ENEMY,
					_cam(bp + Vector3(8, 3, 22), bp + Vector3(0, 4, 0), bp + Vector3(5, 5, 14), 8.0),
					func(): Game.combat.spawn("boss", T + Vector3(27, 0.2, 2))),
				_say("سيف", "السوار ليس لك يا راكان. وليس لي أيضاً. هو للمدينة.", C_SAIF,
					_cam(marker_pos(6) + Vector3(-3, 1.8, 4), marker_pos(6) + Vector3(0, 1.4, 0), null, 6.0)),
				_say("راكان", "المدينة؟ المدينة ستشكرني حين أُنيرها بطاقته ألف سنة! أعطني إياه… أو آخذه من تحت الركام.", C_ENEMY,
					_cam(bp + Vector3(-6, 9, 12), bp + Vector3(0, 4.5, 0), bp + Vector3(-3, 6, 9), 7.0)),
				_say("السوار", "خمسة حرّاس ورجلٌ واحد شجاع. هذا يكفي. قاتِل يا سيف.", C_BRACELET),
			]
	return st


func _outro(ch: int) -> Array:
	var pp: Vector3 = Game.pos()
	# لقطة جانبية: البطل ومن يكلّمه وجهاً لوجه
	var fa: float = Game.player.rig.rotation.y
	var fw := Vector3(-sin(fa), 0, -cos(fa))
	var rt := Vector3(-fw.z, 0, fw.x)
	var mid := pp + fw * 1.2 + Vector3(0, 1.3, 0)
	var friend := pp + fw * 2.4
	var near_cam := _cam(mid + rt * 5.2 + Vector3(0, 0.5, 0), mid, mid + rt * 4.0 + Vector3(0, 0.3, 0), 7.0)
	var st := []
	match ch:
		0:
			st = [
				_say("ليلى", "سيف…؟ ذلك الوحش الحديدي… كان أنت؟!", C_LAYLA, near_cam,
					func(): _actor("layla", friend, pp)),
				_say("سيف", "لا أعرف ماذا كان. لكنه أنقذ الناس… وأظن أن هذه ليست آخر مرة.", C_SAIF),
				_say("السوار", "واحدٌ استيقظ، وبقي أربعة. طاقتي تنفد إن طال التحوّل — عُد بشراً لأستريح.", C_BRACELET),
			]
		1:
			st = [
				_say("جندي أفق", "آه… السيد راكان… سيأخذه منك… مهما فعلت…", C_ENEMY, near_cam),
				_say("السوار", "أحسنت. الحارس الثاني يتململ في نومه… إنه يشمّ رائحة سباق.", C_BRACELET),
			]
		2:
			st = [
				_say("ليلى", "الأجهزة الأربعة صامتة! المدينة ما زالت مضيئة يا سيف!", C_LAYLA, near_cam),
				_say("سيف", "قدماي… لا أشعر بهما. هل ركضتُ فعلاً بهذه السرعة؟", C_SAIF),
				_say("السوار", "وميض راضٍ عنك. والآن ارفع رأسك… الثالث يريد السماء.", C_BRACELET),
			]
		3:
			st = [
				_say("ليلى", "السماء نظيفة. الصيادون يصفّقون لك من الشاطئ… يظنّونك تنّيناً حقيقياً!", C_LAYLA, near_cam),
				_say("سيف", "لا تخبريهم أني أخاف المرتفعات.", C_SAIF),
				_say("السوار", "الرابع ليس وحشاً ولا طائراً. هو عقلٌ من ضوء. ستحتاجه أمام الحديد.", C_BRACELET),
			]
		4:
			var c4 := City.block_center(7, 2)
			st = [
				_say("د. منصور", "أنا… أنا من صمّم أجهزة الشفط. والدرع الذي يبنيه راكان الآن من تصميمي أيضاً.", C_DOC,
					_cam(c4 + Vector3(7, 1.9, 0), c4 + Vector3(4, 1.4, -4), c4 + Vector3(6, 1.7, -1), 8.0),
					func():
						_actor("doctor", c4 + Vector3(4, 0, -4), c4 + Vector3(6, 0, 0))
						_place_player(c4 + Vector3(6.5, 0, -0.5), 2.4)),
				_say("د. منصور", "لم يكن لي خيار. ابنتي محتجزة عنده منذ سنة. كل ما فعلتُه كان لأراها مرة أخرى.", C_DOC),
				{"who": "سيف", "col": C_SAIF, "text": "ماذا تقول له؟", "choice": [
					["«أصدّقك. ساعدني لأوقف راكان، وسنُخرج ابنتك معاً.»", "mercy"],
					["«آلاتك كادت تُطفئ مدينة كاملة. ستسلّم نفسك وتشهد عليه.»", "justice"]]},
				{"who": "د. منصور", "col": C_DOC, "text": "", "text_fn": _doc_reply},
				_say("السوار", "اخترتَ بقلبك يا سيف. الحارس الأخير لا يوقظه إلا من يعرف متى يضرب… ومتى يكفّ.", C_BRACELET),
			]
		5:
			st = [
				_say("ليلى", "دخلتَ النظام! كل آليّات «أفق» في المدينة أُطفئت… إلا واحدة.", C_LAYLA,
					_cam(DEPOT + Vector3(5, 2, 6), DEPOT + Vector3(0, 1.3, 0), DEPOT + Vector3(3, 1.8, 4), 7.0)),
				_say("ليلى", "درعٌ بطول ثلاثة طوابق، يتحرك الآن نحو برج النخيل. وراكان بداخله.", C_LAYLA,
					_cam(T + Vector3(60, 30, 70), T + Vector3(0, 50, 0), T + Vector3(40, 20, 50), 7.0)),
				_say("سيف", "إذن هناك ينتهي كل شيء.", C_SAIF),
			]
		_:
			var bp := T + Vector3(27, 0, 14)
			if Game.choice == "mercy":
				st = [
					_say("د. منصور (لاسلكي)", "سيف! أدخلتُ رمز الإيقاف من المختبر — الدرع لن يقوم مرة أخرى. وابنتي… ابنتي معي!", C_DOC,
						_cam(bp + Vector3(8, 5, 16), bp, bp + Vector3(5, 3, 10), 8.0),
						func(): _actor("layla", friend, pp)),
					_say("راكان", "كنتُ سأنير المدينة ألف سنة…", C_ENEMY),
					_say("سيف", "المدينة مضيئة يا راكان. بأهلها.", C_SAIF, near_cam),
				]
			else:
				st = [
					_say("ليلى", "الشرطة في الطريق. د. منصور سلّم نفسه وأعطاهم كل الملفات — راكان انتهى.", C_LAYLA,
						_cam(bp + Vector3(8, 5, 16), bp, bp + Vector3(5, 3, 10), 8.0),
						func(): _actor("layla", friend, pp)),
					_say("راكان", "كنتُ سأنير المدينة ألف سنة…", C_ENEMY),
					_say("سيف", "المدينة مضيئة يا راكان. بأهلها.", C_SAIF, near_cam),
				]
			st.append(_say("السوار", "خمسة حرّاس استيقظوا، ومدينةٌ نامت آمنة. نَم أنت أيضاً يا سيف… فغداً قد تحتاجنا النخيل من جديد.", C_BRACELET,
				_cam(T + Vector3(90, 60, 110), T + Vector3(0, 60, 0), T + Vector3(120, 90, 60), 12.0)))
	return st


func _doc_reply() -> String:
	## ردّ الدكتور حسب اختيار اللاعب
	if Game.choice == "justice":
		return "…أنت محقّ. تعبتُ من الهرب. سأسلّم نفسي وأقول كل شيء. فقط… أخرِجوا ابنتي من هناك."
	return "ستُخرجها؟… إذن خذ هذا. مُثبِّت طاقة — سوارك سيصمد به أطول. وسأعطّل الدرع من الداخل حين يحين الوقت."


func abort() -> void:
	## عند الخروج للقائمة: ألغِ الفصل الجاري (يُعاد من بدايته لاحقاً)
	if cut.active:
		cut.active = false
		cut.root.visible = false
		Game.cam.end_cine()
	_clear_actors()
	Game.combat.clear_enemies()
	for d in _devices:
		if is_instance_valid(d):
			Game.combat.props.erase(d)
			d.queue_free()
	_devices.clear()
	active = false
	_busy = false
	_await_respawn = false
	boss = null
	timer = -1.0
	target = null
	objective = ""
