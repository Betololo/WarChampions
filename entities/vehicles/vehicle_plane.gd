class_name VehiclePlane
extends VehicleBase

## Arcade Fighter Plane: 3rd-person mouse/keyboard flight, dual front MGs,
## and 2 Wing-Riding seats (left & right wings) where allies shoot or Wrench-repair!
const CRUISE_SPEED: float = 34.0
const MAX_FLIGHT_SPEED: float = 52.0
const TAKEOFF_SPEED: float = 15.0
const MG_FIRE_INTERVAL: float = 0.09


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.PLANE
	max_hp = 340
	hp = 340
	mass = 1400.0
	gravity_scale = 1.0
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.92, -0.15), false, false, false, "sit")
	# Wing-Riding slots on Left & Right wings!
	_add_seat(SeatType.WING_RIDER, Vector3(-3.3, 1.05, 0.15), true, true, false, "stand")
	_add_seat(SeatType.WING_RIDER, Vector3(3.3, 1.05, 0.15), true, true, false, "stand")


func _build_vehicle_mesh() -> void:
	# Slender lower fuselage collider (leaving open cockpit bay y > 0.98m unobstructed)
	var col_fuse := CollisionShape3D.new()
	var box_fuse := BoxShape3D.new()
	box_fuse.size = Vector3(1.05, 0.72, 5.6)
	col_fuse.shape = box_fuse
	col_fuse.position = Vector3(0.0, 0.62, 0.0)
	add_child(col_fuse)

	# Thin wings collider
	var col_wings := CollisionShape3D.new()
	var box_wings := BoxShape3D.new()
	box_wings.size = Vector3(8.5, 0.34, 2.0)
	col_wings.shape = box_wings
	col_wings.position = Vector3(0.0, 0.86, 0.0)
	add_child(col_wings)

	_apply_built_visuals(VehicleMeshBuilder.build_plane_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	if driver != null:
		gravity_scale = 0.0
		var cmd: InputCmd = driver.latest_server_input
		var target_speed: float = CRUISE_SPEED
		if cmd.move_dir.y < -0.1:
			target_speed = MAX_FLIGHT_SPEED
		elif cmd.move_dir.y > 0.1:
			target_speed = 18.0

		var forward: Vector3 = -global_transform.basis.z.normalized()
		var cur_speed: float = clampf(linear_velocity.length(), 0.0, MAX_FLIGHT_SPEED)
		cur_speed = lerpf(cur_speed, target_speed, 2.2 * delta)

		# Smoothly steer plane attitude toward pilot aim_yaw & aim_pitch
		var target_yaw: float = cmd.aim_yaw
		var target_pitch: float = clampf(cmd.aim_pitch, -0.75, 0.75)
		var yaw_diff: float = wrapf(target_yaw - rotation.y, -PI, PI)
		var bank_roll: float = clampf(-yaw_diff * 1.4 - cmd.move_dir.x * 0.7, -0.85, 0.85)

		rotation.y = lerp_angle(rotation.y, target_yaw, 2.8 * delta)
		rotation.x = lerpf(rotation.x, target_pitch, 3.2 * delta)
		rotation.z = lerpf(rotation.z, bank_roll, 4.0 * delta)

		var lift_y: float = 0.0 if cur_speed >= TAKEOFF_SPEED else -4.0
		linear_velocity = forward * cur_speed + Vector3(0.0, lift_y, 0.0)
		angular_velocity = Vector3.ZERO

		# Roadkill check when skimming near ground
		if global_position.y < 4.5:
			_process_roadkill(driver, context, Vector2(1.4, 2.8), 12.0)

		# Dual front MGs
		if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
			_driver_fire_cd = MG_FIRE_INTERVAL
			_fire_front_mgs(driver, forward, context)
	else:
		gravity_scale = 1.0
		linear_velocity.x = lerpf(linear_velocity.x, 0.0, 1.5 * delta)
		linear_velocity.z = lerpf(linear_velocity.z, 0.0, 1.5 * delta)
		if global_position.y < 1.2:
			rotation.x = lerpf(rotation.x, 0.0, 4.0 * delta)
			rotation.z = lerpf(rotation.z, 0.0, 4.0 * delta)


func _fire_front_mgs(driver: HeroCharacter, forward: Vector3, context: Dictionary) -> void:
	var origin: Vector3 = global_position + forward * 3.6
	_fire_ballistic_mg(driver, origin, forward, 165.0, 12.0, 240.0, 18, 24, context)
