class_name AAGun
extends VehicleBase

## Fixed Anti-Aircraft Flak emplacement firing proximity-fuse shells against planes.
const FLAK_COOLDOWN: float = 0.38
const FLAK_SPEED: float = 98.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.AA_GUN
	max_hp = 320
	hp = 320
	freeze = true
	_add_seat(SeatType.GUNNER, Vector3(0.0, 0.88, 0.52), false, false, false, "sit", true)


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 1.8
	col.shape = cyl
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)
	_apply_built_visuals(VehicleMeshBuilder.build_aa_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, _delta: float, context: Dictionary) -> void:
	if driver == null:
		return
	var cmd: InputCmd = driver.latest_server_input
	turret_yaw = cmd.aim_yaw
	turret_pitch = cmd.aim_pitch
	if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
		_driver_fire_cd = FLAK_COOLDOWN
		var aim_basis := Basis.from_euler(Vector3(cmd.aim_pitch, turret_yaw, 0.0))
		var fire_dir: Vector3 = -aim_basis.z.normalized()
		var muzzle: Vector3 = global_position + Vector3(0.0, 1.8, 0.0) + fire_dir * 2.5
		ProjectileEntity.spawn_server_projectile(
			ProjectileEntity.ProjectileKind.AA_FLAK,
			driver.entity_id,
			driver.team,
			muzzle,
			fire_dir * FLAK_SPEED,
			context,
			-1.0,
			get_parent()
		)
