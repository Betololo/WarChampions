class_name LagCompensator
extends Node

## Server-side 64-frame hitbox history (~1.06s @ 60Hz) for Hitscan Rewind (max 400ms / 24 ticks).
const HISTORY_FRAMES: int = 64
const MAX_REWIND_TICKS: int = 24


class HeroHitboxSnapshot extends RefCounted:
	var entity_id: int = 0
	var team: int = 0
	var body_bottom: Vector3 = Vector3.ZERO
	var body_top: Vector3 = Vector3.ZERO
	var body_radius: float = 0.42
	var head_center: Vector3 = Vector3.ZERO
	var head_radius: float = 0.25


class FrameRecord extends RefCounted:
	var server_tick: int = -1
	var entries: Dictionary = {} # entity_id -> HeroHitboxSnapshot


var _history: Array[FrameRecord] = []


func _init() -> void:
	_history.resize(HISTORY_FRAMES)
	for i in range(HISTORY_FRAMES):
		_history[i] = FrameRecord.new()


func record_frame(server_tick: int, heroes_by_id: Dictionary) -> void:
	var slot: FrameRecord = _history[posmod(server_tick, HISTORY_FRAMES)]
	slot.server_tick = server_tick
	slot.entries.clear()

	for id_key in heroes_by_id.keys():
		var hero: HeroCharacter = heroes_by_id[id_key]
		if hero == null or hero.is_defeated:
			continue
		if hero.current_vehicle_id >= 0 and hero.current_seat_enclosed:
			continue
		var snap := HeroHitboxSnapshot.new()
		snap.entity_id = hero.entity_id
		snap.team = hero.team
		var bounds: Dictionary = _compute_hero_bounds(hero)
		snap.body_radius = float(bounds["body_radius"])
		snap.body_bottom = bounds["body_bottom"]
		snap.body_top = bounds["body_top"]
		snap.head_center = bounds["head_center"]
		snap.head_radius = float(bounds["head_radius"])
		slot.entries[hero.entity_id] = snap


func get_frame(target_tick: int, current_tick: int) -> FrameRecord:
	var clamped_tick: int = clampi(target_tick, maxi(0, current_tick - MAX_REWIND_TICKS), current_tick)
	var rec: FrameRecord = _history[posmod(clamped_tick, HISTORY_FRAMES)]
	if rec.server_tick == clamped_tick:
		return rec
	return null


## Evaluates a rewound hitscan ray against World/Vehicle geometry and rewound opponent hitboxes.
## Returns {hit: bool, target_hero_id: int, target_object: Node, is_headshot: bool, hit_pos: Vector3, distance: float}
func trace_rewound_ray(
	shooter: HeroCharacter,
	ray_origin: Vector3,
	ray_dir: Vector3,
	max_range: float,
	view_tick_delta: int,
	current_tick: int,
	heroes_by_id: Dictionary,
	world_3d: World3D,
	exclude_rids: Array[RID] = []
) -> Dictionary:
	var dir: Vector3 = ray_dir.normalized()
	var target_tick: int = current_tick - clampi(view_tick_delta, 0, MAX_REWIND_TICKS)
	var frame: FrameRecord = get_frame(target_tick, current_tick)
	return _trace_segment(shooter, ray_origin, ray_origin + dir * max_range, frame, heroes_by_id, world_3d, exclude_rids)


## Finds the closest rewound (or live fallback) hero hitbox intersected by a ray.
## Returns {hit: bool, dist: float, pos: Vector3, hero_id: int, headshot: bool}
func find_closest_rewound_hero_hit(
	shooter: HeroCharacter,
	ray_origin: Vector3,
	ray_dir: Vector3,
	max_dist: float,
	view_tick_delta: int,
	current_tick: int,
	heroes_by_id: Dictionary
) -> Dictionary:
	var target_tick: int = current_tick - clampi(view_tick_delta, 0, MAX_REWIND_TICKS)
	var frame: FrameRecord = get_frame(target_tick, current_tick)
	return find_closest_hero_hit_in_frame(shooter, ray_origin, ray_dir, max_dist, frame, heroes_by_id)


