class_name VehicleBoat
extends VehicleBase

## Aquatic Patrol / Landing Boat: Buoyancy over ocean (Y = 0.0),
## 1 Driver + 2 open deck Passengers who can fire weapons, skills & Wrench.
const MAX_WATER_SPEED: float = 24.0
const ACCEL: float = 34.0
const TURN_RATE: float = 2.75
const LATERAL_GRIP: float = 10.0
const IDLE_DRAG: float = 3.5
const BUOYANCY_STIFFNESS: float = 36.0
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
	_apply_built_visuals(VehicleMeshBuilder.build_boat_visuals(_visual_root, team))


func _physics_process(delta: float) -> void:
	if _enforce_remote_freeze():
		return
	if is_destroyed or freeze:
		return
	_apply_buoyancy_and_leveling(delta)


func _apply_buoyancy_and_leveling(delta: float) -> void:
	var water_y: float = HeroCharacter.WATER_LEVEL
	var in_water: bool = global_position.y <= water_y + 0.65
	if in_water:
		# Equilibrium sits at global_position.y ~= -0.34m (keel in -0.35 ocean, deck & gunwales crisp above water)
		var submersion: float = clampf((water_y + 0.20) - global_position.y, 0.0, 2.5)
		apply_central_force(Vector3.UP * (submersion * BUOYANCY_STIFFNESS - linear_velocity.y * 6.0) * mass * 0.50)
		var has_driver: bool = not seats.is_empty() and seats[0].occupant_id >= 0
		if not has_driver:
			linear_velocity.x = lerpf(linear_velocity.x, 0.0, WATER_DRAG * delta)
			linear_velocity.z = lerpf(linear_velocity.z, 0.0, WATER_DRAG * delta)
	rotation.x = lerpf(rotation.x, 0.0, 5.0 * delta)
	rotation.z = lerpf(rotation.z, 0.0, 5.0 * delta)


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var water_y: float = HeroCharacter.WATER_LEVEL
	var in_water: bool = global_position.y <= water_y + 0.65

	if in_water:
		var cmd: InputCmd = driver.latest_server_input if driver != null else null
		_apply_arcade_drive(delta, cmd, MAX_WATER_SPEED, ACCEL, TURN_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)
		_process_roadkill(driver, context, Vector2(1.5, 3.2), 5.5)

		if driver != null and cmd != null:
			# Bow light gun on fire
			if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
				_driver_fire_cd = 0.14
				var fire_dir: Vector3 = -Basis.from_euler(Vector3(cmd.aim_pitch, cmd.aim_yaw, 0.0)).z.normalized()
				var muzzle: Vector3 = global_position + Vector3(0.0, 1.9, 0.0) + fire_dir * 2.5
				_fire_ballistic_mg(driver, muzzle, fire_dir, 140.0, 16.0, 140.0, 14, 18, context)
