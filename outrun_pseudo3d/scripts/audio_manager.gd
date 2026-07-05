extends Node
## Autoloaded as "Audio". Central sound system.
##
## Design: the game calls Audio.play("crash") etc. unconditionally. On first
## use, each sound name is looked up in res://assets/audio/ as .ogg/.wav/.mp3.
## Missing files are silent no-ops — the game runs identically with zero,
## some, or all sound files present. Drop correctly named files in and they
## just work; no code changes needed. See assets/audio/SOUNDS.md for the list.

# === CONFIG ===

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS: PackedStringArray = ["ogg", "wav", "mp3"]
const ONESHOT_POOL_SIZE := 8

const MUSIC_VOLUME_DB := -8.0
const ENGINE_MIN_VOLUME_DB := -20.0
const ENGINE_MAX_VOLUME_DB := -6.0
const ENGINE_MIN_PITCH := 0.7
const ENGINE_MAX_PITCH := 1.9
const OFFROAD_VOLUME_DB := -6.0
const SKID_SPEED_THRESHOLD := 0.85   # fraction of max speed
const SKID_COOLDOWN := 0.9           # seconds between skid one-shots

# === STATE ===

var _streams: Dictionary = {}            # name -> AudioStream (or null if missing)
var _oneshot_pool: Array[AudioStreamPlayer] = []
var _cooldowns: Dictionary = {}          # name -> msec timestamp of last play

var _engine_player: AudioStreamPlayer
var _offroad_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	# Music gets its own bus so its volume is adjustable independently of SFX
	# (which ride the Master bus).
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	_engine_player = _make_player()
	_offroad_player = _make_player()
	_music_player = _make_player()
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.bus = "Music"
	for i in range(ONESHOT_POOL_SIZE):
		_oneshot_pool.append(_make_player())


func _make_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


# === PUBLIC API ===

## Fire-and-forget one-shot. Missing file = silent no-op.
## cooldown (seconds) suppresses rapid re-triggering of the same sound.
func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0,
		cooldown: float = 0.0) -> void:
	var stream := _find_stream(sound_name)
	if stream == null:
		return
	if cooldown > 0.0:
		var now := Time.get_ticks_msec()
		var last: int = _cooldowns.get(sound_name, -100000)
		if now - last < int(cooldown * 1000.0):
			return
		_cooldowns[sound_name] = now
	for p in _oneshot_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	# Pool exhausted: steal the first player (oldest sound).
	_oneshot_pool[0].stream = stream
	_oneshot_pool[0].volume_db = volume_db
	_oneshot_pool[0].pitch_scale = pitch
	_oneshot_pool[0].play()


## Start a level's music track (looping). Empty name or missing file = silence.
## Calling again with the same name keeps the current playback running.
func play_music(music_name: String) -> void:
	if music_name == _music_name and _music_player.playing:
		return
	_music_name = music_name
	_music_player.stop()
	if music_name.is_empty():
		return
	var stream := _find_stream(music_name)
	if stream == null:
		return
	_music_player.stream = stream
	_music_player.play()


## True if a stream exists on disk for this sound name.
func has_sound(sound_name: String) -> bool:
	return _find_stream(sound_name) != null


## 0..1 linear music volume (Settings menu), on the dedicated Music bus.
func set_music_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
			linear_to_db(maxf(linear, 0.0001)))


func stop_music() -> void:
	_music_name = ""
	_music_player.stop()


## Continuous engine + surface audio. Call every frame from the game loop.
## speed_percent: 0..1 of max speed. off_road: player is on the grass.
## steer: current steering amount (-1..1), used for skid triggering.
func update_engine(speed_percent: float, off_road: bool, steer: float = 0.0) -> void:
	# Engine loop: pitch and volume rise with speed.
	var engine_stream := _find_stream("engine_loop")
	if engine_stream != null:
		if not _engine_player.playing:
			_engine_player.stream = engine_stream
			_engine_player.play()
		_engine_player.pitch_scale = lerpf(ENGINE_MIN_PITCH, ENGINE_MAX_PITCH, speed_percent)
		_engine_player.volume_db = lerpf(ENGINE_MIN_VOLUME_DB, ENGINE_MAX_VOLUME_DB, speed_percent)

	# Off-road rumble loop, only while actually rolling on the grass.
	var offroad_stream := _find_stream("offroad_loop")
	if offroad_stream != null:
		var want := off_road and speed_percent > 0.03
		if want and not _offroad_player.playing:
			_offroad_player.stream = offroad_stream
			_offroad_player.volume_db = OFFROAD_VOLUME_DB
			_offroad_player.play()
		elif not want and _offroad_player.playing:
			_offroad_player.stop()

	# Tire skid: hard steering near top speed.
	if absf(steer) > 0.5 and speed_percent > SKID_SPEED_THRESHOLD and not off_road:
		play("skid", -4.0, 1.0, SKID_COOLDOWN)


## Silence everything gameplay-related (used on level reload).
func stop_engine() -> void:
	_engine_player.stop()
	_offroad_player.stop()


# === LOADING ===

## Resolve a sound name to a stream, trying each extension. Results
## (including misses) are cached. Loops are enabled on *_loop and music_*.
func _find_stream(sound_name: String) -> AudioStream:
	if _streams.has(sound_name):
		return _streams[sound_name]
	var found: AudioStream = null
	for ext in EXTENSIONS:
		var path := AUDIO_DIR + sound_name + "." + ext
		if ResourceLoader.exists(path):
			found = load(path)
			break
	if found != null and (sound_name.ends_with("_loop") or sound_name.begins_with("music_")):
		_enable_loop(found)
	_streams[sound_name] = found
	return found


## Force looping regardless of the file's import settings, per stream type.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		@warning_ignore("integer_division")  # frame count: exact by construction
		wav.loop_end = wav.data.size() / _wav_frame_bytes(wav)


static func _wav_frame_bytes(wav: AudioStreamWAV) -> int:
	var bytes := 2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1
	return bytes * (2 if wav.stereo else 1)
