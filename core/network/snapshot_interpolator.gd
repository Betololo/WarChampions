class_name SnapshotInterpolator
extends RefCounted

## Render remote entities 100 ms in the past (~3 snapshots at 30 Hz).
const INTERPOLATION_OFFSET_MS: float = 100.0
const MAX_SNAPSHOTS: int = 32


class SnapshotSample extends RefCounted:
	var server_tick: int = 0
	var timestamp_ms: float = 0.0
	var position: Vector3 = Vector3.ZERO
	var rotation: Quaternion = Quaternion.IDENTITY
	var velocity: Vector3 = Vector3.ZERO
	var aim_yaw: float = 0.0
	var aim_pitch: float = 0.0
	var turret_yaw: float = 0.0
	var flags: int = 0


var _buffer: Array[SnapshotSample] = []
var _reusable_sample: SnapshotSample = SnapshotSample.new()


func push_snapshot(
	server_tick: int,
	timestamp_ms: float,
	pos: Vector3,
	rot: Quaternion,
	vel: Vector3 = Vector3.ZERO,
	aim_yaw: float = 0.0,
	aim_pitch: float = 0.0,
	turret_yaw: float = 0.0,
	flags: int = 0
) -> void:
	if not _buffer.is_empty():
		var latest: SnapshotSample = _buffer[_buffer.size() - 1]
		if server_tick <= latest.server_tick:
			return

	var s: SnapshotSample
	if _buffer.size() >= MAX_SNAPSHOTS:
		s = _buffer.pop_front() as SnapshotSample
	else:
		s = SnapshotSample.new()
	s.server_tick = server_tick
	s.timestamp_ms = timestamp_ms
	s.position = pos
	s.rotation = rot.normalized()
	s.velocity = vel
	s.aim_yaw = aim_yaw
	s.aim_pitch = aim_pitch
	s.turret_yaw = turret_yaw
	s.flags = flags
	_buffer.append(s)


func sample(server_clock_ms: float) -> SnapshotSample:
	if _buffer.is_empty():
		return null

	var render_time: float = server_clock_ms - INTERPOLATION_OFFSET_MS

	if render_time <= _buffer[0].timestamp_ms:
		return _buffer[0]

	var last_idx: int = _buffer.size() - 1
	if render_time >= _buffer[last_idx].timestamp_ms:
		return _buffer[last_idx]

	for i in range(last_idx):
		var s0: SnapshotSample = _buffer[i]
		var s1: SnapshotSample = _buffer[i + 1]
		if s0.timestamp_ms <= render_time and render_time <= s1.timestamp_ms:
			var span: float = maxf(s1.timestamp_ms - s0.timestamp_ms, 0.001)
			var alpha: float = clampf((render_time - s0.timestamp_ms) / span, 0.0, 1.0)
			var out: SnapshotSample = _reusable_sample
			out.server_tick = int(lerpf(float(s0.server_tick), float(s1.server_tick), alpha))
			out.timestamp_ms = render_time
			out.position = s0.position.lerp(s1.position, alpha)
			out.rotation = s0.rotation.slerp(s1.rotation, alpha)
			out.velocity = s0.velocity.lerp(s1.velocity, alpha)
			out.aim_yaw = lerp_angle(s0.aim_yaw, s1.aim_yaw, alpha)
			out.aim_pitch = lerpf(s0.aim_pitch, s1.aim_pitch, alpha)
			out.turret_yaw = lerp_angle(s0.turret_yaw, s1.turret_yaw, alpha)
			out.flags = s1.flags if alpha >= 0.5 else s0.flags
			return out

	return _buffer[last_idx]


func get_latest() -> SnapshotSample:
	if _buffer.is_empty():
		return null
	return _buffer[_buffer.size() - 1]


func clear() -> void:
	_buffer.clear()
