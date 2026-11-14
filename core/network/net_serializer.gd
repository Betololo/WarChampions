class_name NetSerializer
extends RefCounted

## Exact wire size in bytes of a packed InputCmd packet.
const INPUT_CMD_BYTES: int = 15

## Compact entity snapshot flags (16-bit mask).
const SNAP_GROUNDED: int = 1 << 0
const SNAP_PARACHUTING: int = 1 << 1
const SNAP_CROUCHING: int = 1 << 2
const SNAP_DEFEATED: int = 1 << 3
const SNAP_STEALTHED: int = 1 << 4
const SNAP_SHIELDED: int = 1 << 5
const SNAP_BURNING: int = 1 << 6
const SNAP_POISONED: int = 1 << 7
const SNAP_SPEED_BOOST: int = 1 << 8
const SNAP_SCOPING: int = 1 << 9
const SNAP_FIRING: int = 1 << 10
const SNAP_SIXTH_SENSE: int = 1 << 11
const SNAP_EAT_GRENADES: int = 1 << 12
const SNAP_EMOTING: int = 1 << 13


static func _pack_angle_u16(radians: float) -> int:
	var wrapped: float = fposmod(radians, TAU)
	var normalized: float = clampf(wrapped / TAU, 0.0, 0.99998474)
	return int(roundf(normalized * 65535.0))


static func _unpack_angle_u16(encoded: int) -> float:
	return (float(encoded) / 65535.0) * TAU


static func _unwrap_signed_angle(radians: float) -> float:
	var a: float = fposmod(radians + PI, TAU)
	if a < 0.0:
		a += TAU
	return a - PI


## Packs an InputCmd into exactly 15 bytes:
## u32 tick (4B) + s8 move_x (1B) + s8 move_z (1B) + u16 yaw (2B) + u16 pitch (2B)
## + u16 buttons (2B) + u8 weapon_slot (1B) + u16 view_interp_tick_delta (2B) = 15 bytes.
static func pack_input_cmd(cmd: InputCmd) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.resize(INPUT_CMD_BYTES)
	buf.seek(0)
	buf.put_u32(cmd.tick)
	buf.put_8(clampi(int(roundf(clampf(cmd.move_dir.x, -1.0, 1.0) * 127.0)), -127, 127))
	buf.put_8(clampi(int(roundf(clampf(cmd.move_dir.y, -1.0, 1.0) * 127.0)), -127, 127))
	buf.put_u16(_pack_angle_u16(cmd.aim_yaw))
	buf.put_u16(_pack_angle_u16(cmd.aim_pitch))
	buf.put_u16(cmd.buttons & 0xFFFF)
	buf.put_u8(cmd.selected_weapon_slot & 0xFF)
	buf.put_u16(clampi(cmd.view_interp_tick_delta, 0, 65535))
	return buf.data_array


static func unpack_input_cmd(bytes: PackedByteArray) -> InputCmd:
	var cmd := InputCmd.new()
	if bytes.size() < INPUT_CMD_BYTES:
		return cmd
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(0)
	cmd.tick = buf.get_u32()
	var mx: int = buf.get_8()
	var mz: int = buf.get_8()
	cmd.move_dir = Vector2(float(mx) / 127.0, float(mz) / 127.0)
	if cmd.move_dir.length() > 1.0:
		cmd.move_dir = cmd.move_dir.normalized()
	cmd.aim_yaw = _unwrap_signed_angle(_unpack_angle_u16(buf.get_u16()))
	cmd.aim_pitch = clampf(_unwrap_signed_angle(_unpack_angle_u16(buf.get_u16())), -1.45, 1.45)
	cmd.buttons = buf.get_u16()
	cmd.selected_weapon_slot = buf.get_u8()
	cmd.view_interp_tick_delta = buf.get_u16()
	return cmd


