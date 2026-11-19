class_name VehiclePlane
extends VehicleBase

## Arcade Fighter Plane: 3rd-person mouse/keyboard flight, dual front MGs,
## and 2 Wing-Riding seats (left & right wings) where allies shoot or Wrench-repair!
const CRUISE_SPEED: float = 34.0
const MAX_FLIGHT_SPEED: float = 52.0
const TAKEOFF_SPEED: float = 16.0
const GROUND_ACCEL: float = 30.0
const AIR_ACCEL: float = 11.0
const COAST_DRAG: float = 6.5
const BRAKE_DECEL: float = 20.0
const UNMANNED_DRAG: float = 1.6
const YAW_RATE: float = 2.6
const CRASH_MIN_IMPACT_SPEED: float = 12.0
const CRASH_STEEP_FALL_VY: float = -8.5
const CRASH_RADIUS: float = 13.0
const CRASH_HERO_DAMAGE: int = 120
const CRASH_VEHICLE_DAMAGE: int = 140
const MG_FIRE_INTERVAL: float = 0.09

var _airspeed: float = 0.0
var _was_airborne: bool = false
var _last_pilot_id: int = -1
var _last_pilot_team: int = -1
var _prev_vel: Vector3 = Vector3.ZERO
var _crash_armed_time: float = 0.0


func _setup_vehicle_stats_and_seats() -> void:
	vehicle_type = VehicleType.PLANE
	max_hp = 340
	hp = 340
	mass = 1400.0
	gravity_scale = 1.0
	_add_seat(SeatType.DRIVER, Vector3(0.0, 0.92, -0.15), false, false, false, "sit")
	# Wing-Riding slots on Left & Right wings!
	_add_seat(SeatType.WING_RIDER, Vector3(-3.3, 1.05, 0.15), true, true, false, "stand")
	_add_seat(SeatType.WING_RIDER, Vector3(3.3, 1.05, 0.15), true, true, false, "stand")


func _build_vehicle_mesh() -> void:
	# Slender lower fuselage collider with elevated belly clearance so nose-up takeoff pitch never snags the tail
	var col_fuse := CollisionShape3D.new()
	var box_fuse := BoxShape3D.new()
	box_fuse.size = Vector3(1.05, 0.58, 5.4)
	col_fuse.shape = box_fuse
	col_fuse.position = Vector3(0.0, 0.72, 0.0)
	add_child(col_fuse)

	# 3-point tricycle landing gear spheres for smooth low-drag runway roll & rotation
	for gear_pos in [Vector3(0.0, 0.28, -1.65), Vector3(-0.85, 0.28, 0.35), Vector3(0.85, 0.28, 0.35)]:
		var col_gear := CollisionShape3D.new()
		var sph_gear := SphereShape3D.new()
		sph_gear.radius = 0.28
		col_gear.shape = sph_gear
		col_gear.position = gear_pos
		add_child(col_gear)

	# Thin wings collider
	var col_wings := CollisionShape3D.new()
	var box_wings := BoxShape3D.new()
	box_wings.size = Vector3(8.5, 0.34, 2.0)
	col_wings.shape = box_wings
	col_wings.position = Vector3(0.0, 0.86, 0.0)
	add_child(col_wings)

	_apply_built_visuals(VehicleMeshBuilder.build_plane_visuals(_visual_root, team))


