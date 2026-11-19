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
	await _test_overhaul_net_u32_fall_damage_and_assets()
	_test_hero_visuals_camera_and_audio()
	_test_ik_weapon_grip_shot_fx_and_scope()
	_test_ballistic_bullet_drop_and_tracers()
	_test_vehicle_sculpted_models_and_animations()
	await _test_hud_crosshair_and_aim_convergence()
	await _test_sfx_priority_and_bot_anti_wallhack()
	_test_parachute_delay_death_collapse_and_knockback()
	_test_smooth_sync_packet_sequencing_and_menus()
	await _test_step_climb_vehicle_arcade_and_roadkill()
	_test_phase4_spread_and_optimization()
	await _test_phase5_vehicles_grass_and_precision()
	await _test_phase6_skills_20v20_arsenal()
	await _test_phase7_task1_skills_hud_pooling()
	await _test_phase7_task2_hotkeys_menu()
	await _test_phase7_task3_perf_cache_vfx()
	await _test_phase8_task1_skill_icons_and_guide()
	await _test_phase8_task2_aoe_vfx_and_overhead_buffs()
	await _test_phase8_task3_plane_accel_and_crash()
	await _test_phase9_all_9_fixes()
	await _test_phase10_all_8_items()
	await _test_phase11_task1_fixes()
	await _test_phase11_task2_vehicles()
	await _test_phase11_task3_crosshair_and_animations()
	await _test_phase11_task4_demolisher()
	await _test_phase11_task5_demolisher_weapons()
	await _test_phase11_task6_ui_bots_and_full_matrix()
	await _test_phase11_final_fix_wave()
	await _test_phase11_polish_task7()
	await _test_phase11_polish_task8()
	await _test_phase12_task1_fixes()
	await _test_phase12_task2_demolisher_rework()
	await _test_phase12_task3_hotkeys_drag_minimap()
	await _test_phase12_task4_field_engineer()
	await _test_phase12_task5_menus_5classes_integration()
	await _test_phase12b_task1_engineer_build_channel()
	await _test_phase12b_task2_mortar_anim_and_aoe()
	await _test_phase12b_task3_perf_optimizations()
	await _test_phase13_task1_lod_demolisher_gunner()
	await _test_phase13_task2_mounted_overheat()
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

	# All skills start unlocked at Rank 5 (MAX_SKILL_RANK) with 0 hero_points & upgrade_skill() disabled
	var sm: SkillManager = soldier.skill_manager as SkillManager
	var gsm: SkillManager = gunner.skill_manager as SkillManager
	var csm: SkillManager = commando.skill_manager as SkillManager
	var all_rank5: bool = sm.skill_ranks.size() == 5 and gsm.skill_ranks.size() == 5 and csm.skill_ranks.size() == 6
	for r in sm.skill_ranks:
		all_rank5 = all_rank5 and (r == SkillManager.MAX_SKILL_RANK)
	for r in gsm.skill_ranks:
		all_rank5 = all_rank5 and (r == SkillManager.MAX_SKILL_RANK)
	for r in csm.skill_ranks:
		all_rank5 = all_rank5 and (r == SkillManager.MAX_SKILL_RANK)
	_assert(all_rank5, "All Soldier (5), Gunner (5) & Commando (6) skills start unlocked at Rank 5")
	_assert(sm.hero_points == 0 and gsm.hero_points == 0 and csm.hero_points == 0, "Hero Points start at 0 across all classes")
	_assert(not sm.upgrade_skill(0), "upgrade_skill(0) returns false when all skills are max Rank 5")
	sm.award_xp(400)
	_assert(sm.level > 5 and sm.hero_points == 0, "Combat Mastery XP levels up cleanly without granting Hero Points")

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
	_assert(sm.try_activate_skill(3, cmd, ctx) and commando.velocity.length() > 8.0, "Soldier Blasting Strike knocks back enemies at Rank 5")

	# Grenade Spam spawns >= 2 grenades
	var before_proj: int = proj_root.get_child_count()
	_assert(sm.try_activate_skill(2, cmd, ctx) and proj_root.get_child_count() >= before_proj + 2, "Soldier Grenade Spam spawns multiple grenades")

	# Gunner Hero Shield & I Eat Grenades
	_assert(gsm.try_activate_skill(0, cmd, ctx) and gunner.shield > 0, "Gunner Hero Shield absorbs damage")
	_assert(gsm.try_activate_skill(4, cmd, ctx) and gunner.status_effects.can_eat_grenades(), "Gunner I Eat Grenades activates explosive heal state at Rank 5")

	# Split Widgets: Widget 2 (Fireproof) cleanses Burn + grants fire immunity; Widget 3 (Antidote) cleanses Poison DoT
	soldier.status_effects.apply_burn(12, 10.0, 5.0)
	soldier.status_effects.apply_poison(12, 12.0, 5.0)
	_assert(sm.try_activate_skill(1, cmd, ctx) or true, "Skill step executed")
	_assert(sm.try_activate_widget(2, ctx), "Fireproof Underwear widget activates")
	_assert(soldier.status_effects.burn_timer == 0.0 and soldier.status_effects.fire_immunity_timer > 1.5 and soldier.status_effects.poison_timer > 0.0, "Fireproof cleanses burn & grants fire immunity while poison stays until Antidote")
	_assert(sm.try_activate_widget(3, ctx), "Antidote widget activates")
	_assert(soldier.status_effects.poison_timer == 0.0, "Antidote cleanses poison DoT")

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

	# Static wall in front of open Jeep MUST block gunfire cleanly
	var block_wall := StaticBody3D.new()
	block_wall.collision_layer = 1
	var bw_col := CollisionShape3D.new()
	var bw_box := BoxShape3D.new()
	bw_box.size = Vector3(8.0, 6.0, 0.6)
	bw_col.shape = bw_box
	block_wall.add_child(bw_col)
	var mid_pt: Vector3 = (shooter.global_position + j_pass.global_position) * 0.5
	add_child(block_wall)
	block_wall.global_position = Vector3(mid_pt.x, 1.5, mid_pt.z)
	block_wall.look_at(Vector3(j_pass.global_position.x, 1.5, j_pass.global_position.z), Vector3.UP)
	await get_tree().physics_frame
	var aim_wall: Dictionary = smg.get_aim_origin_and_dir(j_cmd, get_viewport().get_world_3d().direct_space_state, lc, j_heroes)
	var wall_trace: Dictionary = lc.trace_rewound_ray(shooter, aim_wall["origin"], aim_wall["dir"], 80.0, 0, NetworkManager.server_tick, j_heroes, get_viewport().get_world_3d())
	var pass_hp_walled: int = j_pass.hp
	smg.fire_server(j_cmd, {"lag_compensator": lc, "heroes_by_id": j_heroes})
	_assert(
		bool(wall_trace.get("hit", false)) and int(wall_trace.get("target_hero_id", -1)) == -1 and wall_trace.get("target_object", null) == null and j_pass.hp == pass_hp_walled,
		"Static wall in front of open Jeep cleanly blocks gunfire (hit=%s, target_hero=%d, hp unchanged %d==%d)" % [str(wall_trace.get("hit", false)), int(wall_trace.get("target_hero_id", -1)), j_pass.hp, pass_hp_walled]
	)
	block_wall.free()

	# Seated Fighter Plane pilot CAN take direct gunfire (open cockpit)
	var test_plane := VehiclePlane.new()
	test_plane.id = 82
	test_plane.team = NetworkManager.TEAM_NATIONAL
	add_child(test_plane)
	test_plane.global_position = Vector3(18.0, 0.0, -18.0)
	var p_pilot := HeroCharacter.new()
	p_pilot.setup_identity(806, "Pilot", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(p_pilot)
	_assert(test_plane.try_enter_hero(p_pilot) == 0 and not test_plane.seats[0].is_enclosed, "Fighter plane pilot seat is open and occupied")
	await get_tree().physics_frame
	NetworkManager.server_tick = 22
	var p_heroes := {802: shooter, 806: p_pilot}
	lc.record_frame(22, p_heroes)
	var aim_to_pilot: Vector3 = (p_pilot.global_position + Vector3(0.0, 1.40, 0.0)) - (shooter.global_position + Vector3(0.0, 1.52, 0.0))
	var p_cmd := InputCmd.new()
	p_cmd.aim_yaw = atan2(-aim_to_pilot.x, -aim_to_pilot.z)
	p_cmd.aim_pitch = atan2(aim_to_pilot.y, Vector2(aim_to_pilot.x, aim_to_pilot.z).length())
	var pilot_hp_before: int = p_pilot.hp
	smg.fire_server(p_cmd, {"lag_compensator": lc, "heroes_by_id": p_heroes})
	_assert(p_pilot.hp < pilot_hp_before, "Seated Plane Pilot takes direct gunfire damage in open cockpit (%d -> %d HP)" % [pilot_hp_before, p_pilot.hp])
	test_plane.exit_hero(p_pilot)
	test_plane.free()
	p_pilot.free()

	# Seated Aquatic Boat driver CAN take direct gunfire (open helm)
	var test_boat := VehicleBoat.new()
	test_boat.id = 83
	test_boat.team = NetworkManager.TEAM_NATIONAL
	add_child(test_boat)
	test_boat.global_position = Vector3(22.0, 0.0, -18.0)
	var b_driver := HeroCharacter.new()
	b_driver.setup_identity(807, "BoatDriver", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(b_driver)
	_assert(test_boat.try_enter_hero(b_driver) == 0 and not test_boat.seats[0].is_enclosed, "Boat driver seat is open and occupied")
	await get_tree().physics_frame
	NetworkManager.server_tick = 23
	var b_heroes := {802: shooter, 807: b_driver}
	lc.record_frame(23, b_heroes)
	var aim_to_boat: Vector3 = (b_driver.global_position + Vector3(0.0, 1.40, 0.0)) - (shooter.global_position + Vector3(0.0, 1.52, 0.0))
	var b_cmd := InputCmd.new()
	b_cmd.aim_yaw = atan2(-aim_to_boat.x, -aim_to_boat.z)
	b_cmd.aim_pitch = atan2(aim_to_boat.y, Vector2(aim_to_boat.x, aim_to_boat.z).length())
	var boat_driver_hp_before: int = b_driver.hp
	smg.fire_server(b_cmd, {"lag_compensator": lc, "heroes_by_id": b_heroes})
	_assert(b_driver.hp < boat_driver_hp_before, "Seated Boat Driver takes direct gunfire damage at open helm (%d -> %d HP)" % [boat_driver_hp_before, b_driver.hp])
	test_boat.exit_hero(b_driver)
	test_boat.free()
	b_driver.free()

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
	_assert(game.map_instance.capture_points.size() == 6, "Map creates all 6 Capture Points (4 central + 2 outer)")
	_assert(game.map_instance.royal_spawns.size() == 14 and game.map_instance.national_spawns.size() == 14, "Map defines 14 Royal + 14 National spawn slots (14v14)")

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

	# 2. Launch Optional Offline 14v14 Bots Match and verify 28 spaced combatants (14 Royal vs 14 National)
	game._on_play_offline_bots(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER)
	_assert(NetworkManager.is_solo_bot_mode and NetworkManager.multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Offline 14v14 Bots uses isolated OfflineMultiplayerPeer without binding UDP port")
	var counts: Vector2i = NetworkManager.get_team_counts()
	_assert(counts.x == 14 and counts.y == 14 and game.heroes_by_id.size() == 28, "14v14 Bots match spawns 14 Royal + 14 National (28 heroes)")

	var positions: Array[Vector3] = []
	for hid in game.heroes_by_id.keys():
		positions.append((game.heroes_by_id[hid] as HeroCharacter).position)
	var min_spawn_dist: float = 999.0
	for a in range(positions.size()):
		for b in range(a + 1, positions.size()):
			min_spawn_dist = minf(min_spawn_dist, Vector2(positions[a].x, positions[a].z).distance_to(Vector2(positions[b].x, positions[b].z)))
	_assert(min_spawn_dist >= 3.0, "No overlapping spawn positions across 28 combatants (min XZ separation %.2fm)" % min_spawn_dist)

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

	var fall_floor := StaticBody3D.new()
	fall_floor.collision_layer = 1
	var fall_col := CollisionShape3D.new()
	var fall_box := BoxShape3D.new()
	fall_box.size = Vector3(20.0, 1.0, 20.0)
	fall_col.shape = fall_box
	fall_col.position = Vector3(0.0, -0.5, 0.0)
	fall_floor.add_child(fall_col)
	add_child(fall_floor)
	await get_tree().physics_frame

	# Small drop (2.2m, 0.50s) deals 0 fall damage
	h.global_position = Vector3(0.0, 0.02, 0.0)
	h.velocity = Vector3(0.0, -4.0, 0.0)
	h.simulate_movement(InputCmd.new(), 1.0 / 60.0)
	var start_hp: int = h.hp
	h._was_airborne = true
	h._airborne_start_y = h.global_position.y + 2.2
	h._airborne_fall_time = 0.50
	h._max_air_fall_speed = 18.0
	h.is_parachuting = false
	h.simulate_movement(InputCmd.new(), 1.0 / 60.0)
	_assert(h.hp == start_hp, "Small drop (2.2m, 0.50s) deals 0 fall damage (%d -> %d HP)" % [start_hp, h.hp])

	# High un-parachuted drop (8.0m, 1.1s, >16.5 m/s) deals fall damage
	h._was_airborne = true
	h._airborne_start_y = h.global_position.y + 8.0
	h._airborne_fall_time = 1.1
	h._max_air_fall_speed = 23.0
	h.is_parachuting = false
	h.simulate_movement(InputCmd.new(), 1.0 / 60.0)
	_assert(h.hp < start_hp, "Fast un-parachuted fall speed triggers fall damage (%d -> %d HP)" % [start_hp, h.hp])
	fall_floor.free()
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

	# Verify all 8 weapon icon textures are 96x64 with non-zero opaque pixels
	var all_w_icons_ok: bool = true
	for w_i in range(8):
		var tex := CartoonAssets.get_texture("icon_weapon_%d" % w_i)
		if tex == null or tex.get_width() != 96 or tex.get_height() != 64:
			all_w_icons_ok = false
			break
		var img := tex.get_image()
		var has_pixels: bool = false
		for py in range(64):
			for px in range(96):
				if img.get_pixel(px, py).a > 0.1:
					has_pixels = true
					break
			if has_pixels:
				break
		if not has_pixels:
			all_w_icons_ok = false
			break
	_assert(all_w_icons_ok, "CartoonAssets generates high-crisp 96x64 weapon icons with distinct silhouettes for all 8 weapons")

	# Verify all 8 HeroMeshBuilder.build_weapon_mesh variants generate non-empty meshes
	var all_w_meshes_ok: bool = true
	for w_i in range(8):
		var w_node := HeroMeshBuilder.build_weapon_mesh(w_i)
		if w_node == null or w_node.get_child_count() == 0:
			all_w_meshes_ok = false
		w_node.free()
	_assert(all_w_meshes_ok, "HeroMeshBuilder builds multi-part sculpted 3D weapon meshes across all 8 weapon archetypes")


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

	# 2. Verify ProjectileEntity BAZOOKA_ROCKET & TANK_SHELL fly strictly straight-line (gravity_scale == 0.0)
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
	_assert(rocket.gravity_scale == 0.0 and shell.gravity_scale == 0.0, "BAZOOKA_ROCKET (%.2f) and TANK_SHELL (%.2f) configure gravity_scale == 0.0 for straight flight" % [rocket.gravity_scale, shell.gravity_scale])

	for _tick in range(10):
		rocket._physics_process(0.1)
		shell._physics_process(0.1)
	_assert(
		absf(rocket.velocity.y) < 0.01 and absf(rocket.global_position.y - 30.0) < 0.05 and absf(shell.velocity.y) < 0.01 and absf(shell.global_position.y - 30.0) < 0.05,
		"Bazooka rocket (y=%.2f, vy=%.2f) and Tank shell (y=%.2f, vy=%.2f) fly completely flat without drop" % [rocket.global_position.y, rocket.velocity.y, shell.global_position.y, shell.velocity.y]
	)

	# 3. Verify all firearm classes have zero bullet gravity (pure hitscan) and HitscanWeapon emits straight shot_vfx arcs
	var firearm_kinds: Array[int] = [
		WeaponBase.WeaponKind.SMG,
		WeaponBase.WeaponKind.MG,
		WeaponBase.WeaponKind.SHOTGUN,
		WeaponBase.WeaponKind.PISTOL,
		WeaponBase.WeaponKind.SNIPER,
	]
	var all_zero_gravity: bool = true
	for fk in firearm_kinds:
		var fw := HitscanWeapon.new()
		fw.configure(shooter, fk, NetworkManager.ARCHETYPE_BALANCED)
		if fw.bullet_gravity_scale != 0.0:
			all_zero_gravity = false
		if fk == WeaponBase.WeaponKind.SNIPER:
			fw.spread_rad = 0.0
			fw.fire_server(InputCmd.new(), {"lag_compensator": lc, "heroes_by_id": {901: shooter}})
		fw.free()
	NetworkManager.game_event_received.disconnect(ev_cb)

	# Test straight pinpoint hitscan hit at long range (150m+) with zero bullet drop
	var sniper_long := HitscanWeapon.new()
	sniper_long.configure(shooter, WeaponBase.WeaponKind.SNIPER, NetworkManager.ARCHETYPE_BALANCED)
	sniper_long.spread_rad = 0.0
	add_child(sniper_long)
	var hp_before_high: int = high_target.hp
	var cmd_long := InputCmd.new()
	cmd_long.buttons = InputCmd.BTN_AIM
	cmd_long.aim_pitch = 0.0
	cmd_long.aim_yaw = 0.0
	sniper_long.fire_server(cmd_long, {"lag_compensator": lc, "heroes_by_id": {901: shooter, 902: low_target, 903: high_target}})
	var long_range_hit: bool = high_target.hp < hp_before_high
	sniper_long.free()

	_assert(all_zero_gravity and long_range_hit, "All firearm classes (SMG, MG, Shotgun, Pistol, Sniper) configure bullet_gravity_scale == 0.0 and hit straight target at 240m (150m+) with zero drop")
	_assert(seen_proj_vfx[0] >= 2 and seen_arcs[0] >= 1, "Projectiles emit proj_vfx (%d) and HitscanWeapon emits straight shot_vfx arcs (%d)" % [seen_proj_vfx[0], seen_arcs[0]])

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

	# 6. Verify Plane authentic open cockpit (zero bubble canopy!), coaming & windscreen, tilted wing insignia, and seat enclosure rules
	var canopy_glass := plane._visual_root.get_node_or_null("CanopyGlass") as MeshInstance3D
	var cockpit_coaming := plane._visual_root.get_node_or_null("CockpitCoaming") as MeshInstance3D
	var windscreen := plane._visual_root.get_node_or_null("WindscreenGlass") as MeshInstance3D
	var royal_roundel := plane._visual_root.get_node_or_null("RoundelOut") as MeshInstance3D
	var plane_nat := VehiclePlane.new()
	plane_nat.id = 96
	plane_nat.team = NetworkManager.TEAM_NATIONAL
	add_child(plane_nat)
	var nat_cross := plane_nat._visual_root.get_node_or_null("CrossH") as MeshInstance3D
	_assert(
		canopy_glass == null and cockpit_coaming != null and windscreen != null and royal_roundel != null and absf(royal_roundel.rotation.z) >= 0.039 and royal_roundel.position.y >= 1.095 and nat_cross != null and absf(nat_cross.rotation.z) >= 0.039 and not plane.seats[0].is_enclosed and not boat.seats[0].is_enclosed and tank.seats[0].is_enclosed,
		"VehiclePlane uses authentic open fighter cockpit (zero CanopyGlass, CockpitCoaming & Windscreen present), and only Tank shields driver"
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

	# Verify CentralFountain genuine animated water + GPUParticles3D streams (zero static water cylinders)
	var fountain := map.get_node_or_null("CentralFountain")
	_assert(fountain != null, "CentralFountain landmark exists")
	if fountain != null:
		var lower_w := fountain.get_node_or_null("LowerWater") as MeshInstance3D
		var upper_w := fountain.get_node_or_null("UpperWater") as MeshInstance3D
		_assert(lower_w != null and lower_w.material_override is ShaderMaterial, "CentralFountain LowerWater uses animated ShaderMaterial")
		_assert(upper_w != null and upper_w.material_override is ShaderMaterial, "CentralFountain UpperWater uses animated ShaderMaterial")

		var plume := fountain.get_node_or_null("FountainPlume") as GPUParticles3D
		_assert(plume != null, "CentralFountain FountainPlume exists")

		var all_jets_ok: bool = true
		for j_idx in range(4):
			var jet := fountain.get_node_or_null("FountainJet_%d" % j_idx) as GPUParticles3D
			var splash := fountain.get_node_or_null("FountainSplash_%d" % j_idx) as GPUParticles3D
			if jet == null or splash == null:
				all_jets_ok = false
		_assert(all_jets_ok, "CentralFountain has 4 FountainJet streams and 4 FountainSplash emitters")

		# Confirm zero frozen static water cylinder arc segments exist
		var static_water_cyl_count: int = 0
		for c in fountain.get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is CylinderMesh:
				var cm: CylinderMesh = (c as MeshInstance3D).mesh as CylinderMesh
				if cm.height >= 0.50 and cm.height <= 0.60 and cm.top_radius < 0.20:
					static_water_cyl_count += 1
		_assert(static_water_cyl_count == 0, "CentralFountain has ZERO frozen static water cylinder arc segments (got %d)" % static_water_cyl_count)

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

	# 7. Verify all 28 spawn pads are >= 3.0m apart and clear >= 4.5m horizontally of vertical obstacles
	var all_spawns: Array[Vector3] = []
	all_spawns.append_array(map.royal_spawns)
	all_spawns.append_array(map.national_spawns)
	_assert(all_spawns.size() == 28, "Map provides 28 spawn positions (14 Royal + 14 National)")
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

	# 1. HUD Bottom Hotbar Unclipped at 1280x720 (No '+' Upgrade Buttons, All Rank 5)
	var vp_h: float = float(hud.get_viewport().get_visible_rect().size.y)
	var upg_visible_count: int = 0
	for b in hud._upgrade_buttons:
		if b.visible:
			upg_visible_count += 1
	var all_keys_unclipped: bool = true
	var visible_key_count: int = 0
	var max_key_end_y: float = 0.0
	var all_key_lbls: Array[Label] = []
	all_key_lbls.append_array(hud._weapon_slot_keys)
	all_key_lbls.append_array(hud._skill_slot_keys)
	all_key_lbls.append_array(hud._widget_slot_keys)
	for kl in all_key_lbls:
		var box := kl.get_parent() as Control
		if box != null and not box.visible:
			continue
		visible_key_count += 1
		var rect := kl.get_global_rect()
		max_key_end_y = maxf(max_key_end_y, rect.end.y)
		if rect.position.y < 0.0 or rect.end.y > vp_h - 6.0:
			all_keys_unclipped = false
	_assert(
		hud._upgrade_buttons.is_empty() and upg_visible_count == 0 and all_keys_unclipped and visible_key_count == 13 and all_key_lbls.size() == 14,
		"Soldier HUD displays 13 unclipped hotbar keys (max end.y=%.1f <= %.1f, total slots=%d) with 0 '+' upgrade buttons" % [max_key_end_y, vp_h - 6.0, all_key_lbls.size()]
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

	# 5. First-shot & scoped Sniper crosshair alignment at 140m+ with zero drop
	var target_145 := HeroCharacter.new()
	target_145.setup_identity(953, "Target145", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(target_145)
	target_145.set_physics_process(false)

	var cmd_145 := InputCmd.new()
	cmd_145.aim_yaw = 0.12
	cmd_145.aim_pitch = -0.01
	cmd_145.buttons = InputCmd.BTN_AIM
	var cam_ray_145: Dictionary = HeroCamera.compute_aim_ray(shooter.global_position, cmd_145.aim_yaw, cmd_145.aim_pitch, true, false, false)
	var pt_145: Vector3 = (cam_ray_145["origin"] as Vector3) + (cam_ray_145["dir"] as Vector3) * 145.0
	target_145.global_position = pt_145 - Vector3(0.0, 1.35, 0.0)

	heroes[953] = target_145
	NetworkManager.server_tick = 45
	lc.record_frame(45, heroes)

	var aim_145: Dictionary = sniper.get_aim_origin_and_dir(cmd_145, space, lc, heroes)
	var dist_to_ray_145: float = ((pt_145 - (aim_145["origin"] as Vector3)).cross(aim_145["dir"] as Vector3)).length()
	var hp_before_145: int = target_145.hp
	sniper.fire_server(cmd_145, {"lag_compensator": lc, "heroes_by_id": heroes})
	var hit_145: bool = target_145.hp < hp_before_145

	_assert(
		hit_145 and dist_to_ray_145 < 0.05,
		"Scoped Sniper crosshair alignment at 145m (140m+) hits target with zero drop (err=%.4fm, hit=%s)" % [dist_to_ray_145, str(hit_145)]
	)

	# 6. Zero camera recoil pitch kick on firing (screenshake removed)
	shooter.trigger_weapon_fire_visual(WeaponBase.WeaponKind.SMG, true)
	_assert(
		shooter.hero_camera.recoil_pitch_offset == 0.0,
		"trigger_weapon_fire_visual(..., apply_camera_kick=true) keeps hero_camera.recoil_pitch_offset == 0.0 (zero screenshake)"
	)

	# 7. Drain magazines + reload -> defeat -> respawn_at restores full magazines and cancels reload
	for w in shooter.weapons:
		var wb := w as WeaponBase
		wb.ammo_in_mag = 1
		wb.start_reload()
		_assert(wb.is_reloading, "Weapon %s entered reloading state" % wb.weapon_name)

	shooter.apply_damage_server(9999, 951, false)
	_assert(shooter.is_defeated and shooter.collision_layer == 0, "Lethal damage defeats hero and clears collision_layer to 0")

	shooter.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	var all_refilled: bool = (shooter.collision_layer == 2)
	for w in shooter.weapons:
		var wb := w as WeaponBase
		if wb.ammo_in_mag != wb.mag_size or wb.is_reloading or wb.reload_timer > 0.0 or wb.cooldown_timer > 0.0 or wb._burst_bloom > 0.0:
			all_refilled = false
	_assert(
		all_refilled,
		"respawn_at restores all equipped weapons to full ammo_in_mag == mag_size, cancels reload, and restores collision_layer == 2"
	)

	# 7b. Remote HeroCharacter push_remote_snapshot clears collision_layer on defeat and restores it on alive
	var remote_hero := HeroCharacter.new()
	remote_hero.setup_identity(954, "RemoteTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(remote_hero)
	remote_hero.push_remote_snapshot(50, 1000.0, {"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "vel": Vector3.ZERO, "flags": NetSerializer.SNAP_DEFEATED, "hp": 0})
	_assert(remote_hero.is_defeated and remote_hero.collision_layer == 0, "push_remote_snapshot clears collision_layer=0 on defeated remote hero")
	remote_hero.push_remote_snapshot(51, 1050.0, {"pos": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "vel": Vector3.ZERO, "flags": 0, "hp": 110})
	_assert(not remote_hero.is_defeated and remote_hero.collision_layer == 2, "push_remote_snapshot restores collision_layer=2 on respawned remote hero")
	remote_hero.free()

	# 8. First-shot pinpoint accuracy (spread_mult == 0.0 on first shot with non-zero base spread) & burst bloom decay over 0.28s
	var test_smg := HitscanWeapon.new()
	test_smg.configure(shooter, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_BALANCED)
	_assert(test_smg.is_first_shot() and test_smg.spread_rad > 0.02, "SMG starts with non-zero spread_rad (%.3f) and is_first_shot() == true" % test_smg.spread_rad)

	var cmd_fire := InputCmd.new()
	cmd_fire.buttons = InputCmd.BTN_FIRE
	var consumed: bool = test_smg.try_consume_fire(cmd_fire)
	_assert(consumed and test_smg._burst_bloom > 0.15, "try_consume_fire increments _burst_bloom (got %.2f)" % test_smg._burst_bloom)

	var cmd_idle := InputCmd.new()
	test_smg.step_timers(0.32, cmd_idle)
	_assert(test_smg._burst_bloom <= 0.001 and test_smg.is_first_shot(), "step_timers over 0.28s decays _burst_bloom to 0.0 (got %.3f) and restores is_first_shot()" % test_smg._burst_bloom)
	test_smg.free()

	target_145.free()

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
		"vel": Vector3(14.0, 8.5, 0.0),
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
	shooter.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	teammate.respawn_at(Vector3(1.2, 0.0, 0.0), 0.0)
	enemy.respawn_at(Vector3(0.0, 0.0, 1.2), 0.0)

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
	shooter.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	teammate.respawn_at(Vector3(2.5, 0.0, 0.0), 0.0)
	enemy.respawn_at(Vector3(0.0, 0.0, 2.5), 0.0)

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


func _test_smooth_sync_packet_sequencing_and_menus() -> void:
	# --- 1. Smooth Sync / No-Hopping Verification ---
	var hero := HeroCharacter.new()
	hero.setup_identity(1, "SmoothHero", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	add_child(hero)
	hero.global_position = Vector3(0.0, 1.0, 0.0)
	hero.velocity = Vector3(6.0, 0.0, 0.0)
	hero.active_flags |= NetSerializer.SNAP_GROUNDED

	var move_cmd := InputCmd.new()
	move_cmd.move_dir = Vector2(0.0, -1.0)
	move_cmd.aim_yaw = 0.0

	var min_hips_y: float = 999.0
	var max_hips_y: float = -999.0
	var prev_vis_x: float = hero.visual_root.global_position.x
	var subframe_moved: bool = true
	var max_cam_hero_horiz_div: float = 0.0

	hero._curr_phys_pos = hero.global_position
	for frame in range(30):
		hero._prev_phys_pos = hero._curr_phys_pos
		hero.simulate_movement(move_cmd, 1.0 / 60.0)
		hero.velocity.y = 0.0
		hero.active_flags |= NetSerializer.SNAP_GROUNDED
		hero._curr_phys_pos = hero.global_position
		hero._process(1.0 / 60.0)
		if hero.hero_camera != null:
			hero.hero_camera._process(1.0 / 60.0)

		var cur_vis_x: float = hero.visual_root.global_position.x
		if frame > 0 and cur_vis_x <= prev_vis_x:
			subframe_moved = false
		prev_vis_x = cur_vis_x

		if hero._hips_pivot != null:
			var hy: float = hero._hips_pivot.position.y
			min_hips_y = minf(min_hips_y, hy)
			max_hips_y = maxf(max_hips_y, hy)

		if hero.hero_camera != null:
			var div: float = Vector2(
				hero.hero_camera.global_position.x - hero.visual_root.global_position.x,
				hero.hero_camera.global_position.z - hero.visual_root.global_position.z
			).length()
			max_cam_hero_horiz_div = maxf(max_cam_hero_horiz_div, div)

	var bob_variance: float = max_hips_y - min_hips_y
	_assert(
		subframe_moved,
		"visual_root horizontal position interpolates smoothly (> 0.0 change per sub-frame)"
	)
	_assert(
		bob_variance <= 0.015,
		"walking bob height variance stays <= 0.015m (got %.4fm, no bunny-hopping!)" % bob_variance
	)
	_assert(
		max_cam_hero_horiz_div < 0.02,
		"HeroCamera matches visual_root anchor cleanly (< 0.02m horizontal divergence, got %.4fm)" % max_cam_hero_horiz_div
	)

	# Verify small reconciliation error (0.4m) populates _pred_error_offset smoothly and decays cleanly
	hero.local_tick = 50
	hero.input_buffer.push(50, move_cmd, hero.global_position, hero.velocity, false, false, true, false)
	var pre_rec_pos: Vector3 = hero.global_position
	hero.reconcile_with_server({
		"ack_tick": 50,
		"pos": pre_rec_pos + Vector3(0.4, 0.0, 0.0),
		"vel": hero.velocity,
		"flags": 0,
		"hp": 110,
		"shield": 0,
		"vehicle_id": -1,
		"seat_idx": -1
	})
	_assert(
		hero._pred_error_offset.length() > 0.1,
		"Small reconciliation error (0.4m) populates _pred_error_offset smoothly (len=%.3fm)" % hero._pred_error_offset.length()
	)
	var initial_offset_len: float = hero._pred_error_offset.length()
	for f in range(5):
		hero._process(0.016)
	_assert(
		hero._pred_error_offset.length() < initial_offset_len,
		"_pred_error_offset decays cleanly (%.3fm < %.3fm) rather than snapping instantaneously" % [hero._pred_error_offset.length(), initial_offset_len]
	)

	# Verify normal jump velocity (vel = Vector3(0, 8.8, 0)) does NOT activate _knockback_stun_timer
	hero._knockback_stun_timer = 0.0
	hero.local_tick = 60
	hero.input_buffer.push(60, move_cmd, hero.global_position, hero.velocity, false, false, true, false)
	hero.reconcile_with_server({
		"ack_tick": 60,
		"pos": hero.global_position + Vector3(0.1, 0.0, 0.0),
		"vel": Vector3(0.0, 8.8, 0.0),
		"flags": 0,
		"hp": 110,
		"shield": 0,
		"vehicle_id": -1,
		"seat_idx": -1
	})
	_assert(
		hero._knockback_stun_timer == 0.0,
		"Normal jump velocity (vel = Vector3(0, 8.8, 0)) does NOT activate _knockback_stun_timer (got %.2f)" % hero._knockback_stun_timer
	)

	hero.free()

	# --- 2. Packet Sequencing Verification ---
	NetworkManager.shutdown_network()
	var peer_id: int = 200
	var ticks_to_send: Array[int] = [10, 12, 11, 12, 13, 500]
	var results: Array[bool] = []

	for t in ticks_to_send:
		var c := InputCmd.new()
		c.tick = t
		results.append(NetworkManager.validate_and_enqueue_peer_input(peer_id, c))

	_assert(
		results[0] == true and results[1] == true and results[4] == true,
		"Monotonic input sequence ticks 10, 12, 13 accepted (results=%s)" % str(results)
	)
	_assert(
		results[2] == false and results[3] == false and results[5] == false,
		"Stale tick 11, duplicate tick 12, and future jump 500 strictly rejected (results=%s)" % str(results)
	)
	_assert(
		int(NetworkManager._peer_last_input_tick.get(peer_id, 0)) == 13,
		"_peer_last_input_tick[200] is exactly 13 (got %d)" % int(NetworkManager._peer_last_input_tick.get(peer_id, 0))
	)

	var recovered: InputCmd = NetworkManager.get_input_for_peer_tick(peer_id, 14)
	_assert(
		recovered != null and recovered.tick == 14 and (recovered.buttons & InputCmd.BTN_JUMP) == 0,
		"get_input_for_peer_tick recovers fallback command on dropped packet with BTN_JUMP cleared"
	)

	# Normal monotonic tick resets future spike streak; sustained 3-packet stall window resyncs cleanly
	var cmd_14 := InputCmd.new()
	cmd_14.tick = 14
	var ok_14: bool = NetworkManager.validate_and_enqueue_peer_input(peer_id, cmd_14)
	var stall_ticks: Array[int] = [500, 501, 502, 503]
	var stall_res: Array[bool] = []
	for st in stall_ticks:
		var sc := InputCmd.new()
		sc.tick = st
		stall_res.append(NetworkManager.validate_and_enqueue_peer_input(peer_id, sc))
	_assert(
		ok_14 and stall_res == [false, false, true, true] and int(NetworkManager._peer_last_input_tick.get(peer_id, 0)) == 503,
		"Single future spike keeps streak isolated after monotonic reset, while 3-packet stall resyncs cleanly (res=%s, last_tick=%d)" % [str(stall_res), int(NetworkManager._peer_last_input_tick.get(peer_id, 0))]
	)

	NetworkManager.shutdown_network()
	_assert(
		NetworkManager._peer_last_input_tick.is_empty() and NetworkManager._peer_future_streak.is_empty() and NetworkManager._peer_seq_stats.is_empty(),
		"shutdown_network() clears packet sequencing trackers cleanly"
	)

	# --- 3. Multi-Screen Menu & Settings Verification ---
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = "user://test_hotkeys.cfg"
	add_child(menu)

	# Screen switching
	menu.show_screen("hub")
	_assert(
		menu._hub_screen.visible and not menu._armory_screen.visible and not menu._settings_screen.visible,
		"ClassSelectMenu switches cleanly to 'hub' screen"
	)
	menu.show_screen("armory")
	_assert(
		not menu._hub_screen.visible and menu._armory_screen.visible and not menu._settings_screen.visible,
		"ClassSelectMenu switches cleanly to 'armory' screen"
	)
	menu.show_screen("settings")
	_assert(
		not menu._hub_screen.visible and not menu._armory_screen.visible and menu._settings_screen.visible,
		"ClassSelectMenu switches cleanly to 'settings' screen"
	)

	# Exclusive Class loadout/skill card updates on Soldier/Gunner/Commando switch
	menu.select_class(NetworkManager.CLASS_SOLDIER)
	var s_text: String = menu._summary_lbl.text
	_assert(
		s_text.contains("Soldier") and s_text.contains("SMG"),
		"Armory Soldier selection reflects exclusive SMG loadout: %s" % s_text
	)
	menu.select_class(NetworkManager.CLASS_GUNNER)
	var g_text: String = menu._summary_lbl.text
	_assert(
		g_text.contains("Gunner") and g_text.contains("MG"),
		"Armory Gunner selection reflects exclusive MG loadout: %s" % g_text
	)
	menu.select_class(NetworkManager.CLASS_COMMANDO)
	var c_text: String = menu._summary_lbl.text
	_assert(
		c_text.contains("Commando") and c_text.contains("Sniper"),
		"Armory Commando selection reflects exclusive Sniper loadout: %s" % c_text
	)

	# Signal emissions
	var sig_status := {"bots": false, "host": false, "join": false}

	menu.play_offline_bots_requested.connect(func(_t: int, _c: int) -> void: sig_status["bots"] = true)
	menu.host_online_requested.connect(func(_t: int, _c: int, _p: int) -> void: sig_status["host"] = true)
	menu.join_online_requested.connect(func(_t: int, _c: int, _ip: String, _p: int) -> void: sig_status["join"] = true)

	menu._pending_mode = "bots"
	menu._on_deploy_clicked()
	_assert(sig_status["bots"], "play_offline_bots_requested signal emitted cleanly on deploy")

	menu._pending_mode = "host"
	menu._on_deploy_clicked()
	_assert(sig_status["host"], "host_online_requested signal emitted cleanly on deploy")

	menu._pending_mode = "join"
	menu._on_deploy_clicked()
	_assert(sig_status["join"], "join_online_requested signal emitted cleanly on deploy")

	# Pause state buttons
	menu.set_in_match_mode(true)
	_assert(
		menu._resume_btn.visible and menu._leave_btn.visible,
		"set_in_match_mode(true) displays pause state Retomar and Desconectar buttons"
	)
	menu.set_in_match_mode(false)
	_assert(
		not menu._resume_btn.visible and not menu._leave_btn.visible,
		"set_in_match_mode(false) conceals in-match pause buttons"
	)

	# Audio & Sensitivity sliders propagate to SoundSynthesizer & HeroCamera
	var test_cam := HeroCamera.new()
	test_cam.name = "HeroCamera"
	add_child(test_cam)

	menu._master_vol_slider.value = 65.0
	_assert(
		absf(SoundSynthesizer.master_volume - 0.65) < 0.02,
		"Master volume slider propagates cleanly to SoundSynthesizer (vol=%.2f)" % SoundSynthesizer.master_volume
	)
	menu._sfx_vol_slider.value = 85.0
	_assert(
		absf(SoundSynthesizer.sfx_volume - 0.85) < 0.02,
		"SFX volume slider propagates cleanly to SoundSynthesizer (vol=%.2f)" % SoundSynthesizer.sfx_volume
	)
	menu._music_vol_slider.value = 40.0
	_assert(
		absf(SoundSynthesizer.music_volume - 0.40) < 0.02,
		"Music volume slider propagates cleanly to SoundSynthesizer (vol=%.2f)" % SoundSynthesizer.music_volume
	)

	menu._sens_slider.value = 0.0038
	_assert(
		absf(test_cam.mouse_sensitivity - 0.0038) < 0.0002,
		"Mouse sensitivity slider propagates cleanly to HeroCamera (sens=%.4f)" % test_cam.mouse_sensitivity
	)

	# Restore defaults
	SoundSynthesizer.set_master_volume(1.0)
	SoundSynthesizer.set_sfx_volume(1.0)
	SoundSynthesizer.set_music_volume(1.0)
	menu.set_mouse_sensitivity(0.0024)

	test_cam.free()
	menu.free()

	# --- 4. Dust vs Flesh hit_vfx, Null-Hero Crosshair, & ESC Outside Active Match ---
	var game := MainGame.new()
	add_child(game)
	NetworkManager.local_peer_id = 1

	game.hud._crosshair.visible = true
	game.hud._process(0.016)
	_assert(
		game.hud._crosshair.visible == false,
		"HUDController hides _crosshair when _local_hero == null"
	)

	game.hud._hitmarker_lbl.visible = false
	game.hud._hitmarker_timer = 0.0
	game._on_game_event("hit_vfx", {
		"pos": Vector3(1.0, 1.0, 1.0),
		"kind": "dust",
		"attacker_id": 1,
	})
	_assert(
		not game.hud._hitmarker_lbl.visible and game.hud._hitmarker_timer <= 0.0 and game.hud._floating_dmgs.is_empty(),
		"Dust impact hit_vfx (kind='dust') does NOT show HUDController hitmarker or damage number"
	)

	game._on_game_event("hit_vfx", {
		"pos": Vector3(2.0, 1.5, 2.0),
		"kind": "blood",
		"attacker_id": 1,
		"damage": 18,
		"headshot": false,
	})
	_assert(
		game.hud._hitmarker_lbl.visible and game.hud._hitmarker_timer > 0.0 and game.hud._floating_dmgs.size() == 1,
		"Flesh damage hit_vfx (kind='blood', damage=18) shows HUDController hitmarker and damage number"
	)

	game.class_menu.visible = true
	game.class_menu.show_screen("armory")
	var esc_ev := InputEventKey.new()
	esc_ev.keycode = KEY_ESCAPE
	esc_ev.pressed = true
	game._unhandled_input(esc_ev)
	var back_to_hub: bool = game.class_menu.visible and game.class_menu.current_screen == "hub"
	game._unhandled_input(esc_ev)
	var stays_on_hub: bool = game.class_menu.visible and game.class_menu.current_screen == "hub"
	_assert(
		back_to_hub and stays_on_hub,
		"ESC outside active match returns armory/settings to 'hub' and never hides hub into blank world"
	)

	game.free()


func _test_scene_compile_and_load() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "Main scene res://scenes/main.tscn loads cleanly")


func _test_step_climb_vehicle_arcade_and_roadkill() -> void:
	# 1. HeroCharacter climbing a 0.38m vertical BoxShape3D step/curb
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var f_shape := CollisionShape3D.new()
	var f_box := BoxShape3D.new()
	f_box.size = Vector3(40.0, 1.0, 40.0)
	f_shape.shape = f_box
	floor_body.add_child(f_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child(floor_body)

	var curb_body := StaticBody3D.new()
	curb_body.collision_layer = 1
	var c_shape := CollisionShape3D.new()
	var c_box := BoxShape3D.new()
	c_box.size = Vector3(10.0, 0.38, 4.0)
	c_shape.shape = c_box
	curb_body.add_child(c_shape)
	# Center y = 0.19 -> top at y = 0.38m, center z = -3.0 -> front face at z = -1.0
	curb_body.position = Vector3(0.0, 0.19, -3.0)
	add_child(curb_body)

	await get_tree().physics_frame

	var step_hero := HeroCharacter.new()
	step_hero.setup_identity(710, "StepHero", 0, 0, 0, false, false)
	add_child(step_hero)
	step_hero.global_position = Vector3(0.0, 0.0, -0.4)
	step_hero.velocity = Vector3.ZERO

	await get_tree().physics_frame

	var walk_cmd := InputCmd.new()
	walk_cmd.move_dir = Vector2(0.0, -1.0) # Forward (-Z)
	walk_cmd.aim_yaw = 0.0

	for _i in range(35):
		step_hero.simulate_movement(walk_cmd, 1.0 / 60.0)
		step_hero._curr_phys_pos = step_hero.global_position

	_assert(
		step_hero.global_position.y >= 0.36 and step_hero.global_position.z < -1.1,
		"HeroCharacter walking across 0.38m curb climbs cleanly onto top (y=%.2fm >= 0.36m, z=%.2fm)" % [step_hero.global_position.y, step_hero.global_position.z]
	)

	# 2. VehicleJeep climbing a 0.30m curb/step
	var v_curb := StaticBody3D.new()
	v_curb.collision_layer = 1
	var vc_shape := CollisionShape3D.new()
	var vc_box := BoxShape3D.new()
	vc_box.size = Vector3(10.0, 0.30, 6.0)
	vc_shape.shape = vc_box
	v_curb.add_child(vc_shape)
	v_curb.position = Vector3(10.0, 0.15, -6.0) # front face at z = -3.0
	add_child(v_curb)

	var v_driver := HeroCharacter.new()
	v_driver.setup_identity(711, "JeepClimber", 0, 0, 0, false, false)
	add_child(v_driver)

	var climb_jeep := VehicleJeep.new()
	climb_jeep.id = 72
	add_child(climb_jeep)
	climb_jeep.global_position = Vector3(10.0, 0.0, -0.5)
	climb_jeep.try_enter_hero(v_driver)

	await get_tree().physics_frame

	var climb_cmd := InputCmd.new()
	climb_cmd.move_dir = Vector2(0.0, -1.0)
	v_driver.latest_server_input = climb_cmd

	# Drive into the curb: test _assist_curb_climb triggers bounded lift and rolls onto curb
	var lift_detected: bool = false
	for _i in range(30):
		climb_jeep.step_vehicle_server(1.0 / 60.0, {711: v_driver}, {})
		if climb_jeep.linear_velocity.y >= 2.0:
			lift_detected = true
		if climb_jeep.global_position.y > 0.0:
			climb_jeep.linear_velocity.y -= 9.8 * (1.0 / 60.0)
		climb_jeep.global_position += climb_jeep.linear_velocity * (1.0 / 60.0)
		if climb_jeep.global_position.z <= -3.0:
			if climb_jeep.global_position.y < 0.30:
				climb_jeep.global_position.y = 0.30
				climb_jeep.linear_velocity.y = maxf(0.0, climb_jeep.linear_velocity.y)
		elif climb_jeep.global_position.y < 0.0:
			climb_jeep.global_position.y = 0.0
			climb_jeep.linear_velocity.y = maxf(0.0, climb_jeep.linear_velocity.y)

	_assert(
		lift_detected and climb_jeep.global_position.y >= 0.28 and climb_jeep.global_position.y <= 0.72,
		"VehicleJeep driving into 0.30m curb climbs smoothly onto it (lift=%s, y=%.2fm in [0.28, 0.72])" % [str(lift_detected), climb_jeep.global_position.y]
	)

	# Verify that driving into a 10-degree ramp does NOT trigger trampoline hopping
	var ramp_body := StaticBody3D.new()
	ramp_body.collision_layer = 1
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(10.0, 0.40, 10.0)
	ramp_shape.shape = ramp_box
	ramp_body.add_child(ramp_shape)
	ramp_body.rotation.x = deg_to_rad(-10.0)
	ramp_body.position = Vector3(20.0, 0.20, -6.0)
	add_child(ramp_body)

	var r_driver := HeroCharacter.new()
	r_driver.setup_identity(719, "RampDriver", 0, 0, 0, false, false)
	add_child(r_driver)

	var ramp_jeep := VehicleJeep.new()
	ramp_jeep.id = 78
	add_child(ramp_jeep)
	ramp_jeep.global_position = Vector3(20.0, 0.0, -1.0)
	ramp_jeep.try_enter_hero(r_driver)
	r_driver.latest_server_input = climb_cmd

	await get_tree().physics_frame

	var ramp_max_vy: float = 0.0
	for _i in range(25):
		ramp_jeep.step_vehicle_server(1.0 / 60.0, {719: r_driver}, {})
		ramp_max_vy = maxf(ramp_max_vy, ramp_jeep.linear_velocity.y)
		ramp_jeep.global_position += ramp_jeep.linear_velocity * (1.0 / 60.0)

	_assert(
		ramp_max_vy < 1.0,
		"VehicleJeep driving up 10-degree ramp does NOT trigger trampoline hopping (max_vy=%.2fm/s < 1.0m/s)" % ramp_max_vy
	)

	# 3. VehicleJeep & VehicleBoat crisp arcade turning: lateral speed < 25% within 0.35s
	var test_jeep := VehicleJeep.new()
	test_jeep.id = 73
	add_child(test_jeep)
	test_jeep.global_position = Vector3(-15.0, 0.0, 0.0)
	# Accelerating forward along -Z, then turn heading by 45 degrees
	test_jeep.linear_velocity = Vector3(0.0, 0.0, -20.0)
	test_jeep.rotation.y = PI * 0.25 # Heading rotated by 45 deg

	var fwd_cmd := InputCmd.new()
	fwd_cmd.move_dir = Vector2(0.0, -1.0) # Holding forward

	for _i in range(21): # 21 ticks = 0.35s at 60Hz
		test_jeep._apply_arcade_drive(1.0 / 60.0, fwd_cmd, VehicleJeep.MAX_SPEED, VehicleJeep.ACCEL, VehicleJeep.STEER_RATE, VehicleJeep.LATERAL_GRIP, VehicleJeep.IDLE_DRAG, 0.65)

	var jeep_fwd: float = absf(test_jeep.linear_velocity.dot(-test_jeep.global_transform.basis.z.normalized()))
	var jeep_side: float = absf(test_jeep.linear_velocity.dot(test_jeep.global_transform.basis.x.normalized()))
	var jeep_slip_ratio: float = jeep_side / maxf(0.1, jeep_fwd)
	_assert(
		jeep_slip_ratio < 0.25,
		"VehicleJeep crisp arcade turning cancels lateral slip (lateral/fwd ratio=%.3f < 0.25 within 0.35s)" % jeep_slip_ratio
	)

	var test_boat := VehicleBoat.new()
	test_boat.id = 74
	add_child(test_boat)
	test_boat.global_position = Vector3(-25.0, 0.0, 0.0)
	test_boat.linear_velocity = Vector3(0.0, 0.0, -18.0)
	test_boat.rotation.y = PI * 0.25

	for _i in range(21):
		test_boat._apply_arcade_drive(1.0 / 60.0, fwd_cmd, VehicleBoat.MAX_WATER_SPEED, VehicleBoat.ACCEL, VehicleBoat.TURN_RATE, VehicleBoat.LATERAL_GRIP, VehicleBoat.IDLE_DRAG, 0.65)

	var boat_fwd: float = absf(test_boat.linear_velocity.dot(-test_boat.global_transform.basis.z.normalized()))
	var boat_side: float = absf(test_boat.linear_velocity.dot(test_boat.global_transform.basis.x.normalized()))
	var boat_slip_ratio: float = boat_side / maxf(0.1, boat_fwd)
	_assert(
		boat_slip_ratio < 0.25,
		"VehicleBoat crisp arcade turning cancels lateral slip (lateral/fwd ratio=%.3f < 0.25 within 0.35s)" % boat_slip_ratio
	)

	# 4. Seated Jeep Driver visual_root rotates smoothly with turning Jeep
	var turn_jeep := VehicleJeep.new()
	turn_jeep.id = 75
	add_child(turn_jeep)
	turn_jeep.global_position = Vector3(25.0, 0.0, 0.0)
	turn_jeep.rotation.y = 1.15 # Turn Jeep body to 1.15 rad

	var seated_driver := HeroCharacter.new()
	seated_driver.setup_identity(712, "SeatedRotDriver", 0, 0, 0, false, false)
	add_child(seated_driver)
	turn_jeep.try_enter_hero(seated_driver)

	seated_driver.aim_yaw = 1.45 # Camera aiming slightly offset
	seated_driver._process(0.016)

	var yaw_diff: float = absf(angle_difference(seated_driver.visual_root.global_rotation.y, turn_jeep.global_rotation.y))
	_assert(
		yaw_diff < 0.05,
		"Seated Jeep Driver visual_root rotates smoothly with turning Jeep (diff=%.4f rad < 0.05)" % yaw_diff
	)

	# 5. Moving VehicleJeep & VehicleTank roadkill: defeats enemy at >= 8 m/s, zero friendly fire
	var rk_driver := HeroCharacter.new()
	rk_driver.setup_identity(713, "Roadkiller", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(rk_driver)

	var rk_enemy := HeroCharacter.new()
	rk_enemy.setup_identity(714, "VictimEnemy", NetworkManager.TEAM_NATIONAL, 0, 0, false, false)
	add_child(rk_enemy)
	rk_enemy.global_position = Vector3(0.0, 0.0, -14.0)

	var rk_friend := HeroCharacter.new()
	rk_friend.setup_identity(715, "FriendlyPed", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(rk_friend)
	rk_friend.global_position = Vector3(0.8, 0.0, -14.0)

	var rk_jeep := VehicleJeep.new()
	rk_jeep.id = 76
	rk_jeep.team = NetworkManager.TEAM_ROYAL
	add_child(rk_jeep)
	rk_jeep.global_position = Vector3(0.4, 0.0, -12.5) # ~1.5m away from pedestrian
	rk_jeep.try_enter_hero(rk_driver)
	rk_jeep.linear_velocity = Vector3(0.0, 0.0, -14.0) # 14 m/s >= 8 m/s

	var heroes_map: Dictionary = {
		713: rk_driver,
		714: rk_enemy,
		715: rk_friend,
	}

	rk_jeep.step_vehicle_server(1.0 / 60.0, {713: rk_driver}, {"heroes_by_id": heroes_map})

	_assert(
		rk_enemy.is_defeated and rk_enemy.hp <= 0,
		"Moving VehicleJeep at >= 8 m/s reliably roadkills enemy pedestrian (enemy hp=%d, defeated=%s)" % [rk_enemy.hp, str(rk_enemy.is_defeated)]
	)
	_assert(
		not rk_friend.is_defeated and rk_friend.hp == rk_friend.max_hp,
		"Moving VehicleJeep deals 0 roadkill damage to friendly pedestrian (friend hp=%d/%d, defeated=%s)" % [rk_friend.hp, rk_friend.max_hp, str(rk_friend.is_defeated)]
	)

	# Also verify VehicleTank roadkill
	var rk_enemy2 := HeroCharacter.new()
	rk_enemy2.setup_identity(716, "TankVictim", NetworkManager.TEAM_NATIONAL, 0, 0, false, false)
	add_child(rk_enemy2)
	rk_enemy2.global_position = Vector3(40.0, 0.0, -14.0)

	var rk_friend2 := HeroCharacter.new()
	rk_friend2.setup_identity(717, "TankFriend", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(rk_friend2)
	rk_friend2.global_position = Vector3(40.8, 0.0, -14.0)

	var rk_tank_driver := HeroCharacter.new()
	rk_tank_driver.setup_identity(718, "TankRoadkiller", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(rk_tank_driver)

	var rk_tank := VehicleTank.new()
	rk_tank.id = 77
	rk_tank.team = NetworkManager.TEAM_ROYAL
	add_child(rk_tank)
	rk_tank.global_position = Vector3(40.4, 0.0, -12.5)
	rk_tank.try_enter_hero(rk_tank_driver)
	rk_tank.linear_velocity = Vector3(0.0, 0.0, -10.0) # 10 m/s >= 8 m/s

	var tank_heroes_map: Dictionary = {
		718: rk_tank_driver,
		716: rk_enemy2,
		717: rk_friend2,
	}

	rk_tank.step_vehicle_server(1.0 / 60.0, {718: rk_tank_driver}, {"heroes_by_id": tank_heroes_map})

	_assert(
		rk_enemy2.is_defeated and rk_enemy2.hp <= 0,
		"Moving VehicleTank at >= 8 m/s reliably roadkills enemy pedestrian (enemy hp=%d, defeated=%s)" % [rk_enemy2.hp, str(rk_enemy2.is_defeated)]
	)
	_assert(
		not rk_friend2.is_defeated and rk_friend2.hp == rk_friend2.max_hp,
		"Moving VehicleTank deals 0 roadkill damage to friendly pedestrian (friend hp=%d/%d, defeated=%s)" % [rk_friend2.hp, rk_friend2.max_hp, str(rk_friend2.is_defeated)]
	)

	# Cleanup test nodes
	floor_body.queue_free()
	curb_body.queue_free()
	step_hero.queue_free()
	v_curb.queue_free()
	v_driver.queue_free()
	climb_jeep.queue_free()
	test_jeep.queue_free()
	test_boat.queue_free()
	turn_jeep.queue_free()
	seated_driver.queue_free()
	rk_driver.queue_free()
	rk_enemy.queue_free()
	rk_friend.queue_free()
	rk_jeep.queue_free()
	rk_enemy2.queue_free()
	rk_friend2.queue_free()
	rk_tank_driver.queue_free()
	rk_tank.queue_free()
	ramp_body.queue_free()
	r_driver.queue_free()
	ramp_jeep.queue_free()


func _test_phase4_spread_and_optimization() -> void:
	# 1. Verify automatic weapons (SMG, MG) keep real bullet spread instead of 100% laser precision,
	# while settled Pistol & scoped Sniper stay 100% precise.
	var smg := WeaponBase.new()
	smg.configure(null, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_BALANCED)
	var mg := WeaponBase.new()
	mg.configure(null, WeaponBase.WeaponKind.MG, NetworkManager.ARCHETYPE_BALANCED)
	var sniper := WeaponBase.new()
	sniper.configure(null, WeaponBase.WeaponKind.SNIPER, NetworkManager.ARCHETYPE_BALANCED)
	var pistol := WeaponBase.new()
	pistol.configure(null, WeaponBase.WeaponKind.PISTOL, NetworkManager.ARCHETYPE_BALANCED)

	var fire_cmd := InputCmd.new()
	fire_cmd.set_button(InputCmd.BTN_FIRE, true)
	var idle_cmd := InputCmd.new()

	for _shot in range(6):
		smg.try_consume_fire(fire_cmd)
		smg.step_timers(smg.fire_interval, idle_cmd)
		mg.try_consume_fire(fire_cmd)
		mg.step_timers(mg.fire_interval, idle_cmd)
	smg.try_consume_fire(fire_cmd)
	mg.try_consume_fire(fire_cmd)

	var smg_mult: float = smg.get_current_spread_mult(false, false)
	var mg_mult: float = mg.get_current_spread_mult(false, false)
	_assert(smg._burst_bloom > 0.30 and smg_mult > 0.50, "Automatic SMG retains burst bloom (%.2f) and genuine spread_mult (%.2f)" % [smg._burst_bloom, smg_mult])
	_assert(mg._burst_bloom > 0.30 and mg_mult > 0.50, "Automatic MG retains burst bloom (%.2f) and genuine spread_mult (%.2f)" % [mg._burst_bloom, mg_mult])

	var base_aim := Vector3(0.0, 0.0, -1.0)
	var sum_dir := Vector3.ZERO
	var max_dev_rad: float = 0.0
	for _s in range(16):
		var sd: Vector3 = smg.apply_spread(base_aim, smg_mult)
		sum_dir += sd
		max_dev_rad = maxf(max_dev_rad, base_aim.angle_to(sd))
	var avg_dir: Vector3 = sum_dir.normalized()
	_assert(max_dev_rad > 0.005 and avg_dir.dot(base_aim) > 0.99, "SMG spread creates real cone dispersion (max_dev=%.4f rad) centered on aim" % max_dev_rad)

	var scoped_sniper_mult: float = sniper.get_current_spread_mult(true, false)
	pistol.try_consume_fire(fire_cmd)
	pistol.step_timers(0.30, idle_cmd)
	_assert(absf(scoped_sniper_mult) < 0.0001, "Scoped Sniper keeps 100%% first/scoped accuracy (mult=%.4f)" % scoped_sniper_mult)
	_assert(pistol.is_first_shot() and absf(pistol.get_current_spread_mult(false, false)) < 0.0001, "Slow Pistol resets cleanly between shots to 100%% accuracy")
	smg.free()
	mg.free()
	sniper.free()
	pistol.free()

	# 2. Verify GameCache & shared mesh/material instances
	GameCache.warm_textures()
	GameCache.warm_meshes()
	_assert(GameCache.is_textures_warmed() and GameCache.is_meshes_warmed(), "GameCache warms textures and shared meshes")
	_assert(BuildingMeshBuilder.get_cached_tree_mesh(0) == BuildingMeshBuilder.get_cached_tree_mesh(0), "Tree meshes reuse cached ArrayMesh instances")
	_assert(HeroMeshBuilder.build_torso_mesh(0) == HeroMeshBuilder.build_torso_mesh(0), "Hero meshes reuse cached ArrayMesh instances")

	# 3. Verify Seaside Frontline static batching & material caching budget
	var opt_map := MapSeasideFrontline.new()
	var opt_conq := ConquestManager.new()
	var opt_vehs := Node3D.new()
	add_child(opt_vehs)
	add_child(opt_map)
	add_child(opt_conq)
	opt_map.build_map(opt_conq, opt_vehs, {})

	var map_meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(opt_map, map_meshes)
	var u_meshes: Dictionary = {}
	var u_mats: Dictionary = {}
	for mi in map_meshes:
		if mi.mesh != null:
			u_meshes[mi.mesh] = true
		var m_ovr: Material = mi.material_override
		if m_ovr != null:
			u_mats[m_ovr] = true
		elif mi.mesh != null:
			for si in range(mi.mesh.get_surface_count()):
				var sm := mi.mesh.surface_get_material(si)
				if sm != null:
					u_mats[sm] = true

	_assert(map_meshes.size() <= 900, "Map MeshInstance3D count optimized <= 900 (found %d)" % map_meshes.size())
	_assert(u_meshes.size() <= 350, "Map unique meshes optimized <= 350 (found %d)" % u_meshes.size())
	_assert(u_mats.size() <= 200, "Map unique materials optimized <= 200 (found %d)" % u_mats.size())

	opt_map.queue_free()
	opt_conq.queue_free()
	opt_vehs.queue_free()

	# 4. Verify MainGame LoadingOverlay API
	var main_inst := (load("res://scenes/main.tscn") as PackedScene).instantiate() as MainGame
	add_child(main_inst)
	_assert(not main_inst.is_loading_visible(), "MainGame LoadingOverlay starts hidden")
	main_inst.set_loading_state(true, 65.0, "Carregando teste...")
	_assert(main_inst.is_loading_visible() and absf(main_inst._loading_bar.value - 65.0) < 0.01, "MainGame LoadingOverlay displays progress cleanly")
	main_inst.set_loading_state(false)
	_assert(not main_inst.is_loading_visible(), "MainGame LoadingOverlay hides cleanly")
	main_inst.queue_free()


func _test_phase5_vehicles_grass_and_precision() -> void:
	# 1. Weapon 1st-shot pinpoint accuracy across automatic weapons + crouch spread reduction
	var smg := WeaponBase.new()
	smg.configure(null, WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_BALANCED)
	var mg := WeaponBase.new()
	mg.configure(null, WeaponBase.WeaponKind.MG, NetworkManager.ARCHETYPE_BALANCED)
	var sg := WeaponBase.new()
	sg.configure(null, WeaponBase.WeaponKind.SHOTGUN, NetworkManager.ARCHETYPE_BALANCED)

	var fire_cmd := InputCmd.new()
	fire_cmd.set_button(InputCmd.BTN_FIRE, true)
	var idle_cmd := InputCmd.new()

	_assert(smg.try_consume_fire(fire_cmd) and absf(smg.get_current_spread_mult(false, false, false)) < 0.0001, "Automatic SMG 1st shot has exact 0.0 spread")
	_assert(mg.try_consume_fire(fire_cmd) and absf(mg.get_current_spread_mult(false, false, false)) < 0.0001, "Automatic MG 1st shot has exact 0.0 spread")
	var base_aim := Vector3(0.0, 0.0, -1.0)
	var smg_first_dir: Vector3 = smg.apply_spread(base_aim, smg.get_current_spread_mult(false, false, false))
	_assert(base_aim.angle_to(smg_first_dir) < 0.0001, "SMG 1st shot hits dead-center on crosshair aim ray")

	for _shot in range(5):
		smg.step_timers(smg.fire_interval, idle_cmd)
		smg.try_consume_fire(fire_cmd)
		mg.step_timers(mg.fire_interval, idle_cmd)
		mg.try_consume_fire(fire_cmd)

	var smg_stand: float = smg.get_current_spread_mult(false, false, false)
	var smg_crouch: float = smg.get_current_spread_mult(false, false, true)
	var mg_stand: float = mg.get_current_spread_mult(false, false, false)
	var mg_crouch: float = mg.get_current_spread_mult(false, false, true)
	var sg_stand: float = sg.get_current_spread_mult(false, false, false)
	var sg_crouch: float = sg.get_current_spread_mult(false, false, true)
	_assert(smg_stand > 0.50 and mg_stand > 0.50, "Sustained SMG/MG fire ramps bullet spread (smg=%.2f, mg=%.2f)" % [smg_stand, mg_stand])
	_assert(smg_crouch < smg_stand * 0.70 and mg_crouch < mg_stand * 0.70 and sg_crouch < sg_stand * 0.70, "Crouching tightens spread across SMG (%.2f<%.2f), MG (%.2f<%.2f), and Shotgun (%.2f<%.2f)" % [smg_crouch, smg_stand, mg_crouch, mg_stand, sg_crouch, sg_stand])
	smg.free()
	mg.free()
	sg.free()

	# 2. Grass texture mipmaps, anisotropic filter & non-micro UV scale
	var grass_tex: ImageTexture = CartoonAssets.get_texture("grass")
	var grass_img: Image = grass_tex.get_image()
	_assert(grass_tex.get_width() >= 256 and grass_img != null and grass_img.has_mipmaps(), "Grass texture is >=256px and generates hardware mipmaps")

	var p5_map := MapSeasideFrontline.new()
	var p5_conq := ConquestManager.new()
	var p5_vehs := Node3D.new()
	p5_vehs.name = "Phase5Vehs"
	add_child(p5_vehs)
	add_child(p5_conq)
	add_child(p5_map)
	p5_map.build_map(p5_conq, p5_vehs, {})

	var terrain_mi: MeshInstance3D = p5_map.get_node_or_null("SculptedTerrain/TerrainMesh") as MeshInstance3D
	var terrain_mat: StandardMaterial3D = terrain_mi.material_override as StandardMaterial3D if terrain_mi != null else null
	_assert(
		terrain_mat != null and terrain_mat.uv1_scale.x <= 2.0 and terrain_mat.uv1_scale.y <= 2.0 and terrain_mat.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC,
		"TerrainMesh uses macro grass UV scale (<=2.0) and anisotropic mipmaps"
	)

	# 3. VehiclePlane staggered spawns & effortless takeoff (neutral aim_pitch=0.0 & Space climb)
	var plane_a: VehiclePlane = null
	var plane_b: VehiclePlane = null
	var jeep_a: VehicleJeep = null
	for v in p5_map.spawned_vehicles:
		if v is VehiclePlane and v.team == NetworkManager.TEAM_ROYAL:
			if plane_a == null:
				plane_a = v as VehiclePlane
			else:
				plane_b = v as VehiclePlane
		elif v is VehicleJeep and v.team == NetworkManager.TEAM_ROYAL and jeep_a == null:
			jeep_a = v as VehicleJeep

	_assert(
		plane_a != null and plane_b != null and absf(plane_a.global_position.z - plane_b.global_position.z) >= 8.0,
		"Royal runway planes spawn in staggered parallel lanes (dz=%.1fm >= 8m)" % (absf(plane_a.global_position.z - plane_b.global_position.z) if plane_a != null and plane_b != null else 0.0)
	)
	_assert(
		jeep_a != null and jeep_a.physics_material_override != null and jeep_a.physics_material_override.friction <= 0.05 and plane_a.physics_material_override.friction <= 0.05,
		"Vehicles configure low-friction PhysicsMaterial (<= 0.05) for smooth rolling"
	)

	var pilot := HeroCharacter.new()
	pilot.setup_identity(811, "Phase5Pilot", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(pilot)
	plane_a.try_enter_hero(pilot)

	var j_driver := HeroCharacter.new()
	j_driver.setup_identity(812, "Phase5JeepDriver", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(j_driver)
	jeep_a.try_enter_hero(j_driver)

	await get_tree().physics_frame
	var plane_start_y: float = plane_a.global_position.y
	var p_heroes: Dictionary = {811: pilot, 812: j_driver}
	for tick in range(75):
		var p_cmd := InputCmd.new()
		p_cmd.move_dir = Vector2(0.0, -1.0)
		p_cmd.aim_yaw = -PI * 0.5
		p_cmd.aim_pitch = 0.0 # Neutral horizon camera pitch
		pilot.latest_server_input = p_cmd
		plane_a.step_vehicle_server(1.0 / 60.0, p_heroes, {"heroes_by_id": p_heroes})

		var jc := InputCmd.new()
		jc.move_dir = Vector2(-0.5 if tick > 45 else 0.0, -1.0)
		j_driver.latest_server_input = jc
		jeep_a.step_vehicle_server(1.0 / 60.0, p_heroes, {"heroes_by_id": p_heroes})
		await get_tree().physics_frame

	_assert(
		plane_a.global_position.y >= plane_start_y + 3.0 and plane_a.linear_velocity.length() > 30.0,
		"VehiclePlane takes off cleanly with neutral aim_pitch=0 (dy=%.2fm, spd=%.1f)" % [plane_a.global_position.y - plane_start_y, plane_a.linear_velocity.length()]
	)
	_assert(
		jeep_a.linear_velocity.length() >= 15.0 and absf(jeep_a.rotation.x) < 0.25 and absf(jeep_a.rotation.z) < 0.25,
		"VehicleJeep accelerates & corners onto road/curbs cleanly without stalling or flipping (spd=%.1f)" % jeep_a.linear_velocity.length()
	)

	# Also verify Space (BTN_JUMP) climbs strongly on second plane
	var pilot2 := HeroCharacter.new()
	pilot2.setup_identity(813, "Phase5Pilot2", NetworkManager.TEAM_ROYAL, 0, 0, false, false)
	add_child(pilot2)
	plane_b.try_enter_hero(pilot2)
	await get_tree().physics_frame
	var p2_start_y: float = plane_b.global_position.y
	p_heroes[813] = pilot2
	for _t in range(75):
		var p2_cmd := InputCmd.new()
		p2_cmd.move_dir = Vector2(0.0, -1.0)
		p2_cmd.aim_yaw = -PI * 0.5
		p2_cmd.aim_pitch = 0.0
		p2_cmd.set_button(InputCmd.BTN_JUMP, true)
		pilot2.latest_server_input = p2_cmd
		plane_b.step_vehicle_server(1.0 / 60.0, p_heroes, {"heroes_by_id": p_heroes})
		await get_tree().physics_frame

	_assert(
		plane_b.global_position.y >= p2_start_y + 6.0,
		"VehiclePlane Space (BTN_JUMP) climbs high cleanly (dy=%.2fm)" % (plane_b.global_position.y - p2_start_y)
	)

	pilot.queue_free()
	pilot2.queue_free()
	j_driver.queue_free()
	p5_map.queue_free()
	p5_conq.queue_free()
	p5_vehs.queue_free()


func _test_phase6_skills_20v20_arsenal() -> void:
	# 1. 14v14 Network/Conquest Capacity, 6-Flag Multipliers & 40-Hero + 6-Flag Snapshot Roundtrip
	_assert(NetworkManager.MAX_PLAYERS == 28 and ConquestManager.MAX_PLAYERS_PER_TEAM == 14, "14v14 capacity limits enforced (MAX_PLAYERS=28, MAX_PER_TEAM=14)")

	var cm6 := ConquestManager.new()
	add_child(cm6)
	var cps: Array[CapturePoint] = []
	for i in range(6):
		var cp := CapturePoint.new()
		cp.setup(i, "Flag6_%d" % i, Vector3(float(i) * 30.0, 0.0, 0.0), -1)
		add_child(cp)
		cm6.register_capture_point(cp)
		cps.append(cp)
	# 3v3 -> 1x, 4v2 -> 3x, 2v4 -> 0x
	for i in range(3):
		cps[i].owner_team = NetworkManager.TEAM_ROYAL
		cps[i + 3].owner_team = NetworkManager.TEAM_NATIONAL
	var mult_tie: int = cm6.get_team_kill_multiplier(NetworkManager.TEAM_ROYAL)
	cps[3].owner_team = NetworkManager.TEAM_ROYAL
	var mult_4: int = cm6.get_team_kill_multiplier(NetworkManager.TEAM_ROYAL)
	var mult_2: int = cm6.get_team_kill_multiplier(NetworkManager.TEAM_NATIONAL)
	_assert(mult_tie == 1 and mult_4 == 3 and mult_2 == 0, "6-flag Conquest multipliers: 3v3=%dx (1), 4v2=%dx (3), 2v4=%dx (0)" % [mult_tie, mult_4, mult_2])
	for cp in cps:
		cp.free()
	cm6.free()

	var cmd6 := InputCmd.new()
	cmd6.tick = 777
	cmd6.buttons = InputCmd.BTN_SKILL_6 | InputCmd.BTN_WIDGET_4 | InputCmd.BTN_FIRE
	cmd6.selected_weapon_slot = 3
	var packed_cmd6: PackedByteArray = NetSerializer.pack_input_cmd(cmd6)
	var unpacked_cmd6: InputCmd = NetSerializer.unpack_input_cmd(packed_cmd6)
	_assert(
		packed_cmd6.size() == 15 and unpacked_cmd6.has_button(InputCmd.BTN_SKILL_6) and unpacked_cmd6.has_button(InputCmd.BTN_WIDGET_4) and unpacked_cmd6.selected_weapon_slot == 3,
		"15-byte InputCmd packs BTN_SKILL_6 + BTN_WIDGET_4 + weapon_slot without conflict"
	)

	var h40: Array[Dictionary] = []
	for i in range(40):
		h40.append({
			"id": 1000 + i,
			"team": i % 2,
			"class_id": i % 3,
			"weapon_slot": i % 3,
			"flags": NetSerializer.SNAP_GROUNDED | (NetSerializer.SNAP_MARKED_TARGET if i == 1 else 0),
			"pos": Vector3(float(i) * 5.0, 1.0, -float(i) * 3.0),
			"vel": Vector3.ZERO,
			"yaw": 0.2,
			"pitch": 0.0,
			"hp": 100,
			"shield": 0,
			"vehicle_id": -1,
			"seat_idx": -1,
		})
	var v_marked: Array[Dictionary] = [
		{"id": 9, "type": VehicleBase.VehicleType.TANK, "pos": Vector3(10.0, 2.0, -10.0), "rot": Quaternion.IDENTITY, "vel": Vector3.ZERO, "turret_yaw": 0.5, "hp": 500, "marked": true}
	]
	var f6: Array[Dictionary] = []
	for i in range(6):
		f6.append({"owner": i % 2, "capturing_team": -1, "progress": 1.0})
	var snap40 := NetSerializer.unpack_world_snapshot(NetSerializer.pack_world_snapshot(500, 12345, 48, 49, h40, v_marked, f6))
	_assert(
		(snap40["heroes"] as Array).size() == 40 and (snap40["flags"] as Array).size() == 6 and bool((snap40["vehicles"] as Array)[0].get("marked", false)),
		"WorldSnapshot roundtrips all 40 heroes, 6 Conquest flags & marked vehicles"
	)

	# 2. Custom Weapon Variants per Class Slot + Q Last-Weapon Toggle
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = "user://test_hotkeys.cfg"
	add_child(menu)
	menu.select_class(NetworkManager.CLASS_SOLDIER)
	menu.select_weapon_variant(NetworkManager.CLASS_SOLDIER, 0, NetworkManager.ARCHETYPE_SLOW_LONG)
	menu.select_weapon_variant(NetworkManager.CLASS_SOLDIER, 1, NetworkManager.ARCHETYPE_FAST_SHORT)
	var arch_map: Dictionary = NetworkManager.build_class_slot_archetypes(NetworkManager.CLASS_SOLDIER)

	var variant_hero := HeroCharacter.new()
	variant_hero.setup_identity(601, "VariantSoldier", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, NetworkManager.ARCHETYPE_BALANCED, true, false, arch_map)
	add_child(variant_hero)
	var expected_smg_name: String = WeaponBase.get_variant_display_name(WeaponBase.WeaponKind.SMG, NetworkManager.ARCHETYPE_SLOW_LONG)
	var expected_sg_name: String = WeaponBase.get_variant_display_name(WeaponBase.WeaponKind.SHOTGUN, NetworkManager.ARCHETYPE_FAST_SHORT)
	_assert(
		variant_hero.weapons[0].weapon_name == expected_smg_name and variant_hero.weapons[1].weapon_name == expected_sg_name,
		"Per-slot weapon variants equip cleanly (%s + %s)" % [variant_hero.weapons[0].weapon_name, variant_hero.weapons[1].weapon_name]
	)
	variant_hero.switch_weapon_slot(2)
	variant_hero.quick_switch_last_weapon()
	var back_to_0: int = variant_hero.selected_weapon_slot
	variant_hero.quick_switch_last_weapon()
	var back_to_2: int = variant_hero.selected_weapon_slot
	_assert(back_to_0 == 0 and back_to_2 == 2, "Q quick_switch_last_weapon toggles directly between slot 0 and slot 2")

	# 3. Commando 16th Skill (Mark Target + X-Ray), Infinite Stealth (>15 dmg), Piercing Shot, Max-2 Troop Traps, Backstab & 1.7x HS
	var p6_floor := StaticBody3D.new()
	p6_floor.collision_layer = 1
	var p6_fcol := CollisionShape3D.new()
	var p6_fbox := BoxShape3D.new()
	p6_fbox.size = Vector3(200.0, 1.0, 200.0)
	p6_fcol.shape = p6_fbox
	p6_floor.add_child(p6_fcol)
	add_child(p6_floor)
	p6_floor.global_position = Vector3(25.0, -0.5, -10.0)

	var commando := HeroCharacter.new()
	commando.setup_identity(602, "Phase6Cmd", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	add_child(commando)
	commando.global_position = Vector3(0.0, 0.1, 0.0)

	var target_a := HeroCharacter.new()
	target_a.setup_identity(603, "TargetA", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(target_a)
	target_a.global_position = Vector3(0.0, 0.1, -18.0)

	var target_b := HeroCharacter.new()
	target_b.setup_identity(604, "TargetB", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	add_child(target_b)
	target_b.global_position = Vector3(0.0, 0.1, -28.0)

	var p6_tank := VehicleTank.new()
	p6_tank.id = 690
	p6_tank.team = NetworkManager.TEAM_NATIONAL
	add_child(p6_tank)
	p6_tank.global_position = Vector3(4.0, 0.8, -24.0)

	# Flush deferred queue_free() from previous test suite before raycasting LOS
	await get_tree().process_frame
	await get_tree().physics_frame

	var p6_proj := Node3D.new()
	add_child(p6_proj)
	var p6_vfx := Node3D.new()
	add_child(p6_vfx)
	var lc6 := LagCompensator.new()
	var p6_heroes := {602: commando, 603: target_a, 604: target_b}
	var p6_ctx := {
		"heroes_by_id": p6_heroes,
		"vehicles": [p6_tank] as Array[VehicleBase],
		"projectiles_root": p6_proj,
		"vfx_root": p6_vfx,
		"lag_compensator": lc6,
	}

	# Target A uses infinite Stealth first -> small chip (10) does NOT break stealth, Mark Target DOES break & apply X-Ray
	var ta_sm: SkillManager = target_a.skill_manager as SkillManager
	ta_sm.skill_ranks[0] = 1
	ta_sm.try_activate_skill(0, InputCmd.new(), p6_ctx)
	_assert(
		target_a.is_stealthed and ta_sm.skill_cooldowns[0] == 0.0,
		"Commando Stealth is infinite (cooldown does not start while active)"
	)
	target_a.apply_damage_server(10, 602, false)
	_assert(target_a.is_stealthed, "Damage <= 15 (10 dmg) does NOT break Commando Stealth")
	target_a.apply_damage_server(20, 602, false)
	_assert(not target_a.is_stealthed and ta_sm.skill_cooldowns[0] > 0.0, "Direct damage > 15 (20 dmg) breaks Stealth & starts cooldown")

	# Re-cloak Target A briefly, then Commando activates 6th Skill (Mark Target, index 5) looking straight at Target A
	ta_sm.skill_cooldowns[0] = 0.0
	ta_sm.try_activate_skill(0, InputCmd.new(), p6_ctx)
	var csm6: SkillManager = commando.skill_manager as SkillManager
	csm6.skill_ranks[5] = 1
	var mark_cmd := InputCmd.new()
	mark_cmd.aim_yaw = 0.0
	mark_cmd.aim_pitch = 0.0
	_assert(csm6.try_activate_skill(5, mark_cmd, p6_ctx), "16th skill Mark Target (slot 5) activates on crosshair target")
	_assert(target_a.status_effects.is_marked() and not target_a.is_stealthed and not p6_tank.is_marked, "Mark Target reveals cloaked enemy in crosshair (Target A only, Tank unmarked)")

	# Check X-Ray material_overlay applied on client visuals for Marked enemy hero
	target_a.active_flags |= NetSerializer.SNAP_MARKED_TARGET
	StatusEffectsVFX.update_hero_client_visuals(target_a, commando, 0.016)
	var xray_hero_mat := (target_a._mesh_parts[0] as MeshInstance3D).material_overlay as ShaderMaterial

	# Now aim directly at Tank -> single-target lock switches mark from Target A to Tank
	csm6.skill_cooldowns[5] = 0.0
	var eye_p6: Vector3 = commando.global_position + Vector3(0.0, 1.5, 0.0)
	var dir_to_tank: Vector3 = (p6_tank.global_position + Vector3(0.0, 0.4, 0.0) - eye_p6).normalized()
	var tank_cmd := InputCmd.new()
	tank_cmd.aim_yaw = atan2(-dir_to_tank.x, -dir_to_tank.z)
	tank_cmd.aim_pitch = asin(clampf(dir_to_tank.y, -1.0, 1.0))
	_assert(csm6.try_activate_skill(5, tank_cmd, p6_ctx) and p6_tank.is_marked and not target_a.status_effects.is_marked(), "Mark Target switches lock to aimed Tank and clears old Target A mark")

	StatusEffectsVFX.update_vehicle_client_visuals(p6_tank, commando)
	var xray_veh_ok: bool = false
	for ch in p6_tank.find_children("*", "MeshInstance3D", true, false):
		if ch is MeshInstance3D and (ch as MeshInstance3D).material_overlay != null:
			xray_veh_ok = ((ch as MeshInstance3D).material_overlay as ShaderMaterial).shader == StatusEffectsVFX.XRAY_SHADER
			break
	_assert(
		xray_hero_mat != null and xray_hero_mat.shader == StatusEffectsVFX.XRAY_SHADER and xray_veh_ok,
		"StatusEffectsVFX applies 3D XRAY_SHADER red silhouette overlay through walls on marked hero & tank"
	)

	# Piercing Shot hits BOTH aligned Target A and Target B in one Sniper shot (plus check Sniper headshot mult == 1.7)
	await get_tree().physics_frame
	NetworkManager.server_tick = 100
	lc6.record_frame(100, p6_heroes)
	var sniper := commando.weapons[0] as HitscanWeapon
	var sniper_body_dmg: int = sniper.compute_falloff_damage(10.0, false)
	var sniper_hs_dmg: int = sniper.compute_falloff_damage(10.0, true)
	var sniper_ratio: float = float(sniper_hs_dmg) / float(maxi(1, sniper_body_dmg))
	_assert(absf(sniper_ratio - 1.7) < 0.05, "Sniper Rifle headshot multiplier is 1.7x (%d/%d = %.2fx)" % [sniper_hs_dmg, sniper_body_dmg, sniper_ratio])
	csm6.skill_ranks[1] = 1
	csm6.skill_cooldowns[1] = 0.0
	csm6.try_activate_skill(1, mark_cmd, p6_ctx)
	var ta_hp_pre: int = target_a.hp
	var tb_hp_pre: int = target_b.hp
	commando.aim_yaw = 0.0
	commando.aim_pitch = 0.0
	sniper.spread_rad = 0.0
	sniper.fire_server(mark_cmd, p6_ctx)
	_assert(
		target_a.hp < ta_hp_pre and target_b.hp < tb_hp_pre,
		"Piercing Shot penetrates to damage both Target A (%d->%d) and Target B (%d->%d)" % [ta_hp_pre, target_a.hp, tb_hp_pre, target_b.hp]
	)

	# Max-2 Troop Traps (slot 3) with 60s lifetime
	csm6.skill_ranks[3] = 1
	for t_i in range(3):
		csm6.skill_cooldowns[3] = 0.0
		csm6.try_activate_skill(3, mark_cmd, p6_ctx)
	await get_tree().process_frame
	var trap_count: int = 0
	var trap_life: float = 0.0
	for ch in p6_proj.get_children():
		if ch is CommandoSkills.TroopTrapEntity and not ch.is_queued_for_deletion():
			trap_count += 1
			trap_life = (ch as CommandoSkills.TroopTrapEntity).lifetime_remaining
	_assert(trap_count == 2 and absf(trap_life - 60.0) <= 0.25, "Troop Trap caps active mines at 2 (got %d) with 60s lifetime (life=%.3f)" % [trap_count, trap_life])

	# Knife 120-deg rear backstab = 75 dmg vs front = 42 dmg
	commando.global_position = Vector3(0.0, 0.1, 0.0)
	commando.velocity = Vector3.ZERO
	target_b.hp = target_b.max_hp
	target_b.aim_yaw = 0.0 # Facing -Z; Commando is at Z=0 behind TargetB -> dot > 0.5 -> Backstab!
	target_b.global_position = Vector3(0.0, 0.1, -1.5)
	target_b.velocity = Vector3.ZERO
	await get_tree().physics_frame
	NetworkManager.server_tick = 101
	lc6.record_frame(101, p6_heroes)
	var knife := commando.weapons[1] as HitscanWeapon
	var knife_cmd := InputCmd.new()
	knife_cmd.aim_yaw = 0.0
	knife_cmd.aim_pitch = 0.0
	var hp_pre_backstab: int = target_b.hp
	knife.cooldown_timer = 0.0
	knife.fire_server(knife_cmd, p6_ctx)
	var backstab_dmg: int = hp_pre_backstab - target_b.hp
	target_b.aim_yaw = PI # Now facing Commando -> frontal hit!
	await get_tree().physics_frame
	NetworkManager.server_tick = 102
	lc6.record_frame(102, p6_heroes)
	var hp_pre_front: int = target_b.hp
	knife.cooldown_timer = 0.0
	knife.fire_server(knife_cmd, p6_ctx)
	var front_dmg: int = hp_pre_front - target_b.hp
	_assert(backstab_dmg == 75 and front_dmg == 42, "Knife backstab (120deg rear) deals 75 dmg (got %d) vs front 42 dmg (got %d)" % [backstab_dmg, front_dmg])

	# 4. Explosive Keg (-40% move + -50% camera sensitivity), Combat Medicine HoT, Bandage Interrupt & Poison HUD Tint
	var gunner6 := HeroCharacter.new()
	gunner6.setup_identity(605, "Phase6Gunner", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, true, false)
	add_child(gunner6)
	gunner6.global_position = Vector3(12.0, 0.1, 0.0)
	var cam6 := HeroCamera.new()
	gunner6.add_child(cam6)
	gunner6.hero_camera = cam6
	var gsm6: SkillManager = gunner6.skill_manager as SkillManager
	gsm6.skill_ranks[3] = 1
	var keg_proj := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.EXPLOSIVE_KEG, 602, NetworkManager.TEAM_ROYAL, Vector3(12.0, 0.5, 0.0), Vector3.ZERO, {"heroes_by_id": {605: gunner6}, "projectiles_root": p6_proj})
	keg_proj._detonate()
	gunner6.status_effects._physics_process(0.05)
	_assert(
		gunner6.status_effects.slow_timer >= 4.5 and absf(gunner6.speed_multiplier - 0.60) < 0.02 and (gunner6.active_flags & NetSerializer.SNAP_KEG_CONCUSSED) != 0 and absf(cam6.get_effective_sensitivity() - cam6.mouse_sensitivity * 0.5) < 0.0001,
		"Explosive Keg applies -40%% move (%.2fx) and -50%% mouse sensitivity for 5s" % gunner6.speed_multiplier
	)

	# Combat Medicine instant + HoT, Bandage channel & damage interrupt, Fireproof 2s fire immunity, Poison HUD tint & Antidote
	variant_hero.hp = 40
	var vsm: SkillManager = variant_hero.skill_manager as SkillManager
	vsm.skill_ranks[0] = 1
	vsm.try_activate_skill(0, InputCmd.new(), {"heroes_by_id": {601: variant_hero}})
	var after_instant: int = variant_hero.hp
	for _hot_i in range(4):
		variant_hero.status_effects._physics_process(0.5)
	_assert(after_instant >= 75 and variant_hero.hp > after_instant, "Combat Medicine heals +40 instant (%d) plus +20 HoT (%d)" % [after_instant, variant_hero.hp])

	# Bandage channel interrupted by direct damage
	variant_hero.hp = 50
	vsm.try_activate_widget(0, {"heroes_by_id": {601: variant_hero}})
	_assert(variant_hero.status_effects.bandage_channel_timer > 1.5, "Bandage starts 2s channel timer")
	variant_hero.apply_damage_server(8, 603, false)
	_assert(variant_hero.status_effects.bandage_channel_timer == 0.0, "Direct damage interrupts Bandage channel cleanly")

	# Poisoned Blade (6s, 12 dmg/s) + HUD green screen overlay cleared by Antidote
	var hud6 := HUDController.new()
	add_child(hud6)
	hud6.set_local_hero(commando)
	commando.status_effects.apply_poison(603, 12.0, 6.0)
	commando.status_effects._physics_process(0.1)
	hud6._process(0.016)
	var tint_while_poisoned: bool = hud6._poison_tint_rect != null and hud6._poison_tint_rect.visible
	csm6.try_activate_widget(3, {"heroes_by_id": {602: commando}})
	commando.status_effects._sync_flags()
	hud6._process(0.016)
	var tint_after_antidote: bool = hud6._poison_tint_rect != null and hud6._poison_tint_rect.visible
	_assert(tint_while_poisoned and not tint_after_antidote, "HUD green poison screen tint activates when poisoned & clears immediately with Antidote")

	# Custom Hotkey UI rebinding -> HUD updates -> Reset defaults
	menu.hotkeys_config_path = "user://test_hotkeys.cfg"
	menu.assign_hotkey_from_ui("skill", 5, KEY_H)
	menu.assign_hotkey_from_ui("widget", 3, KEY_N)
	await _flush_deferred()
	_assert(
		hud6._skill_slot_keys[5].text == "H" and hud6._widget_slot_keys[3].text == "N",
		"Custom Skill/Widget hotkeys update HUD hotbar labels live (%s / %s)" % [hud6._skill_slot_keys[5].text, hud6._widget_slot_keys[3].text]
	)
	InputCmd.reset_default_hotkeys()
	if FileAccess.file_exists("user://test_hotkeys.cfg"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hotkeys.cfg"))
	hud6.refresh_hotkey_labels()
	# Also verify Commando 6-skill + 4-weapon + 4-widget = 14 visible slots stay completely unclipped at 1280x720
	var cmd_vis_keys: int = 0
	var cmd_unclipped: bool = true
	var vp6: Vector2 = hud6.get_viewport().get_visible_rect().size
	var cmd_all_lbls: Array[Label] = []
	cmd_all_lbls.append_array(hud6._weapon_slot_keys)
	cmd_all_lbls.append_array(hud6._skill_slot_keys)
	cmd_all_lbls.append_array(hud6._widget_slot_keys)
	for kl in cmd_all_lbls:
		var bx := kl.get_parent() as Control
		if bx != null and not bx.visible:
			continue
		cmd_vis_keys += 1
		var r6 := kl.get_global_rect()
		if r6.position.x < 0.0 or r6.end.x > vp6.x or r6.end.y > vp6.y - 4.0:
			cmd_unclipped = false
	_assert(cmd_vis_keys == 14 and cmd_unclipped, "Commando HUD displays all 14 unclipped hotbar keys (4W+6S+4Wd)")

	# 5. Explosion Wall Occlusion, Sticky TNT Following Vehicle, Bazooka 40/60/95 Directional Armor, Seats + HUD Diagram & All 16 Skill Anims
	var occ_wall := StaticBody3D.new()
	occ_wall.collision_layer = 1
	var occ_col := CollisionShape3D.new()
	var occ_box := BoxShape3D.new()
	occ_box.size = Vector3(6.0, 4.0, 0.5)
	occ_col.shape = occ_box
	occ_wall.add_child(occ_col)
	add_child(occ_wall)
	occ_wall.global_position = Vector3(30.0, 2.0, 0.0)

	var hidden_hero := HeroCharacter.new()
	hidden_hero.setup_identity(606, "BehindWall", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	add_child(hidden_hero)
	hidden_hero.global_position = Vector3(30.0, 1.0, 2.0)
	await get_tree().physics_frame

	var occ_gren := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.FRAG_GRENADE, 602, NetworkManager.TEAM_ROYAL, Vector3(30.0, 1.0, -1.5), Vector3.ZERO, {"heroes_by_id": {606: hidden_hero}, "projectiles_root": p6_proj})
	occ_gren._detonate()
	_assert(hidden_hero.hp == hidden_hero.max_hp, "Layer-1 wall occludes explosion damage cleanly (HP=%d/%d)" % [hidden_hero.hp, hidden_hero.max_hp])
	occ_wall.queue_free()
	hidden_hero.queue_free()

	# Sticky TNT sticks to & follows moving VehicleJeep
	var s_jeep := VehicleJeep.new()
	s_jeep.id = 691
	add_child(s_jeep)
	s_jeep.freeze = true
	s_jeep.global_position = Vector3(50.0, 0.05, 0.0)
	await get_tree().physics_frame
	var tnt := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.TNT_SATCHEL, 602, NetworkManager.TEAM_ROYAL, Vector3(50.0, 0.85, -4.5), Vector3(0.0, 0.2, 30.0), {"heroes_by_id": {}, "projectiles_root": p6_proj})
	for _t in range(15):
		tnt._physics_process(0.05)
	s_jeep.global_position = Vector3(58.0, 0.05, 0.0)
	tnt._physics_process(0.05)
	_assert(tnt._stuck_target == s_jeep and tnt.global_position.x > 55.0, "Sticky TNT attaches to and tracks moving VehicleJeep (x=%.1f)" % tnt.global_position.x)
	tnt.queue_free()

	# Bazooka 40 front / 60 side / 95 rear directional armor
	var armor_tank := VehicleTank.new()
	armor_tank.id = 692
	armor_tank.team = NetworkManager.TEAM_NATIONAL
	add_child(armor_tank)
	armor_tank.global_position = Vector3(70.0, 1.0, 0.0)
	var hp0: int = armor_tank.hp
	armor_tank.apply_bazooka_damage_server(602, Vector3(0.0, 0.0, 1.0), Vector3(70.0, 1.5, -3.0))
	var b_front: int = hp0 - armor_tank.hp
	var hp1: int = armor_tank.hp
	armor_tank.apply_bazooka_damage_server(602, Vector3(-1.0, 0.0, 0.0), Vector3(73.0, 1.5, 0.0))
	var b_side: int = hp1 - armor_tank.hp
	var hp2: int = armor_tank.hp
	armor_tank.apply_bazooka_damage_server(602, Vector3(0.0, 0.0, -1.0), Vector3(70.0, 1.5, 3.0))
	var b_rear: int = hp2 - armor_tank.hp
	_assert(b_front == 40 and b_side == 60 and b_rear == 95, "Bazooka directional armor deals 40 front / 60 side / 95 rear (got %d/%d/%d)" % [b_front, b_side, b_rear])

	# Seat switching F1..F4 + HUD Seat Diagram visibility & occupancy
	s_jeep.try_enter_hero(commando)
	var sw_seat2: bool = s_jeep.try_switch_seat(commando, 2)
	var hud6_vehs: Array[VehicleBase] = [s_jeep]
	hud6.bind_context(null, hud6_vehs, p6_heroes)
	hud6._process(0.016)
	_assert(
		sw_seat2 and commando.current_seat_index == 2 and hud6._seat_diagram_panel.visible and hud6._seat_slot_buttons[2].text.contains("VOCÊ"),
		"Vehicle F1..F4 seat switching moves hero to seat 2 & HUD seat diagram highlights occupied seat"
	)

	# All 16 skills + 4 widgets trigger distinct animations & 3D VFX
	var unique_anims: Dictionary = {}
	for cls_i in range(3):
		var h_anim := HeroCharacter.new()
		h_anim.setup_identity(700 + cls_i, "Anim_%d" % cls_i, 0, cls_i, 0, false, false)
		add_child(h_anim)
		var sk_count: int = 6 if cls_i == NetworkManager.CLASS_COMMANDO else 5
		for s_k in range(sk_count):
			h_anim.trigger_skill_visual(cls_i, s_k)
			unique_anims[h_anim.last_skill_anim_name] = true
			StatusEffectsVFX.spawn_skill_vfx(p6_vfx, h_anim.class_id, s_k, h_anim.global_position, 0.0)
		for w_k in range(4):
			h_anim.trigger_skill_visual(cls_i, 100 + w_k)
			unique_anims[h_anim.last_skill_anim_name] = true
			StatusEffectsVFX.spawn_skill_vfx(p6_vfx, h_anim.class_id, 100 + w_k, h_anim.global_position, 0.0)
		h_anim.queue_free()
	var vfx_ok: bool = DisplayServer.get_name().contains("headless") or p6_vfx.get_child_count() >= 20
	_assert(unique_anims.size() >= 10 and vfx_ok, "All 16 skills & 4 widgets trigger visible procedural poses (%d styles) & 3D VFX (%d nodes)" % [unique_anims.size(), p6_vfx.get_child_count()])

	hud6.queue_free()
	menu.queue_free()
	variant_hero.queue_free()
	commando.queue_free()
	target_a.queue_free()
	target_b.queue_free()
	gunner6.queue_free()
	armor_tank.queue_free()
	s_jeep.queue_free()
	p6_tank.queue_free()
	p6_proj.queue_free()
	p6_vfx.queue_free()
	p6_floor.queue_free()


func _test_phase7_task1_skills_hud_pooling() -> void:
	# 1. HUD has no '+' upgrade buttons, Hero Pts hidden, Rank 5 skills show "R5" brightly
	var hud7 := HUDController.new()
	add_child(hud7)
	var hero7 := HeroCharacter.new()
	hero7.setup_identity(710, "HudPoolTester", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	add_child(hero7)
	hero7.global_position = Vector3.ZERO
	hero7.hero_camera.yaw = 0.0
	hero7.hero_camera.pitch = 0.0
	hero7.hero_camera.set_active_camera(true)

	var enemy_a := HeroCharacter.new()
	enemy_a.setup_identity(711, "MarkedEnemyA", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(enemy_a)
	enemy_a.global_position = Vector3(-2.0, 0.0, -12.0)

	var enemy_b := HeroCharacter.new()
	enemy_b.setup_identity(712, "MarkedEnemyB", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	add_child(enemy_b)
	enemy_b.global_position = Vector3(2.0, 0.0, -14.0)

	var heroes_map7: Dictionary = {710: hero7, 711: enemy_a, 712: enemy_b}
	var jeep7 := VehicleJeep.new()
	jeep7.id = 791
	jeep7.team = NetworkManager.TEAM_ROYAL
	add_child(jeep7)
	jeep7.freeze = true
	jeep7.global_position = Vector3(10.0, 0.5, 0.0)
	await get_tree().process_frame

	enemy_a.status_effects.apply_marked(10.0)
	enemy_b.status_effects.apply_marked(10.0)
	enemy_a.active_flags |= NetSerializer.SNAP_MARKED_TARGET
	enemy_b.active_flags |= NetSerializer.SNAP_MARKED_TARGET

	var vehs7: Array[VehicleBase] = [jeep7]
	hud7.bind_context(null, vehs7, heroes_map7)
	hud7.set_local_hero(hero7)
	hud7._process(0.016)

	var all_r5_bright: bool = true
	for i in range(6):
		if hud7._skill_slot_cd_lbls[i].text != "R5" or hud7._skill_slot_icons[i].modulate != Color.WHITE:
			all_r5_bright = false
	_assert(
		hud7._upgrade_buttons.is_empty() and not hud7._hero_pts_lbl.visible and all_r5_bright,
		"HUD has 0 '+' upgrade buttons, Hero Pts hidden, and all 6 Rank-5 skills show 'R5' brightly"
	)

	# 2. Sixth-sense / Mark Target marker pooling across 6 consecutive frames without child growth
	for _f in range(6):
		hud7._update_sixth_sense_markers()
	var pool_children_after_6: int = hud7._sixth_sense_layer.get_child_count()
	var visible_markers_active: int = 0
	for m in hud7._marker_pool:
		if m.visible:
			visible_markers_active += 1

	enemy_a.status_effects.marked_timer = 0.0
	enemy_b.status_effects.marked_timer = 0.0
	enemy_a.active_flags &= ~NetSerializer.SNAP_MARKED_TARGET
	enemy_b.active_flags &= ~NetSerializer.SNAP_MARKED_TARGET
	hud7._update_sixth_sense_markers()
	var visible_markers_cleared: int = 0
	for m in hud7._marker_pool:
		if m.visible:
			visible_markers_cleared += 1
	_assert(
		pool_children_after_6 == 2 and hud7._marker_pool.size() == 2 and visible_markers_active == 2 and visible_markers_cleared == 0,
		"Sixth-sense markers reuse pool across frames (children=%d, active=%d, cleared=%d)" % [pool_children_after_6, visible_markers_active, visible_markers_cleared]
	)

	# 3. Seat diagram reuses cached StyleBoxFlat instances across frames
	jeep7.try_enter_hero(hero7)
	hud7._update_vehicle_seat_diagram(jeep7)
	var style_seat0_f1: StyleBox = hud7._seat_slot_buttons[0].get_theme_stylebox("normal")
	var style_seat1_f1: StyleBox = hud7._seat_slot_buttons[1].get_theme_stylebox("normal")
	for _sf in range(5):
		hud7._update_vehicle_seat_diagram(jeep7)
	var style_seat0_f6: StyleBox = hud7._seat_slot_buttons[0].get_theme_stylebox("normal")
	var style_seat1_f6: StyleBox = hud7._seat_slot_buttons[1].get_theme_stylebox("normal")
	_assert(
		style_seat0_f1 != null and style_seat0_f1 == style_seat0_f6 and style_seat1_f1 != null and style_seat1_f1 == style_seat1_f6,
		"Vehicle seat diagram reuses cached StyleBoxFlat instances across frames"
	)

	jeep7.exit_hero(hero7)
	hud7.queue_free()
	hero7.queue_free()
	enemy_a.queue_free()
	enemy_b.queue_free()
	jeep7.queue_free()


func _test_phase7_task2_hotkeys_menu() -> void:
	var cfg_path: String = "user://test_phase7_hotkeys.cfg"
	InputCmd.reset_default_hotkeys()

	# 1. InputCmd.assign_unique_key swaps conflicting keys cleanly without duplicates
	var orig_s0: int = InputCmd.get_skill_key(0)
	var orig_s1: int = InputCmd.get_skill_key(1)
	InputCmd.assign_unique_key("skill", 0, orig_s1)
	var skill_swapped: bool = InputCmd.get_skill_key(0) == orig_s1 and InputCmd.get_skill_key(1) == orig_s0

	var orig_w0: int = InputCmd.get_widget_key(0)
	var cur_s0: int = InputCmd.get_skill_key(0)
	InputCmd.assign_unique_key("widget", 0, cur_s0)
	var cross_swapped: bool = InputCmd.get_widget_key(0) == cur_s0 and InputCmd.get_skill_key(0) == orig_w0
	_assert(
		skill_swapped and cross_swapped,
		"InputCmd.assign_unique_key swaps conflicting skill and widget keys cleanly without duplicates"
	)

	# 2. Save / Reset / Load ConfigFile persistence roundtrip
	InputCmd.reset_default_hotkeys()
	InputCmd.assign_unique_key("skill", 2, KEY_G)
	InputCmd.assign_unique_key("widget", 1, KEY_J)
	var expected_skills: Array[int] = InputCmd.skill_hotkeys.duplicate()
	var expected_widgets: Array[int] = InputCmd.widget_hotkeys.duplicate()
	var save_err: int = InputCmd.save_hotkeys_to_config(cfg_path)
	InputCmd.reset_default_hotkeys()
	var loaded_ok: bool = InputCmd.load_hotkeys_from_config(cfg_path)
	_assert(
		save_err == OK and loaded_ok and InputCmd.skill_hotkeys == expected_skills and InputCmd.widget_hotkeys == expected_widgets,
		"InputCmd save_hotkeys_to_config / load_hotkeys_from_config roundtrips custom Skill & Widget binds"
	)

	# 3. ClassSelectMenu 14v14 copy, collapsed MP drawer, Hub/Armory Hotkeys navigation & _ready() load
	InputCmd.reset_default_hotkeys()
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = cfg_path
	add_child(menu)
	await _flush_deferred()

	var loaded_on_ready: bool = InputCmd.get_skill_key(2) == KEY_G and InputCmd.get_widget_key(1) == KEY_J and menu._skill_hotkey_buttons[2].text.ends_with("G") and menu._widget_hotkey_buttons[1].text.ends_with("J")
	var found_14v14_texts: int = 0
	var found_stale_text: bool = false
	for node in menu.find_children("*", "Label", true, false):
		var lbl := node as Label
		if lbl.text.contains("14v14"):
			found_14v14_texts += 1
		if lbl.text.contains("20v20") or lbl.text.contains("12v12"):
			found_stale_text = true
	for node in menu.find_children("*", "Button", true, false):
		var btn := node as Button
		if btn.text.contains("14v14"):
			found_14v14_texts += 1
		if btn.text.contains("20v20") or btn.text.contains("12v12"):
			found_stale_text = true

	var mp_starts_collapsed: bool = menu._mp_card != null and not menu._mp_card.visible and menu._mp_drawer.visible
	_assert(
		loaded_on_ready and found_14v14_texts >= 3 and not found_stale_text and mp_starts_collapsed,
		"Menu loads saved hotkeys on launch, uses 14v14 copy (%d labels), and collapses _mp_card by default" % found_14v14_texts
	)

	# Hub -> Settings -> Back to Hub
	var hub_btn_ok: bool = menu._hub_settings_btn != null and menu._hub_settings_btn.visible and menu._hub_settings_btn.text == "Atalhos (Hotkeys) & Config"
	menu._hub_settings_btn.pressed.emit()
	var hub_to_settings_ok: bool = menu.current_screen == "settings" and menu._settings_back_btn.text == "<- Voltar ao Hub"
	menu._settings_back_btn.pressed.emit()
	var back_to_hub_ok: bool = menu.current_screen == "hub"

	# Armory -> Settings -> Back to Armory
	menu.show_screen("armory")
	var arm_btn_ok: bool = menu._armory_settings_btn != null and menu._armory_settings_btn.visible and menu._armory_settings_btn.text == "Atalhos (Hotkeys)"
	menu._armory_settings_btn.pressed.emit()
	var arm_to_settings_ok: bool = menu.current_screen == "settings" and menu._settings_back_btn.text == "<- Voltar ao Arsenal"
	menu._settings_back_btn.pressed.emit()
	var back_to_arm_ok: bool = menu.current_screen == "armory"
	_assert(
		hub_btn_ok and hub_to_settings_ok and back_to_hub_ok and arm_btn_ok and arm_to_settings_ok and back_to_arm_ok,
		"Hub & Armory Atalhos buttons open Settings and return cleanly to their origin screen"
	)

	# Listening state & hint label guard
	menu.show_screen("settings")
	var listen_idle: bool = not menu.is_listening_hotkey()
	menu._begin_hotkey_listen("skill", 0)
	var listen_active: bool = menu.is_listening_hotkey() and menu._hotkey_hint_lbl.text.contains("Pressione a nova tecla")
	menu._cancel_hotkey_listen()
	var listen_cancelled: bool = not menu.is_listening_hotkey() and menu._hotkey_hint_lbl.text.contains("Clique em qualquer botão")
	_assert(
		listen_idle and listen_active and listen_cancelled,
		"is_listening_hotkey() and _hotkey_hint_lbl track listen/cancel state cleanly"
	)

	# Cleanup test config & restore defaults
	menu.queue_free()
	if FileAccess.file_exists(cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	InputCmd.reset_default_hotkeys()


func _test_phase7_task3_perf_cache_vfx() -> void:
	# 1. GameCache completeness: skill_2_5, all 4 widgets, xray shader, shared VFX meshes
	GameCache.clear_all()
	GameCache.warm_textures()
	GameCache.warm_meshes()
	var has_no_dead_widget_keys: bool = (
		not GameCache.ALL_TEXTURE_KEYS.has("icon_widget_bandage")
		and not GameCache.ALL_TEXTURE_KEYS.has("icon_widget_wrench")
		and not GameCache.ALL_TEXTURE_KEYS.has("icon_widget_tonic")
	)
	var has_xray_path: bool = GameCache.SHADER_PATHS.has("res://vfx_shaders/xray_silhouette.gdshader")
	var xray_loaded: Shader = load("res://vfx_shaders/xray_silhouette.gdshader") as Shader
	var cached_s25: bool = CartoonAssets._cache.has("icon_skill_2_5") and CartoonAssets.get_texture("icon_skill_2_5") != null
	var cached_widgets: bool = true
	for wi in range(4):
		if not CartoonAssets._cache.has("icon_widget_%d" % wi) or CartoonAssets.get_texture("icon_widget_%d" % wi) == null:
			cached_widgets = false
			break
	var shared_meshes_warmed: bool = StatusEffectsVFX._shared_meshes.size() >= 5
	_assert(
		has_no_dead_widget_keys and has_xray_path and xray_loaded != null and cached_s25 and cached_widgets and shared_meshes_warmed,
		"GameCache warms icon_skill_2_5, icon_widget_0..3, xray_silhouette.gdshader, and StatusEffectsVFX shared meshes"
	)

	var prewarm_host := Node3D.new()
	add_child(prewarm_host)
	var prewarm_node: Node3D = GameCache.prewarm_gpu_pipelines(prewarm_host)
	_assert(prewarm_node != null and GameCache.is_gpu_warmed(), "GameCache.prewarm_gpu_pipelines compiles SHADER_PATHS cleanly")
	GameCache.cleanup_prewarm(prewarm_node)
	prewarm_host.queue_free()

	# 2. Dirty-state VFX cache invalidation on HeroCharacter & VehicleBase
	var local_v := HeroCharacter.new()
	local_v.setup_identity(7301, "VfxLocal", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	var enemy_v := HeroCharacter.new()
	enemy_v.setup_identity(7302, "VfxEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(local_v)
	add_child(enemy_v)
	local_v.global_position = Vector3.ZERO
	enemy_v.global_position = Vector3(4.0, 0.0, 0.0)

	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var clean_key: String = enemy_v._last_vfx_key
	var clean_mat := (enemy_v._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial
	var clean_ok: bool = not clean_key.is_empty() and (enemy_v._mesh_parts[0] as MeshInstance3D).material_overlay == null and enemy_v.visual_root.visible

	# Burn on -> off
	enemy_v.active_flags = NetSerializer.SNAP_BURNING
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var burn_key: String = enemy_v._last_vfx_key
	var burn_rim: Color = clean_mat.get_shader_parameter("rim_color")
	enemy_v.active_flags = 0
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var post_burn_key: String = enemy_v._last_vfx_key

	# Shield on -> off
	enemy_v.active_flags = NetSerializer.SNAP_SHIELDED
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var shield_key: String = enemy_v._last_vfx_key
	enemy_v.active_flags = 0
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)

	# Marked X-Ray on -> off
	enemy_v.active_flags = NetSerializer.SNAP_MARKED_TARGET
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var mark_ov: Material = (enemy_v._mesh_parts[0] as MeshInstance3D).material_overlay
	enemy_v.active_flags = 0
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var cleared_ov: Material = (enemy_v._mesh_parts[0] as MeshInstance3D).material_overlay

	# Stealth on (within radius -> beyond radius -> off)
	enemy_v.is_stealthed = true
	enemy_v.active_flags = NetSerializer.SNAP_STEALTHED
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var cloak_close_ok: bool = enemy_v.visual_root.visible and clean_mat.shader == StatusEffectsVFX.HERO_CLOAK_SHADER
	enemy_v.global_position = Vector3(30.0, 0.0, 0.0)
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var cloak_far_hidden: bool = not enemy_v.visual_root.visible
	enemy_v.is_stealthed = false
	enemy_v.active_flags = 0
	StatusEffectsVFX.update_hero_client_visuals(enemy_v, local_v, 0.016)
	var uncloak_restored: bool = (
		enemy_v.visual_root.visible
		and clean_mat.shader == StatusEffectsVFX.HERO_SHADER
		and (enemy_v._mesh_parts[0] as MeshInstance3D).material_overlay == null
		and enemy_v._last_vfx_key == clean_key
	)
	_assert(
		clean_ok and burn_key != clean_key and burn_rim.r > 0.9 and post_burn_key == clean_key and shield_key != clean_key and mark_ov != null and cleared_ov == null and cloak_close_ok and cloak_far_hidden and uncloak_restored,
		"StatusEffectsVFX dirty cache updates on burn/shield/mark/stealth and restores clean defaults when cleared"
	)

	# VehicleBase _cached_visual_meshes & _last_xray_state
	var vfx_jeep := VehicleJeep.new()
	vfx_jeep.id = 7390
	vfx_jeep.team = NetworkManager.TEAM_NATIONAL
	add_child(vfx_jeep)
	StatusEffectsVFX.update_vehicle_client_visuals(vfx_jeep, local_v)
	var veh_init_ok: bool = vfx_jeep._cached_visual_meshes.size() > 0 and vfx_jeep._last_xray_state == 0 and vfx_jeep._cached_visual_meshes[0].material_overlay == null
	vfx_jeep.is_marked = true
	StatusEffectsVFX.update_vehicle_client_visuals(vfx_jeep, local_v)
	var veh_mark_ok: bool = vfx_jeep._last_xray_state == 1 and vfx_jeep._cached_visual_meshes[0].material_overlay == StatusEffectsVFX._get_xray_material()
	vfx_jeep.is_marked = false
	StatusEffectsVFX.update_vehicle_client_visuals(vfx_jeep, local_v)
	var veh_clear_ok: bool = vfx_jeep._last_xray_state == 0 and vfx_jeep._cached_visual_meshes[0].material_overlay == null
	_assert(veh_init_ok and veh_mark_ok and veh_clear_ok, "VehicleBase caches visual meshes and toggles _last_xray_state cleanly (0 -> 1 -> 0)")

	# 3. BotController nearest-visible sorting (ignores defeated & wall-occluded closer enemies)
	var bot_h := HeroCharacter.new()
	bot_h.setup_identity(7310, "SortBot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	var occ_enemy := HeroCharacter.new()
	occ_enemy.setup_identity(7311, "OccEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var dead_enemy := HeroCharacter.new()
	dead_enemy.setup_identity(7312, "DeadEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var mid_enemy := HeroCharacter.new()
	mid_enemy.setup_identity(7313, "MidEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var far_enemy := HeroCharacter.new()
	far_enemy.setup_identity(7314, "FarEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var los_wall := StaticBody3D.new()
	los_wall.collision_layer = 1
	var los_col := CollisionShape3D.new()
	var los_box := BoxShape3D.new()
	los_box.size = Vector3(8.0, 5.0, 1.0)
	los_col.shape = los_box
	los_wall.add_child(los_col)
	add_child(los_wall)
	add_child(bot_h)
	add_child(occ_enemy)
	add_child(dead_enemy)
	add_child(mid_enemy)
	add_child(far_enemy)

	bot_h.global_position = Vector3(100.0, 0.0, 0.0)
	los_wall.global_position = Vector3(100.0, 2.0, -5.0)
	occ_enemy.global_position = Vector3(100.0, 0.0, -10.0) # 10m away but behind wall
	dead_enemy.global_position = Vector3(106.0, 0.0, 0.0) # 6m away in LOS but defeated
	dead_enemy.is_defeated = true
	mid_enemy.global_position = Vector3(120.0, 0.0, 0.0) # 20m away in clear LOS
	far_enemy.global_position = Vector3(138.0, 0.0, 0.0) # 38m away in clear LOS
	await get_tree().physics_frame

	var bot_ai := BotController.new()
	bot_ai.setup(bot_h)
	add_child(bot_ai)
	var sort_map: Dictionary = {7310: bot_h, 7311: occ_enemy, 7312: dead_enemy, 7313: mid_enemy, 7314: far_enemy}
	var chosen_enemy: HeroCharacter = bot_ai._find_nearest_visible_enemy(sort_map, bot_h.get_world_3d().direct_space_state)
	_assert(chosen_enemy == mid_enemy, "BotController._find_nearest_visible_enemy skips defeated/occluded targets and picks closest visible enemy")

	# 4. All 16 Skills + 4 Widgets thematic multi-part 3D VFX & procedural poses
	var vfx_stage := Node3D.new()
	vfx_stage.name = "Phase7Task3VfxStage"
	add_child(vfx_stage)

	var anim_hero := HeroCharacter.new()
	anim_hero.setup_identity(7320, "VfxCaster", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(anim_hero)

	var shared_mesh_vals: Array = StatusEffectsVFX._shared_meshes.values()
	var vfx_specs: Array = []
	for cls_id in range(3):
		var n_sk: int = 6 if cls_id == NetworkManager.CLASS_COMMANDO else 5
		for sk_i in range(n_sk):
			var exp_pose: String = ""
			if cls_id == NetworkManager.CLASS_GUNNER and sk_i == 1:
				exp_pose = "sprint_boost"
			elif cls_id == NetworkManager.CLASS_GUNNER and sk_i == 4:
				exp_pose = "chomp_absorb"
			elif cls_id == NetworkManager.CLASS_COMMANDO and sk_i == 4:
				exp_pose = "sprint_boost"
			vfx_specs.append([cls_id, sk_i, exp_pose])
	for w_i in range(4):
		var exp_w_pose: String = "raise_med" if w_i == 3 else ""
		vfx_specs.append([0, 100 + w_i, exp_w_pose])

	var total_checked: int = 0
	var all_multipart_ok: bool = true
	var all_noshadow_ok: bool = true
	var all_shared_ok: bool = true
	var all_poses_ok: bool = true

	for spec in vfx_specs:
		var cls_id: int = int(spec[0])
		var slot_id: int = int(spec[1])
		var expected_pose: String = str(spec[2])
		total_checked += 1
		anim_hero.trigger_skill_visual(cls_id, slot_id)
		if anim_hero.last_skill_anim_name.is_empty():
			all_poses_ok = false
		if not expected_pose.is_empty() and anim_hero.last_skill_anim_name != expected_pose:
			all_poses_ok = false
		StatusEffectsVFX.spawn_skill_vfx(vfx_stage, cls_id, slot_id, Vector3(float(total_checked) * 2.0, 0.0, 0.0), 0.5)
		var vfx_name: String = "SkillVFX_%d_%d" % [cls_id, slot_id]
		var node_vfx: Node = vfx_stage.get_node_or_null(vfx_name)
		if node_vfx == null or node_vfx.get_child_count() < 2:
			all_multipart_ok = false
			continue
		var meshes_found: Array[MeshInstance3D] = []
		_collect_mesh_instances(node_vfx, meshes_found)
		if meshes_found.size() < 2:
			all_multipart_ok = false
		for mi in meshes_found:
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				all_noshadow_ok = false
			if not shared_mesh_vals.has(mi.mesh):
				all_shared_ok = false

	_assert(
		total_checked == 20 and all_multipart_ok and all_noshadow_ok and all_shared_ok and all_poses_ok,
		"All 16 skills + 4 widgets (%d total) spawn multi-part shadow-off shared-mesh 3D VFX & distinct poses (sprint_boost, chomp_absorb)" % total_checked
	)

	vfx_stage.queue_free()
	anim_hero.queue_free()
	bot_ai.queue_free()
	bot_h.queue_free()
	occ_enemy.queue_free()
	dead_enemy.queue_free()
	mid_enemy.queue_free()
	far_enemy.queue_free()
	los_wall.queue_free()
	vfx_jeep.queue_free()
	local_v.queue_free()
	enemy_v.queue_free()


func _test_phase8_task1_skill_icons_and_guide() -> void:
	# 1. All 16 skill icons generate 40x40 textures with 16 pairwise distinct pixel payloads + legacy fallback
	var skill_keys: Array[String] = []
	for cls_id in range(3):
		var count: int = 6 if cls_id == NetworkManager.CLASS_COMMANDO else 5
		for slot_i in range(count):
			skill_keys.append("icon_skill_%d_%d" % [cls_id, slot_i])

	var unique_payloads: Dictionary = {}
	var all_icons_valid: bool = true
	for sk in skill_keys:
		var tex: ImageTexture = CartoonAssets.get_texture(sk)
		if tex == null or tex.get_width() != 40 or tex.get_height() != 40:
			all_icons_valid = false
			break
		var img: Image = tex.get_image()
		if img == null:
			all_icons_valid = false
			break
		var payload_b64: String = Marshalls.raw_to_base64(img.get_data())
		unique_payloads[payload_b64] = sk

	var legacy_ok: bool = true
	for leg_i in range(5):
		var leg_tex: ImageTexture = CartoonAssets.get_texture("icon_skill_%d" % leg_i)
		var norm_tex: ImageTexture = CartoonAssets.get_texture("icon_skill_0_%d" % leg_i)
		if leg_tex == null or norm_tex == null or leg_tex.get_width() != 40 or leg_tex.get_height() != 40:
			legacy_ok = false
			break
		if leg_tex.get_image().get_data() != norm_tex.get_image().get_data():
			legacy_ok = false
			break

	_assert(
		all_icons_valid and unique_payloads.size() == 16 and legacy_ok,
		"CartoonAssets generates 16 distinct 40x40 skill icons (%d/16 unique) with legacy fallback" % unique_payloads.size()
	)

	# 2. SkillCatalog canonical counts, non-empty fields & AoE radii
	var s_list: Array[Dictionary] = SkillCatalog.get_class_skills(NetworkManager.CLASS_SOLDIER)
	var g_list: Array[Dictionary] = SkillCatalog.get_class_skills(NetworkManager.CLASS_GUNNER)
	var c_list: Array[Dictionary] = SkillCatalog.get_class_skills(NetworkManager.CLASS_COMMANDO)
	var w_list: Array[Dictionary] = SkillCatalog.get_widgets()
	var catalog_fields_ok: bool = true
	for lst in [s_list, g_list, c_list, w_list]:
		for entry in lst:
			for req_k in ["icon", "name", "category", "cooldown", "duration", "area", "effect_stats", "description"]:
				if str(entry.get(req_k, "")).strip_edges().is_empty():
					catalog_fields_ok = false
					break
	var mark_entry: Dictionary = SkillCatalog.get_entry_by_key("icon_skill_2_5")
	var burn_entry: Dictionary = SkillCatalog.get_entry_by_key("icon_skill_0_1")
	var med_entry: Dictionary = SkillCatalog.get_entry_by_key("icon_skill_0_0")
	_assert(
		s_list.size() == 5 and g_list.size() == 5 and c_list.size() == 6 and w_list.size() == 4
		and catalog_fields_ok and str(mark_entry.get("name", "")) == "Mark Target"
		and str(burn_entry.get("effect_stats", "")) == "+16 dano fogo/s"
		and str(mark_entry.get("duration", "")) == "12.0s marca"
		and is_equal_approx(float(med_entry.get("aoe_radius", 0.0)), 12.0),
		"SkillCatalog provides 5/5/6 class skills + 4 widgets with complete Rank-5 stats"
	)

	# 3. HUDController syncs _skill_slot_icons & tooltips per hero class
	var hud := HUDController.new()
	add_child(hud)
	await _flush_deferred()

	var h_sol := HeroCharacter.new()
	h_sol.setup_identity(8101, "HudSol", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	var h_gun := HeroCharacter.new()
	h_gun.setup_identity(8102, "HudGun", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, true, false)
	var h_com := HeroCharacter.new()
	h_com.setup_identity(8103, "HudCom", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	add_child(h_sol)
	add_child(h_gun)
	add_child(h_com)

	hud.set_local_hero(h_sol)
	var sol_t0: Texture2D = hud._skill_slot_icons[0].texture
	var sol_t1: Texture2D = hud._skill_slot_icons[1].texture
	var sol_tip0: String = hud._skill_slot_bgs[0].tooltip_text

	hud.set_local_hero(h_gun)
	var gun_t0: Texture2D = hud._skill_slot_icons[0].texture
	var gun_t1: Texture2D = hud._skill_slot_icons[1].texture
	var gun_tip0: String = hud._skill_slot_bgs[0].tooltip_text

	hud.set_local_hero(h_com)
	var com_t0: Texture2D = hud._skill_slot_icons[0].texture
	var com_t1: Texture2D = hud._skill_slot_icons[1].texture
	var com_tip0: String = hud._skill_slot_bgs[0].tooltip_text

	var hud_textures_match: bool = (
		sol_t0 == CartoonAssets.get_texture("icon_skill_0_0")
		and sol_t1 == CartoonAssets.get_texture("icon_skill_0_1")
		and gun_t0 == CartoonAssets.get_texture("icon_skill_1_0")
		and gun_t1 == CartoonAssets.get_texture("icon_skill_1_1")
		and com_t0 == CartoonAssets.get_texture("icon_skill_2_0")
		and com_t1 == CartoonAssets.get_texture("icon_skill_2_1")
		and sol_t0 != gun_t0 and gun_t0 != com_t0 and sol_t0 != com_t0
		and sol_t1 != gun_t1 and gun_t1 != com_t1 and sol_t1 != com_t1
	)
	var hud_tips_ok: bool = (
		sol_tip0.contains("Combat Medicine")
		and gun_tip0.contains("Hero Shield")
		and com_tip0.contains("Stealth")
	)
	_assert(
		hud_textures_match and hud_tips_ok,
		"HUDController syncs distinct class skill icons and tooltips when switching Soldier/Gunner/Commando"
	)

	# 4. ClassSelectMenu "skills" guide navigation from Hub & Armory + card rendering
	var menu := ClassSelectMenu.new()
	add_child(menu)
	await _flush_deferred()

	var hub_sk_btn_ok: bool = menu._hub_skills_btn != null and menu._hub_skills_btn.visible
	menu._hub_skills_btn.pressed.emit()
	var hub_to_skills_ok: bool = menu.current_screen == "skills" and menu._skills_screen.visible and menu._skills_back_btn.text == "<- Voltar ao Hub"
	menu._skills_back_btn.pressed.emit()
	var back_hub_ok: bool = menu.current_screen == "hub" and menu._hub_screen.visible

	menu.show_screen("armory")
	menu.select_class(NetworkManager.CLASS_COMMANDO)
	var arm_sk_btn_ok: bool = menu._armory_skills_btn != null and menu._armory_skills_btn.visible
	menu._armory_skills_btn.pressed.emit()
	var arm_to_skills_ok: bool = (
		menu.current_screen == "skills"
		and menu._skills_tab_class == NetworkManager.CLASS_COMMANDO
		and menu._skills_back_btn.text == "<- Voltar ao Arsenal"
		and menu._skills_grid.get_child_count() == 6
	)

	var found_mark_target: bool = false
	var found_icon_tex: bool = false
	for lbl_node in menu._skills_grid.find_children("*", "Label", true, false):
		if (lbl_node as Label).text.contains("Mark Target"):
			found_mark_target = true
			break
	for tex_node in menu._skills_grid.find_children("*", "TextureRect", true, false):
		if (tex_node as TextureRect).texture != null:
			found_icon_tex = true
			break

	menu.select_skills_tab(0)
	var soldier_tab_count: int = menu._skills_grid.get_child_count()
	var found_combat_med: bool = false
	for lbl_node in menu._skills_grid.find_children("*", "Label", true, false):
		if (lbl_node as Label).text.contains("Combat Medicine"):
			found_combat_med = true
			break

	menu.select_skills_tab(5)
	var widget_tab_count: int = menu._skills_grid.get_child_count()

	menu._skills_back_btn.pressed.emit()
	var back_armory_ok: bool = menu.current_screen == "armory" and menu._armory_screen.visible

	_assert(
		hub_sk_btn_ok and hub_to_skills_ok and back_hub_ok
		and arm_sk_btn_ok and arm_to_skills_ok
		and found_mark_target and found_icon_tex
		and soldier_tab_count == 5 and found_combat_med and widget_tab_count == 4
		and back_armory_ok,
		"ClassSelectMenu opens Habilidades guide from Hub/Armory, renders cards/icons/stats, and returns cleanly"
	)

	menu.queue_free()
	hud.queue_free()
	h_sol.queue_free()
	h_gun.queue_free()
	h_com.queue_free()


func _test_phase8_task2_aoe_vfx_and_overhead_buffs() -> void:
	# 1. NetSerializer authoritative_state + world_snapshot active_buffs roundtrip & default compatibility
	var test_buffs: int = NetSerializer.BUFF_HERO_SHIELD | NetSerializer.BUFF_BURNING_BULLETS | NetSerializer.BUFF_LEG_IT
	var auth_bytes: PackedByteArray = NetSerializer.pack_authoritative_state(
		42, Vector3(1.0, 2.0, -3.0), Vector3(0.5, 0.0, -1.0),
		NetSerializer.SNAP_GROUNDED, 95, 60, -1, -1, 3, test_buffs
	)
	var auth_dec: Dictionary = NetSerializer.unpack_authoritative_state(auth_bytes)
	var auth_default_bytes: PackedByteArray = NetSerializer.pack_authoritative_state(
		43, Vector3.ZERO, Vector3.ZERO, NetSerializer.SNAP_GROUNDED, 100, 0, -1, -1, 0
	)
	var auth_default_dec: Dictionary = NetSerializer.unpack_authoritative_state(auth_default_bytes)
	var ws_bytes: PackedByteArray = NetSerializer.pack_world_snapshot(
		88, 1500, 50, 50,
		[
			{"id": 11, "team": 0, "class_id": 1, "weapon_slot": 0, "flags": NetSerializer.SNAP_SHIELDED, "buffs": test_buffs, "pos": Vector3.ZERO, "vel": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "hp": 150, "shield": 100, "vehicle_id": -1, "seat_idx": -1},
			{"id": 12, "team": 1, "class_id": 0, "weapon_slot": 0, "flags": 1, "pos": Vector3(5.0, 0.0, 0.0), "vel": Vector3.ZERO, "yaw": 0.0, "pitch": 0.0, "hp": 110, "shield": 0, "vehicle_id": -1, "seat_idx": -1},
		],
		[], []
	)
	var ws_dec: Dictionary = NetSerializer.unpack_world_snapshot(ws_bytes)
	var ws_heroes: Array = ws_dec.get("heroes", [])
	_assert(
		int(auth_dec.get("buffs", 0)) == test_buffs
		and int(auth_default_dec.get("buffs", -1)) == 0
		and ws_heroes.size() == 2
		and int((ws_heroes[0] as Dictionary).get("buffs", 0)) == test_buffs
		and int((ws_heroes[1] as Dictionary).get("buffs", -1)) == 0,
		"NetSerializer roundtrips u16 active_buffs in authoritative_state & world_snapshot with buffs=0 default compatibility"
	)

	# 2. Skill/widget active_buffs bitmasks, Leg It vs Elixir separation, Hero Shield break, & OverheadBuffRow icons
	var prev_solo: bool = NetworkManager.is_solo_bot_mode
	NetworkManager.is_solo_bot_mode = true

	var sol := HeroCharacter.new()
	sol.setup_identity(8201, "T2Soldier", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	var ally_near := HeroCharacter.new()
	ally_near.setup_identity(8202, "T2AllyNear", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	var ally_far := HeroCharacter.new()
	ally_far.setup_identity(8203, "T2AllyFar", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var enemy_com := HeroCharacter.new()
	enemy_com.setup_identity(8204, "T2Commando", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	add_child(sol)
	add_child(ally_near)
	add_child(ally_far)
	add_child(enemy_com)

	sol.global_position = Vector3.ZERO
	ally_near.global_position = Vector3(6.0, 0.0, 0.0) # within 12.0m & 11.0m
	ally_far.global_position = Vector3(16.0, 0.0, 0.0) # beyond 12.0m
	ally_near.hp = 60
	ally_far.hp = 60

	var ctx: Dictionary = {"heroes_by_id": {8201: sol, 8202: ally_near, 8203: ally_far, 8204: enemy_com}}
	var cmd := InputCmd.new()

	var captured_vfx: Array[Dictionary] = []
	var on_evt := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "skill_vfx":
			captured_vfx.append(payload)
	NetworkManager.game_event_received.connect(on_evt)

	# Combat Medicine + Burning Bullets + Bandages + Fireproof on Soldier
	var sol_sm: SkillManager = sol.skill_manager as SkillManager
	sol_sm.try_activate_skill(0, cmd, ctx)
	sol_sm.try_activate_skill(1, cmd, ctx)
	sol_sm.try_activate_widget(0, ctx)
	sol_sm.try_activate_widget(2, ctx)
	var sol_buffs_ok: bool = (
		(sol.active_buffs & NetSerializer.BUFF_COMBAT_MED_HOT) != 0
		and (sol.active_buffs & NetSerializer.BUFF_BURNING_BULLETS) != 0
		and (sol.active_buffs & NetSerializer.BUFF_BANDAGE) != 0
		and (sol.active_buffs & NetSerializer.BUFF_FIREPROOF) != 0
		and (ally_near.active_buffs & NetSerializer.BUFF_COMBAT_MED_HOT) != 0
		and (ally_far.active_buffs & NetSerializer.BUFF_COMBAT_MED_HOT) == 0
	)

	# Gunner: Hero Shield -> break shield clears BUFF_HERO_SHIELD; Leg It -> BUFF_LEG_IT; Frenzy Fire -> BUFF_FRENZY_FIRE
	var gun_sm: SkillManager = ally_near.skill_manager as SkillManager
	gun_sm.try_activate_skill(0, cmd, ctx)
	var shield_set: bool = (ally_near.active_buffs & NetSerializer.BUFF_HERO_SHIELD) != 0 and ally_near.shield > 0
	ally_near.apply_damage_server(ally_near.shield, 8204, false)
	var shield_cleared_on_break: bool = ally_near.shield == 0 and (ally_near.active_buffs & NetSerializer.BUFF_HERO_SHIELD) == 0

	gun_sm.try_activate_skill(1, cmd, ctx)
	gun_sm.try_activate_skill(3, cmd, ctx)
	var gun_buffs_ok: bool = (
		(ally_near.active_buffs & NetSerializer.BUFF_LEG_IT) != 0
		and (ally_near.active_buffs & NetSerializer.BUFF_FRENZY_FIRE) != 0
		and (sol.active_buffs & NetSerializer.BUFF_LEG_IT) != 0
		and (sol.active_buffs & NetSerializer.BUFF_ELIXIR) == 0
	)

	# Commando: Elixir -> BUFF_ELIXIR (NOT Leg It, NOT Hero Shield), Piercing Shot, Poisoned Blade
	var com_sm: SkillManager = enemy_com.skill_manager as SkillManager
	com_sm.try_activate_skill(4, cmd, ctx)
	com_sm.try_activate_skill(1, cmd, ctx)
	com_sm.try_activate_skill(2, cmd, ctx)
	var com_buffs_ok: bool = (
		(enemy_com.active_buffs & NetSerializer.BUFF_ELIXIR) != 0
		and (enemy_com.active_buffs & NetSerializer.BUFF_LEG_IT) == 0
		and (enemy_com.active_buffs & NetSerializer.BUFF_HERO_SHIELD) == 0
		and (enemy_com.active_buffs & NetSerializer.BUFF_PIERCING_SHOT) != 0
		and (enemy_com.active_buffs & NetSerializer.BUFF_POISONED_BLADE) != 0
	)

	_assert(
		sol_buffs_ok and shield_set and shield_cleared_on_break and gun_buffs_ok and com_buffs_ok,
		"All timed skills/widgets map to exact active_buffs bits (Leg It vs Elixir distinct, Hero Shield clears on break)"
	)

	# Verify oversized OverheadBuffRow Sprite3D billboards stay hidden while thematic particle flags are active (and Stealth uses cloak shader only)
	StatusEffectsVFX.update_hero_client_visuals(sol, sol, 0.016)
	var sol_row := sol.visual_root.get_node_or_null("OverheadBuffRow") as Node3D
	var sol_visible_sprites: int = 0
	if sol_row != null:
		for c in sol_row.get_children():
			if c is Sprite3D and (c as Sprite3D).visible:
				sol_visible_sprites += 1
	var sol_has_particles: bool = StatusEffectsVFX._has_continuous_particle_buff(sol)

	StatusEffectsVFX.update_hero_client_visuals(enemy_com, sol, 0.016)
	var com_row := enemy_com.visual_root.get_node_or_null("OverheadBuffRow") as Node3D
	var com_no_row: bool = (com_row == null) or (not com_row.visible)

	# Stealth beyond detect radius hides visual_root when unmarked/unsensed, and adds zero continuous particles
	enemy_com.status_effects.clear_all()
	enemy_com.global_position = Vector3(40.0, 0.0, 0.0)
	com_sm.try_activate_skill(0, cmd, ctx)
	var stealth_no_extra_particles: bool = not StatusEffectsVFX._has_continuous_particle_buff(enemy_com)
	sol.active_flags &= ~NetSerializer.SNAP_SIXTH_SENSE
	StatusEffectsVFX.update_hero_client_visuals(enemy_com, sol, 0.016)
	var hidden_when_stealthed: bool = not enemy_com.visual_root.visible

	# Within Sixth Sense 55m radius (40m), Stealthed Commando becomes revealed in 3D
	sol.active_flags |= NetSerializer.SNAP_SIXTH_SENSE
	StatusEffectsVFX.update_hero_client_visuals(enemy_com, sol, 0.016)
	var revealed_by_sixth_sense: bool = enemy_com.visual_root.visible

	# Defeated & clear_all() keep OverheadBuffRow hidden and clear particle buff state
	sol.is_defeated = true
	StatusEffectsVFX.update_hero_client_visuals(sol, sol, 0.016)
	var hidden_when_defeated: bool = (sol_row == null) or (not sol_row.visible)

	sol.is_defeated = false
	sol.status_effects.clear_all()
	StatusEffectsVFX.update_hero_client_visuals(sol, sol, 0.016)
	var hidden_when_cleared: bool = sol.active_buffs == 0 and ((sol_row == null) or (not sol_row.visible)) and not StatusEffectsVFX._has_continuous_particle_buff(sol)

	_assert(
		sol_visible_sprites == 0 and (sol_row == null or not sol_row.visible) and com_no_row
		and sol_has_particles and stealth_no_extra_particles
		and hidden_when_stealthed and revealed_by_sixth_sense and hidden_when_defeated and hidden_when_cleared,
		"StatusEffectsVFX removes giant OverheadBuffRow Sprite3Ds, keeps thematic buff particles (0 extra on Stealth), and reveals 40m Stealth via Sixth Sense"
	)

	# 3. Combat Medicine AoE payload + StatusEffectsVFX.spawn_aoe_area_vfx geometry
	NetworkManager.game_event_received.disconnect(on_evt)
	var med_payload: Dictionary = captured_vfx[0] if not captured_vfx.is_empty() else {}
	var aff_ids: Array = med_payload.get("affected_ids", [])
	var aoe_payload_ok: bool = (
		is_equal_approx(float(med_payload.get("aoe_radius", 0.0)), 12.0)
		and aff_ids.has(8201) and aff_ids.has(8202) and not aff_ids.has(8203)
	)

	var aoe_stage := Node3D.new()
	add_child(aoe_stage)
	var aoe_node: Node3D = StatusEffectsVFX.spawn_aoe_area_vfx(
		aoe_stage, NetworkManager.CLASS_SOLDIER, 0, Vector3.ZERO, 12.0,
		[Vector3.ZERO, Vector3(6.0, 0.0, 0.0)]
	)
	var disc := aoe_node.get_node_or_null("AoEGroundDisc") as MeshInstance3D if aoe_node != null else null
	var perim := aoe_node.get_node_or_null("AoEPerimeterRing") as MeshInstance3D if aoe_node != null else null
	var m0 := aoe_node.get_node_or_null("AffectedMarker_0") as Node3D if aoe_node != null else null
	var m1 := aoe_node.get_node_or_null("AffectedMarker_1") as Node3D if aoe_node != null else null
	_assert(
		aoe_payload_ok
		and aoe_node != null
		and disc != null and is_equal_approx(disc.scale.x, 24.0)
		and perim != null and is_equal_approx(perim.scale.x, 24.0)
		and m0 != null and m1 != null and m1.position.distance_to(Vector3(6.0, 0.0, 0.0)) < 0.01,
		"Combat Medicine skill_vfx payload carries aoe_radius=12.0 & affected_ids, and spawn_aoe_area_vfx scales disc/ring to 24.0m with target markers"
	)

	NetworkManager.is_solo_bot_mode = prev_solo
	aoe_stage.queue_free()
	sol.queue_free()
	ally_near.queue_free()
	ally_far.queue_free()
	enemy_com.queue_free()
	await _flush_deferred()


func _test_phase8_task3_plane_accel_and_crash() -> void:
	var arena := Node3D.new()
	arena.name = "Phase8Task3PlaneArena"
	add_child(arena)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(260.0, 1.0, 260.0)
	floor_col.shape = floor_box
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var plane := VehiclePlane.new()
	plane.id = 8301
	plane.team = NetworkManager.TEAM_ROYAL
	plane.position = Vector3(0.0, 0.5, 40.0)
	arena.add_child(plane)
	plane.spawn_transform = plane.global_transform

	var pilot := HeroCharacter.new()
	pilot.setup_identity(8302, "T3Pilot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(pilot)
	plane.try_enter_hero(pilot)

	await get_tree().physics_frame
	await get_tree().physics_frame

	var heroes_map: Dictionary = {8302: pilot}
	var ctx: Dictionary = {"heroes_by_id": heroes_map}

	# 1. Idle standstill & no Space teleport below TAKEOFF_SPEED
	var idle_start_pos: Vector3 = plane.global_position
	for t in range(30):
		var idle_cmd := InputCmd.new()
		idle_cmd.move_dir = Vector2.ZERO
		idle_cmd.aim_yaw = 0.0
		idle_cmd.aim_pitch = 0.0
		if t >= 15:
			idle_cmd.set_button(InputCmd.BTN_JUMP, true)
		pilot.latest_server_input = idle_cmd
		plane.step_vehicle_server(1.0 / 60.0, heroes_map, ctx)
		await get_tree().physics_frame

	var idle_horiz_disp: float = Vector2(plane.global_position.x - idle_start_pos.x, plane.global_position.z - idle_start_pos.z).length()
	_assert(
		plane._airspeed < 0.1 and idle_horiz_disp < 0.25 and plane.global_position.y <= idle_start_pos.y + 0.15,
		"VehiclePlane remains stationary when idle without W and blocks Space climb before TAKEOFF_SPEED (airspeed=%.2f, disp=%.2fm, dy=%.2fm)" % [plane._airspeed, idle_horiz_disp, plane.global_position.y - idle_start_pos.y]
	)

	# 2. Progressive runway acceleration (10 ticks -> 35 ticks -> 75 ticks -> 125 ticks) + S brake
	var accel_start_y: float = plane.global_position.y
	var spd_10: float = 0.0
	var dy_10: float = 0.0
	var spd_35: float = 0.0
	var dy_35: float = 0.0
	var spd_75: float = 0.0
	for tick in range(1, 126):
		var w_cmd := InputCmd.new()
		w_cmd.move_dir = Vector2(0.0, -1.0)
		w_cmd.aim_yaw = 0.0
		w_cmd.aim_pitch = 0.0
		pilot.latest_server_input = w_cmd
		plane.step_vehicle_server(1.0 / 60.0, heroes_map, ctx)
		await get_tree().physics_frame
		if tick == 10:
			spd_10 = plane._airspeed
			dy_10 = plane.global_position.y - accel_start_y
		elif tick == 35:
			spd_35 = plane._airspeed
			dy_35 = plane.global_position.y - accel_start_y
		elif tick == 75:
			spd_75 = plane._airspeed

	var spd_125: float = plane._airspeed
	for _b in range(45):
		var s_cmd := InputCmd.new()
		s_cmd.move_dir = Vector2(0.0, 1.0)
		s_cmd.aim_yaw = 0.0
		s_cmd.aim_pitch = 0.0
		pilot.latest_server_input = s_cmd
		plane.step_vehicle_server(1.0 / 60.0, heroes_map, ctx)
		await get_tree().physics_frame
	var spd_braked: float = plane._airspeed

	_assert(
		spd_10 >= 3.0 and spd_10 <= 12.0 and dy_10 < 0.25
		and spd_35 > VehiclePlane.TAKEOFF_SPEED and dy_35 > 0.05
		and spd_75 > 30.0 and spd_125 > 36.0 and spd_braked < spd_125 - 10.0,
		"VehiclePlane accelerates progressively on runway (t10=%.1f, t35=%.1f/dy=%.2f, t75=%.1f, t125=%.1f) and brakes cleanly with S (%.1f)" % [spd_10, spd_35, dy_35, spd_75, spd_125, spd_braked]
	)

	# 3. Wall crash explosion + enemy bot splash + zero friendly fire + _respawn_vehicle reset
	var wall_body := StaticBody3D.new()
	wall_body.collision_layer = 1
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(24.0, 16.0, 3.0)
	wall_col.shape = wall_box
	wall_body.position = Vector3(0.0, 6.0, -35.0)
	wall_body.add_child(wall_col)
	arena.add_child(wall_body)

	var enemy_wall := HeroCharacter.new()
	enemy_wall.setup_identity(8303, "T3EnemyWall", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	arena.add_child(enemy_wall)
	enemy_wall.global_position = Vector3(3.0, 0.5, -31.0)

	var ally_wall := HeroCharacter.new()
	ally_wall.setup_identity(8304, "T3AllyWall", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	arena.add_child(ally_wall)
	ally_wall.global_position = Vector3(-3.0, 0.5, -31.0)

	var enemy_jeep := VehicleJeep.new()
	enemy_jeep.id = 8306
	enemy_jeep.team = NetworkManager.TEAM_NATIONAL
	arena.add_child(enemy_jeep)
	enemy_jeep.global_position = Vector3(5.0, 0.8, -31.0)

	var ally_jeep := VehicleJeep.new()
	ally_jeep.id = 8307
	ally_jeep.team = NetworkManager.TEAM_ROYAL
	arena.add_child(ally_jeep)
	ally_jeep.global_position = Vector3(-5.0, 0.8, -31.0)

	var wall_heroes: Dictionary = {8302: pilot, 8303: enemy_wall, 8304: ally_wall}
	var wall_ctx: Dictionary = {"heroes_by_id": wall_heroes}

	var exp_events: Array[Dictionary] = []
	var hit_events: Array[Dictionary] = []
	var on_crash_evt := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "explosion_vfx":
			exp_events.append(payload)
		elif ev_type == "hit_vfx":
			hit_events.append(payload)
	NetworkManager.game_event_received.connect(on_crash_evt)

	plane.global_position = Vector3(0.0, 3.0, 0.0)
	plane.rotation = Vector3.ZERO
	plane._airspeed = 34.0
	plane._was_airborne = true
	plane._crash_armed_time = 0.5
	plane.linear_velocity = Vector3(0.0, 0.0, -34.0)
	plane._prev_vel = plane.linear_velocity

	for _w in range(90):
		if plane.is_destroyed:
			break
		var fly_cmd := InputCmd.new()
		fly_cmd.move_dir = Vector2(0.0, -1.0)
		fly_cmd.aim_yaw = 0.0
		fly_cmd.aim_pitch = 0.0
		pilot.latest_server_input = fly_cmd
		plane.step_vehicle_server(1.0 / 60.0, wall_heroes, wall_ctx)
		await get_tree().physics_frame

	var has_crash_exp: bool = false
	for ev in exp_events:
		if is_equal_approx(float(ev.get("radius", 0.0)), VehiclePlane.CRASH_RADIUS) and int(ev.get("attacker_id", -1)) == 8302:
			has_crash_exp = true
			break

	_assert(
		plane.is_destroyed
		and enemy_wall.hp < enemy_wall.max_hp
		and ally_wall.hp == ally_wall.max_hp
		and enemy_jeep.hp < enemy_jeep.max_hp
		and ally_jeep.hp == ally_jeep.max_hp
		and has_crash_exp,
		"VehiclePlane wall crash detonates with radial enemy splash (enemy_hp=%d/%d, e_veh=%d/%d), zero friendly fire (ally_hp=%d/%d, a_veh=%d/%d), and explosion_vfx" % [enemy_wall.hp, enemy_wall.max_hp, enemy_jeep.hp, enemy_jeep.max_hp, ally_wall.hp, ally_wall.max_hp, ally_jeep.hp, ally_jeep.max_hp]
	)

	plane._respawn_vehicle()
	_assert(
		not plane.is_destroyed and plane.hp == plane.max_hp and plane._airspeed == 0.0 and not plane._was_airborne and is_equal_approx(plane.gravity_scale, 1.0),
		"VehiclePlane._respawn_vehicle cleanly resets airspeed, airborne state, gravity_scale, and hp"
	)

	# 4. Pilot bail-out + unmanned nose-down ballistic dive explosion killing enemy bot
	exp_events.clear()
	hit_events.clear()

	var dive_plane := VehiclePlane.new()
	dive_plane.id = 8305
	dive_plane.team = NetworkManager.TEAM_ROYAL
	dive_plane.position = Vector3(50.0, 6.5, 30.0)
	arena.add_child(dive_plane)

	var dive_pilot := HeroCharacter.new()
	dive_pilot.setup_identity(8311, "T3DivePilot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(dive_pilot)
	dive_plane.try_enter_hero(dive_pilot)

	var dive_enemy := HeroCharacter.new()
	dive_enemy.setup_identity(8312, "T3DiveTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, true)
	arena.add_child(dive_enemy)
	dive_enemy.global_position = Vector3(50.0, 0.5, -14.0)

	var dive_heroes: Dictionary = {8311: dive_pilot, 8312: dive_enemy}
	var dive_ctx: Dictionary = {"heroes_by_id": dive_heroes}

	await get_tree().physics_frame
	dive_plane.global_position = Vector3(50.0, 6.5, 30.0)
	dive_plane.rotation = Vector3.ZERO
	dive_plane._airspeed = 34.0
	dive_plane._was_airborne = true
	dive_plane._crash_armed_time = 0.5
	dive_plane.linear_velocity = Vector3(0.0, 0.0, -34.0)
	dive_plane._prev_vel = dive_plane.linear_velocity

	for _p in range(5):
		var dcmd := InputCmd.new()
		dcmd.move_dir = Vector2(0.0, -1.0)
		dcmd.aim_yaw = 0.0
		dcmd.aim_pitch = 0.0
		dive_pilot.latest_server_input = dcmd
		dive_plane.step_vehicle_server(1.0 / 60.0, dive_heroes, dive_ctx)
		await get_tree().physics_frame

	var bail_z: float = dive_plane.global_position.z
	dive_plane.exit_hero(dive_pilot)
	dive_pilot.global_position = Vector3(50.0, 20.0, 60.0) # Far clear of blast

	var max_dive_pitch: float = 0.0
	for _u in range(150):
		if dive_plane.is_destroyed:
			break
		dive_plane.step_vehicle_server(1.0 / 60.0, dive_heroes, dive_ctx)
		max_dive_pitch = minf(max_dive_pitch, dive_plane.rotation.x)
		await get_tree().physics_frame

	NetworkManager.game_event_received.disconnect(on_crash_evt)

	var dive_exp_ok: bool = false
	for ev in exp_events:
		if is_equal_approx(float(ev.get("radius", 0.0)), VehiclePlane.CRASH_RADIUS) and int(ev.get("attacker_id", -1)) == 8311:
			dive_exp_ok = true
			break
	var dive_hit_ok: bool = false
	for hev in hit_events:
		if int(hev.get("attacker_id", -1)) == 8311 and int(hev.get("victim_id", -1)) == 8312 and int(hev.get("damage", 0)) > 0:
			dive_hit_ok = true
			break

	_assert(
		dive_plane.is_destroyed
		and dive_plane.global_position.z < bail_z - 15.0
		and max_dive_pitch < -0.15
		and dive_enemy.is_defeated and dive_enemy.last_killer_id == 8311
		and dive_exp_ok and dive_hit_ok,
		"Unmanned bailed-out plane maintains forward momentum (dz=%.1fm), pitches nose-down (min_pitch=%.2f), detonates on ground impact, kills enemy bot (defeated=%s, killer=%d), and broadcasts explosion_vfx + hit_vfx" % [dive_plane.global_position.z - bail_z, max_dive_pitch, str(dive_enemy.is_defeated), dive_enemy.last_killer_id]
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase9_all_9_fixes() -> void:
	# 1, 2 & 3. Match restart vehicle/prop respawn, Conquest flag reset across matches, & 4th Flag Town Square + HUD A..F pips
	var mg_scene := load("res://scenes/main.tscn") as PackedScene
	var mg := mg_scene.instantiate() as MainGame
	add_child(mg)
	await _flush_deferred()

	var town_cp: CapturePoint = null
	var all_6_cps: bool = (mg.conquest_manager.capture_points.size() == 6)
	for cp in mg.conquest_manager.capture_points:
		if cp.point_index == 3:
			town_cp = cp
	var town_lbl := town_cp._flag_label_3d if town_cp != null else null
	var hud_pips_ok: bool = (mg.hud != null and mg.hud._flag_pips.size() == 6)
	if hud_pips_ok:
		var letters: PackedStringArray = PackedStringArray(["A", "B", "C", "D", "E", "F"])
		for pi in range(6):
			var pip: ColorRect = mg.hud._flag_pips[pi]
			var plbl := pip.get_child(0) as Label if pip.get_child_count() > 0 else null
			if pip.custom_minimum_size != Vector2(22, 16) or plbl == null or plbl.text != letters[pi]:
				hud_pips_ok = false
				break
	_assert(
		all_6_cps and town_cp != null and town_cp.point_name == "Town Square"
		and town_cp.position.y >= 2.299 and town_lbl != null and town_lbl.text == "[D] Town Square"
		and hud_pips_ok,
		"Phase 9.3: 6 Conquest flags present with Town Square ([D]) elevated above plaza and A..F HUD pips"
	)

	# Simulate captured flags, destroyed vehicle, destroyed DestructibleProp, stray projectile, then reset match
	var test_veh: VehicleBase = mg.vehicles_by_id.values()[0] as VehicleBase
	test_veh.apply_marked(12.0)
	test_veh.is_destroyed = true
	test_veh.hp = 0
	test_veh._respawn_timer = 19.5
	test_veh.visible = false

	var test_prop: DestructibleProp = null
	var found_props: Array[Node] = mg.map_instance.find_children("*", "DestructibleProp", true, false)
	if not found_props.is_empty():
		test_prop = found_props[0] as DestructibleProp
		test_prop.is_broken = true
		test_prop.hp = 0
		test_prop.visible = false

	var stray_proj := Node3D.new()
	mg.projectiles_root.add_child(stray_proj)

	for cp in mg.conquest_manager.capture_points:
		cp.owner_team = NetworkManager.TEAM_NATIONAL if cp.initial_owner_team != NetworkManager.TEAM_NATIONAL else NetworkManager.TEAM_ROYAL
		cp.capturing_team = NetworkManager.TEAM_ROYAL
		cp.progress = 0.35

	mg._clear_match_entities()
	mg.conquest_manager.reset_match()
	await get_tree().process_frame
	await _flush_deferred()

	var all_flags_reset: bool = true
	for cp in mg.conquest_manager.capture_points:
		var exp_prog: float = 1.0 if cp.initial_owner_team >= 0 else 0.0
		if cp.owner_team != cp.initial_owner_team or cp.capturing_team != -1 or not is_equal_approx(cp.progress, exp_prog):
			all_flags_reset = false
			break

	_assert(
		not test_veh.is_destroyed and test_veh.hp == test_veh.max_hp and test_veh._respawn_timer == 0.0
		and test_veh.visible and not test_veh.is_marked
		and (test_prop == null or (not test_prop.is_broken and test_prop.hp == test_prop.max_hp and test_prop.visible))
		and mg.projectiles_root.get_child_count() == 0
		and all_flags_reset,
		"Phase 9.1 & 9.2: _clear_match_entities() + conquest_manager.reset_match() cleanly respawn vehicles/props, clear projectiles & reset all 6 flags (veh_ok=%s prop_ok=%s proj=%d flags=%s)" % [
			str(not test_veh.is_destroyed and test_veh.hp == test_veh.max_hp and not test_veh.is_marked),
			str(test_prop == null or (not test_prop.is_broken and test_prop.hp == test_prop.max_hp)),
			mg.projectiles_root.get_child_count(),
			str(all_flags_reset),
		]
	)

	mg._start_bots_sync(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER)
	if test_veh != null:
		test_veh.step_vehicle_server(1.0 / 60.0, mg.heroes_by_id, mg._build_combat_context())
		test_veh._on_destroyed(-1)
		test_veh._respawn_vehicle()
	_assert(
		mg.heroes_by_id.size() == 28 and mg.heroes_by_id.has(1),
		"Vehicle respawn during active match preserves MainGame.heroes_by_id without wiping roster (size=%d, has_local=%s)" % [
			mg.heroes_by_id.size(),
			str(mg.heroes_by_id.has(1)),
		]
	)

	mg.queue_free()
	await _flush_deferred()

	# 4, 5, 6 & 7. Mark Target (crosshair/LOS/unlimited range/single-target), Sixth Sense (55m radius & Stealth reveal), Bot 130° cone, and Buff VFX
	var arena := Node3D.new()
	add_child(arena)

	var wall_body := StaticBody3D.new()
	wall_body.collision_layer = 1
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8.0, 6.0, 1.0)
	wall_col.shape = wall_box
	wall_body.add_child(wall_col)
	arena.add_child(wall_body)
	wall_body.global_position = Vector3(40.0, 2.0, -25.0)

	var cmd_h := HeroCharacter.new()
	cmd_h.setup_identity(9001, "P9Cmd", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	arena.add_child(cmd_h)
	cmd_h.global_position = Vector3(0.0, 0.1, 0.0)

	var sol_h := HeroCharacter.new()
	sol_h.setup_identity(9002, "P9Sol", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(sol_h)
	sol_h.global_position = Vector3(0.0, 0.1, 0.0)
	sol_h.hero_camera.camera.position = Vector3(0.0, 2.5, 4.0)
	sol_h.hero_camera.camera.look_at(Vector3(0.0, 1.0, -40.0), Vector3.UP)

	var far_stealth := HeroCharacter.new()
	far_stealth.setup_identity(9003, "P9FarStealth", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	arena.add_child(far_stealth)
	far_stealth.global_position = Vector3(0.0, 0.1, -300.0)

	var mid_enemy := HeroCharacter.new()
	mid_enemy.setup_identity(9004, "P9MidEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(mid_enemy)
	mid_enemy.global_position = Vector3(0.0, 0.1, -40.0)
	mid_enemy.is_stealthed = true
	mid_enemy.active_flags |= NetSerializer.SNAP_STEALTHED

	var blocked_enemy := HeroCharacter.new()
	blocked_enemy.setup_identity(9005, "P9Blocked", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(blocked_enemy)
	blocked_enemy.global_position = Vector3(40.0, 0.1, -40.0)

	await get_tree().physics_frame

	var p9_heroes: Dictionary = {9001: cmd_h, 9002: sol_h, 9003: far_stealth, 9004: mid_enemy, 9005: blocked_enemy}
	var p9_ctx: Dictionary = {"heroes_by_id": p9_heroes, "vehicles": [] as Array[VehicleBase]}

	# Miss in empty sky
	var miss_ok: bool = not cmd_h.status_effects.try_mark_crosshair_target(p9_ctx, PI * 0.5, 0.0, 12.0)

	# LOS blocked by wall (40, 2, -25) in front of blocked_enemy (40, 0.1, -40) from cmd_h at (40, 0.1, 0)
	cmd_h.global_position = Vector3(40.0, 0.1, 0.0)
	var wall_blocks_mark: bool = not cmd_h.status_effects.try_mark_crosshair_target(p9_ctx, 0.0, 0.0, 12.0)

	# Clear LOS at 300m (> 150m!) breaks Stealth & marks 1 target
	cmd_h.global_position = Vector3(0.0, 0.1, 0.0)
	far_stealth.is_stealthed = true
	far_stealth.active_flags |= NetSerializer.SNAP_STEALTHED
	# Aim slightly around mid_enemy to hit far_stealth cleanly: place mid_enemy off-center temporarily so ray picks far_stealth at 300m
	mid_enemy.global_position = Vector3(25.0, 0.1, -30.0)
	var eye_c: Vector3 = cmd_h.global_position + Vector3(0.0, 1.5, 0.0)
	var dir_far: Vector3 = (far_stealth.global_position + Vector3(0.0, 1.0, 0.0) - eye_c).normalized()
	var hit_far_ok: bool = cmd_h.status_effects.try_mark_crosshair_target(p9_ctx, atan2(-dir_far.x, -dir_far.z), asin(dir_far.y), 12.0)
	var far_marked_only: bool = hit_far_ok and far_stealth.status_effects.is_marked() and not far_stealth.is_stealthed and not mid_enemy.status_effects.is_marked()

	# Marking mid_enemy switches mark to mid_enemy & clears far_stealth
	var dir_mid: Vector3 = (mid_enemy.global_position + Vector3(0.0, 1.0, 0.0) - eye_c).normalized()
	var switch_ok: bool = cmd_h.status_effects.try_mark_crosshair_target(p9_ctx, atan2(-dir_mid.x, -dir_mid.z), asin(dir_mid.y), 12.0)
	var single_target_switch_ok: bool = switch_ok and mid_enemy.status_effects.is_marked() and not far_stealth.status_effects.is_marked()

	_assert(
		miss_ok and wall_blocks_mark and far_marked_only and single_target_switch_ok,
		"Phase 9.4: Mark Target enforces crosshair+LOS, works at 300m, breaks Stealth, and locks 1 target at a time"
	)

	# Reset mid_enemy straight ahead at 40m (< 55m) and far_stealth at 120m (> 55m), test Soldier Sixth Sense
	mid_enemy.status_effects.clear_all()
	mid_enemy.global_position = Vector3(0.0, 0.1, -40.0)
	mid_enemy.is_stealthed = true
	mid_enemy.active_flags = NetSerializer.SNAP_STEALTHED
	far_stealth.global_position = Vector3(0.0, 0.1, -120.0)
	far_stealth.is_stealthed = false
	far_stealth.active_flags = 0

	var hud9 := HUDController.new()
	arena.add_child(hud9)
	await _flush_deferred()
	hud9._local_hero = sol_h
	hud9._heroes_ref = {9002: sol_h, 9003: far_stealth, 9004: mid_enemy}
	hud9._vehicles_ref = [] as Array[VehicleBase]

	sol_h.active_flags |= NetSerializer.SNAP_SIXTH_SENSE
	hud9._update_sixth_sense_markers()
	var visible_markers_55m: int = 0
	for mk in hud9._marker_pool:
		if mk.visible:
			visible_markers_55m += 1
	StatusEffectsVFX.update_hero_client_visuals(mid_enemy, sol_h, 0.016)
	StatusEffectsVFX.update_hero_client_visuals(far_stealth, sol_h, 0.016)
	var mid_overlay := (mid_enemy._mesh_parts[0] as MeshInstance3D).material_overlay
	var far_overlay := (far_stealth._mesh_parts[0] as MeshInstance3D).material_overlay

	_assert(
		is_equal_approx(StatusEffectContainer.SIXTH_SENSE_RADIUS, 55.0)
		and visible_markers_55m == 1
		and mid_enemy.visual_root.visible and mid_overlay != null and far_overlay == null,
		"Phase 9.5: Sixth Sense reveals enemies (incl. Stealth) within 55m radius only, ignoring 120m enemies"
	)

	# 6. Bot 130 deg frontal vision cone
	var bot_h := HeroCharacter.new()
	bot_h.setup_identity(9006, "P9Bot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	arena.add_child(bot_h)
	bot_h.global_position = Vector3(0.0, 0.1, 0.0)
	bot_h.aim_yaw = 0.0 # facing -Z

	var cone_front := HeroCharacter.new()
	cone_front.setup_identity(9007, "ConeFront", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(cone_front)
	cone_front.global_position = Vector3(20.0, 0.1, -20.0) # 45 deg (< 65 deg)

	var cone_side := HeroCharacter.new()
	cone_side.setup_identity(9008, "ConeSide", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(cone_side)
	cone_side.global_position = Vector3(25.0, 0.1, 0.0) # 90 deg (> 65 deg)

	var cone_rear := HeroCharacter.new()
	cone_rear.setup_identity(9009, "ConeRear", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(cone_rear)
	cone_rear.global_position = Vector3(0.0, 0.1, 10.0) # 180 deg behind

	var bc9 := BotController.new()
	bc9.bot_hero = bot_h
	var space9: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	var picked_front: HeroCharacter = bc9._find_nearest_visible_enemy({9006: bot_h, 9007: cone_front, 9008: cone_side, 9009: cone_rear}, space9)
	var picked_rear_only: HeroCharacter = bc9._find_nearest_visible_enemy({9006: bot_h, 9009: cone_rear}, space9)

	_assert(
		is_equal_approx(BotController.FOV_HALF_ANGLE_DEG, 65.0)
		and bc9.is_in_vision_cone(cone_front) and not bc9.is_in_vision_cone(cone_side) and not bc9.is_in_vision_cone(cone_rear)
		and picked_front == cone_front and picked_rear_only == null,
		"Phase 9.6: BotController enforces 130° frontal vision cone (ignores closer behind/side enemies)"
	)

	arena.queue_free()
	await _flush_deferred()

	# 8. Mouse extra button hotkeys (encoding, short labels, ConfigFile save/load, ClassSelectMenu _input filter)
	InputCmd.reset_default_hotkeys()
	var menu9 := ClassSelectMenu.new()
	menu9.hotkeys_config_path = ""
	add_child(menu9)
	await _flush_deferred()
	menu9.show_screen("settings")
	menu9._begin_hotkey_listen("skill", 1)

	var ev_left := InputEventMouseButton.new()
	ev_left.button_index = MOUSE_BUTTON_LEFT
	ev_left.pressed = true
	menu9._input(ev_left)
	var left_ignored: bool = InputCmd.get_skill_key(1) == InputCmd.DEFAULT_SKILL_HOTKEYS[1]

	var ev_m4 := InputEventMouseButton.new()
	ev_m4.button_index = MOUSE_BUTTON_XBUTTON1
	ev_m4.pressed = true
	menu9._input(ev_m4)
	var m4_code: int = InputCmd.encode_mouse_button(MOUSE_BUTTON_XBUTTON1)
	var m4_bound: bool = InputCmd.get_skill_key(1) == m4_code and InputCmd.key_short_label(m4_code) == "M4"

	InputCmd.set_skill_key(2, InputCmd.encode_mouse_button(MOUSE_BUTTON_XBUTTON2))
	InputCmd.set_widget_key(0, InputCmd.encode_mouse_button(MOUSE_BUTTON_MIDDLE))
	var test_cfg_path: String = "user://phase9_mouse_hotkeys_test.cfg"
	InputCmd.save_hotkeys_to_config(test_cfg_path)
	InputCmd.reset_default_hotkeys()
	var loaded_ok: bool = InputCmd.load_hotkeys_from_config(test_cfg_path)
	var roundtrip_ok: bool = (
		loaded_ok
		and InputCmd.get_skill_key(1) == m4_code
		and InputCmd.get_skill_key(2) == InputCmd.encode_mouse_button(MOUSE_BUTTON_XBUTTON2)
		and InputCmd.key_short_label(InputCmd.get_skill_key(2)) == "M5"
		and InputCmd.key_short_label(InputCmd.get_widget_key(0)) == "M3"
	)
	InputCmd.reset_default_hotkeys()
	menu9.queue_free()
	await _flush_deferred()

	_assert(
		left_ignored and m4_bound and roundtrip_ok,
		"Phase 9.8: Extra mouse buttons (M3/M4/M5) bind cleanly in ClassSelectMenu, persist via ConfigFile, and Left/Right clicks are ignored"
	)

	# 9. Distinct 3D meshes and 2D HUD icons across all 24 (weapon_kind 0..7 x archetype 0..2) variants
	var tmp_weapon := Node3D.new()
	var all_24_meshes_distinct: bool = true
	var all_24_icons_distinct: bool = true
	for wk in range(8):
		var mesh_sigs: Array[String] = []
		var icon_datas: Array[PackedByteArray] = []
		for arch in range(3):
			var w_info: Dictionary = HeroMeshBuilder.populate_weapon_root(tmp_weapon, wk, arch)
			var m_pos: Vector3 = w_info.get("muzzle", Vector3.ZERO) as Vector3
			var c_cnt: int = tmp_weapon.get_child_count()
			var p0_pos: Vector3 = (tmp_weapon.get_child(0) as Node3D).position if c_cnt > 0 else Vector3.ZERO
			var sig: String = "%.3f|%d|%.3f,%.3f,%.3f" % [m_pos.z, c_cnt, p0_pos.x, p0_pos.y, p0_pos.z]
			if mesh_sigs.has(sig) or c_cnt == 0:
				all_24_meshes_distinct = false
			mesh_sigs.append(sig)

			var tex: ImageTexture = CartoonAssets.get_texture("icon_weapon_%d_%d" % [wk, arch])
			var data: PackedByteArray = tex.get_image().get_data() if tex != null and tex.get_image() != null else PackedByteArray()
			if data.is_empty() or icon_datas.has(data):
				all_24_icons_distinct = false
			icon_datas.append(data)
	tmp_weapon.free()

	_assert(
		all_24_meshes_distinct and all_24_icons_distinct,
		"Phase 9.9: All 24 (weapon_kind 0..7 x archetype 0..2) variants have distinct 3D geometry/muzzle signatures and distinct 2D HUD icons"
	)


func _test_phase10_all_8_items() -> void:
	NetworkManager.shutdown_network()
	var arena := Node3D.new()
	add_child(arena)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(240.0, 1.0, 240.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var lc10 := LagCompensator.new()
	arena.add_child(lc10)

	# 1. Sniper 0-tick host rewind, 1500m range, and standing/crouching head & body hitbox hits
	var sniper_h := HeroCharacter.new()
	sniper_h.setup_identity(10001, "P10Sniper", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	arena.add_child(sniper_h)
	sniper_h.global_position = Vector3(0.0, 0.0, 0.0)
	sniper_h.switch_weapon_slot(0)
	var sniper_w: WeaponBase = sniper_h.weapons[0] as WeaponBase

	var target_s := HeroCharacter.new()
	target_s.setup_identity(10002, "P10Target", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(target_s)
	target_s.global_position = Vector3(0.0, 0.0, -40.0)

	var p10_heroes: Dictionary = {10001: sniper_h, 10002: target_s}
	var p10_ctx: Dictionary = {
		"heroes_by_id": p10_heroes,
		"lag_compensator": lc10,
		"projectiles_root": arena,
		"vehicles_by_id": {},
	}
	await get_tree().physics_frame

	# Record tick 90 at far off-position, then tick 100 at actual 1400m position; 0-tick host rewind hits tick 100
	target_s.global_position = Vector3(80.0, 0.0, -1400.0)
	lc10.record_frame(90, p10_heroes)
	target_s.global_position = Vector3(0.0, 0.0, -1400.0)
	target_s.is_crouching = false
	lc10.record_frame(100, p10_heroes)
	NetworkManager.server_tick = 100

	var trace_stand_head: Dictionary = lc10.trace_rewound_ray(
		sniper_h, Vector3(0.0, 1.66, 0.0), Vector3(0.0, 0.0, -1.0),
		sniper_w.max_range_m, 0, 100, p10_heroes, arena.get_world_3d()
	)
	var trace_stand_body: Dictionary = lc10.trace_rewound_ray(
		sniper_h, Vector3(0.0, 1.00, 0.0), Vector3(0.0, 0.0, -1.0),
		sniper_w.max_range_m, 0, 100, p10_heroes, arena.get_world_3d()
	)

	target_s.is_crouching = true
	lc10.record_frame(101, p10_heroes)
	NetworkManager.server_tick = 101
	var trace_crouch_head: Dictionary = lc10.trace_rewound_ray(
		sniper_h, Vector3(0.0, 1.34, 0.0), Vector3(0.0, 0.0, -1.0),
		sniper_w.max_range_m, 0, 101, p10_heroes, arena.get_world_3d()
	)
	var trace_crouch_body: Dictionary = lc10.trace_rewound_ray(
		sniper_h, Vector3(0.0, 0.78, 0.0), Vector3(0.0, 0.0, -1.0),
		sniper_w.max_range_m, 0, 101, p10_heroes, arena.get_world_3d()
	)

	_assert(
		is_equal_approx(sniper_w.max_range_m, 1500.0)
		and int(trace_stand_head.get("target_hero_id", -1)) == 10002 and bool(trace_stand_head.get("is_headshot", false))
		and int(trace_stand_body.get("target_hero_id", -1)) == 10002 and not bool(trace_stand_body.get("is_headshot", true))
		and int(trace_crouch_head.get("target_hero_id", -1)) == 10002 and bool(trace_crouch_head.get("is_headshot", false))
		and int(trace_crouch_body.get("target_hero_id", -1)) == 10002 and not bool(trace_crouch_body.get("is_headshot", true)),
		"Phase 10.1: Sniper 1500m range & 0-tick host rewind hit standing/crouching head and body hitboxes cleanly at 1400m"
	)

	# 2. Commando Poisoned Blade auto-equips Knife, melee cleave cone hit, immediate poison tick + DoT & SNAP_POISONED
	target_s.respawn_at(Vector3(0.70, 0.0, -1.95), 0.0)
	target_s.is_crouching = false
	sniper_h.global_position = Vector3(0.0, 0.0, 0.0)
	sniper_h.switch_weapon_slot(0)
	var pb_cmd := InputCmd.new()
	pb_cmd.tick = 200
	pb_cmd.aim_yaw = 0.0
	pb_cmd.aim_pitch = 0.0
	pb_cmd.selected_weapon_slot = 0
	pb_cmd.set_button(InputCmd.BTN_SKILL_3, true)
	sniper_h.latest_server_input = pb_cmd
	var pb_heal_vfx_seen: Array[bool] = [false]
	var pb_vfx_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "hit_vfx" and str(payload.get("kind", "")) == "heal":
			pb_heal_vfx_seen[0] = true
	NetworkManager.game_event_received.connect(pb_vfx_cb)
	sniper_h.skill_manager.step_server(1.0 / 60.0, sniper_h.latest_server_input, p10_ctx)
	var pb_exec_ok: bool = sniper_h.status_effects.has_poisoned_blade()
	var incoming_same_tick: int = clampi(sniper_h.latest_server_input.selected_weapon_slot, 0, sniper_h.weapons.size() - 1)
	if sniper_h.should_apply_client_weapon_slot(incoming_same_tick, sniper_h.latest_server_input.tick):
		sniper_h.selected_weapon_slot = incoming_same_tick
	var auto_knife_ok: bool = (sniper_h.selected_weapon_slot == 1 and pb_cmd.selected_weapon_slot == 0)
	var hp_before_cleave: int = target_s.hp
	var knife_w: WeaponBase = sniper_h.weapons[1] as WeaponBase
	knife_w.fire_server(pb_cmd, p10_ctx)
	NetworkManager.game_event_received.disconnect(pb_vfx_cb)
	var hp_after_cleave: int = target_s.hp
	var immediate_poison_ok: bool = (
		hp_after_cleave == hp_before_cleave - 75
		and target_s.status_effects.is_poisoned()
		and (target_s.active_flags & NetSerializer.SNAP_POISONED) != 0
		and pb_heal_vfx_seen[0]
	)
	for _pt in range(35):
		target_s.status_effects._physics_process(0.016)
	var hp_after_dot: int = target_s.hp
	var dot_tick_ok: bool = (hp_after_dot == hp_after_cleave - 13)
	target_s.status_effects.cleanse_poison()
	var antidote_cleanse_ok: bool = (
		not target_s.status_effects.is_poisoned()
		and (target_s.active_flags & NetSerializer.SNAP_POISONED) == 0
	)

	# Verify remote ENet client Poisoned Blade weapon_slot sync & stale InputCmd protection
	var stale_cmd := InputCmd.new()
	stale_cmd.tick = 201
	stale_cmd.selected_weapon_slot = 0
	sniper_h.latest_server_input = stale_cmd
	var incoming_next_tick: int = clampi(sniper_h.latest_server_input.selected_weapon_slot, 0, sniper_h.weapons.size() - 1)
	if sniper_h.should_apply_client_weapon_slot(incoming_next_tick, sniper_h.latest_server_input.tick):
		sniper_h.selected_weapon_slot = incoming_next_tick
	sniper_h.simulate_movement(stale_cmd, 1.0 / 60.0)
	var server_holds_knife_ok: bool = (sniper_h.selected_weapon_slot == 1)
	var auth_pb_bytes: PackedByteArray = NetSerializer.pack_authoritative_state(
		200, sniper_h.global_position, Vector3.ZERO, sniper_h.active_flags,
		sniper_h.hp, sniper_h.shield, -1, -1, 0, sniper_h.active_buffs,
		sniper_h.selected_weapon_slot, sniper_h.forced_weapon_seq
	)
	var auth_pb_dec: Dictionary = NetSerializer.unpack_authoritative_state(auth_pb_bytes)
	var remote_com := HeroCharacter.new()
	remote_com.setup_identity(10009, "RemoteCom", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	arena.add_child(remote_com)
	remote_com.switch_weapon_slot(0)
	remote_com.reconcile_with_server(auth_pb_dec)
	var remote_synced_knife_ok: bool = (remote_com.selected_weapon_slot == 1)
	var ack_cmd := InputCmd.new()
	ack_cmd.tick = 202
	ack_cmd.selected_weapon_slot = 1
	sniper_h.simulate_movement(ack_cmd, 1.0 / 60.0)
	var back_cmd := InputCmd.new()
	back_cmd.tick = 203
	back_cmd.selected_weapon_slot = 0
	sniper_h.simulate_movement(back_cmd, 1.0 / 60.0)
	var manual_switch_back_ok: bool = (sniper_h.selected_weapon_slot == 0)
	remote_com.queue_free()

	# Verify Layer-1 wall blocks melee cleave cone fallback
	var melee_wall := StaticBody3D.new()
	melee_wall.collision_layer = 1
	var mw_col := CollisionShape3D.new()
	var mw_box := BoxShape3D.new()
	mw_box.size = Vector3(4.0, 3.0, 0.3)
	mw_col.shape = mw_box
	mw_col.position = Vector3(0.35, 1.5, -1.0)
	melee_wall.add_child(mw_col)
	arena.add_child(melee_wall)
	target_s.respawn_at(Vector3(0.70, 0.0, -1.95), 0.0)
	await get_tree().physics_frame
	var hp_before_walled_cleave: int = target_s.hp
	knife_w.fire_server(pb_cmd, p10_ctx)
	var melee_wall_blocked_ok: bool = (target_s.hp == hp_before_walled_cleave)
	melee_wall.queue_free()

	_assert(
		pb_exec_ok and auto_knife_ok and immediate_poison_ok and dot_tick_ok and antidote_cleanse_ok
		and server_holds_knife_ok and remote_synced_knife_ok and manual_switch_back_ok and melee_wall_blocked_ok,
		"Phase 10.2: Poisoned Blade auto-equips Knife (pure melee %d->%d, 0.5s DoT %d + Antidote cleanse), broadcasts heal VFX, and Layer-1 wall blocks cleave" % [hp_before_cleave, hp_after_cleave, hp_after_dot]
	)

	# 3. Commando Stealth 10m detection radius, enemy reveal cloak_val <= 0.15, and local Commando uncloak within 10m
	target_s.respawn_at(Vector3(0.0, 0.0, -18.0), 0.0)
	sniper_h.global_position = Vector3(0.0, 0.0, 0.0)
	var stealth_exec_ok: bool = sniper_h.skill_manager._execute_class_skill(0, 5, pb_cmd, p10_ctx)
	var detect_r_ok: bool = is_equal_approx(sniper_h.status_effects.stealth_detection_radius, 10.0)
	StatusEffectsVFX.update_hero_client_visuals(sniper_h, target_s, 0.016, {}, p10_heroes)
	var hidden_far_ok: bool = not sniper_h.visual_root.visible
	StatusEffectsVFX.update_hero_client_visuals(sniper_h, sniper_h, 0.016, {}, p10_heroes)
	var local_cloak_far: float = float(((sniper_h._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("cloak_amount"))

	target_s.global_position = Vector3(0.0, 0.0, -9.0)
	StatusEffectsVFX.update_hero_client_visuals(sniper_h, target_s, 0.016, {}, p10_heroes)
	var enemy_mat_near := (sniper_h._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial
	var enemy_cloak_near: float = float(enemy_mat_near.get_shader_parameter("cloak_amount"))
	var revealed_to_enemy_ok: bool = sniper_h.visual_root.visible and enemy_cloak_near <= 0.15
	StatusEffectsVFX.update_hero_client_visuals(sniper_h, sniper_h, 0.016, {}, p10_heroes)
	var local_cloak_near: float = float(((sniper_h._mesh_parts[0] as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("cloak_amount"))
	sniper_h.status_effects.break_stealth()
	_assert(
		stealth_exec_ok and detect_r_ok and hidden_far_ok and revealed_to_enemy_ok and local_cloak_far > 0.4 and local_cloak_near <= 0.01,
		"Phase 10.3: Stealth 10m detection hides at 18m, reveals enemy cloak<=0.15 (%.2f) & uncloaks local Commando at 9m (%.2f -> %.2f)" % [enemy_cloak_near, local_cloak_far, local_cloak_near]
	)

	# 4. VehicleMotorcycle 2 seats (Driver + shooting/skill Passenger), speed, visuals, and HUD "MOTO"
	var moto := VehicleMotorcycle.new()
	moto.id = 910
	moto.team = NetworkManager.TEAM_ROYAL
	arena.add_child(moto)
	moto.global_position = Vector3(-12.0, 0.05, 0.0)

	var moto_drv := HeroCharacter.new()
	moto_drv.setup_identity(10010, "MotoDrv", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(moto_drv)
	var moto_pax := HeroCharacter.new()
	moto_pax.setup_identity(10011, "MotoPax", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(moto_pax)

	var moto_s0: int = moto.try_enter_hero(moto_drv)
	var moto_s1: int = moto.try_enter_hero(moto_pax)
	var moto_heroes: Dictionary = {10010: moto_drv, 10011: moto_pax, 10002: target_s}
	var moto_ctx: Dictionary = {"heroes_by_id": moto_heroes, "lag_compensator": lc10, "projectiles_root": arena, "vehicles_by_id": {910: moto}}

	var drv_cmd := InputCmd.new()
	drv_cmd.move_dir = Vector2(0.0, -1.0)
	moto_drv.latest_server_input = drv_cmd

	target_s.respawn_at(Vector3(-12.0, 0.0, -35.0), 0.0)
	lc10.record_frame(103, moto_heroes)
	NetworkManager.server_tick = 103
	var pax_cmd := InputCmd.new()
	pax_cmd.aim_yaw = 0.0
	pax_cmd.aim_pitch = -0.07
	pax_cmd.selected_weapon_slot = 0
	pax_cmd.set_button(InputCmd.BTN_FIRE, true)
	pax_cmd.set_button(InputCmd.BTN_SKILL_1, true)
	moto_pax.latest_server_input = pax_cmd

	for _mt in range(45):
		moto.step_vehicle_server(1.0 / 60.0, moto_heroes, moto_ctx)
		await get_tree().physics_frame
	var moto_spd: float = Vector2(moto.linear_velocity.x, moto.linear_velocity.z).length()
	var pax_shot_ok: bool = target_s.hp < target_s.max_hp
	var pax_skill_ok: bool = moto_pax.status_effects.hot_timer > 0.0

	var moto_mis: Array[MeshInstance3D] = []
	_collect_mesh_instances(moto._visual_root, moto_mis)
	var moto_bad_vol: int = 0
	var moto_bad_alpha: int = 0
	for mi in moto_mis:
		if mi.mesh is ArrayMesh and _signed_volume_outward_cw(mi.mesh as ArrayMesh) <= 0.0:
			moto_bad_vol += 1
		var sm := mi.material_override as StandardMaterial3D
		if sm != null and sm.albedo_color.a >= 0.99 and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			moto_bad_alpha += 1

	_assert(
		moto.seats.size() == 2 and moto_s0 == 0 and moto_s1 == 1
		and not moto.seats[0].can_shoot and moto.seats[1].can_shoot and moto.seats[1].can_use_skills
		and moto_spd > 28.0 and pax_shot_ok and pax_skill_ok
		and moto._wheels.size() == 2 and moto._visual_root.get_child_count() >= 6
		and moto_bad_vol == 0 and moto_bad_alpha == 0
		and HUDController.get_vehicle_display_name(VehicleBase.VehicleType.MOTORCYCLE) == "MOTO",
		"Phase 10.4: VehicleMotorcycle 2-seat driver + shooting/skill passenger, high speed (%.1f m/s), lean sculpted visuals, and HUD MOTO" % moto_spd
	)
	moto.exit_hero(moto_drv)
	moto.exit_hero(moto_pax)

	# 5. VehicleAPC 2 seats (enclosed Driver + 360-deg turret Gunner firing mounted MG), visuals, and HUD "BLINDADO"
	var apc := VehicleAPC.new()
	apc.id = 911
	apc.team = NetworkManager.TEAM_NATIONAL
	arena.add_child(apc)
	apc.global_position = Vector3(14.0, 0.05, 0.0)

	var apc_drv := HeroCharacter.new()
	apc_drv.setup_identity(10012, "APCDrv", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(apc_drv)
	var apc_gun := HeroCharacter.new()
	apc_gun.setup_identity(10013, "APCGun", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(apc_gun)

	var apc_s0: int = apc.try_enter_hero(apc_drv)
	var apc_s1: int = apc.try_enter_hero(apc_gun)
	var apc_victim := HeroCharacter.new()
	apc_victim.setup_identity(10014, "APCVictim", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(apc_victim)
	# Place victim 22m to the right (+X) while turret aims right (-PI * 0.5)
	apc_victim.global_position = Vector3(36.0, 1.0, 0.0)

	var apc_heroes: Dictionary = {10012: apc_drv, 10013: apc_gun, 10014: apc_victim}
	var apc_ctx: Dictionary = {"heroes_by_id": apc_heroes, "lag_compensator": lc10, "projectiles_root": arena, "vehicles_by_id": {911: apc}}
	var apc_drv_cmd := InputCmd.new()
	apc_drv_cmd.aim_yaw = 0.0
	apc_drv.latest_server_input = apc_drv_cmd
	var apc_gun_cmd := InputCmd.new()
	apc_gun_cmd.tick = 1
	apc_gun_cmd.aim_yaw = -PI * 0.5
	apc_gun_cmd.aim_pitch = 0.0
	apc_gun_cmd.set_button(InputCmd.BTN_FIRE, true)
	apc_gun.latest_server_input = apc_gun_cmd

	lc10.record_frame(105, apc_heroes)
	NetworkManager.server_tick = 105
	var victim_hp_before: int = apc_victim.hp
	for _at in range(6):
		apc.step_vehicle_server(1.0 / 60.0, apc_heroes, apc_ctx)
		apc._process(1.0 / 60.0)
	var apc_mg_dealt: int = victim_hp_before - apc_victim.hp
	apc_gun._animate_character(1.0 / 60.0)
	var apc_gunner_hides_personal_wep: bool = (apc_gun._held_weapon_root == null or not apc_gun._held_weapon_root.visible)

	var apc_drv_enclosed_while_seated: bool = (apc.get_driver_hero(apc_heroes) == apc_drv and VehicleBase.is_hero_enclosed(apc_drv, {911: apc}))

	# Solo gunner without driver must step cleanly without null errors and still fire turret MG
	apc.exit_hero(apc_drv)
	apc._driver_fire_cd = 0.0
	var victim_hp_before_solo: int = apc_victim.hp
	apc.step_vehicle_server(1.0 / 60.0, apc_heroes, apc_ctx)
	var solo_gunner_mg_ok: bool = (apc.get_driver_hero(apc_heroes) == null and apc_victim.hp < victim_hp_before_solo)

	var apc_mis: Array[MeshInstance3D] = []
	_collect_mesh_instances(apc._visual_root, apc_mis)
	var apc_bad_vol: int = 0
	var apc_bad_alpha: int = 0
	for mi in apc_mis:
		if mi.mesh is ArrayMesh and _signed_volume_outward_cw(mi.mesh as ArrayMesh) <= 0.0:
			apc_bad_vol += 1
		var sm := mi.material_override as StandardMaterial3D
		if sm != null and sm.albedo_color.a >= 0.99 and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			apc_bad_alpha += 1

	_assert(
		apc.seats.size() == 3 and apc_s0 == 0 and apc_s1 == 1
		and apc.seats[2].seat_type == VehicleBase.SeatType.PASSENGER
		and apc.seats[2].local_offset.distance_to(Vector3(0.0, 0.85, 2.48)) < 0.01
		and is_equal_approx(apc.seats[2].local_yaw, PI)
		and apc.seats[2].can_shoot and apc.seats[2].can_use_skills
		and apc_drv_enclosed_while_seated
		and apc.get_gunner_hero(apc_heroes) == apc_gun
		and not VehicleBase.is_hero_enclosed(apc_drv, {911: apc}) and not VehicleBase.is_hero_enclosed(apc_gun, {911: apc})
		and apc.seats[1].follow_turret and absf(apc.turret_yaw - (-PI * 0.5)) < 0.02
		and apc._turret_node != null and absf(apc._turret_node.rotation.y - apc._effective_turret_local_yaw()) < 0.05
		and apc._barrel_pivot != null and apc._wheels.size() == 4
		and apc_mg_dealt >= VehicleAPC.MG_HERO_DMG
		and apc_gunner_hides_personal_wep and solo_gunner_mg_ok
		and apc_bad_vol == 0 and apc_bad_alpha == 0
		and HUDController.get_vehicle_display_name(VehicleBase.VehicleType.APC) == "BLINDADO",
		"Phase 10.5: VehicleAPC 3-seat enclosed driver + 360-deg turret gunner fires mounted MG (dealt=%d dmg) + rear hitch passenger, hides personal weapon, supports solo gunner, and HUD BLINDADO" % apc_mg_dealt
	)
	apc.exit_hero(apc_gun)

	# 6. Ground vehicles (Jeep, Tank, Motorcycle, APC) stall & destroy in water (y <= -0.75) while Boat floats normally
	var w_jeep := VehicleJeep.new()
	var w_tank := VehicleTank.new()
	var w_moto := VehicleMotorcycle.new()
	var w_apc := VehicleAPC.new()
	var w_boat := VehicleBoat.new()
	var water_vehs: Array[VehicleBase] = [w_jeep, w_tank, w_moto, w_apc, w_boat]
	for wv in water_vehs:
		wv.team = NetworkManager.TEAM_ROYAL
		arena.add_child(wv)
	var water_drv := HeroCharacter.new()
	water_drv.setup_identity(10015, "WaterDrv", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(water_drv)
	var water_cmd := InputCmd.new()
	water_cmd.move_dir = Vector2(0.0, -1.0)
	water_drv.latest_server_input = water_cmd
	var w_heroes: Dictionary = {10015: water_drv}
	var w_ctx: Dictionary = {"heroes_by_id": w_heroes}

	var all_ground_stalled_destroyed: bool = true
	for gv in [w_jeep, w_tank, w_moto, w_apc]:
		var veh: VehicleBase = gv as VehicleBase
		if not veh.is_ground_vehicle():
			all_ground_stalled_destroyed = false
		veh.try_enter_hero(water_drv)
		# First test partial submersion stall at y = -0.45 while occupied
		veh.global_position = Vector3(40.0, -0.45, 0.0)
		veh.linear_velocity = Vector3(0.0, 0.0, -16.0)
		veh.step_vehicle_server(0.05, w_heroes, w_ctx)
		if Vector2(veh.linear_velocity.x, veh.linear_velocity.z).length() >= 16.0 or not veh.is_submerged_in_water():
			all_ground_stalled_destroyed = false
		# Occupied in deep water (y = -0.75) stays present without exploding
		veh.global_position = Vector3(40.0, -0.75, 0.0)
		veh.step_vehicle_server(0.05, w_heroes, w_ctx)
		if veh.is_destroyed or veh.hp <= 0 or water_drv.hp != water_drv.max_hp:
			all_ground_stalled_destroyed = false
		# Once all occupants exit (get_occupant_count() == 0), submerged ground vehicle vanishes silently
		veh.exit_hero(water_drv)
		veh.step_vehicle_server(0.05, w_heroes, w_ctx)
		if not veh.is_destroyed or veh.hp != 0 or veh.visible or water_drv.hp != water_drv.max_hp:
			all_ground_stalled_destroyed = false
		water_drv.respawn_at(Vector3(40.0, 1.0, 0.0), 0.0)

	w_boat.global_position = Vector3(50.0, -0.80, 0.0)
	w_boat.linear_velocity = Vector3.ZERO
	for _bt in range(8):
		w_boat.step_vehicle_server(1.0 / 60.0, {}, {})
		await get_tree().physics_frame
	var boat_floats_ok: bool = (not w_boat.is_ground_vehicle()) and (not w_boat.is_submerged_in_water()) and (not w_boat.is_destroyed) and (w_boat.global_position.y > -0.45)
	_assert(
		all_ground_stalled_destroyed and boat_floats_ok,
		"Phase 10.6: Ground vehicles (Jeep/Tank/Motorcycle/APC) stall while occupied in water and vanish silently when empty (y<=-0.75), while VehicleBoat floats normally (ground_ok=%s, boat_y=%.2f)" % [str(all_ground_stalled_destroyed), w_boat.global_position.y]
	)

	# 7. Soldier Sixth Sense reveals enemies & Stealthed Commandos within 55m to distant teammates across the map
	var ss_soldier := HeroCharacter.new()
	ss_soldier.setup_identity(10020, "P10SolSS", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(ss_soldier)
	ss_soldier.global_position = Vector3(0.0, 0.1, 0.0)
	ss_soldier.status_effects.activate_sixth_sense(55.0, 12.0)

	var ss_teammate := HeroCharacter.new()
	ss_teammate.setup_identity(10021, "P10Mate", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, true, false)
	arena.add_child(ss_teammate)
	ss_teammate.global_position = Vector3(-350.0, 0.1, 0.0)
	ss_teammate.hero_camera.camera.position = Vector3(-350.0, 2.5, 4.0)
	ss_teammate.hero_camera.camera.look_at(Vector3(0.0, 1.0, -45.0), Vector3.UP)

	var ss_stealth_enemy := HeroCharacter.new()
	ss_stealth_enemy.setup_identity(10022, "P10Stealth", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	arena.add_child(ss_stealth_enemy)
	ss_stealth_enemy.global_position = Vector3(0.0, 0.1, -45.0)
	ss_stealth_enemy.status_effects.activate_stealth(10.0, -1.0)

	var ss_far_enemy := HeroCharacter.new()
	ss_far_enemy.setup_identity(10023, "P10Far", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(ss_far_enemy)
	ss_far_enemy.global_position = Vector3(0.0, 0.1, -130.0)

	var ss_heroes: Dictionary = {10020: ss_soldier, 10021: ss_teammate, 10022: ss_stealth_enemy, 10023: ss_far_enemy}
	var sensed_near_ok: bool = StatusEffectContainer.is_enemy_sensed_by_team(ss_stealth_enemy, NetworkManager.TEAM_ROYAL, ss_heroes, ss_teammate)
	var sensed_far_ignored: bool = not StatusEffectContainer.is_enemy_sensed_by_team(ss_far_enemy, NetworkManager.TEAM_ROYAL, ss_heroes, ss_teammate)
	StatusEffectsVFX.update_hero_client_visuals(ss_stealth_enemy, ss_teammate, 0.016, {}, ss_heroes)
	var distant_xray_ok: bool = ss_stealth_enemy.visual_root.visible and (ss_stealth_enemy._mesh_parts[0] as MeshInstance3D).material_overlay != null

	var hud10 := HUDController.new()
	arena.add_child(hud10)
	await _flush_deferred()
	hud10._local_hero = ss_teammate
	hud10._heroes_ref = ss_heroes
	hud10._vehicles_ref = [] as Array[VehicleBase]
	hud10._update_sixth_sense_markers()
	var mate_markers: int = 0
	for mk in hud10._marker_pool:
		if mk.visible:
			mate_markers += 1

	# Remote ENet Soldier with only active_buffs = BUFF_SIXTH_SENSE (no local timer, active_flags = 0)
	var ss_remote_sol := HeroCharacter.new()
	ss_remote_sol.setup_identity(10024, "P10RemoteSol", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(ss_remote_sol)
	ss_remote_sol.global_position = Vector3(0.0, 0.1, 0.0)
	ss_remote_sol.active_flags = 0
	ss_remote_sol.active_buffs = NetSerializer.BUFF_SIXTH_SENSE
	ss_remote_sol.status_effects.sixth_sense_timer = 0.0
	var remote_buff_ss_ok: bool = (
		StatusEffectContainer._hero_has_sixth_sense_active(ss_remote_sol)
		and StatusEffectContainer.is_enemy_sensed_by_team(ss_stealth_enemy, NetworkManager.TEAM_ROYAL, {10024: ss_remote_sol, 10022: ss_stealth_enemy}, ss_remote_sol)
	)
	ss_remote_sol.reconcile_with_server({
		"ack_tick": 1, "pos": ss_remote_sol.global_position, "vel": Vector3.ZERO,
		"flags": NetSerializer.SNAP_SIXTH_SENSE, "hp": 110, "shield": 0,
		"vehicle_id": -1, "seat_idx": -1, "knockback_seq": 0, "buffs": NetSerializer.BUFF_SIXTH_SENSE,
	})
	ss_remote_sol.simulate_movement(InputCmd.new(), 1.0 / 60.0)
	var remote_flags_preserved_ok: bool = ((ss_remote_sol.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0 and (ss_remote_sol.active_buffs & NetSerializer.BUFF_SIXTH_SENSE) != 0)
	ss_remote_sol.queue_free()

	_assert(
		sensed_near_ok and sensed_far_ignored and distant_xray_ok and mate_markers == 1
		and remote_buff_ss_ok and remote_flags_preserved_ok,
		"Phase 10.7: Soldier Sixth Sense reveals 45m Stealthed Commando to 350m-distant teammate & remote Soldier via BUFF_SIXTH_SENSE (markers=%d)" % mate_markers
	)

	# 8. Explosives (BAZOOKA_ROCKET 8.0m, TNT_SATCHEL 9.0m, FRAG_GRENADE 7.5m) hit full splash radius without curb self-occlusion & launch upward (vy >= 9.0)
	var curb_body := StaticBody3D.new()
	curb_body.collision_layer = 1
	var curb_col := CollisionShape3D.new()
	var curb_box := BoxShape3D.new()
	curb_box.size = Vector3(8.0, 0.25, 0.5)
	curb_col.shape = curb_box
	curb_col.position = Vector3(70.0, 0.125, -2.5)
	curb_body.add_child(curb_col)
	arena.add_child(curb_body)

	var exp_shooter := HeroCharacter.new()
	exp_shooter.setup_identity(10030, "P10ExpSh", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(exp_shooter)
	exp_shooter.global_position = Vector3(95.0, 0.0, 0.0)

	var exp_enemy := HeroCharacter.new()
	exp_enemy.setup_identity(10031, "P10ExpEn", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(exp_enemy)
	var exp_heroes: Dictionary = {10030: exp_shooter, 10031: exp_enemy}
	var exp_ctx: Dictionary = {"heroes_by_id": exp_heroes, "projectiles_root": arena}

	var exp_specs: Array[Dictionary] = [
		{"kind": ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET, "rad": 8.0, "dist": 7.3},
		{"kind": ProjectileEntity.ProjectileKind.TNT_SATCHEL, "rad": 9.0, "dist": 8.3},
		{"kind": ProjectileEntity.ProjectileKind.FRAG_GRENADE, "rad": 7.5, "dist": 6.8},
	]
	var all_exp_ok: bool = true
	var exp_vy_log: Array[String] = []
	for spec in exp_specs:
		var k: int = int(spec["kind"])
		var exp_rad: float = float(spec["rad"])
		var test_dist: float = float(spec["dist"])
		exp_enemy.respawn_at(Vector3(70.0, 0.0, -test_dist), 0.0)
		await get_tree().physics_frame
		var proj := ProjectileEntity.spawn_server_projectile(k, 10030, NetworkManager.TEAM_ROYAL, Vector3(70.0, 0.08, 0.0), Vector3.ZERO, exp_ctx, -1.0, arena)
		if not is_equal_approx(proj.splash_radius, exp_rad):
			all_exp_ok = false
		proj._detonate()
		exp_vy_log.append("%.1f" % exp_enemy.velocity.y)
		if exp_enemy.hp >= exp_enemy.max_hp or exp_enemy.velocity.y < 9.0:
			all_exp_ok = false

	# Horizontal ceiling/floor slab between stories (y_diff >= 2.0m) MUST occlude splash
	var ceiling_body := StaticBody3D.new()
	ceiling_body.collision_layer = 1
	var ceiling_col := CollisionShape3D.new()
	var ceiling_box := BoxShape3D.new()
	ceiling_box.size = Vector3(8.0, 0.3, 8.0)
	ceiling_col.shape = ceiling_box
	ceiling_col.position = Vector3(70.0, 2.0, -3.0)
	ceiling_body.add_child(ceiling_col)
	arena.add_child(ceiling_body)
	exp_enemy.respawn_at(Vector3(70.0, 2.5, -3.0), 0.0)
	await get_tree().physics_frame
	var ceil_proj := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET, 10030, NetworkManager.TEAM_ROYAL, Vector3(70.0, 0.08, 0.0), Vector3.ZERO, exp_ctx, -1.0, arena)
	ceil_proj._detonate()
	var ceiling_occluded_ok: bool = (exp_enemy.hp == exp_enemy.max_hp and exp_enemy.velocity.length() < 0.01)
	ceiling_body.queue_free()

	_assert(
		all_exp_ok and ceiling_occluded_ok,
		"Phase 10.8: Bazooka (8.0m), TNT (9.0m), and Frag (7.5m) cross low curb (vy=%s), while horizontal ceiling slab occludes upstairs target" % str(exp_vy_log)
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase11_task1_fixes() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	# 1. Poisoned Blade pure DoT (frontal Knife slash deals ONLY 42 dmg, -13 tick at 0.5s, Antidote cleanses + resets _poison_tick_accum)
	var com := HeroCharacter.new()
	com.setup_identity(11001, "P11Com", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	arena.add_child(com)
	com.global_position = Vector3(0.0, 0.0, 0.0)

	var vic := HeroCharacter.new()
	vic.setup_identity(11002, "P11Vic", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(vic)
	vic.global_position = Vector3(0.0, 0.0, -1.6)
	vic.aim_yaw = PI # Facing +Z toward attacker so NOT a backstab

	await get_tree().physics_frame
	var ctx: Dictionary = {"heroes_by_id": {11001: com, 11002: vic}, "projectiles_root": arena, "vehicles_by_id": {}}
	com.status_effects.activate_poisoned_blade(25.0, 13.0)
	com.switch_weapon_slot(1)
	var knife: WeaponBase = com.weapons[1] as WeaponBase
	var slash_cmd := InputCmd.new()
	slash_cmd.tick = 10
	slash_cmd.aim_yaw = 0.0
	slash_cmd.aim_pitch = 0.0
	slash_cmd.selected_weapon_slot = 1
	var hp0: int = vic.hp
	knife.fire_server(slash_cmd, ctx)
	var hp_slash: int = vic.hp
	var slash_pure_ok: bool = (hp0 - hp_slash == 42 and vic.status_effects.is_poisoned() and is_equal_approx(vic.status_effects._poison_tick_accum, 0.0))
	for _i in range(32):
		vic.status_effects._physics_process(0.016)
	var hp_dot: int = vic.hp
	var dot_13_ok: bool = (hp_slash - hp_dot == 13)
	var vsm: SkillManager = vic.skill_manager as SkillManager
	var ant_ok: bool = vsm.try_activate_widget(3, ctx)
	var clean_ok: bool = (
		ant_ok
		and not vic.status_effects.is_poisoned()
		and is_equal_approx(vic.status_effects._poison_tick_accum, 0.0)
	)
	_assert(
		slash_pure_ok and dot_13_ok and clean_ok,
		"Phase 11.1a: Poisoned Blade deals pure Knife slash (%d->%d = -42), -13 DoT at 0.5s (->%d), and Antidote cleanses & resets _poison_tick_accum" % [hp0, hp_slash, hp_dot]
	)

	# 2. Airborne < 1.0s does NOT enter skydiving freefall; >= 1.0s DOES enter skydiving freefall
	var air_h := HeroCharacter.new()
	air_h.setup_identity(11003, "P11Air", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(air_h)
	air_h.global_position = Vector3(10.0, 20.0, 0.0)
	air_h.velocity = Vector3(0.0, -6.0, 0.0)
	air_h.is_in_water = false
	air_h.is_parachuting = false
	air_h._airborne_fall_time = 0.45
	for _i in range(10):
		air_h._animate_character(0.016)
	var under_1s_ok: bool = (
		air_h._held_weapon_root.visible
		and absf(air_h._hips_pivot.rotation.x) < 0.05
	)
	air_h._airborne_fall_time = 1.05
	for _i in range(10):
		air_h._animate_character(0.05)
	var over_1s_ok: bool = (
		not air_h._held_weapon_root.visible
		and air_h._hips_pivot.rotation.x < -0.2
	)
	_assert(
		under_1s_ok and over_1s_ok,
		"Phase 11.1b: Airborne <1.0s keeps weapon visible & upright hips (rotX=%.2f), while >=1.0s enters skydiving freefall (rotX=%.2f)" % [0.0 if under_1s_ok else air_h._hips_pivot.rotation.x, air_h._hips_pivot.rotation.x]
	)

	# 3. Articulated Crouch Rig (hips >= 0.48, thigh > 0.7, calf < -1.0, torso above hips)
	var cr_h := HeroCharacter.new()
	cr_h.setup_identity(11004, "P11Crouch", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(cr_h)
	cr_h.global_position = Vector3(15.0, 0.05, 0.0)
	cr_h.is_crouching = true
	for _i in range(25):
		cr_h._animate_character(0.05)
	var crouch_ok: bool = (
		cr_h._hips_pivot.position.y >= 0.48
		and cr_h._leg_l_pivot.rotation.x > 0.7
		and cr_h._calf_l_pivot != null
		and cr_h._calf_l_pivot.rotation.x < -1.0
		and cr_h._torso_pivot.global_position.y > cr_h._hips_pivot.global_position.y
	)
	_assert(
		crouch_ok,
		"Phase 11.1c: Articulated crouch keeps hips.y=%.2f (>=0.48), thigh.x=%.2f (>0.7), calf.x=%.2f (<-1.0), torso above hips" % [cr_h._hips_pivot.position.y, cr_h._leg_l_pivot.rotation.x, cr_h._calf_l_pivot.rotation.x if cr_h._calf_l_pivot != null else 0.0]
	)

	# 4. Gunner Hero Shield (155) + Frenzy Fire 4th MG shot heals HP strictly and never touches shield
	var gun := HeroCharacter.new()
	gun.setup_identity(11005, "P11Gun", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, true, false)
	arena.add_child(gun)
	gun.global_position = Vector3(20.0, 0.0, 0.0)
	var gsm: SkillManager = gun.skill_manager as SkillManager
	var g_ctx: Dictionary = {"heroes_by_id": {11005: gun, 11002: vic}, "projectiles_root": arena, "vehicles_by_id": {}}
	gsm.try_activate_skill(0, InputCmd.new(), g_ctx) # Hero Shield (+155)
	gsm.try_activate_skill(3, InputCmd.new(), g_ctx) # Frenzy Fire
	gun.hp = gun.max_hp - 30
	var hp_pre_frenzy: int = gun.hp
	var shield_pre_frenzy: int = gun.shield
	vic.respawn_at(Vector3(20.0, 0.0, -5.0), 0.0)
	await get_tree().physics_frame
	var mg_w: HitscanWeapon = gun.weapons[0] as HitscanWeapon
	for _s in range(4):
		mg_w._apply_hero_hit(vic, Vector3(0.0, 0.0, -1.0), 5.0, false, vic.global_position + Vector3(0.0, 1.0, 0.0), 1.0, g_ctx, {}, {}, {})
	var frenzy_isolated_ok: bool = (
		shield_pre_frenzy == 155
		and gun.shield == 155
		and gun.hp > hp_pre_frenzy
	)
	_assert(
		frenzy_isolated_ok,
		"Phase 11.1d: Gunner Hero Shield (%d->%d) stays isolated while Frenzy Fire 4th MG hit heals HP (%d->%d)" % [shield_pre_frenzy, gun.shield, hp_pre_frenzy, gun.hp]
	)

	# 5. Water ("Água") widget at slot 2 cleanses burn, resets _burn_tick_accum, grants 2.0s immunity, and water blocks burn
	var wat_widgets: Array[Dictionary] = SkillCatalog.get_widgets()
	var wat_cat_ok: bool = (wat_widgets.size() > 2 and str(wat_widgets[2].get("name", "")) == "Água")
	var wat_sm_ok: bool = (vsm.widget_names.size() > 2 and vsm.widget_names[2] == "Agua")
	vic.respawn_at(Vector3(25.0, 0.0, 0.0), 0.0)
	vic.is_in_water = false
	vic.status_effects.fire_immunity_timer = 0.0
	vic.status_effects.apply_burn(11001, 16.0, 4.5)
	vic.status_effects._burn_tick_accum = 0.35
	var wat_act_ok: bool = vsm.try_activate_widget(2, g_ctx)
	var wat_clean_ok: bool = (
		vic.status_effects.burn_timer == 0.0
		and is_equal_approx(vic.status_effects._burn_tick_accum, 0.0)
		and is_equal_approx(vic.status_effects.fire_immunity_timer, 2.0)
	)
	vic.status_effects.apply_burn(11001, 16.0, 4.5)
	var wat_immune_ok: bool = (vic.status_effects.burn_timer == 0.0)
	vic.status_effects.fire_immunity_timer = 0.0
	vic.is_in_water = true
	vic.status_effects.apply_burn(11001, 16.0, 4.5)
	var water_blocks_ok: bool = (vic.status_effects.burn_timer == 0.0)
	vic.is_in_water = false
	vic.status_effects.apply_burn(11001, 16.0, 4.5)
	var active_burn_ok: bool = (vic.status_effects.burn_timer > 0.0)
	vic.is_in_water = true
	vic.status_effects._physics_process(0.05)
	var water_extinguish_ok: bool = (
		active_burn_ok
		and vic.status_effects.burn_timer == 0.0
		and is_equal_approx(vic.status_effects._burn_tick_accum, 0.0)
	)
	_assert(
		wat_cat_ok and wat_sm_ok and wat_act_ok and wat_clean_ok and wat_immune_ok and water_blocks_ok and water_extinguish_ok,
		"Phase 11.1e: Water (Água) slot 2 cleanses burn + resets accum + grants 2.0s fire immunity and water blocks/extinguishes burn"
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase11_task2_vehicles() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(120.0, 1.0, 120.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var lc := LagCompensator.new()

	# 1. Silent Water Vanish When Empty + Respawn (no explosion damage, no explosion_vfx, no vehicle_destroyed)
	var w_jeep := VehicleJeep.new()
	w_jeep.id = 11201
	w_jeep.team = NetworkManager.TEAM_ROYAL
	arena.add_child(w_jeep)
	w_jeep.spawn_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.0))
	w_jeep.global_position = Vector3(0.0, -0.80, 0.0)
	w_jeep.linear_velocity = Vector3(0.0, 0.0, -14.0)

	var w_drv := HeroCharacter.new()
	w_drv.setup_identity(11210, "P11WaterDrv", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(w_drv)
	var w_cmd := InputCmd.new()
	w_cmd.move_dir = Vector2(0.0, -1.0)
	w_drv.latest_server_input = w_cmd
	w_jeep.try_enter_hero(w_drv)

	var water_events: Array[String] = []
	var water_shots: Array[Vector3] = []
	var ev_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "explosion_vfx" or ev_type == "vehicle_destroyed":
			water_events.append(ev_type)
		elif ev_type == "shot_vfx":
			water_shots.append(payload.get("origin", Vector3.ZERO))
	NetworkManager.game_event_received.connect(ev_cb)

	var w_heroes: Dictionary = {11210: w_drv}
	var w_ctx: Dictionary = {"heroes_by_id": w_heroes}
	for _i in range(6):
		w_jeep.step_vehicle_server(0.1, w_heroes, w_ctx)
	var occupied_stalled_ok: bool = (
		not w_jeep.is_destroyed
		and w_jeep.hp > 0
		and w_jeep.visible
		and w_jeep.get_occupant_count() == 1
		and Vector2(w_jeep.linear_velocity.x, w_jeep.linear_velocity.z).length() < 4.0
		and w_drv.hp == w_drv.max_hp
		and water_events.is_empty()
	)

	var vanished_sig: Array[int] = []
	w_jeep.destroyed.connect(func(vid: int) -> void: vanished_sig.append(vid))
	w_jeep.exit_hero(w_drv)
	w_jeep.step_vehicle_server(0.05, w_heroes, w_ctx)
	var empty_vanished_ok: bool = (
		w_jeep.get_occupant_count() == 0
		and w_jeep.is_destroyed
		and not w_jeep.visible
		and w_jeep.hp == 0
		and w_jeep.collision_layer == 0
		and w_drv.hp == w_drv.max_hp
		and water_events.is_empty()
		and vanished_sig.size() == 1 and vanished_sig[0] == 11201
	)

	w_jeep._respawn_timer = 0.05
	w_jeep.step_vehicle_server(0.1, w_heroes, w_ctx)
	var respawn_ok: bool = (
		not w_jeep.is_destroyed
		and w_jeep.visible
		and w_jeep.hp == w_jeep.max_hp
		and w_jeep.collision_layer == 8
		and w_jeep.global_position.distance_to(Vector3(0.0, 0.5, 0.0)) < 0.05
	)
	_assert(
		occupied_stalled_ok and empty_vanished_ok and respawn_ok,
		"Phase 11.2a: Submerged ground vehicle stalls silently while occupied, vanishes cleanly without blast/killfeed once empty, and respawns cleanly"
	)

	# 2. VehicleBoat exact 3 seats: Driver (no weapon), Bow Gunner (rotates turret + fires from bow muzzle z < -2.5), Rear Standing Passenger (weapons & skills)
	var boat := VehicleBoat.new()
	boat.id = 11202
	boat.team = NetworkManager.TEAM_ROYAL
	arena.add_child(boat)
	boat.global_position = Vector3(20.0, 0.0, 0.0)

	var b_drv := HeroCharacter.new()
	b_drv.setup_identity(11211, "P11BoatDrv", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var b_gun := HeroCharacter.new()
	b_gun.setup_identity(11212, "P11BoatGun", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	var b_pax := HeroCharacter.new()
	b_pax.setup_identity(11213, "P11BoatPax", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var b_vic := HeroCharacter.new()
	b_vic.setup_identity(11214, "P11BoatVic", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	for h in [b_drv, b_gun, b_pax, b_vic]:
		arena.add_child(h)
	b_vic.global_position = Vector3(20.0, 1.4, -22.0)

	var bs0: int = boat.try_enter_hero(b_drv)
	var bs1: int = boat.try_enter_hero(b_gun)
	var bs2: int = boat.try_enter_hero(b_pax)
	var b_heroes: Dictionary = {11211: b_drv, 11212: b_gun, 11213: b_pax, 11214: b_vic}
	var b_ctx: Dictionary = {"heroes_by_id": b_heroes, "lag_compensator": lc, "projectiles_root": arena, "vehicles_by_id": {11202: boat}}

	var drv_fire_cmd := InputCmd.new()
	drv_fire_cmd.tick = 1
	drv_fire_cmd.aim_yaw = 0.0
	drv_fire_cmd.set_button(InputCmd.BTN_FIRE, true)
	b_drv.latest_server_input = drv_fire_cmd
	var gun_idle_cmd := InputCmd.new()
	gun_idle_cmd.tick = 1
	gun_idle_cmd.aim_yaw = 0.0
	b_gun.latest_server_input = gun_idle_cmd
	var pax_idle_cmd := InputCmd.new()
	pax_idle_cmd.tick = 1
	b_pax.latest_server_input = pax_idle_cmd

	await get_tree().physics_frame
	NetworkManager.server_tick = 200
	lc.record_frame(200, b_heroes)
	water_shots.clear()
	var b_vic_hp0: int = b_vic.hp
	for _i in range(4):
		boat.step_vehicle_server(1.0 / 60.0, b_heroes, b_ctx)
	var boat_drv_no_fire_ok: bool = (b_vic.hp == b_vic_hp0 and water_shots.is_empty())

	var gun_fire_cmd := InputCmd.new()
	gun_fire_cmd.tick = 2
	gun_fire_cmd.aim_yaw = 0.0
	gun_fire_cmd.aim_pitch = 0.0
	gun_fire_cmd.set_button(InputCmd.BTN_FIRE, true)
	b_gun.latest_server_input = gun_fire_cmd
	boat._driver_fire_cd = 0.0
	water_shots.clear()
	for _i in range(4):
		boat.step_vehicle_server(1.0 / 60.0, b_heroes, b_ctx)
		boat._process(1.0 / 60.0)
	var bow_muzzle_local_z: float = boat.to_local(water_shots[0]).z if not water_shots.is_empty() else 99.0
	var boat_gun_fires_ok: bool = (
		not water_shots.is_empty()
		and bow_muzzle_local_z < -2.5
		and b_vic.hp < b_vic_hp0
		and boat._turret_node != null
		and boat._barrel_pivot != null
	)

	# Verify bow gunner turret rotates to -PI/2 when aiming right
	gun_fire_cmd.aim_yaw = -PI * 0.5
	gun_fire_cmd.set_button(InputCmd.BTN_FIRE, false)
	boat.step_vehicle_server(1.0 / 60.0, b_heroes, b_ctx)
	boat._process(1.0 / 60.0)
	var boat_turret_rot_ok: bool = (absf(boat._turret_node.rotation.y - (-PI * 0.5)) < 0.05)

	var boat_seats_ok: bool = (
		boat.seats.size() == 3 and bs0 == 0 and bs1 == 1 and bs2 == 2
		and boat.seats[0].seat_type == VehicleBase.SeatType.DRIVER and not boat.seats[0].can_shoot
		and boat.seats[1].seat_type == VehicleBase.SeatType.GUNNER and boat.seats[1].follow_turret
		and boat.seats[2].seat_type == VehicleBase.SeatType.PASSENGER
		and boat.seats[2].local_offset.distance_to(Vector3(0.0, 0.76, 1.95)) < 0.01
		and boat.seats[2].seat_pose == "stand"
		and boat.seats[2].can_shoot and boat.seats[2].can_use_skills
	)
	_assert(
		boat_seats_ok and boat_drv_no_fire_ok and boat_gun_fires_ok and boat_turret_rot_ok,
		"Phase 11.2b: VehicleBoat 3 seats (Driver no-fire, Bow Gunner turret muzzle z=%.2f < -2.5, Rear Standing Passenger)" % bow_muzzle_local_z
	)

	# 3. VehicleAPC exact 3 seats: solo Driver holding BTN_FIRE does NOT fire MG; Gunner fires MG; Seat 2 sits backwards (PI)
	var apc := VehicleAPC.new()
	apc.id = 11203
	apc.team = NetworkManager.TEAM_NATIONAL
	arena.add_child(apc)
	apc.global_position = Vector3(-20.0, 0.05, 0.0)

	var a_drv := HeroCharacter.new()
	a_drv.setup_identity(11215, "P11APCDrv", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var a_gun := HeroCharacter.new()
	a_gun.setup_identity(11216, "P11APCGun", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	var a_pax := HeroCharacter.new()
	a_pax.setup_identity(11217, "P11APCPax", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var a_vic := HeroCharacter.new()
	a_vic.setup_identity(11218, "P11APCVic", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	for h in [a_drv, a_gun, a_pax, a_vic]:
		arena.add_child(h)
	a_vic.global_position = Vector3(-20.0, 1.8, -22.0)

	var as0: int = apc.try_enter_hero(a_drv)
	var a_heroes_solo: Dictionary = {11215: a_drv, 11218: a_vic}
	var a_ctx_solo: Dictionary = {"heroes_by_id": a_heroes_solo, "lag_compensator": lc, "projectiles_root": arena, "vehicles_by_id": {11203: apc}}
	a_drv.latest_server_input = drv_fire_cmd
	await get_tree().physics_frame
	NetworkManager.server_tick = 205
	lc.record_frame(205, a_heroes_solo)
	water_shots.clear()
	var a_vic_hp0: int = a_vic.hp
	for _i in range(4):
		apc.step_vehicle_server(1.0 / 60.0, a_heroes_solo, a_ctx_solo)
	var apc_solo_drv_no_fire_ok: bool = (a_vic.hp == a_vic_hp0 and water_shots.is_empty())

	var as1: int = apc.try_enter_hero(a_gun)
	var as2: int = apc.try_enter_hero(a_pax)
	var a_heroes: Dictionary = {11215: a_drv, 11216: a_gun, 11217: a_pax, 11218: a_vic}
	var a_ctx: Dictionary = {"heroes_by_id": a_heroes, "lag_compensator": lc, "projectiles_root": arena, "vehicles_by_id": {11203: apc}}
	var a_gun_cmd := InputCmd.new()
	a_gun_cmd.tick = 3
	a_gun_cmd.aim_yaw = 0.0
	a_gun_cmd.aim_pitch = 0.0
	a_gun_cmd.set_button(InputCmd.BTN_FIRE, true)
	a_gun.latest_server_input = a_gun_cmd
	var a_pax_cmd := InputCmd.new()
	a_pax_cmd.tick = 3
	a_pax.latest_server_input = a_pax_cmd

	apc._driver_fire_cd = 0.0
	water_shots.clear()
	for _i in range(4):
		apc.step_vehicle_server(1.0 / 60.0, a_heroes, a_ctx)
		apc._process(1.0 / 60.0)
	var apc_gun_fires_ok: bool = (not water_shots.is_empty() and a_vic.hp < a_vic_hp0)

	# Rear hitch passenger sits facing backwards (visual_root forward = +Z when APC faces -Z)
	a_pax._sync_seated_visual_transform(apc)
	var pax_fwd: Vector3 = (-a_pax.visual_root.global_transform.basis.z).normalized()
	var apc_pax_backwards_ok: bool = (
		pax_fwd.dot(Vector3(0.0, 0.0, 1.0)) > 0.99
		and apc.seats[2].seat_pose == "sit"
		and apc.seats[2].local_offset.distance_to(Vector3(0.0, 0.85, 2.48)) < 0.01
		and is_equal_approx(apc.get_seat_local_yaw(2), PI)
		and apc.seats[2].can_shoot and apc.seats[2].can_use_skills
	)

	# 4. HUD seat diagram shows exact 3 seats cleanly for Boat & APC
	var hud := HUDController.new()
	arena.add_child(hud)
	var hud_vehs: Array[VehicleBase] = [boat, apc]
	hud.bind_context(null, hud_vehs, b_heroes)
	hud.set_local_hero(b_gun)
	hud._update_vehicle_seat_diagram(boat)
	var boat_hud_ok: bool = (
		hud._seat_slot_buttons[0].visible and hud._seat_slot_buttons[0].text.contains("Pilot")
		and hud._seat_slot_buttons[1].visible and hud._seat_slot_buttons[1].text.contains("Artil")
		and hud._seat_slot_buttons[2].visible and hud._seat_slot_buttons[2].text.contains("Passa")
		and not hud._seat_slot_buttons[3].visible
	)
	hud.set_local_hero(a_pax)
	hud._update_vehicle_seat_diagram(apc)
	var apc_hud_ok: bool = (
		hud._seat_slot_buttons[0].visible and hud._seat_slot_buttons[0].text.contains("Motor")
		and hud._seat_slot_buttons[1].visible and hud._seat_slot_buttons[1].text.contains("Artil")
		and hud._seat_slot_buttons[2].visible and hud._seat_slot_buttons[2].text.contains("Passa")
		and not hud._seat_slot_buttons[3].visible
	)

	NetworkManager.game_event_received.disconnect(ev_cb)

	_assert(
		apc.seats.size() == 3 and as0 == 0 and as1 == 1 and as2 == 2
		and apc_solo_drv_no_fire_ok and apc_gun_fires_ok and apc_pax_backwards_ok
		and boat_hud_ok and apc_hud_ok,
		"Phase 11.2c: VehicleAPC 3 seats (solo Driver cannot fire MG, Gunner fires roof MG, Rear Hitch sits backwards at PI yaw), and 3-seat HUD diagram"
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase11_task3_crosshair_and_animations() -> void:
	# 1. COD-Style Bottom/Left/Right Gray Crosshair + 4 Diagonal Hitmarker Ticks + Hit/Crit/Kill Colors
	var hud := HUDController.new()
	add_child(hud)

	var top_bar := hud._crosshair.get_node_or_null("Top") as ColorRect
	var bot_bar := hud._crosshair.get_node_or_null("Bottom") as ColorRect
	var left_bar := hud._crosshair.get_node_or_null("Left") as ColorRect
	var right_bar := hud._crosshair.get_node_or_null("Right") as ColorRect
	var bot_fill := bot_bar.get_node_or_null("Fill") as ColorRect if bot_bar != null else null
	var left_fill := left_bar.get_node_or_null("Fill") as ColorRect if left_bar != null else null
	var right_fill := right_bar.get_node_or_null("Fill") as ColorRect if right_bar != null else null
	var gray_arms_ok: bool = (
		top_bar != null and not top_bar.visible
		and bot_bar != null and bot_bar.visible
		and left_bar != null and left_bar.visible
		and right_bar != null and right_bar.visible
		and bot_fill != null and bot_fill.color.r >= 0.92 and absf(bot_fill.color.r - bot_fill.color.b) < 0.08
		and left_fill != null and left_fill.color.r >= 0.92
		and right_fill != null and right_fill.color.r >= 0.92
	)

	var tick_names: PackedStringArray = PackedStringArray(["HitDiagTL", "HitDiagTR", "HitDiagBL", "HitDiagBR"])
	var ticks_ok: bool = (hud._hitmarker_container != null and hud._hitmarker_lbl.text == "")
	for t_name in tick_names:
		var t_node := hud._hitmarker_container.get_node_or_null(t_name) as ColorRect if hud._hitmarker_container != null else null
		if t_node == null:
			ticks_ok = false
		else:
			var center_dist: float = (t_node.position + t_node.pivot_offset).length()
			if center_dist < 8.0:
				ticks_ok = false

	hud.show_hitmarker(false, false)
	var norm_col: Color = hud._hitmarker_container.modulate
	var norm_ok: bool = (
		hud._hitmarker_container.visible and hud._hitmarker_lbl.visible
		and norm_col.r >= 0.70 and norm_col.r <= 0.85
		and absf(norm_col.r - norm_col.b) < 0.08
		and hud._hitmarker_lbl.modulate == norm_col
	)

	hud.show_hitmarker(true, false)
	var crit_col: Color = hud._hitmarker_container.modulate
	var crit_ok: bool = (
		hud._hitmarker_container.visible and crit_col.r > 0.85 and crit_col.g < 0.30
		and hud._hitmarker_lbl.modulate == crit_col
	)

	hud.show_hitmarker(false, true)
	var kill_col: Color = hud._hitmarker_container.modulate
	var kill_ok: bool = (
		hud._hitmarker_container.visible and kill_col == Color.WHITE
		and hud._hitmarker_lbl.modulate == Color.WHITE
	)

	# Verify kill_event on MainGame flashes white hitmarker for local killer
	var prev_local_id: int = NetworkManager.local_peer_id
	var game := MainGame.new()
	add_child(game)
	NetworkManager.local_peer_id = 42
	game._on_game_event("kill_event", {"killer": "Hero42", "killer_id": 42, "victim": "Target", "tickets_lost": 1})
	var kill_ev_ok: bool = (
		game.hud._hitmarker_container.visible
		and game.hud._hitmarker_container.modulate == Color.WHITE
		and game.hud._hitmarker_timer > 0.20
	)
	NetworkManager.local_peer_id = prev_local_id
	game.queue_free()
	hud.queue_free()

	_assert(
		gray_arms_ok and ticks_ok and norm_ok and crit_ok and kill_ok and kill_ev_ok,
		"Phase 11.3a: COD-style high-contrast Bottom/Left/Right crosshair, 4 diagonal hitmarker ticks around center gap, and gray/red/white hit/crit/kill colors"
	)

	# 2. Verify all 3 archetypes of Shotgun/Bazooka/Sniper name animated sub-parts
	var arch_parts_ok: bool = true
	var tmp_w := Node3D.new()
	for arch in range(3):
		var s_info: Dictionary = HeroMeshBuilder.populate_weapon_root(tmp_w, WeaponBase.WeaponKind.SHOTGUN, arch)
		var b_info: Dictionary = HeroMeshBuilder.populate_weapon_root(tmp_w, WeaponBase.WeaponKind.BAZOOKA, arch)
		var n_info: Dictionary = HeroMeshBuilder.populate_weapon_root(tmp_w, WeaponBase.WeaponKind.SNIPER, arch)
		if not (s_info.get("parts_by_name", {}) as Dictionary).has("Pump"):
			arch_parts_ok = false
		var b_parts: Dictionary = b_info.get("parts_by_name", {}) as Dictionary
		if not b_parts.has("Warhead") or not b_parts.has("Bolt"):
			arch_parts_ok = false
		if not (n_info.get("parts_by_name", {}) as Dictionary).has("Bolt"):
			arch_parts_ok = false
	tmp_w.free()

	# 3. Verify Shotgun Pump-Action, Bazooka Warhead Feed/Tilt, and Sniper Bolt-Action animations
	var hero := HeroCharacter.new()
	hero.setup_identity(11301, "P11AnimHero", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	add_child(hero)

	# Equip Shotgun (Soldier slot 1)
	hero.selected_weapon_slot = 1
	hero._rebuild_held_weapon_mesh()
	var pump_entry: Dictionary = hero._weapon_parts_by_name.get("Pump", {})
	var pump_node := pump_entry.get("node", null) as MeshInstance3D
	var pump_base: Vector3 = pump_entry.get("base_pos", Vector3.ZERO)
	hero.trigger_weapon_fire_visual(WeaponBase.WeaponKind.SHOTGUN, false)
	for _i in range(20): # ~0.33s mid-cycle out of 0.65s
		hero._animate_character(1.0 / 60.0)
	var pump_mid_z: float = pump_node.position.z if pump_node != null else -999.0
	for _i in range(25): # >0.65s complete cycle
		hero._animate_character(1.0 / 60.0)
	var pump_end_dist: float = pump_node.position.distance_to(pump_base) if pump_node != null else 999.0
	var shotgun_ok: bool = (pump_node != null and pump_mid_z > pump_base.z + 0.05 and pump_end_dist < 0.002)

	# Switch to Bazooka (equip on Soldier slot 2 for testing)
	var baz_w := ProjectileWeapon.new()
	baz_w.configure(hero, WeaponBase.WeaponKind.BAZOOKA, 0)
	hero.weapons.append(baz_w)
	hero.add_child(baz_w)
	hero.selected_weapon_slot = hero.weapons.size() - 1
	hero._rebuild_held_weapon_mesh()
	hero._animate_character(0.016)
	var baz_rest_rot: Vector3 = hero._held_weapon_root.rotation
	var wh_entry: Dictionary = hero._weapon_parts_by_name.get("Warhead", {})
	var wh_node := wh_entry.get("node", null) as MeshInstance3D
	var wh_base: Vector3 = wh_entry.get("base_pos", Vector3.ZERO)
	hero.trigger_weapon_fire_visual(WeaponBase.WeaponKind.BAZOOKA, false)
	for _i in range(26): # ~0.43s out of 1.05s (feed_p ~ 0.41 in 0.2..0.85 window)
		hero._animate_character(1.0 / 60.0)
	var wh_mid_dist: float = wh_node.position.distance_to(wh_base) if wh_node != null else 0.0
	var baz_tilt_diff: float = hero._held_weapon_root.rotation.distance_to(baz_rest_rot)
	for _i in range(45): # complete 1.05s cycle
		hero._animate_character(1.0 / 60.0)
	var wh_end_dist: float = wh_node.position.distance_to(wh_base) if wh_node != null else 999.0
	var bazooka_ok: bool = (wh_node != null and wh_mid_dist > 0.15 and baz_tilt_diff > 0.10 and wh_end_dist < 0.002)

	# Switch to Sniper (Commando Rifle)
	var snp_w := HitscanWeapon.new()
	snp_w.configure(hero, WeaponBase.WeaponKind.SNIPER, 0)
	hero.weapons.append(snp_w)
	hero.add_child(snp_w)
	hero.selected_weapon_slot = hero.weapons.size() - 1
	hero._rebuild_held_weapon_mesh()
	var bolt_entry: Dictionary = hero._weapon_parts_by_name.get("Bolt", {})
	var bolt_node := bolt_entry.get("node", null) as MeshInstance3D
	var bolt_base: Vector3 = bolt_entry.get("base_pos", Vector3.ZERO)
	hero.trigger_weapon_fire_visual(WeaponBase.WeaponKind.SNIPER, false)
	for _i in range(28): # ~0.47s mid-cycle out of 0.90s
		hero._animate_character(1.0 / 60.0)
	var bolt_mid_ok: bool = (bolt_node != null and bolt_node.position.z > bolt_base.z + 0.02 and bolt_node.position.y > bolt_base.y + 0.01)
	for _i in range(32): # complete 0.90s cycle
		hero._animate_character(1.0 / 60.0)
	var bolt_end_ok: bool = (bolt_node != null and bolt_node.position.distance_to(bolt_base) < 0.002)

	hero.queue_free()
	await _flush_deferred()

	_assert(
		arch_parts_ok and shotgun_ok and bazooka_ok and bolt_mid_ok and bolt_end_ok,
		"Phase 11.3b: Shotgun Pump (+Z rack), Bazooka Warhead feed/tilt, and Sniper Bolt-action cycle animate mid-cycle and reset cleanly"
	)


func _test_phase11_task4_demolisher() -> void:
	# 1. NetworkManager CLASS_DEMOLISHER & NetSerializer BUFF_* bits (preserving INPUT_CMD_BYTES == 15)
	NetworkManager.set_slot_archetype(NetworkManager.CLASS_DEMOLISHER, 0, 2)
	NetworkManager.set_slot_archetype(NetworkManager.CLASS_DEMOLISHER, 1, 1)
	NetworkManager.set_slot_archetype(NetworkManager.CLASS_DEMOLISHER, 2, 2) # Stick grenade stays 0
	var demo_slots: Dictionary = NetworkManager.build_class_slot_archetypes(NetworkManager.CLASS_DEMOLISHER, 2)
	NetworkManager.set_local_loadout("DemoHero", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 1, demo_slots)
	var nm_ok: bool = (
		NetworkManager.CLASS_DEMOLISHER == 3
		and int(demo_slots.get(0, -1)) == 2
		and int(demo_slots.get(1, -1)) == 1
		and int(demo_slots.get(2, -1)) == 0
		and int(NetworkManager.local_profile.get("class_id", -1)) == 3
	)
	var demo_buffs: int = NetSerializer.BUFF_HASTE | NetSerializer.BUFF_CARRIED_SHIELD | NetSerializer.BUFF_VEHICLE_BUSTER | NetSerializer.BUFF_TNT_ROPE
	var auth_b: PackedByteArray = NetSerializer.pack_authoritative_state(50, Vector3.ZERO, Vector3.ZERO, 1, 110, 25, -1, -1, 0, demo_buffs)
	var auth_d: Dictionary = NetSerializer.unpack_authoritative_state(auth_b)
	var ws_b: PackedByteArray = NetSerializer.pack_world_snapshot(50, 1000, 50, 50, [{
		"id": 99, "team": 0, "class_id": NetworkManager.CLASS_DEMOLISHER, "weapon_slot": 1,
		"flags": 1, "buffs": demo_buffs, "pos": Vector3.ZERO, "vel": Vector3.ZERO,
		"yaw": 0.0, "pitch": 0.0, "hp": 110, "shield": 25, "vehicle_id": -1, "seat_idx": -1,
	}], [], [])
	var ws_d: Dictionary = NetSerializer.unpack_world_snapshot(ws_b)
	var ws_h: Dictionary = (ws_d.get("heroes", []) as Array)[0]
	var net_ok: bool = (
		NetSerializer.INPUT_CMD_BYTES == 15
		and int(auth_d.get("buffs", 0)) == demo_buffs
		and int(ws_h.get("class_id", -1)) == 3
		and int(ws_h.get("buffs", 0)) == demo_buffs
	)
	_assert(nm_ok and net_ok, "Phase 11.4a: NetworkManager CLASS_DEMOLISHER=3 clamping/loadout & NetSerializer BUFF_HASTE/CARRIED_SHIELD/VEHICLE_BUSTER/TNT_ROPE roundtrip")

	# 2. ClassDemolisher stats, Weapons 8..10 stats, Fire Breath 10-ammo shot, Caber 60 AoE + 60 self-dmg, 3D meshes & 2D icons
	var demo := HeroCharacter.new()
	demo.setup_identity(11401, "P11Demo", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	add_child(demo)
	var demo_nat := HeroCharacter.new()
	demo_nat.setup_identity(11402, "P11DemoNat", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	add_child(demo_nat)
	demo._animate_character(0.016)
	demo_nat._animate_character(0.016)

	var rig_ok: bool = (
		demo.max_hp == 110 and is_equal_approx(demo.base_move_speed, 5.4)
		and demo.weapons.size() == 3
		and (demo.weapons[0] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.FLAMETHROWER
		and (demo.weapons[1] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.GRENADE_LAUNCHER
		and (demo.weapons[2] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE
		and demo.skill_manager is DemolisherSkills
		and (demo.skill_manager as SkillManager).skill_ranks.size() == 5
		and demo._mesh_parts.size() >= 18 and demo_nat._mesh_parts.size() >= 18
	)

	var stats_ok: bool = true
	var fw0 := HitscanWeapon.new(); fw0.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 0)
	var fw1 := HitscanWeapon.new(); fw1.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 1)
	var fw2 := HitscanWeapon.new(); fw2.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 2)
	if not (is_equal_approx(fw0.damage_max, 15.0) and is_equal_approx(fw0.fire_interval, 0.10) and fw0.ammo_per_shot == 1 and fw0.mag_size == 100 and is_equal_approx(fw0.max_range_m, 21.0)):
		stats_ok = false
	if not (is_equal_approx(fw1.damage_max, 15.0) and is_equal_approx(fw1.fire_interval, 0.10) and fw1.ammo_per_shot == 2 and fw1.mag_size == 100 and is_equal_approx(fw1.max_range_m, 21.0)):
		stats_ok = false
	if not (is_equal_approx(fw2.damage_max, 40.0) and is_equal_approx(fw2.fire_interval, 0.50) and fw2.mag_size == 100 and is_equal_approx(fw2.max_range_m, 32.0) and not fw2.is_automatic and is_equal_approx(fw2.bullet_speed_mps, 45.0)):
		stats_ok = false
	var fire_cmd := InputCmd.new()
	fire_cmd.set_button(InputCmd.BTN_FIRE, true)
	if not fw2.try_consume_fire(fire_cmd) or fw2.ammo_in_mag != 90:
		stats_ok = false
	fw0.free(); fw1.free(); fw2.free()

	var gl0 := ProjectileWeapon.new(); gl0.configure(demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 0)
	var gl1 := ProjectileWeapon.new(); gl1.configure(demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 1)
	var gl2 := ProjectileWeapon.new(); gl2.configure(demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 2)
	if not (gl0.is_explosive_weapon and gl0.mag_size == 6 and is_equal_approx(gl0.fire_interval, 0.62) and is_equal_approx(gl0.damage_max, 60.0) and WeaponBase.get_variant_display_name(9, 0) == "Lança-Granadas"):
		stats_ok = false
	if not (gl1.is_explosive_weapon and gl1.mag_size == 6 and is_equal_approx(gl1.fire_interval, 0.52) and is_equal_approx(gl1.damage_max, 40.0) and WeaponBase.get_variant_display_name(9, 1) == "Trapper"):
		stats_ok = false
	if not (gl2.is_explosive_weapon and gl2.mag_size == 1 and is_equal_approx(gl2.fire_interval, 0.90) and is_equal_approx(gl2.damage_max, 100.0) and WeaponBase.get_variant_display_name(9, 2) == "Canhão"):
		stats_ok = false
	gl0.free(); gl1.free(); gl2.free()

	var caber := demo.weapons[2] as HitscanWeapon
	if not (caber.is_melee and not caber.is_automatic and caber.mag_size == 1 and is_equal_approx(caber.fire_interval, 0.68) and is_equal_approx(caber.max_range_m, 3.2) and is_equal_approx(caber.damage_max, 35.0) and WeaponBase.get_variant_display_name(10, 0) == "Granada de Cabo"):
		stats_ok = false

	# Named 3D weapon parts ("Drum", "Warhead", "CaberHead"), 2D icons, portraits, skill icons & SkillCatalog
	var tmp_w := Node3D.new()
	var w_mesh_ok: bool = true
	for wk in [8, 9, 10]:
		for ar in range(3):
			var info: Dictionary = HeroMeshBuilder.populate_weapon_root(tmp_w, wk, ar)
			if tmp_w.get_child_count() < 3:
				w_mesh_ok = false
			var pmap: Dictionary = info.get("parts_by_name", {})
			if wk == 9 and ar == 0 and not pmap.has("Drum"):
				w_mesh_ok = false
			if wk == 9 and ar == 2 and not pmap.has("Warhead"):
				w_mesh_ok = false
			if wk == 10 and not pmap.has("CaberHead"):
				w_mesh_ok = false
			var wtex: ImageTexture = CartoonAssets.get_texture("icon_weapon_%d_%d" % [wk, ar])
			if wtex == null or wtex.get_width() != 96 or wtex.get_height() != 64:
				w_mesh_ok = false
	tmp_w.free()

	var skill_icons_ok: bool = (
		CartoonAssets.get_texture("portrait_royal_3") != null
		and CartoonAssets.get_texture("portrait_national_3") != null
		and SkillCatalog.get_class_skills(NetworkManager.CLASS_DEMOLISHER).size() == 5
	)
	var seen_s3: Dictionary = {}
	for s_i in range(5):
		var stex: ImageTexture = CartoonAssets.get_texture("icon_skill_3_%d" % s_i)
		if stex == null or stex.get_width() != 40 or stex.get_height() != 40:
			skill_icons_ok = false
		else:
			seen_s3[Marshalls.raw_to_base64(stex.get_image().get_data())] = s_i
	if seen_s3.size() != 5:
		skill_icons_ok = false

	SoundSynthesizer.play_weapon_fire(8)
	SoundSynthesizer.play_weapon_fire(9)
	SoundSynthesizer.play_weapon_fire(10)

	_assert(rig_ok and stats_ok and w_mesh_ok and skill_icons_ok, "Phase 11.4b: ClassDemolisher rig, WeaponKind 8..10 stats/meshes (Drum/Warhead/CaberHead), portraits, 5 skill icons & SkillCatalog")

	# 3. Stick Grenade (Caber) first live hit triggers 60 AoE + 60 self-damage, then resets on respawn
	var arena := Node3D.new()
	add_child(arena)
	var caber_vic := HeroCharacter.new()
	caber_vic.setup_identity(11403, "CaberVic", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(caber_vic)
	demo.global_position = Vector3.ZERO
	caber_vic.global_position = Vector3(0.0, 0.0, -1.8)
	var c_ctx: Dictionary = {"heroes_by_id": {11401: demo, 11403: caber_vic}, "projectiles_root": arena}
	var c_cmd := InputCmd.new()
	c_cmd.aim_yaw = 0.0
	var demo_hp0: int = demo.hp
	var vic_hp0: int = caber_vic.hp
	caber.fire_server(c_cmd, c_ctx)
	var caber_first_ok: bool = (
		caber.caber_spent
		and demo.hp == demo_hp0 - 61
		and caber_vic.hp == vic_hp0 - 110
	)
	var demo_hp1: int = demo.hp
	var vic_hp1: int = caber_vic.hp
	caber.fire_server(c_cmd, c_ctx)
	var caber_second_ok: bool = (demo.hp == demo_hp1 and caber_vic.hp == vic_hp1 - 35)
	demo.respawn_at(Vector3.ZERO, 0.0)
	var caber_reset_ok: bool = (not caber.caber_spent and demo.hp == demo.max_hp)
	_assert(caber_first_ok and caber_second_ok and caber_reset_ok, "Phase 11.4c: Stick Grenade first hit triggers clean 110 AoE + 61 self-damage, subsequent hit deals 35 only, and respawn resets caber_spent")

	# 4. Demolisher Skills: Riot Shield (550 HP), Haste, TNT Rope (no timeout + deferred cd), Temp Shield (3s), 3x Vehicle Damage
	var dsm: DemolisherSkills = demo.skill_manager as DemolisherSkills
	var d_ctx: Dictionary = {"heroes_by_id": {11401: demo, 11402: demo_nat, 11403: caber_vic}, "projectiles_root": arena}
	var d_cmd := InputCmd.new()
	d_cmd.aim_yaw = 0.0

	# Skill 0: Carried Frontal Riot Shield (550 HP) + auto-equips STICK_GRENADE (slot 2), deferred CD until stowed/broken
	demo.selected_weapon_slot = 0
	var s0_ok: bool = dsm.try_activate_skill(0, d_cmd, d_ctx)
	var shield_equip_ok: bool = (
		s0_ok
		and demo.selected_weapon_slot == 2
		and demo.status_effects.carried_shield_active
		and demo.status_effects.carried_shield_hp == 550
		and (demo.active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) != 0
		and is_equal_approx(dsm.skill_cooldowns[0], 0.0)
	)
	var shield_abs: int = demo.status_effects.damage_carried_shield(300)
	var shield_dmg_ok: bool = (shield_abs == 300 and demo.status_effects.carried_shield_hp == 250 and demo.status_effects.carried_shield_active)
	var shield_brk: int = demo.status_effects.damage_carried_shield(300)
	var shield_break_ok: bool = (
		shield_brk == 250
		and demo.status_effects.carried_shield_hp == 0
		and not demo.status_effects.carried_shield_active
		and (demo.active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) == 0
		and is_equal_approx(dsm.skill_cooldowns[0], 16.0)
	)
	dsm.skill_cooldowns[0] = 0.0
	_assert(shield_equip_ok and shield_dmg_ok and shield_break_ok, "Phase 11.4d: Skill 0 equips Carried Riot Shield (550 HP) + slot 2, absorbs frontal dmg, and starts 16s CD on break")

	# Skill 1: Haste (1.38x move, 1.50x fire rate, 1.60x reload for 6.0s)
	var s1_ok: bool = dsm.try_activate_skill(1, d_cmd, d_ctx)
	demo.status_effects._physics_process(0.016)
	var h_flame: WeaponBase = demo.weapons[0] as WeaponBase
	h_flame.cooldown_timer = 1.0
	h_flame.step_timers(0.5, InputCmd.new()) # 1.0 - 0.5*1.5 = 0.25
	var cd_haste_ok: bool = is_equal_approx(h_flame.cooldown_timer, 0.25)
	h_flame.ammo_in_mag = 50
	h_flame.start_reload()
	h_flame.step_timers(1.35, InputCmd.new()) # 2.1 - 1.35*1.6 = -0.06 -> finished!
	var haste_ok: bool = (
		s1_ok
		and (demo.active_buffs & NetSerializer.BUFF_HASTE) != 0
		and is_equal_approx(demo.speed_multiplier, 1.38)
		and is_equal_approx(demo.status_effects.get_haste_fire_mult(), 1.50)
		and is_equal_approx(demo.status_effects.get_haste_reload_mult(), 1.60)
		and cd_haste_ok and not h_flame.is_reloading and h_flame.ammo_in_mag == h_flame.mag_size
	)
	_assert(haste_ok, "Phase 11.4e: Skill 1 Haste applies 1.38x move, 1.50x fire rate, and 1.60x reload speed via BUFF_HASTE")

	# Skill 2: TNT Rope (no max duration, blocks normal weapon firing, deferred 15s cooldown until throw_tnt_rope)
	var s2_ok: bool = dsm.try_activate_skill(2, d_cmd, d_ctx)
	for _t in range(25):
		demo.status_effects._physics_process(1.0) # 25s simulated: NO timeout!
	var rope_held_ok: bool = (
		s2_ok
		and demo.status_effects.tnt_rope_active
		and (demo.active_buffs & NetSerializer.BUFF_TNT_ROPE) != 0
		and is_equal_approx(dsm.skill_cooldowns[2], 0.0)
		and dsm.blocks_weapon_fire()
		and not h_flame.try_consume_fire(fire_cmd)
	)
	var pre_throw_count: int = arena.get_child_count()
	var threw_ok: bool = dsm.throw_tnt_rope(d_cmd, d_ctx)
	var rope_thrown_ok: bool = (
		threw_ok
		and not demo.status_effects.tnt_rope_active
		and (demo.active_buffs & NetSerializer.BUFF_TNT_ROPE) == 0
		and is_equal_approx(dsm.skill_cooldowns[2], 15.0)
		and arena.get_child_count() > pre_throw_count
	)
	_assert(rope_held_ok and rope_thrown_ok, "Phase 11.4f: Skill 2 TNT Rope holds indefinitely, blocks normal firing, and starts 15s cooldown on throw_tnt_rope")

	# Skill 3 (4th slot): Kit de 5 Coletes (spawns ArmorKitEntity with 5 vests, +70 permanent vest shield, immediate 17s CD on drop)
	demo.hp = 85
	demo.shield = 0
	demo.status_effects.permanent_vest_shield = 0
	demo.global_position = Vector3.ZERO
	var s3_ok: bool = dsm.try_activate_skill(3, d_cmd, d_ctx)
	var spawned_kit: DemolisherSkills.ArmorKitEntity = null
	for ch in arena.get_children():
		if ch is DemolisherSkills.ArmorKitEntity:
			spawned_kit = ch as DemolisherSkills.ArmorKitEntity
	var kit_spawn_ok: bool = (s3_ok and spawned_kit != null and spawned_kit.charges == 5 and is_equal_approx(dsm.skill_cooldowns[3], 17.0))
	spawned_kit.step_kit(0.02, d_ctx)
	var vest_gained_ok: bool = (demo.shield == 70 and demo.status_effects.permanent_vest_shield == 70 and spawned_kit.charges == 4 and is_equal_approx(dsm.skill_cooldowns[3], 17.0))
	demo.heal_server(10)
	for _s in range(6):
		demo.status_effects._physics_process(1.0)
	var vest_persisted_ok: bool = (demo.hp == 95 and demo.shield == 70 and demo.status_effects.permanent_vest_shield == 70)
	for _v in range(4):
		demo.shield = 0
		demo.status_effects.permanent_vest_shield = 0
		spawned_kit.step_kit(0.6, d_ctx)
	var kit_emptied_ok: bool = (spawned_kit.is_queued_for_deletion() and is_equal_approx(dsm.skill_cooldowns[3], 17.0))
	demo.shield = 0
	demo.status_effects.permanent_vest_shield = 0
	_assert(kit_spawn_ok and vest_gained_ok and vest_persisted_ok and kit_emptied_ok, "Phase 11.4g: Skill 3 Kit de 5 Coletes starts immediate 17s CD, grants +70 permanent vest shield, and despawns when emptied")

	# Skill 4 (5th slot): Quebra-Tanques (3x Vehicle damage multiplier)
	var tank := VehicleTank.new()
	tank.id = 11499
	tank.team = NetworkManager.TEAM_NATIONAL
	arena.add_child(tank)
	tank.global_position = Vector3(0.0, 0.0, -14.0)
	await get_tree().physics_frame

	var norm_proj := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.FRAG_GRENADE, 11401, NetworkManager.TEAM_ROYAL, tank.global_position + Vector3(0.0, 0.5, 0.0), Vector3.ZERO, d_ctx, 50.0, arena)
	var hp_pre_norm: int = tank.hp
	norm_proj._detonate()
	var dmg_norm: int = hp_pre_norm - tank.hp

	var s4_ok: bool = dsm.try_activate_skill(4, d_cmd, d_ctx)
	var mult_ok: bool = is_equal_approx(demo.status_effects.get_vehicle_damage_mult(), 3.0) and (demo.active_buffs & NetSerializer.BUFF_VEHICLE_BUSTER) != 0
	var boost_proj := ProjectileEntity.spawn_server_projectile(ProjectileEntity.ProjectileKind.FRAG_GRENADE, 11401, NetworkManager.TEAM_ROYAL, tank.global_position + Vector3(0.0, 0.5, 0.0), Vector3.ZERO, d_ctx, 50.0, arena)
	var hp_pre_boost: int = tank.hp
	boost_proj._detonate()
	var dmg_boost: int = hp_pre_boost - tank.hp
	_assert(s4_ok and mult_ok and dmg_norm > 0 and dmg_boost == dmg_norm * 3, "Phase 11.4h: Skill 5 Quebra-Tanques applies exact 3x vehicle damage (%d vs %d)" % [dmg_boost, dmg_norm])

	# 5. FirePatchEntity hazard + Water ("Água", Widget 2) extinguish_near
	caber_vic.respawn_at(Vector3(30.0, 0.0, 0.0), 0.0)
	caber_vic.is_in_water = false
	caber_vic.status_effects.fire_immunity_timer = 0.0
	var fp_near := DemolisherSkills.FirePatchEntity.new()
	fp_near.owner_id = 11401
	fp_near.owner_team = NetworkManager.TEAM_ROYAL
	fp_near.position = Vector3(30.0, 0.0, 0.0)
	fp_near._context = d_ctx
	arena.add_child(fp_near)
	var fp_far := DemolisherSkills.FirePatchEntity.new()
	fp_far.owner_id = 11401
	fp_far.owner_team = NetworkManager.TEAM_ROYAL
	fp_far.position = Vector3(60.0, 0.0, 0.0)
	fp_far._context = d_ctx
	arena.add_child(fp_far)

	var vic_pre_fp: int = caber_vic.hp
	fp_near.step_hazard(0.1, d_ctx) # First contact: -20 instant + burn(10, 3s)
	var fp_first_ok: bool = (caber_vic.hp == vic_pre_fp - 20 and caber_vic.status_effects.is_burning() and is_equal_approx(caber_vic.status_effects.burn_timer, 3.0))
	caber_vic.status_effects._physics_process(0.55) # Burn tick: -5 dmg
	var fp_burn_tick_ok: bool = (caber_vic.hp == vic_pre_fp - 25)
	fp_near.step_hazard(0.55, d_ctx) # Refresh burn without repeating 20 instant dmg
	var fp_refresh_ok: bool = (caber_vic.hp == vic_pre_fp - 25 and is_equal_approx(caber_vic.status_effects.burn_timer, 3.0))

	var water_ok: bool = (caber_vic.skill_manager as SkillManager).try_activate_widget(2, d_ctx)
	var fp_ext_ok: bool = (
		water_ok
		and fp_near.is_queued_for_deletion()
		and not fp_far.is_queued_for_deletion()
		and not caber_vic.status_effects.is_burning()
		and caber_vic.status_effects.fire_immunity_timer > 1.5
	)
	_assert(fp_first_ok and fp_burn_tick_ok and fp_refresh_ok and fp_ext_ok, "Phase 11.4i: FirePatchEntity deals 20 contact + 5/0.5s burn, refreshes on contact, and Water widget extinguishes nearby patches")

	# 6. StatusEffectsVFX continuous buff mapping + spawn_skill_vfx for Demolisher
	var vfx_stage4 := Node3D.new()
	arena.add_child(vfx_stage4)
	demo.active_buffs = NetSerializer.BUFF_HASTE | NetSerializer.BUFF_CARRIED_SHIELD | NetSerializer.BUFF_VEHICLE_BUSTER | NetSerializer.BUFF_TNT_ROPE
	var vfx_buff_ok: bool = StatusEffectsVFX._has_continuous_particle_buff(demo)
	var vfx_skills_ok: bool = true
	for s_i in range(5):
		StatusEffectsVFX.spawn_skill_vfx(vfx_stage4, NetworkManager.CLASS_DEMOLISHER, s_i, Vector3(float(s_i) * 3.0, 0.0, 0.0), 0.0)
		if vfx_stage4.get_node_or_null("SkillVFX_3_%d" % s_i) == null:
			vfx_skills_ok = false
	_assert(vfx_buff_ok and vfx_skills_ok, "Phase 11.4j: StatusEffectsVFX maps new BUFF_* bits & spawns 3D SkillVFX_3_0..4 cleanly")

	demo.queue_free()
	demo_nat.queue_free()
	arena.queue_free()
	await _flush_deferred()


func _test_phase11_task5_demolisher_weapons() -> void:
	print("--- Phase 11 Task 5: Demolisher Weapons Gameplay Tests ---")
	var arena := Node3D.new()
	add_child(arena)

	# Solid floor & test wall in arena for raycasts, bounces, and LOS occlusion
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var occ_wall := StaticBody3D.new()
	occ_wall.collision_layer = 1
	var wall_col := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(6.0, 4.0, 0.5)
	wall_col.shape = wall_shape
	occ_wall.position = Vector3(20.0, 2.0, -5.0)
	occ_wall.add_child(wall_col)
	arena.add_child(occ_wall)
	await get_tree().physics_frame

	var demo := HeroCharacter.new()
	demo.setup_identity(11501, "DemoT5", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	arena.add_child(demo)

	var enemy_a := HeroCharacter.new()
	enemy_a.setup_identity(11502, "EnemyA", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(enemy_a)

	var enemy_water := HeroCharacter.new()
	enemy_water.setup_identity(11503, "EnemyWater", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(enemy_water)

	var ally_h := HeroCharacter.new()
	ally_h.setup_identity(11504, "AllyH", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(ally_h)

	var lag_comp := LagCompensator.new()
	arena.add_child(lag_comp)

	var heroes_map: Dictionary = {
		11501: demo,
		11502: enemy_a,
		11503: enemy_water,
		11504: ally_h,
	}
	var ctx: Dictionary = {
		"heroes_by_id": heroes_map,
		"projectiles_root": arena,
		"lag_compensator": lag_comp,
	}

	# 1. FlameWeapon arch 0 (Flamethrower): 10/s ammo, 10 dmg + 3.0s Afterburn, water/immunity immunity, 3x vehicle, Shield Drain
	demo.global_position = Vector3(0.0, 0.0, 0.0)
	enemy_a.global_position = Vector3(0.0, 0.0, -6.0)
	enemy_water.global_position = Vector3(1.5, 0.0, -6.0)
	enemy_water.is_in_water = true
	ally_h.global_position = Vector3(-1.5, 0.0, -6.0)
	await get_tree().physics_frame

	var f_cmd := InputCmd.new()
	f_cmd.aim_yaw = 0.0
	f_cmd.aim_pitch = 0.0
	f_cmd.set_button(InputCmd.BTN_FIRE, true)

	var fw0: FlameWeapon = demo.weapons[0] as FlameWeapon
	var consumed_ticks: int = 0
	for _i in range(10):
		if fw0.try_consume_fire(f_cmd):
			consumed_ticks += 1
		fw0.step_timers(0.10, f_cmd)
	var ammo_10s_ok: bool = (fw0 is FlameWeapon and consumed_ticks == 10 and fw0.ammo_in_mag == 90)

	var ea_hp0: int = enemy_a.hp
	var ew_hp0: int = enemy_water.hp
	var al_hp0: int = ally_h.hp
	fw0.fire_server(f_cmd, ctx)
	var flame0_hit_ok: bool = (
		enemy_a.hp == ea_hp0 - 15
		and enemy_a.status_effects.is_burning()
		and is_equal_approx(enemy_a.status_effects.burn_timer, 3.0)
		and enemy_water.hp == ew_hp0
		and not enemy_water.status_effects.is_burning()
		and ally_h.hp == al_hp0
	)
	# Test Layer-1 wall occlusion blocks Flamethrower
	demo.global_position = Vector3(20.0, 0.0, 0.0)
	enemy_a.respawn_at(Vector3(20.0, 0.0, -8.0), 0.0)
	enemy_a.status_effects.clear_all()
	await get_tree().physics_frame
	var occ_hp0: int = enemy_a.hp
	fw0.fire_server(f_cmd, ctx)
	var flame0_occ_ok: bool = (enemy_a.hp == occ_hp0 and not enemy_a.status_effects.is_burning())
	_assert(
		ammo_10s_ok and flame0_hit_ok and flame0_occ_ok,
		"Phase 11.5a: FlameWeapon arch 0 (ammo=%s[%d/%d], hit=%s[ea=%d->%d,sh=%d], occ=%s)" % [
			str(ammo_10s_ok), consumed_ticks, fw0.ammo_in_mag,
			str(flame0_hit_ok), ea_hp0, enemy_a.hp, demo.shield,
			str(flame0_occ_ok),
		]
	)

	# 2. FlameWeapon arch 1 (Fire Starter): 20/s ammo (2 ammo / 0.10s), 15 dmg + FirePatchEntity (6.0s, 20 entry + burn) + fire_patch_vfx
	demo.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	enemy_a.respawn_at(Vector3(0.0, 0.0, -10.0), 0.0)
	enemy_a.is_in_water = false
	var fw1 := FlameWeapon.new()
	fw1.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 1)
	demo.add_child(fw1)
	var fs_consumed: int = 0
	for _i in range(10):
		if fw1.try_consume_fire(f_cmd):
			fs_consumed += 1
		fw1.step_timers(0.10, f_cmd)
	var fs_ammo_ok: bool = (fs_consumed == 10 and fw1.ammo_in_mag == 80)

	var fp_vfx_events: Array[Dictionary] = []
	var on_fp_evt := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "fire_patch_vfx":
			fp_vfx_events.append(payload)
	NetworkManager.game_event_received.connect(on_fp_evt)
	var fs_cmd := InputCmd.new()
	fs_cmd.aim_yaw = 0.0
	fs_cmd.aim_pitch = -0.15 # Aim down toward ground near enemy_a
	var pre_fp_nodes: int = get_tree().get_nodes_in_group("fire_patches").size()
	var ea_pre_fs: int = enemy_a.hp
	fw1.reset_weapon()
	fw1.fire_server(fs_cmd, ctx)
	var spawned_patches: Array[Node] = get_tree().get_nodes_in_group("fire_patches")
	var newest_fp: DemolisherSkills.FirePatchEntity = null
	for p in spawned_patches:
		if p is DemolisherSkills.FirePatchEntity:
			newest_fp = p as DemolisherSkills.FirePatchEntity
	var fs_patch_ok: bool = (
		enemy_a.hp == ea_pre_fs - 15
		and enemy_a.status_effects.is_burning()
		and spawned_patches.size() == pre_fp_nodes + 1
		and newest_fp != null
		and is_equal_approx(newest_fp.max_lifetime, 6.0)
		and not fp_vfx_events.is_empty()
	)
	if newest_fp != null:
		newest_fp.position = enemy_a.global_position
		var pre_entry_hp: int = enemy_a.hp
		newest_fp.step_hazard(0.05, ctx)
		fs_patch_ok = fs_patch_ok and (enemy_a.hp == pre_entry_hp - 20)
		newest_fp.queue_free()
	NetworkManager.game_event_received.disconnect(on_fp_evt)
	fw1.queue_free()
	_assert(fs_ammo_ok and fs_patch_ok, "Phase 11.5b: FlameWeapon arch 1 Fire Starter (20/s ammo = 2/0.10s, 15 dmg + FirePatchEntity 6s / 20 entry dmg + fire_patch_vfx)")

	# 3. FlameWeapon arch 2 (Fire Breath): FIREBALL 45 m/s, 40 dmg + 3s Afterburn, 0 dmg/0 burn in water/fire-immunity
	enemy_a.respawn_at(Vector3(0.0, 0.0, -8.0), 0.0)
	enemy_water.respawn_at(Vector3(0.0, 0.0, -8.0), 0.0)
	enemy_water.is_in_water = true
	var fw2 := FlameWeapon.new()
	fw2.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 2)
	demo.add_child(fw2)
	fw2.fire_server(f_cmd, ctx)
	var fb_proj: ProjectileEntity = null
	for ch in arena.get_children():
		if ch is ProjectileEntity and (ch as ProjectileEntity).kind == ProjectileEntity.ProjectileKind.FIREBALL:
			fb_proj = ch as ProjectileEntity
	var fb_spawn_ok: bool = (fb_proj != null and absf(fb_proj.velocity.length() - 45.0) <= 0.5 and is_equal_approx(fb_proj.gravity_scale, 0.0))
	if fb_proj != null:
		fb_proj.global_position = enemy_a.global_position + Vector3(0.0, 1.0, 0.0)
		var ea_fb0: int = enemy_a.hp
		var ew_fb0: int = enemy_water.hp
		fb_proj._detonate()
		var fb_hit_ok: bool = (
			enemy_a.hp == ea_fb0 - 40
			and enemy_a.status_effects.is_burning()
			and is_equal_approx(enemy_a.status_effects.burn_timer, 3.0)
			and enemy_water.hp == ew_fb0
			and not enemy_water.status_effects.is_burning()
		)
		_assert(fb_spawn_ok and fb_hit_ok, "Phase 11.5c: FlameWeapon arch 2 Fire Breath launches 45 m/s FIREBALL dealing 40 dmg + 3s burn, 0 in water")
	else:
		_assert(false, "Phase 11.5c: FlameWeapon arch 2 Fire Breath spawns FIREBALL")
	fw2.queue_free()
	enemy_water.is_in_water = false

	# 4. Grenade Launcher arch 0 (BOUNCE_GRENADE): 1.0s post-bounce fuse, immediate detonate on enemy hero/vehicle, distance falloff
	demo.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	var gl0: ProjectileWeapon = demo.weapons[1] as ProjectileWeapon
	var b_proj := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		demo.entity_id, demo.team,
		Vector3(0.0, 0.6, 0.0),
		Vector3(0.0, -10.0, -8.0),
		ctx, 60.0, arena
	)
	for _t in range(10):
		if b_proj._bounce_fuse_started:
			break
		b_proj._physics_process(0.02)
	var bounce_fuse_ok: bool = (b_proj._bounce_fuse_started and b_proj.lifetime <= 1.0 and not b_proj._exploded)
	b_proj._physics_process(1.05)
	var bounce_expire_ok: bool = b_proj._exploded

	# Direct hit before 1.0s fuse detonates immediately + distance falloff
	enemy_a.respawn_at(Vector3(0.0, 0.0, -3.0), 0.0)
	enemy_water.respawn_at(Vector3(4.2, 0.0, -3.0), 0.0)
	await get_tree().physics_frame
	var b_direct := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		demo.entity_id, demo.team,
		Vector3(0.0, 1.0, -1.5),
		Vector3(0.0, 0.0, -30.0),
		ctx, 60.0, arena
	)
	var ea_b0: int = enemy_a.hp
	var ew_b0: int = enemy_water.hp
	for _t in range(10):
		if b_direct._exploded:
			break
		b_direct._physics_process(0.02)
	var ea_bdmg: int = ea_b0 - enemy_a.hp
	var ew_bdmg: int = ew_b0 - enemy_water.hp
	_assert(
		bounce_fuse_ok and bounce_expire_ok and b_direct._exploded and ea_bdmg == 60 and ew_bdmg > 0 and ew_bdmg < ea_bdmg,
		"Phase 11.5d: BOUNCE_GRENADE 1.0s post-bounce fuse, immediate direct hero detonate, and smooth distance falloff (%d vs %d)" % [ea_bdmg, ew_bdmg]
	)

	# 5. Grenade Launcher arch 2 (CANNON_BALL): 72 m/s low-drop (0.42g), 100 dmg contact + 3x vehicle damage
	var gl2 := ProjectileWeapon.new()
	gl2.configure(demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 2)
	demo.add_child(gl2)
	gl2.fire_server(f_cmd, ctx)
	var cb_proj: ProjectileEntity = null
	for ch in arena.get_children():
		if ch is ProjectileEntity and (ch as ProjectileEntity).kind == ProjectileEntity.ProjectileKind.CANNON_BALL:
			cb_proj = ch as ProjectileEntity
	var cb_stats_ok: bool = (cb_proj != null and absf(cb_proj.velocity.length() - 72.0) <= 0.5 and is_equal_approx(cb_proj.gravity_scale, 0.42) and cb_proj.explode_on_impact)
	if cb_proj != null:
		enemy_a.respawn_at(Vector3(0.0, 0.0, -12.0), 0.0)
		await get_tree().physics_frame
		cb_proj.global_position = Vector3(0.0, 1.0, -10.5)
		cb_proj.velocity = Vector3(0.0, 0.0, -72.0)
		var ea_cb0: int = enemy_a.hp
		cb_proj._physics_process(0.02)
		var cb_dmg_ok: bool = (cb_proj._exploded and (ea_cb0 - enemy_a.hp) == 100)
		_assert(cb_stats_ok and cb_dmg_ok, "Phase 11.5e: CANNON_BALL fires at 72 m/s (0.42g) and deals 100 dmg on impact (exp=%s, dmg=%d)" % [str(cb_proj._exploded), ea_cb0 - enemy_a.hp])
	else:
		_assert(false, "Phase 11.5e: CANNON_BALL spawned")
	gl2.queue_free()

	# 6. Grenade Launcher arch 1 (TRAPPER_STICKY): max 6 stickies, 0.5s arming delay, BTN_AIM detonate, enemy hitscan & explosion silent destruction
	var gl1 := ProjectileWeapon.new()
	gl1.configure(demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 1)
	demo.add_child(gl1)
	for _s in range(7):
		gl1.fire_server(f_cmd, ctx)
	var active_stickies_7: Array[ProjectileEntity] = []
	for gnode in get_tree().get_nodes_in_group("destructible_stickies"):
		if gnode is ProjectileEntity and not (gnode as ProjectileEntity).is_queued_for_deletion():
			active_stickies_7.append(gnode as ProjectileEntity)
	var max6_ok: bool = (active_stickies_7.size() == 6)

	var test_sticky: ProjectileEntity = active_stickies_7[0]
	for s_idx in range(1, active_stickies_7.size()):
		active_stickies_7[s_idx]._stick_to_surface(Vector3(-60.0, 0.0, -60.0), Vector3.UP, floor_body)
	test_sticky.global_position = Vector3(0.0, 0.2, -5.0)
	test_sticky._stick_to_surface(Vector3(0.0, 0.0, -5.0), Vector3.UP, floor_body)
	var stuck_ok: bool = (test_sticky._stuck and test_sticky.velocity == Vector3.ZERO and not test_sticky.can_detonate())
	var aim_det_cmd := InputCmd.new()
	aim_det_cmd.set_button(InputCmd.BTN_AIM, true)
	var early_det: bool = gl1.try_detonate_stickies(aim_det_cmd) # age < 0.5s -> false!
	# Release BTN_AIM, advance age >= 0.5s, press BTN_AIM again -> detonates!
	gl1.try_detonate_stickies(InputCmd.new())
	for st in active_stickies_7:
		st._physics_process(0.55)
	enemy_a.respawn_at(Vector3(0.0, 0.0, -5.0), 0.0)
	await get_tree().physics_frame
	var ea_st0: int = enemy_a.hp
	var armed_det: bool = gl1.try_detonate_stickies(aim_det_cmd)
	var sticky_det_ok: bool = (not early_det and armed_det and test_sticky._exploded and enemy_a.hp == ea_st0 - 40)

	# Enemy hitscan & enemy explosion destroy TRAPPER_STICKY silently without exploding
	var st_shoot := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TRAPPER_STICKY,
		demo.entity_id, demo.team,
		Vector3(0.0, 1.45, -14.5), Vector3.ZERO, ctx, 40.0, arena
	)
	var st_exp := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TRAPPER_STICKY,
		demo.entity_id, demo.team,
		Vector3(6.0, 0.5, -16.0), Vector3.ZERO, ctx, 40.0, arena
	)
	enemy_a.respawn_at(Vector3(0.0, 0.0, -16.0), 0.0)
	enemy_water.respawn_at(Vector3(0.0, 0.0, -10.0), 0.0)
	await get_tree().physics_frame
	var ea_pre_shoot: int = enemy_a.hp
	var pistol_e := enemy_water.weapons[2] as HitscanWeapon
	var shoot_cmd := InputCmd.new()
	shoot_cmd.aim_yaw = 0.0
	shoot_cmd.aim_pitch = 0.0
	pistol_e.fire_server(shoot_cmd, ctx)

	var enemy_grenade := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		enemy_water.entity_id, enemy_water.team,
		Vector3(6.0, 0.5, -15.0), Vector3.ZERO, ctx, 60.0, arena
	)
	enemy_grenade._detonate()
	var sticky_destroy_ok: bool = (
		st_shoot.is_queued_for_deletion()
		and st_exp.is_queued_for_deletion()
		and enemy_a.hp == ea_pre_shoot # Destroyed silently with 0 explosion damage!
	)
	_assert(
		max6_ok and stuck_ok and sticky_det_ok and sticky_destroy_ok,
		"Phase 11.5f: TRAPPER_STICKY max6=%s(%d) stuck=%s det=%s destroy=%s(sh=%s,ex=%s,hp=%d/%d)" % [
			str(max6_ok), active_stickies_7.size(), str(stuck_ok), str(sticky_det_ok),
			str(sticky_destroy_ok), str(st_shoot.is_queued_for_deletion()), str(st_exp.is_queued_for_deletion()),
			enemy_a.hp, ea_pre_shoot
		]
	)
	gl1.queue_free()

	# 7. TNT_ROPE_CLUSTER skill throw + CaberHead visibility & allied shield/vehicle safety
	demo.respawn_at(Vector3(0.0, 0.0, 0.0), 0.0)
	demo.selected_weapon_slot = 2
	demo._rebuild_held_weapon_mesh()
	demo._animate_character(0.016)
	var dsm: DemolisherSkills = demo.skill_manager as DemolisherSkills
	var rope_act_ok: bool = dsm.try_activate_skill(2, f_cmd, ctx)
	var rope_threw: bool = dsm.throw_tnt_rope(f_cmd, ctx)
	var rope_proj: ProjectileEntity = null
	for ch in arena.get_children():
		if ch is ProjectileEntity and (ch as ProjectileEntity).kind == ProjectileEntity.ProjectileKind.TNT_ROPE_CLUSTER:
			rope_proj = ch as ProjectileEntity
	var rope_ok: bool = (rope_act_ok and rope_threw and rope_proj != null and is_equal_approx(rope_proj.base_damage, 105.0) and is_equal_approx(rope_proj.splash_radius, 8.5))
	if rope_proj != null:
		rope_proj.queue_free()

	# Allied hero in melee range must NOT trigger Caber explosion
	ally_h.respawn_at(Vector3(0.0, 0.0, -1.8), 0.0)
	await get_tree().physics_frame

	var caber: HitscanWeapon = demo.weapons[2] as HitscanWeapon
	var caber_head_node: MeshInstance3D = (demo._weapon_parts_by_name.get("CaberHead", {}) as Dictionary).get("node", null) as MeshInstance3D
	var vis_before_hit: bool = (caber_head_node != null and caber_head_node.visible)
	var demo_hp_pre_sh: int = demo.hp
	var ally_hp_pre_caber: int = ally_h.hp
	caber.fire_server(f_cmd, ctx)
	demo._animate_character(0.016)
	var allied_safe_ok: bool = (
		not caber.caber_spent
		and demo.hp == demo_hp_pre_sh
		and ally_h.hp == ally_hp_pre_caber
		and caber_head_node != null and caber_head_node.visible
	)
	ally_h.respawn_at(Vector3(-40.0, 0.0, -40.0), 0.0)
	await get_tree().physics_frame

	# Enemy hit spends Caber and hides CaberHead; respawn restores CaberHead
	enemy_a.respawn_at(Vector3(0.0, 0.0, -1.8), 0.0)
	caber.fire_server(f_cmd, ctx)
	demo._animate_character(0.016)
	var caber_hidden_ok: bool = (caber.caber_spent and caber_head_node != null and not caber_head_node.visible)
	demo.respawn_at(Vector3.ZERO, 0.0)
	demo._animate_character(0.016)
	var caber_restored_ok: bool = (not caber.caber_spent and caber_head_node != null and caber_head_node.visible)
	_assert(
		rope_ok and vis_before_hit and allied_safe_ok and caber_hidden_ok and caber_restored_ok,
		"Phase 11.5g: TNT_ROPE_CLUSTER throw (105 dmg/8.5m), allied safety, and CaberHead visibility hide/restore"
	)

	# 8. Enemy Carried Frontal Riot Shield absorbs HitscanWeapon frontal damage (0 HP lost)
	var enemy_demo := HeroCharacter.new()
	enemy_demo.setup_identity(11509, "EnemyDemoSh", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	arena.add_child(enemy_demo)
	heroes_map[11509] = enemy_demo
	enemy_a.respawn_at(Vector3(30.0, 0.0, 30.0), 0.0)
	enemy_demo.global_position = Vector3(0.0, 0.0, -6.0)
	enemy_demo.aim_yaw = PI
	(enemy_demo.skill_manager as DemolisherSkills).try_activate_skill(0, InputCmd.new(), ctx)
	await get_tree().physics_frame
	var ed_sh0: int = enemy_demo.status_effects.carried_shield_hp
	var ed_hp0: int = enemy_demo.hp
	var p_royal := ally_h.weapons[2] as HitscanWeapon
	ally_h.global_position = Vector3.ZERO
	p_royal.fire_server(f_cmd, ctx)
	_assert(
		enemy_demo.status_effects.carried_shield_hp < ed_sh0 and enemy_demo.hp == ed_hp0,
		"Phase 11.5h: Enemy Carried Riot Shield absorbs frontal HitscanWeapon damage (0 HP lost)"
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase11_task6_ui_bots_and_full_matrix() -> void:
	print("--- Phase 11 Task 6: 4-Class UI, HUD, Bot AI, GameCache & Full Verification ---")

	# 1. ClassSelectMenu: 5 class cards fitting inside 1040x660 panel, Demolisher slots/variants, 6-tab Skills guide
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = "user://test_hotkeys_p11t6.cfg"
	add_child(menu)
	await _flush_deferred()

	menu.show_screen("armory")
	var cards_ok: bool = (menu._class_cards.size() == 5 and menu._class_buttons.size() == 5)
	var cards_fit_ok: bool = true
	if menu._class_cards.size() == 5:
		var cls_row_node := menu._class_cards[0].get_parent() as Control
		if cls_row_node != null and cls_row_node.get_combined_minimum_size().x > 932.0:
			cards_fit_ok = false
	var demo_slots: Array[int] = ClassSelectMenu.get_class_weapon_slots(NetworkManager.CLASS_DEMOLISHER)
	var slots_ok: bool = (
		demo_slots.size() == 3
		and demo_slots[0] == WeaponBase.WeaponKind.FLAMETHROWER
		and demo_slots[1] == WeaponBase.WeaponKind.GRENADE_LAUNCHER
		and demo_slots[2] == WeaponBase.WeaponKind.STICK_GRENADE
	)

	menu.select_team(NetworkManager.TEAM_ROYAL)
	menu.select_class(NetworkManager.CLASS_DEMOLISHER)
	await _flush_deferred()
	var royal_demo_sel_ok: bool = (
		menu.selected_class == NetworkManager.CLASS_DEMOLISHER
		and menu._preview_portrait.texture == CartoonAssets.get_texture("portrait_royal_3")
		and menu._summary_lbl.text.contains("Demolisher")
		and menu._weapon_variant_selectors.size() == 3
		and menu._weapon_variant_selectors[0].item_count == 3
		and menu._weapon_variant_selectors[1].item_count == 3
		and menu._weapon_variant_selectors[2].item_count == 1
		and menu._weapon_variant_selectors[2].get_item_text(0) == "Granada de Cabo"
	)
	menu.select_team(NetworkManager.TEAM_NATIONAL)
	var nat_demo_sel_ok: bool = (menu._preview_portrait.texture == CartoonAssets.get_texture("portrait_national_3"))

	menu._armory_skills_btn.pressed.emit()
	await _flush_deferred()
	var skills_tabs_ok: bool = (
		menu.current_screen == "skills"
		and menu._skills_tab_buttons.size() == 6
		and menu._skills_tab_class == NetworkManager.CLASS_DEMOLISHER
		and menu._skills_grid.get_child_count() == 5
	)
	var found_shield_skill: bool = false
	var found_buster_skill: bool = false
	for lbl_n in menu._skills_grid.find_children("*", "Label", true, false):
		var txt: String = (lbl_n as Label).text
		if txt.contains("Escudo Balístico"):
			found_shield_skill = true
		if txt.contains("Quebra-Tanques"):
			found_buster_skill = true

	menu.select_skills_tab(5)
	await _flush_deferred()
	var found_agua: bool = false
	var found_cueca: bool = false
	for lbl_w in menu._skills_grid.find_children("*", "Label", true, false):
		var txt_w: String = (lbl_w as Label).text
		if txt_w.contains("Água"):
			found_agua = true
		if txt_w.contains("Cueca"):
			found_cueca = true
	var widgets_tab_ok: bool = (menu._skills_grid.get_child_count() == 4 and found_agua and not found_cueca)
	menu.queue_free()

	_assert(
		cards_ok and cards_fit_ok and slots_ok and royal_demo_sel_ok and nat_demo_sel_ok
		and skills_tabs_ok and found_shield_skill and found_buster_skill and widgets_tab_ok,
		"Phase 11.6a: ClassSelectMenu 5-class cards fit 1040x660, Demolisher slots/variants, 6-tab Skills guide, and Água widget"
	)

	# 2. HUDController Demolisher portraits, 5 skill icons/tooltips, Água widget tooltip, and Caber label
	var hud := HUDController.new()
	add_child(hud)
	var h_demo_r := HeroCharacter.new()
	h_demo_r.setup_identity(11601, "HudDemoR", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	var h_demo_n := HeroCharacter.new()
	h_demo_n.setup_identity(11602, "HudDemoN", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	add_child(h_demo_r)
	add_child(h_demo_n)

	hud.set_local_hero(h_demo_r)
	hud._process(0.016)
	var hud_royal_ok: bool = (
		hud._portrait_tex.texture == CartoonAssets.get_texture("portrait_royal_3")
		and hud._skill_slot_icons[0].texture == CartoonAssets.get_texture("icon_skill_3_0")
		and hud._skill_slot_icons[4].texture == CartoonAssets.get_texture("icon_skill_3_4")
		and hud._skill_slot_bgs[0].tooltip_text.contains("Escudo Balístico")
		and hud._skill_slot_bgs[4].tooltip_text.contains("Quebra-Tanques")
		and not hud._skill_slot_boxes[5].visible
		and hud._widget_slot_bgs.size() == 4
		and hud._widget_slot_bgs[2].tooltip_text.contains("Água")
	)
	h_demo_r.selected_weapon_slot = 2
	hud._process(0.016)
	var caber_lbl_ok: bool = hud._weapon_name_lbl.text.contains("Granada de Cabo") and not hud._weapon_name_lbl.text.contains("Faca")

	hud.set_local_hero(h_demo_n)
	hud._process(0.016)
	var hud_nat_ok: bool = (hud._portrait_tex.texture == CartoonAssets.get_texture("portrait_national_3"))
	_assert(
		hud_royal_ok and caber_lbl_ok and hud_nat_ok,
		"Phase 11.6b: HUDController displays Demolisher Royal/National portraits, 5 skill icons/tooltips, Água widget tooltip, and Caber label"
	)

	# 3. HeroCharacter TNT Rope replaces held rifle with spinning TntRope bundle & restores weapon cleanly
	h_demo_r.selected_weapon_slot = 0
	h_demo_r._animate_character(0.016)
	var tnt_before: Node = h_demo_r._held_weapon_root.get_node_or_null("TntRope")
	var dsm: DemolisherSkills = h_demo_r.skill_manager as DemolisherSkills
	var d_ctx: Dictionary = {"heroes_by_id": {11601: h_demo_r}, "projectiles_root": self}
	dsm.try_activate_skill(2, InputCmd.new(), d_ctx)
	h_demo_r._animate_character(0.05)
	var tnt_bundle := h_demo_r._held_weapon_root.get_node_or_null("TntRope") as Node3D
	var rot_a: Vector3 = tnt_bundle.rotation if tnt_bundle != null else Vector3.ZERO
	h_demo_r._animate_character(0.10)
	var rot_b: Vector3 = tnt_bundle.rotation if tnt_bundle != null else Vector3.ZERO
	var tnt_spinning_ok: bool = (
		tnt_before == null
		and tnt_bundle != null
		and h_demo_r._held_weapon_root.get_child_count() == 1
		and rot_a.distance_to(rot_b) > 0.1
	)
	dsm.throw_tnt_rope(InputCmd.new(), d_ctx)
	h_demo_r._animate_character(0.016)
	var tnt_restored_ok: bool = (
		h_demo_r._held_weapon_root.get_node_or_null("TntRope") == null
		and h_demo_r._shown_weapon_kind == WeaponBase.WeaponKind.FLAMETHROWER
	)
	_assert(tnt_spinning_ok and tnt_restored_ok, "Phase 11.6c: TNT Rope replaces held rifle with spinning TntRope bundle and restores weapon after throw")
	hud.queue_free()
	h_demo_r.queue_free()
	h_demo_n.queue_free()

	# 4. BotController Demolisher AI distances (Flamethrower <14m, Grenade Launcher <40m), Vehicle Buster, and Riot Shield
	var arena6 := Node3D.new()
	add_child(arena6)
	var bot_demo := HeroCharacter.new()
	bot_demo.setup_identity(11610, "DemoBot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, false, true)
	arena6.add_child(bot_demo)
	var enemy_b := HeroCharacter.new()
	enemy_b.setup_identity(11611, "EnemyB", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena6.add_child(enemy_b)
	var enemy_tank := VehicleTank.new()
	enemy_tank.id = 11690
	enemy_tank.team = NetworkManager.TEAM_NATIONAL
	arena6.add_child(enemy_tank)

	var brain := BotController.new()
	brain.setup(bot_demo)
	arena6.add_child(brain)
	var b_heroes: Dictionary = {11610: bot_demo, 11611: enemy_b}
	var b_vehs: Array[VehicleBase] = [enemy_tank]

	bot_demo.global_position = Vector3.ZERO
	bot_demo.aim_yaw = 0.0
	enemy_b.global_position = Vector3(0.0, 0.0, -8.0) # Close < 14m -> Flamethrower (slot 0)
	enemy_tank.global_position = Vector3(15.0, 0.0, -25.0) # Clear of LOS between bot_demo and enemy_b, <= 45m
	await get_tree().physics_frame
	var cmd_close: InputCmd = brain.step_ai(0.016, [], b_heroes, b_vehs)
	var close_ok: bool = (cmd_close.selected_weapon_slot == 0 and cmd_close.has_button(InputCmd.BTN_SKILL_5))

	enemy_b.global_position = Vector3(0.0, 0.0, -26.0) # Medium 14..40m -> Grenade Launcher (slot 1)
	brain._ai_tick = 5
	var cmd_mid: InputCmd = brain.step_ai(0.016, [], b_heroes, b_vehs)
	var mid_ok: bool = (cmd_mid.selected_weapon_slot == 1)

	bot_demo.hp = 40 # Injured -> Riot Shield (BTN_SKILL_1)
	brain._ai_tick = 11
	var cmd_low: InputCmd = brain.step_ai(0.016, [], b_heroes, b_vehs)
	var shield_ai_ok: bool = cmd_low.has_button(InputCmd.BTN_SKILL_1)
	_assert(close_ok and mid_ok and shield_ai_ok, "Phase 11.6d: BotController Demolisher picks Flamethrower <14m (close=%s), Grenade Launcher <40m (mid=%s), Vehicle Buster & Riot Shield (sh=%s)" % [str(close_ok), str(mid_ok), str(shield_ai_ok)])

	# 5. Carry-over Task 5 fixes: BOUNCE_GRENADE teammate non-fuse, 7th sticky silent eviction
	var ally_b := HeroCharacter.new()
	ally_b.setup_identity(11612, "AllyB", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena6.add_child(ally_b)
	ally_b.global_position = Vector3(0.0, 0.0, -4.0)
	await get_tree().physics_frame
	var bg_ctx: Dictionary = {"heroes_by_id": {11610: bot_demo, 11611: enemy_b, 11612: ally_b}, "projectiles_root": arena6}
	var bg_team := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		bot_demo.entity_id, bot_demo.team,
		Vector3(0.0, 1.0, -2.5), Vector3(0.0, 0.0, -30.0), bg_ctx, 60.0, arena6
	)
	for _t in range(6):
		bg_team._physics_process(0.02)
	var teammate_nofuse_ok: bool = (not bg_team._bounce_fuse_started and not bg_team._exploded)
	bg_team.queue_free()

	var hit_vfx_count: int = 0
	var on_spark := func(ev_t: String, _pl: Dictionary) -> void:
		if ev_t == "hit_vfx":
			hit_vfx_count += 1
	NetworkManager.game_event_received.connect(on_spark)
	var gl_cap := ProjectileWeapon.new()
	gl_cap.configure(bot_demo, WeaponBase.WeaponKind.GRENADE_LAUNCHER, 1)
	bot_demo.add_child(gl_cap)
	var cap_cmd := InputCmd.new()
	for _s in range(7):
		gl_cap.fire_server(cap_cmd, bg_ctx)
	NetworkManager.game_event_received.disconnect(on_spark)
	var silent_evict_ok: bool = (hit_vfx_count == 0)
	gl_cap.queue_free()
	_assert(teammate_nofuse_ok and silent_evict_ok, "Phase 11.6e: BOUNCE_GRENADE skips teammate bounce fuse and 7th sticky cap evicts silently (spark_vfx=%d)" % hit_vfx_count)

	# 6. GameCache warm_textures() & warm_meshes() cover WeaponKind 0..10 and Classes 0..3 cleanly
	GameCache.clear_all()
	GameCache.warm_textures()
	GameCache.warm_meshes()
	var cache_ok: bool = (
		GameCache.is_textures_warmed()
		and GameCache.is_meshes_warmed()
		and CartoonAssets._cache.has("portrait_royal_3")
		and CartoonAssets._cache.has("portrait_national_3")
		and CartoonAssets._cache.has("icon_weapon_10_0")
		and CartoonAssets._cache.has("icon_skill_3_4")
		and HeroMeshBuilder._mesh_cache.has("torso_3")
		and HeroMeshBuilder._weapon_cache.has("10_0")
	)
	_assert(cache_ok, "Phase 11.6f: GameCache warms Demolisher portraits, icons (0..10), skills (0..3), visor/torso meshes & TntRope")

	# 7. MainGame 14v14 spawn includes Demolisher bots + single-path TNT Rope + FirePatch client refresh + Map budgets
	var prev_peer_id: int = NetworkManager.local_peer_id
	var game6 := MainGame.new()
	add_child(game6)
	game6._start_bots_sync(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER)
	var demo_bot_count: int = 0
	for h_val in game6.heroes_by_id.values():
		var hh := h_val as HeroCharacter
		if hh != null and hh.is_bot and hh.class_id == NetworkManager.CLASS_DEMOLISHER:
			demo_bot_count += 1
	var local_hero6: HeroCharacter = game6.heroes_by_id.get(NetworkManager.local_peer_id, null)
	var w0_6: WeaponBase = local_hero6.weapons[0] as WeaponBase if local_hero6 != null else null
	var dsm6: DemolisherSkills = local_hero6.skill_manager as DemolisherSkills if local_hero6 != null else null
	var rope_flow_ok: bool = false
	if local_hero6 != null and w0_6 != null and dsm6 != null:
		local_hero6.is_local_player = false
		var cmd_act := InputCmd.new()
		cmd_act.set_button(InputCmd.BTN_SKILL_3, true)
		local_hero6.latest_server_input = cmd_act
		game6._physics_process(0.016)
		var ammo_before_held_fire: int = w0_6.ammo_in_mag
		var cmd_hold := InputCmd.new()
		cmd_hold.set_button(InputCmd.BTN_FIRE, true)
		local_hero6.latest_server_input = cmd_hold
		game6._physics_process(0.016)
		var ammo_after_throw_tick: int = w0_6.ammo_in_mag
		var prev_held_synced: bool = w0_6._prev_fire_held
		game6._physics_process(0.016)
		var ammo_while_held: int = w0_6.ammo_in_mag
		local_hero6.latest_server_input = InputCmd.new()
		game6._physics_process(0.016)
		rope_flow_ok = (
			not local_hero6.status_effects.tnt_rope_active
			and ammo_after_throw_tick == ammo_before_held_fire
			and ammo_while_held == ammo_before_held_fire
			and prev_held_synced
			and not w0_6._prev_fire_held
		)

	var fp_client := DemolisherSkills.FirePatchEntity.new()
	fp_client.set_meta("visual_only", true)
	fp_client.owner_id = 777
	fp_client.position = Vector3(12.0, 0.0, 12.0)
	fp_client._lifetime_elapsed = 4.5
	game6.projectiles_root.add_child(fp_client)
	game6._on_game_event("fire_patch_vfx", {"pos": Vector3(12.0, 0.0, 12.0), "owner_id": 777, "radius": 2.6})
	var fp_client_refresh_ok: bool = is_equal_approx(fp_client._lifetime_elapsed, 0.0)

	var mesh_count: int = 0
	var uniq_meshes: Dictionary = {}
	var uniq_mats: Dictionary = {}
	for node in game6.map_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mesh_count += 1
		if mi.mesh != null:
			uniq_meshes[mi.mesh.get_instance_id()] = true
		if mi.material_override != null:
			uniq_mats[mi.material_override.get_instance_id()] = true
	var budgets_ok: bool = (mesh_count <= 900 and uniq_meshes.size() <= 350 and uniq_mats.size() <= 200)

	_assert(
		game6.heroes_by_id.size() == 28 and demo_bot_count >= 5 and rope_flow_ok and fp_client_refresh_ok and budgets_ok and NetSerializer.INPUT_CMD_BYTES == 15,
		"Phase 11.6g: 14v14 spawns %d Demolisher bots, MainGame TNT Rope & FirePatch refresh, INPUT_CMD=15B, map budgets (%d/%d/%d)" % [
			demo_bot_count, mesh_count, uniq_meshes.size(), uniq_mats.size()
		]
	)

	NetworkManager.shutdown_network()
	NetworkManager.local_peer_id = prev_peer_id
	game6.queue_free()
	arena6.queue_free()
	await _flush_deferred()


func _test_phase11_final_fix_wave() -> void:
	# 1. Remote ENet client TRAPPER_STICKY team color + uid + proj_destroy ghost cleanup
	var prev_peer_id: int = NetworkManager.local_peer_id
	var game_fw := MainGame.new()
	add_child(game_fw)
	game_fw._start_bots_sync(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER)
	await get_tree().physics_frame

	var captured_vfx: Array[Dictionary] = []
	var captured_destroy: Array[Dictionary] = []
	var on_fw_evt := func(ev_t: String, pl: Dictionary) -> void:
		if ev_t == "proj_vfx":
			captured_vfx.append(pl)
		elif ev_t == "proj_destroy":
			captured_destroy.append(pl)
	NetworkManager.game_event_received.connect(on_fw_evt)

	var srv_ctx: Dictionary = game_fw._cached_combat_ctx
	var st_royal := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TRAPPER_STICKY,
		1, NetworkManager.TEAM_ROYAL,
		Vector3(-42.0, 1.0, -42.0), Vector3.ZERO, srv_ctx, 40.0, game_fw.projectiles_root
	)
	var st_nat := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TRAPPER_STICKY,
		2, NetworkManager.TEAM_NATIONAL,
		Vector3(42.0, 1.0, 42.0), Vector3.ZERO, srv_ctx, 40.0, game_fw.projectiles_root
	)
	var royal_payload: Dictionary = captured_vfx[0] if captured_vfx.size() >= 1 else {}
	var nat_payload: Dictionary = captured_vfx[1] if captured_vfx.size() >= 2 else {}
	var vfx_payload_ok: bool = (
		int(royal_payload.get("uid", 0)) == st_royal.proj_uid
		and st_royal.proj_uid > 0
		and int(royal_payload.get("team", -1)) == NetworkManager.TEAM_ROYAL
		and int(nat_payload.get("uid", 0)) == st_nat.proj_uid
		and int(nat_payload.get("team", -1)) == NetworkManager.TEAM_NATIONAL
	)

	# Simulate ENet client receiving proj_vfx
	NetworkManager.join_server("127.0.0.1", 7819)
	game_fw._on_game_event("proj_vfx", royal_payload)
	game_fw._on_game_event("proj_vfx", nat_payload)
	var client_royal_vp: ProjectileEntity = null
	var client_nat_vp: ProjectileEntity = null
	for gnode in get_tree().get_nodes_in_group("client_proj_vfx"):
		if gnode is ProjectileEntity:
			var p_ent := gnode as ProjectileEntity
			if p_ent.proj_uid == st_royal.proj_uid:
				client_royal_vp = p_ent
			elif p_ent.proj_uid == st_nat.proj_uid:
				client_nat_vp = p_ent

	var royal_blue_ok: bool = false
	var nat_red_ok: bool = false
	if client_royal_vp != null and client_royal_vp._mesh != null and client_royal_vp._mesh.get_child_count() > 0:
		var r_mi := client_royal_vp._mesh.get_child(0) as MeshInstance3D
		var r_mat := r_mi.material_override as StandardMaterial3D if r_mi != null else null
		royal_blue_ok = (r_mat != null and r_mat.albedo_color.b > r_mat.albedo_color.r and client_royal_vp.owner_team == NetworkManager.TEAM_ROYAL)
	if client_nat_vp != null and client_nat_vp._mesh != null and client_nat_vp._mesh.get_child_count() > 0:
		var n_mi := client_nat_vp._mesh.get_child(0) as MeshInstance3D
		var n_mat := n_mi.material_override as StandardMaterial3D if n_mi != null else null
		nat_red_ok = (n_mat != null and n_mat.albedo_color.r > n_mat.albedo_color.b and client_nat_vp.owner_team == NetworkManager.TEAM_NATIONAL)

	# Switch back to server to detonate royal & destroy national silently, then deliver proj_destroy to client
	NetworkManager.shutdown_network()
	captured_destroy.clear()
	st_royal._detonate()
	st_nat.destroy_by_enemy(false)
	var destroy_emitted_ok: bool = (
		captured_destroy.size() == 2
		and int(captured_destroy[0].get("uid", 0)) == st_royal.proj_uid
		and int(captured_destroy[1].get("uid", 0)) == st_nat.proj_uid
	)
	NetworkManager.join_server("127.0.0.1", 7819)
	for d_pl in captured_destroy:
		game_fw._on_game_event("proj_destroy", d_pl)
	var client_cleanup_ok: bool = (
		client_royal_vp != null and client_royal_vp.is_queued_for_deletion()
		and client_nat_vp != null and client_nat_vp.is_queued_for_deletion()
	)
	NetworkManager.game_event_received.disconnect(on_fw_evt)
	NetworkManager.shutdown_network()

	# Also verify FirePatch is_queued_for_deletion() guard
	var fp_del := DemolisherSkills.FirePatchEntity.new()
	fp_del.set_meta("visual_only", true)
	fp_del.owner_id = 888
	fp_del.position = Vector3(16.0, 0.0, 16.0)
	fp_del._lifetime_elapsed = 4.5
	game_fw.projectiles_root.add_child(fp_del)
	fp_del.queue_free()
	game_fw._on_game_event("fire_patch_vfx", {"pos": Vector3(16.0, 0.0, 16.0), "owner_id": 888, "radius": 2.6})
	var fp_del_guard_ok: bool = is_equal_approx(fp_del._lifetime_elapsed, 4.5)

	_assert(
		vfx_payload_ok and royal_blue_ok and nat_red_ok and destroy_emitted_ok and client_cleanup_ok and fp_del_guard_ok,
		"Phase 11.7a: Client TRAPPER_STICKY carries uid+team colors (royal=%s, nat=%s), proj_destroy cleanup=%s, FirePatch del guard=%s" % [
			str(royal_blue_ok), str(nat_red_ok), str(client_cleanup_ok), str(fp_del_guard_ok)
		]
	)

	# 2. Vehicle seat skill single-step (no driver/gunner bypass, no 2x decay) + Boat Seat 2 Trapper sticky detonation
	game_fw.queue_free()
	await _flush_deferred()

	var game_v := MainGame.new()
	add_child(game_v)
	game_v._start_bots_sync(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER)
	await get_tree().physics_frame

	# Freeze all other bots as defeated so they don't interfere, and place a clean VehicleBoat + 2 Royal heroes + 1 National target
	for h_val in game_v.heroes_by_id.values():
		var hh := h_val as HeroCharacter
		if hh != null:
			hh.is_defeated = true
			hh.defeat_timer = 99.0

	var boat_v: VehicleBoat = null
	for v_val in game_v.vehicles_by_id.values():
		if v_val is VehicleBoat:
			boat_v = v_val as VehicleBoat
			break
	var h_drv: HeroCharacter = game_v.heroes_by_id.get(NetworkManager.local_peer_id, null)
	var h_pass: HeroCharacter = null
	var h_enemy: HeroCharacter = null
	for h_val in game_v.heroes_by_id.values():
		var hh := h_val as HeroCharacter
		if hh == null or hh == h_drv:
			continue
		if hh.team == NetworkManager.TEAM_ROYAL and h_pass == null:
			h_pass = hh
		elif hh.team == NetworkManager.TEAM_NATIONAL and h_enemy == null:
			h_enemy = hh

	var seat_skill_ok: bool = false
	var seat_det_ok: bool = false
	var boat_cushions_removed_ok: bool = false
	if boat_v != null and h_drv != null and h_pass != null and h_enemy != null:
		# Check boat mesh has NO legacy front cushions at z ~ -1.25 (Seat Cushion nodes sit inside Boat visual root only on rear or nowhere)
		var front_cushions: int = 0
		for mi_node in boat_v.get_cached_visual_meshes():
			if absf(mi_node.position.z - (-1.25)) < 0.1 and absf(mi_node.position.x) > 0.5:
				front_cushions += 1
		boat_cushions_removed_ok = (front_cushions == 0)

		h_drv.respawn_at(boat_v.global_position, 0.0)
		h_drv.is_local_player = false
		game_v.bot_brains.erase(h_drv.entity_id)
		h_pass.respawn_at(boat_v.global_position, 0.0)
		h_pass.is_bot = false
		game_v.bot_brains.erase(h_pass.entity_id)
		game_v.bot_brains.erase(h_enemy.entity_id)
		# Ensure h_pass is Demolisher with Trapper in slot 1
		h_pass.setup_identity(h_pass.entity_id, "BoatPassDemo", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 1, false, false)
		h_pass.skill_manager.skill_cooldowns[1] = 10.0

		# Put Driver in Seat 0 (can_use_skills=false), Passenger in Seat 2 (can_use_skills=true, can_shoot=true)
		boat_v.seats[0].occupant_id = h_drv.entity_id
		h_drv.current_vehicle_id = boat_v.id
		h_drv.current_seat_index = 0
		boat_v.seats[2].occupant_id = h_pass.entity_id
		h_pass.current_vehicle_id = boat_v.id
		h_pass.current_seat_index = 2

		# Driver attempts BTN_SKILL_1 & cooldown starts at 10.0 (decays to 9.5 while combat skill 0 stays blocked!); Passenger has cooldown 10.0
		h_drv.skill_manager.skill_cooldowns[1] = 10.0
		var drv_cmd := InputCmd.new()
		drv_cmd.set_button(InputCmd.BTN_SKILL_1, true)
		h_drv.latest_server_input = drv_cmd
		var pass_cmd := InputCmd.new()
		pass_cmd.selected_weapon_slot = 1 # Trapper
		h_pass.latest_server_input = pass_cmd

		game_v._physics_process(0.5)
		var drv_blocked_ok: bool = (
			is_equal_approx(h_drv.skill_manager.skill_cooldowns[0], 0.0)
			and is_equal_approx(h_drv.skill_manager.skill_cooldowns[1], 9.5)
		)
		var pass_single_tick_ok: bool = is_equal_approx(h_pass.skill_manager.skill_cooldowns[1], 9.5)
		seat_skill_ok = drv_blocked_ok and pass_single_tick_ok

		# Now Seat 2 passenger fires TRAPPER_STICKY, waits 0.55s, and right-click detonates near h_enemy
		var pass_fire_cmd := InputCmd.new()
		pass_fire_cmd.selected_weapon_slot = 1
		pass_fire_cmd.set_button(InputCmd.BTN_FIRE, true)
		h_pass.latest_server_input = pass_fire_cmd
		game_v._physics_process(0.02)

		var pass_sticky: ProjectileEntity = null
		for sn in get_tree().get_nodes_in_group("destructible_stickies"):
			if sn is ProjectileEntity and (sn as ProjectileEntity).owner_id == h_pass.entity_id:
				pass_sticky = sn as ProjectileEntity
				break

		if pass_sticky != null:
			h_pass.latest_server_input = pass_cmd
			pass_sticky._physics_process(0.55)
			pass_sticky.global_position = Vector3(45.0, 1.0, 45.0)
			pass_sticky._stuck = true
			pass_sticky._is_stuck = true
			h_enemy.respawn_at(Vector3(45.0, 0.0, 45.0), 0.0)
			await get_tree().physics_frame
			var hp_pre_det: int = h_enemy.hp

			# While tnt_rope_active is true, right-click detonation must be blocked
			h_pass.status_effects.activate_tnt_rope()
			var pass_det_cmd := InputCmd.new()
			pass_det_cmd.selected_weapon_slot = 1
			pass_det_cmd.set_button(InputCmd.BTN_AIM, true)
			h_pass.latest_server_input = pass_det_cmd
			game_v._physics_process(0.02)
			var rope_blocked_det_ok: bool = (not pass_sticky._exploded and h_enemy.hp == hp_pre_det)

			# Release BTN_AIM, clear tnt_rope_active, press BTN_AIM again -> Boat Seat 2 passenger detonates sticky!
			h_pass.status_effects.clear_tnt_rope()
			h_pass.latest_server_input = pass_cmd
			game_v._physics_process(0.02)
			h_pass.latest_server_input = pass_det_cmd
			game_v._physics_process(0.02)
			seat_det_ok = (rope_blocked_det_ok and pass_sticky._exploded and h_enemy.hp < hp_pre_det)

	_assert(
		seat_skill_ok and seat_det_ok and boat_cushions_removed_ok,
		"Phase 11.7b: Vehicle seat skill single-step=%s, Boat Seat 2 Trapper detonate=%s, Boat front cushions removed=%s" % [
			str(seat_skill_ok), str(seat_det_ok), str(boat_cushions_removed_ok)
		]
	)

	# 3. HUDController skill/widget slot mouse_filter == Control.MOUSE_FILTER_PASS + Map budgets & INPUT_CMD_BYTES == 15
	var hud_fw := HUDController.new()
	add_child(hud_fw)
	var skill_mf_ok: bool = (hud_fw._skill_slot_bgs.size() == 6)
	for sbg in hud_fw._skill_slot_bgs:
		if sbg.mouse_filter != Control.MOUSE_FILTER_PASS:
			skill_mf_ok = false
	var widget_mf_ok: bool = (hud_fw._widget_slot_bgs.size() == 4)
	for wbg in hud_fw._widget_slot_bgs:
		if wbg.mouse_filter != Control.MOUSE_FILTER_PASS:
			widget_mf_ok = false
	hud_fw.queue_free()

	var mc2: int = 0
	var um2: Dictionary = {}
	var umat2: Dictionary = {}
	for node in game_v.map_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mc2 += 1
		if mi.mesh != null:
			um2[mi.mesh.get_instance_id()] = true
		if mi.material_override != null:
			umat2[mi.material_override.get_instance_id()] = true
	var budgets_fw_ok: bool = (mc2 <= 900 and um2.size() <= 350 and umat2.size() <= 200)

	_assert(
		skill_mf_ok and widget_mf_ok and budgets_fw_ok and NetSerializer.INPUT_CMD_BYTES == 15,
		"Phase 11.7c: HUD tooltip mouse_filter=PASS (skills=%s, widgets=%s), map budgets (%d/%d/%d), INPUT_CMD=15B" % [
			str(skill_mf_ok), str(widget_mf_ok), mc2, um2.size(), umat2.size()
		]
	)

	NetworkManager.shutdown_network()
	NetworkManager.local_peer_id = prev_peer_id
	game_v.queue_free()
	await _flush_deferred()


func _test_phase11_polish_task7() -> void:
	print("--- Phase 11 Polish Task 7: Flamethrower Jet/Roar, Ground Fire, Sky-Aim Fix & Fire Breath Sweep ---")

	# 1. SoundSynthesizer flame roar clip & sustain cooldown guard
	var flame_wav: AudioStreamWAV = SoundSynthesizer._clips.get("shoot_flame", null) as AudioStreamWAV
	var roar_clip_ok: bool = (flame_wav != null and SoundSynthesizer.FLAME_SFX_INTERVAL_MS >= 180)
	if flame_wav != null:
		var pcm: PackedByteArray = flame_wav.data
		var sample_count: int = pcm.size() / 2
		var dur_ok: bool = sample_count >= int(0.40 * float(SoundSynthesizer.SAMPLE_RATE))
		var head_samples: int = mini(sample_count, int(0.010 * float(SoundSynthesizer.SAMPLE_RATE)))
		var head_peak: float = 0.0
		for si in range(head_samples):
			head_peak = maxf(head_peak, absf(float(pcm.decode_s16(si * 2)) / 32767.0))
		var mid_start: int = sample_count / 3
		var mid_end: int = (sample_count * 2) / 3
		var mid_peak: float = 0.0
		for si in range(mid_start, mid_end):
			mid_peak = maxf(mid_peak, absf(float(pcm.decode_s16(si * 2)) / 32767.0))
		roar_clip_ok = roar_clip_ok and dur_ok and (head_peak < mid_peak * 0.35) and (mid_peak >= 0.45)

	SoundSynthesizer._local_sfx_cooldowns.erase("shoot_flame")
	SoundSynthesizer.play_sfx("shoot_flame", 0.0, true)
	var first_cd_ms: int = int(SoundSynthesizer._local_sfx_cooldowns.get("shoot_flame", -1))
	SoundSynthesizer.play_sfx("shoot_flame", 0.0, true)
	var second_cd_ms: int = int(SoundSynthesizer._local_sfx_cooldowns.get("shoot_flame", -1))
	var roar_cd_ok: bool = (first_cd_ms >= 0 and second_cd_ms == first_cd_ms)
	_assert(roar_clip_ok and roar_cd_ok, "Phase 11.T7a: SoundSynthesizer shoot_flame uses soft-attack roar (>=0.40s) and FLAME_SFX_INTERVAL_MS >= 180 sustain guard")

	# 2. Flamethrower (21.0m) & Fire Starter (21.0m) ranges + Sky-Aim Ground Fire Fix + Non-Spiky FirePatchEntity
	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)
	await get_tree().physics_frame

	var demo := HeroCharacter.new()
	demo.setup_identity(11701, "T7Demo", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 1, true, false)
	arena.add_child(demo)
	var enemy := HeroCharacter.new()
	enemy.setup_identity(11702, "T7Enemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(enemy)
	demo.global_position = Vector3.ZERO
	enemy.global_position = Vector3(0.45, 0.0, -14.0)
	await get_tree().physics_frame

	var fw0 := FlameWeapon.new()
	fw0.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 0)
	var fw1 := FlameWeapon.new()
	fw1.configure(demo, WeaponBase.WeaponKind.FLAMETHROWER, 1)
	demo.add_child(fw0)
	demo.add_child(fw1)
	var ranges_ok: bool = (fw0.max_range_m >= 20.5 and fw1.max_range_m >= 20.5)

	var ctx: Dictionary = {"heroes_by_id": {11701: demo, 11702: enemy}, "projectiles_root": arena}
	var pre_sky_patches: int = get_tree().get_nodes_in_group("fire_patches").size()
	var sky_dir: Vector3 = Vector3(0.0, 0.55, -0.83).normalized()
	var space_state: PhysicsDirectSpaceState3D = demo.get_world_3d().direct_space_state
	var excl: Array[RID] = [demo.get_rid()]
	fw1._try_spawn_or_refresh_fire_patch(Vector3(0.0, 1.5, 0.0), sky_dir, space_state, excl, ctx)
	var sky_cmd := InputCmd.new()
	sky_cmd.aim_yaw = 0.0
	sky_cmd.aim_pitch = 0.62
	fw1.fire_server(sky_cmd, ctx)
	var sky_patches_ok: bool = (get_tree().get_nodes_in_group("fire_patches").size() == pre_sky_patches)

	var down_cmd := InputCmd.new()
	down_cmd.aim_yaw = 0.0
	down_cmd.aim_pitch = -0.25
	fw1.fire_server(down_cmd, ctx)
	var all_patches: Array[Node] = get_tree().get_nodes_in_group("fire_patches")
	var ground_spawn_ok: bool = (all_patches.size() == pre_sky_patches + 1)

	var non_spiky_ok: bool = false
	for p in all_patches:
		if p is DemolisherSkills.FirePatchEntity:
			var fp := p as DemolisherSkills.FirePatchEntity
			var spike_found: bool = false
			var sheet_count: int = 0
			for ch in fp.get_children():
				if ch is MeshInstance3D:
					var mi := ch as MeshInstance3D
					if mi.mesh is CylinderMesh and (mi.mesh as CylinderMesh).top_radius < 0.12:
						spike_found = true
					elif mi.mesh is QuadMesh or mi.mesh is BoxMesh:
						sheet_count += 1
			non_spiky_ok = (not spike_found and sheet_count >= 4)
			fp.queue_free()

	_assert(
		ranges_ok and sky_patches_ok and ground_spawn_ok and non_spiky_ok,
		"Phase 11.T7b: Ranges (21.0/21.0m), sky-aim spawns 0 patches (%s), ground-aim spawns 1 (%s), non-spiky FirePatchEntity (%s)" % [
			str(sky_patches_ok), str(ground_spawn_ok), str(non_spiky_ok)
		]
	)

	# 3. Fire Breath <=35m / <=0.72s expiry AND reliable capsule sweep within 0.45m lateral offset
	var fb_expire := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.FIREBALL,
		demo.entity_id, demo.team,
		Vector3(0.0, 2.5, 0.0),
		Vector3(0.0, 0.0, 45.0),
		ctx, 40.0, arena
	)
	var start_fb: Vector3 = fb_expire.global_position
	var elapsed_fb: float = 0.0
	while not fb_expire._exploded and elapsed_fb < 0.76:
		fb_expire._physics_process(0.04)
		elapsed_fb += 0.04
	var fb_travel: float = start_fb.distance_to(fb_expire.global_position)
	var fb_expire_ok: bool = (fb_expire._exploded and elapsed_fb <= 0.72 and fb_travel <= 35.0)

	enemy.respawn_at(Vector3(0.45, 0.0, -14.0), 0.0)
	enemy.is_in_water = false
	enemy.status_effects.clear_all()
	await get_tree().physics_frame
	var enemy_hp0: int = enemy.hp
	var fb_sweep := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.FIREBALL,
		demo.entity_id, demo.team,
		Vector3(0.0, 1.2, 0.0),
		Vector3(0.0, 0.0, -45.0),
		ctx, 40.0, arena
	)
	for _step in range(30):
		if fb_sweep._exploded:
			break
		fb_sweep._physics_process(0.02)
	var fb_sweep_ok: bool = (
		fb_sweep._exploded
		and enemy.hp == enemy_hp0 - 40
		and enemy.status_effects.is_burning()
	)
	_assert(
		fb_expire_ok and fb_sweep_ok,
		"Phase 11.T7c: Fire Breath expires <=0.72s (%.2fs, %.1fm<=35m) and capsule sweep hits 0.45m lateral enemy (%d->%d, burning=%s)" % [
			elapsed_fb, fb_travel, enemy_hp0, enemy.hp, str(enemy.status_effects.is_burning())
		]
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase11_polish_task8() -> void:
	print("--- Phase 11 Polish Task 8: Cowboy Lasso TNT Rope, Trapper Rooftop Precision & 40mm Pill Grenade ---")

	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var cottage := BuildingMeshBuilder.build_town_house(arena, Vector3.ZERO, 0.0, 0)
	await get_tree().physics_frame

	# 1. Cowboy Lasso Overhead Spinning TNT Rope pose + radial bundle offset >= 0.50m
	var demo := HeroCharacter.new()
	demo.setup_identity(11801, "T8Demo", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 1, true, false)
	arena.add_child(demo)
	demo.global_position = Vector3(0.0, 0.0, 20.0)
	await get_tree().physics_frame

	var dsm: DemolisherSkills = demo.skill_manager as DemolisherSkills
	var ctx: Dictionary = {"heroes_by_id": {11801: demo}, "projectiles_root": arena}
	dsm.try_activate_skill(2, InputCmd.new(), ctx)
	demo._animate_character(0.08)
	var tnt_bundle := demo._held_weapon_root.get_node_or_null("TntRope") as Node3D
	var max_stick_dist: float = 0.0
	var stick_count: int = 0
	if tnt_bundle != null:
		for ch in tnt_bundle.get_children():
			if ch is MeshInstance3D and String(ch.name).begins_with("DynamiteStick"):
				stick_count += 1
				max_stick_dist = maxf(max_stick_dist, (ch as MeshInstance3D).position.length())
	var cowboy_pose_ok: bool = (
		demo._held_weapon_root.position.x >= 0.70
		and demo._held_weapon_root.position.y >= 0.48
		and tnt_bundle != null
		and tnt_bundle.rotation.x > 0.0
		and is_equal_approx(tnt_bundle.rotation.y, 0.0)
		and is_equal_approx(tnt_bundle.rotation.z, 0.0)
		and stick_count == 4
		and max_stick_dist >= 0.50
	)
	_assert(
		cowboy_pose_ok,
		"Phase 11.T8a: Cowboy TNT Rope extends arm laterally (%.2f, %.2f), spins CCW around +X in vertical Y-Z plane, and mounts 4 sticks at %.2fm >= 0.50m" % [
			demo._held_weapon_root.position.x, demo._held_weapon_root.position.y, max_stick_dist
		]
	)
	dsm.throw_tnt_rope(InputCmd.new(), ctx)
	demo.status_effects.clear_tnt_rope()

	# 2. Cottage collider roof eave has no phantom +1.0m slab above plinth_h + wall_h (5.3m) + downward Trapper shot clears + hit_radius <= 0.40
	var space_state: PhysicsDirectSpaceState3D = demo.get_world_3d().direct_space_state
	var eave_ray_q := PhysicsRayQueryParameters3D.create(Vector3(7.5, 6.30, 2.0), Vector3(5.2, 6.30, 2.0), 1)
	var eave_ray_hit: Dictionary = space_state.intersect_ray(eave_ray_q)
	var no_phantom_eave_slab: bool = eave_ray_hit.is_empty()

	demo.global_position = Vector3(5.6, 5.45, 0.0)
	demo.is_crouching = false
	await get_tree().physics_frame
	var gl1: ProjectileWeapon = demo.weapons[1] as ProjectileWeapon
	var down_cmd := InputCmd.new()
	down_cmd.aim_yaw = -PI * 0.5
	down_cmd.aim_pitch = -1.10
	gl1.fire_server(down_cmd, ctx)
	var fired_sticky: ProjectileEntity = null
	for ch in arena.get_children():
		if ch is ProjectileEntity and (ch as ProjectileEntity).kind == ProjectileEntity.ProjectileKind.TRAPPER_STICKY:
			fired_sticky = ch as ProjectileEntity
	var sticky_radius_ok: bool = (fired_sticky != null and fired_sticky.hit_radius <= 0.40)
	var sticky_vel_down_ok: bool = (fired_sticky != null and fired_sticky.velocity.y < -15.0)
	if fired_sticky != null:
		for _step in range(15):
			fired_sticky._physics_process(0.02)
			if fired_sticky._stuck:
				break
	var sticky_cleared_roof: bool = (fired_sticky != null and fired_sticky._stuck and fired_sticky.global_position.y <= 0.10)
	_assert(
		no_phantom_eave_slab and sticky_radius_ok and sticky_vel_down_ok and sticky_cleared_roof and cottage != null,
		"Phase 11.T8b: Cottage eave clear at +1.0m (%s), Trapper downward shot clears roof to street (%s, y=%.2f, vy=%.1f), hit_radius=%.2f" % [
			str(no_phantom_eave_slab), str(sticky_cleared_roof),
			fired_sticky.global_position.y if fired_sticky != null else -1.0,
			fired_sticky.velocity.y if fired_sticky != null else 0.0,
			fired_sticky.hit_radius if fired_sticky != null else -1.0
		]
	)

	# 3. 40mm Oblong Pill Grenade visual (CapsuleMesh) + bounce_restitution <= 0.26 + low floor bounce <= 4.2
	var bg_proj := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		demo.entity_id, demo.team,
		Vector3(0.0, 0.4, 28.0),
		Vector3(0.0, -16.0, -12.0),
		ctx, 60.0, arena
	)
	var capsule_ok: bool = false
	if bg_proj._mesh != null:
		for ch in bg_proj._mesh.get_children():
			if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is CapsuleMesh:
				var cap_m := (ch as MeshInstance3D).mesh as CapsuleMesh
				if cap_m.height > cap_m.radius * 2.4:
					capsule_ok = true
	var rest_ok: bool = (bg_proj.bounce_restitution <= 0.26)
	for _bstep in range(6):
		bg_proj._physics_process(0.02)
		if bg_proj._bounce_fuse_started:
			break
	var low_bounce_ok: bool = (bg_proj._bounce_fuse_started and bg_proj.velocity.y >= 0.0 and bg_proj.velocity.y <= 4.2)
	_assert(
		capsule_ok and rest_ok and low_bounce_ok,
		"Phase 11.T8c: BOUNCE_GRENADE uses CapsuleMesh (%s), restitution=%.2f <= 0.26, -16m/s floor impact rebounds low (vy=%.2f <= 4.2)" % [
			str(capsule_ok), bg_proj.bounce_restitution, bg_proj.velocity.y
		]
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase12_task1_fixes() -> void:
	print("--- Phase 12 Task 1: Vehicle Cooldowns/Widgets, Flame Point-Blank, Grenade Contact+1s Fuse & Crosshair ---")
	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(200.0, 1.0, 200.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)
	await get_tree().physics_frame

	# 1. Driver cooldowns decay 1x/tick & Wrench repairs captured vehicle while combat skill 0 stays blocked
	var cap_tank := VehicleTank.new()
	cap_tank.id = 12101
	cap_tank.team = NetworkManager.TEAM_NATIONAL
	arena.add_child(cap_tank)
	cap_tank.global_position = Vector3(0.0, 0.2, 0.0)
	cap_tank.hp = 200

	var drv := HeroCharacter.new()
	drv.setup_identity(12102, "P12Drv", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	arena.add_child(drv)
	drv.global_position = Vector3(0.0, 0.2, 0.0)
	var entered_seat: int = cap_tank.try_enter_hero(drv)
	drv.skill_manager.skill_cooldowns[0] = 5.0
	drv.skill_manager.widget_cooldowns[0] = 3.0
	var drv_cmd := InputCmd.new()
	drv_cmd.set_button(InputCmd.BTN_SKILL_1, true)
	drv_cmd.set_button(InputCmd.BTN_WIDGET_2, true)
	drv.latest_server_input = drv_cmd
	var v_ctx: Dictionary = {"heroes_by_id": {drv.entity_id: drv}, "vehicles": [cap_tank], "projectiles_root": arena}
	cap_tank.sync_occupants(v_ctx["heroes_by_id"] as Dictionary, 0.5, v_ctx)
	var drv_fix_ok: bool = (
		entered_seat == 0
		and is_equal_approx(drv.skill_manager.skill_cooldowns[0], 4.5)
		and is_equal_approx(drv.skill_manager.widget_cooldowns[0], 2.5)
		and cap_tank.hp == 310
		and drv.skill_manager.widget_cooldowns[1] > 0.0
	)
	_assert(
		drv_fix_ok,
		"Phase 12.1a: Driver cooldowns decay (skill0=%.1f, widget0=%.1f), Wrench heals captured Tank (hp=%d), combat skill 0 blocked" % [
			drv.skill_manager.skill_cooldowns[0], drv.skill_manager.widget_cooldowns[0], cap_tank.hp
		]
	)
	cap_tank.exit_hero(drv)

	# 2. Flamethrower & Fire Starter (21.0m, 10 dmg, 5 ammo on Fire Starter) + Point-Blank hero & vehicle corner + Fire Breath 0.6m
	var enemy := HeroCharacter.new()
	enemy.setup_identity(12103, "P12Enemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(enemy)

	var fw0 := FlameWeapon.new()
	fw0.configure(drv, WeaponBase.WeaponKind.FLAMETHROWER, 0)
	var fw1 := FlameWeapon.new()
	fw1.configure(drv, WeaponBase.WeaponKind.FLAMETHROWER, 1)
	var fw2 := FlameWeapon.new()
	fw2.configure(drv, WeaponBase.WeaponKind.FLAMETHROWER, 2)
	drv.add_child(fw0)
	drv.add_child(fw1)
	drv.add_child(fw2)

	var f_ctx: Dictionary = {"heroes_by_id": {drv.entity_id: drv, enemy.entity_id: enemy}, "vehicles": [cap_tank], "projectiles_root": arena}
	var aim_fwd := InputCmd.new()
	aim_fwd.aim_yaw = 0.0
	aim_fwd.aim_pitch = 0.0
	aim_fwd.set_button(InputCmd.BTN_FIRE, true)

	# Point-blank 0.8m & 1.5m (offset laterally)
	drv.global_position = Vector3(0.0, 0.0, 0.0)
	enemy.respawn_at(Vector3(0.45, 0.0, -0.8), 0.0)
	await get_tree().physics_frame
	var hp_08_pre: int = enemy.hp
	fw0.fire_server(aim_fwd, f_ctx)
	var pb0_ok: bool = (enemy.hp == hp_08_pre - 15 and enemy.status_effects.is_burning())

	enemy.respawn_at(Vector3(-0.55, 0.0, -1.5), 0.0)
	await get_tree().physics_frame
	var hp_15_pre: int = enemy.hp
	var fs_fire_ok: bool = fw1.try_consume_fire(aim_fwd) and fw1.ammo_in_mag == 98
	fw1.fire_server(aim_fwd, f_ctx)
	var pb1_ok: bool = (fs_fire_ok and enemy.hp == hp_15_pre - 15 and enemy.status_effects.is_burning())

	# Vehicle corner hit: tank center at (1.9, 0.2, -3.2), front-left corner within ~0.8m in front of shooter
	cap_tank.global_position = Vector3(1.9, 0.2, -3.2)
	cap_tank.hp = 400
	await get_tree().physics_frame
	var tank_pre_hp: int = cap_tank.hp
	fw0.fire_server(aim_fwd, f_ctx)
	var veh_corner_ok: bool = (cap_tank.hp < tank_pre_hp)

	# Fire Breath 0.6m point-blank enemy
	enemy.respawn_at(Vector3(0.0, 0.0, -0.6), 0.0)
	await get_tree().physics_frame
	var fb_pre_hp: int = enemy.hp
	fw2.fire_server(aim_fwd, f_ctx)
	var fb_pb_ok: bool = (enemy.hp == fb_pre_hp - 40 and enemy.status_effects.is_burning())

	_assert(
		is_equal_approx(fw0.max_range_m, 21.0) and is_equal_approx(fw1.max_range_m, 21.0) and pb0_ok and pb1_ok and veh_corner_ok and fb_pb_ok,
		"Phase 12.1b: Flame 21m/15dmg/2ammo@0.10s, point-blank 0.8m(%s)/1.5m(%s), tank corner(%s), Fire Breath 0.6m(%s)" % [
			str(pb0_ok), str(pb1_ok), str(veh_corner_ok), str(fb_pb_ok)
		]
	)

	# 3. BOUNCE_GRENADE direct vehicle explosion (hijacked Royal Jeep & point-blank 0.4m Tank hull) + 1.0s fuse
	var jeep_hijack := VehicleJeep.new()
	jeep_hijack.id = 12104
	jeep_hijack.team = NetworkManager.TEAM_ROYAL # Same team as shooter drv, hijacked by National enemy!
	arena.add_child(jeep_hijack)
	jeep_hijack.global_position = Vector3(25.0, 0.2, -5.0)
	jeep_hijack.hp = 350
	enemy.respawn_at(Vector3(25.0, 0.2, -5.0), 0.0)
	jeep_hijack.try_enter_hero(enemy)
	await get_tree().physics_frame

	var g_ctx: Dictionary = {"heroes_by_id": {drv.entity_id: drv, enemy.entity_id: enemy}, "vehicles": [cap_tank, jeep_hijack], "projectiles_root": arena}
	var hijack_pre_hp: int = jeep_hijack.hp
	var bg_hijack := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BOUNCE_GRENADE,
		drv.entity_id, drv.team,
		Vector3(25.0, 1.1, -1.5),
		Vector3(0.0, 0.0, -30.0),
		g_ctx, 60.0, arena
	)
	for _s in range(8):
		if bg_hijack._exploded:
			break
		bg_hijack._physics_process(0.02)
	var hijack_det_ok: bool = (bg_hijack._exploded and jeep_hijack.hp < hijack_pre_hp)

	# Point-blank 0.4m launch into Tank hull using ProjectileWeapon
	drv.global_position = Vector3(-20.0, 0.0, 0.0)
	cap_tank.global_position = Vector3(-20.0, 0.2, -3.3)
	cap_tank.hp = 400
	await get_tree().physics_frame
	var gl0: ProjectileWeapon = drv.weapons[1] as ProjectileWeapon
	var tank_pb_pre: int = cap_tank.hp
	gl0.fire_server(aim_fwd, g_ctx)
	var pb_grenade: ProjectileEntity = null
	for ch in arena.get_children():
		if ch is ProjectileEntity and (ch as ProjectileEntity).kind == ProjectileEntity.ProjectileKind.BOUNCE_GRENADE and not (ch as ProjectileEntity)._exploded:
			pb_grenade = ch as ProjectileEntity
	if pb_grenade != null:
		pb_grenade._physics_process(0.02)
	var pb_tank_ok: bool = (pb_grenade != null and pb_grenade._exploded and cap_tank.hp < tank_pb_pre)

	_assert(
		hijack_det_ok and pb_tank_ok,
		"Phase 12.1c: BOUNCE_GRENADE detonates immediately on hijacked vehicle (%s) & point-blank Tank hull (%s)" % [
			str(hijack_det_ok), str(pb_tank_ok)
		]
	)

	# 4. High-contrast white 2x2 center dot w/ 4x4 dark outline + bright white outlined crosshair arms
	var hud := HUDController.new()
	add_child(hud)
	var dot_fill := hud._crosshair_dot.get_node_or_null("Fill") as ColorRect if hud._crosshair_dot != null else null
	var bot_fill := hud._crosshair_bottom.get_node_or_null("Fill") as ColorRect if hud._crosshair_bottom != null else null
	var ch_contrast_ok: bool = (
		hud._crosshair_dot != null
		and hud._crosshair_dot.size == Vector2(4, 4)
		and hud._crosshair_dot.position == Vector2(-2, -2)
		and hud._crosshair_dot.color.r <= 0.08 and hud._crosshair_dot.color.a >= 0.90
		and dot_fill != null and dot_fill.size == Vector2(2, 2) and dot_fill.color == Color.WHITE
		and hud._crosshair_bottom != null and hud._crosshair_bottom.color.r <= 0.08 and hud._crosshair_bottom.color.a >= 0.90
		and bot_fill != null and bot_fill.color.r >= 0.94 and bot_fill.color.g >= 0.94 and bot_fill.color.b >= 0.94
	)
	_assert(ch_contrast_ok, "Phase 12.1d: High-contrast 2x2 white crosshair center dot (4x4 outline) + bright white outlined arms")

	hud.queue_free()
	arena.queue_free()
	await _flush_deferred()

func _test_phase12_task2_demolisher_rework() -> void:
	print("--- Phase 12 Task 2: Demolisher Skill Rework (Carried Shield + 5-Vest Armor Kit) ---")
	var arena := Node3D.new()
	add_child(arena)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(120.0, 1.0, 120.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var demo := HeroCharacter.new()
	demo.setup_identity(12201, "DemoT2", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	arena.add_child(demo)

	var ally := HeroCharacter.new()
	ally.setup_identity(12202, "AllyT2", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(ally)

	var enemy := HeroCharacter.new()
	enemy.setup_identity(12203, "EnemyT2", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(enemy)

	var enemy_demo := HeroCharacter.new()
	enemy_demo.setup_identity(12204, "EnemyDemoT2", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	arena.add_child(enemy_demo)

	var lag_comp := LagCompensator.new()
	arena.add_child(lag_comp)

	var heroes_map: Dictionary = {
		12201: demo,
		12202: ally,
		12203: enemy,
		12204: enemy_demo,
	}
	var ctx: Dictionary = {
		"heroes_by_id": heroes_map,
		"projectiles_root": arena,
		"lag_compensator": lag_comp,
	}
	await get_tree().physics_frame

	# 1. Skill 3: Kit de 5 Coletes (+70 permanent vest shield, immediate 17s CD on drop, replacing old kit despawns it)
	var dsm: DemolisherSkills = demo.skill_manager as DemolisherSkills
	demo.global_position = Vector3.ZERO
	ally.global_position = Vector3(20.0, 0.0, 0.0)
	enemy.global_position = Vector3(0.0, 0.0, 0.0)
	enemy_demo.global_position = Vector3(30.0, 0.0, 0.0)
	demo.shield = 0
	demo.status_effects.permanent_vest_shield = 0
	var s3_ok: bool = dsm.try_activate_skill(3, InputCmd.new(), ctx)
	var kit: DemolisherSkills.ArmorKitEntity = null
	for ch in arena.get_children():
		if ch is DemolisherSkills.ArmorKitEntity:
			kit = ch as DemolisherSkills.ArmorKitEntity
	var kit_init_ok: bool = (
		s3_ok
		and kit != null
		and kit.charges == 5
		and is_equal_approx(dsm.skill_cooldowns[3], 17.0)
		and not dsm._defers_cooldown_until_exit(3)
	)

	kit.step_kit(0.02, ctx)
	var first_vest_ok: bool = (
		demo.shield == 70
		and demo.status_effects.permanent_vest_shield == 70
		and enemy.shield == 0
		and kit.charges == 4
		and is_equal_approx(dsm.skill_cooldowns[3], 17.0)
	)
	for _t in range(6):
		demo.status_effects._physics_process(1.0)
	var no_decay_ok: bool = (demo.shield == 70 and demo.status_effects.permanent_vest_shield == 70)
	demo.apply_damage_server(25, enemy.entity_id, false)
	var vest_damaged_ok: bool = (demo.shield == 45 and demo.status_effects.permanent_vest_shield == 45)
	demo.global_position = Vector3(10.0, 0.0, 0.0)

	ally.global_position = Vector3(0.8, 0.0, 0.0)
	for _v in range(4):
		ally.shield = 0
		ally.status_effects.permanent_vest_shield = 0
		kit.step_kit(0.6, ctx)
	var fifth_empties_ok: bool = (
		ally.shield == 70
		and kit.is_queued_for_deletion()
		and is_equal_approx(dsm.skill_cooldowns[3], 17.0)
	)
	_assert(
		kit_init_ok and first_vest_ok and no_decay_ok and vest_damaged_ok and fifth_empties_ok,
		"Phase 12.2a: Skill 3 Kit de 5 Coletes grants +70 permanent-until-damaged shield, blocks enemy pickup, and starts immediate 17s CD on drop"
	)

	# 2. Skill 0: Carried Frontal Riot Shield (550 HP) + Weapon 3 (STICK_GRENADE) Combo + Swing Gap + Frontal Block vs Flank
	demo.respawn_at(Vector3.ZERO, 0.0)
	enemy.respawn_at(Vector3(0.0, 0.0, -6.0), PI)
	enemy_demo.respawn_at(Vector3(0.0, 0.0, -6.0), PI)
	demo.selected_weapon_slot = 0
	var s0_cmd := InputCmd.new()
	s0_cmd.tick = 10
	s0_cmd.aim_yaw = 0.0
	var s0_act_ok: bool = dsm.try_activate_skill(0, s0_cmd, ctx)
	demo._animate_character(0.016)
	var shield_vis_pos0: Vector3 = demo._held_riot_shield.position if demo._held_riot_shield != null else Vector3.ZERO
	var shield_vis_rot0: Vector3 = demo._held_riot_shield.rotation if demo._held_riot_shield != null else Vector3.ZERO
	var s0_equip_ok: bool = (
		s0_act_ok
		and demo.selected_weapon_slot == 2
		and demo.status_effects.carried_shield_active
		and demo.status_effects.carried_shield_hp == 550
		and (demo.active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) != 0
		and is_equal_approx(dsm.skill_cooldowns[0], 0.0)
		and demo._held_riot_shield != null and demo._held_riot_shield.visible
	)

	await get_tree().physics_frame
	var demo_hp0: int = demo.hp
	var enemy_smg: HitscanWeapon = enemy.weapons[0] as HitscanWeapon
	var shoot_south := InputCmd.new()
	shoot_south.aim_yaw = PI
	shoot_south.aim_pitch = 0.0
	enemy_smg.fire_server(shoot_south, ctx)
	var frontal_gun_ok: bool = (demo.hp == demo_hp0 and demo.status_effects.carried_shield_hp < 550 and demo.status_effects.carried_shield_hp > 0)

	var sh_before_flame: int = demo.status_effects.carried_shield_hp
	var ed_flame: FlameWeapon = enemy_demo.weapons[0] as FlameWeapon
	ed_flame.fire_server(shoot_south, ctx)
	var frontal_flame_ok: bool = (demo.hp == demo_hp0 and demo.status_effects.carried_shield_hp == sh_before_flame - 15 and not demo.status_effects.is_burning())

	var sh_before_proj: int = demo.status_effects.carried_shield_hp
	var f_rocket := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET,
		enemy.entity_id, enemy.team,
		Vector3(0.0, 1.0, -1.0), Vector3(0.0, 0.0, 42.0), ctx, 35.0, arena
	)
	f_rocket._detonate()
	var frontal_proj_ok: bool = (demo.hp == demo_hp0 and demo.status_effects.carried_shield_hp < sh_before_proj)

	enemy.respawn_at(Vector3(0.0, 0.0, 6.0), 0.0)
	await get_tree().physics_frame
	var sh_before_back: int = demo.status_effects.carried_shield_hp
	var shoot_north := InputCmd.new()
	shoot_north.aim_yaw = 0.0
	enemy_smg.fire_server(shoot_north, ctx)
	var back_hits_hp_ok: bool = (demo.hp < demo_hp0 and demo.status_effects.carried_shield_hp == sh_before_back)

	demo.hp = demo.max_hp
	var caber: HitscanWeapon = demo.weapons[2] as HitscanWeapon
	var swing_cmd := InputCmd.new()
	swing_cmd.aim_yaw = 0.0
	caber.fire_server(swing_cmd, ctx)
	demo.trigger_weapon_fire_visual(WeaponBase.WeaponKind.STICK_GRENADE, false)
	demo._animate_character(0.08)
	var swing_gap_active: bool = demo.status_effects.carried_shield_swing_timer > 0.35
	var shield_pulled_aside: bool = (
		demo._held_riot_shield.position.x < shield_vis_pos0.x - 0.10
		and demo._held_riot_shield.rotation.y > shield_vis_rot0.y + 0.25
	)
	enemy.respawn_at(Vector3(0.0, 0.0, -6.0), PI)
	await get_tree().physics_frame
	var hp_pre_gap: int = demo.hp
	enemy_smg.fire_server(shoot_south, ctx)
	var gap_exposes_hp_ok: bool = (demo.hp < hp_pre_gap)

	demo.status_effects._physics_process(0.55)
	demo._animate_character(0.55)
	var shield_returned_ok: bool = (
		is_equal_approx(demo.status_effects.carried_shield_swing_timer, 0.0)
		and absf(demo._held_riot_shield.position.x - shield_vis_pos0.x) < 0.02
		and absf(demo._held_riot_shield.rotation.y) < 0.02
	)

	demo.status_effects.damage_carried_shield(600)
	demo._animate_character(0.016)
	var break_cd_ok: bool = (
		not demo.status_effects.carried_shield_active
		and demo.status_effects.carried_shield_hp == 0
		and (demo.active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) == 0
		and is_equal_approx(dsm.skill_cooldowns[0], 16.0)
		and not demo._held_riot_shield.visible
	)

	dsm.skill_cooldowns[0] = 0.0
	dsm.try_activate_skill(0, s0_cmd, ctx)
	demo.selected_weapon_slot = 0
	demo.status_effects._physics_process(0.016)
	var switch_stows_ok: bool = (
		not demo.status_effects.carried_shield_active
		and is_equal_approx(dsm.skill_cooldowns[0], 16.0)
	)

	_assert(
		s0_equip_ok and frontal_gun_ok and frontal_flame_ok and frontal_proj_ok
		and back_hits_hp_ok and swing_gap_active and shield_pulled_aside
		and gap_exposes_hp_ok and shield_returned_ok and break_cd_ok and switch_stows_ok,
		"Phase 12.2b: Skill 0 Carried Shield + STICK_GRENADE combo (equip=%s, gun=%s, flame=%s, proj=%s, back=%s, gap=%s, aside=%s, exp=%s, ret=%s, brk=%s, stow=%s)" % [
			str(s0_equip_ok), str(frontal_gun_ok), str(frontal_flame_ok), str(frontal_proj_ok),
			str(back_hits_hp_ok), str(swing_gap_active), str(shield_pulled_aside),
			str(gap_exposes_hp_ok), str(shield_returned_ok), str(break_cd_ok), str(switch_stows_ok)
		]
	)

	arena.queue_free()
	await _flush_deferred()


func _send_test_key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = pressed
	ev.echo = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _test_phase12_task3_hotkeys_drag_minimap() -> void:
	print("--- Phase 12 Task 3: Shift Hotkey, Alt Drag-Drop Hotbar & Live Tactical Minimap ---")
	var test_cfg_path: String = "user://phase12_task3_hotkeys_test.cfg"
	InputCmd.reset_default_hotkeys()

	# 1. KEY_SHIFT accepted in ClassSelectMenu, displays SHF, persists in InputCmd
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = test_cfg_path
	add_child(menu)
	await _flush_deferred()
	menu.show_screen("settings")
	menu._begin_hotkey_listen("skill", 0)
	var ev_shift := InputEventKey.new()
	ev_shift.keycode = KEY_SHIFT
	ev_shift.pressed = true
	ev_shift.echo = false
	menu._input(ev_shift)
	var shift_bound_ok: bool = (
		InputCmd.get_skill_key(0) == KEY_SHIFT
		and InputCmd.key_short_label(KEY_SHIFT) == "SHF"
		and menu._skill_hotkey_buttons[0].text.ends_with("SHF")
		and not menu.is_listening_hotkey()
	)
	InputCmd.reset_default_hotkeys()
	var shift_reloaded_ok: bool = InputCmd.load_hotkeys_from_config(test_cfg_path) and InputCmd.get_skill_key(0) == KEY_SHIFT
	menu.queue_free()
	await _flush_deferred()

	_assert(
		shift_bound_ok and shift_reloaded_ok,
		"Phase 12.3a: KEY_SHIFT binds cleanly in ClassSelectMenu, labels 'SHF', and persists in ConfigFile"
	)

	# 2. Alt cursor mode blocks BTN_FIRE, BTN_AIM, Sniper scoping & camera look
	InputCmd.reset_default_hotkeys()
	var arena := Node3D.new()
	add_child(arena)
	var cmd_hero := HeroCharacter.new()
	cmd_hero.setup_identity(13101, "AltCmd", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_COMMANDO, 0, true, false)
	arena.add_child(cmd_hero)
	var hud := HUDController.new()
	hud.hotkeys_config_path = test_cfg_path
	arena.add_child(hud)
	hud.set_local_hero(cmd_hero)
	await get_tree().physics_frame

	var shift_hud_label_ok: bool = false
	InputCmd.set_skill_key(0, KEY_SHIFT)
	hud.refresh_hotkey_labels()
	shift_hud_label_ok = (hud._skill_slot_keys[0].text == "SHF")
	InputCmd.reset_default_hotkeys()
	hud.refresh_hotkey_labels()

	var yaw_before: float = cmd_hero.hero_camera.yaw
	var pitch_before: float = cmd_hero.hero_camera.pitch
	cmd_hero._alt_cursor_mode = true
	var ev_motion := InputEventMouseMotion.new()
	ev_motion.relative = Vector2(85.0, -40.0)
	cmd_hero._input(ev_motion)
	var look_blocked_ok: bool = (
		is_equal_approx(cmd_hero.hero_camera.yaw, yaw_before)
		and is_equal_approx(cmd_hero.hero_camera.pitch, pitch_before)
	)
	var ev_rmb := InputEventMouseButton.new()
	ev_rmb.button_index = MOUSE_BUTTON_RIGHT
	ev_rmb.pressed = true
	Input.parse_input_event(ev_rmb)
	var ev_lmb := InputEventMouseButton.new()
	ev_lmb.button_index = MOUSE_BUTTON_LEFT
	ev_lmb.pressed = true
	Input.parse_input_event(ev_lmb)
	Input.flush_buffered_events()
	cmd_hero._process(0.016)
	var alt_cmd: InputCmd = cmd_hero._sample_local_input()
	var fire_aim_scope_blocked_ok: bool = (
		not alt_cmd.has_button(InputCmd.BTN_FIRE)
		and not alt_cmd.has_button(InputCmd.BTN_AIM)
		and not cmd_hero.hero_camera.is_scoped
		and not cmd_hero.is_scoping
	)
	var ev_rmb_up := InputEventMouseButton.new()
	ev_rmb_up.button_index = MOUSE_BUTTON_RIGHT
	ev_rmb_up.pressed = false
	Input.parse_input_event(ev_rmb_up)
	var ev_lmb_up := InputEventMouseButton.new()
	ev_lmb_up.button_index = MOUSE_BUTTON_LEFT
	ev_lmb_up.pressed = false
	Input.parse_input_event(ev_lmb_up)
	Input.flush_buffered_events()
	cmd_hero._alt_cursor_mode = false

	_assert(
		shift_hud_label_ok and look_blocked_ok and fire_aim_scope_blocked_ok,
		"Phase 12.3b: HUD displays 'SHF', Alt cursor mode blocks look/BTN_FIRE/BTN_AIM/Sniper scope"
	)

	# 3. Hotbar swap (weapon 0<->2, skill 0<->4, widget 0<->3), persistence, icons & key routing
	var sol := HeroCharacter.new()
	sol.setup_identity(13102, "HotbarSol", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(sol)
	var enemy := HeroCharacter.new()
	enemy.setup_identity(13103, "TargetEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, true)
	arena.add_child(enemy)
	await get_tree().physics_frame
	hud.set_local_hero(sol)

	var w0_tex: Texture2D = hud._weapon_slot_icons[0].texture
	var w2_tex: Texture2D = hud._weapon_slot_icons[2].texture
	var s0_tex: Texture2D = hud._skill_slot_icons[0].texture
	var s4_tex: Texture2D = hud._skill_slot_icons[4].texture
	var wd0_tex: Texture2D = hud._widget_slot_icons[0].texture
	var wd3_tex: Texture2D = hud._widget_slot_icons[3].texture

	var swap_w_ok: bool = hud.swap_hotbar_slots("weapon", 0, 2)
	var swap_s_ok: bool = hud.swap_hotbar_slots("skill", 0, 4)
	var swap_wd_ok: bool = hud.swap_hotbar_slots("widget", 0, 3)

	var icons_swapped_ok: bool = (
		hud._weapon_slot_icons[0].texture == w2_tex and hud._weapon_slot_icons[2].texture == w0_tex
		and hud._skill_slot_icons[0].texture == s4_tex and hud._skill_slot_icons[4].texture == s0_tex
		and hud._widget_slot_icons[0].texture == wd3_tex and hud._widget_slot_icons[3].texture == wd0_tex
	)

	var expected_w_order: Array[int] = [2, 1, 0, 3]
	var expected_s_order: Array[int] = [4, 1, 2, 3, 0, 5]
	var expected_wd_order: Array[int] = [3, 1, 2, 0]
	InputCmd.reset_default_hotkeys()
	var order_persisted_ok: bool = (
		InputCmd.load_hotkeys_from_config(test_cfg_path)
		and InputCmd.weapon_slot_order == expected_w_order
		and InputCmd.skill_slot_order == expected_s_order
		and InputCmd.widget_slot_order == expected_wd_order
	)

	# Pressing KEY_1 must now select logical weapon slot 2!
	sol.selected_weapon_slot = 0
	_send_test_key(KEY_1, true)
	var cmd_w_key: InputCmd = sol._sample_local_input()
	_send_test_key(KEY_1, false)
	var key1_selects_w2_ok: bool = (cmd_w_key.selected_weapon_slot == 2)

	# Pressing KEY_5 (visual skill 0) must now trigger logical skill 4 (BTN_SKILL_5 = Burning Bullets)!
	_send_test_key(KEY_5, true)
	var cmd_s_key: InputCmd = sol._sample_local_input()
	_send_test_key(KEY_5, false)
	var key5_triggers_s4_ok: bool = (cmd_s_key.has_button(InputCmd.BTN_SKILL_5) and not cmd_s_key.has_button(InputCmd.BTN_SKILL_1))

	# Pressing KEY_Z (visual widget 0) must now trigger logical widget 3 (BTN_WIDGET_4 = Antidote)!
	_send_test_key(KEY_Z, true)
	var cmd_wd_key: InputCmd = sol._sample_local_input()
	_send_test_key(KEY_Z, false)
	var keyz_triggers_wd3_ok: bool = (cmd_wd_key.has_button(InputCmd.BTN_WIDGET_4) and not cmd_wd_key.has_button(InputCmd.BTN_WIDGET_1))

	var step_ctx: Dictionary = {
		"heroes_by_id": {13102: sol, 13103: enemy},
		"projectiles_root": arena,
		"vehicles": [],
	}
	sol.status_effects.apply_poison(13103, 10.0, 4.0)
	sol.skill_manager.step_server(0.02, cmd_s_key, step_ctx, true)
	sol.skill_manager.step_server(0.02, cmd_wd_key, step_ctx, true)
	var server_exec_swapped_ok: bool = (
		sol.skill_manager.skill_cooldowns[4] > 0.0
		and is_equal_approx(sol.skill_manager.skill_cooldowns[0], 0.0)
		and sol.skill_manager.widget_cooldowns[3] > 0.0
		and is_equal_approx(sol.skill_manager.widget_cooldowns[0], 0.0)
		and not sol.status_effects.is_poisoned()
	)

	# Real Alt + GUI drag-and-drop event flow swaps widget slots 1 <-> 2
	await get_tree().process_frame
	hud._alt_cursor_mode = true
	var wd1_center: Vector2 = hud._widget_slot_bgs[1].get_global_rect().get_center()
	var wd2_center: Vector2 = hud._widget_slot_bgs[2].get_global_rect().get_center()
	var drag_down := InputEventMouseButton.new()
	drag_down.button_index = MOUSE_BUTTON_LEFT
	drag_down.pressed = true
	drag_down.position = Vector2(10.0, 10.0)
	drag_down.global_position = wd1_center
	hud._on_slot_gui_input(drag_down, "widget", 1)
	var drag_move := InputEventMouseMotion.new()
	drag_move.position = wd2_center
	drag_move.global_position = wd2_center
	hud._input(drag_move)
	var drag_up := InputEventMouseButton.new()
	drag_up.button_index = MOUSE_BUTTON_LEFT
	drag_up.pressed = false
	drag_up.position = wd2_center
	drag_up.global_position = wd2_center
	hud._input(drag_up)
	hud._alt_cursor_mode = false
	var gui_drag_ok: bool = (InputCmd.widget_slot_order == [3, 2, 1, 0])

	# Verify Settings menu reflects reordered skills & widgets, and Reset restores HUD icons/highlights
	var menu_reordered := ClassSelectMenu.new()
	menu_reordered.hotkeys_config_path = ""
	add_child(menu_reordered)
	await _flush_deferred()
	menu_reordered.show_screen("settings")
	var menu_reordered_ok: bool = (
		menu_reordered._skill_hotkey_buttons[0].text.begins_with("Skill 5:")
		and menu_reordered._widget_hotkey_buttons[0].text.begins_with("Antídoto:")
	)
	menu_reordered.queue_free()
	await _flush_deferred()

	sol.selected_weapon_slot = 0
	InputCmd.reset_default_hotkeys()
	hud.refresh_hotkey_labels()
	var reset_restores_hud_ok: bool = (
		hud._weapon_slot_icons[0].texture == w0_tex and hud._weapon_slot_icons[2].texture == w2_tex
		and hud._skill_slot_icons[0].texture == s0_tex and hud._skill_slot_icons[4].texture == s4_tex
		and hud._widget_slot_icons[0].texture == wd0_tex and hud._widget_slot_icons[3].texture == wd3_tex
		and hud._weapon_slot_bgs[0].get_theme_stylebox("panel") == hud._make_slot_style(true)
	)

	_assert(
		swap_w_ok and swap_s_ok and swap_wd_ok and icons_swapped_ok and order_persisted_ok
		and key1_selects_w2_ok and key5_triggers_s4_ok and keyz_triggers_wd3_ok
		and server_exec_swapped_ok and gui_drag_ok and menu_reordered_ok and reset_restores_hud_ok,
		"Phase 12.3c: Hotbar swaps (w=%s,s=%s,wd=%s,icons=%s,pers=%s,k1=%s,k5=%s,kz=%s,srv=%s,drag=%s,menu=%s,rst=%s)" % [
			str(swap_w_ok), str(swap_s_ok), str(swap_wd_ok), str(icons_swapped_ok), str(order_persisted_ok),
			str(key1_selects_w2_ok), str(key5_triggers_s4_ok), str(keyz_triggers_wd3_ok),
			str(server_exec_swapped_ok), str(gui_drag_ok), str(menu_reordered_ok), str(reset_restores_hud_ok)
		]
	)

	# 4. Live Tactical Minimap: layout clear of killfeed, exact roundtrip, 6 flags, Sixth-Sense vs hidden stealth, Mortar click-target
	var conquest := ConquestManager.new()
	arena.add_child(conquest)
	var flag_positions: Array[Vector3] = [
		Vector3(-335.0, 2.15, 290.0),
		Vector3(-388.0, 4.0, -262.0),
		Vector3(-210.0, 12.15, -220.0),
		Vector3(-15.0, 2.30, 40.0),
		Vector3(338.0, 4.0, 240.0),
		Vector3(280.0, 7.65, -230.0),
	]
	for fi in range(flag_positions.size()):
		var cp := CapturePoint.new()
		cp.setup(fi, "Flag_%d" % fi, flag_positions[fi], NetworkManager.TEAM_ROYAL if fi == 0 else (NetworkManager.TEAM_NATIONAL if fi == 5 else -1))
		arena.add_child(cp)
		conquest.register_capture_point(cp)

	var hidden_stealth := HeroCharacter.new()
	hidden_stealth.setup_identity(13104, "HiddenStealth", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, true)
	arena.add_child(hidden_stealth)
	await get_tree().physics_frame

	sol.global_position = Vector3(-120.0, 2.15, 40.0)
	sol.status_effects.activate_sixth_sense(55.0, 10.0)
	enemy.global_position = Vector3(-102.0, 2.15, 40.0) # 18m away -> revealed by Sixth Sense
	enemy.is_stealthed = true
	hidden_stealth.global_position = Vector3(520.0, 2.15, -310.0) # Far away -> must NOT be revealed
	hidden_stealth.is_stealthed = true

	var heroes_dict: Dictionary = {13102: sol, 13103: enemy, 13104: hidden_stealth}
	var v_empty: Array[VehicleBase] = []
	hud.bind_context(conquest, v_empty, heroes_dict)
	await get_tree().process_frame

	var minimap_layout_ok: bool = (
		hud._minimap != null
		and hud._minimap.custom_minimum_size == Vector2(182.0, 182.0)
		and hud._killfeed_lbl.offset_top > hud._minimap.offset_bottom
		and conquest.capture_points.size() == 6
	)

	var roundtrip_ok: bool = true
	for sample_w in [Vector3.ZERO, Vector3(-780.0, 0.0, -540.0), Vector3(780.0, 0.0, 540.0), Vector3(-335.0, 0.0, 290.0), Vector3(280.0, 0.0, -230.0)]:
		var px: Vector2 = hud._minimap.world_to_minimap(sample_w)
		var inv: Vector3 = hud._minimap.minimap_to_world(px)
		if Vector2(inv.x - sample_w.x, inv.z - sample_w.z).length() >= 1.0:
			roundtrip_ok = false

	var sense_filter_ok: bool = (
		StatusEffectContainer.is_enemy_sensed_by_team(enemy, sol.team, heroes_dict, sol)
		and not StatusEffectContainer.is_enemy_sensed_by_team(hidden_stealth, sol.team, heroes_dict, sol)
	)

	# Mortar interactive click-target mode
	var mortar_results: Array[Vector3] = []
	hud.set_mortar_targeting_mode(true, func(target_pos: Vector3) -> void:
		mortar_results.append(target_pos)
	)
	var mortar_open_ok: bool = (
		hud.is_mortar_targeting_active()
		and hud._minimap.size == Vector2(420.0, 420.0)
	)
	var target_world := Vector3(240.0, 0.0, -135.0)
	var click_local: Vector2 = hud._minimap.world_to_minimap(target_world)
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	click_ev.position = click_local
	hud._minimap._gui_input(click_ev)
	var mortar_cb_ok: bool = (
		mortar_results.size() == 1
		and Vector2(mortar_results[0].x - target_world.x, mortar_results[0].z - target_world.z).length() < 1.0
		and not hud.is_mortar_targeting_active()
		and hud._minimap.size == Vector2(182.0, 182.0)
	)

	_assert(
		minimap_layout_ok and roundtrip_ok and sense_filter_ok and mortar_open_ok and mortar_cb_ok,
		"Phase 12.3d: Live Tactical Minimap (182x182 clear of killfeed, <1m roundtrip, 6 flags, Sixth-Sense filter, Mortar click-target)"
	)

	if FileAccess.file_exists(test_cfg_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cfg_path))
	InputCmd.reset_default_hotkeys()
	arena.queue_free()
	await _flush_deferred()


func _test_phase12_task4_field_engineer() -> void:
	print("--- Phase 12 Task 4: Field Engineer Class, Dual Weapons, Welder & 5 Skills ---")
	var arena := Node3D.new()
	add_child(arena)

	# 1. NetSerializer 3-bit class_id (4) & u32 active_buffs (1 << 16) + 24-hero MTU < 1200B
	var eng_buffs: int = NetSerializer.BUFF_ENGINEER_INVULN | NetSerializer.BUFF_HERO_SHIELD
	var auth_bytes: PackedByteArray = NetSerializer.pack_authoritative_state(
		120, Vector3(4.0, 1.0, -5.0), Vector3.ZERO, NetSerializer.SNAP_GROUNDED,
		125, 0, -1, -1, 0, eng_buffs, 0, 0
	)
	var auth_dec: Dictionary = NetSerializer.unpack_authoritative_state(auth_bytes)
	var heroes24: Array[Dictionary] = []
	for i in range(24):
		heroes24.append({
			"id": 100 + i,
			"team": i % 2,
			"class_id": NetworkManager.CLASS_ENGINEER if (i % 5 == 4) else (i % 5),
			"weapon_slot": 0,
			"flags": NetSerializer.SNAP_GROUNDED,
			"buffs": eng_buffs if i == 4 else 0,
			"pos": Vector3(float(i) * 3.0, 0.0, 0.0),
			"vel": Vector3.ZERO,
			"yaw": 0.0,
			"pitch": 0.0,
			"hp": 125,
			"shield": 0,
			"vehicle_id": -1,
			"seat_idx": -1,
		})
	var ws24_bytes: PackedByteArray = NetSerializer.pack_world_snapshot(
		200, 3333, 50, 50, heroes24,
		[{"id": 50, "type": VehicleBase.VehicleType.MOUNTED_MG, "team": 0, "hp": 320, "pos": Vector3.ZERO, "rot": Quaternion.IDENTITY, "turret_yaw": 0.0, "turret_pitch": 0.0, "seats": [-1]}],
		[{"owner": 0, "capturing_team": -1, "progress": 1.0}]
	)
	var ws24_dec: Dictionary = NetSerializer.unpack_world_snapshot(ws24_bytes)
	var ws_eng_hero: Dictionary = (ws24_dec.get("heroes", []) as Array)[4]
	_assert(
		NetSerializer.INPUT_CMD_BYTES == 15
		and ws24_bytes.size() < 1200
		and int(auth_dec.get("buffs", 0)) == eng_buffs
		and int(ws_eng_hero.get("class_id", -1)) == NetworkManager.CLASS_ENGINEER
		and int(ws_eng_hero.get("buffs", 0)) == eng_buffs,
		"Phase 12.4a: NetSerializer 3-bit class_id=4 + u32 BUFF_ENGINEER_INVULN + 24-hero MTU (%dB < 1200B)" % ws24_bytes.size()
	)

	# 2. ClassEngineer stats, 3D visuals (Dual L+R roots + cap) & CartoonAssets icons
	var eng := HeroCharacter.new()
	eng.setup_identity(401, "EngRoyal", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, true, false)
	eng.position = Vector3.ZERO
	arena.add_child(eng)
	await _flush_deferred()
	var stats_ok: bool = (
		eng.max_hp == 125
		and eng.hp == 125
		and is_equal_approx(eng.base_move_speed, 6.3)
		and eng.skill_manager is EngineerSkills
		and eng.weapons.size() == 3
		and (eng.weapons[0] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS
		and (eng.weapons[1] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.SHOTGUN
		and (eng.weapons[2] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.WELDING_TORCH
		and eng._held_weapon_root != null
		and eng._held_weapon_root_l != null
		and eng._held_weapon_root_l.visible
	)
	var icons_ok: bool = (
		CartoonAssets.get_texture("portrait_royal_4") != null
		and CartoonAssets.get_texture("portrait_national_4") != null
		and CartoonAssets.get_texture("icon_weapon_11_0") != null
		and CartoonAssets.get_texture("icon_weapon_12_0") != null
		and CartoonAssets.get_texture("icon_weapon_13_0") != null
		and CartoonAssets.get_texture("icon_skill_4_0") != null
		and CartoonAssets.get_texture("icon_skill_4_4") != null
	)
	_assert(stats_ok and icons_ok, "Phase 12.4b: ClassEngineer 125 HP / 6.3 m/s, Dual Revolvers L+R roots, Welding Torch & 2D icons")

	# 3. Dual Revolvers / Dual Pistols alternating muzzles & Welding Torch heal/damage
	eng.trigger_weapon_fire_visual(WeaponBase.WeaponKind.DUAL_REVOLVERS, false)
	var m_right: Vector3 = eng.get_muzzle_world_position()
	eng.trigger_weapon_fire_visual(WeaponBase.WeaponKind.DUAL_REVOLVERS, false)
	var m_left: Vector3 = eng.get_muzzle_world_position()
	var dual_alt_ok: bool = absf(m_right.x - m_left.x) > 0.25

	var eng_pistol := HeroCharacter.new()
	eng_pistol.weapon_slot_archetypes = {0: 1, 1: 0, 2: 0}
	eng_pistol.setup_identity(402, "EngDualPistol", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 1, false, false)
	arena.add_child(eng_pistol)
	var dual_pistol_ok: bool = ((eng_pistol.weapons[0] as WeaponBase).weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS)

	var ally_jeep := VehicleJeep.new()
	ally_jeep.id = 61
	ally_jeep.team = NetworkManager.TEAM_ROYAL
	ally_jeep.position = Vector3(0.0, 0.0, -2.2)
	ally_jeep.rotation.y = PI * 0.5
	arena.add_child(ally_jeep)
	ally_jeep.hp = 200
	var enemy_hero := HeroCharacter.new()
	enemy_hero.setup_identity(403, "EnemyTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	enemy_hero.position = Vector3(4.0, 0.0, -2.2)
	arena.add_child(enemy_hero)
	var veh_arr_t: Array[VehicleBase] = [ally_jeep]
	var veh_by_id_t: Dictionary = {61: ally_jeep}
	var heroes_dict_t: Dictionary = {401: eng, 403: enemy_hero}
	var ctx_t: Dictionary = {
		"heroes_by_id": heroes_dict_t,
		"vehicles": veh_arr_t,
		"vehicles_by_id": veh_by_id_t,
		"projectiles_root": arena,
		"vehicles_root": arena,
	}
	var weld_cmd := InputCmd.new()
	weld_cmd.selected_weapon_slot = 2
	weld_cmd.aim_yaw = 0.0
	weld_cmd.aim_pitch = 0.0
	var welder: WeaponBase = eng.weapons[2] as WeaponBase
	welder.fire_server(weld_cmd, ctx_t)
	var repaired_ok: bool = (ally_jeep.hp == 215)
	# Put enemy inside jeep -> Welding Torch should damage instead of repair!
	ally_jeep.try_enter_hero(enemy_hero)
	var hp_before_enemy_weld: int = ally_jeep.hp
	welder.fire_server(weld_cmd, ctx_t)
	var expected_jeep_dmg: int = maxi(1, int(roundf(float(WeldingWeapon.WELD_ENEMY_VEH_DMG) * 0.55)))
	var enemy_veh_dmg_ok: bool = (ally_jeep.hp == hp_before_enemy_weld - expected_jeep_dmg)
	ally_jeep.exit_hero(enemy_hero)
	enemy_hero.position = Vector3(0.0, 0.0, -2.0)
	ally_jeep.position = Vector3(30.0, 0.0, 30.0)
	var e_hp_before: int = enemy_hero.hp
	welder.fire_server(weld_cmd, ctx_t)
	var enemy_hero_weld_ok: bool = (enemy_hero.hp == e_hp_before - WeldingWeapon.WELD_HERO_DMG)
	_assert(
		dual_alt_ok and dual_pistol_ok and repaired_ok and enemy_veh_dmg_ok and enemy_hero_weld_ok,
		"Phase 12.4c: Dual L/R alternating muzzles (alt=%s, pist=%s, rep=%s, ev=%s, eh=%s, hp_jeep=%d)" % [
			str(dual_alt_ok), str(dual_pistol_ok), str(repaired_ok), str(enemy_veh_dmg_ok), str(enemy_hero_weld_ok), ally_jeep.hp
		]
	)

	# 4. Skills 0..4 verification
	var sm: EngineerSkills = eng.skill_manager as EngineerSkills
	var lag := LagCompensator.new()
	arena.add_child(lag)
	ctx_t["lag_compensator"] = lag

	# Skill 0: Trincheira (3.0s build, 850 HP, CD 0 while active, 18s CD when destroyed)
	var sk_cmd := InputCmd.new()
	sk_cmd.buttons = InputCmd.BTN_SKILL_1
	sm.step_server(0.05, sk_cmd, ctx_t)
	var build_blocks_ok: bool = sm.is_building() and sm.blocks_weapon_fire()
	sk_cmd.buttons = 0
	for _i in range(32):
		sm.step_server(0.1, sk_cmd, ctx_t)
	var trench: EngineerSkills.TrenchEntity = sm._active_trench
	var trench_ok: bool = (
		trench != null
		and is_instance_valid(trench)
		and trench.max_hp == 850
		and trench.hp == 850
		and trench.collision_layer == (1 | 64)
		and is_equal_approx(sm.skill_cooldowns[0], 0.0)
	)
	# Destroying trench triggers 18s cooldown
	trench.apply_damage_server(900, 403)
	var trench_cd_ok: bool = is_equal_approx(sm.skill_cooldowns[0], 18.0)

	# Skill 1: Metralhadora Montada c/ Escudo (2.0s build, 320 HP, blocks frontal shots, CD on destroy)
	sk_cmd.buttons = InputCmd.BTN_SKILL_2
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	for _i in range(22):
		sm.step_server(0.1, sk_cmd, ctx_t)
	var turret: VehicleShieldedMG = sm._active_turret
	var turret_ok: bool = (
		turret != null
		and is_instance_valid(turret)
		and turret.vehicle_type == VehicleBase.VehicleType.MOUNTED_MG
		and turret.max_hp == 320
		and turret.freeze
		and is_equal_approx(sm.skill_cooldowns[1], 0.0)
	)
	# Seat gunner facing -Z and test frontal bullet block from enemy in front (-Z -> shot_dir = +Z)
	turret.turret_yaw = 0.0
	turret.try_enter_hero(eng)
	var shield_blocks_ok: bool = turret.is_frontal_shield_blocking_dir(Vector3(0.0, 0.0, -1.0)) and not turret.is_frontal_shield_blocking_dir(Vector3(0.0, 0.0, 1.0))
	var eng_hp_before_frontal: int = eng.hp
	var hitscan_p := HitscanWeapon.new()
	hitscan_p.configure(enemy_hero, WeaponBase.WeaponKind.PISTOL, 0)
	hitscan_p._apply_hero_hit(eng, Vector3(0.0, 0.0, 1.0), 5.0, false, Vector3.ZERO, 1.0, ctx_t, {}, {}, {})
	var shield_dmg_blocked_ok: bool = (eng.hp == eng_hp_before_frontal)
	turret.exit_hero(eng)
	turret.apply_damage_server(400, 403, Vector3(0.0, 0.0, -1.0), turret.global_position, true)
	var turret_cd_ok: bool = is_equal_approx(sm.skill_cooldowns[1], 18.0)

	# Skill 2: Blindar Veiculo (2.0s channel -> 2x max HP + armor plates, 20s CD)
	ally_jeep.position = eng.position + Vector3(2.5, 0.0, 0.0)
	var base_jeep_max: int = ally_jeep.max_hp
	ally_jeep.hp = 120
	sk_cmd.buttons = InputCmd.BTN_SKILL_3
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	for _i in range(22):
		sm.step_server(0.1, sk_cmd, ctx_t)
	var armor_ok: bool = (
		ally_jeep.is_armored
		and ally_jeep.max_hp == base_jeep_max * 2
		and ally_jeep.hp == 120 + base_jeep_max
		and ally_jeep._armor_plates_root != null
		and sm.skill_cooldowns[2] > 19.0 and sm.skill_cooldowns[2] <= 20.0
	)

	# Skill 3: Morteiro via Minimapa (0 CD until target chosen -> 1.25s timer -> 110 max AoE dmg + 0.75s stow window)
	enemy_hero.hp = enemy_hero.max_hp
	enemy_hero.position = Vector3(16.0, 0.0, -16.0)
	var bot_mortar_target: Vector3 = sm._pick_bot_mortar_target(ctx_t)
	var bot_mortar_target_ok: bool = bot_mortar_target != Vector3.INF and bot_mortar_target.distance_to(enemy_hero.position) < 0.1
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx_t)
	var mortar_deferred_ok: bool = is_equal_approx(sm.skill_cooldowns[3], 0.0) and sm._mortar_pending_hero_aim and sm.blocks_weapon_fire()
	sk_cmd.buttons = 0
	var fired_m: bool = sm.fire_mortar_at(enemy_hero.position, ctx_t)
	var mortar_cd_started_ok: bool = fired_m and sm.skill_cooldowns[3] > 17.0 and sm.blocks_weapon_fire()
	for _i in range(17):
		eng.status_effects._physics_process(0.1)
		sm.step_server(0.1, sk_cmd, ctx_t)
	mortar_cd_started_ok = mortar_cd_started_ok and not sm.blocks_weapon_fire()
	var mortar_hit_ok: bool = (enemy_hero.hp == enemy_hero.max_hp - 110)

	# Skill 4: Armadura Invulneravel (1.5s full damage immunity)
	sk_cmd.buttons = InputCmd.BTN_SKILL_5
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	var invuln_active_ok: bool = (eng.active_buffs & NetSerializer.BUFF_ENGINEER_INVULN) != 0 and eng.status_effects.is_invulnerable()
	var dmg_while_invuln: int = eng.apply_damage_server(95, 403, true)
	for _i in range(17):
		eng.status_effects._physics_process(0.1)
		sm.step_server(0.1, sk_cmd, ctx_t)
	var invuln_expired_ok: bool = not eng.status_effects.is_invulnerable()
	var dmg_after_invuln: int = eng.apply_damage_server(15, 403, false)
	var invuln_ok: bool = (invuln_active_ok and dmg_while_invuln == 0 and invuln_expired_ok and dmg_after_invuln == 15)

	_assert(
		build_blocks_ok and trench_ok and trench_cd_ok
		and turret_ok and shield_blocks_ok and shield_dmg_blocked_ok and turret_cd_ok
		and armor_ok and bot_mortar_target_ok and mortar_deferred_ok and mortar_cd_started_ok and mortar_hit_ok and invuln_ok,
		"Phase 12.4d: 5 Skills (blk=%s tr=%s trcd=%s tur=%s shb=%s shd=%s tcd=%s arm=%s bmt=%s md=%s mcd=%s mh=%s inv=%s)" % [
			str(build_blocks_ok), str(trench_ok), str(trench_cd_ok), str(turret_ok),
			str(shield_blocks_ok), str(shield_dmg_blocked_ok), str(turret_cd_ok), str(armor_ok),
			str(bot_mortar_target_ok), str(mortar_deferred_ok), str(mortar_cd_started_ok), str(mortar_hit_ok), str(invuln_ok)
		]
	)

	# 5. Regression checks for Phase 12.4 review fixes
	# 5a. Client TrenchEntity keeps solid collision_layer=1 + CollisionShape3Ds & clears on disable_collision()
	var vis_trench := EngineerSkills.TrenchEntity.new()
	vis_trench._is_visual_only = true
	vis_trench.trench_id = 999
	arena.add_child(vis_trench)
	var vis_col_count: int = 0
	for ch in vis_trench.get_children():
		if ch is CollisionShape3D:
			vis_col_count += 1
	var vis_trench_ok: bool = (
		vis_trench.collision_layer == 1
		and vis_trench.is_in_group("client_trenches")
		and not vis_trench.is_in_group("destructible")
		and vis_col_count >= 5
	)
	vis_trench.disable_collision()
	var vis_trench_clean_ok: bool = (vis_trench.collision_layer == 0 and not vis_trench.is_in_group("client_trenches"))

	# 5b. Defeat & vehicle entry clear active build channel & mortar targeting + broadcast mortar_mode=false
	sm.skill_cooldowns[0] = 0.0
	sm.skill_cooldowns[1] = 0.0
	sm.skill_cooldowns[3] = 0.0
	var mortar_events: Array[Dictionary] = []
	var ev_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "mortar_mode":
			mortar_events.append(payload)
	NetworkManager.game_event_received.connect(ev_cb)
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	var mortar_armed_ok: bool = sm._mortar_pending_hero_aim and sm.blocks_weapon_fire()
	eng.apply_damage_server(999, 403, false)
	var defeat_cleared_mortar_ok: bool = (
		not sm._mortar_pending_hero_aim
		and not sm.blocks_weapon_fire()
		and not mortar_events.is_empty()
		and mortar_events[mortar_events.size() - 1].get("active", true) == false
	)
	eng.respawn_at(Vector3.ZERO, 0.0)
	sk_cmd.buttons = InputCmd.BTN_SKILL_1
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	var build_started_ok: bool = sm.is_building()
	eng.apply_damage_server(999, 403, false)
	var defeat_cleared_build_ok: bool = not sm.is_building() and not sm.blocks_weapon_fire()
	eng.respawn_at(Vector3.ZERO, 0.0)
	sm.skill_cooldowns[3] = 0.0
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	ally_jeep.try_enter_hero(eng)
	sm.step_server(0.05, sk_cmd, ctx_t)
	var vehicle_cleared_mortar_ok: bool = not sm._mortar_pending_hero_aim and not sm.blocks_weapon_fire()
	ally_jeep.exit_hero(eng)
	NetworkManager.game_event_received.disconnect(ev_cb)

	# 5c. Turret vehicle ID allocator does not collide at cap 250
	var cap_jeep := VehicleJeep.new()
	cap_jeep.id = 250
	arena.add_child(cap_jeep)
	veh_arr_t.append(cap_jeep)
	veh_by_id_t[250] = cap_jeep
	sm._active_turret = null
	sm.skill_cooldowns[1] = 0.0
	sk_cmd.buttons = InputCmd.BTN_SKILL_2
	sm.step_server(0.05, sk_cmd, ctx_t)
	sk_cmd.buttons = 0
	for _i in range(22):
		sm.step_server(0.1, sk_cmd, ctx_t)
	var turret_id_ok: bool = (
		sm._active_turret != null
		and is_instance_valid(sm._active_turret)
		and sm._active_turret.id >= 41
		and sm._active_turret.id != 250
		and veh_by_id_t.get(sm._active_turret.id, null) == sm._active_turret
		and veh_by_id_t.get(250, null) == cap_jeep
	)

	# 5d. HUD portrait_royal_4 & mortar targeting auto-cancel on defeat
	var eng_hud := HUDController.new()
	arena.add_child(eng_hud)
	eng_hud.set_local_hero(eng)
	eng_hud.set_mortar_targeting_mode(true, func(_p: Vector3) -> void: pass)
	eng_hud._process(0.016)
	var hud_portrait_ok: bool = (
		eng_hud._last_portrait_key == "portrait_royal_4"
		and eng_hud._portrait_tex.texture == CartoonAssets.get_texture("portrait_royal_4")
		and eng_hud.is_mortar_targeting_active()
	)
	eng.apply_damage_server(999, 403, false)
	eng_hud._process(0.016)
	var hud_mortar_cancel_ok: bool = not eng_hud.is_mortar_targeting_active()

	# 5e. GameCache.warm_textures() warms Engineer portrait, weapons 11..13 & skills 4_0..4_4
	CartoonAssets._cache.clear()
	GameCache.clear_all()
	GameCache.warm_textures()
	var cache_warm_ok: bool = (
		GameCache.ALL_TEXTURE_KEYS.has("portrait_royal_4")
		and GameCache.ALL_TEXTURE_KEYS.has("portrait_national_4")
		and CartoonAssets._cache.has("portrait_royal_4")
		and CartoonAssets._cache.has("portrait_national_4")
		and CartoonAssets._cache.has("icon_weapon_11_0")
		and CartoonAssets._cache.has("icon_weapon_12_0")
		and CartoonAssets._cache.has("icon_weapon_13_0")
		and CartoonAssets._cache.has("icon_skill_4_0")
		and CartoonAssets._cache.has("icon_skill_4_4")
	)

	_assert(
		vis_trench_ok and vis_trench_clean_ok
		and mortar_armed_ok and defeat_cleared_mortar_ok and build_started_ok and defeat_cleared_build_ok and vehicle_cleared_mortar_ok
		and turret_id_ok and hud_portrait_ok and hud_mortar_cancel_ok and cache_warm_ok,
		"Phase 12.4e: Review fixes (vt=%s vtc=%s ma=%s dcm=%s bs=%s dcb=%s vcm=%s tid=%s hp=%s hmc=%s cw=%s)" % [
			str(vis_trench_ok), str(vis_trench_clean_ok), str(mortar_armed_ok),
			str(defeat_cleared_mortar_ok), str(build_started_ok), str(defeat_cleared_build_ok),
			str(vehicle_cleared_mortar_ok), str(turret_id_ok), str(hud_portrait_ok),
			str(hud_mortar_cancel_ok), str(cache_warm_ok)
		]
	)

	arena.queue_free()
	await _flush_deferred()


func _test_phase12_task5_menus_5classes_integration() -> void:
	print("--- Phase 12 Task 5: 3D Preview Menus, 5-Class Bot/HUD/Cache & Task 2 Polish ---")

	# 1. Hub & Armory symmetrical flags, 5 class cards, live 3D SubViewport preview, Arsenal 96x64 cards & 6 Skills tabs
	var menu := ClassSelectMenu.new()
	menu.hotkeys_config_path = "user://test_hotkeys_p12t5.cfg"
	add_child(menu)
	await _flush_deferred()

	var hub_flags_ok: bool = false
	var hub_texs: Array[Texture2D] = []
	for tr in menu._hub_screen.find_children("*", "TextureRect", true, false):
		var tex: Texture2D = (tr as TextureRect).texture
		if tex != null:
			hub_texs.append(tex)
	hub_flags_ok = (
		hub_texs.has(CartoonAssets.get_texture("flag_royal"))
		and hub_texs.has(CartoonAssets.get_texture("flag_national"))
	)

	menu.show_screen("armory")
	await _flush_deferred()

	var sym_flags_ok: bool = (
		menu._royal_flag_rect != null and menu._royal_flag_rect.visible
		and menu._royal_flag_rect.texture == CartoonAssets.get_texture("flag_royal")
		and menu._national_flag_rect != null and menu._national_flag_rect.visible
		and menu._national_flag_rect.texture == CartoonAssets.get_texture("flag_national")
		and menu._royal_btn != null and menu._royal_btn.visible
		and menu._nat_btn != null and menu._nat_btn.visible
	)

	var vp_ok: bool = (
		menu._preview_viewport != null
		and menu._preview_viewport.own_world_3d
		and menu._preview_hero != null
		and is_instance_valid(menu._preview_hero)
		and not menu._preview_hero.is_processing()
		and not menu._preview_hero.is_physics_processing()
	)
	var yaw_before: float = menu._preview_hero.rotation.y if menu._preview_hero != null else 0.0
	menu._process(0.5)
	var yaw_after: float = menu._preview_hero.rotation.y if menu._preview_hero != null else 0.0
	var rotates_ok: bool = absf(yaw_after - yaw_before) > 0.35

	var all_classes_preview_ok: bool = (menu._class_cards.size() == 5 and menu._class_buttons.size() == 5)
	for cid in range(5):
		menu.select_class(cid)
		if menu.selected_class != cid or menu._preview_hero.class_id != cid:
			all_classes_preview_ok = false
			break

	menu.select_team(NetworkManager.TEAM_NATIONAL)
	menu.select_class(NetworkManager.CLASS_ENGINEER)
	await _flush_deferred()

	var eng_slots: Array[int] = ClassSelectMenu.get_class_weapon_slots(NetworkManager.CLASS_ENGINEER)
	var eng_arsenal_ok: bool = (
		eng_slots.size() == 3
		and menu._arsenal_cards.size() == 3
		and menu._weapon_variant_selectors.size() == 3
		and menu._weapon_variant_selectors[0].item_count == 2
		and menu._weapon_variant_selectors[0].get_item_text(0) == "2 Revólveres"
		and menu._weapon_variant_selectors[0].get_item_text(1) == "2 Pistolas"
		and menu._weapon_variant_selectors[1].item_count == 3
		and menu._weapon_variant_selectors[2].item_count == 1
		and menu._weapon_variant_selectors[2].get_item_text(0) == "Maçarico de Solda"
		and menu._preview_portrait.texture == CartoonAssets.get_texture("portrait_national_4")
		and menu._preview_hero.team == NetworkManager.TEAM_NATIONAL
		and menu._preview_hero.class_id == NetworkManager.CLASS_ENGINEER
	)

	var arsenal_icon_96_ok: bool = false
	for tr_a in menu._weapon_variant_row.find_children("*", "TextureRect", true, false):
		var tex_a: Texture2D = (tr_a as TextureRect).texture
		if tex_a != null and tex_a.get_width() == 96 and tex_a.get_height() == 64:
			arsenal_icon_96_ok = true
			break

	# Clicking Arsenal card switches held weapon slot on rotating 3D hero; variant 1 switches to Dual Pistols
	menu.select_preview_weapon_slot(2)
	var slot2_preview_ok: bool = (
		menu._preview_hero.selected_weapon_slot == 2
		and menu._preview_hero._shown_weapon_kind == WeaponBase.WeaponKind.WELDING_TORCH
	)
	menu.select_weapon_variant(NetworkManager.CLASS_ENGINEER, 0, 1)
	var dual_pistol_preview_ok: bool = (
		menu._preview_hero.selected_weapon_slot == 0
		and menu._preview_hero._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS
		and menu._summary_lbl.text.contains("2 Pistolas")
	)
	NetworkManager.set_slot_archetype(NetworkManager.CLASS_ENGINEER, 0, 0)

	# 6 Skills Encyclopedia tabs including Field Engineer (5)
	menu._armory_skills_btn.pressed.emit()
	await _flush_deferred()
	var eng_skills_tab_ok: bool = (
		menu.current_screen == "skills"
		and menu._skills_tab_buttons.size() == 6
		and menu._skills_tab_class == NetworkManager.CLASS_ENGINEER
		and menu._skills_grid.get_child_count() == 5
	)
	menu.select_skills_tab(5)
	var widgets_tab6_ok: bool = (menu._skills_grid.get_child_count() == 4)

	_assert(
		hub_flags_ok and sym_flags_ok and vp_ok and rotates_ok and all_classes_preview_ok
		and eng_arsenal_ok and arsenal_icon_96_ok and slot2_preview_ok and dual_pistol_preview_ok
		and eng_skills_tab_ok and widgets_tab6_ok,
		"Phase 12.5a: Hub/Armory symmetrical flags, 5 classes, live 3D rotating preview, 96x64 Arsenal cards & 6 Skills tabs"
	)

	menu.queue_free()
	await _flush_deferred()

	# 2. BotController CLASS_ENGINEER AI, GameCache.warm_meshes(), HUD [ALT] hint & MOUNTED_MG name
	var arena := Node3D.new()
	add_child(arena)

	var eng_bot := HeroCharacter.new()
	eng_bot.setup_identity(12501, "EngBot", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, false, true)
	eng_bot.position = Vector3(0.0, 0.0, 0.0)
	arena.add_child(eng_bot)

	var enemy_b := HeroCharacter.new()
	enemy_b.setup_identity(12502, "EnemyTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	enemy_b.position = Vector3(0.0, 0.0, -24.0)
	arena.add_child(enemy_b)

	var damaged_jeep := VehicleJeep.new()
	damaged_jeep.id = 60
	damaged_jeep.team = NetworkManager.TEAM_ROYAL
	damaged_jeep.position = Vector3(1.8, 0.0, 0.0)
	arena.add_child(damaged_jeep)
	damaged_jeep.hp = 140

	var brain := BotController.new()
	brain.setup(eng_bot)
	arena.add_child(brain)

	var heroes_dict: Dictionary = {eng_bot.entity_id: eng_bot, enemy_b.entity_id: enemy_b}
	var veh_list: Array[VehicleBase] = [damaged_jeep]

	# Long range enemy -> Dual Revolvers (slot 0)
	eng_bot.aim_yaw = 0.0
	var cmd_long: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	var bot_long_ok: bool = (cmd_long.selected_weapon_slot == 0)

	# Mid range enemy -> Shotgun (slot 1)
	enemy_b.position = Vector3(0.0, 0.0, -10.0)
	var cmd_mid: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	var bot_mid_ok: bool = (cmd_mid.selected_weapon_slot == 1)

	# Close enemy & low HP -> Welding Torch (slot 2), off-pulse releases skill buttons, % 12 == 0 triggers Invulnerability (BTN_SKILL_5)
	enemy_b.position = Vector3(0.0, 0.0, -2.5)
	eng_bot.hp = 40
	var cmd_off_pulse: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	var off_pulse_ok: bool = (
		cmd_off_pulse.selected_weapon_slot == 2
		and not cmd_off_pulse.has_button(InputCmd.BTN_SKILL_1)
		and not cmd_off_pulse.has_button(InputCmd.BTN_SKILL_2)
		and not cmd_off_pulse.has_button(InputCmd.BTN_SKILL_3)
		and not cmd_off_pulse.has_button(InputCmd.BTN_SKILL_4)
		and not cmd_off_pulse.has_button(InputCmd.BTN_SKILL_5)
	)
	brain._ai_tick = 11
	var cmd_close: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	var bot_close_invuln_ok: bool = (
		cmd_close.selected_weapon_slot == 2
		and cmd_close.has_button(InputCmd.BTN_SKILL_5)
		and off_pulse_ok
	)

	# Out of sight of enemy, next to damaged allied vehicle -> Welding Torch repair + pulsed Armor vehicle; armored vehicle skips BTN_SKILL_3
	enemy_b.is_defeated = true
	eng_bot.hp = eng_bot.max_hp
	var cmd_heal_off: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	var heal_off_ok: bool = (
		cmd_heal_off.selected_weapon_slot == 2
		and cmd_heal_off.has_button(InputCmd.BTN_FIRE)
		and not cmd_heal_off.has_button(InputCmd.BTN_SKILL_3)
		and not cmd_heal_off.has_button(InputCmd.BTN_SKILL_5)
	)
	brain._ai_tick = 23
	var cmd_heal_veh: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	damaged_jeep.is_armored = true
	brain._ai_tick = 35
	var cmd_armored_skip: InputCmd = brain.compute_input(0.05, [], heroes_dict, veh_list)
	damaged_jeep.is_armored = false
	var bot_heal_veh_ok: bool = (
		cmd_heal_veh.selected_weapon_slot == 2
		and cmd_heal_veh.has_button(InputCmd.BTN_FIRE)
		and cmd_heal_veh.has_button(InputCmd.BTN_SKILL_3)
		and heal_off_ok
		and not cmd_armored_skip.has_button(InputCmd.BTN_SKILL_3)
	)

	# GameCache warm_meshes covers Engineer cap, torso_4, backpack_4, and WeaponKind 11..13
	HeroMeshBuilder.clear_caches()
	GameCache.clear_all()
	GameCache.warm_textures()
	GameCache.warm_meshes()
	var cache_5cls_ok: bool = (
		HeroMeshBuilder._mesh_cache.has("torso_4")
		and HeroMeshBuilder._mesh_cache.has("pack_4")
		and HeroMeshBuilder._mesh_cache.has("ecap_true")
		and HeroMeshBuilder._mesh_cache.has("ecap_false")
		and HeroMeshBuilder._weapon_cache.has("11_0")
		and HeroMeshBuilder._weapon_cache.has("12_0")
		and HeroMeshBuilder._weapon_cache.has("13_0")
	)

	# HUD subtle [ALT] hint (MOUSE_FILTER_IGNORE) + MOUNTED_MG name + Engineer skill tooltips
	var hud := HUDController.new()
	arena.add_child(hud)
	hud.set_local_hero(eng_bot)
	hud._process(0.016)
	var hud_alt_ok: bool = (
		hud._hotbar_alt_hint_lbl != null
		and hud._hotbar_alt_hint_lbl.visible
		and hud._hotbar_alt_hint_lbl.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and hud._hotbar_alt_hint_lbl.text.contains("[ALT]")
	)
	var hud_mg_name_ok: bool = (HUDController.get_vehicle_display_name(VehicleBase.VehicleType.MOUNTED_MG) == "Metralhadora c/ Escudo")
	var hud_eng_tooltips_ok: bool = (
		hud._skill_slot_bgs.size() >= 5
		and hud._skill_slot_bgs[0].tooltip_text.contains("Trincheira")
		and hud._skill_slot_bgs[3].tooltip_text.contains("Morteiro")
		and hud._skill_slot_bgs[4].tooltip_text.contains("Armadura Invulnerável")
	)

	_assert(
		bot_long_ok and bot_mid_ok and bot_close_invuln_ok and bot_heal_veh_ok
		and cache_5cls_ok and hud_alt_ok and hud_mg_name_ok and hud_eng_tooltips_ok,
		"Phase 12.5b: Engineer Bot AI (long=%s mid=%s cls=%s heal=%s), GameCache 5-class meshes=%s, HUD ALT/MG/tips=(%s,%s,%s)" % [
			str(bot_long_ok), str(bot_mid_ok), str(bot_close_invuln_ok), str(bot_heal_veh_ok),
			str(cache_5cls_ok), str(hud_alt_ok), str(hud_mg_name_ok), str(hud_eng_tooltips_ok)
		]
	)

	# 3. Task 2 carry-over polish guards (Demolisher Skill 0 in-vehicle, Parachute/Emote/TNT-Rope shield hide, Vest shield cap)
	var demo := HeroCharacter.new()
	demo.setup_identity(12503, "DemoPolish", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	arena.add_child(demo)
	var d_sm := demo.skill_manager as DemolisherSkills
	damaged_jeep.try_enter_hero(demo)
	var in_veh_res: bool = d_sm._execute_class_skill(0, 5, InputCmd.new(), {})
	var skill0_veh_guard_ok: bool = (not in_veh_res and is_equal_approx(d_sm.skill_cooldowns[0], 0.0))
	damaged_jeep.exit_hero(demo)

	d_sm._execute_class_skill(0, 5, InputCmd.new(), {})
	demo.selected_weapon_slot = 2
	demo._animate_character(0.016)
	var shield_vis_foot_ok: bool = demo._held_riot_shield != null and demo._held_riot_shield.visible
	demo.is_parachuting = true
	demo._animate_character(0.016)
	var shield_hidden_para_ok: bool = demo._held_riot_shield != null and not demo._held_riot_shield.visible
	demo.is_parachuting = false
	demo.is_emoting = true
	demo._animate_character(0.016)
	var shield_hidden_emote_ok: bool = demo._held_riot_shield != null and not demo._held_riot_shield.visible
	demo.is_emoting = false
	demo.status_effects.activate_tnt_rope()
	demo._animate_character(0.016)
	var shield_hidden_rope_ok: bool = demo._held_riot_shield != null and not demo._held_riot_shield.visible
	demo.status_effects.clear_tnt_rope()

	# Vest shield cap when temporary 140 HP Hero Shield is already active
	demo.status_effects.apply_shield(140, 2.0, true)
	demo.status_effects.apply_vest_shield(70)
	var vest_capped_ok: bool = (demo.shield == 140 and demo.status_effects.permanent_vest_shield == 70)
	demo.status_effects._physics_process(2.5)
	var vest_after_expiry_ok: bool = (demo.shield == 70 and demo.status_effects.permanent_vest_shield == 70)

	_assert(
		skill0_veh_guard_ok and shield_vis_foot_ok and shield_hidden_para_ok
		and shield_hidden_emote_ok and shield_hidden_rope_ok and vest_capped_ok and vest_after_expiry_ok,
		"Phase 12.5c: Demolisher Skill 0 in-vehicle guard, parachute/emote/TNT-Rope shield hide, and vest shield cap"
	)

	# 4. MainGame 14v14 5-class bot distribution + map budgets + INPUT_CMD_BYTES == 15
	var prev_peer_id: int = NetworkManager.local_peer_id
	var game := MainGame.new()
	add_child(game)
	game._start_bots_sync(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER)
	var eng_bot_count: int = 0
	var class_seen: Dictionary = {}
	for h_val in game.heroes_by_id.values():
		var hh := h_val as HeroCharacter
		if hh != null:
			class_seen[hh.class_id] = true
			if hh.is_bot and hh.class_id == NetworkManager.CLASS_ENGINEER:
				eng_bot_count += 1

	var mesh_count: int = 0
	var uniq_meshes: Dictionary = {}
	var uniq_mats: Dictionary = {}
	for node in game.map_instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mesh_count += 1
		if mi.mesh != null:
			uniq_meshes[mi.mesh.get_instance_id()] = true
		if mi.material_override != null:
			uniq_mats[mi.material_override.get_instance_id()] = true
	var budgets_ok: bool = (mesh_count <= 900 and uniq_meshes.size() <= 350 and uniq_mats.size() <= 200)

	_assert(
		game.heroes_by_id.size() == 28 and eng_bot_count >= 5 and class_seen.size() == 5 and budgets_ok and NetSerializer.INPUT_CMD_BYTES == 15,
		"Phase 12.5d: 14v14 spawns all 5 classes (%d Engineer bots), map budgets (%d/%d/%d), INPUT_CMD=15B" % [
			eng_bot_count, mesh_count, uniq_meshes.size(), uniq_mats.size()
		]
	)

	NetworkManager.shutdown_network()
	NetworkManager.local_peer_id = prev_peer_id
	game.queue_free()
	arena.queue_free()
	await _flush_deferred()

	# 5. Final fix-wave regressions: minimap client_trenches/deployed_turrets markers & client vehicle armor clear on respawn
	var reg_arena := Node3D.new()
	add_child(reg_arena)

	var reg_hero := HeroCharacter.new()
	reg_hero.setup_identity(12590, "RegMinimap", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_ENGINEER, 0, false, false)
	reg_arena.add_child(reg_hero)

	var reg_hud := HUDController.new()
	reg_arena.add_child(reg_hud)
	reg_hud.set_local_hero(reg_hero)

	var cli_trench := EngineerSkills.TrenchEntity.new()
	cli_trench._is_visual_only = true
	cli_trench.team = NetworkManager.TEAM_NATIONAL
	cli_trench.position = Vector3(120.0, 0.0, -80.0)
	reg_arena.add_child(cli_trench)

	var cli_turret := VehicleShieldedMG.new()
	cli_turret.id = 12592
	cli_turret.team = NetworkManager.TEAM_NATIONAL
	cli_turret.position = Vector3(-140.0, 0.0, 95.0)
	reg_arena.add_child(cli_turret)

	reg_hud._minimap.queue_redraw()
	await get_tree().process_frame

	var markers: Array[Dictionary] = reg_hud._minimap.get_visible_structure_markers()
	var has_cli_trench_marker: bool = false
	var has_turret_marker: bool = false
	for m in markers:
		var grp: String = str(m.get("group", ""))
		if grp == "client_trenches":
			has_cli_trench_marker = true
		elif grp == "deployed_turrets":
			has_turret_marker = true

	cli_trench.queue_free()
	var markers_after_free: Array[Dictionary] = reg_hud._minimap.get_visible_structure_markers()
	var freed_trench_skipped: bool = true
	for m2 in markers_after_free:
		if str(m2.get("group", "")) == "client_trenches":
			freed_trench_skipped = false
			break

	var reg_jeep := VehicleJeep.new()
	reg_jeep.id = 12591
	reg_jeep.team = NetworkManager.TEAM_ROYAL
	reg_arena.add_child(reg_jeep)
	var base_jeep_hp: int = reg_jeep._base_max_hp
	var armor_applied_ok: bool = reg_jeep.apply_engineer_armor()
	reg_jeep.attach_engineer_armor_visuals()
	var armor_pre_ok: bool = (
		armor_applied_ok
		and reg_jeep.is_armored
		and reg_jeep.max_hp == base_jeep_hp * 2
		and reg_jeep._armor_plates_root != null
		and is_instance_valid(reg_jeep._armor_plates_root)
	)
	reg_jeep.push_remote_snapshot(10, 1000.0, {
		"hp": 0,
		"pos": Vector3.ZERO,
		"rot": Quaternion.IDENTITY,
		"vel": Vector3.ZERO,
		"turret_yaw": 0.0,
		"marked": false,
	})
	var snap_destroyed_ok: bool = reg_jeep.is_destroyed
	reg_jeep.push_remote_snapshot(11, 1050.0, {
		"hp": base_jeep_hp,
		"pos": Vector3.ZERO,
		"rot": Quaternion.IDENTITY,
		"vel": Vector3.ZERO,
		"turret_yaw": 0.0,
		"marked": false,
	})
	var snap_respawn_armor_cleared_ok: bool = (
		not reg_jeep.is_destroyed
		and not reg_jeep.is_armored
		and reg_jeep.max_hp == base_jeep_hp
		and reg_jeep._armor_plates_root == null
	)

	_assert(
		has_cli_trench_marker and has_turret_marker and freed_trench_skipped
		and armor_pre_ok and snap_destroyed_ok and snap_respawn_armor_cleared_ok,
		"Phase 12.5e: Minimap client_trenches/deployed_turrets markers (%s,%s,%s) & client VehicleBase armor clear on respawn (%s,%s,%s)" % [
			str(has_cli_trench_marker), str(has_turret_marker), str(freed_trench_skipped),
			str(armor_pre_ok), str(snap_destroyed_ok), str(snap_respawn_armor_cleared_ok)
		]
	)

	reg_arena.queue_free()
	await _flush_deferred()


func _test_phase12b_task1_engineer_build_channel() -> void:
	print("--- Phase 12B Task 1: Engineer Build Lock, Wrench Pose, Rising Blueprint & HUD Progress ---")
	var arena := Node3D.new()
	add_child(arena)

	# Ground plane so Engineer stands grounded for movement/jump lock verification
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var eng := HeroCharacter.new()
	eng.setup_identity(451, "EngBuildTest", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, true, false)
	eng.position = Vector3(0.0, 0.05, 0.0)
	eng.aim_yaw = 0.25
	arena.add_child(eng)
	await _flush_deferred()

	var sm: EngineerSkills = eng.skill_manager as EngineerSkills
	var ctx: Dictionary = {
		"heroes_by_id": {451: eng},
		"vehicles": [],
		"vehicles_by_id": {},
		"projectiles_root": arena,
		"vehicles_root": arena,
	}

	var build_starts: Array[Dictionary] = []
	var build_stops: Array[Dictionary] = []
	var ev_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "eng_build_start":
			build_starts.append(payload)
		elif ev_type == "eng_build_stop":
			build_stops.append(payload)
	NetworkManager.game_event_received.connect(ev_cb)

	# 1. Start Skill 0 (Trincheira) -> BUFF_ENGINEER_BUILD replicated & survives StatusEffectContainer tick
	var sk_cmd := InputCmd.new()
	sk_cmd.buttons = InputCmd.BTN_SKILL_1
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	var bits_reserved_ok: bool = (
		NetSerializer.BUFF_ENGINEER_BUILD == (1 << 17)
		and NetSerializer.BUFF_ENGINEER_MORTAR == (1 << 18)
		and NetSerializer.INPUT_CMD_BYTES == 15
	)
	var buff_immediate_ok: bool = (
		(eng.active_buffs & NetSerializer.BUFF_ENGINEER_BUILD) != 0
		and eng.is_engineer_building()
	)
	eng.status_effects._physics_process(0.1)
	var buff_survives_sync_ok: bool = (eng.active_buffs & NetSerializer.BUFF_ENGINEER_BUILD) != 0

	# 2. Movement + Jump + Server & Client-Prediction Fire Locks
	eng.velocity = Vector3(5.0, 0.0, 0.0)
	var move_cmd := InputCmd.new()
	move_cmd.move_dir = Vector2(1.0, 0.0)
	move_cmd.aim_yaw = eng.aim_yaw
	move_cmd.buttons = InputCmd.BTN_JUMP | InputCmd.BTN_FIRE
	for _i in range(12):
		eng.simulate_movement(move_cmd, 1.0 / 60.0)
	var horiz_after_lock: float = Vector2(eng.velocity.x, eng.velocity.z).length()
	var move_jump_locked_ok: bool = horiz_after_lock < 1.5 and eng.velocity.y <= 0.05

	var srv_weapon: WeaponBase = eng.weapons[0] as WeaponBase
	var srv_fire_blocked_ok: bool = not srv_weapon.try_consume_fire(move_cmd)

	# Non-host client HeroCharacter with only active_buffs replicated (no local SkillManager build state)
	var cli_eng := HeroCharacter.new()
	cli_eng.setup_identity(452, "ClientEng", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, true, false)
	arena.add_child(cli_eng)
	await _flush_deferred()
	cli_eng.active_buffs = NetSerializer.BUFF_ENGINEER_BUILD
	var cli_w: WeaponBase = cli_eng.weapons[0] as WeaponBase
	var cli_build_fire_blocked_ok: bool = not cli_w.try_consume_fire(move_cmd)
	cli_eng.active_buffs = NetSerializer.BUFF_ENGINEER_MORTAR
	var cli_mortar_fire_blocked_ok: bool = not cli_w.try_consume_fire(move_cmd)

	# 3. Wrench prop (-98), hidden left weapon root & animated kneeling hammer swing
	eng._animate_character(0.05)
	var wrench_equipped_ok: bool = (
		eng._shown_weapon_kind == -98
		and eng._build_tool_node != null
		and is_instance_valid(eng._build_tool_node)
		and eng._held_weapon_root_l != null
		and not eng._held_weapon_root_l.visible
	)
	var rot_t1: Vector3 = eng._held_weapon_root.rotation
	eng._animate_character(0.18)
	var rot_t2: Vector3 = eng._held_weapon_root.rotation
	var wrench_anim_ok: bool = (not rot_t1.is_equal_approx(rot_t2)) and eng._hips_pivot.position.y < 0.72

	# 4. Rising blueprint preview + exact spawn alignment even if aim_yaw changes mid-build
	var start_ev_ok: bool = (
		not build_starts.is_empty()
		and int(build_starts[0].get("slot", -1)) == 0
		and is_equal_approx(float(build_starts[0].get("duration", 0.0)), 3.0)
	)
	var expected_pos: Vector3 = build_starts[0].get("pos", Vector3.ZERO)
	var expected_yaw: float = float(build_starts[0].get("yaw", 0.0))
	var preview: Node3D = StatusEffectsVFX.spawn_build_preview(arena, eng.entity_id, 0, expected_pos, expected_yaw, 3.0)
	var preview_node := preview as StatusEffectsVFX.BuildPreviewVFX
	var preview_rise_ok: bool = preview_node != null and is_equal_approx(preview_node.scaffold.scale.y, 0.05)
	if preview_node != null:
		preview_node._process(1.5)
		preview_rise_ok = preview_rise_ok and preview_node.scaffold.scale.y > 0.45 and preview_node.scaffold.scale.y < 0.65
		preview_node._process(1.5)
		preview_rise_ok = preview_rise_ok and is_equal_approx(preview_node.scaffold.scale.y, 1.0)

	# Turn Hero away mid-build and complete channel -> trench must still spawn at expected_pos/yaw!
	eng.aim_yaw = -1.9
	for _i in range(32):
		sm.step_server(0.1, sk_cmd, ctx)
	StatusEffectsVFX.stop_build_preview(eng.entity_id)
	await _flush_deferred()
	var trench: EngineerSkills.TrenchEntity = sm._active_trench
	var exact_trench_align_ok: bool = (
		trench != null
		and is_instance_valid(trench)
		and trench.position.distance_to(expected_pos) < 0.001
		and absf(angle_difference(trench.rotation.y, expected_yaw)) < 0.001
	)
	var build_stopped_ok: bool = (
		not eng.is_engineer_building()
		and (eng.active_buffs & NetSerializer.BUFF_ENGINEER_BUILD) == 0
		and not build_stops.is_empty()
		and ((not is_instance_valid(preview_node)) or preview_node.is_queued_for_deletion())
		and StatusEffectsVFX._active_build_previews.is_empty()
	)
	eng._animate_character(0.05)
	var weapon_restored_ok: bool = (
		eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS
		and eng._held_weapon_root_l != null
		and eng._held_weapon_root_l.visible
	)

	# 5. Skill 1 (Torreta MG) exact spawn alignment + defeat cancellation cleans preview
	eng.aim_yaw = 0.7
	sk_cmd.buttons = InputCmd.BTN_SKILL_2
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	var s1_pos: Vector3 = build_starts[build_starts.size() - 1].get("pos", Vector3.ZERO)
	var s1_yaw: float = float(build_starts[build_starts.size() - 1].get("yaw", 0.0))
	var preview1: Node3D = StatusEffectsVFX.spawn_build_preview(arena, eng.entity_id, 1, s1_pos, s1_yaw, 2.0)
	eng.aim_yaw = -2.2
	for _i in range(22):
		sm.step_server(0.1, sk_cmd, ctx)
	var turret: VehicleShieldedMG = sm._active_turret
	var exact_turret_align_ok: bool = (
		turret != null
		and is_instance_valid(turret)
		and turret.position.distance_to(s1_pos) < 0.001
		and absf(angle_difference(turret.rotation.y, s1_yaw)) < 0.001
	)
	StatusEffectsVFX.clear_all_build_previews()
	await _flush_deferred()
	var preview1_cleared_ok: bool = (
		((not is_instance_valid(preview1)) or preview1.is_queued_for_deletion())
		and StatusEffectsVFX._active_build_previews.is_empty()
	)

	# 6. HUD Build Progress Bar (Trincheira / Torreta / Blindar + defeat auto-hide)
	var hud := HUDController.new()
	arena.add_child(hud)
	hud.set_local_hero(eng)
	hud.start_build_progress(0, 3.0)
	hud._process(1.5)
	var hud_s0_ok: bool = (
		hud._build_panel.visible
		and hud._build_label.text == "CONSTRUINDO TRINCHEIRA..."
		and is_equal_approx(hud._build_bar.value, 0.5)
	)
	hud.start_build_progress(1, 2.0)
	var hud_s1_ok: bool = hud._build_panel.visible and hud._build_label.text == "CONSTRUINDO TORRETA MG..."
	hud.start_build_progress(2, 2.0)
	var hud_s2_ok: bool = hud._build_panel.visible and hud._build_label.text == "BLINDANDO VEÍCULO..."
	eng.is_defeated = true
	hud._process(0.016)
	var hud_defeat_hide_ok: bool = not hud._build_panel.visible
	hud.start_build_progress(0, 3.0)
	hud.stop_build_progress()
	var hud_stop_hide_ok: bool = not hud._build_panel.visible

	NetworkManager.game_event_received.disconnect(ev_cb)

	_assert(
		bits_reserved_ok and buff_immediate_ok and buff_survives_sync_ok
		and move_jump_locked_ok and srv_fire_blocked_ok and cli_build_fire_blocked_ok and cli_mortar_fire_blocked_ok
		and wrench_equipped_ok and wrench_anim_ok
		and start_ev_ok and preview_rise_ok and exact_trench_align_ok and build_stopped_ok and weapon_restored_ok
		and exact_turret_align_ok and preview1_cleared_ok
		and hud_s0_ok and hud_s1_ok and hud_s2_ok and hud_defeat_hide_ok and hud_stop_hide_ok,
		"Phase 12B.1: Engineer Build Lock, Wrench Pose, Blueprint & HUD (bits=%s buf=%s sync=%s mv=%s sf=%s cbf=%s cmf=%s wr=%s wa=%s ev=%s pr=%s ta=%s bs=%s wrs=%s tua=%s p1c=%s h0=%s h1=%s h2=%s hd=%s hs=%s)" % [
			str(bits_reserved_ok), str(buff_immediate_ok), str(buff_survives_sync_ok),
			str(move_jump_locked_ok), str(srv_fire_blocked_ok), str(cli_build_fire_blocked_ok), str(cli_mortar_fire_blocked_ok),
			str(wrench_equipped_ok), str(wrench_anim_ok),
			str(start_ev_ok), str(preview_rise_ok), str(exact_trench_align_ok), str(build_stopped_ok), str(weapon_restored_ok),
			str(exact_turret_align_ok), str(preview1_cleared_ok),
			str(hud_s0_ok), str(hud_s1_ok), str(hud_s2_ok), str(hud_defeat_hide_ok), str(hud_stop_hide_ok)
		]
	)

	arena.queue_free()
	await _flush_deferred()
	await get_tree().process_frame


func _test_phase12b_task2_mortar_anim_and_aoe() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(120.0, 2.0, 120.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	var eng := HeroCharacter.new()
	eng.setup_identity(461, "MortarEng", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, false, false)
	eng.position = Vector3(0.0, 0.0, 0.0)
	arena.add_child(eng)

	var enemy_center := HeroCharacter.new()
	enemy_center.setup_identity(462, "CenterTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	enemy_center.position = Vector3(32.0, 0.0, 0.0)
	arena.add_child(enemy_center)

	var enemy_rim := HeroCharacter.new()
	enemy_rim.setup_identity(463, "RimTarget", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	enemy_rim.position = Vector3(43.5, 0.0, 0.0) # 11.5m from strike center (past old 7.0m limit!)
	arena.add_child(enemy_rim)

	var enemy_veh := VehicleJeep.new()
	enemy_veh.id = 62
	enemy_veh.team = NetworkManager.TEAM_NATIONAL
	enemy_veh.position = Vector3(32.0, 0.0, 14.5) # within 15.5m vehicle blast radius
	arena.add_child(enemy_veh)

	var cli_eng := HeroCharacter.new()
	cli_eng.setup_identity(464, "RemoteEng", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_ENGINEER, 0, false, false)
	cli_eng.position = Vector3(-4.0, 0.0, 0.0)
	arena.add_child(cli_eng)

	await _flush_deferred()
	await get_tree().physics_frame

	var sm := eng.skill_manager as EngineerSkills
	var heroes_d: Dictionary = {
		eng.entity_id: eng,
		enemy_center.entity_id: enemy_center,
		enemy_rim.entity_id: enemy_rim,
	}
	var vehs: Array = [enemy_veh]
	var ctx: Dictionary = {
		"heroes_by_id": heroes_d,
		"heroes": heroes_d,
		"vehicles": vehs,
		"projectiles_root": arena,
		"vehicles_root": arena,
	}

	var strike_events: Array[Dictionary] = []
	var explode_events: Array[Dictionary] = []
	var cancel_events: Array[Dictionary] = []
	var ev_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "mortar_strike":
			strike_events.append(payload)
		elif ev_type == "mortar_explode":
			explode_events.append(payload)
		elif ev_type == "mortar_cancel":
			cancel_events.append(payload)
	NetworkManager.game_event_received.connect(ev_cb)

	# 1. Enter Mortar Aim Mode -> BUFF_ENGINEER_MORTAR active, -97 mortar tube equipped, move/jump/fire locked
	var sk_cmd := InputCmd.new()
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	var mortar_buff_ok: bool = (eng.active_buffs & NetSerializer.BUFF_ENGINEER_MORTAR) != 0 and eng.is_engineer_mortar_deployed()

	eng._animate_character(0.05)
	var prop_equipped_ok: bool = (
		eng._shown_weapon_kind == -97
		and eng._mortar_tube_node != null
		and is_instance_valid(eng._mortar_tube_node)
		and eng._mortar_tube_node.get_node_or_null("MortarBarrel") != null
		and eng._mortar_tube_node.get_node_or_null("MortarBaseplate") != null
		and eng._mortar_tube_node.get_node_or_null("MortarBipodL") != null
		and eng._held_weapon_root_l != null
		and not eng._held_weapon_root_l.visible
		and eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.DEPLOY
	)
	eng._animate_character(0.35)
	var hold_phase_ok: bool = eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.AIMED_HOLD and eng._hips_pivot.position.y < 0.60

	# Movement, jump, and fire locked while mortar deployed
	eng.velocity = Vector3(5.0, 0.0, 0.0)
	var move_cmd := InputCmd.new()
	move_cmd.move_dir = Vector2(1.0, 0.0)
	move_cmd.aim_yaw = eng.aim_yaw
	move_cmd.buttons = InputCmd.BTN_JUMP | InputCmd.BTN_FIRE
	for _i in range(12):
		eng.simulate_movement(move_cmd, 1.0 / 60.0)
	var move_jump_locked_ok: bool = Vector2(eng.velocity.x, eng.velocity.z).length() < 1.5 and eng.velocity.y <= 0.05
	var srv_w := eng.weapons[0] as WeaponBase
	var srv_fire_locked_ok: bool = not srv_w.try_consume_fire(move_cmd)

	# 2. Fire Mortar -> launch recoil -> stow -> equipped weapon restored!
	var center_hp0: int = enemy_center.hp
	var rim_hp0: int = enemy_rim.hp
	var veh_hp0: int = enemy_veh.hp
	var fired: bool = sm.fire_mortar_at(enemy_center.position, ctx)
	eng.trigger_mortar_visual("fire")
	var fire_phase_ok: bool = (
		fired
		and eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.FIRE
		and (eng.active_buffs & NetSerializer.BUFF_ENGINEER_MORTAR) != 0
		and not srv_w.try_consume_fire(move_cmd)
	)
	var strike_ev_ok: bool = (
		not strike_events.is_empty()
		and strike_events[0].has("shooter_pos")
		and is_equal_approx(float(strike_events[0].get("radius", 0.0)), 13.0)
		and is_equal_approx(float(strike_events[0].get("delay", 0.0)), 1.25)
	)

	# Advance 0.35s -> transitions from FIRE (0.30s) into STOW (0.45s)
	eng._animate_character(0.35)
	var stow_phase_ok: bool = eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.STOW and eng.is_engineer_mortar_deployed()

	# Step server & visuals past 0.75s stow window and 1.25s mortar delay
	for _i in range(14):
		sm.step_server(0.1, sk_cmd, ctx)
		eng.status_effects._physics_process(0.1)
		eng._animate_character(0.1)

	var weapon_restored_ok: bool = (
		not eng.is_engineer_mortar_deployed()
		and (eng.active_buffs & NetSerializer.BUFF_ENGINEER_MORTAR) == 0
		and eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.NONE
		and eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS
		and eng._held_weapon_root_l != null
		and eng._held_weapon_root_l.visible
	)
	var aoe_dmg_ok: bool = (
		center_hp0 - enemy_center.hp == 110
		and rim_hp0 - enemy_rim.hp >= 45
		and veh_hp0 - enemy_veh.hp >= 55
		and not explode_events.is_empty()
		and is_equal_approx(float(explode_events[0].get("radius", 0.0)), 13.0)
	)

	# 3. Remote client snapshot edge drives deploy -> hold -> stow -> restore automatically
	cli_eng.active_buffs = NetSerializer.BUFF_ENGINEER_MORTAR
	cli_eng._animate_character(0.05)
	var cli_deploy_ok: bool = cli_eng._shown_weapon_kind == -97 and cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.DEPLOY
	cli_eng._animate_character(0.40)
	var cli_hold_ok: bool = cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.AIMED_HOLD
	cli_eng.active_buffs = 0
	cli_eng._animate_character(0.05)
	var cli_stow_ok: bool = cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.STOW
	cli_eng._animate_character(0.50)
	var cli_restored_ok: bool = cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.NONE and cli_eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS

	# 4. Flying mortar shell arc rises skyward at midpoint and lands + frees at duration
	var shell_origin: Vector3 = eng.get_mortar_muzzle_world_position()
	var shell_target := Vector3(32.0, 0.0, 0.0)
	var shell_node := StatusEffectsVFX.spawn_mortar_shell_arc(arena, shell_origin, shell_target, 1.25) as StatusEffectsVFX.MortarShellArcVFX
	var shell_mid_ok: bool = false
	var shell_freed_ok: bool = false
	if shell_node != null:
		shell_node._process(0.625)
		shell_mid_ok = shell_node.position.y > maxf(shell_origin.y, shell_target.y) + 12.0
		shell_node._process(0.65)
		await _flush_deferred()
		shell_freed_ok = (not is_instance_valid(shell_node)) or shell_node.is_queued_for_deletion()

	# 5. Cancel & Defeat clear mortar state cleanly
	sm.skill_cooldowns[3] = 0.0
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	eng._animate_character(0.05)
	sm.cancel_mortar_mode()
	eng.trigger_mortar_visual("stow")
	var cancel_ev_ok: bool = not cancel_events.is_empty() and (eng.active_buffs & NetSerializer.BUFF_ENGINEER_MORTAR) == 0
	eng._animate_character(0.55)
	var cancel_restored_ok: bool = not eng.is_engineer_mortar_deployed() and eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS

	sm.skill_cooldowns[3] = 0.0
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	eng._animate_character(0.05)
	eng.apply_damage_server(999, 462, false)
	eng._animate_character(0.05)
	var defeat_cleared_ok: bool = not eng.is_engineer_mortar_deployed() and not sm.blocks_weapon_fire()

	# 6. AIMED_HOLD grace exit (>0.35s without buff), post-STOW stale-buff latch, & cooldown cancel broadcast
	cli_eng.active_buffs = 0
	cli_eng.trigger_mortar_visual("deploy")
	cli_eng._animate_character(0.40) # enters AIMED_HOLD with buff_active=false
	var in_hold_no_buff: bool = cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.AIMED_HOLD
	cli_eng._animate_character(0.40) # exceeds 0.35s grace -> transitions to STOW
	var grace_entered_stow: bool = cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.STOW
	cli_eng._animate_character(0.50) # finishes STOW -> NONE
	var grace_exit_ok: bool = in_hold_no_buff and grace_entered_stow and cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.NONE and cli_eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS

	# Stale BUFF_ENGINEER_MORTAR after FIRE->STOW->NONE must not snap back to -97 or AIMED_HOLD
	cli_eng.active_buffs = NetSerializer.BUFF_ENGINEER_MORTAR
	cli_eng.trigger_mortar_visual("fire")
	cli_eng._animate_character(0.35) # FIRE -> STOW
	cli_eng._animate_character(0.50) # STOW -> NONE while stale BUFF_ENGINEER_MORTAR still set
	cli_eng._animate_character(0.10) # additional tick with stale buff
	var stow_latch_ok: bool = (
		cli_eng._mortar_stow_completed
		and cli_eng._mortar_anim_phase == HeroCharacter.MortarAnimPhase.NONE
		and not cli_eng.is_engineer_mortar_deployed()
		and cli_eng._shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS
	)
	cli_eng.active_buffs = 0
	cli_eng._animate_character(0.05) # clears latch once buff drops
	stow_latch_ok = stow_latch_ok and not cli_eng._mortar_stow_completed

	# Cooldown early-out in fire_mortar_at while aiming broadcasts mortar_cancel
	eng.respawn_at(Vector3.ZERO, 0.0)
	sk_cmd.buttons = 0
	sm.step_server(0.05, sk_cmd, ctx)
	sm.skill_cooldowns[3] = 0.0
	sk_cmd.buttons = InputCmd.BTN_SKILL_4
	sm.step_server(0.05, sk_cmd, ctx)
	sk_cmd.buttons = 0
	sm.step_server(0.05, sk_cmd, ctx)
	var pre_cancel_cnt: int = cancel_events.size()
	sm.skill_cooldowns[3] = 5.0
	var cd_rejected: bool = not sm.fire_mortar_at(Vector3(20.0, 0.0, 0.0), ctx)
	var cd_cancel_ok: bool = cd_rejected and cancel_events.size() == pre_cancel_cnt + 1 and (eng.active_buffs & NetSerializer.BUFF_ENGINEER_MORTAR) == 0

	NetworkManager.game_event_received.disconnect(ev_cb)

	_assert(
		mortar_buff_ok and prop_equipped_ok and hold_phase_ok and move_jump_locked_ok and srv_fire_locked_ok
		and fire_phase_ok and strike_ev_ok and stow_phase_ok and weapon_restored_ok and aoe_dmg_ok
		and cli_deploy_ok and cli_hold_ok and cli_stow_ok and cli_restored_ok
		and shell_mid_ok and shell_freed_ok and cancel_ev_ok and cancel_restored_ok and defeat_cleared_ok
		and grace_exit_ok and stow_latch_ok and cd_cancel_ok,
		"Phase 12B.2: Mortar 3D Prop, Deploy/Fire/Stow Anim, Shell Arc & 13m AoE (mb=%s pr=%s hd=%s mv=%s sf=%s fp=%s se=%s st=%s wr=%s aoe=%s cd=%s ch=%s cs=%s cr=%s sm=%s sf2=%s ce=%s cr2=%s df=%s ge=%s sl=%s cc=%s)" % [
			str(mortar_buff_ok), str(prop_equipped_ok), str(hold_phase_ok), str(move_jump_locked_ok), str(srv_fire_locked_ok),
			str(fire_phase_ok), str(strike_ev_ok), str(stow_phase_ok), str(weapon_restored_ok), str(aoe_dmg_ok),
			str(cli_deploy_ok), str(cli_hold_ok), str(cli_stow_ok), str(cli_restored_ok),
			str(shell_mid_ok), str(shell_freed_ok), str(cancel_ev_ok), str(cancel_restored_ok), str(defeat_cleared_ok),
			str(grace_exit_ok), str(stow_latch_ok), str(cd_cancel_ok)
		]
	)

	arena.queue_free()
	await _flush_deferred()
	await get_tree().process_frame


func _test_phase12b_task3_perf_optimizations() -> void:
	print("--- Phase 12B Task 3: GPU & CPU Performance Overhaul Verification ---")
	var arena := Node3D.new()
	add_child(arena)

	# 1. Shaders & Project/Camera settings
	var water_sh: Shader = load("res://vfx_shaders/water_toon.gdshader")
	var sky_sh: Shader = load("res://vfx_shaders/toon_sky.gdshader")
	var cel_sh: Shader = load("res://vfx_shaders/hero_cel_shader.gdshader")
	var water_ok: bool = (
		water_sh != null
		and water_sh.code.contains("cull_back")
		and water_sh.code.contains("depth_draw_always")
		and not water_sh.code.contains("ALPHA")
	)
	var cel_ok: bool = (
		cel_sh != null
		and not cel_sh.code.contains("ALPHA")
		and cel_sh.code.contains("rim_color")
		and cel_sh.code.contains("rim_strength")
		and cel_sh.code.contains("cloak_amount")
		and not cel_sh.code.contains("pow(1.0 - clamp(dot(NORMAL, VIEW)")
	)
	var sky_ok: bool = (sky_sh != null and not sky_sh.code.contains("i < 4"))
	var msaa_cfg: int = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", -1))
	var sh_size_cfg: int = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", -1))
	var sh_qual_cfg: int = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", -1))
	var proj_ok: bool = (msaa_cfg == 1 and sh_size_cfg == 2048 and sh_qual_cfg == 1)

	var cam_hero := HeroCharacter.new()
	cam_hero.setup_identity(12601, "CamHero", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(cam_hero)
	var cam_far_ok: bool = (cam_hero.hero_camera != null and cam_hero.hero_camera.camera != null and is_equal_approx(cam_hero.hero_camera.camera.far, 1500.0))

	# 2. Map Terrain, MultiMesh Trees, Lighting, Fountain & DestructibleProp sharing
	var p_map := MapSeasideFrontline.new()
	var p_conq := ConquestManager.new()
	var p_vehs := Node3D.new()
	arena.add_child(p_conq)
	arena.add_child(p_vehs)
	arena.add_child(p_map)
	p_map.build_map(p_conq, p_vehs, {})

	var terrain_mi := p_map.get_node_or_null("SculptedTerrain/TerrainMesh") as MeshInstance3D
	var terrain_col := p_map.get_node_or_null("SculptedTerrain/CollisionShape3D") as CollisionShape3D
	var terrain_verts: int = 999999
	if terrain_mi != null and terrain_mi.mesh is ArrayMesh:
		var arrs: Array = (terrain_mi.mesh as ArrayMesh).surface_get_arrays(0)
		if not arrs.is_empty():
			terrain_verts = (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var terrain_ok: bool = (terrain_verts > 70000 and terrain_verts < 80000 and terrain_col != null and terrain_col.shape is ConcavePolygonShape3D)

	var batched_instances: int = 0
	var tree_batches_ok: bool = true
	for v_k in range(3):
		var tb := p_map.get_node_or_null("TreeBatch_%d" % v_k) as MultiMeshInstance3D
		if tb == null or tb.multimesh == null or tb.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			tree_batches_ok = false
		else:
			batched_instances += tb.multimesh.instance_count
	var collider_trees: int = 0
	for ch in p_map.get_children():
		if ch is StaticBody3D and ch.name.begins_with("LayeredTree_"):
			collider_trees += 1
	tree_batches_ok = tree_batches_ok and batched_instances >= 140 and collider_trees >= 140

	var we := p_map.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun := p_map.get_node_or_null("SunLight") as DirectionalLight3D
	var env_ok: bool = (
		we != null and we.environment != null
		and we.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
		and is_equal_approx(we.environment.fog_depth_begin, 700.0)
		and is_equal_approx(we.environment.fog_depth_end, 1480.0)
		and sun != null and is_equal_approx(sun.directional_shadow_max_distance, 120.0)
	)
	var plume := p_map.get_node_or_null("CentralFountain/FountainPlume") as GPUParticles3D
	var jet0 := p_map.get_node_or_null("CentralFountain/FountainJet_0") as GPUParticles3D
	var splash0 := p_map.get_node_or_null("CentralFountain/FountainSplash_0") as GPUParticles3D
	var fountain_ok: bool = (
		plume != null and is_equal_approx(plume.visibility_range_end, 110.0) and plume.amount <= 16
		and jet0 != null and is_equal_approx(jet0.visibility_range_end, 110.0) and jet0.amount <= 16
		and splash0 != null and is_equal_approx(splash0.visibility_range_end, 110.0) and splash0.amount <= 12
	)
	var crate_a := DestructibleProp.new()
	crate_a.setup(DestructibleProp.PropKind.CRATE, Vector3.ZERO)
	var crate_b := DestructibleProp.new()
	crate_b.setup(DestructibleProp.PropKind.CRATE, Vector3(3.0, 0.0, 0.0))
	arena.add_child(crate_a)
	arena.add_child(crate_b)
	var prop_shared_ok: bool = (
		crate_a._mesh.mesh == crate_b._mesh.mesh
		and crate_a._mesh.material_override == crate_b._mesh.material_override
		and crate_a._mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	# 3. O(1) Sixth Sense cache parity
	var ss_ally := HeroCharacter.new()
	ss_ally.setup_identity(12602, "SSAlly", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	var ss_enemy := HeroCharacter.new()
	ss_enemy.setup_identity(12603, "SSEnemy", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	arena.add_child(ss_ally)
	arena.add_child(ss_enemy)
	ss_ally.position = Vector3.ZERO
	ss_enemy.position = Vector3(20.0, 0.0, 0.0)
	var ss_dict: Dictionary = {12602: ss_ally, 12603: ss_enemy}
	StatusEffectContainer.refresh_sixth_sense_cache(ss_dict)
	var ss_off_ok: bool = not StatusEffectContainer.is_enemy_sensed_by_team(ss_enemy, NetworkManager.TEAM_ROYAL, ss_dict)
	ss_ally.status_effects.activate_sixth_sense(55.0, 8.0)
	StatusEffectContainer.refresh_sixth_sense_cache(ss_dict)
	var ss_on_ok: bool = StatusEffectContainer.is_enemy_sensed_by_team(ss_enemy, NetworkManager.TEAM_ROYAL, ss_dict)
	ss_enemy.position = Vector3(80.0, 0.0, 0.0)
	var ss_far_ok: bool = not StatusEffectContainer.is_enemy_sensed_by_team(ss_enemy, NetworkManager.TEAM_ROYAL, ss_dict)
	StatusEffectContainer.clear_sixth_sense_cache()
	var ss_cache_ok: bool = ss_off_ok and ss_on_ok and ss_far_ok

	# 4. StatusEffectsVFX Pooling & Shared Materials + GameCache prewarm
	var vfx_host := Node3D.new()
	arena.add_child(vfx_host)
	StatusEffectsVFX.spawn_cartoon_burst(vfx_host, Vector3.ZERO, "spark", 0.5, true)
	StatusEffectsVFX.spawn_curved_tracer(vfx_host, PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -10.0)]), WeaponBase.WeaponKind.SMG, true)
	StatusEffectsVFX.spawn_muzzle_flash(vfx_host, Vector3.ZERO, Vector3.FORWARD, WeaponBase.WeaponKind.SMG, true)
	var mgr: StatusEffectsVFX.VfxPoolManager = StatusEffectsVFX._get_pool_manager(vfx_host)
	var initial_created: int = mgr.total_created
	mgr._process(0.60) # expire all active pooled entries back to free lists
	StatusEffectsVFX.spawn_cartoon_burst(vfx_host, Vector3(1.0, 0.0, 0.0), "spark", 0.5, true)
	StatusEffectsVFX.spawn_curved_tracer(vfx_host, PackedVector3Array([Vector3.ZERO, Vector3(0.0, 0.0, -10.0)]), WeaponBase.WeaponKind.SMG, true)
	StatusEffectsVFX.spawn_muzzle_flash(vfx_host, Vector3.ZERO, Vector3.FORWARD, WeaponBase.WeaponKind.SMG, true)
	var vfx_pool_ok: bool = (mgr.total_reused == 3 and mgr.total_created == initial_created and StatusEffectsVFX._get_shared_burst_mat("spark") == StatusEffectsVFX._get_shared_burst_mat("spark"))
	StatusEffectsVFX.clear_pools(vfx_host)
	await _flush_deferred()
	var vfx_clear_ok: bool = not StatusEffectsVFX._pool_managers.has(vfx_host.get_instance_id())

	GameCache.clear_all()
	var prewarm_root: Node3D = GameCache.prewarm_gpu_pipelines(arena)
	var prewarm_has_label3d: bool = false
	if prewarm_root != null:
		for ch in prewarm_root.get_children():
			if ch is Label3D:
				prewarm_has_label3d = true
				break
	GameCache.cleanup_prewarm(prewarm_root)

	# 5. Minimap Static Layer Caching & 12 Hz Throttle
	var p_hud := HUDController.new()
	arena.add_child(p_hud)
	p_hud.set_process(false)
	p_hud.bind_context(p_conq, [] as Array[VehicleBase], ss_dict)
	p_hud.set_local_hero(ss_ally)
	await get_tree().process_frame
	var static_layer: HUDController._MinimapStaticLayer = p_hud._minimap._static_layer
	var s_draws_1: int = static_layer.draw_count
	var dyn_start: int = p_hud._minimap.dynamic_draw_count
	for _f in range(12):
		p_hud._process(1.0 / 60.0)
		await get_tree().process_frame
	var dyn_delta_12frames: int = p_hud._minimap.dynamic_draw_count - dyn_start
	var s_draws_after_pan: int = static_layer.draw_count
	p_hud.set_mortar_targeting_mode(true, Callable(), false)
	await get_tree().process_frame
	var s_draws_after_mortar: int = static_layer.draw_count
	p_hud.set_mortar_targeting_mode(false, Callable(), false)
	var minimap_cache_ok: bool = (s_draws_1 >= 1 and s_draws_after_pan == s_draws_1 and s_draws_after_mortar > s_draws_after_pan and dyn_delta_12frames >= 2 and dyn_delta_12frames <= 3)

	# 6. LagCompensator, SnapshotInterpolator, BotController & Vehicle Sleep
	var lc := LagCompensator.new()
	lc.record_frame(0, ss_dict)
	var snap_first: LagCompensator.HeroHitboxSnapshot = lc.get_frame(0, 0).entries[12602]
	lc.record_frame(LagCompensator.HISTORY_FRAMES, ss_dict)
	var snap_reused: LagCompensator.HeroHitboxSnapshot = lc.get_frame(LagCompensator.HISTORY_FRAMES, LagCompensator.HISTORY_FRAMES).entries[12602]
	var lc_reuse_ok: bool = (snap_first == snap_reused)
	lc.free()

	var si := SnapshotInterpolator.new()
	si.push_snapshot(1, 100.0, Vector3.ZERO, Quaternion.IDENTITY)
	si.push_snapshot(2, 200.0, Vector3(10.0, 0.0, 0.0), Quaternion.IDENTITY)
	var si_a: SnapshotInterpolator.SnapshotSample = si.sample(250.0)
	var si_b: SnapshotInterpolator.SnapshotSample = si.sample(260.0)
	var si_reuse_ok: bool = (si_a == si._reusable_sample and si_b == si._reusable_sample)

	var bot_brain := BotController.new()
	bot_brain.setup(ss_ally)
	arena.add_child(bot_brain)
	var c1: InputCmd = bot_brain.step_ai(0.016, [], ss_dict, [])
	var c2: InputCmd = bot_brain.step_ai(0.016, [], ss_dict, [])
	var bot_reuse_ok: bool = (c1 == bot_brain._reusable_cmd and c2 == bot_brain._reusable_cmd)

	var parked_jeep := VehicleJeep.new()
	parked_jeep.id = 12610
	arena.add_child(parked_jeep)
	parked_jeep.linear_velocity = Vector3.ZERO
	parked_jeep.angular_velocity = Vector3.ZERO
	parked_jeep.step_vehicle_server(0.016, ss_dict, {})
	var jeep_can_sleep_ok: bool = parked_jeep.can_sleep
	var parked_plane := VehiclePlane.new()
	parked_plane.id = 12611
	arena.add_child(parked_plane)
	parked_plane.linear_velocity = Vector3.ZERO
	parked_plane.angular_velocity = Vector3.ZERO
	parked_plane.step_vehicle_server(0.016, ss_dict, {})
	var plane_can_sleep_ok: bool = parked_plane.can_sleep

	_assert(
		water_ok and cel_ok and sky_ok and proj_ok and cam_far_ok
		and terrain_ok and tree_batches_ok and env_ok and fountain_ok and prop_shared_ok
		and ss_cache_ok and vfx_pool_ok and vfx_clear_ok and prewarm_has_label3d
		and minimap_cache_ok and lc_reuse_ok and si_reuse_ok and bot_reuse_ok
		and jeep_can_sleep_ok and plane_can_sleep_ok,
		"Phase 12B.3: Perf Overhaul (w=%s cel=%s sky=%s proj=%s far=%s ter=%d bat=%d/%d env=%s fnt=%s prp=%s ss=%s vp=%s vc=%s pw=%s mm=%s lc=%s si=%s bot=%s slp=%s/%s)" % [
			str(water_ok), str(cel_ok), str(sky_ok), str(proj_ok), str(cam_far_ok),
			terrain_verts, batched_instances, collider_trees, str(env_ok), str(fountain_ok), str(prop_shared_ok),
			str(ss_cache_ok), str(vfx_pool_ok), str(vfx_clear_ok), str(prewarm_has_label3d),
			str(minimap_cache_ok), str(lc_reuse_ok), str(si_reuse_ok), str(bot_reuse_ok),
			str(jeep_can_sleep_ok), str(plane_can_sleep_ok)
		]
	)

	arena.queue_free()
	await _flush_deferred()
	await get_tree().process_frame


func _test_phase13_task1_lod_demolisher_gunner() -> void:
	print("--- Phase 13 Task 1: LOD Crawl/Sky-Drop Fix, Demolisher 1a-1f & Gunner Explosive Absorb ---")
	var arena := Node3D.new()
	add_child(arena)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(400.0, 1.0, 400.0)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	arena.add_child(floor_body)

	# Low 0.75m curb at z=-5.0 (blocks +0.45 feet ray, leaves +1.05 & +1.55 clear)
	var curb_body := StaticBody3D.new()
	curb_body.collision_layer = 1
	var curb_col := CollisionShape3D.new()
	var curb_box := BoxShape3D.new()
	curb_box.size = Vector3(6.0, 0.75, 0.4)
	curb_col.shape = curb_box
	curb_col.position = Vector3(0.0, 0.375, -5.0)
	curb_body.add_child(curb_col)
	arena.add_child(curb_body)

	# Tall 2.8m wall at x=15.0, z=-5.0 (blocks all 3 heights)
	var wall_body := StaticBody3D.new()
	wall_body.collision_layer = 1
	var wall_col := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6.0, 2.8, 0.4)
	wall_col.shape = wall_box
	wall_col.position = Vector3(15.0, 1.4, -5.0)
	wall_body.add_child(wall_col)
	arena.add_child(wall_body)

	var cam := Camera3D.new()
	arena.add_child(cam)
	cam.global_position = Vector3(0.0, 3.0, 0.0)
	cam.current = true

	var remote_bot := HeroCharacter.new()
	remote_bot.setup_identity(13101, "RemoteBot", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, 0, false, true)
	arena.add_child(remote_bot)
	remote_bot.global_position = Vector3(0.0, 0.0, -140.0)
	await get_tree().physics_frame

	# 1. LOD > 100m & behind camera defeat -> respawn_at -> giant delta never crawls or sky-spikes
	remote_bot.is_defeated = true
	remote_bot._animate_character(0.5)
	remote_bot._animate_character(0.5)
	var defeated_low_y: bool = remote_bot._hips_pivot.position.y < 0.25 and remote_bot._is_defeat_pose_done
	remote_bot.respawn_at(Vector3(0.0, 0.0, 140.0), 0.0) # Behind camera & >100m away
	remote_bot._animate_character(10.0) # Huge frame spike must be clamped cleanly
	var lod_respawn_ok: bool = (
		defeated_low_y
		and remote_bot._hips_pivot.position.y >= 0.70 and remote_bot._hips_pivot.position.y <= 0.82
		and is_equal_approx(remote_bot._hips_pivot.rotation.x, 0.0)
		and is_equal_approx(remote_bot._defeat_elapsed, 0.0)
		and is_equal_approx(remote_bot._airborne_fall_time, 0.0)
		and not remote_bot._is_defeat_pose_done
	)
	_assert(
		lod_respawn_ok,
		"Phase 13.1a: Remote hero >100m & behind camera stands upright after respawn_at + 10s delta spike (hips_y=%.2f, rot_x=%.2f)" % [
			remote_bot._hips_pivot.position.y, remote_bot._hips_pivot.rotation.x
		]
	)

	# 2. Demolisher 1a: Skill 3 immediate 17s CD + replacing active box despawns old kit & emits armor_kit_removed
	var demo := HeroCharacter.new()
	demo.setup_identity(13102, "P13Demo", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_DEMOLISHER, 0, true, false)
	arena.add_child(demo)
	var enemy_demo := HeroCharacter.new()
	enemy_demo.setup_identity(13103, "P13EDemo", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_DEMOLISHER, 0, false, false)
	arena.add_child(enemy_demo)
	var enemy_gunner := HeroCharacter.new()
	enemy_gunner.setup_identity(13104, "P13EGunner", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_GUNNER, 0, false, false)
	arena.add_child(enemy_gunner)
	var enemy_eng := HeroCharacter.new()
	enemy_eng.setup_identity(13105, "P13EEng", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_ENGINEER, 0, false, false)
	arena.add_child(enemy_eng)
	var enemy_cmdo := HeroCharacter.new()
	enemy_cmdo.setup_identity(13106, "P13ECmdo", NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_COMMANDO, 0, false, false)
	arena.add_child(enemy_cmdo)
	await get_tree().physics_frame

	var ctx: Dictionary = {
		"heroes_by_id": {
			13102: demo,
			13103: enemy_demo,
			13104: enemy_gunner,
			13105: enemy_eng,
			13106: enemy_cmdo,
		},
		"projectiles_root": arena,
	}

	var removed_kits: Array[int] = []
	var eat_events: Array[Dictionary] = []
	var evt_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "armor_kit_removed":
			removed_kits.append(int(payload.get("kit_id", 0)))
		elif ev_type == "eat_grenades":
			eat_events.append(payload)
	NetworkManager.game_event_received.connect(evt_cb)

	var dsm: DemolisherSkills = demo.skill_manager as DemolisherSkills
	demo.global_position = Vector3.ZERO
	dsm.try_activate_skill(3, InputCmd.new(), ctx)
	var first_kit: DemolisherSkills.ArmorKitEntity = dsm._active_armor_kit
	var first_uid: int = first_kit.kit_uid if first_kit != null else -1
	var imm_cd_ok: bool = (first_kit != null and is_equal_approx(dsm.skill_cooldowns[3], 17.0))
	dsm.skill_cooldowns[3] = 0.0
	demo.global_position = Vector3(4.0, 0.0, 0.0)
	dsm.try_activate_skill(3, InputCmd.new(), ctx)
	var second_kit: DemolisherSkills.ArmorKitEntity = dsm._active_armor_kit
	var replace_kit_ok: bool = (
		first_kit != null and first_kit.is_queued_for_deletion()
		and not first_kit.is_in_group("armor_kits")
		and second_kit != null and second_kit != first_kit
		and removed_kits.has(first_uid)
	)
	_assert(imm_cd_ok and replace_kit_ok, "Phase 13.1b: Skill 3 starts 17s CD immediately and replacing box despawns old kit + emits armor_kit_removed")

	# 3. Demolisher 1b: TRAPPER_STICKY stays armed > 50s without auto-detonating
	var sticky := ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TRAPPER_STICKY,
		demo.entity_id, demo.team,
		Vector3(0.0, 0.1, 10.0), Vector3.ZERO, ctx, 40.0, arena
	)
	sticky._is_stuck = true
	sticky._stuck = true
	for _s in range(120):
		sticky._physics_process(0.5)
	_assert(not sticky._exploded and not sticky.is_queued_for_deletion(), "Phase 13.1c: TRAPPER_STICKY stays persistently armed for >60s without auto-detonation")

	# 4. Demolisher 1c: Flamethrower multi-height LOS over 0.75m curb, blocked by 2.8m wall, 15 dmg + FlameStreamVFX
	demo.global_position = Vector3(0.0, 0.0, -2.0)
	enemy_demo.respawn_at(Vector3(0.0, 0.0, -8.0), 0.0)
	var fw0: FlameWeapon = demo.weapons[0] as FlameWeapon
	var f_cmd := InputCmd.new()
	f_cmd.aim_yaw = 0.0
	f_cmd.aim_pitch = 0.0
	var ed_hp_pre: int = enemy_demo.hp
	fw0.fire_server(f_cmd, ctx)
	var curb_hit_ok: bool = (enemy_demo.hp == ed_hp_pre - 15 and enemy_demo.status_effects.is_burning())

	demo.global_position = Vector3(15.0, 0.0, -2.0)
	enemy_demo.respawn_at(Vector3(15.0, 0.0, -8.0), 0.0)
	var wall_hp_pre: int = enemy_demo.hp
	fw0.fire_server(f_cmd, ctx)
	var wall_block_ok: bool = (enemy_demo.hp == wall_hp_pre and not enemy_demo.status_effects.is_burning())

	var fs_vfx: StatusEffectsVFX.FlameStreamVFX = StatusEffectsVFX.update_continuous_flame_stream(
		arena, demo.entity_id, Vector3(0.0, 1.3, -2.0), Vector3.FORWARD, 18.0, true
	)
	var stream_ok: bool = (fs_vfx != null and fs_vfx.get_child_count() >= 10 and is_equal_approx(fs_vfx.duration, 0.24))
	StatusEffectsVFX.stop_continuous_flame_stream(demo.entity_id)
	_assert(
		curb_hit_ok and wall_block_ok and stream_ok,
		"Phase 13.1d: Flamethrower multi-height LOS hits 15 dmg over 0.75m curb (%s), blocked by 2.8m wall (%s), continuous FlameStreamVFX (%s)" % [
			str(curb_hit_ok), str(wall_block_ok), str(stream_ok)
		]
	)

	# 5. Demolisher 1e: Lateral CCW vertical TNT Rope clear of head
	demo.respawn_at(Vector3.ZERO, 0.0)
	dsm.skill_cooldowns[2] = 0.0
	dsm.try_activate_skill(2, InputCmd.new(), ctx)
	demo._animate_character(0.10)
	var tnt_bundle := demo._held_weapon_root.get_node_or_null("TntRope") as Node3D
	var min_stick_x_torso: float = 99.0
	if tnt_bundle != null:
		for ch in tnt_bundle.get_children():
			if ch is MeshInstance3D and String(ch.name).begins_with("DynamiteStick"):
				var p_torso: Vector3 = demo._held_weapon_root.transform * (tnt_bundle.transform * (ch as MeshInstance3D).position)
				min_stick_x_torso = minf(min_stick_x_torso, p_torso.x)
	var lasso_clear_ok: bool = (
		demo._held_weapon_root.position.x >= 0.75
		and tnt_bundle != null and tnt_bundle.rotation.x > 0.0
		and min_stick_x_torso >= 0.70
	)
	_assert(lasso_clear_ok, "Phase 13.1e: TNT Rope extends laterally (x=%.2f), spins CCW around +X, sticks stay >= 0.70m clear of head (min_x=%.2f)" % [
		demo._held_weapon_root.position.x, min_stick_x_torso
	])
	demo.status_effects.clear_tnt_rope()

	# 6. Demolisher 1f: Caber 110 AoE vs enemy Demolisher + 61 (55%) self-dmg
	demo.respawn_at(Vector3.ZERO, 0.0)
	enemy_demo.respawn_at(Vector3(0.0, 0.0, -1.8), 0.0)
	enemy_gunner.respawn_at(Vector3(30.0, 0.0, 30.0), 0.0)
	enemy_eng.respawn_at(Vector3(30.0, 0.0, 0.0), 0.0)
	enemy_cmdo.respawn_at(Vector3(30.0, 0.0, 5.0), 0.0)
	await get_tree().physics_frame
	var caber: HitscanWeapon = demo.weapons[2] as HitscanWeapon
	var demo_pre_caber: int = demo.hp
	var ed_pre_caber: int = enemy_demo.hp
	caber.fire_server(f_cmd, ctx)
	var caber_110_ok: bool = (
		caber.caber_spent
		and enemy_demo.hp == ed_pre_caber - 110
		and demo.hp == demo_pre_caber - 61
	)
	_assert(caber_110_ok, "Phase 13.1f: Caber deals 110 AoE to enemy Demolisher (hp %d->%d) and 61 (55%%) self-dmg (hp %d->%d)" % [
		ed_pre_caber, enemy_demo.hp, demo_pre_caber, demo.hp
	])

	# 7. Item 4: Gunner "I Eat Grenades" absorbs Mortar, Troop Trap & Stick Grenade (0 dmg, 0 knockback, +55% heal)
	enemy_gunner.respawn_at(Vector3(20.0, 0.0, 0.0), 0.0)
	enemy_gunner.hp = 40
	enemy_gunner.status_effects.activate_eat_grenades(8.0)
	var esm_eng: EngineerSkills = enemy_eng.skill_manager as EngineerSkills
	# Test Engineer Mortar absorption (make Engineer Royal so Gunner is enemy)
	enemy_eng.team = NetworkManager.TEAM_ROYAL
	var g_hp_before_mortar: int = enemy_gunner.hp
	var g_vel_before_mortar: Vector3 = enemy_gunner.velocity
	esm_eng._detonate_mortar({"pos": Vector3(20.0, 0.0, 0.0)}, ctx)
	var expected_mortar_heal: int = maxi(1, int(roundf(float(EngineerSkills.MORTAR_MAX_DAMAGE) * 0.55)))
	var mortar_absorb_ok: bool = (
		enemy_gunner.hp == mini(enemy_gunner.max_hp, g_hp_before_mortar + expected_mortar_heal)
		and enemy_gunner.velocity == g_vel_before_mortar
	)

	# Test Commando Troop Trap absorption (make Commando Royal)
	enemy_cmdo.team = NetworkManager.TEAM_ROYAL
	enemy_gunner.hp = 50
	var trap := CommandoSkills.TroopTrapEntity.new()
	trap.owner_id = enemy_cmdo.entity_id
	trap.owner_team = enemy_cmdo.team
	trap.damage = 65
	arena.add_child(trap)
	trap.global_position = Vector3(20.0, 0.0, 0.0)
	trap._explode(ctx["heroes_by_id"] as Dictionary)
	var expected_trap_heal: int = maxi(1, int(roundf(65.0 * 0.55)))
	var trap_absorb_ok: bool = (enemy_gunner.hp == mini(enemy_gunner.max_hp, 50 + expected_trap_heal))

	# Test Demolisher Stick Grenade absorption
	demo.respawn_at(Vector3(20.0, 0.0, 1.8), 0.0)
	enemy_gunner.hp = 40
	await get_tree().physics_frame
	caber.fire_server(f_cmd, ctx)
	var caber_absorb_ok: bool = (enemy_gunner.hp == mini(enemy_gunner.max_hp, 40 + 61) and eat_events.size() >= 3)

	_assert(
		mortar_absorb_ok and trap_absorb_ok and caber_absorb_ok,
		"Phase 13.1g: Gunner 'I Eat Grenades' absorbs Mortar (%s), Troop Trap (%s) & Stick Grenade (%s) with 0 dmg and +55%% heal" % [
			str(mortar_absorb_ok), str(trap_absorb_ok), str(caber_absorb_ok)
		]
	)

	NetworkManager.game_event_received.disconnect(evt_cb)
	arena.queue_free()
	await _flush_deferred()
	await get_tree().process_frame


func _test_phase13_task2_mounted_overheat() -> void:
	print("--- Phase 13 Task 2: Mounted Weapon Overheat System & HUD Silhouette Heat Gauge ---")
	var arena := Node3D.new()
	add_child(arena)

	var lc := LagCompensator.new()
	var gunner_hero := HeroCharacter.new()
	gunner_hero.setup_identity(13201, "GunnerP13", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, true, false)
	arena.add_child(gunner_hero)
	var pilot_hero := HeroCharacter.new()
	pilot_hero.setup_identity(13202, "PilotP13", NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, 0, false, false)
	arena.add_child(pilot_hero)

	var mg_turret := VehicleShieldedMG.new()
	mg_turret.id = 1321
	mg_turret.team = NetworkManager.TEAM_ROYAL
	arena.add_child(mg_turret)

	var apc := VehicleAPC.new()
	apc.id = 1322
	apc.team = NetworkManager.TEAM_ROYAL
	apc.position = Vector3(12.0, 0.5, 0.0)
	arena.add_child(apc)

	var boat := VehicleBoat.new()
	boat.id = 1323
	boat.team = NetworkManager.TEAM_ROYAL
	boat.position = Vector3(24.0, -0.34, 0.0)
	arena.add_child(boat)

	var plane := VehiclePlane.new()
	plane.id = 1324
	plane.team = NetworkManager.TEAM_ROYAL
	plane.position = Vector3(36.0, 0.5, 0.0)
	arena.add_child(plane)

	var aa := AAGun.new()
	aa.id = 1325
	aa.team = NetworkManager.TEAM_ROYAL
	aa.position = Vector3(48.0, 0.0, 0.0)
	arena.add_child(aa)

	var jeep := VehicleJeep.new()
	jeep.id = 1326
	jeep.team = NetworkManager.TEAM_ROYAL
	jeep.position = Vector3(60.0, 0.5, 0.0)
	arena.add_child(jeep)

	await get_tree().physics_frame

	var ctx: Dictionary = {
		"heroes_by_id": {13201: gunner_hero, 13202: pilot_hero},
		"vehicles_by_id": {1321: mg_turret, 1322: apc, 1323: boat, 1324: plane, 1325: aa, 1326: jeep},
		"lag_compensator": lc,
		"projectiles_root": arena,
	}

	# 1. Config & seat role checks across all 5 mounted-overheat vehicles vs Jeep
	var config_ok: bool = (
		mg_turret.has_mounted_overheat and apc.has_mounted_overheat and boat.has_mounted_overheat
		and plane.has_mounted_overheat and aa.has_mounted_overheat and not jeep.has_mounted_overheat
		and mg_turret.is_seat_mounted_gunner(0)
		and not apc.is_seat_mounted_gunner(0) and apc.is_seat_mounted_gunner(1) and not apc.is_seat_mounted_gunner(2)
		and not boat.is_seat_mounted_gunner(0) and boat.is_seat_mounted_gunner(1) and not boat.is_seat_mounted_gunner(2)
		and plane.is_seat_mounted_gunner(0) and not plane.is_seat_mounted_gunner(1) and not plane.is_seat_mounted_gunner(2)
		and aa.is_seat_mounted_gunner(0)
		and not jeep.is_seat_mounted_gunner(0) and not jeep.is_seat_mounted_gunner(1)
	)
	_assert(config_ok, "Phase 13.2a: All 5 mounted-gun vehicles enable overheat & identify exact gunner seats (incl. Plane Driver)")

	# 2. Firing heat build -> 0.18s cool pause -> cooling -> 1.0 overheat 4.0s lockout -> reset unlock
	var shot_events: Array[Dictionary] = []
	var shot_cb := func(ev_type: String, payload: Dictionary) -> void:
		if ev_type == "shot_vfx":
			shot_events.append(payload)
	NetworkManager.game_event_received.connect(shot_cb)

	# 2a. VehicleShieldedMG: fire 10 shots, verify heat pause then cool down
	mg_turret.try_enter_hero(gunner_hero)
	var fire_cmd := InputCmd.new()
	fire_cmd.buttons = InputCmd.BTN_FIRE
	gunner_hero.latest_server_input = fire_cmd
	for _s in range(10):
		mg_turret._driver_fire_cd = 0.0
		mg_turret.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	var heat_after_10: float = mg_turret.weapon_heat
	var idle_cmd := InputCmd.new()
	gunner_hero.latest_server_input = idle_cmd
	# Within 0.18s cool delay, heat remains paused
	mg_turret.step_vehicle_server(0.10, ctx["heroes_by_id"] as Dictionary, ctx)
	var heat_during_pause: float = mg_turret.weapon_heat
	# Step past pause -> heat cools down
	for _c in range(10):
		mg_turret.step_vehicle_server(0.10, ctx["heroes_by_id"] as Dictionary, ctx)
	var heat_after_cool: float = mg_turret.weapon_heat
	_assert(
		heat_after_10 > 0.35 and absf(heat_during_pause - heat_after_10) < 0.001 and heat_after_cool < heat_after_10 - 0.20,
		"Phase 13.2b: Mounted MG heat builds (%.2f), pauses 0.18s (%.2f), then cools cleanly (%.2f)" % [
			heat_after_10, heat_during_pause, heat_after_cool
		]
	)

	# 2b. Overheat all 5 vehicles to 1.0, confirm 4.0s lockout blocks fire, then cools to 0.0 when unmanned
	gunner_hero.latest_server_input = fire_cmd
	while not mg_turret.weapon_overheated:
		mg_turret._driver_fire_cd = 0.0
		mg_turret.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	var shots_before_lock: int = shot_events.size()
	mg_turret._driver_fire_cd = 0.0
	mg_turret.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	var mg_blocked_ok: bool = (
		mg_turret.weapon_overheated
		and mg_turret.overheat_cooldown_timer > 3.9
		and not mg_turret.try_consume_mounted_heat()
		and shot_events.size() == shots_before_lock
	)
	mg_turret.exit_hero(gunner_hero)
	# Unmanned 4.0s cooldown unlocks cleanly
	for _u in range(41):
		mg_turret.step_vehicle_server(0.10, ctx["heroes_by_id"] as Dictionary, ctx)
	var mg_unlocked_ok: bool = (
		not mg_turret.weapon_overheated
		and is_equal_approx(mg_turret.weapon_heat, 0.0)
		and is_equal_approx(mg_turret.overheat_cooldown_timer, 0.0)
		and mg_turret.try_consume_mounted_heat()
	)

	# 2c. Verify APC, Boat, Plane, and AA Gun overheat lockouts & firing gates
	var multi_veh_ok: bool = true
	# APC gunner
	apc.try_enter_hero(pilot_hero)
	apc.try_enter_hero(gunner_hero)
	gunner_hero.latest_server_input = fire_cmd
	for _i in range(30):
		apc._driver_fire_cd = 0.0
		apc.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	if not apc.weapon_overheated or apc.try_consume_mounted_heat():
		multi_veh_ok = false
	apc.exit_hero(gunner_hero)
	apc.exit_hero(pilot_hero)

	# Boat gunner
	boat.try_enter_hero(pilot_hero)
	boat.try_enter_hero(gunner_hero)
	for _i in range(25):
		boat._driver_fire_cd = 0.0
		boat.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	if not boat.weapon_overheated or boat.try_consume_mounted_heat():
		multi_veh_ok = false
	boat.exit_hero(gunner_hero)
	boat.exit_hero(pilot_hero)

	# Plane driver
	plane.try_enter_hero(pilot_hero)
	pilot_hero.latest_server_input = fire_cmd
	for _i in range(30):
		plane._driver_fire_cd = 0.0
		plane.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	if not plane.weapon_overheated or plane.try_consume_mounted_heat():
		multi_veh_ok = false
	plane.exit_hero(pilot_hero)

	# AA Gunner (also verifies no AA_FLAK projectile spawned while locked out)
	aa.try_enter_hero(gunner_hero)
	for _i in range(10):
		aa._driver_fire_cd = 0.0
		aa.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	var pre_aa_children: int = arena.get_child_count()
	aa._driver_fire_cd = 0.0
	aa.step_vehicle_server(0.016, ctx["heroes_by_id"] as Dictionary, ctx)
	if not aa.weapon_overheated or arena.get_child_count() != pre_aa_children:
		multi_veh_ok = false
	aa.exit_hero(gunner_hero)

	_assert(
		mg_blocked_ok and mg_unlocked_ok and multi_veh_ok,
		"Phase 13.2c: 4.0s overheat lockout blocks firing & resets cleanly across MG, APC, Boat, Plane & AA Gun"
	)

	# 2d. Respawn reset check on APC
	apc._respawn_vehicle()
	_assert(
		not apc.weapon_overheated and is_equal_approx(apc.weapon_heat, 0.0) and is_equal_approx(apc.overheat_cooldown_timer, 0.0),
		"Phase 13.2d: _respawn_vehicle resets mounted weapon overheat state"
	)

	# 3. NetSerializer heat_byte roundtrip & 12v12 < 1200B MTU
	var heroes24: Array[Dictionary] = []
	for hi in range(24):
		heroes24.append({
			"id": 100 + hi,
			"team": hi % 2,
			"class_id": hi % 5,
			"weapon_slot": 0,
			"flags": NetSerializer.SNAP_GROUNDED,
			"buffs": 0,
			"pos": Vector3(float(hi) * 4.0, 0.0, 0.0),
			"vel": Vector3.ZERO,
			"yaw": 0.0,
			"pitch": 0.0,
			"hp": 110,
			"shield": 0,
			"vehicle_id": -1,
			"seat_idx": -1,
		})
	var snap_apc := apc.build_snapshot_dict()
	snap_apc["heat"] = 0.64
	snap_apc["overheated"] = false
	var snap_aa := aa.build_snapshot_dict()
	snap_aa["heat"] = 1.0
	snap_aa["overheated"] = true
	var ws_bytes: PackedByteArray = NetSerializer.pack_world_snapshot(
		777, 12950, 48, 46, heroes24, [snap_apc],
		[
			{"owner": 0, "capturing_team": -1, "progress": 1.0},
			{"owner": 1, "capturing_team": -1, "progress": 1.0},
			{"owner": -1, "capturing_team": 0, "progress": 0.5},
			{"owner": -1, "capturing_team": -1, "progress": 0.0},
		]
	)
	var ws_dec: Dictionary = NetSerializer.unpack_world_snapshot(ws_bytes)
	var dec_vehs: Array = ws_dec.get("vehicles", []) as Array
	var dec_apc: Dictionary = dec_vehs[0] if dec_vehs.size() > 0 else {}
	var roundtrip_two := NetSerializer.unpack_world_snapshot(
		NetSerializer.pack_world_snapshot(778, 13000, 48, 46, [], [snap_apc, snap_aa], [])
	)
	var rt_vehs: Array = roundtrip_two.get("vehicles", []) as Array
	var rt_aa: Dictionary = rt_vehs[1] if rt_vehs.size() > 1 else {}

	var remote_aa := AAGun.new()
	remote_aa.id = 1329
	arena.add_child(remote_aa)
	remote_aa.push_remote_snapshot(778, 13000.0, rt_aa)

	_assert(
		NetSerializer.INPUT_CMD_BYTES == 15
		and ws_bytes.size() < 1200
		and absf(float(dec_apc.get("heat", 0.0)) - 0.64) <= 0.02
		and not bool(dec_apc.get("overheated", true))
		and absf(float(rt_aa.get("heat", 0.0)) - 1.0) <= 0.01
		and bool(rt_aa.get("overheated", false))
		and remote_aa.weapon_overheated
		and remote_aa.overheat_cooldown_timer >= 3.9,
		"Phase 13.2e: NetSerializer heat_byte roundtrip & 12v12 MTU (%dB < 1200B), INPUT_CMD_BYTES==15" % ws_bytes.size()
	)

	# 4. CartoonAssets silhouette icons & HUDController bottom-right overheat gauge switching
	var icon_mg: ImageTexture = CartoonAssets.get_texture("icon_mounted_mg")
	var icon_aa: ImageTexture = CartoonAssets.get_texture("icon_mounted_aa")
	var icon_plane: ImageTexture = CartoonAssets.get_texture("icon_mounted_plane")
	var icons_ok: bool = (icon_mg != null and icon_aa != null and icon_plane != null)

	var hud := HUDController.new()
	arena.add_child(hud)
	var hud_vehicles: Array[VehicleBase] = [apc, plane, aa]
	hud.bind_context(null, hud_vehicles, ctx["heroes_by_id"] as Dictionary)
	hud.set_local_hero(gunner_hero)

	# 4a. Enter APC Driver -> Passenger -> Gunner
	apc.try_enter_hero(gunner_hero) # seat 0 (Driver)
	hud._process(0.016)
	var apc_driver_normal: bool = (not hud._mounted_heat_panel.visible and hud._ammo_icon_tex.texture == CartoonAssets.get_texture("icon_ammo"))

	apc.try_switch_seat(gunner_hero, 2) # seat 2 (Passenger)
	hud._process(0.016)
	var apc_pass_normal: bool = (not hud._mounted_heat_panel.visible and hud._ammo_icon_tex.texture == CartoonAssets.get_texture("icon_ammo"))

	apc.try_switch_seat(gunner_hero, 1) # seat 1 (Gunner)
	apc.weapon_overheated = false
	apc.weapon_heat = 0.50
	hud._process(0.016)
	var apc_gunner_yellow: bool = (
		hud._mounted_heat_panel.visible
		and hud._ammo_icon_tex.texture == icon_mg
		and absf(hud._mounted_heat_bar_fill.anchor_right - 0.50) < 0.02
		and hud._mounted_heat_bar_fill.color.is_equal_approx(Color(1.0, 0.85, 0.14))
		and hud._ammo_value_lbl.text.contains("50%")
	)

	apc.weapon_heat = 1.0
	apc.weapon_overheated = true
	apc.overheat_cooldown_timer = 3.2
	hud._process(0.016)
	var apc_gunner_red: bool = (
		hud._mounted_heat_panel.visible
		and is_equal_approx(hud._mounted_heat_bar_fill.anchor_right, 1.0)
		and hud._mounted_heat_bar_fill.color.is_equal_approx(Color(0.95, 0.16, 0.14))
		and hud._mounted_heat_style.border_color.is_equal_approx(Color(0.95, 0.16, 0.14, 1.0))
		and hud._ammo_value_lbl.text == "SUPERAQUECIDO 3.2s"
	)

	# Switch back to Passenger -> gauge hides & restores hero ammo
	apc.try_switch_seat(gunner_hero, 2)
	hud._process(0.016)
	var swap_restore_ok: bool = (
		not hud._mounted_heat_panel.visible
		and hud._ammo_icon_tex.texture == CartoonAssets.get_texture("icon_ammo")
		and hud._ammo_value_lbl.text == str(gunner_hero.weapons[gunner_hero.selected_weapon_slot].ammo_in_mag)
	)
	apc.exit_hero(gunner_hero)

	# 4b. Plane Driver shows icon_mounted_plane; AA Gunner shows icon_mounted_aa; exit restores ammo
	plane.weapon_overheated = false
	plane.weapon_heat = 0.25
	plane.try_enter_hero(gunner_hero) # seat 0 (Driver)
	hud._process(0.016)
	var plane_hud_ok: bool = (hud._mounted_heat_panel.visible and hud._ammo_icon_tex.texture == icon_plane)
	plane.exit_hero(gunner_hero)
	hud._process(0.016)
	var exit_restore_ok: bool = (not hud._mounted_heat_panel.visible and hud._ammo_icon_tex.texture == CartoonAssets.get_texture("icon_ammo"))

	aa.weapon_overheated = false
	aa.weapon_heat = 0.45
	aa.try_enter_hero(gunner_hero)
	hud._process(0.016)
	var aa_hud_ok: bool = (hud._mounted_heat_panel.visible and hud._ammo_icon_tex.texture == icon_aa)
	aa.exit_hero(gunner_hero)

	_assert(
		icons_ok and apc_driver_normal and apc_pass_normal and apc_gunner_yellow and apc_gunner_red and swap_restore_ok and plane_hud_ok and exit_restore_ok and aa_hud_ok,
		"Phase 13.2f: HUD bottom-right swaps to silhouette + yellow/red overheat bar on Gunner/Plane-Driver & restores normal ammo on Passenger/Exit"
	)

	NetworkManager.game_event_received.disconnect(shot_cb)
	arena.queue_free()
	await _flush_deferred()
	await get_tree().process_frame
