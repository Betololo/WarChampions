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
		var h_pos: Vector3 = hero.global_position if hero.is_inside_tree() else hero.position
		var height: float = HeroCharacter.CROUCH_HEIGHT if hero.is_crouching else HeroCharacter.STAND_HEIGHT
		var r: float = hero.capsule_radius
		snap.body_radius = r
		snap.body_bottom = h_pos + Vector3(0.0, r, 0.0)
		snap.body_top = h_pos + Vector3(0.0, maxf(r + 0.1, height - r), 0.0)
		snap.head_center = h_pos + Vector3(0.0, height - 0.14, 0.0)
		snap.head_radius = 0.24
		slot.entries[hero.entity_id] = snap


func get_frame(target_tick: int, current_tick: int) -> FrameRecord:
	var clamped_tick: int = clampi(target_tick, maxi(0, current_tick - MAX_REWIND_TICKS), current_tick)
	var rec: FrameRecord = _history[posmod(clamped_tick, HISTORY_FRAMES)]
	if rec.server_tick == clamped_tick:
		return rec
	return null


## Evaluates a rewound hitscan ray against World/Vehicle geometry and rewound opponent hitboxes.
## Returns {hit: bool, target_hero_id: int, target_vehicle: Node, is_headshot: bool, hit_pos: Vector3, distance: float}
func trace_rewound_ray(
	shooter: HeroCharacter,
	ray_origin: Vector3,
	ray_dir: Vector3,
	max_range: float,
	view_tick_delta: int,
	current_tick: int,
	heroes_by_id: Dictionary,
	world_3d: World3D
) -> Dictionary:
	var dir: Vector3 = ray_dir.normalized()
	var best_dist: float = max_range
	var best_pos: Vector3 = ray_origin + dir * max_range
	var hit_vehicle: Node = null
	var hit_world: bool = false

	# 1. Check static world + vehicles + destructibles at current state
	if world_3d != null:
		var space: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(
				ray_origin,
				ray_origin + dir * max_range,
				1 | 8 | 64 # Layer 1 World (1) + Layer 4 Vehicle (8) + Layer 7 Destructible (64)
			)
			if shooter != null:
				query.exclude = [shooter.get_rid()]
			var res: Dictionary = space.intersect_ray(query)
			if not res.is_empty():
				best_pos = res["position"]
				best_dist = ray_origin.distance_to(best_pos)
				hit_world = true
				var collider: Object = res.get("collider", null)
				if collider is Node and (collider as Node).is_in_group("vehicles"):
					hit_vehicle = collider as Node
				elif collider is Node and (collider as Node).is_in_group("destructible"):
					hit_vehicle = collider as Node

	# 2. Check rewound player hitboxes closer than wall/vehicle hit
	var target_tick: int = current_tick - clampi(view_tick_delta, 0, MAX_REWIND_TICKS)
	var frame: FrameRecord = get_frame(target_tick, current_tick)
	var best_hero_id: int = -1
	var best_headshot: bool = false

	if frame != null:
		for id_key in frame.entries.keys():
			var snap: HeroHitboxSnapshot = frame.entries[id_key]
			if shooter != null and (snap.entity_id == shooter.entity_id or snap.team == shooter.team):
				continue
			var live_h: HeroCharacter = heroes_by_id.get(snap.entity_id, null) as HeroCharacter
			if live_h != null and live_h.current_vehicle_id >= 0 and live_h.current_seat_enclosed:
				continue
			var t_head: float = ray_intersect_sphere(ray_origin, dir, snap.head_center, snap.head_radius)
			if t_head >= 0.0 and t_head < best_dist:
				best_dist = t_head
				best_pos = ray_origin + dir * t_head
				best_hero_id = snap.entity_id
				best_headshot = true
				hit_vehicle = null
				continue

			var t_body: float = ray_intersect_capsule(ray_origin, dir, snap.body_bottom, snap.body_top, snap.body_radius)
			if t_body >= 0.0 and t_body < best_dist:
				best_dist = t_body
				best_pos = ray_origin + dir * t_body
				best_hero_id = snap.entity_id
				best_headshot = false
				hit_vehicle = null
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
			var height: float = HeroCharacter.CROUCH_HEIGHT if h.is_crouching else HeroCharacter.STAND_HEIGHT
			var r: float = h.capsule_radius
			var b := h.global_position + Vector3(0.0, r, 0.0)
			var t := h.global_position + Vector3(0.0, maxf(r + 0.1, height - r), 0.0)
			var hc := h.global_position + Vector3(0.0, height - 0.14, 0.0)
			var t_head: float = ray_intersect_sphere(ray_origin, dir, hc, 0.24)
			if t_head >= 0.0 and t_head < best_dist:
				best_dist = t_head
				best_pos = ray_origin + dir * t_head
				best_hero_id = h.entity_id
				best_headshot = true
				hit_vehicle = null
				continue
			var t_body: float = ray_intersect_capsule(ray_origin, dir, b, t, r)
			if t_body >= 0.0 and t_body < best_dist:
				best_dist = t_body
				best_pos = ray_origin + dir * t_body
				best_hero_id = h.entity_id
				best_headshot = false
				hit_vehicle = null

	return {
		"hit": best_hero_id >= 0 or hit_world or hit_vehicle != null,
		"target_hero_id": best_hero_id,
		"target_object": hit_vehicle,
		"is_headshot": best_headshot,
		"hit_pos": best_pos,
		"distance": best_dist,
	}


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
