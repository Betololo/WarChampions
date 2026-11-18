class_name WeldingWeapon
extends WeaponBase

## Field Engineer Slot 2 weapon: Maçarico de Solda (Welding Torch).
## Close-range (3.6m) continuous 0.12s beam:
## - Enemy heroes: 10 dmg/tick with weld spark VFX
## - Vehicles with any enemy occupant riding inside: 18 dmg/tick
## - Allied or empty vehicles (zero enemy occupants): +15 HP/tick repair

const WELD_HERO_DMG: int = 10
const WELD_ENEMY_VEH_DMG: int = 18
const WELD_REPAIR_HP: int = 15
const WELD_MIN_DOT: float = 0.58


func fire_server(cmd: InputCmd, context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return

	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("break_stealth"):
		owner_hero.status_effects.break_stealth()

	var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var aim: Dictionary = get_aim_origin_and_dir(cmd, space_state, lag_comp, heroes_by_id)
	var origin: Vector3 = aim["origin"] as Vector3
	var dir: Vector3 = (aim["dir"] as Vector3).normalized()
	var cam_basis := Basis.from_euler(Vector3(cmd.aim_pitch, cmd.aim_yaw, 0.0))
	var cam_fwd: Vector3 = (-cam_basis.z).normalized()

	var owner_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var beam_origin: Vector3 = owner_pos + Vector3(0.0, 1.35 if not owner_hero.is_crouching else 0.95, 0.0)
	var excludes_base: Array[RID] = []
	if owner_hero.is_inside_tree():
		excludes_base.append(owner_hero.get_rid())
	if owner_hero.current_vehicle_id >= 0 and owner_hero.is_inside_tree():
		for v_node in owner_hero.get_tree().get_nodes_in_group("vehicles"):
			if v_node is VehicleBase and (v_node as VehicleBase).id == owner_hero.current_vehicle_id:
				excludes_base.append((v_node as CollisionObject3D).get_rid())

	var beam_end: Vector3 = origin + dir * max_range_m
	if space_state != null:
		var wall_q := PhysicsRayQueryParameters3D.create(origin, beam_end, 1, excludes_base)
		var wall_hit: Dictionary = space_state.intersect_ray(wall_q)
		if not wall_hit.is_empty():
			beam_end = wall_hit["position"] as Vector3

	var xp_cb: Callable = context.get("on_damage_dealt", Callable())
	var best_hit_dist: float = max_range_m + 0.5
	var best_hit_pos: Vector3 = beam_end
	var best_kind: String = "" # "hero" | "veh" | "destr"
	var best_hero: HeroCharacter = null
	var best_veh: VehicleBase = null
	var best_veh_dir: Vector3 = dir
	var best_destr: Node3D = null

	# 1. Check Enemy Heroes within 3.6m beam
	for hid_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated:
			continue
		if h.entity_id == owner_hero.entity_id or h.team == owner_hero.team:
			continue
		if h.current_vehicle_id >= 0 and h.current_seat_enclosed:
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var h_center: Vector3 = h_pos + Vector3(0.0, 1.05, 0.0)
		var to_h: Vector3 = h_center - beam_origin
		var dist: float = to_h.length()
		var eff_dist: float = maxf(0.0, dist - h.capsule_radius)
		if eff_dist > max_range_m:
			continue
		var close_ok: bool = (dist <= 1.35 and to_h.dot(cam_fwd) >= -0.15)
		if not close_ok and dist > 0.25 and (to_h / dist).dot(dir) < WELD_MIN_DOT and (to_h / dist).dot(cam_fwd) < WELD_MIN_DOT:
			continue
		if space_state != null and dist > 0.25:
			var occ_q := PhysicsRayQueryParameters3D.create(beam_origin, h_center, 1, excludes_base)
			if not space_state.intersect_ray(occ_q).is_empty():
				continue
		if eff_dist < best_hit_dist:
			best_hit_dist = eff_dist
			best_hit_pos = h_center
			best_kind = "hero"
			best_hero = h

	# 2. Check Vehicles within 3.6m beam (heal allied/empty, damage enemy-occupied)
	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	for v in vehs:
		if not (v is VehicleBase):
			continue
		var vb: VehicleBase = v as VehicleBase
		if vb.is_destroyed or vb.id == owner_hero.current_vehicle_id:
			continue
		var v_hit: Dictionary = _find_vehicle_weld_target(vb, beam_origin, cam_fwd, dir)
		if not bool(v_hit.get("hit", false)):
			continue
		var v_pos: Vector3 = v_hit["pos"] as Vector3
		var v_dist: float = float(v_hit["dist"])
		if space_state != null and v_dist > 0.25:
			var v_excl: Array[RID] = excludes_base.duplicate()
			v_excl.append(vb.get_rid())
			var v_occ := PhysicsRayQueryParameters3D.create(beam_origin, v_pos, 1, v_excl)
			if not space_state.intersect_ray(v_occ).is_empty():
				continue
		if v_dist < best_hit_dist:
			best_hit_dist = v_dist
			best_hit_pos = v_pos
			best_kind = "veh"
			best_veh = vb
			best_veh_dir = v_hit["dir"] as Vector3

	# 3. Check Destructibles (Trench, crates) if no hero/vehicle closer
	if best_kind.is_empty() and owner_hero.is_inside_tree():
		for d in owner_hero.get_tree().get_nodes_in_group("destructible"):
			if not (d is Node3D) or not d.has_method("apply_damage_server"):
				continue
			var d_node: Node3D = d as Node3D
			var d_pos: Vector3 = (d_node.global_position if d_node.is_inside_tree() else d_node.position) + Vector3(0.0, 0.9, 0.0)
			var to_d: Vector3 = d_pos - beam_origin
			var d_dist: float = to_d.length()
			if d_dist > max_range_m + 1.0:
				continue
			var d_dir: Vector3 = to_d / maxf(d_dist, 0.001)
			if d_dist <= 1.5 or d_dir.dot(dir) >= WELD_MIN_DOT or d_dir.dot(cam_fwd) >= WELD_MIN_DOT:
				if d_dist < best_hit_dist:
					best_hit_dist = d_dist
					best_hit_pos = d_pos
					best_kind = "destr"
					best_destr = d_node

	# Apply effect to closest valid target
	if best_kind == "hero" and best_hero != null:
		beam_end = best_hit_pos
		if best_hero.status_effects != null and best_hero.status_effects.has_method("is_frontal_carried_shield_block") and best_hero.status_effects.is_frontal_carried_shield_block(beam_origin):
			best_hero.status_effects.damage_carried_shield(WELD_HERO_DMG)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": best_hit_pos,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": best_hero.entity_id,
				"damage": 0,
			})
		else:
			var dealt: int = best_hero.apply_damage_server(WELD_HERO_DMG, owner_hero.entity_id, false)
			if dealt > 0 and xp_cb.is_valid():
				xp_cb.call(owner_hero, best_hero, dealt)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": best_hit_pos,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": best_hero.entity_id,
				"damage": dealt,
			})
	elif best_kind == "veh" and best_veh != null:
		beam_end = best_hit_pos
		var has_enemy_inside: bool = _vehicle_has_enemy_occupant(best_veh, heroes_by_id)
		if has_enemy_inside:
			best_veh.apply_damage_server(WELD_ENEMY_VEH_DMG, owner_hero.entity_id, best_veh_dir, best_hit_pos, false)
		elif best_veh.team == owner_hero.team or best_veh.get_occupant_count() == 0:
			var repaired: int = best_veh.repair_server(WELD_REPAIR_HP)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": best_hit_pos,
				"kind": "heal" if repaired > 0 else "spark",
				"attacker_id": owner_hero.entity_id,
				"damage": 0,
			})
	elif best_kind == "destr" and best_destr != null:
		beam_end = best_hit_pos
		var d_dir: Vector3 = (best_hit_pos - beam_origin).normalized()
		best_destr.apply_damage_server(WELD_HERO_DMG, owner_hero.entity_id, d_dir, best_hit_pos, false)
		NetworkManager.broadcast_game_event("hit_vfx", {
			"pos": best_hit_pos,
			"kind": "spark",
			"attacker_id": owner_hero.entity_id,
			"damage": WELD_HERO_DMG,
		})

	fired.emit(weapon_kind, origin, beam_end)
	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": weapon_kind,
		"origin": origin,
		"dir": dir,
		"hits": [beam_end],
	})


