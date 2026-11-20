class_name WebRoomRelay
extends RefCounted

const BROKER_URLS: Array[String] = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
]
const TOPIC_PREFIX: String = "warchampions_bfh_v14/"

const MSG_JOIN_REQ: int = 1
const MSG_ROSTER_SYNC: int = 2
const MSG_PEER_LEAVE: int = 3
const MSG_INPUT_CMD: int = 4
const MSG_WORLD_BUNDLE: int = 5
const MSG_GAME_EVENT: int = 6
const MSG_PING_REQ: int = 7
const MSG_PING_ACK: int = 8
const MSG_SEAT_SWITCH: int = 9
const MSG_MORTAR_TARGET: int = 10
const MSG_MORTAR_CANCEL: int = 11

const MQTT_PKT_CONNECT: int = 1
const MQTT_PKT_CONNACK: int = 2
const MQTT_PKT_PUBLISH: int = 3
const MQTT_PKT_SUBSCRIBE: int = 8
const MQTT_PKT_SUBACK: int = 9
const MQTT_PKT_PINGREQ: int = 12
const MQTT_PKT_PINGRESP: int = 13

signal relay_connected
signal relay_failed(reason: String)
signal join_req_received(peer_id: int, profile: Dictionary)
signal roster_sync_received(roster: Dictionary)
signal peer_leave_received(peer_id: int)
signal input_cmd_received(peer_id: int, packed_cmd: PackedByteArray)
signal auth_state_packet_received(packed_state: PackedByteArray)
signal world_snapshot_packet_received(packed_snapshot: PackedByteArray)
signal game_event_packet_received(sender_id: int, event_type: String, payload: Dictionary)
signal ping_req_received(peer_id: int, client_send_ms: int)
signal ping_ack_received(client_send_ms: int, srv_tick: int, srv_time_ms: int)
signal seat_switch_packet_received(peer_id: int, seat_idx: int)
signal mortar_target_packet_received(peer_id: int, wx: float, wz: float)
signal mortar_cancel_packet_received(peer_id: int)

static var _local_test_bus: Dictionary = {}

var room_code: String = ""
var is_host: bool = false
var local_peer_id: int = 1
var is_ready: bool = false
var is_local_loopback: bool = false

var _topic_c2s: String = ""
var _topic_s2c: String = ""
var _topic_bcast: String = ""
var _ws: WebSocketPeer = null
var _broker_idx: int = 0
var _ws_connect_sent: bool = false
var _connect_elapsed: float = 0.0
var _keepalive_elapsed: float = 0.0
var _rx_stream: PackedByteArray = PackedByteArray()
var _manual_close: bool = false


static func sanitize_room_code(raw: String) -> String:
	var s: String = raw.strip_edges().to_upper()
	s = s.replace("/", "-").replace(" ", "-").replace("#", "-").replace("+", "-")
	if s.is_empty():
		return "SALA-1"
	return s


func connect_room(p_room_code: String, as_host: bool, initial_peer_id: int) -> Error:
	close_room()
	room_code = sanitize_room_code(p_room_code)
	is_host = as_host
	local_peer_id = initial_peer_id
	_manual_close = false
	_broker_idx = 0
	_topic_c2s = "%s%s/c2s" % [TOPIC_PREFIX, room_code]
	_topic_s2c = "%s%s/s2c" % [TOPIC_PREFIX, room_code]
	_topic_bcast = "%s%s/bcast" % [TOPIC_PREFIX, room_code]

	if room_code.begins_with("LOCALTEST"):
		is_local_loopback = true
		var bucket: Array = _local_test_bus.get(room_code, [])
		var cleaned: Array = []
		for item in bucket:
			if item != null and item != self:
				cleaned.append(item)
		cleaned.append(self)
		_local_test_bus[room_code] = cleaned
		is_ready = true
		relay_connected.emit()
		return OK

	is_local_loopback = false
	return _start_broker_socket(0)


