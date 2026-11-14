extends Node

## Warm, balanced procedural AudioStreamWAV synthesizer for War Champions:
## Mellow Whistle Theme loop, soft-transient weapon SFX, hit dings, explosions, and faction emotes.

const SAMPLE_RATE: int = 22050

var _clips: Dictionary = {}
var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_idx: int = 0
var music_enabled: bool = true
var sfx_enabled: bool = true


func _ready() -> void:
	if DisplayServer.get_name().contains("headless"):
		return
	_build_clips()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "WhistleThemePlayer"
	_music_player.volume_db = -26.0
	_music_player.stream = _clips.get("whistle_theme", null)
	add_child(_music_player)

	for i in range(16):
		var p := AudioStreamPlayer.new()
		p.volume_db = -19.0
		add_child(p)
		_sfx_pool.append(p)


func start_whistle_theme() -> void:
	if _music_player != null and music_enabled and not _music_player.playing and _music_player.stream != null:
		_music_player.play()


func stop_whistle_theme() -> void:
	if _music_player != null and _music_player.playing:
		_music_player.stop()


func toggle_music() -> bool:
	music_enabled = not music_enabled
	if music_enabled:
		start_whistle_theme()
	else:
		stop_whistle_theme()
	return music_enabled


func toggle_sfx() -> bool:
	sfx_enabled = not sfx_enabled
	return sfx_enabled


func play_sfx(clip_name: String, pitch_scale: float = 1.0, distance_m: float = 0.0) -> void:
	if not sfx_enabled or _sfx_pool.is_empty() or not _clips.has(clip_name):
		return
	if distance_m > 68.0:
		return
	var player: AudioStreamPlayer = _sfx_pool[_pool_idx]
	_pool_idx = (_pool_idx + 1) % _sfx_pool.size()
	player.stream = _clips[clip_name]
	player.pitch_scale = clampf(pitch_scale, 0.72, 1.35)
	var base_db: float = -16.5 if clip_name == "explosion" else (-21.0 if clip_name in ["scope_in", "reload"] else -18.5)
	var dist_attenuation: float = clampf(distance_m * 0.28, 0.0, 18.0) if distance_m > 2.0 else 0.0
	player.volume_db = base_db - dist_attenuation
	player.play()


func play_weapon_fire(weapon_kind: int, distance_m: float = 0.0) -> void:
	var clip: String = "shot_smg"
	var p_jitter: float = randf_range(0.96, 1.05)
	match weapon_kind:
		0: # SMG
			clip = "shot_smg"
		1: # Heavy MG
			clip = "shot_mg"
			p_jitter = randf_range(0.93, 1.02)
		2: # Shotgun
			clip = "shot_shotgun"
		3: # Pistol
			clip = "shot_pistol"
		4: # Sniper
			clip = "shot_sniper"
		5: # Knife
			clip = "shot_knife"
		6: # Bazooka
			clip = "shot_bazooka"
		7: # TNT
			clip = "shot_tnt"
	play_sfx(clip, p_jitter, distance_m)


func play_faction_emote(team: int) -> void:
	var pitch: float = randf_range(1.04, 1.15) if team == 0 else randf_range(0.82, 0.94)
	play_sfx("emote_gibberish", pitch)


