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
	var is_enclosed: bool = false
	var seat_pose: String = "stand"


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
var _last_heroes_by_id: Dictionary = {}
var _damage_smoke_timer: float = 0.0


static func is_hero_enclosed(hero: HeroCharacter, vehicles_by_id: Dictionary) -> bool:
	if hero == null or hero.current_vehicle_id < 0:
		return false
	var v: VehicleBase = vehicles_by_id.get(hero.current_vehicle_id, null) as VehicleBase
	if v != null:
		if v.is_destroyed:
			return false
		var seat: SeatSlot = v.get_seat(hero.current_seat_index)
		if seat != null:
			return seat.is_enclosed
	return hero.current_seat_enclosed


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


func _add_seat(s_type: int, offset: Vector3, allow_shoot: bool, allow_skills: bool, is_enclosed: bool = false, seat_pose: String = "sit") -> void:
	var s := SeatSlot.new()
	s.seat_index = seats.size()
	s.seat_type = s_type
	s.local_offset = offset
	s.can_shoot = allow_shoot
	s.can_use_skills = allow_skills
	s.is_enclosed = is_enclosed
	s.seat_pose = seat_pose
	seats.append(s)


func _seat_world_pos(s: SeatSlot) -> Vector3:
	if is_inside_tree():
		return to_global(s.local_offset)
	return transform * s.local_offset


func _sync_hero_seat_state(hero: HeroCharacter, s: SeatSlot) -> void:
	var seat_world: Vector3 = _seat_world_pos(s)
	if hero.is_inside_tree():
		hero.global_position = seat_world
	else:
		hero.position = seat_world
	hero._prev_phys_pos = seat_world
	hero._curr_phys_pos = seat_world
	hero.current_seat_enclosed = s.is_enclosed
	hero.current_seat_pose = s.seat_pose
	hero.current_seat_can_shoot = s.can_shoot
	hero.velocity = linear_velocity


func _clear_hero_seat_state(hero: HeroCharacter) -> void:
	hero.clear_vehicle_state()


func try_enter_hero(hero: HeroCharacter) -> int:
	if is_destroyed or hero == null or hero.is_defeated or hero.current_vehicle_id >= 0:
		return -1
	# Prefer driver seat first if empty, then passenger/wing-rider/gunner
	for s in seats:
		if s.occupant_id < 0:
			s.occupant_id = hero.entity_id
			_last_heroes_by_id[hero.entity_id] = hero
			hero.current_vehicle_id = id
			hero.current_seat_index = s.seat_index
			hero.is_parachuting = false
			if hero._body_collision != null:
				hero._body_collision.disabled = true
			if hero.hero_camera != null:
				hero.hero_camera.set_vehicle_mode(true)
			_sync_hero_seat_state(hero, s)
			return s.seat_index
	return -1


func exit_hero(hero: HeroCharacter) -> void:
	if hero == null or hero.current_vehicle_id != id:
		return
	for s in seats:
		if s.occupant_id == hero.entity_id:
			s.occupant_id = -1
			break
	_clear_hero_seat_state(hero)
	var base_pos: Vector3 = global_position if is_inside_tree() else position
	var right_vec: Vector3 = global_transform.basis.x if is_inside_tree() else transform.basis.x
	var exit_pos: Vector3 = base_pos + right_vec * 3.2 + Vector3(0.0, 1.8, 0.0)
	if hero.is_inside_tree():
		hero.global_position = exit_pos
	else:
		hero.position = exit_pos
	hero._prev_phys_pos = exit_pos
	hero._curr_phys_pos = exit_pos
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
			if h != null:
				_clear_hero_seat_state(h)
			continue
		_sync_hero_seat_state(h, s)
		h.aim_yaw = h.latest_server_input.aim_yaw
		h.aim_pitch = h.latest_server_input.aim_pitch
		if s.can_shoot or s.can_use_skills:
			# Passengers & Wing-Riders freely fire weapons, use skills, and repair with Wrench
			if s.can_shoot and not h.weapons.is_empty():
				var slot: int = clampi(h.latest_server_input.selected_weapon_slot, 0, h.weapons.size() - 1)
				h.selected_weapon_slot = slot
				var w: WeaponBase = h.weapons[slot] as WeaponBase
				if w != null:
					w.step_timers(delta, h.latest_server_input)
					if w.try_consume_fire(h.latest_server_input):
						w.fire_server(h.latest_server_input, context)
			if s.can_use_skills and h.skill_manager != null and h.skill_manager.has_method("step_server"):
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
		final_dmg = maxi(1, int(roundf(float(final_dmg) * 0.55)))
	else:
		final_dmg = maxi(1, int(roundf(float(final_dmg) * 1.20)))
	hp = maxi(0, hp - final_dmg)
	NetworkManager.broadcast_game_event("hit_vfx", {
		"pos": hit_pos,
		"kind": "spark",
		"attacker_id": attacker_id,
		"damage": final_dmg,
		"headshot": mult > 1.5,
		"is_vehicle": true,
	})
	if hp == 0:
		_on_destroyed(attacker_id)


func repair_server(amount: int) -> int:
	if is_destroyed or amount <= 0:
		return 0
	var prev: int = hp
	hp = mini(max_hp, hp + amount)
	return hp - prev


