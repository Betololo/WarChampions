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
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.92, -0.15), false, false, true, "sit")
	# Wing-Riding slots on Left & Right wings!
	_add_seat(SeatType.WING_RIDER, Vector3(-3.3, 1.05, 0.15), true, true, false, "stand")
	_add_seat(SeatType.WING_RIDER, Vector3(3.3, 1.05, 0.15), true, true, false, "stand")


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.5, 1.6, 5.8)
	col.shape = box
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	var body_col: Color = Color(0.24, 0.45, 0.78) if team == 0 else Color(0.32, 0.34, 0.36)
	var accent_col: Color = Color(0.95, 0.82, 0.25) if team == 0 else Color(0.84, 0.16, 0.16)
	# Fuselage
	_add_box_part(_visual_root, Vector3(1.25, 1.15, 5.8), Vector3(0.0, 0.95, 0.0), body_col)
	# Wings for Wing-Riding
	_add_box_part(_visual_root, Vector3(9.4, 0.22, 1.85), Vector3(0.0, 0.85, -0.1), body_col.lightened(0.08))
	# Tail & Nose
	_add_box_part(_visual_root, Vector3(3.1, 0.18, 1.0), Vector3(0.0, 1.0, 2.5), accent_col)
	_add_box_part(_visual_root, Vector3(0.2, 1.1, 1.0), Vector3(0.0, 1.5, 2.5), accent_col)
	_add_box_part(_visual_root, Vector3(0.75, 0.75, 0.65), Vector3(0.0, 0.95, -3.1), accent_col)


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