func _drive_physics(driver: HeroCharacter, delta: float, context: Dictionary) -> void:
	if is_destroyed:
		return
	_crash_armed_time += delta

	var parked_unmanned: bool = (
		driver == null
		and not _was_airborne
		and _airspeed <= 0.05
		and linear_velocity.length_squared() < 0.01
		and angular_velocity.length_squared() < 0.01
		and absf(rotation.x) < 0.02
		and absf(rotation.z) < 0.02
	)
	if parked_unmanned:
		gravity_scale = 1.0
		_airspeed = 0.0
		_prev_vel = linear_velocity
		if _crash_armed_time >= 0.25 and global_position.y <= HeroCharacter.WATER_LEVEL - 0.15:
			_detonate_plane_crash(context)
		return

	var ground_dist: float = _probe_ground_distance(6.5)
	if _check_crash_impact(driver, context, ground_dist):
		return

	var basis_ref: Basis = global_transform.basis if is_inside_tree() else transform.basis
	var nose_3d: Vector3 = -basis_ref.z.normalized()
	var fwd: Vector3 = Vector3(nose_3d.x, 0.0, nose_3d.z)
	if fwd.length_squared() > 0.0001:
		fwd = fwd.normalized()
	else:
		fwd = Vector3.FORWARD

	var grounded_close: bool = (ground_dist >= -0.25 and ground_dist <= 6.2)

	if driver != null:
		_last_pilot_id = driver.entity_id
		_last_pilot_team = driver.team

		var cmd: InputCmd = driver.latest_server_input
		var throttle: float = -cmd.move_dir.y if cmd != null else 0.0

		if throttle > 0.1:
			if _airspeed < CRUISE_SPEED:
				_airspeed = minf(CRUISE_SPEED, _airspeed + GROUND_ACCEL * delta)
			else:
				_airspeed = minf(MAX_FLIGHT_SPEED, _airspeed + AIR_ACCEL * delta)
		elif throttle < -0.1:
			_airspeed = maxf(0.0, _airspeed - BRAKE_DECEL * delta)
		else:
			_airspeed = maxf(0.0, _airspeed - COAST_DRAG * delta)

		var can_fly: bool = _airspeed >= TAKEOFF_SPEED
		var target_yaw: float = cmd.aim_yaw if cmd != null else rotation.y
		var yaw_diff: float = wrapf(target_yaw - rotation.y, -PI, PI)

		if not can_fly:
			gravity_scale = 1.0
			if _airspeed >= 0.4 or absf(throttle) > 0.1:
				var ground_steer_rate: float = YAW_RATE * clampf(_airspeed / 10.0, 0.25, 1.0)
				rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, ground_steer_rate * delta))
			rotation.x = lerpf(rotation.x, 0.0, minf(1.0, 4.0 * delta))
			rotation.z = lerpf(rotation.z, 0.0, minf(1.0, 4.2 * delta))

			if _airspeed < 0.05 and absf(throttle) <= 0.1:
				linear_velocity.x = 0.0
				linear_velocity.z = 0.0
			else:
				linear_velocity.x = fwd.x * _airspeed
				linear_velocity.z = fwd.z * _airspeed
		else:
			gravity_scale = 0.0
			var lift_factor: float = clampf((_airspeed - TAKEOFF_SPEED) / 12.0, 0.50, 1.0)
			var jump_held: bool = cmd != null and cmd.has_button(InputCmd.BTN_JUMP)
			var crouch_held: bool = cmd != null and cmd.has_button(InputCmd.BTN_CROUCH)
			var aim_p: float = cmd.aim_pitch if cmd != null else 0.0
			var move_x: float = cmd.move_dir.x if cmd != null else 0.0

			var target_vspeed: float
			var target_pitch: float
			if jump_held:
				target_vspeed = 14.5 * lift_factor
				target_pitch = clampf(aim_p + 0.36, -0.75, 0.75)
			elif crouch_held:
				target_vspeed = -13.5 * maxf(0.5, lift_factor)
				target_pitch = clampf(aim_p - 0.38, -0.75, 0.75)
			elif throttle > 0.1 and grounded_close and aim_p >= -0.08:
				target_vspeed = 8.4 * lift_factor
				target_pitch = clampf(maxf(aim_p, 0.22), -0.75, 0.75)
			else:
				target_vspeed = clampf(sin(aim_p) * _airspeed * 0.48, -11.0, 11.0)
				target_pitch = clampf(aim_p, -0.75, 0.75)

			var bank_roll: float = clampf(-yaw_diff * 1.4 - move_x * 0.7, -0.85, 0.85)
			rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, YAW_RATE * delta))
			rotation.x = lerpf(rotation.x, target_pitch, minf(1.0, 3.8 * delta))
			rotation.z = lerpf(rotation.z, bank_roll, minf(1.0, 4.2 * delta))

			linear_velocity.x = fwd.x * _airspeed
			linear_velocity.z = fwd.z * _airspeed
			linear_velocity.y = lerpf(linear_velocity.y, target_vspeed, minf(1.0, 12.0 * delta))

		angular_velocity = Vector3.ZERO

		if can_fly and (ground_dist < 0.0 or ground_dist >= 0.85):
			_was_airborne = true
		elif ground_dist >= -0.25 and ground_dist <= 0.55 and _airspeed < 4.0 and absf(linear_velocity.y) < 1.5:
			_was_airborne = false

		# Roadkill check when skimming near ground
		if grounded_close or global_position.y < 4.5:
			_process_roadkill(driver, context, Vector2(1.4, 2.8), 12.0)

		# Dual front MGs
		if cmd != null and cmd.has_button(InputCmd.BTN_FIRE) and _driver_fire_cd <= 0.0:
			_driver_fire_cd = MG_FIRE_INTERVAL
			_fire_front_mgs(driver, nose_3d, context)
	else:
		gravity_scale = 1.0
		if _airspeed > 4.0 or _was_airborne:
			_airspeed = maxf(0.0, _airspeed - UNMANNED_DRAG * delta)
			linear_velocity.x = fwd.x * _airspeed
			linear_velocity.z = fwd.z * _airspeed
			if ground_dist < 0.0 or ground_dist > 1.35:
				rotation.x = lerpf(rotation.x, -0.58, minf(1.0, 2.2 * delta))
			else:
				rotation.x = lerpf(rotation.x, 0.0, minf(1.0, 4.0 * delta))
			rotation.z = lerpf(rotation.z, 0.0, minf(1.0, 2.5 * delta))
		else:
			_airspeed = maxf(0.0, _airspeed - BRAKE_DECEL * delta)
			linear_velocity.x = lerpf(linear_velocity.x, 0.0, minf(1.0, 8.0 * delta))
			linear_velocity.z = lerpf(linear_velocity.z, 0.0, minf(1.0, 8.0 * delta))
			rotation.x = lerpf(rotation.x, 0.0, minf(1.0, 4.0 * delta))
			rotation.z = lerpf(rotation.z, 0.0, minf(1.0, 4.0 * delta))
		angular_velocity = Vector3.ZERO

	_prev_vel = linear_velocity


