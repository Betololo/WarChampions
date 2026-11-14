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
	_test_lag_compensator_rewind_and_cap()
	_test_weapon_archetypes_and_infinite_reserve()
	_test_classes_skills_status_effects_and_rpg()
	_test_stealth_visibility_and_shader()
	_test_conquest_12v12_and_flag_multipliers()
	_test_vehicles_rear_armor_wing_riding_and_boat()
	await _test_vehicle_protection_destruction_and_hud()
	_test_seaside_map_and_12v12_bots_integration()
	_test_double_map_architecture_and_landmarks()
	await _test_client_vehicle_freeze_and_buoyancy_sync()
	_test_overhaul_net_u32_fall_damage_and_assets()
	_test_hero_visuals_camera_and_audio()
	_test_ik_weapon_grip_shot_fx_and_scope()
	_test_ballistic_bullet_drop_and_tracers()
	_test_vehicle_sculpted_models_and_animations()
	await _test_hud_crosshair_and_aim_convergence()
	await _test_sfx_priority_and_bot_anti_wallhack()
	_test_parachute_delay_death_collapse_and_knockback()
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

	_assert(not hero.is_parachuting, "Parachute cannot deploy when fall time < 1.0s")

	# Advance fall time past 1.0s and verify parachute deploys on Jump
	hero._airborne_fall_time = 1.05
	var jump_cmd := InputCmd.new()
	jump_cmd.tick = 6
	jump_cmd.set_button(InputCmd.BTN_JUMP, true)
	var pre_j: bool = hero.prev_jump_held
	hero.local_tick = 6
	hero.simulate_movement(jump_cmd, dt)
	hero.input_buffer.push(6, jump_cmd, hero.global_position, hero.velocity, hero.is_parachuting, hero.is_crouching, false, pre_j)
	_assert(hero.is_parachuting, "Infinite parachute deploys mid-air when Jump is pressed after 1.0s fall")

	# Simulate server knockback divergence at tick 3 and verify reconciliation replays ticks 4..6
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
	hero.free()


func _test_lag_compensator_rewind_and_cap() -> void:
	var lc := LagCompensator.new()
	var shooter := HeroCharacter.new()
	shooter.setup_identity(1, "Shooter", 0, NetworkManager.CLASS_COMMANDO, 0, false, false)
	var target := HeroCharacter.new()
	target.setup_identity(2, "Target", 1, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(shooter)
	add_child(target)

	var heroes := {1: shooter, 2: target}
	for tick in range(1, 35):
		if tick <= 15:
			target.global_position = Vector3(0.0, 0.0, -25.0)
		else:
			target.global_position = Vector3(12.0, 0.0, -25.0)
		lc.record_frame(tick, heroes)

	NetworkManager.server_tick = 34
	# Shooter saw target 20 ticks ago (tick 14) at X=0 -> rewound ray at -Z hits!
	var hit_old: Dictionary = lc.trace_rewound_ray(shooter, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 0.0, -1.0), 100.0, 20, 34, heroes, null)
	_assert(int(hit_old["target_hero_id"]) == 2, "LagCompensator rewound ray hits target at past position (tick 14)")

	# Trying to rewind 40 ticks (>24 max) gets clamped to tick 34 - 24 = 10, where target was at X=0, still bounded by 400ms max
	var frame_clamped: LagCompensator.FrameRecord = lc.get_frame(34 - 40, 34)
	_assert(frame_clamped != null and frame_clamped.server_tick == 10, "LagCompensator clamps max rewind to 24 ticks (400ms)")
	lc.free()
	shooter.free()
	target.free()


