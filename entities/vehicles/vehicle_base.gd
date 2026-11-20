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
	MOTORCYCLE,
	APC,
	MOUNTED_MG,
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
	var follow_turret: bool = false
	var local_yaw: float = 0.0


var id: int = 1
var vehicle_type: int = VehicleType.JEEP
var team: int = -1 # -1 = neutral/capturable, 0 = Royal, 1 = National
var max_hp: int = 350
var hp: int = 350
var _base_max_hp: int = 0
var is_armored: bool = false
var is_deployable: bool = false
var _armor_plates_root: Node3D = null
var turret_yaw: float = 0.0
var turret_pitch: float = 0.0
var is_destroyed: bool = false
var is_marked: bool = false
var marked_timer: float = 0.0
var respawn_delay: float = 25.0
var _respawn_timer: float = 0.0
var spawn_transform: Transform3D = Transform3D.IDENTITY

var seats: Array[SeatSlot] = []
var snapshot_interpolator: SnapshotInterpolator = SnapshotInterpolator.new()
var _visual_root: Node3D
var _cached_visual_meshes: Array[MeshInstance3D] = []
var _last_xray_state: int = -1
var _turret_node: Node3D
var _barrel_pivot: Node3D
var _propeller_node: Node3D
var _wheels: Array[Node3D] = []
const OVERHEAT_LOCKOUT_SEC: float = 4.0
const HEAT_COOL_DELAY_SEC: float = 0.18

var _driver_fire_cd: float = 0.0
var has_mounted_overheat: bool = false
var weapon_heat: float = 0.0
var weapon_overheated: bool = false
var overheat_cooldown_timer: float = 0.0
var heat_per_shot: float = 0.05
var heat_cool_rate: float = 0.35
var _heat_cool_delay: float = 0.0
var _last_heroes_by_id: Dictionary = {}
var _damage_smoke_timer: float = 0.0
var _roadkill_cooldowns: Dictionary = {}
var _water_submerge_timer: float = 0.0


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
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 4
	if physics_material_override == null:
		var phys_mat := PhysicsMaterial.new()
		phys_mat.friction = 0.02
		phys_mat.bounce = 0.0
		physics_material_override = phys_mat
	spawn_transform = global_transform

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_setup_vehicle_stats_and_seats()
	_base_max_hp = max_hp
	_build_vehicle_mesh()
	get_cached_visual_meshes()

	if not NetworkManager.is_server_authority():
		freeze = true


func get_cached_visual_meshes() -> Array[MeshInstance3D]:
	if _cached_visual_meshes.is_empty() and _visual_root != null:
		_collect_visual_meshes_recursive(_visual_root)
	return _cached_visual_meshes


func _collect_visual_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		_cached_visual_meshes.append(node as MeshInstance3D)
	for ch in node.get_children():
		_collect_visual_meshes_recursive(ch)


func is_aircraft() -> bool:
	return vehicle_type == VehicleType.PLANE


func is_watercraft() -> bool:
	return vehicle_type == VehicleType.BOAT


func is_ground_vehicle() -> bool:
	return not is_aircraft() and not is_watercraft() and vehicle_type != VehicleType.AA_GUN and vehicle_type != VehicleType.MOUNTED_MG


func _get_world_y() -> float:
	return global_position.y if is_inside_tree() else position.y


func is_submerged_in_water() -> bool:
	if not is_ground_vehicle():
		return false
	return _get_world_y() <= HeroCharacter.WATER_LEVEL - 0.35


func _setup_vehicle_stats_and_seats() -> void:
	pass


func _build_vehicle_mesh() -> void:
	pass


func _add_seat(s_type: int, offset: Vector3, allow_shoot: bool, allow_skills: bool, is_enclosed: bool = false, seat_pose: String = "sit", follow_turret_flag: bool = false, p_local_yaw: float = 0.0) -> void:
	var s := SeatSlot.new()
	s.seat_index = seats.size()
	s.seat_type = s_type
	s.local_offset = offset
	s.can_shoot = allow_shoot
	s.can_use_skills = allow_skills
	s.is_enclosed = is_enclosed
	s.seat_pose = seat_pose
	s.follow_turret = follow_turret_flag
	s.local_yaw = p_local_yaw
	seats.append(s)


func get_seat_local_yaw(seat_idx: int) -> float:
	var s: SeatSlot = get_seat(seat_idx)
	return s.local_yaw if s != null else 0.0