func _probe_ground_distance(max_dist: float) -> float:
	if not is_inside_tree():
		return -1.0
	var world: World3D = get_world_3d()
	if world == null:
		return -1.0
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	if space == null:
		return -1.0
	var start: Vector3 = global_position + Vector3(0.0, 0.35, 0.0)
	var end: Vector3 = global_position - Vector3(0.0, max_dist, 0.0)
	var q := PhysicsRayQueryParameters3D.create(start, end, 1 | 64, [get_rid()])
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return -1.0
	var hit_pos: Vector3 = hit.get("position", global_position)
	return global_position.y - hit_pos.y


func _check_crash_impact(driver: HeroCharacter, context: Dictionary, ground_dist: float) -> bool:
	if is_destroyed or _crash_armed_time < 0.25 or not is_inside_tree():
		return false

	var pre_spd: float = maxf(_prev_vel.length(), _airspeed)
	var d_state: PhysicsDirectBodyState3D = PhysicsServer3D.body_get_direct_state(get_rid())
	var has_non_hero_contact: bool = false
	var has_ground_contact: bool = (ground_dist >= -0.25 and ground_dist <= 0.65)

	if d_state != null:
		var count: int = d_state.get_contact_count()
		for i in range(count):
			var col_obj: Object = d_state.get_contact_collider_object(i)
			if col_obj is HeroCharacter:
				continue
			has_non_hero_contact = true
			var n: Vector3 = d_state.get_contact_local_normal(i)
			var horiz_n: float = Vector2(n.x, n.z).length()
			if horiz_n > 0.55 and pre_spd >= CRASH_MIN_IMPACT_SPEED:
				_detonate_plane_crash(context)
				return true
			if absf(n.y) >= 0.55:
				has_ground_contact = true
				if _prev_vel.y <= CRASH_STEEP_FALL_VY:
					_detonate_plane_crash(context)
					return true
				if driver == null and _was_airborne and pre_spd >= 10.0:
					_detonate_plane_crash(context)
					return true
				if rotation.x <= -0.35 and pre_spd >= CRASH_MIN_IMPACT_SPEED:
					_detonate_plane_crash(context)
					return true

	if has_non_hero_contact:
		var vel_delta: float = (_prev_vel - linear_velocity).length()
		if vel_delta >= 13.0 and pre_spd >= 14.0:
			_detonate_plane_crash(context)
			return true

	if global_position.y <= HeroCharacter.WATER_LEVEL - 0.15 or (
		global_position.y <= HeroCharacter.WATER_LEVEL + 0.35
		and not has_ground_contact
		and (pre_spd >= CRASH_MIN_IMPACT_SPEED or _was_airborne or _prev_vel.y <= -6.5)
	):
		_detonate_plane_crash(context)
		return true

	return false


