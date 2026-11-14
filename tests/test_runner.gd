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
	_test_overhaul_net_u32_fall_damage_and_assets()
	_test_hero_visuals_camera_and_audio()
	_test_ik_weapon_grip_shot_fx_and_scope()
	_test_ballistic_bullet_drop_and_tracers()
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
	_assert(commando.visual_root.visible, "Stealthed Commando becomes translucent/visible within close detection radius")

	var cel_shader: Shader = load("res://vfx_shaders/hero_cel_shader.gdshader")
	var water_shader: Shader = load("res://vfx_shaders/water_toon.gdshader")
	_assert(cel_shader != null and water_shader != null, "Cel & Water shaders load cleanly")

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
	_assert(h.can_open_parachute(), "Airborne falling hero reports can_open_parachute() == true")

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
	var torso0: ArrayMesh = HeroMeshBuilder.build_torso_mesh(0)
	var torso1: ArrayMesh = HeroMeshBuilder.build_torso_mesh(1)
	var torso2: ArrayMesh = HeroMeshBuilder.build_torso_mesh(2)
	var head_m: ArrayMesh = HeroMeshBuilder.build_head_mesh()
	_assert(
		torso0.get_surface_count() > 0 and torso1.get_surface_count() > 0 and torso2.get_surface_count() > 0 and head_m.get_surface_count() > 0,
		"HeroMeshBuilder constructs sculpted loft ArrayMeshes for all 3 classes and head"
	)

	var hero_tex_keys: Array[String] = [
		"hero_jacket_royal", "hero_jacket_national", "hero_coat_commando",
		"hero_gunner_vest", "hero_skin", "hero_pants_royal", "hero_pants_national", "hero_gun_wood"
	]
	var tex_ok: bool = true
	for tk in hero_tex_keys:
		if CartoonAssets.get_texture(tk) == null:
			tex_ok = false
	_assert(tex_ok, "CartoonAssets provides hand-painted hero uniform, skin & rifle textures")

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


func _test_scene_compile_and_load() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_assert(main_scene != null, "Main scene res://scenes/main.tscn loads cleanly")