func _start_broker_socket(idx: int) -> Error:
	if idx < 0 or idx >= BROKER_URLS.size():
		relay_failed.emit("Nenhum broker WebSocket disponível")
		return ERR_CANT_CONNECT
	_broker_idx = idx
	_ws_connect_sent = false
	_connect_elapsed = 0.0
	_keepalive_elapsed = 0.0
	_rx_stream.clear()
	is_ready = false
	if _ws != null:
		_ws.close()
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray(["mqtt"])
	_ws.inbound_buffer_size = 262144
	_ws.outbound_buffer_size = 262144
	var url: String = BROKER_URLS[_broker_idx]
	var err: Error = _ws.connect_to_url(url)
	if err != OK:
		if _broker_idx + 1 < BROKER_URLS.size():
			return _start_broker_socket(_broker_idx + 1)
		relay_failed.emit("Falha ao conectar %s (%s)" % [url, error_string(err)])
	return err


func close_room() -> void:
	_manual_close = true
	is_ready = false
	if is_local_loopback and not room_code.is_empty() and _local_test_bus.has(room_code):
		var bucket: Array = _local_test_bus[room_code]
		bucket.erase(self)
		if bucket.is_empty():
			_local_test_bus.erase(room_code)
	is_local_loopback = false
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.send(PackedByteArray([0xE0, 0x00]))
		_ws.close()
		_ws = null
	_rx_stream.clear()


func poll(delta: float) -> void:
	if is_local_loopback or _ws == null:
		return
	_ws.poll()
	var st: WebSocketPeer.State = _ws.get_ready_state()
	match st:
		WebSocketPeer.STATE_CONNECTING:
			_connect_elapsed += delta
			if _connect_elapsed >= 4.0:
				_try_next_broker_or_fail("Timeout ao conectar ao relay MQTT")
		WebSocketPeer.STATE_OPEN:
			if not _ws_connect_sent:
				_ws_connect_sent = true
				var cid: String = "wcb_%s_%d_%d" % ["h" if is_host else "c", local_peer_id, Time.get_ticks_usec() % 100000]
				_ws.send(build_connect_packet(cid, 20))
			elif not is_ready:
				_connect_elapsed += delta
				if _connect_elapsed >= 5.0:
					_try_next_broker_or_fail("Timeout handshake MQTT")
			while _ws.get_available_packet_count() > 0:
				var pkt: PackedByteArray = _ws.get_packet()
				if not pkt.is_empty():
					_rx_stream.append_array(pkt)
			_consume_mqtt_stream()
			if is_ready:
				_keepalive_elapsed += delta
				if _keepalive_elapsed >= 12.0:
					_keepalive_elapsed = 0.0
					_ws.send(build_pingreq_packet())
		WebSocketPeer.STATE_CLOSING:
			pass
		WebSocketPeer.STATE_CLOSED:
			if not _manual_close:
				_try_next_broker_or_fail("Conexão WebSocket encerrada")


func _try_next_broker_or_fail(reason: String) -> void:
	is_ready = false
	if _broker_idx + 1 < BROKER_URLS.size():
		_start_broker_socket(_broker_idx + 1)
	else:
		_ws = null
		relay_failed.emit(reason)


func _publish(topic: String, payload: PackedByteArray) -> void:
	if not is_ready or payload.is_empty():
		return
	if is_local_loopback:
		var bucket: Array = _local_test_bus.get(room_code, [])
		for peer_obj in bucket:
			var r := peer_obj as WebRoomRelay
			if r == null or r == self or not r.is_ready:
				continue
			if r._subscribes_to(topic):
				r._handle_incoming_payload(topic, payload)
		return
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send(build_publish_packet(topic, payload))


func _subscribes_to(topic: String) -> bool:
	if is_host:
		return topic == _topic_c2s
	return topic == _topic_s2c or topic == _topic_bcast


func send_join_req(peer_id: int, profile: Dictionary) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_JOIN_REQ)
	buf.put_u32(peer_id)
	var p_bytes: PackedByteArray = var_to_bytes(profile)
	buf.put_data(p_bytes)
	_publish(_topic_c2s, buf.data_array)


