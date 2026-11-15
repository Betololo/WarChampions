class_name VehicleTank
extends VehicleBase

## Heavy Armor Tank: 360-deg turret, parabolic cannon with splash & projectile drop,
## 2.0x rear armor damage, and external rear passenger/repair seat.
const MAX_SPEED: float = 14.0
const ACCEL: float = 26.0
const TURN_RATE: float = 2.1
const LATERAL_GRIP: float = 14.0
const IDLE_DRAG: float = 5.5
const CANNON_COOLDOWN: float = 1.85
const SHELL_SPEED: float = 62.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.TANK
	max_hp = 520
	hp = 520
	mass = 4500.0
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.95, 0.0), false, false, true, "hidden")
	# External rear engine-deck ride seat (Wrench repair in motion!)
	_add_seat(SeatType.PASSENGER, Vector3(0.0, 1.55, 2.35), true, true, false, "stand")


func _build_vehicle_mesh() -> void:
	# Main hull box with elevated belly clearance (bottom y = 0.60m, top y = 2.10m)
	var col_hull := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.2, 1.5, 5.2)
	col_hull.shape = box
	col_hull.position = Vector3(0.0, 1.35, 0.0)
	add_child(col_hull)

	# Rounded front/rear tread sprocket skids (y = 0.0..1.05)
	for tx in [-1.45, 1.45]:
		for tz in [-2.15, 2.15]:
			var col_sprocket := CollisionShape3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.525
			col_sprocket.shape = sph
			col_sprocket.position = Vector3(tx, 0.525, tz)
			add_child(col_sprocket)

	_apply_built_visuals(VehicleMeshBuilder.build_tank_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var cmd: InputCmd = driver.latest_server_input if driver != null else null
	_apply_arcade_drive(delta, cmd, MAX_SPEED, ACCEL, TURN_RATE, LATERAL_GRIP, IDLE_DRAG, 0.65)
	var throttle: float = -cmd.move_dir.y if cmd != null else 0.0
	_assist_curb_climb(throttle, 2.7, 0.55)
	_process_roadkill(driver, context, Vector2(1.7, 2.8), 5.5)

	if driver != null and cmd != null:
		turret_yaw = cmd.aim_yaw
		turret_pitch = cmd.aim_pitch

		if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
			_driver_fire_cd = CANNON_COOLDOWN
			var aim_basis := Basis.from_euler(Vector3(cmd.aim_pitch, turret_yaw, 0.0))
			var fire_dir: Vector3 = -aim_basis.z.normalized()
			var muzzle_pos: Vector3 = global_position + Vector3(0.0, 2.2, 0.0) + fire_dir * 3.8
			ProjectileEntity.spawn_server_projectile(
				ProjectileEntity.ProjectileKind.TANK_SHELL,
				driver.entity_id,
				driver.team,
				muzzle_pos,
				fire_dir * SHELL_SPEED,
				context,
				-1.0,
				get_parent()
			)
			NetworkManager.broadcast_game_event("shot_vfx", {
				"shooter_id": driver.entity_id,
				"weapon_kind": WeaponBase.WeaponKind.BAZOOKA,
				"origin": muzzle_pos,
				"dir": fire_dir,
				"hits": [],
				"vehicle_shot": true,
			})
