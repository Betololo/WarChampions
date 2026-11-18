extends Node

## Punchy, balanced procedural AudioStreamWAV synthesizer for War Champions:
## Dedicated 8-channel local priority SFX pool + 12-channel spatial/rate-limited world pool,
## crisp normalized combat waveforms, and comfortable Whistle Theme background loop.

const SAMPLE_RATE: int = 22050
const LOCAL_POOL_SIZE: int = 8
const WORLD_POOL_SIZE: int = 12
const BASE_SFX_DB: float = -4.5
const BASE_MUSIC_DB: float = -25.0
const WORLD_MAX_DISTANCE_M: float = 75.0
const WORLD_SFX_COOLDOWN_MS: int = 45
const FLAME_SFX_INTERVAL_MS: int = 220

var _clips: Dictionary = {}
var _music_player: AudioStreamPlayer
var _local_sfx_pool: Array[AudioStreamPlayer] = []
var _world_sfx_pool: Array[AudioStreamPlayer] = []
var _local_pool_idx: int = 0
var _world_pool_idx: int = 0
var _local_sfx_cooldowns: Dictionary = {} # clip_name -> last_ticks_msec
var _world_sfx_cooldowns: Dictionary = {} # clip_name -> last_ticks_msec
var _listener_pos: Vector3 = Vector3.ZERO
var _has_listener_pos: bool = false

var music_enabled: bool = true
var sfx_enabled: bool = true
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0


func _ready() -> void:
	_build_clips()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "WhistleThemePlayer"
	_music_player.stream = _clips.get("whistle_theme", null)
	add_child(_music_player)
	_apply_music_volume()

	for i in range(LOCAL_POOL_SIZE):
		var lp := AudioStreamPlayer.new()
		lp.name = "LocalSfx_%d" % i
		lp.volume_db = BASE_SFX_DB
		add_child(lp)
		_local_sfx_pool.append(lp)

	for i in range(WORLD_POOL_SIZE):
		var wp := AudioStreamPlayer.new()
		wp.name = "WorldSfx_%d" % i
		wp.volume_db = BASE_SFX_DB
		add_child(wp)
		_world_sfx_pool.append(wp)


func set_listener_position(pos: Vector3) -> void:
	_listener_pos = pos
	_has_listener_pos = true


func set_master_volume(vol: float) -> void:
	master_volume = clampf(vol, 0.0, 1.0)
	_apply_music_volume()


func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	_apply_music_volume()


func _apply_music_volume() -> void:
	if _music_player == null:
		return
	var eff: float = master_volume * music_volume
	if eff <= 0.001:
		_music_player.volume_db = -80.0
	else:
		_music_player.volume_db = BASE_MUSIC_DB + linear_to_db(eff)


func start_whistle_theme() -> void:
	if _music_player != null and music_enabled and not _music_player.playing and _music_player.stream != null:
		_apply_music_volume()
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


func _acquire_channel(pool: Array[AudioStreamPlayer], idx_is_local: bool) -> AudioStreamPlayer:
	for p in pool:
		if not p.playing:
			return p
	if idx_is_local:
		var p: AudioStreamPlayer = pool[_local_pool_idx]
		_local_pool_idx = (_local_pool_idx + 1) % pool.size()
		return p
	var wp: AudioStreamPlayer = pool[_world_pool_idx]
	_world_pool_idx = (_world_pool_idx + 1) % pool.size()
	return wp


func play_sfx(
	sfx_name: String,
	gain_db_offset: float = 0.0,
	is_local_priority: bool = true,
	world_pos: Vector3 = Vector3.ZERO,
	pitch_scale: float = 1.0
) -> void:
	if not sfx_enabled or not _clips.has(sfx_name):
		return
	var eff_sfx: float = master_volume * sfx_volume
	if eff_sfx <= 0.001:
		return

	var vol_offset_db: float = clampf(gain_db_offset, -30.0, 12.0)
	var dist_attenuation: float = 0.0

	var now_ms: int = Time.get_ticks_msec()
	if not is_local_priority:
		if _world_sfx_pool.is_empty():
			return
		var dist_m: float = _listener_pos.distance_to(world_pos) if _has_listener_pos else 0.0
		if dist_m > WORLD_MAX_DISTANCE_M:
			return
		var min_cd_ms: int = FLAME_SFX_INTERVAL_MS if sfx_name == "shoot_flame" else WORLD_SFX_COOLDOWN_MS
		var last_ms: int = int(_world_sfx_cooldowns.get(sfx_name, -10000))
		if now_ms - last_ms < min_cd_ms:
			return
		_world_sfx_cooldowns[sfx_name] = now_ms
		var t_dist: float = clampf((dist_m - 3.0) / (WORLD_MAX_DISTANCE_M - 3.0), 0.0, 1.0)
		dist_attenuation = lerpf(0.0, 24.0, pow(t_dist, 0.85))
	else:
		if _local_sfx_pool.is_empty():
			return
		if sfx_name == "shoot_flame":
			var last_local_ms: int = int(_local_sfx_cooldowns.get(sfx_name, -10000))
			if now_ms - last_local_ms < FLAME_SFX_INTERVAL_MS:
				return
			_local_sfx_cooldowns[sfx_name] = now_ms

	var player: AudioStreamPlayer = _acquire_channel(
		_local_sfx_pool if is_local_priority else _world_sfx_pool,
		is_local_priority
	)
	player.stream = _clips[sfx_name]
	player.pitch_scale = clampf(pitch_scale, 0.72, 1.35)
	player.volume_db = BASE_SFX_DB + linear_to_db(eff_sfx) + vol_offset_db - dist_attenuation
	player.play()


