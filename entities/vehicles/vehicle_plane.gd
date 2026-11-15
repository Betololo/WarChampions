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
	# Slender lower fuselage collider with elevated belly clearance so nose-up takeoff pitch never snags the tail
	var col_fuse := CollisionShape3D.new()
	var box_fuse := BoxShape3D.new()
	box_fuse.size = Vector3(1.05, 0.58, 5.4)
	col_fuse.shape = box_fuse
	col_fuse.position = Vector3(0.0, 0.72, 0.0)
	add_child(col_fuse)

	# 3-point tricycle landing gear spheres for smooth low-drag runway roll & rotation
	for gear_pos in [Vector3(0.0, 0.28, -1.65), Vector3(-0.85, 0.28, 0.35), Vector3(0.85, 0.28, 0.35)]:
		var col_gear := CollisionShape3D.new()
		var sph_gear := SphereShape3D.new()
		sph_gear.radius = 0.28
		col_gear.shape = sph_gear
		col_gear.position = gear_pos
		add_child(col_gear)

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
		cur_speed = lerpf(cur_speed, target_speed, 2.6 * delta)

		# Support both mouse aim pitch/yaw AND Space (climb) / Crouch (dive) / A-D (roll)
		var climb_input: float = (0.34 if cmd.has_button(InputCmd.BTN_JUMP) else 0.0) - (0.30 if cmd.has_button(InputCmd.BTN_CROUCH) else 0.0)
		var target_yaw: float = cmd.aim_yaw
		var target_pitch: float = clampf(cmd.aim_pitch + climb_input, -0.75, 0.75)

		# Automatic aerodynamic liftoff once past takeoff speed on runway (unless deliberately diving)
		var near_runway: bool = global_position.y < 6.5
		if near_runway and cur_speed >= TAKEOFF_SPEED and target_pitch > -0.15:
			target_pitch = maxf(target_pitch, 0.18)

		var airborne: bool = cur_speed >= TAKEOFF_SPEED or global_position.y >= 4.2
		var yaw_diff: float = wrapf(target_yaw - rotation.y, -PI, PI)
		var yaw_rate: float = 2.8 if airborne else 1.15
		var bank_roll: float = clampf(-yaw_diff * 1.4 - cmd.move_dir.x * 0.7, -0.85, 0.85) if airborne else 0.0

		rotation.y = lerp_angle(rotation.y, target_yaw, yaw_rate * delta)
		rotation.x = lerpf(rotation.x, target_pitch, 3.4 * delta)
		rotation.z = lerpf(rotation.z, bank_roll, 4.2 * delta)

		var lift_y: float = 0.0 if cur_speed >= TAKEOFF_SPEED else -4.0
		if near_runway and cur_speed >= TAKEOFF_SPEED and target_pitch > -0.10:
			lift_y = clampf((cur_speed - TAKEOFF_SPEED) * 0.35 + 1.4, 1.4, 4.5)
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
