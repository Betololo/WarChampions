class_name VehicleShieldedMG
extends VehicleBase

## Field Engineer deployable Shielded MG Turret (320 HP, stationary, 360-degree rotating gunner,
## heavy ballistic MG, and sculpted frontal steel gun shield blocking frontal incoming bullets).

const MG_FIRE_INTERVAL: float = 0.09
const MG_HERO_DMG: int = 18
const MG_OBJ_DMG: int = 26

var owner_id: int = -1
var owner_team: int = 0
var on_turret_destroyed: Callable = Callable()
var _shield_body: StaticBody3D = null


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.MOUNTED_MG
	max_hp = 320
	hp = 320
	freeze = true
	respawn_delay = 999999.0
	_add_seat(SeatType.GUNNER, Vector3(0.0, 0.22, 0.56), false, false, false, "stand", true)


func _build_vehicle_mesh() -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.95
	cyl.height = 0.98
	col.shape = cyl
	col.position = Vector3(0.0, 0.49, 0.0)
	add_child(col)

	_apply_built_visuals(VehicleMeshBuilder.build_mounted_mg_visuals(_visual_root, team))

	if _turret_node != null:
		_shield_body = StaticBody3D.new()
		_shield_body.name = "GunShieldBody"
		_shield_body.collision_layer = 1 # World layer blocks incoming hitscan/ballistic bullets
		_shield_body.collision_mask = 0
		_shield_body.position = Vector3(0.0, 0.48, -0.45)
		var shield_col := CollisionShape3D.new()
		var shield_box := BoxShape3D.new()
		shield_box.size = Vector3(1.36, 0.96, 0.14)
		shield_col.shape = shield_box
		_shield_body.add_child(shield_col)
		_turret_node.add_child(_shield_body)


func get_shield_rid() -> RID:
	if _shield_body != null and is_instance_valid(_shield_body):
		return _shield_body.get_rid()
	return RID()


func is_frontal_shield_blocking_dir(attack_dir_from_target: Vector3) -> bool:
	if is_destroyed:
		return false
	var flat_atk := Vector3(attack_dir_from_target.x, 0.0, attack_dir_from_target.z)
	if flat_atk.length_squared() < 0.0001:
		return false
	var turret_fwd := -Basis(Vector3.UP, turret_yaw).z
	turret_fwd.y = 0.0
	if turret_fwd.length_squared() < 0.0001:
		turret_fwd = Vector3.FORWARD
	return flat_atk.normalized().dot(turret_fwd.normalized()) >= 0.35


func _drive_physics(driver: HeroCharacter, _delta: float, context: Dictionary) -> void:
	if driver == null:
		return
	var cmd: InputCmd = driver.latest_server_input
	if cmd == null:
		return
	turret_yaw = cmd.aim_yaw
	turret_pitch = clampf(cmd.aim_pitch, -0.45, 0.65)
	if _turret_node != null:
		_turret_node.rotation.y = _effective_turret_local_yaw()
	if cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
		_driver_fire_cd = MG_FIRE_INTERVAL
		var aim_b := Basis.from_euler(Vector3(turret_pitch, turret_yaw, 0.0))
		var fire_dir: Vector3 = (-aim_b.z).normalized()
		var muzzle_base: Vector3 = _barrel_pivot.global_position if (_barrel_pivot != null and is_inside_tree()) else ((global_transform if is_inside_tree() else transform) * Vector3(0.0, 1.50, -0.30))
		var muzzle: Vector3 = muzzle_base + fire_dir * 1.45
		_fire_ballistic_mg(driver, muzzle, fire_dir, 180.0, 9.8 * 0.18, 220.0, MG_HERO_DMG, MG_OBJ_DMG, context)


func _on_destroyed(attacker_id: int) -> void:
	super._on_destroyed(attacker_id)
	if _shield_body != null and is_instance_valid(_shield_body):
		_shield_body.collision_layer = 0
	if on_turret_destroyed.is_valid():
		on_turret_destroyed.call()
	queue_free()


func _respawn_vehicle() -> void:
	# Deployable Engineer turrets do not auto-respawn once destroyed.
	pass
