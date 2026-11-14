class_name VehicleBase
extends RigidBody3D

## Base cooperative vehicle with SeatSlots (Driver, Passenger, Wing-Rider, Gunner),
## 2.0x directional rear armor damage, Wrench repairs, and remote interpolation.

enum VehicleType {
	JEEP,
	TANK,
	PLANE,
	BOAT,
	AA_GUN,
}

enum SeatType {
	DRIVER,
	PASSENGER,
	WING_RIDER,
	GUNNER,
}

signal destroyed(vehicle_id: int)
signal respawned(vehicle_id: int)


class SeatSlot extends RefCounted:
	var seat_index: int = 0
	var seat_type: int = SeatType.DRIVER
	var local_offset: Vector3 = Vector3.ZERO
	var occupant_id: int = -1
	var can_shoot: bool = false
	var can_use_skills: bool = false


var id: int = 1
var vehicle_type: int = VehicleType.JEEP
var team: int = -1 # -1 = neutral/capturable, 0 = Royal, 1 = National
var max_hp: int = 350
var hp: int = 350
var turret_yaw: float = 0.0
var is_destroyed: bool = false
var respawn_delay: float = 25.0
var _respawn_timer: float = 0.0
var spawn_transform: Transform3D = Transform3D.IDENTITY

var seats: Array[SeatSlot] = []
var snapshot_interpolator: SnapshotInterpolator = SnapshotInterpolator.new()
var _visual_root: Node3D
var _turret_node: Node3D
var _driver_fire_cd: float = 0.0


func _ready() -> void:
	collision_layer = 8 # Layer 4 Vehicle
	collision_mask = 1 | 2 | 8 | 64
	add_to_group("vehicles")
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 4
	spawn_transform = global_transform

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_setup_vehicle_stats_and_seats()
	_build_vehicle_mesh()

	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		freeze = true


func is_aircraft() -> bool:
	return vehicle_type == VehicleType.PLANE


func _setup_vehicle_stats_and_seats() -> void:
	pass


func _build_vehicle_mesh() -> void:
	pass


func _add_seat(s_type: int, offset: Vector3, allow_shoot: bool, allow_skills: bool) -> void:
	var s := SeatSlot.new()
	s.seat_index = seats.size()
	s.seat_type = s_type
	s.local_offset = offset
	s.can_shoot = allow_shoot
	s.can_use_skills = allow_skills
	seats.append(s)


func try_enter_hero(hero: HeroCharacter) -> int:
	if is_destroyed or hero == null or hero.is_defeated or hero.current_vehicle_id >= 0:
		return -1
	# Prefer driver seat first if empty, then passenger/wing-rider/gunner
	for s in seats:
		if s.occupant_id < 0:
			s.occupant_id = hero.entity_id
			hero.current_vehicle_id = id
			hero.current_seat_index = s.seat_index
			if hero._body_collision != null:
				hero._body_collision.disabled = true
			if hero.hero_camera != null:
				hero.hero_camera.set_vehicle_mode(true)
			return s.seat_index
	return -1


func exit_hero(hero: HeroCharacter) -> void:
	if hero == null or hero.current_vehicle_id != id:
		return
	for s in seats:
		if s.occupant_id == hero.entity_id:
			s.occupant_id = -1
			break
	hero.current_vehicle_id = -1
	hero.current_seat_index = -1
	if hero._body_collision != null:
		hero._body_collision.disabled = false
	if hero.hero_camera != null:
		hero.hero_camera.set_vehicle_mode(false)
	hero.global_position = global_position + global_transform.basis.x * 3.2 + Vector3(0.0, 1.8, 0.0)
	hero.velocity = linear_velocity * 0.4 + Vector3(0.0, 2.0, 0.0)


func get_seat(seat_idx: int) -> SeatSlot:
	if seat_idx < 0 or seat_idx >= seats.size():
		return null
	return seats[seat_idx]


func get_driver_hero(heroes_by_id: Dictionary) -> HeroCharacter:
	for s in seats:
		if (s.seat_type == SeatType.DRIVER or s.seat_type == SeatType.GUNNER) and s.occupant_id >= 0:
			return heroes_by_id.get(s.occupant_id, null)
	return null