func is_seat_mounted_gunner(seat_idx: int) -> bool:
	if not has_mounted_overheat or seat_idx < 0 or seat_idx >= seats.size():
		return false
	var s: SeatSlot = seats[seat_idx]
	if s == null or s.can_shoot:
		return false
	if vehicle_type == VehicleType.PLANE:
		return s.seat_type == SeatType.DRIVER
	return s.seat_type == SeatType.GUNNER


func try_consume_mounted_heat() -> bool:
	if not has_mounted_overheat:
		return true
	if weapon_overheated:
		return false
	weapon_heat = minf(1.0, weapon_heat + heat_per_shot)
	_heat_cool_delay = HEAT_COOL_DELAY_SEC
	if weapon_heat >= 0.9999:
		weapon_heat = 1.0
		weapon_overheated = true
		overheat_cooldown_timer = OVERHEAT_LOCKOUT_SEC
	return true


func _step_mounted_heat(delta: float) -> void:
	if not has_mounted_overheat:
		return
	if weapon_overheated:
		overheat_cooldown_timer = maxf(0.0, overheat_cooldown_timer - delta)
		if overheat_cooldown_timer <= 0.0:
			weapon_overheated = false
			overheat_cooldown_timer = 0.0
			weapon_heat = 0.0
			_heat_cool_delay = 0.0
	elif weapon_heat > 0.0:
		if _heat_cool_delay > 0.0:
			_heat_cool_delay = maxf(0.0, _heat_cool_delay - delta)
		else:
			weapon_heat = maxf(0.0, weapon_heat - heat_cool_rate * delta)


func _reset_mounted_heat() -> void:
	weapon_heat = 0.0
	weapon_overheated = false
	overheat_cooldown_timer = 0.0
	_heat_cool_delay = 0.0


func get_occupant_count() -> int:
	var count: int = 0
	for s in seats:
		if s.occupant_id >= 0:
			count += 1
	return count


func _effective_turret_local_yaw() -> float:
	return turret_yaw - rotation.y


func _seat_local_offset(s: SeatSlot) -> Vector3:
	if not s.follow_turret:
		return s.local_offset
	var piv_xz: Vector3 = Vector3(_turret_node.position.x, 0.0, _turret_node.position.z) if _turret_node != null else Vector3.ZERO
	return piv_xz + (s.local_offset - piv_xz).rotated(Vector3.UP, _effective_turret_local_yaw())


func _seat_world_pos(s: SeatSlot) -> Vector3:
	var off: Vector3 = _seat_local_offset(s)
	if is_inside_tree():
		return to_global(off)
	return transform * off


## Returns the precise world seat position for an occupant hero.
func get_seat_world_pos_for_hero(hero: HeroCharacter) -> Vector3:
	if hero == null:
		return global_position if is_inside_tree() else position
	var seat: SeatSlot = get_seat(hero.current_seat_index)
	if seat != null:
		return _seat_world_pos(seat)
	return global_position if is_inside_tree() else position


func _place_hero_at(hero: HeroCharacter, world_pos: Vector3, vel: Vector3) -> void:
	if hero.is_inside_tree():
		hero.global_position = world_pos
	else:
		hero.position = world_pos
	hero._prev_phys_pos = world_pos
	hero._curr_phys_pos = world_pos
	hero.velocity = vel


func _sync_hero_seat_state(hero: HeroCharacter, s: SeatSlot) -> void:
	_place_hero_at(hero, _seat_world_pos(s), linear_velocity)
	hero.current_seat_enclosed = s.is_enclosed
	hero.current_seat_pose = s.seat_pose
	hero.current_seat_can_shoot = s.can_shoot
	if s.follow_turret:
		_sync_turret_occupant_facing(hero)
	elif hero.has_method("_sync_seated_visual_transform"):
		hero._sync_seated_visual_transform(self)


func _sync_turret_occupant_facing(hero: HeroCharacter) -> void:
	var cmd: InputCmd = hero.latest_server_input
	var use_turret_yaw: bool = (cmd == null) or (cmd.tick == 0 and is_zero_approx(cmd.aim_yaw))
	var target_yaw: float = turret_yaw if use_turret_yaw else cmd.aim_yaw
	hero.aim_yaw = target_yaw
	if hero.visual_root != null:
		hero.visual_root.global_position = hero.global_position if hero.is_inside_tree() else hero.position
		hero.visual_root.rotation.y = target_yaw


