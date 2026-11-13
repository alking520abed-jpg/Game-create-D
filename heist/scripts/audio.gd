extends Node
## الصوت: مؤثرات ثنائية وثلاثية الأبعاد، حلقات، وموسيقى متغيرة حسب الموقف.

var _cache := {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _loops := {}
var _music := {}
var _music_target := ""
var _i2 := 0
var _i3 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)
	for i in 14:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 9.0
		p3.max_distance = 70.0
		p3.attenuation_filter_cutoff_hz = 9000.0
		add_child(p3)
		_pool3d.append(p3)
	for m in ["music_tense", "music_action"]:
		var mp := AudioStreamPlayer.new()
		mp.stream = _stream(m, true)
		mp.volume_db = -60.0
		add_child(mp)
		_music[m] = mp
	Game.settings_changed.connect(_apply)


func _stream(n: String, loop := false) -> AudioStream:
	var key := n + ("@" if loop else "")
	if not _cache.has(key):
		var s: AudioStreamWAV = load("res://sfx/%s.wav" % n)
		if loop:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_end = s.data.size() / 2
		_cache[key] = s
	return _cache[key]


func play(n: String, db := 0.0, pitch := 1.0) -> void:
	if not Game.settings["sound"]:
		return
	var p := _pool2d[_i2]
	_i2 = (_i2 + 1) % _pool2d.size()
	p.stream = _stream(n)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.play()


func play_at(n: String, pos: Vector3, db := 0.0, pitch := 1.0) -> void:
	if not Game.settings["sound"]:
		return
	var p := _pool3d[_i3]
	_i3 = (_i3 + 1) % _pool3d.size()
	p.stream = _stream(n)
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.global_position = pos
	p.play()


## حلقة صوت ثلاثية الأبعاد باسم (مثقاب، إنذار...)
func loop_at(id: String, n: String, pos: Vector3, db := 0.0) -> void:
	stop_loop(id)
	var p := AudioStreamPlayer3D.new()
	p.stream = _stream(n, true)
	p.unit_size = 12.0
	p.max_distance = 80.0
	p.volume_db = db if Game.settings["sound"] else -80.0
	add_child(p)
	p.global_position = pos
	p.play()
	_loops[id] = p


func stop_loop(id: String) -> void:
	if _loops.has(id):
		_loops[id].queue_free()
		_loops.erase(id)


func stop_all_loops() -> void:
	for id in _loops.keys():
		stop_loop(id)


func music(n: String) -> void:
	_music_target = n
	if n != "" and not _music[n].playing:
		_music[n].play()


func _process(delta: float) -> void:
	for m in _music:
		var p: AudioStreamPlayer = _music[m]
		var want := -12.0 if (m == _music_target and Game.settings["music"]) else -60.0
		p.volume_db = move_toward(p.volume_db, want, delta * 30.0)
		if p.volume_db <= -59.0 and p.playing and m != _music_target:
			p.stop()


func _apply() -> void:
	for id in _loops:
		_loops[id].volume_db = 0.0 if Game.settings["sound"] else -80.0
