class_name VehicleBoat
extends VehicleBase

## Aquatic Patrol / Landing Boat: Buoyancy over ocean (Y = 0.0),
## Pilot (no weapon) + Bow Twin-MG Gunner + Rear Standing Passenger (weapons/skills/Wrench).
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
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.85, 0.35), false, false, false, "sit")
	_add_seat(SeatType.GUNNER, Vector3(0.0, 0.96, -1.95), false, false, false, "stand", true)
	_add_seat(SeatType.PASSENGER, Vector3(0.0, 0.76, 1.95), true, true, false, "stand")


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.9, 0.90, 6.2)
	col.shape = box
	col.position = Vector3(0.0, 0.45, 0.0)
	add_child(col)
	_apply_built_visuals(VehicleMeshBuilder.build_boat_visuals(_visual_root, team))


func _physics_process(delta: float) -> void:
	if _enforce_remote_freeze():
		return
	if is_destroyed or freeze or sleeping:
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
	var cur_y: float = global_position.y if is_inside_tree() else position.y
	var in_water: bool = cur_y <= water_y + 0.65

	if in_water:
		var cmd: InputCmd = driver.latest_server_input if driver != null else null
		_apply_arcade_drive(delta, cmd, MAX_WATER_SPEED, ACCEL, TURN_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)
		_process_roadkill(driver, context, Vector2(1.5, 3.2), 5.5)

	var heroes_by_id: Dictionary = context.get("heroes_by_id", _last_heroes_by_id)
	var gunner: HeroCharacter = get_gunner_hero(heroes_by_id)
	if gunner != null and gunner.latest_server_input != null:
		var gun_cmd: InputCmd = gunner.latest_server_input
		turret_yaw = gun_cmd.aim_yaw
		turret_pitch = clampf(gun_cmd.aim_pitch, -0.35, 0.65)
		if _turret_node != null:
			_turret_node.rotation.y = _effective_turret_local_yaw()
		if gun_cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
			_driver_fire_cd = 0.14
			var fire_dir: Vector3 = -Basis.from_euler(Vector3(turret_pitch, turret_yaw, 0.0)).z.normalized()
			var muzzle_base: Vector3 = _barrel_pivot.global_position if (_barrel_pivot != null and is_inside_tree()) else ((global_transform if is_inside_tree() else transform) * Vector3(0.0, 1.40, -2.52))
			var muzzle: Vector3 = muzzle_base + fire_dir * 0.88
			_fire_ballistic_mg(gunner, muzzle, fire_dir, 140.0, 16.0, 140.0, 14, 18, context)