func _clear_hero_seat_state(hero: HeroCharacter, eject_pos: Variant = null, eject_vel: Variant = null) -> void:
	hero.clear_vehicle_state()
	if eject_pos is Vector3:
		var target_vel: Vector3 = eject_vel if eject_vel is Vector3 else Vector3.ZERO
		_place_hero_at(hero, eject_pos as Vector3, target_vel)


func try_enter_hero(hero: HeroCharacter) -> int:
	if is_destroyed or hero == null or hero.is_defeated or hero.hp <= 0 or hero.is_last_stand_active() or hero.current_vehicle_id >= 0:
		return -1
	# Prefer driver seat first if empty, then passenger/wing-rider/gunner
	for s in seats:
		if s.occupant_id < 0:
			s.occupant_id = hero.entity_id
			can_sleep = false
			sleeping = false
			_last_heroes_by_id[hero.entity_id] = hero
			hero.current_vehicle_id = id
			hero.current_seat_index = s.seat_index
			hero.is_parachuting = false
			hero.active_flags &= ~NetSerializer.SNAP_PARACHUTING
			if is_aircraft() and s.seat_index == 0:
				hero.aim_yaw = rotation.y
				if hero.hero_camera != null:
					hero.hero_camera.yaw = rotation.y
					hero.hero_camera.pitch = maxf(hero.hero_camera.pitch, 0.06)
			if hero._body_collision != null:
				hero._body_collision.disabled = true
			if hero.hero_camera != null:
				hero.hero_camera.set_vehicle_mode(true)
			_sync_hero_seat_state(hero, s)
			return s.seat_index
	return -1


func try_switch_seat(hero: HeroCharacter, target_seat_idx: int) -> bool:
	if is_destroyed or hero == null or hero.is_defeated or hero.current_vehicle_id != id:
		return false
	if target_seat_idx < 0 or target_seat_idx >= seats.size():
		return false
	if hero.current_seat_index == target_seat_idx:
		return true
	var target_seat: SeatSlot = seats[target_seat_idx]
	if target_seat.occupant_id >= 0:
		return false
	var prev_seat: SeatSlot = get_seat(hero.current_seat_index)
	if prev_seat != null and prev_seat.occupant_id == hero.entity_id:
		prev_seat.occupant_id = -1
	target_seat.occupant_id = hero.entity_id
	hero.current_seat_index = target_seat_idx
	if is_aircraft() and target_seat_idx == 0:
		hero.aim_yaw = rotation.y
		if hero.hero_camera != null:
			hero.hero_camera.yaw = rotation.y
			hero.hero_camera.pitch = maxf(hero.hero_camera.pitch, 0.06)
	_sync_hero_seat_state(hero, target_seat)
	hero.stats_changed.emit()
	return true


func exit_hero(hero: HeroCharacter) -> void:
	if hero == null or hero.current_vehicle_id != id:
		return
	for s in seats:
		if s.occupant_id == hero.entity_id:
			s.occupant_id = -1
			break
	var base_pos: Vector3 = global_position if is_inside_tree() else position
	var right_vec: Vector3 = global_transform.basis.x if is_inside_tree() else transform.basis.x
	var exit_pos: Vector3 = base_pos + right_vec * 3.2 + Vector3(0.0, 1.8, 0.0)
	_clear_hero_seat_state(hero, exit_pos, linear_velocity * 0.4 + Vector3(0.0, 2.0, 0.0))


func get_seat(seat_idx: int) -> SeatSlot:
	if seat_idx < 0 or seat_idx >= seats.size():
		return null
	return seats[seat_idx]


func get_driver_hero(heroes_by_id: Dictionary) -> HeroCharacter:
	var has_driver_seat: bool = false
	for s in seats:
		if s.seat_type == SeatType.DRIVER:
			has_driver_seat = true
			if s.occupant_id >= 0:
				return heroes_by_id.get(s.occupant_id, null)
	if not has_driver_seat:
		for s in seats:
			if s.seat_type == SeatType.GUNNER and s.occupant_id >= 0:
				return heroes_by_id.get(s.occupant_id, null)
	return null