func send_roster_sync(roster: Dictionary) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_ROSTER_SYNC)
	buf.put_data(var_to_bytes(roster))
	_publish(_topic_bcast, buf.data_array)


func send_peer_leave(peer_id: int) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_PEER_LEAVE)
	buf.put_u32(peer_id)
	_publish(_topic_bcast if is_host else _topic_c2s, buf.data_array)


func send_input_cmd(peer_id: int, packed_cmd: PackedByteArray) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_INPUT_CMD)
	buf.put_u32(peer_id)
	buf.put_data(packed_cmd)
	_publish(_topic_c2s, buf.data_array)


func send_world_bundle(auth_map: Dictionary, packed_snapshot: PackedByteArray) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_WORLD_BUNDLE)
	var valid_ids: Array[int] = []
	for k in auth_map.keys():
		var bytes_var: Variant = auth_map[k]
		if bytes_var is PackedByteArray and not (bytes_var as PackedByteArray).is_empty():
			valid_ids.append(int(k))
	var auth_cnt: int = mini(valid_ids.size(), 255)
	buf.put_u8(auth_cnt)
	for i in range(auth_cnt):
		var pid: int = valid_ids[i]
		var a_bytes: PackedByteArray = auth_map[pid]
		buf.put_u32(pid)
		buf.put_u16(a_bytes.size())
		buf.put_data(a_bytes)
	if not packed_snapshot.is_empty():
		buf.put_data(packed_snapshot)
	_publish(_topic_bcast, buf.data_array)


func send_game_event(sender_id: int, event_type: String, payload: Dictionary, to_host: bool) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_GAME_EVENT)
	buf.put_u32(sender_id)
	buf.put_data(var_to_bytes([event_type, payload]))
	_publish(_topic_c2s if to_host else _topic_bcast, buf.data_array)


func send_ping_req(peer_id: int, client_send_ms: int) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_PING_REQ)
	buf.put_u32(peer_id)
	buf.put_u32(client_send_ms)
	_publish(_topic_c2s, buf.data_array)


func send_ping_ack(target_peer_id: int, client_send_ms: int, srv_tick: int, srv_time_ms: int) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_PING_ACK)
	buf.put_u32(target_peer_id)
	buf.put_u32(client_send_ms)
	buf.put_u32(srv_tick)
	buf.put_u32(srv_time_ms)
	_publish(_topic_s2c, buf.data_array)


func send_seat_switch(peer_id: int, seat_idx: int) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_SEAT_SWITCH)
	buf.put_u32(peer_id)
	buf.put_u8(clampi(seat_idx, 0, 3))
	_publish(_topic_c2s, buf.data_array)


func send_mortar_target(peer_id: int, wx: float, wz: float) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_MORTAR_TARGET)
	buf.put_u32(peer_id)
	buf.put_float(wx)
	buf.put_float(wz)
	_publish(_topic_c2s, buf.data_array)


func send_mortar_cancel(peer_id: int) -> void:
	var buf := StreamPeerBuffer.new()
	buf.put_u8(MSG_MORTAR_CANCEL)
	buf.put_u32(peer_id)
	_publish(_topic_c2s, buf.data_array)