func _build_clips() -> void:
	_clips["whistle_theme"] = _synth_whistle_theme()
	_clips["shot_smg"] = _synth_pop_noise(0.070, 340.0, 95.0, 0.44, 0.34, 2.0, 0.36)
	_clips["shot_mg"] = _synth_pop_noise(0.090, 230.0, 72.0, 0.50, 0.40, 1.8, 0.32)
	_clips["shot_shotgun"] = _synth_pop_noise(0.18, 280.0, 58.0, 0.60, 0.58, 1.9, 0.34)
	_clips["shot_pistol"] = _synth_pop_noise(0.085, 420.0, 110.0, 0.46, 0.32, 2.2, 0.38)
	_clips["shot_sniper"] = _synth_pop_noise(0.22, 620.0, 76.0, 0.62, 0.45, 2.1, 0.40)
	_clips["shot_bazooka"] = _synth_pop_noise(0.28, 175.0, 48.0, 0.58, 0.52, 1.5, 0.25)
	_clips["shot_tnt"] = _synth_tone_burst(0.11, 240.0, 110.0, 0.26)
	_clips["shot_knife"] = _synth_pop_noise(0.095, 520.0, 180.0, 0.32, 0.22, 2.2, 0.40)
	_clips["reload"] = _synth_tone_burst(0.08, 380.0, 520.0, 0.24)
	_clips["scope_in"] = _synth_tone_burst(0.06, 620.0, 880.0, 0.22)
	_clips["explosion"] = _synth_pop_noise(0.40, 125.0, 32.0, 0.58, 0.42, 1.8, 0.26)
	_clips["hit_ding"] = _synth_tone_burst(0.075, 760.0, 920.0, 0.28)
	_clips["skill_cast"] = _synth_tone_burst(0.15, 420.0, 640.0, 0.30)
	_clips["emote_gibberish"] = _synth_gibberish(0.34)


func _lowpass_smooth(samples: PackedFloat32Array, alpha: float = 0.32) -> void:
	var prev: float = 0.0
	for i in range(samples.size()):
		prev = prev + alpha * (samples[i] - prev)
		samples[i] = prev


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
	# Warm, relaxed lower-octave march whistle with breathing pauses (non-piercing)
	var notes: Array[Vector2] = [
		Vector2(261.63, 0.24), Vector2(329.63, 0.24), Vector2(392.00, 0.28), Vector2(329.63, 0.20),
		Vector2(440.00, 0.28), Vector2(392.00, 0.24), Vector2(329.63, 0.38), Vector2(0.0, 0.24),
		Vector2(293.66, 0.24), Vector2(329.63, 0.24), Vector2(392.00, 0.24), Vector2(261.63, 0.40),
		Vector2(0.0, 0.35),
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
			if n.x <= 1.0:
				buf[cursor] = 0.0
			else:
				var t_norm: float = float(i) / float(maxi(1, count))
				var env: float = sin(clampf(t_norm * 4.5, 0.0, 1.0) * PI * 0.5) * (1.0 - maxf(0.0, (t_norm - 0.70) / 0.30))
				var vib: float = sin(float(cursor) / float(SAMPLE_RATE) * 18.0) * 2.2
				phase += TAU * (n.x + vib) / float(SAMPLE_RATE)
				buf[cursor] = (sin(phase) * 0.14 + sin(phase * 0.5) * 0.06) * env
			cursor += 1
	_lowpass_smooth(buf, 0.25)
	return _make_wav(buf, true)


func _synth_pop_noise(duration: float, f_start: float, f_end: float, amp: float, noise_mix: float = 0.28, decay_pow: float = 2.1, smooth_alpha: float = 0.28) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = sin(clampf(t * 14.0, 0.0, 1.0) * PI * 0.5) * pow(1.0 - t, decay_pow)
		var noise: float = randf_range(-1.0, 1.0) * noise_mix
		buf[i] = clampf((sin(phase) * (1.0 - noise_mix * 0.65) + noise) * env * amp, -1.0, 1.0)
	_lowpass_smooth(buf, smooth_alpha)
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
		var env: float = sin(clampf(t * 10.0, 0.0, 1.0) * PI * 0.5) * (1.0 - t)
		buf[i] = sin(phase) * env * amp
	_lowpass_smooth(buf, 0.35)
	return _make_wav(buf, false)


func _synth_gibberish(duration: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var syllable: float = absf(sin(t * PI * 3.5))
		var freq: float = 175.0 + sin(t * 20.0) * 42.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var wave: float = sin(phase) * 0.65 + sin(phase * 1.5) * 0.15
		buf[i] = wave * syllable * (1.0 - t * 0.6) * 0.28
	_lowpass_smooth(buf, 0.28)
	return _make_wav(buf, false)
