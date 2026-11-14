class_name VehicleJeep
extends VehicleBase

## High-speed Recon Jeep: 1 Driver + 2 rear Passengers who fire weapons & skills freely, plus high-speed roadkill!
const MAX_SPEED: float = 26.0
const ACCEL: float = 28.0
const STEER_TORQUE: float = 4.2


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.JEEP
	max_hp = 280
	hp = 280
	mass = 900.0
	_add_seat(SeatType.DRIVER, Vector3(-0.46, 0.58, -0.05), false, false, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(-0.52, 0.62, 0.95), true, true, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(0.52, 0.62, 0.95), true, true, false, "sit")


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.3, 1.3, 4.4)
	col.shape = box
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	_apply_built_visuals(VehicleMeshBuilder.build_jeep_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var forward: Vector3 = -global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	if driver != null:
		var cmd: InputCmd = driver.latest_server_input
		var throttle: float = -cmd.move_dir.y
		var steer: float = -cmd.move_dir.x
		var cur_fwd_speed: float = linear_velocity.dot(flat_fwd)
		if absf(throttle) > 0.05 and absf(cur_fwd_speed) < MAX_SPEED:
			apply_central_force(flat_fwd * throttle * ACCEL * mass)
		if absf(steer) > 0.05:
			var speed_factor: float = clampf(linear_velocity.length() / 5.0, 0.35, 1.0)
			var dir_sign: float = 1.0 if cur_fwd_speed >= -0.5 else -1.0
			angular_velocity.y = lerpf(angular_velocity.y, steer * STEER_TORQUE * speed_factor * dir_sign, 8.0 * delta)
	else:
		linear_velocity.x = lerpf(linear_velocity.x, 0.0, 2.5 * delta)
		linear_velocity.z = lerpf(linear_velocity.z, 0.0, 2.5 * delta)

	# Keep upright arcade stability
	rotation.x = lerpf(rotation.x, 0.0, 6.0 * delta)
	rotation.z = lerpf(rotation.z, 0.0, 6.0 * delta)

	# Roadkill check at high speed
	var spd: float = linear_velocity.length()
	if spd > 10.0:
		var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h == null or h.is_defeated or h.current_vehicle_id >= 0:
				continue
			if driver != null and h.team == driver.team:
				continue
			if h.global_position.distance_to(global_position) <= 2.9:
				var driver_id: int = driver.entity_id if driver != null else -1
				h.apply_damage_server(int(spd * 4.5), driver_id, true)
				h.apply_knockback((h.global_position - global_position + Vector3(0.0, 0.6, 0.0)).normalized() * spd * 0.9)