static func find_closest_hero_hit_in_frame(
	shooter: HeroCharacter,
	ray_origin: Vector3,
	ray_dir: Vector3,
	max_dist: float,
	frame: FrameRecord,
	heroes_by_id: Dictionary,
	hit_veh: VehicleBase = null,
	unblocked_max_dist: float = -1.0
) -> Dictionary:
	var dir: Vector3 = ray_dir.normalized()
	var cap_dist: float = unblocked_max_dist if unblocked_max_dist > 0.0 else max_dist
	var best_dist: float = cap_dist
	var best_pos: Vector3 = ray_origin + dir * cap_dist
	var best_hero_id: int = -1
	var best_headshot: bool = false

	if frame != null:
		for id_key in frame.entries.keys():
			var snap: HeroHitboxSnapshot = frame.entries[id_key]
			if shooter != null and (snap.entity_id == shooter.entity_id or snap.team == shooter.team):
				continue
			var live_h: HeroCharacter = heroes_by_id.get(snap.entity_id, null) as HeroCharacter
			if live_h != null and (live_h.is_defeated or (live_h.current_vehicle_id >= 0 and live_h.current_seat_enclosed)):
				continue

			var is_open_seat_in_hit_veh: bool = false
			if hit_veh != null and live_h != null and live_h.current_vehicle_id == hit_veh.id and not live_h.current_seat_enclosed:
				is_open_seat_in_hit_veh = true

			var allowed_max: float = best_dist
			if not is_open_seat_in_hit_veh:
				allowed_max = minf(allowed_max, max_dist)

			var h_res: Dictionary = _hit_test_hero_bounds(
				ray_origin, dir, allowed_max,
				snap.head_center, snap.head_radius,
				snap.body_bottom, snap.body_top, snap.body_radius
			)
			if bool(h_res["hit"]):
				best_dist = float(h_res["dist"])
				best_pos = ray_origin + dir * best_dist
				best_hero_id = snap.entity_id
				best_headshot = bool(h_res["headshot"])
	else:
		# Fallback to live hero bounds if buffer hasn't reached target_tick yet
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h == null or h.is_defeated:
				continue
			if h.current_vehicle_id >= 0 and h.current_seat_enclosed:
				continue
			if shooter != null and (h.entity_id == shooter.entity_id or h.team == shooter.team):
				continue

			var is_open_seat_in_hit_veh: bool = false
			if hit_veh != null and h.current_vehicle_id == hit_veh.id and not h.current_seat_enclosed:
				is_open_seat_in_hit_veh = true

			var allowed_max: float = best_dist
			if not is_open_seat_in_hit_veh:
				allowed_max = minf(allowed_max, max_dist)

			var bnd: Dictionary = _compute_hero_bounds(h)
			var h_res: Dictionary = _hit_test_hero_bounds(
				ray_origin, dir, allowed_max,
				bnd["head_center"], float(bnd["head_radius"]),
				bnd["body_bottom"], bnd["body_top"], float(bnd["body_radius"])
			)
			if bool(h_res["hit"]):
				best_dist = float(h_res["dist"])
				best_pos = ray_origin + dir * best_dist
				best_hero_id = h.entity_id
				best_headshot = bool(h_res["headshot"])

	return {
		"hit": best_hero_id >= 0,
		"dist": best_dist,
		"pos": best_pos,
		"hero_id": best_hero_id,
		"headshot": best_headshot,
	}