func get_gunner_hero(heroes_by_id: Dictionary) -> HeroCharacter:
	for s in seats:
		if s.seat_type == SeatType.GUNNER and s.occupant_id >= 0:
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
		if not s.follow_turret:
			h.aim_yaw = h.latest_server_input.aim_yaw
		h.aim_pitch = h.latest_server_input.aim_pitch
		# Always step cooldowns & Widgets (Wrench/Bandages/Água/Antídoto) for all occupants; gate class skills by seat
		if h.skill_manager != null and h.skill_manager.has_method("step_server"):
			h.skill_manager.step_server(delta, h.latest_server_input, context, s.can_use_skills)
		if s.can_shoot and not h.weapons.is_empty():
			var slot: int = clampi(h.latest_server_input.selected_weapon_slot, 0, h.weapons.size() - 1)
			if h.should_apply_client_weapon_slot(slot, h.latest_server_input.tick):
				h.selected_weapon_slot = slot
			var w: WeaponBase = h.weapons[h.selected_weapon_slot] as WeaponBase
			if w != null:
				w.step_timers(delta, h.latest_server_input)
				if w is ProjectileWeapon and not h.is_defeated:
					(w as ProjectileWeapon).try_detonate_stickies(h.latest_server_input)
				if w.try_consume_fire(h.latest_server_input):
					w.fire_server(h.latest_server_input, context)


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


## Calculates exact Bazooka directional armor damage: 40 Front / 60 Side / 95 Rear.
func compute_bazooka_directional_damage(hit_dir_world: Vector3, hit_pos_world: Vector3) -> int:
	var fwd_normal: Vector3 = -global_transform.basis.z.normalized()
	var dir_check: Vector3 = hit_pos_world - global_position
	dir_check.y = 0.0
	if dir_check.length_squared() > 0.05:
		var d: float = dir_check.normalized().dot(fwd_normal)
		if d >= 0.45:
			return 40
		if d <= -0.45:
			return 95
		return 60
	if hit_dir_world.length_squared() > 0.01:
		var hd: Vector3 = Vector3(hit_dir_world.x, 0.0, hit_dir_world.z).normalized()
		var d2: float = hd.dot(fwd_normal)
		if d2 <= -0.45:
			return 40
		if d2 >= 0.45:
			return 95
	return 60


func apply_bazooka_damage_server(attacker_id: int, hit_dir: Vector3, hit_pos: Vector3) -> void:
	if is_destroyed:
		return
	var final_dmg: int = compute_bazooka_directional_damage(hit_dir, hit_pos)
	hp = maxi(0, hp - final_dmg)
	NetworkManager.broadcast_game_event("hit_vfx", {
		"pos": hit_pos,
		"kind": "spark",
		"attacker_id": attacker_id,
		"damage": final_dmg,
		"headshot": final_dmg >= 95,
		"is_vehicle": true,
	})
	if hp == 0:
		_on_destroyed(attacker_id)


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


func _vanish_in_water_and_schedule_respawn() -> void:
	is_destroyed = true
	_respawn_timer = respawn_delay
	_water_submerge_timer = 0.0
	_reset_mounted_heat()
	hp = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = false
	freeze = true
	collision_layer = 0
	destroyed.emit(id)


func _on_destroyed(attacker_id: int) -> void:
	is_destroyed = true
	_respawn_timer = respawn_delay
	_reset_mounted_heat()
	var wreck_pos: Vector3 = global_position if is_inside_tree() else position
	for s in seats:
		if s.occupant_id >= 0:
			var occ_id: int = s.occupant_id
			s.occupant_id = -1
			var h: HeroCharacter = _last_heroes_by_id.get(occ_id, null) as HeroCharacter
			if h != null and is_instance_valid(h):
				var eject_pos: Vector3 = wreck_pos + Vector3(randf_range(-1.5, 1.5), 1.8, randf_range(-1.5, 1.5))
				var eject_vel: Vector3 = linear_velocity * 0.35 + Vector3(randf_range(-3.0, 3.0), 8.5, randf_range(-3.0, 3.0))
				_clear_hero_seat_state(h, eject_pos, eject_vel)
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


func apply_engineer_armor() -> bool:
	if is_destroyed or is_armored:
		return false
	if _base_max_hp <= 0:
		_base_max_hp = maxi(1, max_hp)
	is_armored = true
	max_hp = _base_max_hp * 2
	hp = mini(max_hp, hp + _base_max_hp)
	attach_engineer_armor_visuals()
	return true


func attach_engineer_armor_visuals() -> void:
	is_armored = true
	if _visual_root == null:
		return
	if _armor_plates_root != null and is_instance_valid(_armor_plates_root):
		return
	_armor_plates_root = VehicleMeshBuilder.build_engineer_armor_plates(_visual_root, vehicle_type, team)
	_cached_visual_meshes.clear()
	get_cached_visual_meshes()