func sync_occupants(heroes_by_id: Dictionary, delta: float, context: Dictionary) -> void:
	if is_destroyed:
		return
	for s in seats:
		if s.occupant_id < 0:
			continue
		var h: HeroCharacter = heroes_by_id.get(s.occupant_id, null)
		if h == null or h.is_defeated:
			s.occupant_id = -1
			continue
		h.global_position = to_global(s.local_offset)
		h.velocity = linear_velocity
		if s.seat_type == SeatType.PASSENGER or s.seat_type == SeatType.WING_RIDER:
			# Passengers & Wing-Riders freely fire weapons, use skills, and repair with Wrench
			if not h.weapons.is_empty():
				var slot: int = clampi(h.latest_server_input.selected_weapon_slot, 0, h.weapons.size() - 1)
				var w: WeaponBase = h.weapons[slot] as WeaponBase
				if w != null:
					w.step_timers(delta, h.latest_server_input)
					if w.try_consume_fire(h.latest_server_input):
						w.fire_server(h.latest_server_input, context)
			if h.skill_manager != null and h.skill_manager.has_method("step_server"):
				h.skill_manager.step_server(delta, h.latest_server_input, context)


## Calculates directional armor damage multiplier: rear hits deal 2.0x damage!
func compute_directional_multiplier(hit_dir_world: Vector3, hit_pos_world: Vector3) -> float:
	var rear_normal: Vector3 = global_transform.basis.z.normalized()
	var to_hit: Vector3 = (hit_pos_world - global_position)
	if to_hit.length_squared() > 0.05:
		if to_hit.normalized().dot(rear_normal) > 0.35:
			return 2.0
	if hit_dir_world.length_squared() > 0.01:
		# A shot traveling forward (-Z) into the back of the vehicle opposes +Z rear normal
		if hit_dir_world.normalized().dot(-rear_normal) > 0.45:
			return 2.0
	return 1.0


func apply_damage_server(amount: int, attacker_id: int, hit_dir: Vector3, hit_pos: Vector3, is_explosive: bool) -> void:
	if is_destroyed or amount <= 0:
		return
	var mult: float = compute_directional_multiplier(hit_dir, hit_pos) if vehicle_type == VehicleType.TANK else 1.0
	var final_dmg: int = maxi(1, int(roundf(float(amount) * mult)))
	if not is_explosive:
		final_dmg = maxi(1, int(roundf(float(final_dmg) * 0.45)))
	hp = maxi(0, hp - final_dmg)
	if hp == 0:
		_on_destroyed(attacker_id)


func repair_server(amount: int) -> int:
	if is_destroyed or amount <= 0:
		return 0
	var prev: int = hp
	hp = mini(max_hp, hp + amount)
	return hp - prev


func _on_destroyed(_attacker_id: int) -> void:
	is_destroyed = true
	_respawn_timer = respawn_delay
	visible = false
	freeze = true
	collision_layer = 0
	NetworkManager.broadcast_game_event("explosion_vfx", {"pos": global_position, "radius": 8.0, "kind": 88})
	destroyed.emit(id)


func _respawn_vehicle() -> void:
	is_destroyed = false
	hp = max_hp
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = true
	freeze = (multiplayer.multiplayer_peer != null and not multiplayer.is_server())
	collision_layer = 8
	respawned.emit(id)


func step_vehicle_server(delta: float, heroes_by_id: Dictionary, context: Dictionary) -> void:
	if is_destroyed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_vehicle()
		return
	if _driver_fire_cd > 0.0:
		_driver_fire_cd = maxf(0.0, _driver_fire_cd - delta)
	sync_occupants(heroes_by_id, delta, context)
	var driver: HeroCharacter = get_driver_hero(heroes_by_id)
	_drive_physics(driver, delta, context)


func _drive_physics(_driver: HeroCharacter, _delta: float, _context: Dictionary) -> void:
	pass


func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		var sample: SnapshotInterpolator.SnapshotSample = snapshot_interpolator.sample(NetworkManager.get_server_clock_ms())
		if sample != null:
			global_position = sample.position
			quaternion = sample.rotation
			turret_yaw = sample.turret_yaw
			if _turret_node != null:
				_turret_node.rotation.y = turret_yaw - rotation.y
	elif _turret_node != null:
		_turret_node.rotation.y = lerp_angle(_turret_node.rotation.y, turret_yaw - rotation.y, minf(1.0, 12.0 * delta))


func push_remote_snapshot(server_tick: int, server_time_ms: float, snap: Dictionary) -> void:
	hp = int(snap.get("hp", hp))
	visible = hp > 0
	snapshot_interpolator.push_snapshot(
		server_tick,
		server_time_ms,
		snap.get("pos", Vector3.ZERO),
		snap.get("rot", Quaternion.IDENTITY),
		snap.get("vel", Vector3.ZERO),
		0.0,
		0.0,
		float(snap.get("turret_yaw", 0.0)),
		0
	)


func build_snapshot_dict() -> Dictionary:
	return {
		"id": id,
		"type": vehicle_type,
		"pos": global_position,
		"rot": quaternion,
		"vel": linear_velocity,
		"turret_yaw": turret_yaw,
		"hp": hp if not is_destroyed else 0,
	}


func _add_box_part(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	mi.material_override = mat
	parent.add_child(mi)
	return mi
