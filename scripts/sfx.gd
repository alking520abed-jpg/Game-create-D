extends Node
## كل الأصوات مولّدة بالكود: محرك، زمور، نقود، موسيقى خلفية...

const RATE := 22050
var sounds := {}
var pool: Array[AudioStreamPlayer] = []
var engine: AudioStreamPlayer
var music: AudioStreamPlayer
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	sounds["click"] = _tone([[900.0, 0.0, 0.05]], 0.5, 30.0)
	sounds["coin"] = _tone([[1318.0, 0.0, 0.09], [1976.0, 0.08, 0.3]], 0.5, 9.0)
	sounds["star"] = _tone([[1047.0, 0.0, 0.1], [1319.0, 0.07, 0.1], [1568.0, 0.14, 0.1], [2093.0, 0.21, 0.4]], 0.45, 7.0)
	sounds["success"] = _tone([[523.0, 0.0, 0.16], [659.0, 0.14, 0.16], [784.0, 0.28, 0.16], [1047.0, 0.42, 0.6]], 0.5, 4.0)
	sounds["fail"] = _tone([[392.0, 0.0, 0.25], [330.0, 0.22, 0.25], [262.0, 0.44, 0.6]], 0.5, 3.5, true)
	sounds["beep"] = _tone([[660.0, 0.0, 0.14]], 0.5, 6.0)
	sounds["go"] = _tone([[1320.0, 0.0, 0.5]], 0.5, 3.0)
	sounds["horn"] = _tone([[415.0, 0.0, 0.42], [523.0, 0.0, 0.42]], 0.4, 0.6, true)
	sounds["door"] = _noise(0.16, 0.6)
	sounds["jump"] = _sweep(260.0, 520.0, 0.14, 0.35)
	sounds["meow"] = _meow()
	engine = AudioStreamPlayer.new()
	engine.stream = _engine()
	engine.volume_db = -60.0
	add_child(engine)
	music = AudioStreamPlayer.new()
	music.volume_db = -17.0
	add_child(music)
	_thread = Thread.new()
	_thread.start(_gen_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


func play(n: String, db := 0.0, pitch := 1.0) -> void:
	if not Game.settings["sound"] or not sounds.has(n):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[n]
			p.volume_db = db
			p.pitch_scale = pitch
			p.play()
			return
	pool[0].stream = sounds[n]
	pool[0].volume_db = db
	pool[0].pitch_scale = pitch
	pool[0].play()


func engine_set(active: bool, speed01 := 0.0, throttle := 0.0) -> void:
	if not active or not Game.settings["sound"]:
		if engine.playing:
			engine.stop()
		return
	if not engine.playing:
		engine.play()
	engine.pitch_scale = lerp(engine.pitch_scale, 0.7 + speed01 * 1.5 + throttle * 0.15, 0.2)
	engine.volume_db = lerp(engine.volume_db, -19.0 + throttle * 5.0, 0.2)


func update_music() -> void:
	if music.stream == null:
		return
	var want: bool = Game.settings["music"] and Game.settings["sound"]
	if want and not music.playing:
		music.play()
	elif not want and music.playing:
		music.stop()


func _wav(buf: PackedFloat32Array, loop := false, rate := RATE) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


func _tone(notes: Array, vol: float, decay: float, saw := false) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total = max(total, n[1] + n[2])
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE))
	for n in notes:
		var f: float = n[0]
		var start := int(n[1] * RATE)
		var cnt := int(n[2] * RATE)
		for i in cnt:
			var t := float(i) / RATE
			var env: float = exp(-decay * t) * min(1.0, i / 60.0) * min(1.0, (cnt - i) / 200.0)
			var s := sin(TAU * f * t)
			if saw:
				s = 0.6 * s + 0.4 * (fmod(f * t, 1.0) * 2.0 - 1.0)
			buf[start + i] += s * env * vol
	return _wav(buf)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var n := int(dur * RATE)
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerp(f0, f1, k) / RATE
		buf[i] = sin(ph) * vol * (1.0 - k)
	return _wav(buf)


func _noise(dur: float, vol: float) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var n := int(dur * RATE)
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		lp = lerp(lp, randf() * 2.0 - 1.0, 0.12)
		buf[i] = (lp * 2.0 + sin(TAU * 70.0 * i / RATE) * 0.6) * vol * exp(-k * 6.0)
	return _wav(buf)


func _meow() -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	var n := int(0.55 * RATE)
	buf.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		var f := 520.0 + 380.0 * sin(k * PI) - 120.0 * k
		ph += TAU * f / RATE
		var s := sin(ph) * 0.6 + sin(ph * 2.0) * 0.3 + sin(ph * 3.0) * 0.15
		buf[i] = s * sin(k * PI) * 0.45
	return _wav(buf)


func _engine() -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var s := (fmod(80.0 * t, 1.0) * 2.0 - 1.0) * 0.45
		s += sin(TAU * 40.0 * t) * 0.5 + sin(TAU * 160.0 * t) * 0.18 + sin(TAU * 120.0 * t) * 0.12
		buf[i] = s * 0.5 * (0.85 + 0.15 * sin(TAU * 20.0 * t))
	return _wav(buf, true)


func _gen_music() -> void:
	# لحن هادئ على مقام حجاز، يتولد في الخلفية
	var rate := 16000
	var step := 0.34
	var hz := {"D": 146.83, "Eb": 155.56, "F#": 185.0, "G": 196.0, "A": 220.0, "Bb": 233.08, "C": 261.63, "D2": 293.66, "Eb2": 311.13, "F#2": 369.99, "G2": 392.0, "A2": 440.0}
	var seq := ["D2", "", "Eb2", "D2", "C", "", "Bb", "A", "", "A", "Bb", "C", "D2", "", "", "",
		"G", "", "A", "Bb", "A", "", "G", "F#", "", "F#", "G", "A", "G", "", "", "",
		"D2", "", "F#2", "G2", "F#2", "", "Eb2", "D2", "", "C", "Bb", "A", "Bb", "", "C", "",
		"A", "", "G", "F#", "Eb", "", "F#", "G", "", "Eb", "", "D", "D", "", "", ""]
	var bass := ["D", "D", "G", "G", "D", "D", "A", "D"]
	var total := int(seq.size() * step * rate)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for si in seq.size():
		if seq[si] == "":
			continue
		var f: float = hz[seq[si]] * 2.0
		var start := int(si * step * rate)
		var cnt := int(1.3 * rate)
		for i in cnt:
			var t := float(i) / rate
			var env: float = exp(-3.2 * t) * min(1.0, i / 30.0)
			var s := sin(TAU * f * t) + 0.5 * sin(TAU * f * 2.0 * t) * exp(-5.0 * t) + 0.25 * sin(TAU * f * 3.0 * t) * exp(-8.0 * t)
			buf[(start + i) % total] += s * env * 0.16
	for bi in bass.size():
		var f2: float = hz[bass[bi]] * 0.5
		var start2 := int(bi * 8 * step * rate)
		var cnt2 := int(8 * step * rate)
		for i in cnt2:
			var t := float(i) / rate
			var env: float = min(1.0, i / 3000.0) * min(1.0, (cnt2 - i) / 3000.0)
			buf[(start2 + i) % total] += (sin(TAU * f2 * t) + 0.4 * sin(TAU * f2 * 1.5 * t)) * env * 0.09
	var w := _wav(buf, true, rate)
	call_deferred("_music_ready", w)


func _music_ready(w: AudioStreamWAV) -> void:
	music.stream = w
	update_music()
