class_name VehicleJeep
extends VehicleBase

## High-speed Recon Jeep: 1 Driver + 2 rear Passengers who fire weapons & skills freely, plus high-speed roadkill!
const MAX_SPEED: float = 28.0
const ACCEL: float = 42.0
const STEER_RATE: float = 3.2
const LATERAL_GRIP: float = 13.0
const IDLE_DRAG: float = 4.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.JEEP
	max_hp = 280
	hp = 280
	mass = 900.0
	_add_seat(SeatType.DRIVER, Vector3(-0.46, 0.58, -0.05), false, false, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(-0.52, 0.62, 0.95), true, true, false, "sit")
	_add_seat(SeatType.PASSENGER, Vector3(0.52, 0.62, 0.95), true, true, false, "sit")


func _build_vehicle_mesh() -> void:
	# Main hull box with elevated belly clearance (bottom y = 0.55m, top y = 1.07m <= 1.10m)
	var col_hull := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.1, 0.52, 4.0)
	col_hull.shape = box
	col_hull.position = Vector3(0.0, 0.81, 0.0)
	add_child(col_hull)

	# 4 rounded wheel skids (y = 0.0..0.85) at corners so curbs & steps roll up curved radius naturally
	for wx in [-0.95, 0.95]:
		for wz in [-1.45, 1.45]:
			var col_w := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.425
			col_w.shape = sph
			col_w.position = Vector3(wx, 0.425, wz)
			add_child(col_w)

	_apply_built_visuals(VehicleMeshBuilder.build_jeep_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var cmd: InputCmd = driver.latest_server_input if driver != null else null
	_apply_arcade_drive(delta, cmd, MAX_SPEED, ACCEL, STEER_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)
	var throttle: float = -cmd.move_dir.y if cmd != null else 0.0
	_assist_curb_climb(throttle, 2.2, 0.55)
	_process_roadkill(driver, context, Vector2(1.15, 2.2), 5.5)
