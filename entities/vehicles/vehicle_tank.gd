class_name VehicleTank
extends VehicleBase

## Heavy Armor Tank: 360-deg turret, parabolic cannon with splash & projectile drop,
## 2.0x rear armor damage, and external rear passenger/repair seat.
const MAX_SPEED: float = 12.5
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
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 2.0, 5.6)
	col.shape = box
	col.position = Vector3(0.0, 1.15, 0.0)
	add_child(col)

	var hull_col: Color = Color(0.24, 0.36, 0.22) if team == 0 else Color(0.26, 0.26, 0.28)
	var accent_col: Color = Color(0.88, 0.74, 0.22) if team == 0 else Color(0.75, 0.14, 0.14)
	_add_box_part(_visual_root, Vector3(3.3, 1.1, 5.4), Vector3(0.0, 0.95, 0.0), hull_col)
	# Treads
	_add_box_part(_visual_root, Vector3(0.65, 0.95, 5.6), Vector3(-1.6, 0.55, 0.0), Color(0.14, 0.14, 0.14))
	_add_box_part(_visual_root, Vector3(0.65, 0.95, 5.6), Vector3(1.6, 0.55, 0.0), Color(0.14, 0.14, 0.14))

	# 360-degree Turret
	_turret_node = Node3D.new()
	_turret_node.name = "Turret"
	_turret_node.position = Vector3(0.0, 1.85, -0.2)
	_visual_root.add_child(_turret_node)
	_add_box_part(_turret_node, Vector3(2.1, 0.85, 2.4), Vector3(0.0, 0.1, 0.0), hull_col.lightened(0.08))
	_add_box_part(_turret_node, Vector3(0.32, 0.32, 3.2), Vector3(0.0, 0.15, -2.2), accent_col)


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	var forward: Vector3 = -global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	if driver != null:
		var cmd: InputCmd = driver.latest_server_input
		var throttle: float = -cmd.move_dir.y
		var turn: float = -cmd.move_dir.x
		var cur_fwd_speed: float = linear_velocity.dot(flat_fwd)
		if absf(throttle) > 0.05 and absf(cur_fwd_speed) < MAX_SPEED:
			apply_central_force(flat_fwd * throttle * 20.0 * mass)
		if absf(turn) > 0.05:
			angular_velocity.y = lerpf(angular_velocity.y, turn * 1.9, 5.0 * delta)
		turret_yaw = cmd.aim_yaw

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
				fire_dir * SHELL_SPEED + Vector3(0.0, 1.2, 0.0),
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
	else:
		linear_velocity.x = lerpf(linear_velocity.x, 0.0, 4.0 * delta)
		linear_velocity.z = lerpf(linear_velocity.z, 0.0, 4.0 * delta)

	rotation.x = lerpf(rotation.x, 0.0, 8.0 * delta)
	rotation.z = lerpf(rotation.z, 0.0, 8.0 * delta)
