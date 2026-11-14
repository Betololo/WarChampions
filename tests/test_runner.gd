extends Node

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=== War Champions Automated Verification Suite ===")
	_test_input_cmd_15_bytes_roundtrip()
	_test_world_snapshot_24_players_roundtrip()
	_test_input_ring_buffer_wraparound()
	_test_snapshot_interpolator()
	_test_hero_prediction_reconciliation_and_parachute()
	_test_scene_compile_and_load()
	print("Results: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] %s" % label)
	else:
		_failed += 1
		printerr("[FAIL] %s" % label)


func _test_input_cmd_15_bytes_roundtrip() -> void:
	var cmd := InputCmd.new()
	cmd.tick = 104299
	cmd.move_dir = Vector2(0.707, -0.707)
	cmd.aim_yaw = 1.75
	cmd.aim_pitch = -0.45
	cmd.buttons = InputCmd.BTN_JUMP | InputCmd.BTN_FIRE | InputCmd.BTN_SKILL_3 | InputCmd.BTN_WIDGET_2
	cmd.selected_weapon_slot = 2
	cmd.view_interp_tick_delta = 6

	var bytes: PackedByteArray = NetSerializer.pack_input_cmd(cmd)
	_assert(bytes.size() == 15, "InputCmd bitpacked size is exactly 15 bytes (got %d)" % bytes.size())

	var decoded: InputCmd = NetSerializer.unpack_input_cmd(bytes)
	_assert(decoded.tick == 104299, "InputCmd tick roundtrip matches")
	_assert(decoded.move_dir.distance_to(cmd.move_dir) < 0.02, "InputCmd move_dir quantized roundtrip within tolerance")
	_assert(absf(decoded.aim_yaw - cmd.aim_yaw) < 0.002, "InputCmd aim_yaw roundtrip within 0.002 rad")
	_assert(absf(decoded.aim_pitch - cmd.aim_pitch) < 0.002, "InputCmd aim_pitch roundtrip within 0.002 rad")
	_assert(decoded.buttons == cmd.buttons, "InputCmd buttons bitmask exact roundtrip")
	_assert(decoded.selected_weapon_slot == 2, "InputCmd weapon slot roundtrip")
	_assert(decoded.view_interp_tick_delta == 6, "InputCmd view_interp_tick_delta roundtrip")


func _test_world_snapshot_24_players_roundtrip() -> void:
	var heroes: Array[Dictionary] = []
	for i in range(24):
		heroes.append({
			"id": 100 + i,
			"team": i % 2,
			"class_id": i % 3,
			"weapon_slot": i % 3,
			"flags": NetSerializer.SNAP_GROUNDED | NetSerializer.SNAP_SHIELDED,
			"pos": Vector3(float(i) * 10.0, 2.5, -float(i) * 4.0),
			"vel": Vector3(1.5, 0.0, -2.5),
			"yaw": 0.5,
			"pitch": -0.2,
			"hp": 110,
			"shield": 25,
			"vehicle_id": -1,
			"seat_idx": -1,
		})
	var vehicles: Array[Dictionary] = [
		{"id": 1, "type": 1, "pos": Vector3(20.0, 1.0, 30.0), "rot": Quaternion.IDENTITY, "vel": Vector3(5.0, 0.0, 0.0), "turret_yaw": 1.2, "hp": 450},
	]
	var flags: Array[Dictionary] = [
		{"owner": 0, "capturing_team": -1, "progress": 1.0},
		{"owner": 1, "capturing_team": 0, "progress": 0.4},
		{"owner": -1, "capturing_team": -1, "progress": 0.0},
		{"owner": 0, "capturing_team": 0, "progress": 1.0},
	]
	var bytes: PackedByteArray = NetSerializer.pack_world_snapshot(3600, 60000, 48, 42, heroes, vehicles, flags)
	_assert(bytes.size() < 1200, "12v12 (24 heroes + vehicle + 4 flags) snapshot fits under 1200B MTU (%dB)" % bytes.size())

	var decoded: Dictionary = NetSerializer.unpack_world_snapshot(bytes)
	_assert(int(decoded["server_tick"]) == 3600, "Snapshot server_tick matches")
	_assert(int(decoded["royal_tickets"]) == 48 and int(decoded["national_tickets"]) == 42, "Snapshot tickets match")
	_assert((decoded["heroes"] as Array).size() == 24, "Snapshot decoded all 24 heroes (12v12)")
	_assert((decoded["vehicles"] as Array).size() == 1, "Snapshot decoded vehicles")
	_assert((decoded["flags"] as Array).size() == 4, "Snapshot decoded all 4 flags")