## Evaluates a gravity-curved ballistic arc against World/Vehicle geometry and rewound opponent hitboxes.
## Returns {hit: bool, target_hero_id: int, target_object: Node, is_headshot: bool, hit_pos: Vector3, distance: float, arc_points: PackedVector3Array}
func trace_ballistic_arc(
	shooter: HeroCharacter,
	ray_origin: Vector3,
	initial_vel: Vector3,
	gravity_mps2: float,
	max_range: float,
	step_distance: float,
	view_tick_delta: int,
	current_tick: int,
	heroes_by_id: Dictionary,
	world_3d: World3D,
	exclude_rids: Array[RID] = []
) -> Dictionary:
	var arc_points := PackedVector3Array([ray_origin])
	if max_range <= 0.0 or initial_vel.length_squared() < 0.0001:
		return {
			"hit": false,
			"target_hero_id": -1,
			"target_object": null,
			"is_headshot": false,
			"hit_pos": ray_origin,
			"distance": 0.0,
			"arc_points": arc_points,
		}

	var target_tick: int = current_tick - clampi(view_tick_delta, 0, MAX_REWIND_TICKS)
	var frame: FrameRecord = get_frame(target_tick, current_tick)

	if gravity_mps2 <= 0.001:
		var straight_dir: Vector3 = initial_vel.normalized()
		var straight_res: Dictionary = _trace_segment(
			shooter,
			ray_origin,
			ray_origin + straight_dir * max_range,
			frame,
			heroes_by_id,
			world_3d,
			exclude_rids
		)
		arc_points.append(straight_res.get("hit_pos", ray_origin + straight_dir * max_range))
		straight_res["arc_points"] = arc_points
		return straight_res

	var seg_step: float = clampf(step_distance, 4.0, 32.0) if step_distance > 0.0 else 12.0
	var pos: Vector3 = ray_origin
	var vel: Vector3 = initial_vel
	var traveled: float = 0.0
	var steps: int = 0

	while traveled < max_range and steps < 64:
		steps += 1
		var cur_speed: float = maxf(10.0, vel.length())
		var rem_dist: float = maxf(0.0, max_range - traveled)
		var dt: float = minf(seg_step / cur_speed, rem_dist / cur_speed)
		dt = clampf(dt, 0.005, 0.14)
		var vel_next: Vector3 = vel + Vector3(0.0, -gravity_mps2 * dt, 0.0)
		var next_pos: Vector3 = pos + (vel + vel_next) * 0.5 * dt

		var seg_res: Dictionary = _trace_segment(shooter, pos, next_pos, frame, heroes_by_id, world_3d, exclude_rids)
		if bool(seg_res.get("hit", false)):
			var hit_pos: Vector3 = seg_res["hit_pos"]
			arc_points.append(hit_pos)
			seg_res["distance"] = traveled + pos.distance_to(hit_pos)
			seg_res["arc_points"] = arc_points
			return seg_res

		arc_points.append(next_pos)
		traveled += pos.distance_to(next_pos)
		pos = next_pos
		vel = vel_next
		if pos.y < -25.0:
			break

	return {
		"hit": false,
		"target_hero_id": -1,
		"target_object": null,
		"is_headshot": false,
		"hit_pos": pos,
		"distance": traveled,
		"arc_points": arc_points,
	}


func _trace_segment(
	shooter: HeroCharacter,
	seg_start: Vector3,
	seg_end: Vector3,
	frame: FrameRecord,
	heroes_by_id: Dictionary,
	world_3d: World3D,
	exclude_rids: Array[RID] = []
) -> Dictionary:
	var seg_vec: Vector3 = seg_end - seg_start
	var seg_len: float = seg_vec.length()
	if seg_len <= 0.0001:
		return {
			"hit": false,
			"target_hero_id": -1,
			"target_object": null,
			"is_headshot": false,
			"hit_pos": seg_end,
			"distance": 0.0,
		}

	var dir: Vector3 = seg_vec / seg_len
	var best_dist: float = seg_len
	var best_pos: Vector3 = seg_end
	var hit_object: Node = null
	var hit_world: bool = false
	var hit_veh: VehicleBase = null

	# 1. Check static world + vehicles + destructibles at current state
	if world_3d != null:
		var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(
				seg_start,
				seg_end,
				1 | 8 | 64 # Layer 1 World (1) + Layer 4 Vehicle (8) + Layer 7 Destructible (64)
			)
			query.hit_from_inside = true
			var excludes: Array[RID] = []
			if shooter != null:
				excludes.append(shooter.get_rid())
			for rid in exclude_rids:
				if not excludes.has(rid):
					excludes.append(rid)
			if not excludes.is_empty():
				query.exclude = excludes
			var res: Dictionary = space.intersect_ray(query)
			if not res.is_empty():
				best_pos = res["position"]
				best_dist = seg_start.distance_to(best_pos)
				hit_world = true
				var collider: Object = res.get("collider", null)
				if collider is Node:
					var c_node: Node = collider as Node
					if c_node.is_in_group("vehicles") or c_node.is_in_group("destructible"):
						hit_object = c_node
					if c_node is VehicleBase:
						hit_veh = c_node as VehicleBase
						hit_object = c_node
					elif c_node.get_parent() is VehicleBase:
						hit_veh = c_node.get_parent() as VehicleBase
						hit_object = hit_veh

	# 2. Check rewound player hitboxes (or live fallback)
	# For heroes seated in an open seat of hit_veh, hit_veh does not block the shot!
	var hero_hit: Dictionary = find_closest_hero_hit_in_frame(
		shooter,
		seg_start,
		dir,
		best_dist,
		frame,
		heroes_by_id,
		hit_veh,
		seg_len
	)
	var best_hero_id: int = -1
	var best_headshot: bool = false
	if bool(hero_hit.get("hit", false)):
		best_dist = float(hero_hit["dist"])
		best_pos = hero_hit["pos"]
		best_hero_id = int(hero_hit["hero_id"])
		best_headshot = bool(hero_hit["headshot"])
		hit_object = null

	return {
		"hit": best_hero_id >= 0 or hit_world or hit_object != null,
		"target_hero_id": best_hero_id,
		"target_object": hit_object,
		"is_headshot": best_headshot,
		"hit_pos": best_pos,
		"distance": best_dist,
	}