func _clear_engineer_armor() -> void:
	var had_armor_nodes: bool = _armor_plates_root != null
	is_armored = false
	if _base_max_hp > 0:
		max_hp = _base_max_hp
	if _armor_plates_root != null and is_instance_valid(_armor_plates_root):
		if _armor_plates_root.get_parent() != null:
			_armor_plates_root.get_parent().remove_child(_armor_plates_root)
		_armor_plates_root.queue_free()
	_armor_plates_root = null
	if had_armor_nodes:
		_cached_visual_meshes.clear()
		get_cached_visual_meshes()


func _respawn_vehicle() -> void:
	if is_deployable:
		return
	is_destroyed = false
	is_marked = false
	_clear_engineer_armor()
	marked_timer = 0.0
	_respawn_timer = 0.0
	_last_xray_state = -1
	_reset_mounted_heat()
	hp = max_hp
	_damage_smoke_timer = 0.0
	_water_submerge_timer = 0.0
	_roadkill_cooldowns.clear()
	for mi in _cached_visual_meshes:
		if is_instance_valid(mi):
			mi.material_overlay = null
	for s in seats:
		if s.occupant_id >= 0:
			var occ_h: HeroCharacter = _last_heroes_by_id.get(s.occupant_id, null) as HeroCharacter
			if occ_h != null and is_instance_valid(occ_h) and occ_h.current_vehicle_id == id:
				_clear_hero_seat_state(occ_h)
		s.occupant_id = -1
	_last_heroes_by_id = {}
	if is_inside_tree():
		global_transform = spawn_transform
	else:
		transform = spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	visible = true
	freeze = (vehicle_type == VehicleType.AA_GUN or vehicle_type == VehicleType.MOUNTED_MG) or not NetworkManager.is_server_authority()
	collision_layer = 8
	respawned.emit(id)


func apply_marked(duration: float = 12.0) -> void:
	marked_timer = maxf(marked_timer, duration)
	is_marked = marked_timer > 0.0


func clear_marked() -> void:
	marked_timer = 0.0
	is_marked = false


func step_vehicle_server(delta: float, heroes_by_id: Dictionary, context: Dictionary) -> void:
	if not heroes_by_id.is_empty():
		_last_heroes_by_id = heroes_by_id
	if marked_timer > 0.0:
		marked_timer = maxf(0.0, marked_timer - delta)
	is_marked = marked_timer > 0.0
	if is_destroyed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn_vehicle()
		return
	if is_submerged_in_water():
		_water_submerge_timer += delta
		if (_get_world_y() <= HeroCharacter.WATER_LEVEL - 0.70 or _water_submerge_timer >= 0.40) and get_occupant_count() == 0:
			_vanish_in_water_and_schedule_respawn()
			return
	else:
		_water_submerge_timer = 0.0
	if _driver_fire_cd > 0.0:
		_driver_fire_cd = maxf(0.0, _driver_fire_cd - delta)
	_step_mounted_heat(delta)
	sync_occupants(heroes_by_id, delta, context)
	var occ_count: int = get_occupant_count()
	var can_park_sleep: bool = (occ_count == 0) and (linear_velocity.length_squared() < 0.01) and (angular_velocity.length_squared() < 0.01)
	if is_watercraft():
		can_park_sleep = can_park_sleep and absf(_get_world_y() - (HeroCharacter.WATER_LEVEL - 0.34)) <= 0.12
	can_sleep = can_park_sleep
	if not can_park_sleep and sleeping:
		sleeping = false
	var driver: HeroCharacter = get_driver_hero(heroes_by_id)
	_drive_physics(driver, delta, context)
	for s in seats:
		if s.follow_turret and s.occupant_id >= 0:
			var occ: HeroCharacter = heroes_by_id.get(s.occupant_id, null)
			if occ != null and not occ.is_defeated:
				_sync_hero_seat_state(occ, s)


func _drive_physics(_driver: HeroCharacter, _delta: float, _context: Dictionary) -> void:
	pass