func _on_destroyed(attacker_id: int) -> void:
	is_destroyed = true
	_respawn_timer = respawn_delay
	var wreck_pos: Vector3 = global_position if is_inside_tree() else position
	for s in seats:
		if s.occupant_id >= 0:
			var occ_id: int = s.occupant_id
			s.occupant_id = -1
			var h: HeroCharacter = _last_heroes_by_id.get(occ_id, null) as HeroCharacter
			if h != null and is_instance_valid(h):
				_clear_hero_seat_state(h)
				var eject_pos: Vector3 = wreck_pos + Vector3(randf_range(-1.5, 1.5), 1.8, randf_range(-1.5, 1.5))
				if h.is_inside_tree():
					h.global_position = eject_pos
				else:
					h.position = eject_pos
				h._prev_phys_pos = eject_pos
				h._curr_phys_pos = eject_pos
				h.velocity = linear_velocity * 0.35 + Vector3(randf_range(-3.0, 3.0), 8.5, randf_range(-3.0, 3.0))
				h.apply_damage_server(45, attacker_id, true, true)
	visible = false
	freeze = true
	collision_layer = 0
	NetworkManager.broadcast_game_event("explosion_vfx", {"pos": wreck_pos, "radius": 8.0, "kind": 88})
	NetworkManager.broadcast_game_event("vehicle_destroyed", {
		"vehicle_id": id,
		"vehicle_type": vehicle_type,
		"attacker_id": attacker_id,
		"pos": wreck_pos,
	})
	destroyed.emit(id)


func _respawn_vehicle() -> void:
	is_destroyed = false
	hp = max_hp
	_damage_smoke_timer = 0.0
	for s in seats:
		s.occupant_id = -1
	global_transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = true
	freeze = (vehicle_type == VehicleType.AA_GUN) or (multiplayer.multiplayer_peer != null and not multiplayer.is_server())
	collision_layer = 8
	respawned.emit(id)


func step_vehicle_server(delta: float, heroes_by_id: Dictionary, context: Dictionary) -> void:
	if not heroes_by_id.is_empty():
		_last_heroes_by_id = heroes_by_id
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

	if not is_destroyed and hp > 0 and max_hp > 0 and hp < int(float(max_hp) * 0.55):
		var critical: bool = hp < int(float(max_hp) * 0.25)
		_damage_smoke_timer -= delta
		if _damage_smoke_timer <= 0.0:
			_damage_smoke_timer = 0.18 if critical else 0.42
			var fx_parent: Node = get_parent()
			if fx_parent != null:
				var smoke_pos: Vector3 = global_position + Vector3(randf_range(-0.6, 0.6), 1.4, randf_range(-0.6, 0.6))
				StatusEffectsVFX.spawn_cartoon_burst(fx_parent, smoke_pos, "smoke", 1.2)
				if critical:
					StatusEffectsVFX.spawn_cartoon_burst(fx_parent, smoke_pos + Vector3(0.0, 0.2, 0.0), "fire", 0.9)


func push_remote_snapshot(server_tick: int, server_time_ms: float, snap: Dictionary) -> void:
	hp = int(snap.get("hp", hp))
	is_destroyed = (hp <= 0)
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


func _fire_ballistic_mg(
	driver: HeroCharacter,
	muzzle: Vector3,
	fire_dir: Vector3,
	speed: float,
	gravity_mps2: float,
	max_range: float,
	hero_dmg: int,
	obj_dmg: int,
	context: Dictionary
) -> void:
	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	if lag_comp == null or driver == null:
		return
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var res: Dictionary = lag_comp.trace_ballistic_arc(
		driver,
		muzzle,
		fire_dir * speed,
		gravity_mps2,
		max_range,
		12.0,
		driver.latest_server_input.view_interp_tick_delta,
		NetworkManager.server_tick,
		heroes_by_id,
		get_world_3d(),
		[get_rid()]
	)
	var hit_pos: Vector3 = res.get("hit_pos", muzzle + fire_dir * max_range)
	var arc: PackedVector3Array = res.get("arc_points", PackedVector3Array([muzzle, hit_pos]))
	var tid: int = int(res.get("target_hero_id", -1))
	if tid >= 0 and heroes_by_id.has(tid):
		var victim: HeroCharacter = heroes_by_id[tid] as HeroCharacter
		var vehicles_by_id: Dictionary = context.get("vehicles_by_id", {})
		if victim != null and not VehicleBase.is_hero_enclosed(victim, vehicles_by_id) and not (victim.current_vehicle_id >= 0 and victim.current_seat_enclosed):
			var is_hs: bool = bool(res.get("is_headshot", false))
			var dealt: int = victim.apply_damage_server(hero_dmg, driver.entity_id, false)
			if dealt > 0:
				NetworkManager.broadcast_game_event("hit_vfx", {
					"pos": hit_pos,
					"kind": "spark",
					"attacker_id": driver.entity_id,
					"victim_id": tid,
					"damage": dealt,
					"headshot": is_hs,
				})
	else:
		var obj: Variant = res.get("target_object", null)
		if obj != null and obj is Node and obj != self and (obj as Node).has_method("apply_damage_server"):
			(obj as Node).apply_damage_server(obj_dmg, driver.entity_id, fire_dir, hit_pos, false)
		elif bool(res.get("hit", false)):
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": hit_pos,
				"kind": "dust",
				"attacker_id": driver.entity_id,
			})

	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": driver.entity_id,
		"weapon_kind": WeaponBase.WeaponKind.MG,
		"origin": muzzle,
		"dir": fire_dir,
		"hits": [hit_pos],
		"arcs": [arc],
		"vehicle_shot": true,
	})


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