func _handle_incoming_payload(topic: String, data: PackedByteArray) -> void:
	if not _subscribes_to(topic) or data.is_empty():
		return
	var buf := StreamPeerBuffer.new()
	buf.data_array = data
	var msg_type: int = buf.get_u8()
	match msg_type:
		MSG_JOIN_REQ:
			if not is_host or buf.get_available_bytes() < 4:
				return
			var pid: int = buf.get_u32()
			var tail_len: int = buf.get_available_bytes()
			if tail_len <= 0:
				return
			var raw: PackedByteArray = buf.get_data(tail_len)[1]
			var decoded: Variant = bytes_to_var(raw)
			if decoded is Dictionary:
				join_req_received.emit(pid, decoded as Dictionary)
		MSG_ROSTER_SYNC:
			if is_host or buf.get_available_bytes() <= 0:
				return
			var raw: PackedByteArray = buf.get_data(buf.get_available_bytes())[1]
			var decoded: Variant = bytes_to_var(raw)
			if decoded is Dictionary:
				roster_sync_received.emit(decoded as Dictionary)
		MSG_PEER_LEAVE:
			if buf.get_available_bytes() < 4:
				return
			var pid: int = buf.get_u32()
			peer_leave_received.emit(pid)
		MSG_INPUT_CMD:
			if not is_host or buf.get_available_bytes() < 4 + NetSerializer.INPUT_CMD_BYTES:
				return
			var pid: int = buf.get_u32()
			var packed_cmd: PackedByteArray = buf.get_data(NetSerializer.INPUT_CMD_BYTES)[1]
			input_cmd_received.emit(pid, packed_cmd)
		MSG_WORLD_BUNDLE:
			if is_host or buf.get_available_bytes() < 1:
				return
			var auth_cnt: int = buf.get_u8()
			for _i in range(auth_cnt):
				if buf.get_available_bytes() < 6:
					return
				var pid: int = buf.get_u32()
				var a_len: int = buf.get_u16()
				if a_len <= 0 or buf.get_available_bytes() < a_len:
					return
				var a_bytes: PackedByteArray = buf.get_data(a_len)[1]
				if pid == local_peer_id:
					auth_state_packet_received.emit(a_bytes)
			var rem: int = buf.get_available_bytes()
			if rem > 0:
				var snap_bytes: PackedByteArray = buf.get_data(rem)[1]
				world_snapshot_packet_received.emit(snap_bytes)
		MSG_GAME_EVENT:
			if buf.get_available_bytes() < 5:
				return
			var sender_id: int = buf.get_u32()
			var raw: PackedByteArray = buf.get_data(buf.get_available_bytes())[1]
			var decoded: Variant = bytes_to_var(raw)
			if decoded is Array and (decoded as Array).size() >= 2:
				var arr: Array = decoded as Array
				var ev_type: String = str(arr[0])
				var payload: Dictionary = arr[1] if arr[1] is Dictionary else {}
				game_event_packet_received.emit(sender_id, ev_type, payload)
		MSG_PING_REQ:
			if not is_host or buf.get_available_bytes() < 8:
				return
			var pid: int = buf.get_u32()
			var send_ms: int = buf.get_u32()
			ping_req_received.emit(pid, send_ms)
		MSG_PING_ACK:
			if is_host or buf.get_available_bytes() < 16:
				return
			var target_pid: int = buf.get_u32()
			var send_ms: int = buf.get_u32()
			var srv_tick: int = buf.get_u32()
			var srv_ms: int = buf.get_u32()
			if target_pid == local_peer_id:
				ping_ack_received.emit(send_ms, srv_tick, srv_ms)
		MSG_SEAT_SWITCH:
			if not is_host or buf.get_available_bytes() < 5:
				return
			var pid: int = buf.get_u32()
			var s_idx: int = buf.get_u8()
			seat_switch_packet_received.emit(pid, s_idx)
		MSG_MORTAR_TARGET:
			if not is_host or buf.get_available_bytes() < 12:
				return
			var pid: int = buf.get_u32()
			var wx: float = buf.get_float()
			var wz: float = buf.get_float()
			mortar_target_packet_received.emit(pid, wx, wz)
		MSG_MORTAR_CANCEL:
			if not is_host or buf.get_available_bytes() < 4:
				return
			var pid: int = buf.get_u32()
			mortar_cancel_packet_received.emit(pid)


