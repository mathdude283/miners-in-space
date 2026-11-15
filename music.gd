extends Node
## Background music and the sound settings. Autoload "Music".
## Six gentle piano-and-strings pieces from the team's web prototype (original, synthesized, no commercial samples).
## Music.play("design") crossfades to that piece and loops it. M (handled in Sfx) mutes everything.
## The volumes are saved in user://settings.cfg so they stay the way the player left them.

const FOLDER := "res://assets/audio/music/classical_%s.mp3"
const TRACKS := ["design", "launch", "cruise", "orbit", "event", "landing"]
const SETTINGS := "user://settings.cfg"
const FADE := 1.6

var music_volume := 0.5        # 0 to 1, the player's slider
var sfx_volume := 0.7          # 0 to 1; 0.7 is how loud the sounds were before there was a slider

var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _current := ""
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	_apply_sfx()


## Fade to this piece (one of TRACKS). Asking for the one already playing does nothing.
func play(track: String) -> void:
	if track == _current or not TRACKS.has(track):
		return
	_current = track
	var s := _stream(track)
	if s == null:
		return
	var old := _players[_front]
	_front = 1 - _front
	var nw := _players[_front]
	nw.stream = s
	nw.volume_db = -80.0
	nw.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(nw, "volume_db", _target_db(), FADE)
	tw.tween_property(old, "volume_db", -80.0, FADE)
	tw.chain().tween_callback(old.stop)


func current() -> String:
	return _current


func set_music(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	if not _players.is_empty():
		_players[_front].volume_db = _target_db()
	_save()


func set_sfx(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_sfx()
	_save()


func _target_db() -> float:
	return -80.0 if music_volume <= 0.001 else linear_to_db(music_volume * 0.5)


func _apply_sfx() -> void:
	var sfx = get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.master_db = -5.0 + (-80.0 if sfx_volume <= 0.001 else linear_to_db(sfx_volume / 0.7))


func _stream(track: String) -> AudioStream:
	if not _streams.has(track):
		var s = load(FOLDER % track)
		if s is AudioStreamMP3:
			s.loop = true
		_streams[track] = s
	return _streams[track]


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS) == OK:
		music_volume = float(cf.get_value("sound", "music", music_volume))
		sfx_volume = float(cf.get_value("sound", "sfx", sfx_volume))


func _save() -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS)
	cf.set_value("sound", "music", music_volume)
	cf.set_value("sound", "sfx", sfx_volume)
	cf.save(SETTINGS)
