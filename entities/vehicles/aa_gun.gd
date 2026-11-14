class_name AAGun
extends VehicleBase

## Fixed Anti-Aircraft Flak emplacement firing proximity-fuse shells against planes.
const FLAK_COOLDOWN: float = 0.38
const FLAK_SPEED: float = 95.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.AA_GUN
	max_hp = 320
	hp = 320
	freeze = true
	_add_seat(SeatType.GUNNER, Vector3(0.0, 0.88, 0.52), false, false, false, "sit")


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.6
	cyl.height = 1.8
	col.shape = cyl
	col.position = Vector3(0.0, 0.9, 0.0)
	add_child(col)

	_add_box_part(_visual_root, Vector3(2.4, 0.5, 2.4), Vector3(0.0, 0.25, 0.0), Color(0.28, 0.28, 0.26))
	_turret_node = Node3D.new()
	_turret_node.name = "AATurret"
	_turret_node.position = Vector3(0.0, 1.1, 0.0)
	_visual_root.add_child(_turret_node)
	_add_box_part(_turret_node, Vector3(1.2, 0.9, 1.2), Vector3(0.0, 0.2, 0.0), Color(0.32, 0.34, 0.30))
	_add_box_part(_turret_node, Vector3(0.18, 0.18, 2.4), Vector3(-0.3, 0.4, -1.1), Color(0.15, 0.15, 0.15))
	_add_box_part(_turret_node, Vector3(0.18, 0.18, 2.4), Vector3(0.3, 0.4, -1.1), Color(0.15, 0.15, 0.15))


func _drive_physics(driver: HeroCharacter, _delta: float, context: Dictionary) -> void:
	if driver == null:
		return
	var cmd: InputCmd = driver.latest_server_input
	turret_yaw = cmd.aim_yaw
	if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
		_driver_fire_cd = FLAK_COOLDOWN
		var aim_basis := Basis.from_euler(Vector3(cmd.aim_pitch, turret_yaw, 0.0))
		var fire_dir: Vector3 = -aim_basis.z.normalized()
		var muzzle: Vector3 = global_position + Vector3(0.0, 1.8, 0.0) + fire_dir * 2.5
		var flak := ProjectileEntity.new()
		flak.setup(ProjectileEntity.ProjectileKind.AA_FLAK, driver.entity_id, driver.team, muzzle, fire_dir * FLAK_SPEED, context)
		var projectiles_root: Node = context.get("projectiles_root", get_parent())
		if projectiles_root != null:
			projectiles_root.add_child(flak)