func play_weapon_fire(
	weapon_kind: int,
	distance_m: float = 0.0,
	is_local_priority: bool = true,
	world_pos: Vector3 = Vector3.ZERO
) -> void:
	var clip: String = "shoot_smg"
	var p_jitter: float = randf_range(0.96, 1.04)
	var gain_off: float = 0.0
	match weapon_kind:
		0: # SMG
			clip = "shoot_smg"
		1: # Heavy MG
			clip = "shoot_mg"
			p_jitter = randf_range(0.94, 1.02)
			gain_off = 0.5
		2: # Shotgun
			clip = "shoot_shotgun"
			gain_off = 1.0
		3: # Pistol
			clip = "shoot_pistol"
		4: # Sniper
			clip = "shoot_sniper"
			gain_off = 1.2
		5: # Knife
			clip = "knife"
		6: # Bazooka
			clip = "shoot_bazooka"
			gain_off = 1.0
		7: # TNT
			clip = "shot_tnt"
		8: # Flamethrower
			clip = "shoot_flame"
			p_jitter = randf_range(0.92, 1.08)
		9: # Grenade Launcher
			clip = "shoot_launcher"
			gain_off = 0.8
		10: # Stick Grenade
			clip = "stick_grenade"
			gain_off = 0.6
	var effective_pos: Vector3 = world_pos
	if not is_local_priority and world_pos == Vector3.ZERO and distance_m > 0.0:
		effective_pos = (_listener_pos if _has_listener_pos else Vector3.ZERO) + Vector3(distance_m, 0.0, 0.0)
	play_sfx(clip, gain_off, is_local_priority, effective_pos, p_jitter)


func play_faction_emote(team: int, is_local_priority: bool = true, world_pos: Vector3 = Vector3.ZERO) -> void:
	var pitch: float = randf_range(1.04, 1.14) if team == 0 else randf_range(0.84, 0.94)
	play_sfx("emote_gibberish", -2.0, is_local_priority, world_pos, pitch)


func _build_clips() -> void:
	_clips["whistle_theme"] = _synth_whistle_theme()

	# Punchy weapon fire signatures normalized to 0.78..0.92 peak
	_clips["shoot_smg"] = _synth_gunshot(0.088, 390.0, 92.0, 0.44, 0.86, 2.3, 0.42, 0.55)
	_clips["shoot_mg"] = _synth_gunshot(0.108, 250.0, 66.0, 0.48, 0.88, 1.9, 0.36, 0.65)
	_clips["shoot_shotgun"] = _synth_gunshot(0.220, 220.0, 42.0, 0.64, 0.92, 1.7, 0.34, 0.78)
	_clips["shoot_pistol"] = _synth_gunshot(0.095, 480.0, 115.0, 0.38, 0.84, 2.4, 0.44, 0.58)
	_clips["shoot_sniper"] = _synth_gunshot(0.260, 640.0, 62.0, 0.52, 0.92, 1.85, 0.46, 0.82)
	_clips["shoot_bazooka"] = _synth_gunshot(0.320, 165.0, 42.0, 0.62, 0.90, 1.4, 0.28, 0.70)
	_clips["shot_tnt"] = _synth_tone_burst_norm(0.11, 240.0, 110.0, 0.80)
	_clips["knife"] = _synth_gunshot(0.095, 680.0, 210.0, 0.42, 0.80, 2.2, 0.48, 0.32)
	_clips["shoot_flame"] = _synth_flame_roar(0.42, 0.72)
	_clips["shoot_launcher"] = _synth_gunshot(0.240, 185.0, 48.0, 0.58, 0.90, 1.5, 0.28, 0.65)
	_clips["stick_grenade"] = _synth_gunshot(0.180, 320.0, 72.0, 0.55, 0.88, 1.8, 0.36, 0.68)

	# Combat, feedback & UI clips normalized to 0.78..0.92 peak
	_clips["explosion"] = _synth_explosion(0.48, 0.92)
	_clips["hit"] = _synth_tone_burst_norm(0.075, 820.0, 1060.0, 0.82, 0.25)
	_clips["crit"] = _synth_crit_chime(0.12, 0.88)
	_clips["heal"] = _synth_arpeggio(PackedFloat32Array([440.0, 554.37, 659.25]), 0.19, 0.80)
	_clips["reload"] = _synth_reload_clicks(0.13, 0.82)
	_clips["scope_in"] = _synth_tone_burst_norm(0.06, 620.0, 880.0, 0.78)
	_clips["parachute"] = _synth_parachute_snap(0.22, 0.82)
	_clips["level_up"] = _synth_arpeggio(PackedFloat32Array([523.25, 659.25, 783.99, 1046.50]), 0.34, 0.86)
	_clips["click"] = _synth_tone_burst_norm(0.042, 960.0, 420.0, 0.78, 0.22)
	_clips["emote_gibberish"] = _synth_gibberish(0.34)

	# Backwards-compatible aliases for legacy clip names
	_clips["shot_smg"] = _clips["shoot_smg"]
	_clips["shot_mg"] = _clips["shoot_mg"]
	_clips["shot_shotgun"] = _clips["shoot_shotgun"]
	_clips["shot_pistol"] = _clips["shoot_pistol"]
	_clips["shot_sniper"] = _clips["shoot_sniper"]
	_clips["shot_bazooka"] = _clips["shoot_bazooka"]
	_clips["shot_knife"] = _clips["knife"]
	_clips["hit_ding"] = _clips["hit"]
	_clips["skill_cast"] = _clips["heal"]