func _detonate_plane_crash(context: Dictionary) -> void:
	if is_destroyed:
		return
	var crash_pos: Vector3 = global_position if is_inside_tree() else position
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var xp_cb: Callable = context.get("on_damage_dealt", Callable())
	var attacker: HeroCharacter = heroes_by_id.get(_last_pilot_id, null) as HeroCharacter if _last_pilot_id >= 0 else null

	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated:
			continue
		# Skip seat occupants of this plane: _on_destroyed ejects & damages them without double-hit
		if h.current_vehicle_id == id:
			continue
		# Zero friendly fire when a pilot/team is attributed
		if _last_pilot_team >= 0 and h.team == _last_pilot_team and h.entity_id != _last_pilot_id:
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var dist: float = h_pos.distance_to(crash_pos)
		if dist > CRASH_RADIUS:
			continue

		var falloff: float = clampf(1.0 - (dist / CRASH_RADIUS) * 0.625, 0.375, 1.0)
		var kb_vec: Vector3 = h_pos - crash_pos + Vector3(0.0, 1.1, 0.0)
		if kb_vec.length_squared() < 0.001:
			kb_vec = Vector3.UP
		var kb_dir: Vector3 = kb_vec.normalized()

		if _last_pilot_id >= 0 and h.entity_id == _last_pilot_id:
			# Zero self-damage if pilot bailed out nearby; apply radial knockback only
			h.apply_knockback(kb_dir * (22.0 * falloff))
			continue

		var dmg: int = maxi(1, int(roundf(float(CRASH_HERO_DAMAGE) * falloff)))
		var dealt: int = h.apply_damage_server(dmg, _last_pilot_id, true)
		h.apply_knockback(kb_dir * (28.0 * falloff))
		if dealt > 0:
			if xp_cb.is_valid() and attacker != null:
				xp_cb.call(attacker, h, dealt)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": h_pos + Vector3(0.0, 1.85, 0.0),
				"kind": "spark",
				"attacker_id": _last_pilot_id,
				"victim_id": h.entity_id,
				"damage": dmg,
				"headshot": dist <= 4.5,
			})

	if is_inside_tree():
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v == self or not (v is Node3D) or not v.has_method("apply_damage_server"):
				continue
			if v is VehicleBase and (v as VehicleBase).is_destroyed:
				continue
			if _last_pilot_team >= 0 and v is VehicleBase and (v as VehicleBase).team == _last_pilot_team:
				continue
			var v_pos: Vector3 = (v as Node3D).global_position
			var vdist: float = v_pos.distance_to(crash_pos)
			if vdist <= CRASH_RADIUS + 2.0:
				var vfalloff: float = clampf(1.0 - (vdist / (CRASH_RADIUS + 2.0)) * 0.65, 0.35, 1.0)
				var vdmg: int = maxi(10, int(roundf(float(CRASH_VEHICLE_DAMAGE) * vfalloff)))
				var hit_dir: Vector3 = (v_pos - crash_pos).normalized()
				if hit_dir.length_squared() < 0.001:
					hit_dir = Vector3.UP
				v.apply_damage_server(vdmg, _last_pilot_id, hit_dir, crash_pos, true)

		for d in get_tree().get_nodes_in_group("destructible"):
			if d == self or not (d is Node3D) or not d.has_method("apply_damage_server"):
				continue
			var d_pos: Vector3 = (d as Node3D).global_position
			var ddist: float = d_pos.distance_to(crash_pos)
			if ddist <= CRASH_RADIUS:
				var dfalloff: float = clampf(1.0 - (ddist / CRASH_RADIUS) * 0.625, 0.375, 1.0)
				var ddmg: int = maxi(10, int(roundf(float(CRASH_HERO_DAMAGE) * dfalloff)))
				d.apply_damage_server(ddmg, _last_pilot_id, Vector3.UP, crash_pos, true)

	NetworkManager.broadcast_game_event("explosion_vfx", {
		"pos": crash_pos,
		"radius": CRASH_RADIUS,
		"attacker_id": _last_pilot_id,
	})
	hp = 0
	_on_destroyed(_last_pilot_id)


func _respawn_vehicle() -> void:
	super._respawn_vehicle()
	_airspeed = 0.0
	_was_airborne = false
	_last_pilot_id = -1
	_last_pilot_team = -1
	_prev_vel = Vector3.ZERO
	_crash_armed_time = 0.0
	gravity_scale = 1.0


func _fire_front_mgs(driver: HeroCharacter, forward: Vector3, context: Dictionary) -> void:
	var origin: Vector3 = global_position + forward * 3.6
	_fire_ballistic_mg(driver, origin, forward, 165.0, 12.0, 240.0, 18, 24, context)