func _vehicle_has_enemy_occupant(vb: VehicleBase, heroes_by_id: Dictionary) -> bool:
	for s in vb.seats:
		if s.occupant_id >= 0:
			var occ: HeroCharacter = heroes_by_id.get(s.occupant_id, null) as HeroCharacter
			if occ != null and not occ.is_defeated and occ.team != owner_hero.team:
				return true
	return false


func _find_vehicle_weld_target(v_node: Node3D, beam_origin: Vector3, cam_fwd: Vector3, dir: Vector3) -> Dictionary:
	var v_xform: Transform3D = v_node.global_transform if v_node.is_inside_tree() else v_node.transform
	var v_inv: Transform3D = v_xform.affine_inverse()
	var origin_local: Vector3 = v_inv * beam_origin
	var v_center_world: Vector3 = v_xform * Vector3(0.0, 0.85, 0.0)
	var approx_dist: float = clampf(beam_origin.distance_to(v_center_world), 0.0, max_range_m)
	var ray_local: Vector3 = v_inv * (beam_origin + dir * approx_dist)
	var cam_ray_local: Vector3 = v_inv * (beam_origin + cam_fwd * minf(2.5, approx_dist))
	var best_pt: Vector3 = Vector3.ZERO
	var best_dist: float = INF
	var best_dir: Vector3 = dir
	var hit_any: bool = false
	for local_pt in [ray_local, cam_ray_local, origin_local]:
		var clamped_local := Vector3(
			clampf(local_pt.x, -2.2, 2.2),
			clampf(local_pt.y, -0.2, 2.1),
			clampf(local_pt.z, -2.6, 2.6)
		)
		var world_pt: Vector3 = v_xform * clamped_local
		var to_v: Vector3 = world_pt - beam_origin
		var vd: float = to_v.length()
		if vd > max_range_m + 0.35:
			continue
		var v_dir: Vector3 = to_v / maxf(vd, 0.001)
		var close_ok: bool = (vd <= 1.45 and to_v.dot(cam_fwd) >= -0.15)
		if not close_ok and vd > 0.25 and v_dir.dot(dir) < WELD_MIN_DOT and v_dir.dot(cam_fwd) < WELD_MIN_DOT:
			continue
		if vd < best_dist:
			best_dist = vd
			best_pt = world_pt
			best_dir = v_dir
			hit_any = true
	return {"hit": hit_any, "pos": best_pt, "dist": best_dist, "dir": best_dir}