func _lowpass_smooth(samples: PackedFloat32Array, alpha: float = 0.32) -> void:
	var prev: float = 0.0
	for i in range(samples.size()):
		prev = prev + alpha * (samples[i] - prev)
		samples[i] = prev


func _normalize_peak(samples: PackedFloat32Array, target_peak: float) -> void:
	var max_abs: float = 0.0
	for i in range(samples.size()):
		var a: float = absf(samples[i])
		if a > max_abs:
			max_abs = a
	if max_abs <= 0.00001:
		return
	var scale_f: float = clampf(target_peak, 0.78, 0.92) / max_abs
	for i in range(samples.size()):
		samples[i] = clampf(samples[i] * scale_f, -0.98, 0.98)


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


func _synth_flame_roar(dur_s: float = 0.42, peak: float = 0.72) -> AudioStreamWAV:
	var n: int = maxi(1, int(dur_s * float(SAMPLE_RATE)))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var lp: float = 0.0
	var hp_prev: float = 0.0
	var atk_s: float = 0.09
	var rel_s: float = 0.14
	for i in range(n):
		var t_sec: float = float(i) / float(SAMPLE_RATE)
		var rem_s: float = maxf(0.0, dur_s - t_sec)
		var atk: float = sin(clampf(t_sec / atk_s, 0.0, 1.0) * PI * 0.5)
		var rel: float = sin(clampf(rem_s / rel_s, 0.0, 1.0) * PI * 0.5)
		var env: float = atk * rel

		# Pink-weighted band-filtered noise for smooth pressurized gas roar
		var white: float = randf_range(-1.0, 1.0)
		b0 = 0.997 * b0 + white * 0.029
		b1 = 0.985 * b1 + white * 0.032
		b2 = 0.950 * b2 + white * 0.048
		var pink: float = (b0 + b1 + b2 + white * 0.18) * 1.4
		lp += 0.24 * (pink - lp)
		hp_prev += 0.015 * (lp - hp_prev)
		var band_noise: float = lp - hp_prev

		# Warm low flame rumble (~90..150 Hz subtle LFO roar)
		var lfo: float = 0.5 + 0.5 * sin(TAU * 11.5 * t_sec)
		var rumble_freq: float = lerpf(95.0, 145.0, lfo)
		phase += TAU * rumble_freq / float(SAMPLE_RATE)
		var rumble: float = sin(phase) * 0.24 + sin(phase * 0.5) * 0.14
		var turb: float = 0.85 + 0.15 * sin(TAU * 7.5 * t_sec)

		buf[i] = tanh((band_noise * 0.82 + rumble) * turb * 1.25) * env

	_lowpass_smooth(buf, 0.28)
	var max_abs: float = 0.0
	for i in range(n):
		var a: float = absf(buf[i])
		if a > max_abs:
			max_abs = a
	if max_abs > 0.00001:
		var scale_f: float = clampf(peak, 0.25, 0.92) / max_abs
		for i in range(n):
			buf[i] = clampf(buf[i] * scale_f, -0.98, 0.98)
	return _make_wav(buf, false)