## Unified arcade chassis physics: aggressive lateral slip cancellation, snappy yaw turning, and responsive throttle.
func _apply_arcade_drive(
	delta: float,
	cmd: InputCmd,
	max_speed: float,
	accel: float,
	turn_rate: float,
	lateral_grip: float,
	idle_drag: float,
	reverse_mult: float = 0.65
) -> void:
	if cmd == null and can_sleep and linear_velocity.length_squared() < 0.01 and angular_velocity.length_squared() < 0.01 and absf(rotation.x) < 0.02 and absf(rotation.z) < 0.02 and not is_submerged_in_water():
		return
	var basis_ref: Basis = global_transform.basis if is_inside_tree() else transform.basis
	var forward_3d: Vector3 = -basis_ref.z
	var right_3d: Vector3 = basis_ref.x
	var flat_fwd: Vector3 = Vector3(forward_3d.x, 0.0, forward_3d.z)
	var flat_right: Vector3 = Vector3(right_3d.x, 0.0, right_3d.z)
	if flat_fwd.length_squared() > 0.001:
		flat_fwd = flat_fwd.normalized()
	else:
		flat_fwd = -Vector3.FORWARD
	if flat_right.length_squared() > 0.001:
		flat_right = flat_right.normalized()
	else:
		flat_right = Vector3.RIGHT

	var cur_vy: float = linear_velocity.y
	var fwd_speed: float = linear_velocity.dot(flat_fwd)
	var side_speed: float = linear_velocity.dot(flat_right)

	# Aggressively cancel lateral slip so vehicle tracks strictly where pointed
	side_speed = lerpf(side_speed, 0.0, minf(1.0, lateral_grip * delta))

	var throttle: float = -cmd.move_dir.y if cmd != null else 0.0
	var steer: float = -cmd.move_dir.x if cmd != null else 0.0
	var submerged: bool = is_submerged_in_water()
	if submerged:
		throttle = 0.0

	var is_tank: bool = (vehicle_type == VehicleType.TANK)
	var steer_factor: float = 1.0
	var dir_sign: float = 1.0
	if not is_tank:
		if throttle < -0.1 and fwd_speed <= 0.1:
			dir_sign = -1.0
		if absf(throttle) > 0.05 or absf(fwd_speed) > 0.4:
			steer_factor = clampf(maxf(absf(throttle) * 0.75, absf(fwd_speed) / 4.5), 0.35, 1.0)
		else:
			steer_factor = 0.0

	var target_yaw_rate: float = steer * turn_rate * steer_factor * dir_sign
	angular_velocity.y = lerpf(angular_velocity.y, target_yaw_rate, minf(1.0, 10.0 * delta))
	angular_velocity.x = lerpf(angular_velocity.x, 0.0, minf(1.0, 14.0 * delta))
	angular_velocity.z = lerpf(angular_velocity.z, 0.0, minf(1.0, 14.0 * delta))

	rotation.x = lerpf(rotation.x, 0.0, minf(1.0, 10.0 * delta))
	rotation.z = lerpf(rotation.z, 0.0, minf(1.0, 10.0 * delta))

	if submerged:
		fwd_speed = lerpf(fwd_speed, 0.0, minf(1.0, 14.0 * delta))
	elif absf(throttle) > 0.05:
		if throttle > 0.0:
			var target_fwd: float = max_speed * throttle
			if fwd_speed < target_fwd:
				fwd_speed = minf(target_fwd, fwd_speed + accel * delta)
			elif fwd_speed < 0.0:
				fwd_speed = minf(0.0, fwd_speed + accel * 1.5 * delta)
		else:
			var max_rev: float = max_speed * reverse_mult
			var target_rev: float = -max_rev * (-throttle)
			if fwd_speed > 0.5:
				fwd_speed = maxf(0.0, fwd_speed - accel * 1.4 * delta)
			elif fwd_speed > target_rev:
				fwd_speed = maxf(target_rev, fwd_speed - accel * reverse_mult * delta)
	else:
		fwd_speed = lerpf(fwd_speed, 0.0, minf(1.0, idle_drag * delta))

	linear_velocity = flat_fwd * fwd_speed + flat_right * side_speed + Vector3.UP * cur_vy


