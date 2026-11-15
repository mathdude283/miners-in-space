extends Node
## Sound for the whole game. Every sound is made in code (no audio files, so nothing to license or credit).
## Each one is a short synthesized recording, built the first time it is needed and then kept.
##
## Sfx.play("click")            one-shot, any name from _make()
## Sfx.loop_start("rumble")     a looping bed (engine). Sfx.loop_stop("rumble") fades it out.
## Press M anywhere to mute or unmute. Every button in the game also gets a click and a small press squash.

const RATE := 22050
const POOL := 12

var muted := false
var master_db := -5.0

var _cache := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _loops := {}
var _last_hover := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)


# ---------------------------------------------------------------- playing

func play(sound: String, vol := 0.0, pitch := 1.0) -> void:
	var s: AudioStreamWAV = _stream(sound)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = master_db + vol
	p.pitch_scale = pitch
	p.play()


func loop_start(sound: String, vol := 0.0) -> void:
	var s: AudioStreamWAV = _stream(sound)
	if s == null:
		return
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		add_child(p)
		_loops[sound] = p
	if p.playing:
		p.stream_paused = false
		loop_level(sound, vol, 0.2)
		return
	p.stream = s
	p.volume_db = -50.0
	p.play()
	create_tween().tween_property(p, "volume_db", master_db + vol, 0.6)


func loop_level(sound: String, vol: float, over := 0.4) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p != null and p.playing:
		create_tween().tween_property(p, "volume_db", master_db + vol, over)


func loop_stop(sound: String, fade := 0.5) -> void:
	var p: AudioStreamPlayer = _loops.get(sound)
	if p == null or not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -50.0, fade)
	tw.tween_callback(p.stop)


func stop_all_loops() -> void:
	for k in _loops:
		loop_stop(k, 0.2)


# ---------------------------------------------------------------- every button gets sound and a squash

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		var b := n as BaseButton
		# A button that is moved to another parent is "added" again: do not connect it twice
		if b.has_meta("sfx_wired"):
			return
		b.set_meta("sfx_wired", true)
		b.pressed.connect(_on_pressed.bind(b))
		b.mouse_entered.connect(_on_hover.bind(b))