func _test_input_ring_buffer_wraparound() -> void:
	var rb := InputRingBuffer.new()
	for t in range(1, 200):
		var cmd := InputCmd.new()
		cmd.tick = t
		rb.push(t, cmd, Vector3(float(t), 0.0, 0.0), Vector3.ZERO, false, false, true, false)

	_assert(rb.get_entry(10) == null, "Old entry overwritten after 128 ticks returns null")
	_assert(rb.get_entry(199) != null and rb.get_entry(199).position.x == 199.0, "Latest entry retrieved accurately")
	var range_arr: Array[InputRingBuffer.RingEntry] = rb.get_entries_range(190, 199)
	_assert(range_arr.size() == 10 and range_arr[0].tick == 190 and range_arr[9].tick == 199, "RingBuffer range query ordered accurately")


func _test_snapshot_interpolator() -> void:
	var interp := SnapshotInterpolator.new()
	interp.push_snapshot(10, 1000.0, Vector3(0.0, 0.0, 0.0), Quaternion.IDENTITY)
	interp.push_snapshot(12, 1050.0, Vector3(10.0, 0.0, 0.0), Quaternion(Vector3.UP, PI * 0.5))
	var s: SnapshotInterpolator.SnapshotSample = interp.sample(1125.0)
	_assert(s != null and s.position.distance_to(Vector3(5.0, 0.0, 0.0)) < 0.01, "SnapshotInterpolator mid-frame position lerp accurate")


func _test_hero_prediction_reconciliation_and_parachute() -> void:
	var hero := HeroCharacter.new()
	hero.setup_identity(1, "TestHero", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(hero)
	hero.global_position = Vector3(0.0, 40.0, 0.0)
	hero.velocity = Vector3(0.0, -8.0, 0.0)

	var dt: float = 1.0 / 60.0
	for t in range(1, 6):
		var cmd := InputCmd.new()
		cmd.tick = t
		cmd.move_dir = Vector2(0.0, -1.0)
		cmd.set_button(InputCmd.BTN_JUMP, t == 2)
		var pre_jump: bool = hero.prev_jump_held
		hero.local_tick = t
		hero.simulate_movement(cmd, dt)
		hero.input_buffer.push(t, cmd, hero.global_position, hero.velocity, hero.is_parachuting, hero.is_crouching, false, pre_jump)

	_assert(hero.is_parachuting, "Infinite parachute deploys mid-air when Jump is pressed")

	# Simulate server knockback divergence at tick 3 and verify reconciliation replays ticks 4..5
	var pos_before: Vector3 = hero.global_position
	hero.reconcile_with_server({
		"ack_tick": 3,
		"pos": Vector3(2.0, 38.0, -1.0),
		"vel": Vector3(4.0, -2.0, -3.0),
		"flags": NetSerializer.SNAP_PARACHUTING,
		"hp": 110,
		"shield": 0,
		"vehicle_id": -1,
		"seat_idx": -1,
		"knockback_seq": 1,
	})
	_assert(hero.global_position.distance_to(pos_before) > 0.5, "Server reconciliation adjusts predicted position when divergence > 0.05m")
	hero.queue_free()


func _test_scene_compile_and_load() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "Main scene res://scenes/main.tscn loads cleanly")
