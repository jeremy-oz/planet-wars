## Music and sound effects. Buses Music / SFX / UI under Master, a small voice pool for effects,
## and two looping pads (calm, tense) crossfaded by how much of the war is in flight.
extends Node

const SOUNDS := ["whoosh", "thud", "ui_click", "ui_hover", "select", "deny", "win", "lose"]
const CHIMES := 10
const POOL := 16
const MAX_SAME_PER_FRAME := 3

var volumes := {"music": 0.7, "sfx": 0.8, "ui": 0.6}
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _tension := 0.0
var _tension_target := 0.0
var _music_gain := 0.0
var _paused := false  # the game is paused: the music fades out and holds its place
var _played_this_frame: Dictionary = {}


func _ready() -> void:
	for bus in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	for n in SOUNDS:
		_streams[n] = _load(n)
	for i in range(CHIMES):
		_streams["chime_%d" % i] = _load("chime_%d" % i)
	for i in range(POOL):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_calm = _music_player("pad_calm")
	_tense = _music_player("pad_tense")
	apply_volumes(volumes)
	_calm.volume_db = -80.0
	_tense.volume_db = -80.0
	_calm.play()
	_tense.play()


func _process(delta: float) -> void:
	_played_this_frame.clear()
	_tension = move_toward(_tension, _tension_target, delta * 0.12)
	if _paused:
		_music_gain = move_toward(_music_gain, 0.0, delta * 4.0)  # out in a quarter second
		if _music_gain <= 0.0 and not _calm.stream_paused:
			_calm.stream_paused = true
			_tense.stream_paused = true
	else:
		if _calm.stream_paused:
			_calm.stream_paused = false
			_tense.stream_paused = false
		_music_gain = move_toward(_music_gain, 1.0, delta * 0.8)  # music fades in, never starts abruptly
	_calm.volume_db = linear_to_db(maxf(0.0001, _music_gain * (1.0 - 0.5 * _tension)))
	_tense.volume_db = linear_to_db(maxf(0.0001, _music_gain * _tension * 0.9))


## Pausing the game pauses the music (fade out, hold the position); resuming fades it back in.
func set_paused(p: bool) -> void:
	_paused = p


func is_music_paused() -> bool:
	return _paused and _calm.stream_paused


func music_gain() -> float:
	return _music_gain


## 0 = calm, 1 = everything is in flight. Moves slowly so the music never lurches.
func set_tension(t: float) -> void:
	_tension_target = clampf(t, 0.0, 1.0)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0, bus: String = "SFX") -> void:
	var s: AudioStream = _streams.get(sound)
	if s == null or _pool.is_empty():
		return
	var count: int = int(_played_this_frame.get(sound, 0))
	if count >= MAX_SAME_PER_FRAME:
		return
	_played_this_frame[sound] = count + 1
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = bus
	p.play()


func play_ui(sound: String) -> void:
	play(sound, -9.0 if sound == "ui_hover" else -3.0, 1.0, "UI")


func chime(index: int, volume_db: float = 0.0) -> void:
	play("chime_%d" % clampi(index, 0, CHIMES - 1), volume_db)


func apply_volumes(v: Dictionary) -> void:
	for k in ["music", "sfx", "ui"]:
		if v.has(k):
			volumes[k] = float(v[k])
	_set_bus("Music", volumes["music"])
	_set_bus("SFX", volumes["sfx"])
	_set_bus("UI", volumes["ui"])


func _set_bus(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _load(sound: String) -> AudioStream:
	var path := "res://game/audio/%s.wav" % sound
	if not ResourceLoader.exists(path):
		push_warning("audio: missing %s (run `make audio`)" % path)
		return null
	return load(path)


func _music_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	var s := _load(sound) as AudioStreamWAV
	if s != null:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(round(s.get_length() * s.mix_rate))
		p.stream = s
	add_child(p)
	return p