static func pack_authoritative_state(
	ack_tick: int,
	pos: Vector3,
	vel: Vector3,
	flags: int,
	hp: int,
	shield: int,
	vehicle_id: int,
	seat_idx: int,
	knockback_seq: int
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(ack_tick)
	buf.put_float(pos.x)
	buf.put_float(pos.y)
	buf.put_float(pos.z)
	buf.put_float(vel.x)
	buf.put_float(vel.y)
	buf.put_float(vel.z)
	buf.put_u16(flags & 0xFFFF)
	buf.put_u16(clampi(hp, 0, 65535))
	buf.put_u16(clampi(shield, 0, 65535))
	buf.put_16(clampi(vehicle_id, -1, 32767))
	buf.put_8(clampi(seat_idx, -1, 127))
	buf.put_u8(knockback_seq & 0xFF)
	return buf.data_array


static func unpack_authoritative_state(bytes: PackedByteArray) -> Dictionary:
	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(0)
	var ack_tick: int = buf.get_u32()
	var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
	var vel := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
	var flags: int = buf.get_u16()
	var hp: int = buf.get_u16()
	var shield: int = buf.get_u16()
	var vehicle_id: int = buf.get_16()
	var seat_idx: int = buf.get_8()
	var knockback_seq: int = buf.get_u8()
	return {
		"ack_tick": ack_tick,
		"pos": pos,
		"vel": vel,
		"flags": flags,
		"hp": hp,
		"shield": shield,
		"vehicle_id": vehicle_id,
		"seat_idx": seat_idx,
		"knockback_seq": knockback_seq,
	}


static func _put_vec3_s16_vel(buf: StreamPeerBuffer, v: Vector3) -> void:
	buf.put_16(clampi(int(roundf(v.x * 100.0)), -32767, 32767))
	buf.put_16(clampi(int(roundf(v.y * 100.0)), -32767, 32767))
	buf.put_16(clampi(int(roundf(v.z * 100.0)), -32767, 32767))


static func _get_vec3_s16_vel(buf: StreamPeerBuffer) -> Vector3:
	var vx: float = float(buf.get_16()) / 100.0
	var vy: float = float(buf.get_16()) / 100.0
	var vz: float = float(buf.get_16()) / 100.0
	return Vector3(vx, vy, vz)


## Packs a full WorldSnapshot for up to 24 heroes + active vehicles + 4 flags + tickets.
static func pack_world_snapshot(
	server_tick: int,
	server_time_ms: int,
	royal_tickets: int,
	national_tickets: int,
	heroes: Array[Dictionary],
	vehicles: Array[Dictionary],
	flags_state: Array[Dictionary]
) -> PackedByteArray:
	var buf := StreamPeerBuffer.new()
	buf.put_u32(server_tick)
	buf.put_u32(server_time_ms)
	buf.put_u16(clampi(royal_tickets, 0, 65535))
	buf.put_u16(clampi(national_tickets, 0, 65535))

	var hero_count: int = mini(heroes.size(), 32)
	buf.put_u8(hero_count)
	for i in range(hero_count):
		var h: Dictionary = heroes[i]
		buf.put_u16(int(h.get("id", 0)) & 0xFFFF)
		var meta: int = (int(h.get("team", 0)) & 0x3) | ((int(h.get("class_id", 0)) & 0x3) << 2) | ((int(h.get("weapon_slot", 0)) & 0x3) << 4)
		buf.put_u8(meta)
		buf.put_u16(int(h.get("flags", 0)) & 0xFFFF)
		var pos: Vector3 = h.get("pos", Vector3.ZERO)
		buf.put_float(pos.x)
		buf.put_float(pos.y)
		buf.put_float(pos.z)
		_put_vec3_s16_vel(buf, h.get("vel", Vector3.ZERO))
		buf.put_u16(_pack_angle_u16(float(h.get("yaw", 0.0))))
		buf.put_u16(_pack_angle_u16(float(h.get("pitch", 0.0))))
		buf.put_u16(clampi(int(h.get("hp", 0)), 0, 65535))
		buf.put_u16(clampi(int(h.get("shield", 0)), 0, 65535))
		buf.put_16(clampi(int(h.get("vehicle_id", -1)), -1, 32767))
		buf.put_8(clampi(int(h.get("seat_idx", -1)), -1, 127))

	var veh_count: int = mini(vehicles.size(), 32)
	buf.put_u8(veh_count)
	for i in range(veh_count):
		var v: Dictionary = vehicles[i]
		buf.put_u16(int(v.get("id", 0)) & 0xFFFF)
		buf.put_u8(int(v.get("type", 0)) & 0xFF)
		var pos: Vector3 = v.get("pos", Vector3.ZERO)
		buf.put_float(pos.x)
		buf.put_float(pos.y)
		buf.put_float(pos.z)
		var rot: Quaternion = v.get("rot", Quaternion.IDENTITY)
		buf.put_float(rot.x)
		buf.put_float(rot.y)
		buf.put_float(rot.z)
		buf.put_float(rot.w)
		_put_vec3_s16_vel(buf, v.get("vel", Vector3.ZERO))
		buf.put_u16(_pack_angle_u16(float(v.get("turret_yaw", 0.0))))
		buf.put_u16(clampi(int(v.get("hp", 0)), 0, 65535))

	var flag_count: int = mini(flags_state.size(), 16)
	buf.put_u8(flag_count)
	for i in range(flag_count):
		var f: Dictionary = flags_state[i]
		buf.put_8(clampi(int(f.get("owner", -1)), -1, 127))
		buf.put_8(clampi(int(f.get("capturing_team", -1)), -1, 127))
		buf.put_u8(clampi(int(roundf(clampf(float(f.get("progress", 0.0)), 0.0, 1.0) * 255.0)), 0, 255))

	return buf.data_array


static func unpack_world_snapshot(bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {
		"server_tick": 0,
		"server_time_ms": 0,
		"royal_tickets": 50,
		"national_tickets": 50,
		"heroes": [] as Array[Dictionary],
		"vehicles": [] as Array[Dictionary],
		"flags": [] as Array[Dictionary],
	}
	if bytes.size() < 15:
		return result

	var buf := StreamPeerBuffer.new()
	buf.data_array = bytes
	buf.seek(0)
	result["server_tick"] = buf.get_u32()
	result["server_time_ms"] = buf.get_u32()
	result["royal_tickets"] = buf.get_u16()
	result["national_tickets"] = buf.get_u16()

	var heroes_out: Array[Dictionary] = []
	var hero_count: int = buf.get_u8()
	for i in range(hero_count):
		var id: int = buf.get_u16()
		var meta: int = buf.get_u8()
		var flags: int = buf.get_u16()
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var vel: Vector3 = _get_vec3_s16_vel(buf)
		var yaw: float = _unwrap_signed_angle(_unpack_angle_u16(buf.get_u16()))
		var pitch: float = clampf(_unwrap_signed_angle(_unpack_angle_u16(buf.get_u16())), -1.45, 1.45)
		var hp: int = buf.get_u16()
		var shield: int = buf.get_u16()
		var vehicle_id: int = buf.get_16()
		var seat_idx: int = buf.get_8()
		heroes_out.append({
			"id": id,
			"team": meta & 0x3,
			"class_id": (meta >> 2) & 0x3,
			"weapon_slot": (meta >> 4) & 0x3,
			"flags": flags,
			"pos": pos,
			"vel": vel,
			"yaw": yaw,
			"pitch": pitch,
			"hp": hp,
			"shield": shield,
			"vehicle_id": vehicle_id,
			"seat_idx": seat_idx,
		})
	result["heroes"] = heroes_out

	var vehicles_out: Array[Dictionary] = []
	var veh_count: int = buf.get_u8()
	for i in range(veh_count):
		var id: int = buf.get_u16()
		var vtype: int = buf.get_u8()
		var pos := Vector3(buf.get_float(), buf.get_float(), buf.get_float())
		var rot := Quaternion(buf.get_float(), buf.get_float(), buf.get_float(), buf.get_float()).normalized()
		var vel: Vector3 = _get_vec3_s16_vel(buf)
		var turret_yaw: float = _unwrap_signed_angle(_unpack_angle_u16(buf.get_u16()))
		var hp: int = buf.get_u16()
		vehicles_out.append({
			"id": id,
			"type": vtype,
			"pos": pos,
			"rot": rot,
			"vel": vel,
			"turret_yaw": turret_yaw,
			"hp": hp,
		})
	result["vehicles"] = vehicles_out

	var flags_out: Array[Dictionary] = []
	var flag_count: int = buf.get_u8()
	for i in range(flag_count):
		var owner: int = buf.get_8()
		var cap_team: int = buf.get_8()
		var prog: float = float(buf.get_u8()) / 255.0
		flags_out.append({
			"owner": owner,
			"capturing_team": cap_team,
			"progress": prog,
		})
	result["flags"] = flags_out
	return result