## Upward step/curb climb assist for ground vehicles (Jeep, Tank).
func _assist_curb_climb(throttle: float, lookahead_z: float, max_step: float = 0.55) -> void:
	if absf(throttle) <= 0.05 or not is_inside_tree():
		return
	# Do not apply step lift if the vehicle is already rising
	if linear_velocity.y >= 1.5:
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return

	var basis_ref: Basis = global_transform.basis
	var forward: Vector3 = -basis_ref.z
	var drive_dir: Vector3 = (forward if throttle > 0.0 else -forward)
	drive_dir.y = 0.0
	if drive_dir.length_squared() < 0.001:
		return
	drive_dir = drive_dir.normalized()

	var ray_dist: float = lookahead_z + 0.45
	var low_start: Vector3 = global_position + Vector3(0.0, 0.18, 0.0)
	var low_end: Vector3 = low_start + drive_dir * ray_dist

	var low_query := PhysicsRayQueryParameters3D.create(low_start, low_end, 1 | 64, [get_rid()])
	var low_hit: Dictionary = space.intersect_ray(low_query)
	if low_hit.is_empty():
		return

	var low_norm: Vector3 = low_hit.get("normal", Vector3.UP)
	# Require a steep step face; gentle driveable ramps/slopes (abs(norm.y) >= 0.45) do not need assist
	if absf(low_norm.y) >= 0.45:
		return

	var hit_pos: Vector3 = low_hit.get("position", Vector3.ZERO)
	var dist_to_hit: float = (hit_pos - low_start).length()
	if dist_to_hit > lookahead_z + 0.15:
		return

	var up_start: Vector3 = global_position + Vector3(0.0, 0.65, 0.0)
	var up_end: Vector3 = up_start + drive_dir * (dist_to_hit + 0.35)
	var up_query := PhysicsRayQueryParameters3D.create(up_start, up_end, 1 | 64, [get_rid()])
	var up_hit: Dictionary = space.intersect_ray(up_query)
	if not up_hit.is_empty():
		return

	# Downward probe from ahead to find exact step top surface
	var top_probe_start: Vector3 = hit_pos + drive_dir * 0.30 + Vector3(0.0, max_step + 0.20, 0.0)
	var top_probe_end: Vector3 = hit_pos + drive_dir * 0.30 - Vector3(0.0, 0.20, 0.0)
	var top_query := PhysicsRayQueryParameters3D.create(top_probe_start, top_probe_end, 1 | 64, [get_rid()])
	var top_hit: Dictionary = space.intersect_ray(top_query)
	if top_hit.is_empty() or top_hit.get("normal", Vector3.ZERO).y < 0.60:
		return

	var step_top_y: float = float(top_hit.get("position", Vector3.ZERO).y)
	var step_h: float = step_top_y - global_position.y

	# Ignore gentle sidewalks (< 0.16m) where wheel spheres already roll up cleanly; boost only taller curbs
	if step_h < 0.16 or step_h > max_step or global_position.y >= step_top_y + 0.04:
		return

	# Bounded step lift proportional to step height
	var target_vy: float = minf(2.2, sqrt(2.0 * 9.8 * step_h) + 0.35)
	linear_velocity.y = maxf(linear_velocity.y, target_vy)
	linear_velocity += drive_dir * 0.8


## Shared high-speed roadkill logic for ground, water, and skimming vehicles.
func _process_roadkill(driver: HeroCharacter, context: Dictionary, half_extents: Vector2, min_speed: float = 5.5) -> void:
	if driver == null or is_destroyed:
		return
	var spd: float = linear_velocity.length()
	var horiz_spd: float = Vector2(linear_velocity.x, linear_velocity.z).length()
	var eff_spd: float = maxf(spd, horiz_spd)
	if eff_spd < min_speed:
		return

	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	if heroes_by_id.is_empty():
		return

	var now_sec: float = float(Time.get_ticks_msec()) * 0.001
	var inv_xform: Transform3D = global_transform.affine_inverse() if is_inside_tree() else transform.affine_inverse()

	for hid in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[hid] as HeroCharacter
		if h == null or not is_instance_valid(h):
			continue
		if h.is_defeated:
			continue
		if h.current_vehicle_id >= 0:
			continue
		if h.team == driver.team:
			continue

		if now_sec < float(_roadkill_cooldowns.get(h.entity_id, 0.0)):
			continue

		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var lp: Vector3 = inv_xform * h_pos

		var in_x: bool = absf(lp.x) <= half_extents.x + 0.65
		var in_y: bool = lp.y >= -0.9 and lp.y <= 2.4
		var sweep_ahead: float = maxf(0.85, eff_spd * 0.035 + 0.3)
		var in_z: bool = absf(lp.z) <= half_extents.y + sweep_ahead

		if in_x and in_y and in_z:
			_roadkill_cooldowns[h.entity_id] = now_sec + 0.45
			var dmg: int = maxi(int(float(h.max_hp) * 1.25), int(eff_spd * 15.0))
			h.apply_damage_server(dmg, driver.entity_id, true)

			var hit_dir: Vector3 = (h_pos - global_position).normalized()
			if hit_dir.length_squared() < 0.01:
				hit_dir = -global_transform.basis.z
			var fling_dir: Vector3 = (hit_dir + linear_velocity.normalized() * 1.2 + Vector3.UP * 0.85).normalized()
			var fling_speed: float = maxf(14.0, eff_spd * 1.1)
			h.apply_knockback(fling_dir * fling_speed)

			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": h_pos + Vector3(0.0, 0.9, 0.0),
				"kind": "blood",
				"attacker_id": driver.entity_id,
				"victim_id": h.entity_id,
				"damage": dmg,
				"headshot": false,
			})


