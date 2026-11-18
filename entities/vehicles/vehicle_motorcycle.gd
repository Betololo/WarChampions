class_name VehicleMotorcycle
extends VehicleBase

## High-speed 2-Seat Military Motorcycle: agile driver + rear passenger who fires weapons, uses skills, and repairs.
const MAX_SPEED: float = 33.0
const ACCEL: float = 48.0
const STEER_RATE: float = 2.85
const LATERAL_GRIP: float = 16.0
const IDLE_DRAG: float = 4.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.MOTORCYCLE
	max_hp = 190
	hp = 190
	mass = 420.0
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.68, -0.12), false, false, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(0.0, 0.76, 0.68), true, true, false, "sit")


func _build_vehicle_mesh() -> void:
	var col_hull := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.05, 0.50, 2.55)
	col_hull.shape = box
	col_hull.position = Vector3(0.0, 0.75, 0.0)
	add_child(col_hull)

	for wz in [-0.88, 0.88]:
		var col_w := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.38
		col_w.shape = sph
		col_w.position = Vector3(0.0, 0.38, wz)
		add_child(col_w)

	_apply_built_visuals(VehicleMeshBuilder.build_motorcycle_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var cmd: InputCmd = driver.latest_server_input if driver != null else null
	_apply_arcade_drive(delta, cmd, MAX_SPEED, ACCEL, STEER_RATE, LATERAL_GRIP, IDLE_DRAG, 0.60)
	var throttle: float = -cmd.move_dir.y if cmd != null else 0.0
	_assist_curb_climb(throttle, 1.6, 0.50)
	_process_roadkill(driver, context, Vector2(0.75, 1.55), 5.0)
