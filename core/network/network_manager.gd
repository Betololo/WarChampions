extends Node

## War Champions Dedicated-Server Authoritative Network Manager (14v14 / 28 players).
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 28
const CHANNEL_RELIABLE: int = 0
const CHANNEL_UNRELIABLE: int = 1
const TICK_RATE: int = 60
const SNAPSHOT_RATE_HZ: int = 30
const TICK_INTERVAL_MS: float = 1000.0 / float(TICK_RATE)

const TEAM_ROYAL: int = 0
const TEAM_NATIONAL: int = 1

const CLASS_SOLDIER: int = 0
const CLASS_GUNNER: int = 1
const CLASS_COMMANDO: int = 2
const CLASS_DEMOLISHER: int = 3
const CLASS_ENGINEER: int = 4
const CLASS_MARKSMAN: int = 5

const ARCHETYPE_BALANCED: int = 0
const ARCHETYPE_FAST_SHORT: int = 1
const ARCHETYPE_SLOW_LONG: int = 2

signal client_input_received(peer_id: int, cmd: InputCmd)
signal authoritative_state_received(state: Dictionary)
signal world_snapshot_received(snapshot: Dictionary)
signal player_registered(peer_id: int, info: Dictionary)
signal player_unregistered(peer_id: int)
signal game_event_received(event_type: String, payload: Dictionary)
signal connection_state_changed(connected: bool, is_server: bool)
signal seat_switch_requested(peer_id: int, seat_idx: int)
signal mortar_target_received(peer_id: int, wx: float, wz: float)
signal mortar_cancel_received(peer_id: int)

var is_dedicated_server: bool = false
var is_solo_bot_mode: bool = false
var server_tick: int = 0
var local_peer_id: int = 1

## Clock synchronization (Client side)
var ema_rtt_ms: float = 20.0
var server_clock_offset_ms: float = 0.0
var _clock_samples: int = 0
var _ping_timer: float = 0.0
var _snapshot_accum: int = 0

## Artificial network impairment simulator (Channel 1) for local verification
var sim_latency_ms: float = 0.0
var sim_jitter_ms: float = 0.0
var sim_packet_loss: float = 0.0
var _delayed_queue: Array[Dictionary] = []

## Player roster: peer_id (or bot entity_id >= 1000) -> Dictionary
var players_info: Dictionary = {}
var peer_input_buffers: Dictionary = {} # peer_id: int -> InputRingBuffer
var _peer_last_input_tick: Dictionary = {} # peer_id: int -> int
var _peer_future_streak: Dictionary = {} # peer_id: int -> int
var _peer_seq_stats: Dictionary = {} # peer_id: int -> Dictionary
var local_slot_archetypes: Dictionary = {} # "%d_%d" % [class_id, weapon_slot] -> archetype
var local_profile: Dictionary = {
	"name": "Hero",
	"team": TEAM_ROYAL,
	"class_id": CLASS_SOLDIER,
	"archetype": ARCHETYPE_BALANCED,
	"slot_archetypes": {},
}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--server"):
		var port: int = DEFAULT_PORT
		for arg in args:
			if arg.begins_with("--port="):
				port = int(arg.trim_prefix("--port="))
		start_dedicated_server(port)