func _consume_mqtt_stream() -> void:
	while _rx_stream.size() >= 2:
		var hdr: int = _rx_stream[0]
		var ptype: int = (hdr >> 4) & 0x0F
		var rl: Vector2i = _decode_remaining_length(_rx_stream, 1)
		if rl.x == -1:
			break
		if rl.x < 0:
			_rx_stream.clear()
			_try_next_broker_or_fail("MQTT frame inválido")
			break
		var total_len: int = 1 + rl.y + rl.x
		if _rx_stream.size() < total_len:
			break
		var body: PackedByteArray = _rx_stream.slice(1 + rl.y, total_len)
		_rx_stream = _rx_stream.slice(total_len)
		match ptype:
			MQTT_PKT_CONNACK:
				if body.size() >= 2 and body[1] == 0:
					var topics: PackedStringArray = PackedStringArray([_topic_c2s]) if is_host else PackedStringArray([_topic_s2c, _topic_bcast])
					_ws.send(build_subscribe_packet(1, topics))
				else:
					_try_next_broker_or_fail("MQTT CONNACK recusado")
			MQTT_PKT_SUBACK:
				if not is_ready:
					is_ready = true
					relay_connected.emit()
			MQTT_PKT_PUBLISH:
				if body.size() >= 2:
					var tlen: int = (int(body[0]) << 8) | int(body[1])
					var pos: int = 2 + tlen
					if pos <= body.size():
						var topic: String = body.slice(2, pos).get_string_from_utf8()
						var qos: int = (hdr >> 1) & 0x03
						if qos > 0:
							pos += 2
						if pos <= body.size():
							_handle_incoming_payload(topic, body.slice(pos))
			MQTT_PKT_PINGRESP:
				pass


static func _encode_remaining_length(val: int) -> PackedByteArray:
	var out := PackedByteArray()
	var x: int = maxi(0, val)
	while true:
		var digit: int = x % 128
		x = int(x / 128)
		if x > 0:
			digit |= 0x80
		out.append(digit)
		if x <= 0:
			break
	return out


static func _decode_remaining_length(buf: PackedByteArray, offset: int) -> Vector2i:
	var mult: int = 1
	var val: int = 0
	var consumed: int = 0
	while consumed < 4:
		if offset + consumed >= buf.size():
			return Vector2i(-1, 0)
		var b: int = buf[offset + consumed]
		val += (b & 0x7F) * mult
		consumed += 1
		if (b & 0x80) == 0:
			return Vector2i(val, consumed)
		mult *= 128
	return Vector2i(-2, 0)


static func _encode_utf8(text: String) -> PackedByteArray:
	var raw: PackedByteArray = text.to_utf8_buffer()
	var out := PackedByteArray([(raw.size() >> 8) & 0xFF, raw.size() & 0xFF])
	out.append_array(raw)
	return out


static func build_connect_packet(client_id: String, keepalive_sec: int = 20) -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array(_encode_utf8("MQTT"))
	body.append(0x04) # Protocol Level 4 (3.1.1)
	body.append(0x02) # Clean Session
	body.append((keepalive_sec >> 8) & 0xFF)
	body.append(keepalive_sec & 0xFF)
	body.append_array(_encode_utf8(client_id))
	var pkt := PackedByteArray([0x10])
	pkt.append_array(_encode_remaining_length(body.size()))
	pkt.append_array(body)
	return pkt


static func build_subscribe_packet(packet_id: int, topics: PackedStringArray) -> PackedByteArray:
	var body := PackedByteArray([(packet_id >> 8) & 0xFF, packet_id & 0xFF])
	for t in topics:
		body.append_array(_encode_utf8(t))
		body.append(0x00) # QoS 0
	var pkt := PackedByteArray([0x82])
	pkt.append_array(_encode_remaining_length(body.size()))
	pkt.append_array(body)
	return pkt


static func build_publish_packet(topic: String, payload: PackedByteArray) -> PackedByteArray:
	var body := PackedByteArray()
	body.append_array(_encode_utf8(topic))
	body.append_array(payload)
	var pkt := PackedByteArray([0x30])
	pkt.append_array(_encode_remaining_length(body.size()))
	pkt.append_array(body)
	return pkt


static func build_pingreq_packet() -> PackedByteArray:
	return PackedByteArray([0xC0, 0x00])