func _enforce_remote_freeze() -> bool:
	if not NetworkManager.is_server_authority():
		if not freeze:
			freeze = true
			linear_velocity = Vector3.ZERO
			angular_velocity = Vector3.ZERO
		return true
	return false


func _physics_process(_delta: float) -> void:
	_enforce_remote_freeze()


func _process(delta: float) -> void:
	var eff_vel: Vector3 = linear_velocity
	var has_turret_seat: bool = false
	for s in seats:
		if s.follow_turret:
			has_turret_seat = true
			break
	if not NetworkManager.is_server_authority():
		if has_mounted_overheat and weapon_overheated and overheat_cooldown_timer > 0.0:
			overheat_cooldown_timer = maxf(0.0, overheat_cooldown_timer - delta)
		var sample: SnapshotInterpolator.SnapshotSample = snapshot_interpolator.sample(NetworkManager.get_server_clock_ms())
		if sample != null:
			global_position = sample.position
			quaternion = sample.rotation
			eff_vel = sample.velocity
			turret_yaw = sample.turret_yaw
			if _turret_node != null:
				_turret_node.rotation.y = _effective_turret_local_yaw()
	elif _turret_node != null:
		if has_turret_seat:
			_turret_node.rotation.y = _effective_turret_local_yaw()
		else:
			_turret_node.rotation.y = lerp_angle(_turret_node.rotation.y, _effective_turret_local_yaw(), minf(1.0, 12.0 * delta))

	if has_turret_seat:
		for s in seats:
			if s.follow_turret and s.occupant_id >= 0:
				var th: HeroCharacter = _last_heroes_by_id.get(s.occupant_id, null) as HeroCharacter
				if th != null and is_instance_valid(th) and not th.is_defeated:
					_sync_hero_seat_state(th, s)

	if _barrel_pivot != null:
		var target_pitch: float = clampf(turret_pitch, -0.35, 0.95)
		_barrel_pivot.rotation.x = lerpf(_barrel_pivot.rotation.x, target_pitch, minf(1.0, 14.0 * delta))

	if not _wheels.is_empty():
		var basis_ref: Basis = global_transform.basis if is_inside_tree() else transform.basis
		var fwd_speed: float = eff_vel.dot(-basis_ref.z)
		if absf(fwd_speed) > 0.05:
			for w in _wheels:
				if is_instance_valid(w):
					var r: float = maxf(0.12, float(w.get_meta("wheel_radius", 0.45)))
					w.rotation.x -= (fwd_speed / r) * delta

	if _propeller_node != null and not is_destroyed:
		var has_pilot: bool = not seats.is_empty() and seats[0].occupant_id >= 0
		var prop_rate: float = 36.0 if (has_pilot or eff_vel.length() > 3.0) else 2.2
		_propeller_node.rotation.z += prop_rate * delta

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
	var was_destroyed: bool = is_destroyed
	hp = int(snap.get("hp", hp))
	is_marked = bool(snap.get("marked", false))
	is_destroyed = (hp <= 0)
	if was_destroyed and not is_destroyed:
		_clear_engineer_armor()
		_reset_mounted_heat()
	var was_overheated: bool = weapon_overheated
	weapon_heat = clampf(float(snap.get("heat", weapon_heat)), 0.0, 1.0)
	weapon_overheated = bool(snap.get("overheated", false))
	if weapon_overheated:
		if not was_overheated:
			overheat_cooldown_timer = float(snap.get("overheat_cd", OVERHEAT_LOCKOUT_SEC))
	else:
		overheat_cooldown_timer = 0.0
	visible = hp > 0
	collision_layer = 8 if not is_destroyed else 0
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
		"marked": is_marked,
		"pos": global_position,
		"rot": quaternion,
		"vel": linear_velocity,
		"turret_yaw": turret_yaw,
		"hp": hp if not is_destroyed else 0,
		"heat": weapon_heat,
		"overheated": weapon_overheated,
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


func _apply_built_visuals(built: Dictionary) -> void:
	_turret_node = built.get("turret", null) as Node3D
	_barrel_pivot = built.get("barrel", null) as Node3D
	_propeller_node = built.get("propeller", null) as Node3D
	_wheels.clear()
	var built_wheels: Array = built.get("wheels", [])
	for w in built_wheels:
		if w is Node3D:
			_wheels.append(w as Node3D)