func is_active_enet_connected() -> bool:
	if multiplayer.multiplayer_peer == null or (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_server_authority() -> bool:
	if multiplayer.multiplayer_peer == null or (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		return true
	return multiplayer.is_server()


func is_active_host_authority() -> bool:
	return (is_active_enet_connected() or is_solo_bot_mode) and multiplayer.is_server()


func _process(delta: float) -> void:
	_flush_delayed_packets()
	if is_active_enet_connected() and not multiplayer.is_server():
		_ping_timer += delta
		if _ping_timer >= 0.5:
			_ping_timer = 0.0
			_send_ping_request()


func _physics_process(_delta: float) -> void:
	if is_active_host_authority():
		server_tick += 1
		_snapshot_accum += 1


func should_broadcast_snapshot() -> bool:
	var interval: int = maxi(1, int(TICK_RATE / SNAPSHOT_RATE_HZ))
	if _snapshot_accum >= interval:
		_snapshot_accum = 0
		return true
	return false


func start_dedicated_server(port: int = DEFAULT_PORT) -> Error:
	shutdown_network()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_PLAYERS, 2)
	if err != OK:
		push_error("Failed to create ENet server on port %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	is_dedicated_server = true
	is_solo_bot_mode = false
	server_tick = 0
	local_peer_id = 1
	connection_state_changed.emit(true, true)
	print("[NetworkManager] Dedicated server listening on UDP port %d (Max %d / 14v14)" % [port, MAX_PLAYERS])
	return OK


func start_host(port: int = DEFAULT_PORT, solo_with_bots: bool = false) -> Error:
	shutdown_network()
	if solo_with_bots:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	else:
		var peer := ENetMultiplayerPeer.new()
		var err: Error = peer.create_server(port, MAX_PLAYERS, 2)
		if err != OK:
			push_error("Failed to start host on port %d: %s" % [port, error_string(err)])
			return err
		multiplayer.multiplayer_peer = peer
	is_dedicated_server = false
	is_solo_bot_mode = solo_with_bots
	server_tick = 0
	local_peer_id = 1
	_register_player_internal(1, local_profile.duplicate())
	connection_state_changed.emit(true, true)
	return OK


func join_server(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	shutdown_network()
	var peer := ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port, 2)
	if err != OK:
		push_error("Failed to connect to %s:%d: %s" % [ip, port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	is_dedicated_server = false
	is_solo_bot_mode = false
	_clock_samples = 0
	return OK


func shutdown_network() -> void:
	_delayed_queue.clear()
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players_info.clear()
	_peer_last_input_tick.clear()
	_peer_future_streak.clear()
	_peer_seq_stats.clear()
	peer_input_buffers.clear()
	server_tick = 0
	_snapshot_accum = 0
	is_dedicated_server = false
	is_solo_bot_mode = false
	connection_state_changed.emit(false, false)


func validate_and_enqueue_peer_input(sender_id: int, cmd: InputCmd) -> bool:
	if not _peer_seq_stats.has(sender_id):
		_peer_seq_stats[sender_id] = {
			"accepted": 0,
			"dropped_stale": 0,
			"dropped_future": 0,
			"last_tick": 0,
		}

	if cmd == null or cmd.tick <= 0:
		return false

	var last_tick: int = int(_peer_last_input_tick.get(sender_id, 0))

	if last_tick > 0 and cmd.tick <= last_tick:
		_peer_seq_stats[sender_id]["dropped_stale"] += 1
		return false

	if last_tick > 0 and cmd.tick > last_tick + 180:
		var streak: int = int(_peer_future_streak.get(sender_id, 0)) + 1
		if streak < 3:
			_peer_future_streak[sender_id] = streak
			_peer_seq_stats[sender_id]["dropped_future"] += 1
			return false
		_peer_future_streak[sender_id] = 0
	else:
		_peer_future_streak[sender_id] = 0

	_peer_last_input_tick[sender_id] = cmd.tick
	_peer_seq_stats[sender_id]["accepted"] += 1
	_peer_seq_stats[sender_id]["last_tick"] = cmd.tick

	if not peer_input_buffers.has(sender_id):
		peer_input_buffers[sender_id] = InputRingBuffer.new()

	var buf: InputRingBuffer = peer_input_buffers[sender_id]
	buf.push(cmd.tick, cmd, Vector3.ZERO, Vector3.ZERO, false, false, false, false)

	return true


func get_input_for_peer_tick(peer_id: int, tick: int) -> InputCmd:
	if not peer_input_buffers.has(peer_id):
		return null
	var buf: InputRingBuffer = peer_input_buffers[peer_id]
	var entry: InputRingBuffer.RingEntry = buf.get_entry(tick)
	if entry != null and entry.cmd != null:
		return entry.cmd
	var last_tick: int = int(_peer_last_input_tick.get(peer_id, -1))
	if last_tick >= 0:
		var latest: InputRingBuffer.RingEntry = buf.get_entry(last_tick)
		if latest != null and latest.cmd != null:
			var fallback_cmd := InputCmd.new()
			fallback_cmd.tick = tick
			fallback_cmd.move_dir = latest.cmd.move_dir
			fallback_cmd.aim_yaw = latest.cmd.aim_yaw
			fallback_cmd.aim_pitch = latest.cmd.aim_pitch
			fallback_cmd.selected_weapon_slot = latest.cmd.selected_weapon_slot
			fallback_cmd.view_interp_tick_delta = latest.cmd.view_interp_tick_delta
			fallback_cmd.buttons = latest.cmd.buttons & (~InputCmd.BTN_JUMP)
			return fallback_cmd
	return null


func get_server_clock_ms() -> float:
	if multiplayer.multiplayer_peer == null or multiplayer.is_server():
		return float(server_tick) * TICK_INTERVAL_MS
	return float(Time.get_ticks_msec()) + server_clock_offset_ms


func get_estimated_server_tick() -> int:
	return int(roundf(get_server_clock_ms() / TICK_INTERVAL_MS))


func get_view_interp_tick_delta() -> int:
	if is_server_authority():
		return 0
	var interp_ticks: int = int(roundf(SnapshotInterpolator.INTERPOLATION_OFFSET_MS / TICK_INTERVAL_MS))
	return clampi(interp_ticks, 0, 65535)


static func _clamp_class_slot_archetype(cid: int, slot_idx: int, arch: int) -> int:
	if (cid == CLASS_DEMOLISHER or cid == CLASS_ENGINEER) and slot_idx == 2:
		return 0
	if cid == CLASS_MARKSMAN and slot_idx == 0:
		return clampi(arch, 0, 1)
	return clampi(arch, 0, 2)


func set_slot_archetype(p_class_id: int, slot_idx: int, arch: int) -> void:
	var cid: int = clampi(p_class_id, 0, 5)
	var clean_arch: int = _clamp_class_slot_archetype(cid, slot_idx, arch)
	local_slot_archetypes["%d_%d" % [cid, maxi(0, slot_idx)]] = clean_arch


func get_slot_archetype(p_class_id: int, slot_idx: int, fallback: int = ARCHETYPE_BALANCED) -> int:
	var cid: int = clampi(p_class_id, 0, 5)
	var raw_val: int = int(local_slot_archetypes.get("%d_%d" % [cid, maxi(0, slot_idx)], fallback))
	return _clamp_class_slot_archetype(cid, slot_idx, raw_val)


func build_class_slot_archetypes(p_class_id: int, fallback: int = ARCHETYPE_BALANCED) -> Dictionary:
	var out: Dictionary = {}
	var cid: int = clampi(p_class_id, 0, 5)
	for slot in range(4):
		if (cid == CLASS_DEMOLISHER or cid == CLASS_ENGINEER) and slot == 2:
			out[slot] = 0
			continue
		var key: String = "%d_%d" % [cid, slot]
		if local_slot_archetypes.has(key):
			out[slot] = _clamp_class_slot_archetype(cid, slot, int(local_slot_archetypes[key]))
		elif fallback != ARCHETYPE_BALANCED:
			out[slot] = _clamp_class_slot_archetype(cid, slot, fallback)
	return out


func set_local_loadout(player_name: String, team: int, class_id: int, archetype: int, slot_archetypes: Dictionary = {}) -> void:
	var cid: int = clampi(class_id, 0, 5)
	var merged_slots: Dictionary = build_class_slot_archetypes(cid, archetype)
	for k in slot_archetypes.keys():
		var s_idx: int = int(k)
		merged_slots[s_idx] = _clamp_class_slot_archetype(cid, s_idx, int(slot_archetypes[k]))
	local_profile = {
		"name": player_name,
		"team": clampi(team, 0, 1),
		"class_id": cid,
		"archetype": clampi(archetype, 0, 2),
		"slot_archetypes": merged_slots,
	}
	if is_active_enet_connected():
		if multiplayer.is_server():
			_register_player_internal(1, local_profile.duplicate(true))
		else:
			_rpc_register_profile.rpc_id(1, local_profile)


func request_seat_switch(seat_idx: int) -> void:
	if seat_idx < 0 or seat_idx >= 4:
		return
	if not is_active_enet_connected() and not is_solo_bot_mode:
		return
	if multiplayer.is_server():
		seat_switch_requested.emit(local_peer_id, seat_idx)
	else:
		_rpc_request_seat_switch.rpc_id(1, seat_idx)


func send_mortar_target(wx: float, wz: float) -> void:
	if is_active_enet_connected() and not multiplayer.is_server():
		_rpc_send_mortar_target.rpc_id(1, wx, wz)
	else:
		mortar_target_received.emit(local_peer_id, wx, wz)


func send_mortar_cancel() -> void:
	if is_active_enet_connected() and not multiplayer.is_server():
		_rpc_send_mortar_cancel.rpc_id(1)
	else:
		mortar_cancel_received.emit(local_peer_id)


func get_team_counts() -> Vector2i:
	var royal: int = 0
	var national: int = 0
	for id_key in players_info.keys():
		var info: Dictionary = players_info[id_key]
		if int(info.get("team", TEAM_ROYAL)) == TEAM_ROYAL:
			royal += 1
		else:
			national += 1
	return Vector2i(royal, national)


func register_bot(bot_id: int, bot_name: String, team: int, class_id: int, archetype: int = ARCHETYPE_BALANCED) -> void:
	var info: Dictionary = {
		"name": bot_name,
		"team": team,
		"class_id": class_id,
		"archetype": archetype,
		"is_bot": true,
		"xp": 0,
		"level": 5,
		"hero_points": 0,
		"kills": 0,
		"deaths": 0,
	}
	players_info[bot_id] = info
	player_registered.emit(bot_id, info)


func send_input_to_server(cmd: InputCmd) -> void:
	if not is_active_enet_connected() and not is_solo_bot_mode:
		return
	if multiplayer.is_server():
		validate_and_enqueue_peer_input(1, cmd)
		client_input_received.emit(1, cmd)
		return
	var packed: PackedByteArray = NetSerializer.pack_input_cmd(cmd)
	_schedule_unreliable(func() -> void:
		if is_active_enet_connected() and not multiplayer.is_server():
			_rpc_server_receive_input.rpc_id(1, packed)
	)


func send_authoritative_state(peer_id: int, packed_state: PackedByteArray) -> void:
	if peer_id == 1:
		authoritative_state_received.emit(NetSerializer.unpack_authoritative_state(packed_state))
		return
	if bool(players_info.get(peer_id, {}).get("is_bot", false)):
		return
	_schedule_unreliable(func() -> void:
		if is_active_enet_connected() and multiplayer.get_peers().has(peer_id):
			_rpc_client_receive_auth_state.rpc_id(peer_id, packed_state)
	)


func broadcast_world_snapshot(packed_snapshot: PackedByteArray) -> void:
	if not is_active_enet_connected() or not multiplayer.is_server():
		return
	var peers: PackedInt32Array = multiplayer.get_peers()
	if peers.is_empty():
		return
	_schedule_unreliable(func() -> void:
		if is_active_enet_connected() and multiplayer.is_server():
			for p in multiplayer.get_peers():
				_rpc_client_receive_snapshot.rpc_id(p, packed_snapshot)
	)


func broadcast_game_event(event_type: String, payload: Dictionary) -> void:
	if not is_active_enet_connected():
		game_event_received.emit(event_type, payload)
		return
	if multiplayer.is_server():
		game_event_received.emit(event_type, payload)
		if not multiplayer.get_peers().is_empty():
			_rpc_client_game_event.rpc(event_type, payload)
	else:
		_rpc_server_game_event.rpc_id(1, event_type, payload)


func _schedule_unreliable(fn: Callable) -> void:
	if sim_packet_loss > 0.0 and randf() < sim_packet_loss:
		return
	if sim_latency_ms <= 0.0 and sim_jitter_ms <= 0.0:
		fn.call()
		return
	var jitter: float = randf_range(-sim_jitter_ms, sim_jitter_ms)
	var deliver_at: int = Time.get_ticks_msec() + maxi(0, int(sim_latency_ms + jitter))
	_delayed_queue.append({"deliver_at": deliver_at, "fn": fn})


func _flush_delayed_packets() -> void:
	if _delayed_queue.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	var remaining: Array[Dictionary] = []
	for item in _delayed_queue:
		if int(item["deliver_at"]) <= now:
			var fn: Callable = item["fn"]
			if fn.is_valid():
				fn.call()
		else:
			remaining.append(item)
	_delayed_queue = remaining


func _send_ping_request() -> void:
	_rpc_ping_req.rpc_id(1, Time.get_ticks_msec())


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_ping_req(client_send_ms: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var srv_time_ms: int = int(roundf(float(server_tick) * TICK_INTERVAL_MS))
	_rpc_ping_ack.rpc_id(sender, client_send_ms, server_tick, srv_time_ms)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_ping_ack(client_send_ms: int, _srv_tick: int, srv_time_ms: int) -> void:
	var now: int = Time.get_ticks_msec()
	var rtt_ms: float = float(maxi(0, now - client_send_ms))
	if _clock_samples >= 4 and rtt_ms > ema_rtt_ms * 2.5 + 30.0:
		return
	if _clock_samples == 0:
		ema_rtt_ms = rtt_ms
	else:
		ema_rtt_ms = lerpf(ema_rtt_ms, rtt_ms, 0.18)
	var estimated_now_srv: float = float(srv_time_ms) + rtt_ms * 0.5
	var measured_offset: float = estimated_now_srv - float(now)
	if _clock_samples == 0:
		server_clock_offset_ms = measured_offset
	else:
		server_clock_offset_ms = lerpf(server_clock_offset_ms, measured_offset, 0.2)
	_clock_samples += 1


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _rpc_server_receive_input(packed_bytes: PackedByteArray) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var cmd: InputCmd = NetSerializer.unpack_input_cmd(packed_bytes)
	if validate_and_enqueue_peer_input(sender, cmd):
		client_input_received.emit(sender, cmd)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_client_receive_auth_state(packed_bytes: PackedByteArray) -> void:
	authoritative_state_received.emit(NetSerializer.unpack_authoritative_state(packed_bytes))


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_client_receive_snapshot(packed_bytes: PackedByteArray) -> void:
	world_snapshot_received.emit(NetSerializer.unpack_world_snapshot(packed_bytes))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_register_profile(profile: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	_register_player_internal(sender, profile)
	_sync_roster_to_peer(sender)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_sync_player_entry(peer_id: int, info: Dictionary) -> void:
	players_info[peer_id] = info
	player_registered.emit(peer_id, info)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_remove_player_entry(peer_id: int) -> void:
	players_info.erase(peer_id)
	player_unregistered.emit(peer_id)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_client_game_event(event_type: String, payload: Dictionary) -> void:
	game_event_received.emit(event_type, payload)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_request_seat_switch(seat_idx: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	seat_switch_requested.emit(sender, clampi(seat_idx, 0, 3))


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_send_mortar_target(wx: float, wz: float) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	mortar_target_received.emit(sender, wx, wz)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_send_mortar_cancel() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	mortar_cancel_received.emit(sender)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_server_game_event(event_type: String, payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	payload["sender_id"] = multiplayer.get_remote_sender_id()
	game_event_received.emit(event_type, payload)


func _register_player_internal(peer_id: int, profile: Dictionary) -> void:
	var cid: int = clampi(int(profile.get("class_id", CLASS_SOLDIER)), 0, 5)
	var raw_slots: Variant = profile.get("slot_archetypes", {})
	var clean_slots: Dictionary = {}
	if raw_slots is Dictionary:
		for k in (raw_slots as Dictionary).keys():
			var s_idx: int = int(k)
			clean_slots[s_idx] = _clamp_class_slot_archetype(cid, s_idx, int((raw_slots as Dictionary)[k]))
	var info: Dictionary = {
		"name": str(profile.get("name", "Player_%d" % peer_id)),
		"team": clampi(int(profile.get("team", TEAM_ROYAL)), 0, 1),
		"class_id": cid,
		"archetype": clampi(int(profile.get("archetype", ARCHETYPE_BALANCED)), 0, 2),
		"slot_archetypes": clean_slots,
		"is_bot": false,
		"xp": int(players_info.get(peer_id, {}).get("xp", 0)),
		"level": int(players_info.get(peer_id, {}).get("level", 5)),
		"hero_points": int(players_info.get(peer_id, {}).get("hero_points", 0)),
		"kills": int(players_info.get(peer_id, {}).get("kills", 0)),
		"deaths": int(players_info.get(peer_id, {}).get("deaths", 0)),
	}
	players_info[peer_id] = info
	player_registered.emit(peer_id, info)
	if multiplayer.is_server() and not multiplayer.get_peers().is_empty():
		_rpc_sync_player_entry.rpc(peer_id, info)


func _sync_roster_to_peer(target_peer_id: int) -> void:
	for id_key in players_info.keys():
		_rpc_sync_player_entry.rpc_id(target_peer_id, int(id_key), players_info[id_key])


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_sync_roster_to_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_peer_last_input_tick.erase(peer_id)
	_peer_future_streak.erase(peer_id)
	_peer_seq_stats.erase(peer_id)
	peer_input_buffers.erase(peer_id)
	if multiplayer.is_server():
		players_info.erase(peer_id)
		player_unregistered.emit(peer_id)
		if not multiplayer.get_peers().is_empty():
			_rpc_remove_player_entry.rpc(peer_id)


func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	_rpc_register_profile.rpc_id(1, local_profile)
	_send_ping_request()
	connection_state_changed.emit(true, false)


func _on_connection_failed() -> void:
	shutdown_network()


func _on_server_disconnected() -> void:
	shutdown_network()
