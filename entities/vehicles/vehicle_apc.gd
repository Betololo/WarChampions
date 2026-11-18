class_name VehicleAPC
extends VehicleBase

## Armored MG Carrier (Blindado): enclosed armored driver + 360-degree mounted MG turret gunner.
const MAX_SPEED: float = 21.0
const ACCEL: float = 32.0
const STEER_RATE: float = 2.15
const LATERAL_GRIP: float = 14.5
const IDLE_DRAG: float = 4.8
const MG_FIRE_INTERVAL: float = 0.095
const MG_HERO_DMG: int = 16
const MG_OBJ_DMG: int = 22


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.APC
	max_hp = 420
	hp = 420
	mass = 2600.0
	_add_seat(SeatType.DRIVER, Vector3(-0.45, 0.85, -0.35), false, false, true, "hidden")
	_add_seat(SeatType.GUNNER, Vector3(0.0, 1.48, 0.35), false, false, false, "stand", true)


func _build_vehicle_mesh() -> void:
	var col_hull := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.5, 1.15, 4.6)
	col_hull.shape = box
	col_hull.position = Vector3(0.0, 1.05, 0.0)
	add_child(col_hull)

	for wx in [-1.1, 1.1]:
		for wz in [-1.65, 1.65]:
			var col_w := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.46
			col_w.shape = sph
			col_w.position = Vector3(wx, 0.46, wz)
			add_child(col_w)

	_apply_built_visuals(VehicleMeshBuilder.build_apc_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var drv_cmd: InputCmd = driver.latest_server_input if driver != null else null
	_apply_arcade_drive(delta, drv_cmd, MAX_SPEED, ACCEL, STEER_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)
	var throttle: float = -drv_cmd.move_dir.y if drv_cmd != null else 0.0
	_assist_curb_climb(throttle, 2.5, 0.55)
	_process_roadkill(driver, context, Vector2(1.35, 2.45), 5.5)

	var heroes_by_id: Dictionary = context.get("heroes_by_id", _last_heroes_by_id)
	var gunner: HeroCharacter = get_gunner_hero(heroes_by_id)
	var operator: HeroCharacter = gunner if gunner != null else driver
	if operator != null and operator.latest_server_input != null:
		var op_cmd: InputCmd = operator.latest_server_input
		turret_yaw = op_cmd.aim_yaw
		turret_pitch = op_cmd.aim_pitch
		if op_cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
			_driver_fire_cd = MG_FIRE_INTERVAL
			var aim_b := Basis.from_euler(Vector3(clampf(turret_pitch, -0.45, 0.65), turret_yaw, 0.0))
			var fire_dir: Vector3 = (-aim_b.z).normalized()
			var muzzle: Vector3 = global_position + Vector3(0.0, 2.15, 0.0) + fire_dir * 2.3
			_fire_ballistic_mg(operator, muzzle, fire_dir, 175.0, 9.8 * 0.20, 220.0, MG_HERO_DMG, MG_OBJ_DMG, context)