static func _compute_hero_bounds(hero: HeroCharacter) -> Dictionary:
	var h_pos: Vector3 = hero.global_position if hero.is_inside_tree() else hero.position
	var height: float = HeroCharacter.CROUCH_HEIGHT if hero.is_crouching else HeroCharacter.STAND_HEIGHT
	var r: float = hero.capsule_radius
	return {
		"body_radius": r,
		"body_bottom": h_pos + Vector3(0.0, r, 0.0),
		"body_top": h_pos + Vector3(0.0, maxf(r + 0.1, height - r), 0.0),
		"head_center": h_pos + Vector3(0.0, height - 0.14, 0.0),
		"head_radius": 0.24,
	}


static func _hit_test_hero_bounds(
	origin: Vector3,
	dir: Vector3,
	max_dist: float,
	head_center: Vector3,
	head_radius: float,
	body_bottom: Vector3,
	body_top: Vector3,
	body_radius: float
) -> Dictionary:
	var t_head: float = ray_intersect_sphere(origin, dir, head_center, head_radius)
	if t_head >= 0.0 and t_head < max_dist:
		return {"hit": true, "dist": t_head, "headshot": true}
	var t_body: float = ray_intersect_capsule(origin, dir, body_bottom, body_top, body_radius)
	if t_body >= 0.0 and t_body < max_dist:
		return {"hit": true, "dist": t_body, "headshot": false}
	return {"hit": false}


static func ray_intersect_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc: Vector3 = origin - center
	var b: float = oc.dot(dir)
	var c: float = oc.dot(oc) - radius * radius
	if c > 0.0 and b > 0.0:
		return -1.0
	var disc: float = b * b - c
	if disc < 0.0:
		return -1.0
	var t: float = -b - sqrt(disc)
	if t < 0.0:
		t = 0.0
	return t


static func ray_intersect_capsule(origin: Vector3, dir: Vector3, p0: Vector3, p1: Vector3, radius: float) -> float:
	var ba: Vector3 = p1 - p0
	var oa: Vector3 = origin - p0
	var baba: float = ba.dot(ba)
	var bard: float = ba.dot(dir)
	var baoa: float = ba.dot(oa)
	var rdoa: float = dir.dot(oa)
	var oaoa: float = oa.dot(oa)

	var a: float = baba - bard * bard
	var b: float = baba * rdoa - baoa * bard
	var c: float = baba * oaoa - baoa * baoa - radius * radius * baba
	var h: float = b * b - a * c
	if h >= 0.0 and absf(a) > 0.00001:
		var t: float = (-b - sqrt(h)) / a
		var y: float = baoa + t * bard
		if y > 0.0 and y < baba:
			return maxf(0.0, t)

	# Cap spheres
	var t0: float = ray_intersect_sphere(origin, dir, p0, radius)
	var t1: float = ray_intersect_sphere(origin, dir, p1, radius)
	if t0 >= 0.0 and t1 >= 0.0:
		return minf(t0, t1)
	if t0 >= 0.0:
		return t0
	return t1