func _on_pressed(b: BaseButton) -> void:
	if b.has_meta("silent"):
		return
	play("confirm" if b.theme_type_variation == &"PrimaryButton" else "click")
	var c := b as Control
	if c != null and c.is_inside_tree():
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2(0.95, 0.95)
		var tw := c.create_tween()
		tw.tween_property(c, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_hover(b: BaseButton) -> void:
	if b.disabled or b.has_meta("silent"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_hover < 0.05:
		return
	_last_hover = now
	play("hover", -9.0)


# ---------------------------------------------------------------- the synthesizer

func _stream(sound: String) -> AudioStreamWAV:
	if not _cache.has(sound):
		_cache[sound] = _make(sound)
	return _cache[sound]


func names() -> Array[String]:
	return ["click", "hover", "confirm", "back", "add", "remove", "error", "beep", "beep_hi", "tick", "go", "nogo", "hold",
		"shutter", "steady", "lock", "lost", "static", "packet", "received", "chime_good", "chime_ok", "chime_poor",
		"boom", "thud", "whoosh", "fanfare", "fail", "stage", "rumble"]


func _make(sound: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	var loop := false
	match sound:
		"click":
			b = _buf(0.06)
			_tone(b, 0.0, 1900.0, 1500.0, 0.04, 0.5)
			_noise(b, 0.0, 0.012, 0.18, 0.7, 2.0)
		"hover":
			b = _buf(0.04)
			_tone(b, 0.0, 1500.0, 1500.0, 0.025, 0.3)
		"confirm":
			b = _buf(0.3)
			_tone(b, 0.0, 660.0, 880.0, 0.1, 0.45)
			_tone(b, 0.07, 880.0, 1320.0, 0.2, 0.45)
		"back":
			b = _buf(0.16)
			_tone(b, 0.0, 700.0, 430.0, 0.14, 0.45)
		"add":
			b = _buf(0.18)
			_tone(b, 0.0, 520.0, 800.0, 0.13, 0.5, "tri")
			_noise(b, 0.0, 0.01, 0.12, 0.6, 2.0)
		"remove":
			b = _buf(0.18)
			_tone(b, 0.0, 620.0, 280.0, 0.14, 0.5, "tri")
		"error":
			b = _buf(0.34)
			_tone(b, 0.0, 170.0, 150.0, 0.12, 0.35, "square", 1.2)
			_tone(b, 0.15, 140.0, 110.0, 0.17, 0.35, "square", 1.2)
		"beep":
			b = _buf(0.18)
			_tone(b, 0.0, 880.0, 880.0, 0.14, 0.5, "sine", 1.0)
		"beep_hi":
			b = _buf(0.5)
			_tone(b, 0.0, 1320.0, 1320.0, 0.45, 0.5, "sine", 1.2)
		"tick":
			b = _buf(0.03)
			_tone(b, 0.0, 2400.0, 2400.0, 0.018, 0.4)
		"go":
			b = _buf(0.55)
			_tone(b, 0.0, 523.0, 523.0, 0.18, 0.4)
			_tone(b, 0.09, 659.0, 659.0, 0.18, 0.4)
			_tone(b, 0.18, 784.0, 784.0, 0.32, 0.4)
		"nogo":
			b = _buf(0.42)
			_tone(b, 0.0, 240.0, 150.0, 0.34, 0.3, "saw", 1.5)
		"hold":
			b = _buf(0.45)
			_tone(b, 0.0, 330.0, 330.0, 0.13, 0.35, "square", 1.0)
			_tone(b, 0.2, 330.0, 330.0, 0.18, 0.35, "square", 1.0)
		"shutter":
			b = _buf(0.22)
			_noise(b, 0.0, 0.014, 0.9, 0.55, 1.5)
			_noise(b, 0.055, 0.035, 0.7, 0.3, 1.5)
			_tone(b, 0.0, 200.0, 120.0, 0.07, 0.35)
		"steady":
			b = _buf(0.22)
			_tone(b, 0.0, 1568.0, 1568.0, 0.16, 0.3)
		"lock":
			b = _buf(0.24)
			_tone(b, 0.0, 700.0, 1250.0, 0.18, 0.45)
		"lost":
			b = _buf(0.34)
			_tone(b, 0.0, 520.0, 210.0, 0.28, 0.45, "tri")
		"static":
			b = _buf(0.55)
			_noise(b, 0.0, 0.5, 0.45, 0.9, 0.7, 0.01)
		"packet":
			b = _buf(0.05)
			_tone(b, 0.0, 1700.0, 2100.0, 0.03, 0.3)
		"received":
			b = _buf(0.75)
			for i in 4:
				_tone(b, 0.1 * i, [659.0, 784.0, 988.0, 1319.0][i], [659.0, 784.0, 988.0, 1319.0][i], 0.26 if i < 3 else 0.4, 0.4)
		"chime_good":
			b = _buf(0.9)
			for i in 4:
				_tone(b, 0.09 * i, [784.0, 988.0, 1175.0, 1568.0][i], [784.0, 988.0, 1175.0, 1568.0][i], 0.3 if i < 3 else 0.5, 0.4)
		"chime_ok":
			b = _buf(0.5)
			_tone(b, 0.0, 660.0, 660.0, 0.2, 0.4)
			_tone(b, 0.1, 880.0, 880.0, 0.3, 0.4)
		"chime_poor":
			b = _buf(0.4)
			_tone(b, 0.0, 330.0, 300.0, 0.3, 0.4, "tri")
		"boom":
			b = _buf(1.9)
			_noise(b, 0.0, 1.8, 3.2, 0.07, 1.8, 0.003)
			_tone(b, 0.0, 95.0, 32.0, 1.3, 0.9, "sine", 1.5)
		"thud":
			b = _buf(0.5)
			_noise(b, 0.0, 0.4, 2.2, 0.1, 2.5, 0.002)
			_tone(b, 0.0, 120.0, 45.0, 0.3, 0.8, "sine", 2.0)
		"whoosh":
			b = _buf(1.1)
			_noise(b, 0.0, 1.0, 2.0, 0.12, 1.0, 0.25)
		"fanfare":
			b = _buf(1.5)
			var notes := [523.0, 659.0, 784.0, 1047.0]
			for i in 4:
				_tone(b, 0.14 * i, notes[i], notes[i], 0.3 if i < 3 else 0.8, 0.4, "tri")
				_tone(b, 0.14 * i, notes[i] * 2.0, notes[i] * 2.0, 0.3 if i < 3 else 0.8, 0.12)
		"fail":
			b = _buf(1.0)
			_tone(b, 0.0, 330.0, 220.0, 0.35, 0.45, "tri")
			_tone(b, 0.3, 247.0, 150.0, 0.65, 0.45, "tri")
		"stage":
			b = _buf(0.4)
			_tone(b, 0.0, 880.0, 1175.0, 0.08, 0.35)
			_tone(b, 0.1, 1175.0, 1175.0, 0.2, 0.35)
		"rumble":
			loop = true
			b = _buf(2.0)
			_noise(b, 0.0, 2.0, 4.5, 0.035, 0.0, 0.0)
			_tone(b, 0.0, 46.0, 46.0, 2.0, 0.5, "tri", 0.0, 0.0)
		_:
			return null
	return _to_stream(b, loop)


func _buf(sec: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * RATE))
	return b


func _tone(b: PackedFloat32Array, at: float, f0: float, f1: float, dur: float, vol: float, shape := "sine", decay := 2.0, attack := 0.004) -> void:
	var start := int(at * RATE)
	var n := int(dur * RATE)
	var phase := 0.0
	for i in n:
		var idx := start + i
		if idx >= b.size():
			break
		var t := float(i) / float(n)
		phase += lerpf(f0, f1, t) / RATE
		var ph := fposmod(phase, 1.0)
		var s := 0.0
		match shape:
			"square":
				s = 1.0 if ph < 0.5 else -1.0
			"saw":
				s = ph * 2.0 - 1.0
			"tri":
				s = 1.0 - 4.0 * absf(ph - 0.5)
			_:
				s = sin(ph * TAU)
		var env := 1.0
		if attack > 0.0:
			env = minf(float(i) / (attack * RATE), 1.0)
		if decay > 0.0:
			env *= pow(1.0 - t, decay)
		b[idx] += s * env * vol


func _noise(b: PackedFloat32Array, at: float, dur: float, vol: float, lp := 1.0, decay := 2.0, attack := 0.002) -> void:
	var start := int(at * RATE)
	var n := int(dur * RATE)
	var y := 0.0
	for i in n:
		var idx := start + i
		if idx >= b.size():
			break
		var t := float(i) / float(n)
		y += lp * (randf_range(-1.0, 1.0) - y)
		var env := 1.0
		if attack > 0.0:
			env = minf(float(i) / (attack * RATE), 1.0)
		if decay > 0.0:
			env *= pow(1.0 - t, decay)
		b[idx] += y * env * vol


func _to_stream(b: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for v in b:
		peak = maxf(peak, absf(v))
	var k := minf(1.0, 0.9 / peak)
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * k, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w