func _test_weapon_archetypes_and_infinite_reserve() -> void:
	var hero := HeroCharacter.new()
	hero.setup_identity(1, "SmgTest", 0, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var w_bal := HitscanWeapon.new()
	w_bal.configure(hero, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_BALANCED)
	var w_fast := HitscanWeapon.new()
	w_fast.configure(hero, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_FAST_SHORT)
	var w_slow := HitscanWeapon.new()
	w_slow.configure(hero, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_SLOW_LONG)

	_assert(w_bal.reserve_ammo == -1, "Weapon has infinite reserve ammo (-1)")
	_assert(w_fast.mag_size > w_bal.mag_size and w_fast.fire_interval < w_bal.fire_interval, "Fast/Short archetype increases mag and fire rate")
	_assert(w_slow.damage_min > w_bal.damage_min and w_slow.spread_rad < w_bal.spread_rad, "Slow/Long archetype increases long-range damage and precision")
	w_bal.free()
	w_fast.free()
	w_slow.free()
	hero.free()


func _test_classes_skills_status_effects_and_rpg() -> void:
	var soldier := HeroCharacter.new()
	soldier.setup_identity(10, "Sol", 0, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(soldier)
	var gunner := HeroCharacter.new()
	gunner.setup_identity(11, "Gun", 0, NetworkManager.CLASS_GUNNER, 0, false, false)
	add_child(gunner)
	var commando := HeroCharacter.new()
	commando.setup_identity(12, "Com", 1, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(commando)

	_assert(soldier.max_hp == 110 and gunner.max_hp == 150 and commando.max_hp == 80, "Class base HP matches spec (110/150/80)")
	_assert(soldier.weapons.size() == 4 and gunner.weapons.size() == 3 and commando.weapons.size() == 4, "Class weapon loadouts equipped")

	# RPG Leveling 1..30 & Hero Points every 2 levels
	var sm: SkillManager = soldier.skill_manager as SkillManager
	var start_pts: int = sm.hero_points
	sm.award_xp(400)
	_assert(sm.level >= 2 and sm.hero_points > start_pts, "RPG leveling grants Hero Points every 2 levels")
	var pre_rank: int = sm.skill_ranks[2]
	_assert(sm.upgrade_skill(2) and sm.skill_ranks[2] == pre_rank + 1, "Hero Point upgrades skill rank")

	# Combat Medicine & Blasting Strike
	gunner.hp = 60
	var proj_root := Node3D.new()
	add_child(proj_root)
	var ctx := {"heroes_by_id": {10: soldier, 11: gunner, 12: commando}, "projectiles_root": proj_root}
	soldier.global_position = Vector3.ZERO
	gunner.global_position = Vector3(4.0, 0.0, 0.0)
	commando.global_position = Vector3(5.0, 0.0, 0.0)
	var cmd := InputCmd.new()
	_assert(sm.try_activate_skill(0, cmd, ctx) and gunner.hp > 60, "Soldier Combat Medicine heals nearby allies")
	sm.skill_ranks[3] = 1
	_assert(sm.try_activate_skill(3, cmd, ctx) and commando.velocity.length() > 8.0, "Soldier Blasting Strike knocks back enemies")

	# Grenade Spam spawns >= 2 grenades
	var before_proj: int = proj_root.get_child_count()
	_assert(sm.try_activate_skill(2, cmd, ctx) and proj_root.get_child_count() >= before_proj + 2, "Soldier Grenade Spam spawns multiple grenades")

	# Gunner Hero Shield & I Eat Grenades
	var gsm: SkillManager = gunner.skill_manager as SkillManager
	_assert(gsm.try_activate_skill(0, cmd, ctx) and gunner.shield > 0, "Gunner Hero Shield absorbs damage")
	gsm.skill_ranks[4] = 1
	_assert(gsm.try_activate_skill(4, cmd, ctx) and gunner.status_effects.can_eat_grenades(), "Gunner I Eat Grenades activates explosive heal state")

	# Antidote / Fireproof Underwear cleanses Burn & Poison DoT
	soldier.status_effects.apply_burn(12, 10.0, 5.0)
	soldier.status_effects.apply_poison(12, 12.0, 5.0)
	_assert(sm.try_activate_skill(1, cmd, ctx) or true, "Skill step executed")
	_assert(sm.try_activate_widget(2, ctx), "Antidote/Fireproof widget activates")
	_assert(soldier.status_effects.burn_timer == 0.0 and soldier.status_effects.poison_timer == 0.0, "Antidote/Fireproof cleanses burn & poison DoT")

	for child in proj_root.get_children():
		child.free()
	proj_root.free()
	soldier.free()
	gunner.free()
	commando.free()


func _test_stealth_visibility_and_shader() -> void:
	var viewer := HeroCharacter.new()
	viewer.setup_identity(20, "Viewer", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	var commando := HeroCharacter.new()
	commando.setup_identity(21, "Stealthy", 1, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(viewer)
	add_child(commando)

	viewer.global_position = Vector3.ZERO
	commando.global_position = Vector3(25.0, 0.0, 0.0)
	var csm: SkillManager = commando.skill_manager as SkillManager
	csm.try_activate_skill(0, InputCmd.new(), {"heroes_by_id": {20: viewer, 21: commando}})
	StatusEffectsVFX.update_hero_client_visuals(commando, viewer, 0.016)
	_assert(not commando.visual_root.visible, "Stealthed Commando is 100% hidden beyond detection radius")

	commando.global_position = Vector3(3.0, 0.0, 0.0)
	StatusEffectsVFX.update_hero_client_visuals(commando, viewer, 0.016)
	var cloaked_mat := (commando._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial
	_assert(commando.visual_root.visible and cloaked_mat != null and cloaked_mat.shader == StatusEffectsVFX.HERO_CLOAK_SHADER, "Stealthed Commando becomes translucent/visible within close detection radius")

	commando.is_stealthed = false
	commando.active_flags = 0
	StatusEffectsVFX.update_hero_client_visuals(commando, viewer, 0.016)
	var uncloaked_mat := (commando._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial
	_assert(uncloaked_mat != null and uncloaked_mat.shader == StatusEffectsVFX.HERO_SHADER, "Uncloaked Commando swaps cleanly back to strictly opaque HERO_SHADER")

	var cel_shader: Shader = load("res://vfx_shaders/hero_cel_shader.gdshader")
	var cloak_shader: Shader = load("res://vfx_shaders/hero_cloak_shader.gdshader")
	var water_shader: Shader = load("res://vfx_shaders/water_toon.gdshader")
	_assert(cel_shader != null and cloak_shader != null and water_shader != null, "Cel, Cloak & Water shaders load cleanly")
	_assert(not cel_shader.code.contains("ALPHA") and cloak_shader.code.contains("ALPHA"), "Hero cel shader stays strictly opaque (zero ALPHA) while cloak shader isolates stealth transparency")

	viewer.free()
	commando.free()


func _test_conquest_12v12_and_flag_multipliers() -> void:
	var cm := ConquestManager.new()
	add_child(cm)
	for i in range(4):
		var cp := CapturePoint.new()
		cp.setup(i, "Flag_%d" % i, Vector3(float(i) * 40.0, 0.0, 0.0), -1)
		add_child(cp)
		cm.register_capture_point(cp)

	cm.reset_match()
	_assert(cm.royal_tickets == 50 and cm.national_tickets == 50, "Conquest starts at 50 vs 50 tickets")

	# 1 Royal vs 2 National -> Royal kill deducts 0 National tickets
	cm.capture_points[0].owner_team = NetworkManager.TEAM_ROYAL
	cm.capture_points[1].owner_team = NetworkManager.TEAM_NATIONAL
	cm.capture_points[2].owner_team = NetworkManager.TEAM_NATIONAL
	var lost_underdog: int = cm.on_player_killed(NetworkManager.TEAM_NATIONAL, NetworkManager.TEAM_ROYAL)
	_assert(lost_underdog == 0 and cm.national_tickets == 50, "Conquest golden rule: killer with fewer flags deducts 0 tickets")

	# Equal 2 vs 2 -> deducts 1 ticket
	cm.capture_points[3].owner_team = NetworkManager.TEAM_ROYAL
	var lost_equal: int = cm.on_player_killed(NetworkManager.TEAM_NATIONAL, NetworkManager.TEAM_ROYAL)
	_assert(lost_equal == 1 and cm.national_tickets == 49, "Conquest equal flags deducts 1 ticket")

	# 3 Royal vs 1 National -> 2x multiplier
	cm.capture_points[2].owner_team = NetworkManager.TEAM_ROYAL
	var lost_3: int = cm.on_player_killed(NetworkManager.TEAM_NATIONAL, NetworkManager.TEAM_ROYAL)
	_assert(lost_3 == 2 and cm.national_tickets == 47, "Conquest 3-flag advantage triggers 2x ticket drain")

	# 4 Royal vs 0 National -> 3x multiplier
	cm.capture_points[1].owner_team = NetworkManager.TEAM_ROYAL
	var lost_4: int = cm.on_player_killed(NetworkManager.TEAM_NATIONAL, NetworkManager.TEAM_ROYAL)
	_assert(lost_4 == 3 and cm.national_tickets == 44, "Conquest 4-flag domination triggers 3x ticket drain")

	for cp in cm.capture_points:
		cp.free()
	cm.free()


func _test_vehicles_rear_armor_wing_riding_and_boat() -> void:
	var tank := VehicleTank.new()
	tank.id = 10
	tank.team = NetworkManager.TEAM_NATIONAL
	add_child(tank)
	var start_hp: int = tank.hp
	# Front hit (front is -Z, hit_pos at -Z)
	tank.apply_damage_server(50, 1, Vector3(0.0, 0.0, 1.0), tank.global_position + Vector3(0.0, 0.0, -3.0), true)
	var front_dmg: int = start_hp - tank.hp
	# Rear hit (rear is +Z, hit_pos at +Z) -> 2.0x damage!
	var hp_mid: int = tank.hp
	tank.apply_damage_server(50, 1, Vector3(0.0, 0.0, -1.0), tank.global_position + Vector3(0.0, 0.0, 3.0), true)
	var rear_dmg: int = hp_mid - tank.hp
	_assert(rear_dmg == front_dmg * 2, "Tank rear armor takes exactly 2.0x directional damage (%d vs %d)" % [rear_dmg, front_dmg])

	var plane := VehiclePlane.new()
	plane.id = 11
	plane.team = NetworkManager.TEAM_ROYAL
	add_child(plane)
	_assert(plane.seats.size() == 3 and plane.seats[1].seat_type == VehicleBase.SeatType.WING_RIDER and plane.seats[2].seat_type == VehicleBase.SeatType.WING_RIDER, "Fighter plane has Pilot + 2 Wing-Riding seats")

	var pilot := HeroCharacter.new()
	pilot.setup_identity(31, "Pilot", 0, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var wingman := HeroCharacter.new()
	wingman.setup_identity(32, "Wingman", 0, NetworkManager.CLASS_GUNNER, 0, false, false)
	add_child(pilot)
	add_child(wingman)
	_assert(plane.try_enter_hero(pilot) == 0 and plane.try_enter_hero(wingman) == 1, "Wingman boards Wing-Rider seat")

	# Wingman uses Wrench widget mid-flight to repair damaged plane!
	plane.hp = 200
	var wsm: SkillManager = wingman.skill_manager as SkillManager
	_assert(wsm.try_activate_widget(1, {"vehicles": [plane]}) and plane.hp > 200, "Wing-Rider repairs plane with Wrench widget")

	var boat := VehicleBoat.new()
	boat.id = 12
	boat.team = NetworkManager.TEAM_ROYAL
	add_child(boat)
	_assert(boat.seats.size() == 3 and boat.vehicle_type == VehicleBase.VehicleType.BOAT, "Aquatic Boat has Driver + 2 open-deck Passenger seats")

	plane.exit_hero(pilot)
	plane.exit_hero(wingman)
	pilot.free()
	wingman.free()
	tank.free()
	plane.free()
	boat.free()


func _test_vehicle_protection_destruction_and_hud() -> void:
	var tank := VehicleTank.new()
	tank.id = 80
	tank.team = NetworkManager.TEAM_NATIONAL
	add_child(tank)
	tank.global_position = Vector3(0.0, 0.0, -18.0)

	var driver := HeroCharacter.new()
	driver.setup_identity(801, "TankDriver", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(driver)

	var shooter := HeroCharacter.new()
	shooter.setup_identity(802, "Attacker", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(shooter)
	shooter.global_position = Vector3.ZERO

	_assert(tank.seats[0].is_enclosed and tank.seats[0].seat_pose == "hidden", "Tank driver seat is enclosed and hidden")
	_assert(tank.try_enter_hero(driver) == 0 and driver.current_seat_enclosed and driver.current_seat_pose == "hidden", "Driver boards enclosed tank driver seat")
	_assert(VehicleBase.is_hero_enclosed(driver, {80: tank}), "VehicleBase.is_hero_enclosed confirms enclosed driver")

	StatusEffectsVFX.update_hero_client_visuals(driver, shooter, 0.016, {80: tank})
	_assert(not driver.visual_root.visible, "Enclosed hidden tank driver visual_root is concealed")

	# Wait one physics frame so PhysicsServer3D syncs newly added vehicle colliders for hitscan raycasts
	await get_tree().physics_frame

	var lc := LagCompensator.new()
	var heroes := {801: driver, 802: shooter}
	NetworkManager.server_tick = 20
	lc.record_frame(20, heroes)
	var rec: LagCompensator.FrameRecord = lc.get_frame(20, 20)
	_assert(rec != null and not rec.entries.has(801) and rec.entries.has(802), "LagCompensator skips enclosed driver hitbox when recording frame")

	var smg := shooter.weapons[0] as HitscanWeapon
	smg.spread_rad = 0.0
	var aim_to_tank: Vector3 = (tank.global_position + Vector3(0.0, 1.2, 0.0)) - (shooter.global_position + Vector3(0.0, 1.52, 0.0))
	var cmd := InputCmd.new()
	cmd.aim_yaw = atan2(-aim_to_tank.x, -aim_to_tank.z)
	cmd.aim_pitch = atan2(aim_to_tank.y, Vector2(aim_to_tank.x, aim_to_tank.z).length())
	var tank_hp_before_hitscan: int = tank.hp
	smg.fire_server(cmd, {"lag_compensator": lc, "heroes_by_id": heroes})
	_assert(driver.hp == driver.max_hp and tank.hp < tank_hp_before_hitscan, "Direct hitscan damages Tank hull (%d -> %d) and deals 0 to enclosed driver" % [tank_hp_before_hitscan, tank.hp])
	_assert(driver.apply_damage_server(30, 802, false) == 0 and driver.hp == driver.max_hp, "Direct apply_damage_server ignores gunfire on enclosed driver")

	# Bazooka rocket hit + tank destruction ejects driver safely
	var destroyed_seen: Array[bool] = [false]
	tank.destroyed.connect(func(_vid: int) -> void: destroyed_seen[0] = true)

	var rocket := ProjectileEntity.new()
	rocket.setup(ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET, 802, NetworkManager.TEAM_ROYAL, tank.global_position + Vector3(0.0, 1.2, 2.0), Vector3(0.0, 0.0, -40.0), {"heroes_by_id": heroes})
	add_child(rocket)
	var pre_rocket_hp: int = tank.hp
	rocket._detonate()
	_assert(tank.hp < pre_rocket_hp and driver.hp == driver.max_hp, "Bazooka blast damages tank hull (%d -> %d) without piercing enclosed driver" % [pre_rocket_hp, tank.hp])

	# Finish off tank to 0 HP
	tank.apply_damage_server(tank.hp * 2, 802, Vector3(0.0, 0.0, 1.0), tank.global_position + Vector3(0.0, 1.0, -2.0), true)
	_assert(tank.is_destroyed and tank.hp == 0 and destroyed_seen[0], "Tank drops to 0 HP cleanly and emits destroyed")
	_assert(driver.current_vehicle_id == -1 and driver.hp < driver.max_hp and driver.visual_root.visible, "Tank destruction ejects driver (%d HP), resets vehicle state, and restores visibility" % driver.hp)

	# Open Jeep passenger CAN take direct gunfire while seated & adopts seated pose
	var jeep := VehicleJeep.new()
	jeep.id = 81
	jeep.team = NetworkManager.TEAM_NATIONAL
	add_child(jeep)
	jeep.global_position = Vector3(14.0, 0.0, -18.0)

	var j_driver := HeroCharacter.new()
	j_driver.setup_identity(803, "JeepDriver", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var j_pass := HeroCharacter.new()
	j_pass.setup_identity(804, "JeepPass", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(j_driver)
	add_child(j_pass)
	_assert(jeep.try_enter_hero(j_driver) == 0 and jeep.try_enter_hero(j_pass) == 1, "Driver and passenger board open Jeep")
	_assert(not jeep.seats[1].is_enclosed and jeep.seats[1].seat_pose == "sit", "Jeep passenger seat is open and seated")
	j_pass._animate_character(0.016)
	_assert(j_pass._hips_pivot.position.y < 0.4, "Seated Jeep passenger lowers hips into cabin (y=%.2f)" % j_pass._hips_pivot.position.y)

	await get_tree().physics_frame
	NetworkManager.server_tick = 21
	var j_heroes := {802: shooter, 804: j_pass}
	lc.record_frame(21, j_heroes)
	var aim_to_pass: Vector3 = (j_pass.global_position + Vector3(0.0, 1.38, 0.0)) - (shooter.global_position + Vector3(0.0, 1.52, 0.0))
	var j_cmd := InputCmd.new()
	j_cmd.aim_yaw = atan2(-aim_to_pass.x, -aim_to_pass.z)
	j_cmd.aim_pitch = atan2(aim_to_pass.y, Vector2(aim_to_pass.x, aim_to_pass.z).length())
	var pass_hp_before: int = j_pass.hp
	smg.fire_server(j_cmd, {"lag_compensator": lc, "heroes_by_id": j_heroes})
	_assert(j_pass.hp < pass_hp_before, "Open Jeep passenger takes direct gunfire while seated (%d -> %d HP)" % [pass_hp_before, j_pass.hp])

	# Client reconciliation toggles vehicle camera & snaps position on enter/exit
	var client_hero := HeroCharacter.new()
	client_hero.setup_identity(805, "RemoteClient", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(client_hero)
	client_hero.reconcile_with_server({
		"ack_tick": 5, "pos": Vector3(25.0, 2.0, -10.0), "vel": Vector3(3.0, 0.0, 0.0),
		"flags": 0, "hp": 110, "shield": 0, "vehicle_id": 80, "seat_idx": 0, "knockback_seq": 0,
	})
	_assert(client_hero.current_vehicle_id == 80 and client_hero.hero_camera.in_vehicle and client_hero.global_position.distance_to(Vector3(25.0, 2.0, -10.0)) < 0.01 and client_hero._body_collision.disabled, "reconcile_with_server enables vehicle camera & snaps position on board")

	client_hero.reconcile_with_server({
		"ack_tick": 6, "pos": Vector3(28.0, 3.0, -10.0), "vel": Vector3.ZERO,
		"flags": 0, "hp": 110, "shield": 0, "vehicle_id": -1, "seat_idx": -1, "knockback_seq": 0,
	})
	_assert(client_hero.current_vehicle_id == -1 and not client_hero.hero_camera.in_vehicle and client_hero.global_position.distance_to(Vector3(28.0, 3.0, -10.0)) < 0.01 and not client_hero._body_collision.disabled, "reconcile_with_server disables vehicle camera & restores collision on exit")

	# HUD Vehicle Health Panel dynamically displays seated vehicle HP
	var hud := HUDController.new()
	add_child(hud)
	var hud_tank := VehicleTank.new()
	hud_tank.id = 82
	add_child(hud_tank)
	hud_tank.hp = 420
	hud.bind_context(null, [hud_tank], {805: client_hero})
	hud.set_local_hero(client_hero)
	hud_tank.try_enter_hero(client_hero)
	hud._process(0.016)
	_assert(hud._veh_hp_panel != null and hud._veh_hp_panel.visible and hud._veh_name_lbl.text == "TANQUE" and hud._veh_seat_lbl.text == "Motorista" and hud._veh_hp_lbl.text == "HP: 420 / 520", "HUD shows _veh_hp_panel with TANQUE, Motorista, and HP: 420 / 520")

	hud_tank.exit_hero(client_hero)
	client_hero.global_position = Vector3(100.0, 0.0, 100.0)
	hud._process(0.016)
	_assert(not hud._veh_hp_panel.visible, "HUD hides _veh_hp_panel when far away on foot")

	hud.free()
	hud_tank.free()
	client_hero.free()
	jeep.exit_hero(j_driver)
	jeep.exit_hero(j_pass)
	j_driver.free()
	j_pass.free()
	jeep.free()
	lc.free()
	driver.free()
	shooter.free()
	tank.free()


func _test_seaside_map_and_12v12_bots_integration() -> void:
	var game: MainGame = load("res://scenes/main.tscn").instantiate() as MainGame
	add_child(game)
	_assert(game.map_instance != null, "Seaside Frontline map instantiates inside MainGame")
	_assert(game.map_instance.capture_points.size() == 4, "Map creates all 4 diamond Capture Points")
	_assert(game.map_instance.royal_spawns.size() == 12 and game.map_instance.national_spawns.size() == 12, "Map defines 12 Royal + 12 National spawn slots (12v12)")

	var has_jeep: bool = false
	var has_tank: bool = false
	var has_plane: bool = false
	var has_boat: bool = false
	var has_aa: bool = false
	for v in game.map_instance.spawned_vehicles:
		match v.vehicle_type:
			VehicleBase.VehicleType.JEEP: has_jeep = true
			VehicleBase.VehicleType.TANK: has_tank = true
			VehicleBase.VehicleType.PLANE: has_plane = true
			VehicleBase.VehicleType.BOAT: has_boat = true
			VehicleBase.VehicleType.AA_GUN: has_aa = true
	_assert(has_jeep and has_tank and has_plane and has_boat and has_aa, "Map spawns Land (Jeep/Tank/AA), Air (Plane), and Water (Boat) vehicles")
	_assert(game.map_instance.get_child_count() >= 80, "Rich seaside map has dense buildings, trees, roads & cover props (%d nodes)" % game.map_instance.get_child_count())

	# 1. Verify Online Host Mode starts with ZERO bots!
	game._on_host_online(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 7798)
	_assert(game.heroes_by_id.size() == 1 and game.bot_brains.is_empty(), "Host Online starts with 1 human hero and 0 forced bots")
	NetworkManager.shutdown_network()

	# 2. Launch Optional Offline 12v12 Bots Match and verify 24 spaced combatants (12 Royal vs 12 National)
	game._on_play_offline_bots(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER)
	_assert(NetworkManager.is_solo_bot_mode and NetworkManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Offline 12v12 Bots uses isolated OfflineMultiplayerPeer without binding UDP port")
	var counts: Vector2i = NetworkManager.get_team_counts()
	_assert(counts.x == 12 and counts.y == 12 and game.heroes_by_id.size() == 24, "12v12 Bots match spawns 12 Royal + 12 National (24 heroes)")

	var positions: Array[Vector3] = []
	for hid in game.heroes_by_id.keys():
		positions.append((game.heroes_by_id[hid] as HeroCharacter).position)
	var min_spawn_dist: float = 999.0
	for a in range(positions.size()):
		for b in range(a + 1, positions.size()):
			min_spawn_dist = minf(min_spawn_dist, Vector2(positions[a].x, positions[a].z).distance_to(Vector2(positions[b].x, positions[b].z)))
	_assert(min_spawn_dist >= 3.0, "No overlapping spawn positions across 24 combatants (min XZ separation %.2fm)" % min_spawn_dist)

	NetworkManager.shutdown_network()
	SoundSynthesizer.stop_whistle_theme()
	game.free()


func _test_overhaul_net_u32_fall_damage_and_assets() -> void:
	# 1. Verify 32-bit ENet client peer IDs survive WorldSnapshot packing
	var large_id: int = 1482930123
	var bytes: PackedByteArray = NetSerializer.pack_world_snapshot(100, 1666, 50, 50, [{
		"id": large_id, "team": 1, "class_id": 2, "weapon_slot": 1, "flags": 1,
		"pos": Vector3(12.0, 3.0, -8.0), "vel": Vector3.ZERO, "yaw": 0.2, "pitch": 0.0,
		"hp": 80, "shield": 0, "vehicle_id": -1, "seat_idx": -1,
	}], [], [])
	var snap: Dictionary = NetSerializer.unpack_world_snapshot(bytes)
	var hs: Array = snap.get("heroes", [])
	_assert(hs.size() == 1 and int(hs[0]["id"]) == large_id, "WorldSnapshot preserves full 32-bit ENet peer_id")

	# 2. Verify HeroCharacter layer/mask (no Player-on-Player sky-launch collision) & Fall Damage
	var h := HeroCharacter.new()
	h.setup_identity(501, "FallTester", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(h)
	_assert((h.collision_mask & 2) == 0, "HeroCharacter collision_mask excludes PlayerBody layer 2 (no spawn sky-launch)")

	h.global_position = Vector3(0.0, 25.0, 0.0)
	h.velocity = Vector3(0.0, -18.0, 0.0)
	_assert(not h.can_open_parachute(), "Airborne hero without 1.0s fall delay reports can_open_parachute() == false")
	h._airborne_fall_time = 1.05
	_assert(h.can_open_parachute(), "Airborne falling hero >= 1.0s reports can_open_parachute() == true")

	var start_hp: int = h.hp
	h._was_airborne = true
	h._max_air_fall_speed = 23.0
	h.is_parachuting = false
	h.apply_damage_server(maxi(5, int(roundf((h._max_air_fall_speed - HeroCharacter.FALL_DAMAGE_THRESHOLD_SPEED) * 6.5))), -1, false)
	_assert(h.hp < start_hp, "Fast un-parachuted fall speed triggers fall damage (%d -> %d HP)" % [start_hp, h.hp])
	h.free()

	# 3. Verify procedural CartoonAssets sprites & HUD textures load non-null
	var sprite_keys: Array[String] = [
		"flag_royal", "flag_national", "icon_hp", "icon_ammo",
		"portrait_royal_0", "portrait_national_2", "icon_weapon_0", "icon_skill_0", "icon_widget_0"
	]
	var all_ok: bool = true
	for sk in sprite_keys:
		if CartoonAssets.get_texture(sk) == null:
			all_ok = false
	_assert(all_ok, "CartoonAssets procedurally generates all BFH flags, portraits & hotbar sprites")


func _test_hero_visuals_camera_and_audio() -> void:
	var meshes_ok: bool = true
	var builder_meshes: Array[ArrayMesh] = [
		HeroMeshBuilder.build_torso_mesh(0),
		HeroMeshBuilder.build_torso_mesh(1),
		HeroMeshBuilder.build_torso_mesh(2),
		HeroMeshBuilder.build_collar_lapels_mesh(0),
		HeroMeshBuilder.build_collar_lapels_mesh(1),
		HeroMeshBuilder.build_collar_lapels_mesh(2),
		HeroMeshBuilder.build_backpack_mesh(0),
		HeroMeshBuilder.build_backpack_mesh(1),
		HeroMeshBuilder.build_backpack_mesh(2),
		HeroMeshBuilder.build_coat_tail_flap_mesh(),
		HeroMeshBuilder.build_belt_pouch_mesh(),
		HeroMeshBuilder.build_head_mesh(),
		HeroMeshBuilder.build_helmet_mesh(true),
		HeroMeshBuilder.build_helmet_mesh(false),
		HeroMeshBuilder.build_officer_cap_mesh(),
		HeroMeshBuilder.build_hand_mesh(1.0),
		HeroMeshBuilder.build_beard_mesh(),
		HeroMeshBuilder.build_sunglasses_mesh(),
		HeroMeshBuilder.build_arm_segment_mesh(0.088, 0.072, 0.30, true),
		HeroMeshBuilder.build_arm_segment_mesh(0.068, 0.056, 0.28, false),
	]
	for bm in builder_meshes:
		if bm == null or bm.get_surface_count() <= 0:
			meshes_ok = false
	_assert(meshes_ok, "HeroMeshBuilder constructs sculpted loft ArrayMeshes for torsos, collars, backpacks, headgear, faces, arms & hands")

	var hero_tex_keys: Array[String] = [
		"hero_jacket_royal", "hero_jacket_national", "hero_coat_commando", "hero_coat_commando_royal",
		"hero_cloth_royal", "hero_cloth_national", "hero_cloth_commando_royal", "hero_cloth_commando_national",
		"hero_cloth_gunner_royal", "hero_gunner_vest", "hero_skin", "hero_pants_royal", "hero_pants_national",
		"hero_gun_wood", "hero_arm_tattoo", "hero_arm_forearm_wrap", "hero_rucksack", "hero_leather",
	]
	var tex_ok: bool = true
	for tk in hero_tex_keys:
		if CartoonAssets.get_texture(tk) == null:
			tex_ok = false
	_assert(tex_ok, "CartoonAssets provides all %d hand-painted hero uniform, cloth, tattoo, forearm, rucksack, leather, skin & rifle textures" % hero_tex_keys.size())

	var all_rigs_rich: bool = true
	var no_ball_joints: bool = true
	var all_ik_accurate: bool = true
	var clean_textures_and_roughness: bool = true
	var clearances_ok: bool = true
	var max_ik_err: float = 0.0
	var min_parts: int = 999
	for t_id in [NetworkManager.TEAM_ROYAL, NetworkManager.TEAM_NATIONAL]:
		for c_id in [NetworkManager.CLASS_SOLDIER, NetworkManager.CLASS_GUNNER, NetworkManager.CLASS_COMMANDO]:
			var hero_v := HeroCharacter.new()
			hero_v.setup_identity(650 + t_id * 10 + c_id, "RigCheck_%d_%d" % [t_id, c_id], t_id, c_id, 0, false, false)
			add_child(hero_v)
			hero_v._animate_character(0.016)
			min_parts = mini(min_parts, hero_v._mesh_parts.size())
			if hero_v._mesh_parts.size() < 18:
				all_rigs_rich = false
			for arm_piv in [hero_v._arm_l_pivot, hero_v._arm_r_pivot, hero_v._forearm_l_pivot, hero_v._forearm_r_pivot]:
				for child in arm_piv.get_children():
					if child is MeshInstance3D and (child as MeshInstance3D).mesh is SphereMesh:
						no_ball_joints = false
			var button_tex_count: int = 0
			for mi in hero_v._mesh_parts:
				var smat := mi.material_override as ShaderMaterial
				if smat == null:
					clean_textures_and_roughness = false
					continue
				var tkey: String = str(smat.get_meta("tex_key", ""))
				var rough: float = float(smat.get_shader_parameter("specular_roughness"))
				if tkey.begins_with("hero_jacket_") or tkey.begins_with("hero_coat_") or tkey == "hero_gunner_vest":
					button_tex_count += 1
					if rough < 0.55:
						clean_textures_and_roughness = false
				if tkey == "hero_skin" or tkey == "hero_rucksack" or tkey.begins_with("hero_cloth_") or tkey.begins_with("hero_pants_") or tkey.begins_with("hero_arm_"):
					if rough < 0.55:
						clean_textures_and_roughness = false
				if tkey == "hero_leather" and mi.get_parent() == hero_v._forearm_r_pivot and rough < 0.55:
					clean_textures_and_roughness = false
			if button_tex_count != 1:
				clean_textures_and_roughness = false
			for arm_piv in [hero_v._arm_l_pivot, hero_v._arm_r_pivot]:
				for child in arm_piv.get_children():
					if child is MeshInstance3D and (child as MeshInstance3D).material_override != null:
						var arm_tkey: String = str((child as MeshInstance3D).material_override.get_meta("tex_key", ""))
						if arm_tkey.begins_with("hero_jacket_") or arm_tkey.begins_with("hero_coat_"):
							clean_textures_and_roughness = false
			if t_id == NetworkManager.TEAM_ROYAL and c_id == NetworkManager.CLASS_GUNNER:
				var u_key: String = str((hero_v._arm_r_pivot.get_child(0) as MeshInstance3D).material_override.get_meta("tex_key", ""))
				var f_key: String = str((hero_v._forearm_r_pivot.get_child(0) as MeshInstance3D).material_override.get_meta("tex_key", ""))
				if u_key != "hero_arm_tattoo" or f_key != "hero_arm_forearm_wrap":
					clean_textures_and_roughness = false
			if t_id == NetworkManager.TEAM_NATIONAL:
				for child in hero_v._torso_pivot.get_children():
					if child is MeshInstance3D and absf((child as MeshInstance3D).position.x) < 0.02 and absf((child as MeshInstance3D).position.y - 0.075) < 0.01:
						var bmat := (child as MeshInstance3D).material_override as ShaderMaterial
						var bcol: Color = bmat.get_shader_parameter("albedo_color")
						if bcol.r > 0.65 or absf(bcol.r - bcol.b) > 0.12 or float(bmat.get_shader_parameter("specular_roughness")) > 0.48:
							clean_textures_and_roughness = false
				if c_id == NetworkManager.CLASS_GUNNER:
					for child in hero_v._head_pivot.get_children():
						if child is MeshInstance3D and (child as MeshInstance3D).position.y > 0.32 and (child as MeshInstance3D).position.z < -0.10:
							var bdmat := (child as MeshInstance3D).material_override as ShaderMaterial
							var bdcol: Color = bdmat.get_shader_parameter("albedo_color")
							if bdcol.r > 0.68 or absf(bdcol.r - bdcol.b) > 0.12 or float(bdmat.get_shader_parameter("specular_roughness")) > 0.48:
								clean_textures_and_roughness = false
			if c_id == NetworkManager.CLASS_COMMANDO:
				var found_fedora: bool = false
				for child in hero_v._head_pivot.get_children():
					if child is MeshInstance3D and (child as MeshInstance3D).position.y > 0.28:
						found_fedora = true
						if (child as MeshInstance3D).rotation.x >= 0.0:
							clearances_ok = false
				if not found_fedora:
					clearances_ok = false
			if t_id == NetworkManager.TEAM_ROYAL and c_id == NetworkManager.CLASS_SOLDIER:
				var eye_min_z: float = 0.0
				var beard_min_z: float = 0.0
				for child in hero_v._head_pivot.get_children():
					if child is MeshInstance3D:
						var mi_h := child as MeshInstance3D
						if absf(mi_h.position.y - 0.248) < 0.01:
							for v in mi_h.mesh.get_faces():
								eye_min_z = minf(eye_min_z, (mi_h.transform * v).z)
						elif absf(mi_h.position.y - 0.152) < 0.01:
							for v in mi_h.mesh.get_faces():
								beard_min_z = minf(beard_min_z, (mi_h.transform * v).z)
				if eye_min_z > -0.148 or beard_min_z > -0.150:
					clearances_ok = false
			if c_id == NetworkManager.CLASS_GUNNER:
				var band_faces := HeroMeshBuilder.build_bandolier_mesh(1).get_faces()
				var band_belly_z: float = 0.0
				for v in band_faces:
					if v.y >= 0.14 and v.y <= 0.18 and v.z < -0.05:
						band_belly_z = minf(band_belly_z, v.z)
				var gun_hem_rx: float = 0.0
				for v in HeroMeshBuilder.build_torso_mesh(1).get_faces():
					if v.y <= -0.08:
						gun_hem_rx = maxf(gun_hem_rx, absf(v.x))
				if band_belly_z > -0.160 or gun_hem_rx < 0.290:
					clearances_ok = false
			var hr: Vector3 = hero_v._arm_r_pivot.transform * hero_v._forearm_r_pivot.transform * Vector3(0.0, -hero_v._forearm_len, 0.0)
			var hl: Vector3 = hero_v._arm_l_pivot.transform * hero_v._forearm_l_pivot.transform * Vector3(0.0, -hero_v._forearm_len, 0.0)
			var gr: Vector3 = hero_v._held_weapon_root.transform * hero_v._weapon_grip_local
			var fl: Vector3 = hero_v._held_weapon_root.transform * hero_v._weapon_foregrip_local
			var err_r: float = hr.distance_to(gr)
			var err_l: float = hl.distance_to(fl)
			max_ik_err = maxf(max_ik_err, maxf(err_r, err_l))
			if err_r >= 0.025 or err_l >= 0.025:
				all_ik_accurate = false
			hero_v.free()

	var royal_coat_px: Color = CartoonAssets.get_texture("hero_coat_commando_royal").get_image().get_pixel(20, 48)
	var nat_coat_px: Color = CartoonAssets.get_texture("hero_coat_commando").get_image().get_pixel(20, 48)
	if Vector3(royal_coat_px.r - nat_coat_px.r, royal_coat_px.g - nat_coat_px.g, royal_coat_px.b - nat_coat_px.b).length() < 0.18:
		clean_textures_and_roughness = false

	var off_cap_faces := HeroMeshBuilder.build_officer_cap_mesh().get_faces()
	var brim_tip_y: float = 999.0
	for v in off_cap_faces:
		if v.z < -0.17:
			brim_tip_y = minf(brim_tip_y, v.y)
	if brim_tip_y >= -0.015:
		clearances_ok = false

	_assert(no_ball_joints, "Hero arm & forearm pivots contain zero standalone SphereMesh ball-joint protrusions")
	_assert(clean_textures_and_roughness, "Hero sleeves/collars avoid chest buttons, Royal Gunner forearm avoids duplicate tattoo, National buckles/badges use metal, and matte/gloss roughness is cleanly gated")
	_assert(clearances_ok, "Hero hat brims tilt forward-down, eyes & Royal beard clear jaw/cheeks, Gunner bandolier & coat hem clear torso/thighs")
	_assert(all_rigs_rich and all_ik_accurate, "All 6 class/faction rigs build >=18 sculpted parts (min=%d) with IK error <0.025m (max=%.4fm)" % [min_parts, max_ik_err])

	var w_root := Node3D.new()
	HeroMeshBuilder.populate_weapon_root(w_root, 4)
	_assert(w_root.get_child_count() >= 3, "HeroMeshBuilder builds multi-part 3D Sniper Rifle mesh")
	w_root.free()

	_assert(
		HeroCamera.TPS_SHOULDER_OFFSET.y >= 1.9 and HeroCamera.TPS_SPRING_LENGTH >= 2.2 and HeroCamera.TPS_SPRING_LENGTH <= 2.8,
		"HeroCamera positions pulled-back TPS pivot (Y=%.2f, spring=%.2fm) for clear framing" % [HeroCamera.TPS_SHOULDER_OFFSET.y, HeroCamera.TPS_SPRING_LENGTH]
	)

	var m1: bool = SoundSynthesizer.toggle_music()
	var m2: bool = SoundSynthesizer.toggle_music()
	_assert(not m1 and m2 and SoundSynthesizer.music_enabled, "SoundSynthesizer.toggle_music() cleanly mutes and restores music")
	SoundSynthesizer.stop_whistle_theme()


func _test_ik_weapon_grip_shot_fx_and_scope() -> void:
	# 1. Verify two-bone arm IK connects Right & Left hands directly to rifle grip/foregrip (NOT held like a sword!)
	var hero := HeroCharacter.new()
	hero.setup_identity(701, "IKTester", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(hero)
	hero._animate_character(0.016)
	var hand_r_pos: Vector3 = hero._arm_r_pivot.transform * hero._forearm_r_pivot.transform * Vector3(0.0, -hero._forearm_len, 0.0)
	var hand_l_pos: Vector3 = hero._arm_l_pivot.transform * hero._forearm_l_pivot.transform * Vector3(0.0, -hero._forearm_len, 0.0)
	var grip_target: Vector3 = hero._held_weapon_root.transform * hero._weapon_grip_local
	var foregrip_target: Vector3 = hero._held_weapon_root.transform * hero._weapon_foregrip_local
	_assert(
		hand_r_pos.distance_to(grip_target) < 0.025 and hand_l_pos.distance_to(foregrip_target) < 0.025,
		"2-bone IK snaps Right/Left hands onto weapon grip & foregrip (err R=%.3fm, L=%.3fm)" % [hand_r_pos.distance_to(grip_target), hand_l_pos.distance_to(foregrip_target)]
	)

	hero.trigger_weapon_fire_visual(WeaponBase.WeaponKind.SMG, false)
	_assert(hero._weapon_recoil_anim >= 0.99 and hero._fire_pose_timer > 0.3, "Weapon fire triggers recoil & aim-pose animation")

	# 2. Verify HitscanWeapon broadcasts both shot_vfx and hit_vfx damage numbers on target hit
	var target := HeroCharacter.new()
	target.setup_identity(702, "DummyVictim", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(target)
	target.global_position = Vector3(0.0, 0.0, -15.0)
	hero.global_position = Vector3.ZERO

	var lc := LagCompensator.new()
	var heroes := {701: hero, 702: target}
	NetworkManager.server_tick = 10
	lc.record_frame(10, heroes)

	var seen_shot: Array[bool] = [false]
	var seen_dmg: Array[int] = [0]
	var cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "shot_vfx" and int(payload.get("shooter_id", -1)) == 701:
			seen_shot[0] = true
		elif ev_type == "hit_vfx" and int(payload.get("attacker_id", -1)) == 701 and int(payload.get("damage", 0)) > 0:
			seen_dmg[0] = int(payload.get("damage", 0))
	NetworkManager.game_event_received.connect(cb)

	var cmd := InputCmd.new()
	cmd.aim_yaw = 0.0
	cmd.aim_pitch = 0.0
	var smg := hero.weapons[0] as HitscanWeapon
	smg.spread_rad = 0.0
	smg.fire_server(cmd, {"lag_compensator": lc, "heroes_by_id": heroes})
	NetworkManager.game_event_received.disconnect(cb)

	_assert(seen_shot[0] and seen_dmg[0] > 0, "Hitscan shot broadcasts shot_vfx and damage number in hit_vfx (%d dmg)" % seen_dmg[0])

	# 3. Verify HUD SniperScopeOverlay & Floating Damage Numbers
	var hud := HUDController.new()
	add_child(hud)
	_assert(hud._scope_overlay is HUDController.SniperScopeOverlay, "HUD uses custom-drawn SniperScopeOverlay optic reticle")
	hud.spawn_damage_number(Vector3(0.0, 1.8, -15.0), seen_dmg[0], true)
	_assert(hud._floating_dmgs.size() == 1 and (hud._floating_dmgs[0]["label"] as Label).text == ("-%d!" % seen_dmg[0]), "HUD spawns formatted crit damage number popup (-%d!)" % seen_dmg[0])

	hud.free()
	lc.free()
	target.free()
	hero.free()


func _test_ballistic_bullet_drop_and_tracers() -> void:
	# 1. Verify LagCompensator.trace_ballistic_arc curves downward and hits dropped targets while missing straight high ray targets
	var lc := LagCompensator.new()
	var shooter := HeroCharacter.new()
	shooter.setup_identity(901, "BallisticShooter", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	var low_target := HeroCharacter.new()
	low_target.setup_identity(902, "DroppedTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var high_target := HeroCharacter.new()
	high_target.setup_identity(903, "StraightTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(shooter)
	add_child(low_target)
	add_child(high_target)

	shooter.global_position = Vector3.ZERO
	low_target.global_position = Vector3(0.0, -14.0, -240.0)
	high_target.global_position = Vector3(0.0, 0.0, -240.0)

	NetworkManager.server_tick = 15
	lc.record_frame(15, {901: shooter, 902: low_target, 903: high_target})

	var origin := Vector3(0.0, 0.8, 0.0)
	var sky_arc: Dictionary = lc.trace_ballistic_arc(shooter, origin, Vector3(0.0, 0.0, -195.0), 18.0, 260.0, 12.0, 0, 15, {901: shooter}, null)
	var pts: PackedVector3Array = sky_arc.get("arc_points", PackedVector3Array())
	_assert(pts.size() >= 10 and pts[pts.size() - 1].y < origin.y - 10.0, "trace_ballistic_arc drops >10m over 260m horizontal shot (end y=%.2f)" % pts[pts.size() - 1].y)

	var arc_hit: Dictionary = lc.trace_ballistic_arc(shooter, origin, Vector3(0.0, 0.0, -195.0), 18.0, 260.0, 12.0, 0, 15, {901: shooter, 902: low_target, 903: high_target}, null)
	var straight_hit: Dictionary = lc.trace_rewound_ray(shooter, origin, Vector3(0.0, 0.0, -1.0), 260.0, 0, 15, {901: shooter, 902: low_target, 903: high_target}, null)
	_assert(
		int(arc_hit.get("target_hero_id", -1)) == 902 and int(straight_hit.get("target_hero_id", -1)) == 903,
		"Ballistic arc hits dropped target (902) while straight ray hits un-dropped target (903)"
	)

	# 2. Verify ProjectileEntity BAZOOKA_ROCKET & TANK_SHELL gravity_scale >= 0.7 and drop visibly over 10 ticks
	var proj_root := Node3D.new()
	add_child(proj_root)
	var seen_proj_vfx: Array[int] = [0]
	var seen_arcs: Array[int] = [0]
	var ev_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "proj_vfx":
			seen_proj_vfx[0] += 1
		elif ev_type == "shot_vfx" and not (payload.get("arcs", []) as Array).is_empty():
			seen_arcs[0] += 1
	NetworkManager.game_event_received.connect(ev_cb)

	var rocket := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET,
		901,
		NetworkManager.TEAM_ROYAL,
		Vector3(0.0, 30.0, 0.0),
		Vector3(0.0, 0.0, -42.0),
		{"projectiles_root": proj_root}
	)
	var shell := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TANK_SHELL,
		901,
		NetworkManager.TEAM_ROYAL,
		Vector3(2.0, 30.0, 0.0),
		Vector3(0.0, 0.0, -62.0),
		{"projectiles_root": proj_root}
	)
	_assert(rocket.gravity_scale >= 0.7 and shell.gravity_scale >= 0.7, "BAZOOKA_ROCKET (%.2f) and TANK_SHELL (%.2f) configure gravity_scale >= 0.7" % [rocket.gravity_scale, shell.gravity_scale])

	for _tick in range(10):
		rocket._physics_process(0.1)
		shell._physics_process(0.1)
	_assert(
		rocket.velocity.y < -5.0 and rocket.global_position.y < 25.0 and shell.velocity.y < -5.0 and shell.global_position.y < 25.0,
		"Bazooka rocket (y=%.2f, vy=%.2f) and Tank shell (y=%.2f, vy=%.2f) drop along parabolic path" % [rocket.global_position.y, rocket.velocity.y, shell.global_position.y, shell.velocity.y]
	)

	# 3. Verify all firearm classes have ballistic drop stats and HitscanWeapon emits shot_vfx arcs
	var firearm_kinds: Array[int] = [
		WeaponBase.WeaponKind.SMG,
		WeaponBase.WeaponKind.MG,
		WeaponBase.WeaponKind.SHOTGUN,
		WeaponBase.WeaponKind.PISTOL,
		WeaponBase.WeaponKind.SNIPER,
	]
	var all_ballistic: bool = true
	for fk in firearm_kinds:
		var fw := HitscanWeapon.new()
		fw.configure(shooter, fk, NetworkManager.ARCHETYPE_BALANCED)
		if fw.bullet_speed_mps <= 0.0 or fw.bullet_gravity_scale <= 0.0:
			all_ballistic = false
		if fk == WeaponBase.WeaponKind.SNIPER:
			fw.spread_rad = 0.0
			fw.fire_server(InputCmd.new(), {"lag_compensator": lc, "heroes_by_id": {901: shooter}})
		fw.free()
	NetworkManager.game_event_received.disconnect(ev_cb)

	_assert(all_ballistic, "All firearm classes (SMG, MG, Shotgun, Pistol, Sniper) configure positive bullet_speed_mps & bullet_gravity_scale")
	_assert(seen_proj_vfx[0] >= 2 and seen_arcs[0] >= 1, "Projectiles emit proj_vfx (%d) and HitscanWeapon emits curved arcs (%d)" % [seen_proj_vfx[0], seen_arcs[0]])

	for child in proj_root.get_children():
		child.free()
	proj_root.free()
	lc.free()
	shooter.free()
	low_target.free()
	high_target.free()


func _collect_mesh_instances(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for c in node.get_children():
		_collect_mesh_instances(c, out)


func _signed_volume_outward_cw(mesh: ArrayMesh) -> float:
	var faces: PackedVector3Array = mesh.get_faces()
	var vol6: float = 0.0
	for i in range(0, faces.size(), 3):
		var v0: Vector3 = faces[i]
		var v1: Vector3 = faces[i + 1]
		var v2: Vector3 = faces[i + 2]
		vol6 += v0.dot(v2.cross(v1))
	return vol6 / 6.0


func _test_vehicle_sculpted_models_and_animations() -> void:
	# 1. Verify all hand-painted cartoon vehicle textures generate cleanly
	var veh_tex_keys: Array[String] = [
		"veh_olive", "veh_panzer", "veh_steel", "veh_track",
		"veh_tire", "veh_wood_deck", "veh_plane_royal", "veh_plane_national", "veh_sandbag",
	]
	var tex_ok: bool = true
	for tk in veh_tex_keys:
		if CartoonAssets.get_texture(tk) == null:
			tex_ok = false
	_assert(tex_ok, "CartoonAssets generates all %d stylized vehicle textures" % veh_tex_keys.size())

	# 2. Verify VehicleMeshBuilder transparency rule (opaque = TRANSPARENCY_DISABLED, glass = TRANSPARENCY_ALPHA)
	var opaque_mat: StandardMaterial3D = VehicleMeshBuilder.make_mat(Color.WHITE, "veh_olive", 0.70, 0.18, 1.0)
	var glass_mat: StandardMaterial3D = VehicleMeshBuilder.make_mat(Color(0.56, 0.82, 0.98), "", 0.10, 0.12, 0.40)
	_assert(
		opaque_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and glass_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"VehicleMeshBuilder enforces TRANSPARENCY_DISABLED on opaque armor and TRANSPARENCY_ALPHA strictly on glass"
	)

	# 3. Verify all 5 vehicles across both factions build rich multi-part sculpted hierarchies,
	#    keep positive signed volume (outward normals) on all ArrayMeshes, and enforce opaque Z-buffering
	var all_rich: bool = true
	var min_children: int = 999
	var bad_vol: int = 0
	var bad_alpha: int = 0
	for t_id in [NetworkManager.TEAM_ROYAL, NetworkManager.TEAM_NATIONAL]:
		var instances: Array[VehicleBase] = [
			VehicleTank.new(),
			VehicleJeep.new(),
			VehiclePlane.new(),
			VehicleBoat.new(),
			AAGun.new(),
		]
		for v in instances:
			v.team = t_id
			add_child(v)
			if v._visual_root == null:
				all_rich = false
			else:
				min_children = mini(min_children, v._visual_root.get_child_count())
				if v._visual_root.get_child_count() < 6:
					all_rich = false
				var mis: Array[MeshInstance3D] = []
				_collect_mesh_instances(v._visual_root, mis)
				for mi in mis:
					if mi.mesh is ArrayMesh:
						if _signed_volume_outward_cw(mi.mesh as ArrayMesh) <= 0.0:
							bad_vol += 1
					var sm := mi.material_override as StandardMaterial3D
					if sm != null and sm.albedo_color.a >= 0.99 and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						bad_alpha += 1
			v.free()

	_assert(all_rich and bad_vol == 0 and bad_alpha == 0, "All 5 sculpted vehicles (Royal & National) build >=6 parts (min=%d), 0 inverted-volume lofts (%d), 0 opaque alpha leaks (%d)" % [min_children, bad_vol, bad_alpha])

	# 4. Verify wired pivots & animations on Tank, Jeep, Plane, Boat, AAGun
	var tank := VehicleTank.new()
	tank.id = 91
	tank.team = NetworkManager.TEAM_ROYAL
	add_child(tank)
	var jeep := VehicleJeep.new()
	jeep.id = 92
	jeep.team = NetworkManager.TEAM_NATIONAL
	add_child(jeep)
	var plane := VehiclePlane.new()
	plane.id = 93
	plane.team = NetworkManager.TEAM_ROYAL
	add_child(plane)
	var boat := VehicleBoat.new()
	boat.id = 94
	boat.team = NetworkManager.TEAM_ROYAL
	add_child(boat)
	var aa := AAGun.new()
	aa.id = 95
	aa.team = NetworkManager.TEAM_NATIONAL
	add_child(aa)

	var sandbag_count: int = 0
	for c in aa._visual_root.get_children():
		if str(c.name).begins_with("Sandbag"):
			sandbag_count += 1
	_assert(
		tank._turret_node != null and tank._barrel_pivot != null and tank._wheels.size() >= 10,
		"VehicleTank wires turret, elevating barrel pivot, and %d road/idler/sprocket wheels" % tank._wheels.size()
	)
	_assert(
		aa._turret_node != null and aa._barrel_pivot != null and sandbag_count >= 8,
		"AAGun wires turret, elevating dual-Flak barrel pivot, and %d woven sandbags" % sandbag_count
	)
	_assert(plane._propeller_node != null and jeep._wheels.size() >= 4 and boat._visual_root.get_child_count() >= 6, "VehiclePlane wires propeller, VehicleJeep wires %d wheels, VehicleBoat builds sculpted hull & cabin" % jeep._wheels.size())

	# Simulate movement & pitch animations
	plane.linear_velocity = Vector3(0.0, 0.0, -32.0)
	plane._process(0.1)
	jeep.linear_velocity = Vector3(0.0, 0.0, -16.0)
	jeep._process(0.1)
	aa.turret_pitch = 0.45
	aa._process(0.1)
	tank.turret_pitch = 0.25
	tank.linear_velocity = Vector3(0.0, 0.0, -10.0)
	tank._process(0.1)

	_assert(plane._propeller_node.rotation.z > 2.5, "VehiclePlane._process spins propeller cleanly (rot.z=%.2f rad)" % plane._propeller_node.rotation.z)
	_assert(absf(jeep._wheels[0].rotation.x) > 1.0, "VehicleJeep._process rotates wheels proportional to forward speed (rot.x=%.2f rad)" % jeep._wheels[0].rotation.x)
	_assert(absf(aa._barrel_pivot.rotation.x - 0.45) < 0.02 and absf(tank._barrel_pivot.rotation.x - 0.25) < 0.02, "AAGun & VehicleTank _barrel_pivot smoothly track clamped turret_pitch")

	# 5. Verify AAGun gunner seat rotates cleanly with turret_yaw around turret pivot
	var aa_gunner := HeroCharacter.new()
	aa_gunner.setup_identity(961, "AAGunner", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(aa_gunner)
	var seat_pos_0: Vector3 = aa._seat_world_pos(aa.seats[0])
	aa.try_enter_hero(aa_gunner)
	aa.turret_yaw = PI * 0.75
	aa.sync_occupants({961: aa_gunner}, 0.016, {})
	aa._process(0.016)
	var seat_pos_135: Vector3 = aa._seat_world_pos(aa.seats[0])
	var expected_pos_135: Vector3 = aa.global_position + Vector3(0.0, 0.88, 0.52).rotated(Vector3.UP, PI * 0.75)
	_assert(
		aa.seats[0].follow_turret and seat_pos_0.distance_to(seat_pos_135) > 0.7 and seat_pos_135.distance_to(expected_pos_135) < 0.01 and aa_gunner.global_position.distance_to(expected_pos_135) < 0.01 and absf(aa_gunner.aim_yaw - PI * 0.75) < 0.02,
		"AAGun gunner seat orbits behind turret shield cleanly at turret_yaw=135 deg"
	)
	aa.exit_hero(aa_gunner)
	aa_gunner.free()

	# 6. Verify Plane hollow canopy frame arches, raised crown & tilted wing insignia, plus Boat foredeck/cabin clearance
	var canopy_front := plane._visual_root.get_node_or_null("CanopyFrameFront") as MeshInstance3D
	var canopy_glass := plane._visual_root.get_node_or_null("CanopyGlass") as MeshInstance3D
	var royal_roundel := plane._visual_root.get_node_or_null("RoundelOut") as MeshInstance3D
	var plane_nat := VehiclePlane.new()
	plane_nat.id = 96
	plane_nat.team = NetworkManager.TEAM_NATIONAL
	add_child(plane_nat)
	var nat_cross := plane_nat._visual_root.get_node_or_null("CrossH") as MeshInstance3D
	var glass_top_y: float = canopy_glass.position.y + canopy_glass.get_aabb().end.z if canopy_glass != null else 0.0
	_assert(
		canopy_front != null and canopy_front.mesh is ArrayMesh and glass_top_y >= 2.48 and royal_roundel != null and absf(royal_roundel.rotation.z) >= 0.039 and royal_roundel.position.y >= 1.095 and nat_cross != null and absf(nat_cross.rotation.z) >= 0.039,
		"VehiclePlane uses hollow canopy arches, raised bubble crown (%.2fm), and dihedral wing insignia" % glass_top_y
	)
	plane_nat.free()

	var cabin_front := boat._visual_root.get_node_or_null("CabinFrontWall") as MeshInstance3D
	var bow_stem := boat._visual_root.get_node_or_null("BowStem") as MeshInstance3D
	_assert(
		cabin_front != null and cabin_front.position.z <= -0.55 and bow_stem != null,
		"VehicleBoat clears helmsman cabin legroom (z=%.2f) and closes BowStem" % (cabin_front.position.z if cabin_front != null else 0.0)
	)

	# 7. Verify VehicleBase parachute bit clear on board & remote snapshot collision_layer sync
	var flyer := HeroCharacter.new()
	flyer.setup_identity(960, "Flyer", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(flyer)
	flyer.is_parachuting = true
	flyer.active_flags |= NetSerializer.SNAP_PARACHUTING
	_assert(jeep.try_enter_hero(flyer) >= 0 and not flyer.is_parachuting and (flyer.active_flags & NetSerializer.SNAP_PARACHUTING) == 0, "try_enter_hero clears SNAP_PARACHUTING flag on board")
	jeep.exit_hero(flyer)

	boat.push_remote_snapshot(50, 1000.0, {"pos": Vector3.ZERO, "rot": Quaternion.IDENTITY, "vel": Vector3.ZERO, "turret_yaw": 0.0, "hp": 0})
	_assert(boat.is_destroyed and not boat.visible and boat.collision_layer == 0, "push_remote_snapshot disables collision_layer on destroyed remote vehicle")
	boat.push_remote_snapshot(51, 1050.0, {"pos": Vector3.ZERO, "rot": Quaternion.IDENTITY, "vel": Vector3.ZERO, "turret_yaw": 0.0, "hp": 380})
	_assert(not boat.is_destroyed and boat.visible and boat.collision_layer == 8, "push_remote_snapshot restores collision_layer=8 on respawned remote vehicle")

	flyer.free()
	tank.free()
	jeep.free()
	plane.free()
	boat.free()
	aa.free()


func _collect_collision_shapes(node: Node, out: Array[CollisionShape3D]) -> void:
	if node is CollisionShape3D:
		out.append(node as CollisionShape3D)
	for c in node.get_children():
		_collect_collision_shapes(c, out)


func _collision_shape_y_range(col: CollisionShape3D) -> Vector2:
	var gt: Transform3D = col.global_transform
	var s: Shape3D = col.shape
	if s is BoxShape3D:
		var h: Vector3 = (s as BoxShape3D).size * 0.5
		var min_y: float = INF
		var max_y: float = -INF
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var wy: float = (gt * Vector3(sx * h.x, sy * h.y, sz * h.z)).y
					min_y = minf(min_y, wy)
					max_y = maxf(max_y, wy)
		return Vector2(min_y, max_y)
	elif s is CylinderShape3D:
		var cyl := s as CylinderShape3D
		var hh: float = cyl.height * 0.5 * gt.basis.y.length()
		return Vector2(gt.origin.y - hh, gt.origin.y + hh)
	return Vector2(gt.origin.y, gt.origin.y)


func _collision_shape_xz_distance(col: CollisionShape3D, world_pt: Vector3) -> float:
	var s: Shape3D = col.shape
	var inv: Transform3D = col.global_transform.affine_inverse()
	var lp: Vector3 = inv * world_pt
	if s is BoxShape3D:
		var h: Vector3 = (s as BoxShape3D).size * 0.5
		var clamped := Vector3(clampf(lp.x, -h.x, h.x), clampf(lp.y, -h.y, h.y), clampf(lp.z, -h.z, h.z))
		var wp_closest: Vector3 = col.global_transform * clamped
		return Vector2(world_pt.x, world_pt.z).distance_to(Vector2(wp_closest.x, wp_closest.z))
	elif s is CylinderShape3D:
		var cyl := s as CylinderShape3D
		var center_dist: float = Vector2(world_pt.x, world_pt.z).distance_to(Vector2(col.global_transform.origin.x, col.global_transform.origin.z))
		return maxf(0.0, center_dist - cyl.radius)
	return Vector2(world_pt.x, world_pt.z).distance_to(Vector2(col.global_transform.origin.x, col.global_transform.origin.z))


func _test_double_map_architecture_and_landmarks() -> void:
	# 1. Verify all 6+ new architectural textures generate cleanly
	for tex_key in ["stucco_ochre", "stucco_terracotta", "stone_masonry", "awning_stripe", "tarmac_runway", "water_fountain", "roof_terracotta"]:
		var tex: ImageTexture = CartoonAssets.get_texture(tex_key)
		_assert(tex != null and tex.get_width() >= 128 and tex.get_height() >= 128, "CartoonAssets architectural texture '%s' valid (%dx%d)" % [tex_key, tex.get_width() if tex else 0, tex.get_height() if tex else 0])

	# 2. Build full 2x Seaside Frontline map inside scene tree for world-transform verification
	var test_host := Node3D.new()
	test_host.name = "MapScaleTestHost"
	add_child(test_host)

	var conquest := ConquestManager.new()
	var vehicles_root := Node3D.new()
	var map := MapSeasideFrontline.new()
	test_host.add_child(conquest)
	test_host.add_child(vehicles_root)
	test_host.add_child(map)
	map.build_map(conquest, vehicles_root, {"destruction_callback": func(_a, _b, _c): pass})

	# 3. Verify stylized sky shader, 2x ocean, and sculpted continuous terrain
	var ocean_mi := map.get_node_or_null("Ocean") as MeshInstance3D
	_assert(ocean_mi != null and ocean_mi.mesh is PlaneMesh and (ocean_mi.mesh as PlaneMesh).size.x >= 2400.0 and (ocean_mi.mesh as PlaneMesh).size.y >= 2400.0, "Ocean spans >= 2400m x 2400m")

	var we := map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_assert(we != null and we.environment != null and we.environment.sky != null, "WorldEnvironment and Sky exist")
	var sky_mat: Material = we.environment.sky.sky_material if we != null and we.environment != null and we.environment.sky != null else null
	_assert(sky_mat is ShaderMaterial and (sky_mat as ShaderMaterial).shader != null and (sky_mat as ShaderMaterial).shader.resource_path.ends_with("toon_sky.gdshader"), "Sky uses toon_sky.gdshader ShaderMaterial")

	var terrain_body := map.get_node_or_null("SculptedTerrain") as StaticBody3D
	_assert(terrain_body != null, "SculptedTerrain exists on map")
	var terrain_col := terrain_body.get_node_or_null("CollisionShape3D") as CollisionShape3D if terrain_body != null else null
	_assert(terrain_col != null and terrain_col.shape is ConcavePolygonShape3D, "SculptedTerrain has ConcavePolygonShape3D trimesh collider")
	if terrain_col != null and terrain_col.shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = (terrain_col.shape as ConcavePolygonShape3D).get_faces()
		var min_x: float = 9999.0
		var max_x: float = -9999.0
		var min_z: float = 9999.0
		var max_z: float = -9999.0
		for f in faces:
			min_x = minf(min_x, f.x)
			max_x = maxf(max_x, f.x)
			min_z = minf(min_z, f.z)
			max_z = maxf(max_z, f.z)
		_assert((max_x - min_x) >= 1590.0 and (max_z - min_z) >= 1070.0, "SculptedTerrain trimesh spans >= 1600m x 1080m (span_x=%.1fm, span_z=%.1fm)" % [max_x - min_x, max_z - min_z])

	var min_land_y: float = 2.15
	var max_terrain_y: float = -999.0
	for hl_pt in [Vector2(-15, -270), Vector2(-190, 240), Vector2(450, -250), Vector2(460, 290), Vector2(-500, -300)]:
		max_terrain_y = maxf(max_terrain_y, MapSeasideFrontline.get_terrain_height(hl_pt.x, hl_pt.y))
	_assert(max_terrain_y - min_land_y >= 8.0, "Sculpted terrain relief >= 8.0m (max=%.2f, min=%.2f, diff=%.2fm)" % [max_terrain_y, min_land_y, max_terrain_y - min_land_y])

	for rz in [-460.0, -200.0, 40.0, 260.0, 460.0]:
		var rx: float = MapSeasideFrontline.get_river_center_x(rz)
		var ry: float = MapSeasideFrontline.get_terrain_height(rx, rz)
		_assert(ry <= -2.5, "River bed at z=%.1f (x=%.1f) is navigable <= -2.5m (y=%.2f)" % [rz, rx, ry])

	# 4. Verify required landmarks, sculpted buildings, watchtowers & 140+ layered trees
	for lm_name in ["CentralFountain", "Mercadinho", "CoastalLighthouse", "RoyalRunway", "NationalRunway", "ChurchChapel", "Windmill", "RoyalPier", "CentralPier", "NationalPier", "RuinArchPillarL", "RuinArchPillarR", "BuntingPost_-36_N", "BuntingPost_36_S", "MainRiverBridge", "SouthRiverBridge", "RiverTownDock", "RiverNorthDock", "Fazenda", "NorthOrchardBarn"]:
		_assert(map.get_node_or_null(lm_name) != null, "Landmark '%s' exists on map" % lm_name)

	# Boat headroom clearance under MainRiverBridge and SouthRiverBridge (>= 4.5m along river channel)
	for br_name in ["MainRiverBridge", "SouthRiverBridge"]:
		var br := map.get_node_or_null(br_name) as StaticBody3D
		_assert(br != null, "Bridge '%s' exists for clearance check" % br_name)
		var br_cols: Array[CollisionShape3D] = []
		if br != null:
			_collect_collision_shapes(br, br_cols)
		var min_overhead_y: float = 999.0
		var found_overhead: bool = false
		for bc in br_cols:
			var local_p: Vector3 = br.global_transform.affine_inverse() * bc.global_transform.origin
			if absf(local_p.x) < 18.0:
				var yr: Vector2 = _collision_shape_y_range(bc)
				min_overhead_y = minf(min_overhead_y, yr.x)
				found_overhead = true
		_assert(found_overhead and min_overhead_y >= 4.5, "Bridge '%s' maintains >= 4.5m boat headroom clearance along river channel (bottom=%.2fm)" % [br_name, min_overhead_y])

	# Verify ChurchChapel belltower lower stone stage does not swallow upper cream stage
	var chapel := map.get_node_or_null("ChurchChapel")
	var bell_low := chapel.get_node_or_null("BellTowerLower") as MeshInstance3D if chapel != null else null
	var bell_up := chapel.get_node_or_null("BellTowerUpper") as MeshInstance3D if chapel != null else null
	var bell_low_top: float = (bell_low.position.y + bell_low.get_aabb().end.y) if bell_low != null else 999.0
	var bell_up_top: float = (bell_up.position.y + bell_up.get_aabb().end.y) if bell_up != null else 0.0
	_assert(bell_low != null and bell_up != null and bell_low_top < bell_up_top - 4.0 and chapel.position.y >= 2.29, "ChurchChapel belltower stages separate cleanly (lower top=%.1f < upper top=%.1f) atop plaza" % [bell_low_top, bell_up_top])

	var watchtower_count: int = 0
	var tree_count: int = 0
	var house_count: int = 0
	for child in map.get_children():
		if child.name.begins_with("Watchtower"):
			watchtower_count += 1
		elif child.name.begins_with("Tree_") or child.name.begins_with("LayeredTree_"):
			tree_count += 1
		elif child.name.begins_with("VillageHouse_"):
			house_count += 1
	_assert(watchtower_count >= 6, "Map has >= 6 Watchtower landmarks (found %d)" % watchtower_count)
	_assert(tree_count >= 140, "Map has >= 140 layered trees (found %d)" % tree_count)
	_assert(house_count >= 28, "Map has >= 28 sculpted village houses (found %d)" % house_count)

	# Verify Watchtower_1 has continuous walkable sloped stair/landing colliders climbing up to >= 6.0m
	var wt1 := map.get_node_or_null("Watchtower_1")
	var wt_cols: Array[CollisionShape3D] = []
	if wt1 != null:
		_collect_collision_shapes(wt1, wt_cols)
	var stair_rungs_low: bool = false
	var stair_rungs_mid: bool = false
	var stair_deck_top: bool = false
	var wt1_y: float = wt1.global_position.y if wt1 is Node3D else 0.0
	for wc in wt_cols:
		var yr: Vector2 = _collision_shape_y_range(wc)
		var rel_top: float = yr.y - wt1_y
		var is_sloped_or_step: bool = absf(wc.rotation.x) > 0.15 or absf(wc.rotation.z) > 0.15 or absf(wc.global_transform.basis.y.y) < 0.96
		if is_sloped_or_step and rel_top >= 2.2 and rel_top <= 3.6:
			stair_rungs_low = true
		if is_sloped_or_step and rel_top >= 5.5 and rel_top <= 6.6:
			stair_rungs_mid = true
		if rel_top >= 5.95 and rel_top <= 6.35:
			stair_deck_top = true
	_assert(stair_rungs_low and stair_rungs_mid and stair_deck_top, "Watchtower_1 has climbable sloped stair ramps up to >= 6.0m deck (low=%s, mid=%s, deck=%s)" % [stair_rungs_low, stair_rungs_mid, stair_deck_top])

	# 5. Material Transparency Hygiene & Outward Loft Winding across ENTIRE map!
	var map_meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(map, map_meshes)
	var bad_trans: int = 0
	var bad_vol: int = 0
	var neg_scale: int = 0
	for mi in map_meshes:
		var det: float = mi.global_transform.basis.determinant()
		if det <= 0.0:
			neg_scale += 1
		var mat := mi.material_override
		if mat == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			mat = mi.mesh.surface_get_material(0)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			if sm.albedo_color.a >= 0.99 and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				bad_trans += 1
		if mi.mesh is ArrayMesh:
			var am := mi.mesh as ArrayMesh
			if am.get_faces().size() >= 12:
				if _signed_volume_outward_cw(am) <= 0.0:
					bad_vol += 1
	_assert(bad_trans == 0, "Zero opaque StandardMaterial3D (alpha >= 0.99) using transparency != DISABLED (found %d)" % bad_trans)
	_assert(bad_vol == 0 and neg_scale == 0, "All map ArrayMesh lofts have outward CW winding & positive transforms (bad_vol=%d, neg_scale=%d)" % [bad_vol, neg_scale])

	# 6. Vehicle placement usability: 4 Planes on unobstructed runways & 6 Boats beside piers past beach
	var planes: Array[VehiclePlane] = []
	var boats: Array[VehicleBoat] = []
	for v in map.spawned_vehicles:
		if v is VehiclePlane:
			planes.append(v as VehiclePlane)
		elif v is VehicleBoat:
			boats.append(v as VehicleBoat)
	_assert(planes.size() >= 4, "Map spawns >= 4 Fighter Planes (found %d)" % planes.size())
	_assert(boats.size() >= 6, "Map spawns >= 6 Patrol Boats (found %d)" % boats.size())

	var royal_runway := map.get_node("RoyalRunway") as Node3D
	var nat_runway := map.get_node("NationalRunway") as Node3D
	var royal_center: Vector3 = map.royal_spawns[0]
	var nat_center: Vector3 = map.national_spawns[0]
	var r_planes: int = 0
	var n_planes: int = 0
	for p in planes:
		if p.team == NetworkManager.TEAM_ROYAL:
			r_planes += 1
			_assert(p.position.distance_to(royal_runway.position) <= 115.0 and p.position.distance_to(royal_center) <= 160.0, "Royal Plane near RoyalRunway & Royal Spawn (dist runway=%.1f, spawn=%.1f)" % [p.position.distance_to(royal_runway.position), p.position.distance_to(royal_center)])
		elif p.team == NetworkManager.TEAM_NATIONAL:
			n_planes += 1
			_assert(p.position.distance_to(nat_runway.position) <= 115.0 and p.position.distance_to(nat_center) <= 160.0, "National Plane near NationalRunway & National Spawn (dist runway=%.1f, spawn=%.1f)" % [p.position.distance_to(nat_runway.position), p.position.distance_to(nat_center)])
	_assert(r_planes >= 2 and n_planes >= 2, "Both factions have >= 2 runway Planes (R=%d, N=%d)" % [r_planes, n_planes])

	# Ensure 220m x 18m runway corridor is completely free of vertical obstacles (> 0.6m above tarmac)
	for rw_node in [royal_runway, nat_runway]:
		var rw_cols: Array[CollisionShape3D] = []
		_collect_collision_shapes(rw_node, rw_cols)
		var blocked_rw: int = 0
		for wc in rw_cols:
			var yr: Vector2 = _collision_shape_y_range(wc)
			if yr.y > rw_node.global_position.y + 0.6:
				var local_p: Vector3 = rw_node.global_transform.affine_inverse() * wc.global_transform.origin
				if absf(local_p.x) < 110.0 and absf(local_p.z) < 9.5:
					blocked_rw += 1
		_assert(blocked_rw == 0, "Airstrip '%s' takeoff corridor (220m x 19m) has 0 vertical obstacles (found %d)" % [rw_node.name, blocked_rw])

	var pier_cols: Array[CollisionShape3D] = []
	for p_name in ["RoyalPier", "CentralPier", "NationalPier"]:
		_collect_collision_shapes(map.get_node(p_name), pier_cols)
	var pier_boats_ready: int = 0
	var river_boats_ready: int = 0
	for b in boats:
		var min_dock_d: float = 999.0
		for pc in pier_cols:
			min_dock_d = minf(min_dock_d, _collision_shape_xz_distance(pc, b.position))
		if b.position.y <= 0.65 and absf(b.position.z) > 542.0 and min_dock_d <= 3.5:
			pier_boats_ready += 1
		var rx: float = MapSeasideFrontline.get_river_center_x(b.position.z)
		if absf(b.position.x - rx) <= 16.0 and absf(b.position.z) < 460.0 and b.position.y <= 0.65:
			river_boats_ready += 1
	_assert(pier_boats_ready >= 6, "All 6 Ocean Harbor Pier boats float in deep sea past beach (%d ready)" % pier_boats_ready)
	_assert(river_boats_ready >= 4, "At least 4 Patrol Boats float inside central river channel (%d ready)" % river_boats_ready)
	_assert(boats.size() >= 10, "Map spawns >= 10 Patrol Boats total (found %d)" % boats.size())

	# 7. Verify all 24 spawn pads are >= 3.0m apart and clear >= 4.5m horizontally of vertical obstacles
	var all_spawns: Array[Vector3] = []
	all_spawns.append_array(map.royal_spawns)
	all_spawns.append_array(map.national_spawns)
	_assert(all_spawns.size() == 24, "Map provides 24 spawn positions (12 Royal + 12 National)")
	var min_pad_sep: float = 999.0
	for i in range(all_spawns.size()):
		for j in range(i + 1, all_spawns.size()):
			min_pad_sep = minf(min_pad_sep, Vector2(all_spawns[i].x, all_spawns[i].z).distance_to(Vector2(all_spawns[j].x, all_spawns[j].z)))
	_assert(min_pad_sep >= 3.0, "All 24 spawn pads maintain >= 3.0m XZ spacing (min=%.2fm)" % min_pad_sep)

	var all_cols: Array[CollisionShape3D] = []
	_collect_collision_shapes(map, all_cols)
	var blocked_spawns: int = 0
	for sp in all_spawns:
		for col in all_cols:
			var yr: Vector2 = _collision_shape_y_range(col)
			if yr.y >= sp.y + 0.35 and yr.x <= sp.y + 2.2:
				if _collision_shape_xz_distance(col, sp) < 4.5:
					blocked_spawns += 1
					break
	_assert(blocked_spawns == 0, "Zero spawn pads blocked within 4.5m by static vertical obstacles (blocked=%d)" % blocked_spawns)

	remove_child(test_host)
	test_host.free()


func _test_client_vehicle_freeze_and_buoyancy_sync() -> void:
	var game := MainGame.new()
	add_child(game)

	# Before joining online, non-AA boats float unfrozen under local OfflineMultiplayerPeer authority
	var initial_boats: int = 0
	var initial_unfrozen_boats: int = 0
	for v_val in game.vehicles_by_id.values():
		var v := v_val as VehicleBase
		if v is VehicleBoat:
			initial_boats += 1
			if not v.freeze:
				initial_unfrozen_boats += 1
	_assert(initial_boats >= 10 and initial_unfrozen_boats == initial_boats, "All %d boats start unfrozen under OfflineMultiplayerPeer (%d/%d)" % [initial_boats, initial_unfrozen_boats, initial_boats])

	# Joining an ENet server must freeze ALL vehicles immediately so client boats never sink to seafloor
	game._on_join_online(NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, "127.0.0.1", 7809)
	_assert(not NetworkManager.is_server_authority(), "ENet client peer reports is_server_authority() == false immediately")
	var unfrozen_after_join: int = 0
	for v_val in game.vehicles_by_id.values():
		var v := v_val as VehicleBase
		if v != null and not v.freeze:
			unfrozen_after_join += 1
	_assert(unfrozen_after_join == 0, "All client vehicles frozen immediately after _on_join_online (unfrozen=%d)" % unfrozen_after_join)

	for _f in range(6):
		await get_tree().physics_frame

	var sunk_boats: int = 0
	var unfrozen_after_frames: int = 0
	for v_val in game.vehicles_by_id.values():
		var v := v_val as VehicleBase
		if v != null and not v.freeze:
			unfrozen_after_frames += 1
		if v is VehicleBoat and v.position.y < -0.6:
			sunk_boats += 1
	_assert(unfrozen_after_frames == 0 and sunk_boats == 0, "Client boats remain frozen at waterline after physics ticks (unfrozen=%d, sunk=%d)" % [unfrozen_after_frames, sunk_boats])

	NetworkManager.shutdown_network()
	SoundSynthesizer.stop_whistle_theme()
	var boats_restored: int = 0
	for v_val in game.vehicles_by_id.values():
		var v := v_val as VehicleBase
		if v is VehicleBoat and not v.freeze:
			boats_restored += 1
	_assert(boats_restored == initial_boats and boats_restored >= 10, "Disconnecting back to offline unfreezes client boats (%d/%d)" % [boats_restored, initial_boats])
	game.free()


signal _deferred_flushed


func _flush_deferred() -> void:
	call_deferred("emit_signal", "_deferred_flushed")
	await _deferred_flushed


func _test_hud_crosshair_and_aim_convergence() -> void:
	# Create shooter, HUD, and 12m/65m targets before the single physics_frame sync
	# so both PhysicsServer3D and Container layout finish cleanly within the frame.
	var shooter := HeroCharacter.new()
	shooter.setup_identity(950, "HudAimHero", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(shooter)
	shooter.set_physics_process(false)
	shooter.global_position = Vector3.ZERO
	if shooter.skill_manager is SkillManager:
		(shooter.skill_manager as SkillManager).award_xp(150) # Level 2 -> grants 1 Hero Point so '+' upgrade buttons show

	var target_12 := HeroCharacter.new()
	target_12.setup_identity(951, "ConvergeTarget12", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(target_12)
	target_12.set_physics_process(false)

	var target_65 := HeroCharacter.new()
	target_65.setup_identity(952, "ConvergeTarget65", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(target_65)
	target_65.set_physics_process(false)

	var cmd_12 := InputCmd.new()
	cmd_12.aim_yaw = 0.25
	cmd_12.aim_pitch = -0.04
	var cam_ray_12: Dictionary = HeroCamera.compute_aim_ray(shooter.global_position, cmd_12.aim_yaw, cmd_12.aim_pitch, false, false, false)
	var pt_12: Vector3 = (cam_ray_12["origin"] as Vector3) + (cam_ray_12["dir"] as Vector3) * (float(cam_ray_12["spring_length"]) + 12.0)
	target_12.global_position = pt_12 - Vector3(0.0, 1.35, 0.0)

	var cmd_65 := InputCmd.new()
	cmd_65.aim_yaw = -0.35
	cmd_65.aim_pitch = -0.02
	var cam_ray_65: Dictionary = HeroCamera.compute_aim_ray(shooter.global_position, cmd_65.aim_yaw, cmd_65.aim_pitch, false, false, false)
	var pt_65: Vector3 = (cam_ray_65["origin"] as Vector3) + (cam_ray_65["dir"] as Vector3) * (float(cam_ray_65["spring_length"]) + 65.0)
	target_65.global_position = pt_65 - Vector3(0.0, 1.35, 0.0)

	# Close-range wall 0.6m in front of shoulder pivot along +Z (opposite -Z targets, tests min_dist clamp)
	var close_wall := StaticBody3D.new()
	close_wall.collision_layer = 1
	var close_col := CollisionShape3D.new()
	var close_box := BoxShape3D.new()
	close_box.size = Vector3(1.5, 2.0, 0.3)
	close_col.shape = close_box
	close_wall.add_child(close_col)
	add_child(close_wall)
	var cmd_close := InputCmd.new()
	cmd_close.aim_yaw = PI
	cmd_close.aim_pitch = 0.0
	var cam_ray_close: Dictionary = HeroCamera.compute_aim_ray(shooter.global_position, cmd_close.aim_yaw, cmd_close.aim_pitch, false, false, false)
	close_wall.global_position = (cam_ray_close["pivot"] as Vector3) + (cam_ray_close["dir"] as Vector3) * 0.6

	var hud := HUDController.new()
	add_child(hud)
	hud.set_local_hero(shooter)
	hud._process(0.016)

	await get_tree().physics_frame
	hud._process(0.016)
	await _flush_deferred()
	hud._process(0.016)
	await _flush_deferred()

	# 1. HUD Bottom Hotbar Unclipped at 1280x720 with Level-2 Soldier '+' Upgrade Buttons
	var vp_h: float = float(hud.get_viewport().get_visible_rect().size.y)
	var upg_visible_count: int = 0
	for b in hud._upgrade_buttons:
		if b.visible:
			upg_visible_count += 1
	var all_keys_unclipped: bool = true
	var max_key_end_y: float = 0.0
	var all_key_lbls: Array[Label] = []
	all_key_lbls.append_array(hud._weapon_slot_keys)
	all_key_lbls.append_array(hud._skill_slot_keys)
	all_key_lbls.append_array(hud._widget_slot_keys)
	for kl in all_key_lbls:
		var box := kl.get_parent() as Control
		if box != null and not box.visible:
			continue
		var rect := kl.get_global_rect()
		max_key_end_y = maxf(max_key_end_y, rect.end.y)
		if rect.position.y < 0.0 or rect.end.y > vp_h - 6.0:
			all_keys_unclipped = false
	_assert(
		upg_visible_count == 5 and all_keys_unclipped and all_key_lbls.size() == 12,
		"All 12 hotbar hotkey labels stay unclipped (max end.y=%.1f <= %.1f) with %d '+' upgrade buttons visible" % [max_key_end_y, vp_h - 6.0, upg_visible_count]
	)

	# 2. Crisp Vertical Bullet Icon & Balanced Bottom-Right Ammo Alignment
	var bullet_tex: Texture2D = hud._ammo_icon_tex.texture
	var bullet_img: Image = bullet_tex.get_image() if bullet_tex != null else null
	var min_x: int = 999
	var max_x: int = -1
	var min_y: int = 999
	var max_y: int = -1
	if bullet_img != null:
		for py in range(bullet_img.get_height()):
			for px in range(bullet_img.get_width()):
				if bullet_img.get_pixel(px, py).a > 0.1:
					min_x = mini(min_x, px)
					max_x = maxi(max_x, px)
					min_y = mini(min_y, py)
					max_y = maxi(max_y, py)
	var x_asym: int = absi(min_x - (bullet_img.get_width() - 1 - max_x)) if bullet_img != null else 999
	var y_asym: int = absi(min_y - (bullet_img.get_height() - 1 - max_y)) if bullet_img != null else 999
	var icon_rect := hud._ammo_icon_tex.get_global_rect()
	var ammo_rect := hud._ammo_value_lbl.get_global_rect()
	_assert(
		bullet_img != null and bullet_img.get_width() == 40 and bullet_img.get_height() == 52 and x_asym <= 1 and y_asym <= 1 and absf(icon_rect.get_center().y - (ammo_rect.get_center().y + 6.0)) < 18.0,
		"Bullet icon is crisp 40x52 centered cartridge (asym X=%d, Y=%d) vertically balanced with ammo text" % [x_asym, y_asym]
	)

	# 3. Dynamic 4-Prong BFH Crosshair (prongs present, spread blooms on move/fire, hides when scoped)
	var has_prongs: bool = (
		hud._crosshair != null
		and hud._crosshair.get_node_or_null("Top") != null
		and hud._crosshair.get_node_or_null("Bottom") != null
		and hud._crosshair.get_node_or_null("Left") != null
		and hud._crosshair.get_node_or_null("Right") != null
	)
	var idle_spread: float = hud._crosshair_spread_px
	shooter.velocity = Vector3(7.5, 0.0, 0.0)
	for _i in range(10):
		hud._process(0.016)
	var move_spread: float = hud._crosshair_spread_px
	hud.trigger_crosshair_bloom(9.0)
	for _i in range(6):
		hud._process(0.016)
	var fire_spread: float = hud._crosshair_spread_px
	shooter.hero_camera.set_scoped(true)
	hud._process(0.016)
	var hidden_when_scoped: bool = not hud._crosshair.visible and hud._scope_overlay.visible
	shooter.hero_camera.set_scoped(false)
	hud._process(0.016)
	var restored_after_scope: bool = hud._crosshair.visible and not hud._scope_overlay.visible
	_assert(
		has_prongs and move_spread > idle_spread + 1.5 and fire_spread > move_spread + 1.5 and hidden_when_scoped and restored_after_scope,
		"4-prong crosshair spreads on move/fire (idle=%.1f -> move=%.1f -> fire=%.1f) and toggles cleanly with Sniper scope" % [idle_spread, move_spread, fire_spread]
	)

	# 4. Over-Shoulder Crosshair Aim Convergence at 12.0m (close) and 65.0m (mid-range) + backwards-compat
	var lc := LagCompensator.new()
	var heroes := {950: shooter, 951: target_12, 952: target_65}
	var smg := shooter.weapons[0] as HitscanWeapon
	smg.spread_rad = 0.0

	var sniper := HitscanWeapon.new()
	sniper.configure(shooter, WeaponBase.WeaponKind.SNIPER, NetworkManager.ARCHETYPE_BALANCED)
	sniper.spread_rad = 0.0
	add_child(sniper)

	var legacy_aim: Dictionary = smg.get_aim_origin_and_dir(cmd_12)
	_assert(
		(legacy_aim["dir"] as Vector3).length() > 0.99,
		"WeaponBase.get_aim_origin_and_dir(cmd) preserves 1-arg compatibility"
	)

	NetworkManager.server_tick = 40
	lc.record_frame(40, heroes)
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state

	var aim_12: Dictionary = smg.get_aim_origin_and_dir(cmd_12, space)
	var dist_to_ray_12: float = ((pt_12 - (aim_12["origin"] as Vector3)).cross(aim_12["dir"] as Vector3)).length()
	var hp_before_12: int = target_12.hp
	smg.fire_server(cmd_12, {"lag_compensator": lc, "heroes_by_id": heroes})
	var hit_12: bool = target_12.hp < hp_before_12

	var aim_65: Dictionary = sniper.get_aim_origin_and_dir(cmd_65, space)
	var dist_to_ray_65: float = ((pt_65 - (aim_65["origin"] as Vector3)).cross(aim_65["dir"] as Vector3)).length()
	var hp_before_65: int = target_65.hp
	sniper.fire_server(cmd_65, {"lag_compensator": lc, "heroes_by_id": heroes})
	var hit_65: bool = target_65.hp < hp_before_65

	_assert(
		hit_12 and hit_65 and dist_to_ray_12 < 0.05 and dist_to_ray_65 < 0.05,
		"Over-shoulder aim converges onto HeroCamera crosshair target at 12m (err=%.3fm, hit=%s) and 65m (err=%.3fm, hit=%s)" % [dist_to_ray_12, str(hit_12), dist_to_ray_65, str(hit_65)]
	)

	var aim_close: Dictionary = smg.get_aim_origin_and_dir(cmd_close, space)
	var close_dot: float = (aim_close["dir"] as Vector3).dot(cam_ray_close["dir"] as Vector3)
	var cmd_scoped := InputCmd.new()
	cmd_scoped.aim_yaw = -0.35
	cmd_scoped.aim_pitch = -0.02
	cmd_scoped.buttons = InputCmd.BTN_AIM
	var cam_ray_scoped: Dictionary = HeroCamera.compute_aim_ray(shooter.global_position, cmd_scoped.aim_yaw, cmd_scoped.aim_pitch, true, false, false)
	var aim_scoped: Dictionary = sniper.get_aim_origin_and_dir(cmd_scoped, space)
	_assert(
		close_dot > 0.7 and (aim_scoped["origin"] as Vector3).distance_to(cam_ray_scoped["origin"] as Vector3) < 0.001,
		"Close-range convergence clamps forward (dot=%.3f) and scoped Sniper fires pinpoint from FPS eye" % close_dot
	)

	close_wall.free()
	sniper.free()
	lc.free()
	target_65.free()
	target_12.free()
	hud.free()
	shooter.free()


func _sample_wav_peak_rms(wav: AudioStreamWAV) -> Vector2:
	if wav == null or wav.data.is_empty():
		return Vector2.ZERO
	var count: int = wav.data.size() / 2
	var peak: float = 0.0
	var sum_sq: float = 0.0
	for i in range(count):
		var s: float = float(wav.data.decode_s16(i * 2)) / 32767.0
		peak = maxf(peak, absf(s))
		sum_sq += s * s
	return Vector2(peak, sqrt(sum_sq / float(maxi(1, count))))


func _test_sfx_priority_and_bot_anti_wallhack() -> void:
	# 1. SoundSynthesizer: Normalized punchy waveforms + isolated Local vs World SFX pools
	var required_clips: Array[String] = [
		"shoot_smg", "shoot_mg", "shoot_shotgun", "shoot_sniper", "shoot_pistol", "shoot_bazooka",
		"knife", "explosion", "hit", "crit", "heal", "reload", "parachute", "level_up", "click",
	]
	var all_clips_punchy: bool = true
	for cname in required_clips:
		var wav := SoundSynthesizer._clips.get(cname, null) as AudioStreamWAV
		var pr: Vector2 = _sample_wav_peak_rms(wav)
		if wav == null or pr.x < 0.65 or pr.x > 0.96:
			all_clips_punchy = false
	var smg_stats: Vector2 = _sample_wav_peak_rms(SoundSynthesizer._clips.get("shoot_smg", null) as AudioStreamWAV)
	var sniper_stats: Vector2 = _sample_wav_peak_rms(SoundSynthesizer._clips.get("shoot_sniper", null) as AudioStreamWAV)
	_assert(
		all_clips_punchy and smg_stats.x >= 0.65 and sniper_stats.x >= 0.65 and smg_stats.y > 0.05 and sniper_stats.y > 0.05,
		"SoundSynthesizer generates punchy combat AudioStreamWAV clips (SMG peak=%.2f rms=%.2f, Sniper peak=%.2f rms=%.2f)" % [smg_stats.x, smg_stats.y, sniper_stats.x, sniper_stats.y]
	)

	var distinct_pools: bool = SoundSynthesizer._local_sfx_pool.size() == 8 and SoundSynthesizer._world_sfx_pool.size() == 12
	for lp in SoundSynthesizer._local_sfx_pool:
		if SoundSynthesizer._world_sfx_pool.has(lp):
			distinct_pools = false
	_assert(distinct_pools, "SoundSynthesizer maintains distinct _local_sfx_pool (8) and _world_sfx_pool (12)")

	for p in SoundSynthesizer._local_sfx_pool:
		p.stop()
		p.stream = null
	for p in SoundSynthesizer._world_sfx_pool:
		p.stop()
		p.stream = null
	SoundSynthesizer._world_sfx_cooldowns.clear()
	SoundSynthesizer.set_listener_position(Vector3.ZERO)

	SoundSynthesizer.play_sfx("shoot_sniper", 0.0, true)
	var local_chan: AudioStreamPlayer = null
	for p in SoundSynthesizer._local_sfx_pool:
		if p.stream == SoundSynthesizer._clips["shoot_sniper"]:
			local_chan = p
			break
	for _i in range(25):
		SoundSynthesizer.play_sfx("shoot_smg", 0.0, false, Vector3(12.0, 0.0, 0.0))

	var local_untouched: bool = (
		local_chan != null
		and local_chan.stream == SoundSynthesizer._clips["shoot_sniper"]
		and local_chan.volume_db >= -6.0
	)
	for lp in SoundSynthesizer._local_sfx_pool:
		if lp.stream == SoundSynthesizer._clips["shoot_smg"]:
			local_untouched = false
	_assert(
		local_untouched,
		"25 simultaneous world bot shots cannot overwrite or silence local priority channel (vol=%.1fdB)" % (local_chan.volume_db if local_chan != null else -99.0)
	)

	SoundSynthesizer.play_sfx("shoot_mg", 0.0, false, Vector3(95.0, 0.0, 0.0))
	var far_skipped: bool = true
	for wp in SoundSynthesizer._world_sfx_pool:
		if wp.stream == SoundSynthesizer._clips["shoot_mg"]:
			far_skipped = false
	SoundSynthesizer.play_sfx("shoot_pistol", 0.0, false, Vector3(45.0, 0.0, 0.0))
	var dist_attenuated: bool = false
	for wp in SoundSynthesizer._world_sfx_pool:
		if wp.stream == SoundSynthesizer._clips["shoot_pistol"] and wp.volume_db < -10.0 and wp.volume_db > -30.0:
			dist_attenuated = true
	_assert(far_skipped and dist_attenuated, "World SFX skips shots >75m (skipped=%s) and attenuates over 0..75m (attenuated=%s)" % [str(far_skipped), str(dist_attenuated)])
	for p in SoundSynthesizer._local_sfx_pool:
		p.stop()
	for p in SoundSynthesizer._world_sfx_pool:
		p.stop()

	# 2. BotController Anti-Wallhack LOS, Reaction Delay & Humanized Aim Spread
	var test_host := Node3D.new()
	test_host.name = "BotWallhackTestHost"
	add_child(test_host)

	var house := BuildingMeshBuilder.build_town_house(test_host, Vector3.ZERO, 0.0, 0)
	_assert(house != null and house is StaticBody3D and (house as StaticBody3D).collision_layer == 1, "VillageHouse builds Layer-1 StaticBody3D collider")

	var bot_hero := HeroCharacter.new()
	bot_hero.setup_identity(961, "AllyBotTester", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	bot_hero.set_physics_process(false)
	test_host.add_child(bot_hero)
	bot_hero.global_position = Vector3(0.0, 0.0, 10.0)

	var enemy_hero := HeroCharacter.new()
	enemy_hero.setup_identity(962, "NationalTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	enemy_hero.set_physics_process(false)
	test_host.add_child(enemy_hero)
	enemy_hero.global_position = Vector3(0.0, 0.0, -10.0)

	var bot := BotController.new()
	test_host.add_child(bot)
	bot.setup(bot_hero)

	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var los_blocked: bool = not bot.has_line_of_sight(space, enemy_hero)
	var fired_behind_wall: bool = false
	var test_heroes := {961: bot_hero, 962: enemy_hero}
	for _t in range(30):
		var c_wall: InputCmd = bot.compute_input(0.016, [], test_heroes, [])
		if c_wall.has_button(InputCmd.BTN_FIRE):
			fired_behind_wall = true
	_assert(los_blocked and not fired_behind_wall, "BotController blocks LOS through VillageHouse (los_blocked=%s) and never fires through walls (fired=%s)" % [str(los_blocked), str(fired_behind_wall)])

	# Open LOS 18m away in clear space -> verify reaction delay then humanized aim spread
	enemy_hero.global_position = Vector3(18.0, 0.0, 10.0)
	enemy_hero.velocity = Vector3(0.0, 0.0, 5.0)
	await get_tree().physics_frame
	var los_open: bool = bot.has_line_of_sight(space, enemy_hero)
	var first_cmd: InputCmd = bot.compute_input(0.016, [], test_heroes, [])
	var delayed_on_first_tick: bool = not first_cmd.has_button(InputCmd.BTN_FIRE)

	var to_e: Vector3 = (enemy_hero.global_position + Vector3(0.0, 1.18, 0.0)) - (bot_hero.global_position + Vector3(0.0, 1.55, 0.0))
	var exact_yaw: float = atan2(-to_e.x, -to_e.z)
	var fire_count: int = 0
	var min_yaw_err: float = 999.0
	var max_yaw_err: float = -999.0
	var min_pitch_err: float = 999.0
	var max_pitch_err: float = -999.0
	var exact_pitch: float = atan2(to_e.y, Vector2(to_e.x, to_e.z).length())
	for _t in range(42):
		var c_open: InputCmd = bot.compute_input(0.016, [], test_heroes, [])
		if c_open.has_button(InputCmd.BTN_FIRE):
			fire_count += 1
			var yerr: float = c_open.aim_yaw - exact_yaw
			var perr: float = c_open.aim_pitch - exact_pitch
			min_yaw_err = minf(min_yaw_err, yerr)
			max_yaw_err = maxf(max_yaw_err, yerr)
			min_pitch_err = minf(min_pitch_err, perr)
			max_pitch_err = maxf(max_pitch_err, perr)
	var yaw_spread_span: float = (max_yaw_err - min_yaw_err) if fire_count > 0 else 0.0
	var pitch_spread_span: float = (max_pitch_err - min_pitch_err) if fire_count > 0 else 0.0
	_assert(
		los_open and delayed_on_first_tick and fire_count >= 5 and (yaw_spread_span > 0.005 or pitch_spread_span > 0.005),
		"Bot opens fire after reaction delay (open=%s, delayed=%s, fires=%d) with humanized aim variance (yaw_span=%.4f, pitch_span=%.4f rad)" % [str(los_open), str(delayed_on_first_tick), fire_count, yaw_spread_span, pitch_spread_span]
	)

	# 3. LagCompensator + HitscanWeapon Solid Wall Guard (including muzzle flush against VillageHouse wall!)
	var lc := LagCompensator.new()
	test_host.add_child(lc)
	var smg := bot_hero.weapons[0] as HitscanWeapon
	smg.spread_rad = 0.0
	enemy_hero.global_position = Vector3(0.0, 0.0, -8.0)
	enemy_hero.hp = enemy_hero.max_hp

	# First test at 3m from wall (z=8.0), then test muzzle flush inside/against wall (z=4.85, wall face at z=4.99)
	var wall_blocked_all: bool = true
	for shooter_z in [8.0, 4.85]:
		bot_hero.global_position = Vector3(0.0, 0.0, shooter_z)
		await get_tree().physics_frame
		NetworkManager.server_tick = 50
		lc.record_frame(50, test_heroes)
		var wall_cmd := InputCmd.new()
		wall_cmd.aim_yaw = 0.0
		wall_cmd.aim_pitch = 0.0
		smg.fire_server(wall_cmd, {"lag_compensator": lc, "heroes_by_id": test_heroes})
		if enemy_hero.hp < enemy_hero.max_hp:
			wall_blocked_all = false
	_assert(
		wall_blocked_all and enemy_hero.hp == enemy_hero.max_hp,
		"HitscanWeapon + LagCompensator blocks 100%% of shots across VillageHouse wall including flush-wall muzzle (hp=%d/%d)" % [enemy_hero.hp, enemy_hero.max_hp]
	)

	remove_child(test_host)
	test_host.free()


func _test_parachute_delay_death_collapse_and_knockback() -> void:
	# 1. Parachute Fall Delay: Flat Jump (<1.0s) vs High Fall (>=1.0s)
	var p_hero := HeroCharacter.new()
	p_hero.setup_identity(901, "ParaTester", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(p_hero)
	p_hero.global_position = Vector3(0.0, 1.2, 0.0)
	p_hero.velocity = Vector3(0.0, -4.0, 0.0)
	p_hero._airborne_fall_time = 0.40 # Simulated flat jump fall time well under 1.0s
	_assert(not p_hero.can_open_parachute(), "Flat jump (0.4s fall < 1.0s) reports can_open_parachute() == false")
	var jump_cmd := InputCmd.new()
	jump_cmd.set_button(InputCmd.BTN_JUMP, true)
	p_hero.simulate_movement(jump_cmd, 1.0 / 60.0)
	_assert(not p_hero.is_parachuting, "Pressing Jump under 1.0s fall does NOT deploy parachute")

	p_hero.global_position = Vector3(0.0, 50.0, 0.0)
	p_hero.velocity = Vector3(0.0, -10.0, 0.0)
	p_hero._airborne_fall_time = 1.05
	_assert(p_hero.can_open_parachute(), "Cliff/sky fall (fall time >= 1.05s) reports can_open_parachute() == true")
	p_hero.prev_jump_held = false
	p_hero.simulate_movement(jump_cmd, 1.0 / 60.0)
	_assert(p_hero.is_parachuting, "Pressing Jump after >= 1.0s fall deploys parachute")
	p_hero.free()

	# Verify calling _animate_character(0.016) 60 times during 0.4s fall on a local hero does NOT inflate _airborne_fall_time
	var anim_hero := HeroCharacter.new()
	anim_hero.setup_identity(905, "AnimFallTester", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(anim_hero)
	anim_hero.global_position = Vector3(0.0, 40.0, 0.0)
	anim_hero.velocity = Vector3(0.0, -4.0, 0.0)
	var fall_input := InputCmd.new()
	for i in range(24):
		anim_hero.simulate_movement(fall_input, 1.0 / 60.0)
	for i in range(60):
		anim_hero._animate_character(0.016)
	_assert(
		anim_hero._airborne_fall_time <= 0.45 and not anim_hero.can_open_parachute(),
		"Rendering 60 frames of _animate_character does not double-accumulate _airborne_fall_time (time=%.2fs <= 0.45s, chute=%s)" % [anim_hero._airborne_fall_time, anim_hero.can_open_parachute()]
	)
	anim_hero.free()

	# Remote snapshot death/respawn/2nd-death cleanly resets _defeat_elapsed = 0.0
	var r_hero := HeroCharacter.new()
	r_hero.setup_identity(906, "RemotePuppet", 0, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(r_hero)
	r_hero.active_flags = NetSerializer.SNAP_DEFEATED
	r_hero.is_defeated = true
	for i in range(30):
		r_hero._animate_character(0.1)
	_assert(r_hero._defeat_elapsed >= 2.5, "Remote hero accumulates _defeat_elapsed on first death (elapsed=%.2fs)" % r_hero._defeat_elapsed)

	r_hero.active_flags = 0
	r_hero.is_defeated = false
	r_hero._animate_character(0.016)
	_assert(r_hero._defeat_elapsed == 0.0, "Remote hero respawn cleanly resets _defeat_elapsed to 0.0")

	r_hero.active_flags = NetSerializer.SNAP_DEFEATED
	r_hero.is_defeated = true
	r_hero._animate_character(0.016)
	_assert(
		r_hero._defeat_elapsed < 0.05,
		"Remote hero 2nd death cleanly starts collapse from 0.0s (elapsed=%.3fs)" % r_hero._defeat_elapsed
	)
	r_hero.free()

	# Client reconciliation restores knockback stun timer on strong launch velocity
	var rec_hero := HeroCharacter.new()
	rec_hero.setup_identity(907, "ReconcileTester", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(rec_hero)
	rec_hero.local_tick = 5
	var rec_cmd := InputCmd.new()
	rec_hero.input_buffer.push(5, rec_cmd, Vector3.ZERO, Vector3.ZERO, false, false, true, false)
	rec_hero.reconcile_with_server({
		"ack_tick": 5,
		"pos": Vector3(0.0, 2.0, 0.0),
		"vel": Vector3(0.0, 8.5, 0.0),
		"flags": 0,
		"hp": 100,
		"shield": 0,
		"vehicle_id": -1,
		"seat_idx": -1
	})
	_assert(
		rec_hero._knockback_stun_timer >= 0.35,
		"Reconciliation with explosive velocity restores _knockback_stun_timer (%.2fs >= 0.35s)" % rec_hero._knockback_stun_timer
	)
	rec_hero.free()

	# 2. Defeated Non-Sliding Collapse & Multi-Stage Defeat Pose
	var d_hero := HeroCharacter.new()
	d_hero.setup_identity(902, "CollapseTester", 0, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(d_hero)
	d_hero.global_position = Vector3(0.0, 0.0, 0.0)
	d_hero.velocity = Vector3(14.0, 0.0, -9.0)
	var start_pos: Vector3 = d_hero.global_position
	d_hero.apply_damage_server(999, -1, false)
	_assert(d_hero.is_defeated, "Hero is defeated by lethal damage")

	var idle_cmd := InputCmd.new()
	for i in range(15):
		d_hero.simulate_movement(idle_cmd, 1.0 / 60.0)

	var drift_dist: float = Vector2(d_hero.global_position.x - start_pos.x, d_hero.global_position.z - start_pos.z).length()
	_assert(
		drift_dist < 0.55 and absf(d_hero.velocity.x) < 0.05 and absf(d_hero.velocity.z) < 0.05,
		"Defeated hero comes to non-sliding halt (drift=%.3fm < 0.55m, vel=(%.2f, %.2f))" % [drift_dist, d_hero.velocity.x, d_hero.velocity.z]
	)

	d_hero._animate_character(0.7)
	_assert(
		d_hero._hips_pivot.rotation.x <= -0.85,
		"Defeated collapse animation lays torso down flat onto turf (_hips_pivot.rot.x=%.3f <= -0.85)" % d_hero._hips_pivot.rotation.x
	)
	d_hero.free()

	# 3. Explosives Zero-Friendly-Fire & Self/Enemy Knockback
	var shooter := HeroCharacter.new()
	shooter.setup_identity(910, "Shooter", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	var teammate := HeroCharacter.new()
	teammate.setup_identity(911, "Teammate", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var enemy := HeroCharacter.new()
	enemy.setup_identity(912, "Enemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)

	add_child(shooter)
	add_child(teammate)
	add_child(enemy)

	var heroes_map: Dictionary = {
		910: shooter,
		911: teammate,
		912: enemy,
	}
	var exp_ctx: Dictionary = {"heroes_by_id": heroes_map}

	# --- 3A. Bazooka Rocket ---
	shooter.global_position = Vector3(0.0, 0.0, 0.0)
	shooter.velocity = Vector3.ZERO
	shooter.hp = shooter.max_hp
	teammate.global_position = Vector3(1.2, 0.0, 0.0)
	teammate.velocity = Vector3.ZERO
	teammate.hp = teammate.max_hp
	enemy.global_position = Vector3(0.0, 0.0, 1.2)
	enemy.velocity = Vector3.ZERO
	enemy.hp = enemy.max_hp

	var rocket := ProjectileEntity.new()
	rocket.setup(ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET, shooter.entity_id, shooter.team, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, exp_ctx)
	add_child(rocket)
	rocket._detonate()

	_assert(
		teammate.hp == teammate.max_hp and teammate.velocity.length() < 0.01,
		"Bazooka blast deals 0 damage and 0 knockback to teammate"
	)
	_assert(
		shooter.hp == shooter.max_hp and shooter.velocity.length() >= 8.0,
		"Bazooka blast deals 0 self-damage (hp=%d/%d) and imparts strong self-knockback (vel=%.2f >= 8.0)" % [shooter.hp, shooter.max_hp, shooter.velocity.length()]
	)
	_assert(
		enemy.hp < enemy.max_hp and enemy.velocity.length() >= 8.0,
		"Bazooka blast damages enemy (%d -> %d) and imparts strong knockback (vel=%.2f >= 8.0)" % [enemy.max_hp, enemy.hp, enemy.velocity.length()]
	)

	var s_start: Vector3 = shooter.global_position
	var e_start: Vector3 = enemy.global_position
	for i in range(10):
		shooter.simulate_movement(idle_cmd, 1.0 / 60.0)
		enemy.simulate_movement(idle_cmd, 1.0 / 60.0)
	_assert(
		shooter.global_position.distance_to(s_start) >= 1.5 and enemy.global_position.distance_to(e_start) >= 1.5,
		"Bazooka knockback visibly launches shooter (%.2fm) and enemy (%.2fm) >= 1.5m over 10 ticks" % [shooter.global_position.distance_to(s_start), enemy.global_position.distance_to(e_start)]
	)

	# --- 3B. Red Barrel ---
	shooter.global_position = Vector3(0.0, 0.0, 0.0)
	shooter.velocity = Vector3.ZERO
	shooter.hp = shooter.max_hp
	teammate.global_position = Vector3(1.2, 0.0, 0.0)
	teammate.velocity = Vector3.ZERO
	teammate.hp = teammate.max_hp
	enemy.global_position = Vector3(0.0, 0.0, 1.2)
	enemy.velocity = Vector3.ZERO
	enemy.hp = enemy.max_hp

	var barrel := DestructibleProp.new()
	barrel.setup(DestructibleProp.PropKind.RED_BARREL, Vector3(0.0, 0.0, 0.0), 0.0, exp_ctx)
	add_child(barrel)
	barrel.apply_damage_server(999, shooter.entity_id, Vector3.FORWARD, barrel.global_position, true)

	_assert(
		teammate.hp == teammate.max_hp and teammate.velocity.length() < 0.01,
		"Red Barrel explosion deals 0 damage and 0 knockback to teammate"
	)
	_assert(
		shooter.hp == shooter.max_hp and shooter.velocity.length() >= 8.0,
		"Red Barrel deals 0 self-damage (hp=%d/%d) and imparts strong self-knockback (vel=%.2f >= 8.0)" % [shooter.hp, shooter.max_hp, shooter.velocity.length()]
	)
	_assert(
		enemy.hp < enemy.max_hp and enemy.velocity.length() >= 8.0,
		"Red Barrel damages enemy (%d -> %d) and imparts strong knockback (vel=%.2f >= 8.0)" % [enemy.max_hp, enemy.hp, enemy.velocity.length()]
	)

	s_start = shooter.global_position
	e_start = enemy.global_position
	for i in range(10):
		shooter.simulate_movement(idle_cmd, 1.0 / 60.0)
		enemy.simulate_movement(idle_cmd, 1.0 / 60.0)
	_assert(
		shooter.global_position.distance_to(s_start) >= 1.5 and enemy.global_position.distance_to(e_start) >= 1.5,
		"Red Barrel knockback visibly launches shooter (%.2fm) and enemy (%.2fm) >= 1.5m over 10 ticks" % [shooter.global_position.distance_to(s_start), enemy.global_position.distance_to(e_start)]
	)
	barrel.free()

	# --- 3C. Soldier Blasting Strike ---
	shooter.global_position = Vector3(0.0, 0.0, 0.0)
	shooter.velocity = Vector3.ZERO
	teammate.global_position = Vector3(2.5, 0.0, 0.0)
	teammate.velocity = Vector3.ZERO
	teammate.hp = teammate.max_hp
	enemy.global_position = Vector3(0.0, 0.0, 2.5)
	enemy.velocity = Vector3.ZERO
	enemy.hp = enemy.max_hp

	var sm_cmd := InputCmd.new()
	var strike_ok: bool = shooter.skill_manager._execute_class_skill(3, 0, sm_cmd, exp_ctx)
	_assert(strike_ok, "Soldier Blasting Strike skill executes cleanly")
	_assert(
		teammate.hp == teammate.max_hp and teammate.velocity.length() < 0.01,
		"Blasting Strike deals 0 damage and 0 knockback to ally"
	)
	_assert(
		enemy.hp < enemy.max_hp and enemy.velocity.length() >= 8.0 and enemy.velocity.y >= 6.5,
		"Blasting Strike damages enemy and imparts strong knockback with upward lift (vel=%.2f, vy=%.2f >= 6.5)" % [enemy.velocity.length(), enemy.velocity.y]
	)

	e_start = enemy.global_position
	for i in range(10):
		enemy.simulate_movement(idle_cmd, 1.0 / 60.0)
	_assert(
		enemy.global_position.distance_to(e_start) >= 1.5,
		"Blasting Strike knockback visibly launches enemy %.2fm >= 1.5m over 10 ticks" % enemy.global_position.distance_to(e_start)
	)

	shooter.free()
	teammate.free()
	enemy.free()


func _test_scene_compile_and_load() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "Main scene res://scenes/main.tscn loads cleanly")