func _synth_gunshot(
	duration: float,
	f_start: float,
	f_end: float,
	noise_mix: float,
	target_peak: float,
	decay_pow: float,
	smooth_alpha: float,
	crack_strength: float
) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var crack_samples: int = maxi(12, int(0.012 * float(SAMPLE_RATE)))
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(f_start, f_end, pow(t, 0.55))
		phase += TAU * freq / float(SAMPLE_RATE)
		var attack: float = minf(1.0, float(i) / float(maxi(1, int(0.002 * float(SAMPLE_RATE)))))
		var env: float = attack * pow(1.0 - t, decay_pow)
		var body: float = sin(phase) * 0.75 + sin(phase * 0.5) * 0.30 + sin(phase * 2.1) * 0.18
		var noise: float = randf_range(-1.0, 1.0) * noise_mix
		var crack: float = 0.0
		if i < crack_samples:
			var ct: float = 1.0 - float(i) / float(crack_samples)
			crack = randf_range(-1.0, 1.0) * crack_strength * ct
		# Soft saturate before normalization for warm analog punch without harsh clipping
		buf[i] = tanh((body * (1.0 - noise_mix * 0.45) + noise) * env * 1.45 + crack)
	_lowpass_smooth(buf, smooth_alpha)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_explosion(duration: float, target_peak: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(135.0, 28.0, pow(t, 0.45))
		phase += TAU * freq / float(SAMPLE_RATE)
		var attack: float = minf(1.0, float(i) / float(maxi(1, int(0.005 * float(SAMPLE_RATE)))))
		var env: float = attack * pow(1.0 - t, 1.45)
		var sub: float = sin(phase) * 0.85 + sin(phase * 0.5) * 0.45
		var rumble: float = randf_range(-1.0, 1.0) * 0.75
		buf[i] = tanh((sub + rumble) * env * 1.4)
	_lowpass_smooth(buf, 0.24)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_tone_burst_norm(duration: float, f_start: float, f_end: float, target_peak: float, overtone: float = 0.15) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = lerpf(f_start, f_end, t)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = sin(clampf(t * 12.0, 0.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.2)
		buf[i] = (sin(phase) + sin(phase * 2.0) * overtone) * env
	_lowpass_smooth(buf, 0.42)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_crit_chime(duration: float, target_peak: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var freq: float = 1120.0 if t < 0.38 else 1480.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = sin(clampf(t * 18.0, 0.0, 1.0) * PI * 0.5) * pow(1.0 - t, 1.1)
		buf[i] = (sin(phase) * 0.78 + sin(phase * 2.0) * 0.28) * env
	_lowpass_smooth(buf, 0.48)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_arpeggio(freqs: PackedFloat32Array, duration: float, target_peak: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	var note_count: int = maxi(1, freqs.size())
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		var idx: int = mini(note_count - 1, int(t * float(note_count)))
		var local_t: float = fmod(t * float(note_count), 1.0)
		phase += TAU * freqs[idx] / float(SAMPLE_RATE)
		var env: float = sin(clampf(local_t * 8.0, 0.0, 1.0) * PI * 0.5) * (1.0 - t * 0.65)
		buf[i] = (sin(phase) * 0.78 + sin(phase * 1.5) * 0.22) * env
	_lowpass_smooth(buf, 0.40)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_reload_clicks(duration: float, target_peak: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var p1: float = 0.0
	var p2: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		p1 += TAU * 540.0 / float(SAMPLE_RATE)
		p2 += TAU * 860.0 / float(SAMPLE_RATE)
		var c1: float = exp(-pow((t - 0.16) / 0.07, 2.0)) * (sin(p1) * 0.6 + randf_range(-0.4, 0.4))
		var c2: float = exp(-pow((t - 0.70) / 0.08, 2.0)) * (sin(p2) * 0.6 + randf_range(-0.45, 0.45))
		buf[i] = c1 + c2
	_lowpass_smooth(buf, 0.45)
	_normalize_peak(buf, target_peak)
	return _make_wav(buf, false)


func _synth_parachute_snap(duration: float, target_peak: float) -> AudioStreamWAV:
	var n: int = int(duration * float(SAMPLE_RATE))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(maxi(1, n))
		phase += TAU * lerpf(320.0, 95.0, t) / float(SAMPLE_RATE)
		var snap: float = exp(-t * 18.0) * sin(phase) * 0.9
		var wind: float = sin(clampf(t * 5.0, 0.0, 1.0) * PI * 0.5) * (1.0 - t) * randf_range(-0.7, 0.7)
		buf[i] = snap + wind
	_lowpass_smooth(buf, 0.30)
	_normalize_peak(buf, target_peak)
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
		buf[i] = wave * syllable * (1.0 - t * 0.6)
	_lowpass_smooth(buf, 0.30)
	_normalize_peak(buf, 0.78)
	return _make_wav(buf, false)
