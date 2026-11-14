class_name VehicleBoat
extends VehicleBase

## Aquatic Patrol / Landing Boat: Buoyancy over ocean (Y = 0.0),
## 1 Driver + 2 open deck Passengers who can fire weapons, skills & Wrench.
const MAX_WATER_SPEED: float = 22.0
const BUOYANCY_STIFFNESS: float = 24.0
const WATER_DRAG: float = 2.8


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.BOAT
	max_hp = 380
	hp = 380
	mass = 1600.0
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.85, 0.35), false, false, true, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(-0.72, 0.72, -1.25), true, true, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(0.72, 0.72, -1.25), true, true, false, "sit")


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.4, 6.4)
	col.shape = box
	col.position = Vector3(0.0, 0.7, 0.0)
	add_child(col)

	var hull_col: Color = Color(0.25, 0.42, 0.65) if team == 0 else Color(0.28, 0.30, 0.33)
	var trim_col: Color = Color(0.86, 0.72, 0.38) if team == 0 else Color(0.76, 0.16, 0.16)
	_add_box_part(_visual_root, Vector3(2.9, 0.9, 6.2), Vector3(0.0, 0.65, 0.0), hull_col)
	_add_box_part(_visual_root, Vector3(1.8, 0.85, 1.8), Vector3(0.0, 1.35, 0.5), trim_col)
	_add_box_part(_visual_root, Vector3(0.35, 0.4, 1.2), Vector3(0.0, 1.3, -2.5), Color(0.18, 0.18, 0.18))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var water_y: float = HeroCharacter.WATER_LEVEL
	var in_water: bool = global_position.y <= water_y + 0.65

	if in_water:
		var submersion: float = clampf((water_y + 0.35) - global_position.y, 0.0, 2.5)
		apply_central_force(Vector3.UP * (submersion * BUOYANCY_STIFFNESS - linear_velocity.y * 5.0) * mass * 0.45)

		var forward: Vector3 = -global_transform.basis.z
		var flat_fwd := Vector3(forward.x, 0.0, forward.z).normalized()
		if driver != null:
			var cmd: InputCmd = driver.latest_server_input
			var throttle: float = -cmd.move_dir.y
			var steer: float = -cmd.move_dir.x
			if absf(throttle) > 0.05 and linear_velocity.length() < MAX_WATER_SPEED:
				apply_central_force(flat_fwd * throttle * 26.0 * mass)
			if absf(steer) > 0.05:
				angular_velocity.y = lerpf(angular_velocity.y, steer * 2.6, 5.0 * delta)
			# Bow light gun on fire
			if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
				_driver_fire_cd = 0.14
				var lag_comp: LagCompensator = context.get("lag_compensator", null)
				var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
				var fire_dir: Vector3 = -Basis.from_euler(Vector3(cmd.aim_pitch, cmd.aim_yaw, 0.0)).z.normalized()
				var muzzle: Vector3 = global_position + Vector3(0.0, 1.9, 0.0) + fire_dir * 2.5
				if lag_comp != null:
					var res: Dictionary = lag_comp.trace_rewound_ray(driver, muzzle, fire_dir, 140.0, cmd.view_interp_tick_delta, NetworkManager.server_tick, heroes_by_id, get_world_3d())
					var tid: int = int(res.get("target_hero_id", -1))
					if tid >= 0 and heroes_by_id.has(tid):
						(heroes_by_id[tid] as HeroCharacter).apply_damage_server(14, driver.entity_id, false)
					NetworkManager.broadcast_game_event("hit_vfx", {"pos": res.get("hit_pos", muzzle + fire_dir * 40.0), "kind": "spark", "attacker_id": driver.entity_id})
		else:
			linear_velocity.x = lerpf(linear_velocity.x, 0.0, WATER_DRAG * delta)
			linear_velocity.z = lerpf(linear_velocity.z, 0.0, WATER_DRAG * delta)

	rotation.x = lerpf(rotation.x, 0.0, 5.0 * delta)
	rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)
