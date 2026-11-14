extends Node

## Procedural cartoon AudioStreamWAV synthesizer for War Champions:
## Whistle Theme loop, stylized gun pops, explosions, hit dings, parachute whoosh, and faction emotes.

const SAMPLE_RATE: int = 22050

var _clips: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var music_enabled: bool = true


func _ready() -> void:
	if DisplayServer.get_name().contains("headless"):
		return
	_build_clips()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "WhistleThemePlayer"
	_music_player.volume_db = -12.0
	_music_player.stream = _clips.get("whistle_theme", null)
	add_child(_music_player)

	for i in range(10):
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_sfx_pool.append(p)


func start_whistle_theme() -> void:
	if _music_player != null and music_enabled and not _music_player.playing and _music_player.stream != null:
		_music_player.play()


func stop_whistle_theme() -> void:
	if _music_player != null and _music_player.playing:
		_music_player.stop()


func play_sfx(clip_name: String, pitch_scale: float = 1.0) -> void:
	if _sfx_pool.is_empty() or not _clips.has(clip_name):
		return
	var player: AudioStreamPlayer = _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _sfx_pool.size()
	player.stream = _clips[clip_name]
	player.pitch_scale = clampf(pitch_scale, 0.65, 1.5)
	player.play()


func play_faction_emote(team: int) -> void:
	# Royal: higher comical British cadence; National: lower gruff Germanic cadence
	var pitch: float = randf_range(1.06, 1.22) if team == 0 else randf_range(0.78, 0.92)
	play_sfx("emote_gibberish", pitch)


func _build_clips() -> void:
	_clips["whistle_theme"] = _synth_whistle_theme()
	_clips["shot_smg"] = _synth_pop_noise(0.08, 420.0, 140.0, 0.55)
	_clips["shot_sniper"] = _synth_pop_noise(0.20, 720.0, 110.0, 0.85)
	_clips["explosion"] = _synth_pop_noise(0.45, 160.0, 38.0, 0.95)
	_clips["hit_ding"] = _synth_tone_burst(0.09, 1080.0, 1340.0, 0.45)
	_clips["skill_cast"] = _synth_tone_burst(0.18, 520.0, 880.0, 0.50)
	_clips["emote_gibberish"] = _synth_gibberish(0.42)


func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s: int = clampi(int(roundf(samples[i] * 32767.0)), -32768, 32767)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	wav.loop_end = samples.size()
	return wav


func _synth_whistle_theme() -> AudioStreamWAV:
	# Jaunty heroic march whistle melody in C major / A minor bounce
	var notes: Array[Vector2] = [
		Vector2(523.25, 0.20), Vector2(659.25, 0.20), Vector2(783.99, 0.25), Vector2(659.25, 0.15),
		Vector2(880.00, 0.25), Vector2(783.99, 0.20), Vector2(659.25, 0.35),
		Vector2(587.33, 0.20), Vector2(659.25, 0.20), Vector2(783.99, 0.20), Vector2(523.25, 0.35),
		Vector2(587.33, 0.18), Vector2(659.25, 0.18), Vector2(523.25, 0.42),
	]
	var total_sec: float = 0.0
	for n in notes:
		total_sec += n.y
	var total_samples: int = int(total_sec * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(total_samples)

	var cursor: int = 0
	var phase: float = 0.0
	for n in notes:
		var count: int = int(n.y * float(SAMPLE_RATE))
		for i in range(count):
			if cursor >= total_samples:
				break
			var t_norm: float = float(i) / float(maxi(1, count))
			var env: float = sin(clampf(t_norm * 6.0, 0.0, 1.0) * PI * 0.5) * (1.0 - maxf(0.0, (t_norm - 0.78) / 0.22))
			var vib: float = sin(float(cursor) / float(SAMPLE_RATE) * 32.0) * 8.0
			phase += TAU * (n.x + vib) / float(SAMPLE_RATE)
			# Pure whistle sine + subtle airy harmonic
			buf[cursor] = (sin(phase) * 0.22 + sin(phase * 2.0) * 0.03) * env
			cursor += 1
	return _make_wav(buf, true)


func _synth_pop_noise(duration: float, f_start: float, f_end: float, amp: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = pow(1.0 - t, 1.8)
		var noise: float = randf_range(-1.0, 1.0) * 0.45
		buf[i] = clampf((sin(phase) * 0.65 + noise) * env * amp, -1.0, 1.0)
	return _make_wav(buf, false)


func _synth_tone_burst(duration: float, f_start: float, f_end: float, amp: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		buf[i] = sin(phase) * (1.0 - t) * amp
	return _make_wav(buf, false)


func _synth_gibberish(duration: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var syllable: float = absf(sin(t * PI * 4.0))
		var freq: float = 190.0 + sin(t * 28.0) * 55.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var wave: float = sin(phase) * 0.55 + sin(phase * 2.0) * 0.25
		buf[i] = wave * syllable * (1.0 - t * 0.5) * 0.45
	return _make_wav(buf, false)
