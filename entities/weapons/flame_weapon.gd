class_name FlameWeapon
extends WeaponBase

## Demolisher Slot 0 primary weapons:
## 0: Flamethrower (21.0m cone, 10 ammo/s, 10 dmg/tick + 3.0s Afterburn)
## 1: Fire Starter (21.0m cone + FirePatchEntity ground hazards, 5 ammo/0.25s = 20 ammo/s, 10 dmg/shot + 3.0s Afterburn)
## 2: Fire Breath (0.50s semi/auto, 10 ammo/shot, 45 m/s FIREBALL projectile, ~30.6m max reach)

const AFTERBURN_DPS: float = 10.0
const AFTERBURN_DURATION: float = 3.0
const FLAME_CONE_MIN_DOT: float = 0.65


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
	var arch: int = clampi(archetype, 0, 2)

	var owner_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var cone_origin: Vector3 = owner_pos + Vector3(0.0, 1.35 if not owner_hero.is_crouching else 0.95, 0.0)
	var excludes_base: Array[RID] = []
	if owner_hero.is_inside_tree():
		excludes_base.append(owner_hero.get_rid())
	if owner_hero.current_vehicle_id >= 0 and owner_hero.is_inside_tree():
		for v_node in owner_hero.get_tree().get_nodes_in_group("vehicles"):
			if v_node is VehicleBase and (v_node as VehicleBase).id == owner_hero.current_vehicle_id:
				excludes_base.append((v_node as CollisionObject3D).get_rid())

	if arch == 2:
		var shot_dir: Vector3 = apply_spread(dir)
		var spawn_dist: float = 0.35
		if space_state != null:
			var pre_q := PhysicsRayQueryParameters3D.create(origin, origin + shot_dir * 0.9, 1, excludes_base)
			var pre_hit: Dictionary = space_state.intersect_ray(pre_q)
			if not pre_hit.is_empty():
				var wall_dist: float = origin.distance_to(pre_hit["position"] as Vector3)
				spawn_dist = minf(spawn_dist, maxf(0.05, wall_dist - 0.08))
		var spawn_pos: Vector3 = origin + shot_dir * spawn_dist
		var fb: ProjectileEntity = ProjectileEntity.spawn_server_projectile(
			ProjectileEntity.ProjectileKind.FIREBALL,
			owner_hero.entity_id,
			owner_hero.team,
			spawn_pos,
			shot_dir * 45.0,
			context,
			40.0,
			owner_hero.get_parent()
		)
		if fb != null:
			_check_fireball_point_blank(fb, cone_origin, cam_fwd, spawn_pos, shot_dir, space_state, excludes_base, context)
		var end_pos: Vector3 = spawn_pos + shot_dir * 24.0
		fired.emit(weapon_kind, spawn_pos, end_pos)
		NetworkManager.broadcast_game_event("shot_vfx", {
			"shooter_id": owner_hero.entity_id,
			"weapon_kind": weapon_kind,
			"archetype": arch,
			"origin": spawn_pos,
			"dir": shot_dir,
			"hits": [],
		})
		return

	var dmg_amt: int = maxi(1, int(roundf(damage_max)))
	var xp_cb: Callable = context.get("on_damage_dealt", Callable())

	# 1. Enemy Heroes in flame cone (respecting water/fire immunity, close-range cylinder & Layer-1 LOS)
	for hid_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated:
			continue
		if h.entity_id == owner_hero.entity_id or h.team == owner_hero.team:
			continue
		if h.current_vehicle_id >= 0 and h.current_seat_enclosed:
			continue
		var is_immune: bool = h.is_in_water or (h.status_effects != null and h.status_effects.fire_immunity_timer > 0.0)
		if is_immune:
			continue

		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var h_center: Vector3 = h_pos + Vector3(0.0, 1.05, 0.0)
		var to_h: Vector3 = h_center - cone_origin
		var dist: float = to_h.length()
		if dist > max_range_m + h.capsule_radius:
			continue

		var in_close_zone: bool = false
		if dist <= 1.35 and to_h.dot(cam_fwd) >= -0.15:
			in_close_zone = true
		elif dist <= 3.0:
			var proj: float = to_h.dot(cam_fwd)
			if proj >= -0.15:
				var ray_pt: Vector3 = cone_origin + cam_fwd * maxf(0.0, proj)
				var horiz_dist: float = Vector2(h_center.x - ray_pt.x, h_center.z - ray_pt.z).length()
				if horiz_dist <= 1.25 and absf(h_center.y - ray_pt.y) <= 1.8:
					in_close_zone = true

		var eff_dir: Vector3 = cam_fwd if dist <= 3.0 else dir
		if not in_close_zone and dist > 0.55 and (to_h / dist).dot(eff_dir) < FLAME_CONE_MIN_DOT:
			continue

		if space_state != null and dist > 0.25:
			var occ_q := PhysicsRayQueryParameters3D.create(cone_origin, h_center, 1, excludes_base)
			var occ_hit: Dictionary = space_state.intersect_ray(occ_q)
			if not occ_hit.is_empty():
				continue

		if h.status_effects != null and h.status_effects.has_method("is_frontal_carried_shield_block") and h.status_effects.is_frontal_carried_shield_block(cone_origin):
			h.status_effects.damage_carried_shield(dmg_amt)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": h_center,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": h.entity_id,
				"damage": 0,
			})
			continue

		var dealt: int = h.apply_damage_server(dmg_amt, owner_hero.entity_id, false)
		if dealt > 0:
			if xp_cb.is_valid():
				xp_cb.call(owner_hero, h, dealt)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": h_center,
				"kind": "fire",
				"attacker_id": owner_hero.entity_id,
				"victim_id": h.entity_id,
				"damage": dealt,
			})
		if h.status_effects != null and h.status_effects.has_method("apply_burn"):
			h.status_effects.apply_burn(owner_hero.entity_id, AFTERBURN_DPS, AFTERBURN_DURATION)

	# 2. Vehicles in flame cone (3x Vehicle Buster multiplier + Shield Drain notify + corner AABB clamp)
	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	var veh_mult: float = 1.0
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_vehicle_damage_mult"):
		veh_mult = float(owner_hero.status_effects.get_vehicle_damage_mult())

	for v in vehs:
		if not (v is Node3D) or not v.has_method("apply_damage_server"):
			continue
		if v is VehicleBase and not _is_hostile_vehicle(v as VehicleBase, heroes_by_id):
			continue
		var v_node: Node3D = v as Node3D
		var v_hit: Dictionary = _find_vehicle_flame_target(v_node, cone_origin, cam_fwd, dir)
		if not bool(v_hit.get("hit", false)):
			continue
		var v_pos: Vector3 = v_hit["pos"] as Vector3
		var v_dist: float = float(v_hit["dist"])
		var v_dir: Vector3 = v_hit["dir"] as Vector3
		if space_state != null and v_dist > 0.25:
			var v_excl: Array[RID] = excludes_base.duplicate()
			if v_node is CollisionObject3D:
				v_excl.append((v_node as CollisionObject3D).get_rid())
			var v_occ := PhysicsRayQueryParameters3D.create(cone_origin, v_pos, 1, v_excl)
			if not space_state.intersect_ray(v_occ).is_empty():
				continue
		var vdmg: int = maxi(1, int(roundf(float(dmg_amt) * veh_mult)))
		v.apply_damage_server(vdmg, owner_hero.entity_id, v_dir, v_pos, false)

	# 3. Destructible props in flame cone
	if owner_hero.is_inside_tree():
		for d in owner_hero.get_tree().get_nodes_in_group("destructible"):
			if not (d is Node3D) or not d.has_method("apply_damage_server"):
				continue
			var d_node: Node3D = d as Node3D
			var d_pos: Vector3 = d_node.global_position + Vector3(0.0, 0.9, 0.0)
			var to_d: Vector3 = d_pos - cone_origin
			var d_dist: float = to_d.length()
			var d_dir: Vector3 = to_d / maxf(d_dist, 0.001)
			var d_eff: Vector3 = cam_fwd if d_dist <= 3.0 else dir
			if d_dist <= max_range_m + 0.8 and (d_dist <= 1.35 and to_d.dot(cam_fwd) >= -0.15 or d_dir.dot(d_eff) >= FLAME_CONE_MIN_DOT):
				d.apply_damage_server(dmg_amt, owner_hero.entity_id, d_dir, d_pos, false)

	# 4. Fire Starter (arch == 1): raycast aim ray up to max_range_m (21.0m) to spawn/refresh FirePatchEntity
	var stream_end: Vector3 = origin + dir * max_range_m
	if space_state != null:
		var wall_q := PhysicsRayQueryParameters3D.create(origin, stream_end, 1, excludes_base)
		var wall_hit: Dictionary = space_state.intersect_ray(wall_q)
		if not wall_hit.is_empty():
			stream_end = wall_hit["position"] as Vector3

	if arch == 1 and space_state != null:
		_try_spawn_or_refresh_fire_patch(origin, dir, space_state, excludes_base, context)

	fired.emit(weapon_kind, origin, stream_end)
	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": weapon_kind,
		"archetype": arch,
		"origin": origin,
		"dir": dir,
		"hits": [stream_end],
	})


func _is_hostile_vehicle(vb: VehicleBase, heroes_by_id: Dictionary) -> bool:
	if vb.is_destroyed or vb.id == owner_hero.current_vehicle_id:
		return false
	if vb.team < 0 or vb.team != owner_hero.team:
		return true
	for s in vb.seats:
		if s.occupant_id >= 0:
			var occ: HeroCharacter = heroes_by_id.get(s.occupant_id, null) as HeroCharacter
			if occ != null and not occ.is_defeated and occ.team != owner_hero.team:
				return true
	return false


func _find_vehicle_flame_target(v_node: Node3D, cone_origin: Vector3, cam_fwd: Vector3, dir: Vector3) -> Dictionary:
	var v_xform: Transform3D = v_node.global_transform if v_node.is_inside_tree() else v_node.transform
	var v_inv: Transform3D = v_xform.affine_inverse()
	var cone_local: Vector3 = v_inv * cone_origin
	var v_center_world: Vector3 = v_xform * Vector3(0.0, 0.85, 0.0)
	var approx_dist: float = clampf(cone_origin.distance_to(v_center_world), 0.0, max_range_m)
	var ray_local: Vector3 = v_inv * (cone_origin + dir * approx_dist)
	var cam_ray_local: Vector3 = v_inv * (cone_origin + cam_fwd * minf(3.0, approx_dist))
	var best_pt: Vector3 = Vector3.ZERO
	var best_dist: float = INF
	var best_dir: Vector3 = dir
	var hit_any: bool = false
	for local_pt in [ray_local, cam_ray_local, cone_local]:
		var clamped_local := Vector3(
			clampf(local_pt.x, -2.4, 2.4),
			clampf(local_pt.y, -0.2, 2.2),
			clampf(local_pt.z, -2.8, 2.8)
		)
		var world_pt: Vector3 = v_xform * clamped_local
		var to_v: Vector3 = world_pt - cone_origin
		var vd: float = to_v.length()
		if vd > max_range_m + 0.8:
			continue
		var v_dir: Vector3 = to_v / maxf(vd, 0.001)
		var eff_dir: Vector3 = cam_fwd if vd <= 3.0 else dir
		var close_ok: bool = (vd <= 1.35 and to_v.dot(cam_fwd) >= -0.15)
		if not close_ok and vd > 0.55 and v_dir.dot(eff_dir) < FLAME_CONE_MIN_DOT:
			continue
		if vd < best_dist:
			best_dist = vd
			best_pt = world_pt
			best_dir = v_dir
			hit_any = true
	return {"hit": hit_any, "pos": best_pt, "dist": best_dist, "dir": best_dir}


func _check_fireball_point_blank(
	fb: ProjectileEntity,
	cone_origin: Vector3,
	cam_fwd: Vector3,
	spawn_pos: Vector3,
	shot_dir: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	excludes_base: Array[RID],
	context: Dictionary
) -> void:
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var best_dist_sq: float = INF
	var best_contact: Vector3 = Vector3.ZERO
	var best_veh_rid: RID = RID()
	var has_contact: bool = false
	var check_end: Vector3 = cone_origin + cam_fwd * 0.95
	var spawn_end: Vector3 = spawn_pos + shot_dir * 0.65

	for hid_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated:
			continue
		if h.entity_id == owner_hero.entity_id or h.team == owner_hero.team:
			continue
		if h.current_vehicle_id >= 0 and h.current_seat_enclosed:
			continue
		if h.is_in_water or (h.status_effects != null and h.status_effects.fire_immunity_timer > 0.0):
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var cap_a: Vector3 = h_pos + Vector3(0.0, 0.3, 0.0)
		var cap_b: Vector3 = h_pos + Vector3(0.0, 1.7, 0.0)
		for seg in [[cone_origin, check_end], [spawn_pos, spawn_end]]:
			var seg_a: Vector3 = seg[0] as Vector3
			var seg_b: Vector3 = seg[1] as Vector3
			var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(seg_a, seg_b, cap_a, cap_b)
			if closest[0].distance_to(closest[1]) <= 0.62 + h.capsule_radius * 0.4:
				var d_sq: float = cone_origin.distance_squared_to(closest[0])
				if d_sq < best_dist_sq:
					best_dist_sq = d_sq
					best_contact = closest[0]
					best_veh_rid = RID()
					has_contact = true

	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	var hull_aabb := AABB(Vector3(-1.8, -0.8, -3.0), Vector3(3.6, 3.6, 6.0))
	for v in vehs:
		if not (v is Node3D):
			continue
		if v is VehicleBase and not _is_hostile_vehicle(v as VehicleBase, heroes_by_id):
			continue
		var v_node: Node3D = v as Node3D
		var v_xform: Transform3D = v_node.global_transform if v_node.is_inside_tree() else v_node.transform
		var v_inv: Transform3D = v_xform.affine_inverse()
		var local_a: Vector3 = v_inv * cone_origin
		var local_b: Vector3 = v_inv * check_end
		var hit_v_pt: Variant = hull_aabb.intersects_segment(local_a, local_b)
		var contact_v: Vector3 = Vector3.ZERO
		var hit_v: bool = false
		if hull_aabb.has_point(local_a):
			contact_v = cone_origin
			hit_v = true
		elif hull_aabb.has_point(local_b):
			contact_v = check_end
			hit_v = true
		elif hit_v_pt is Vector3:
			contact_v = v_xform * (hit_v_pt as Vector3)
			hit_v = true
		if hit_v:
			var d_sq_v: float = cone_origin.distance_squared_to(contact_v)
			if d_sq_v < best_dist_sq:
				best_dist_sq = d_sq_v
				best_contact = contact_v
				best_veh_rid = (v as CollisionObject3D).get_rid() if v is CollisionObject3D else RID()
				has_contact = true

	if has_contact:
		var wall_blocked: bool = false
		if space_state != null and best_dist_sq > 0.01:
			var occ_excl: Array[RID] = excludes_base.duplicate()
			if best_veh_rid.is_valid():
				occ_excl.append(best_veh_rid)
			var occ_q := PhysicsRayQueryParameters3D.create(cone_origin, best_contact, 1, occ_excl)
			if not space_state.intersect_ray(occ_q).is_empty():
				wall_blocked = true
		if not wall_blocked:
			fb.global_position = best_contact
			fb._detonate()


func _try_spawn_or_refresh_fire_patch(
	origin: Vector3,
	dir: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	excludes: Array[RID],
	context: Dictionary
) -> void:
	var aim_end: Vector3 = origin + dir * max_range_m
	var patch_pos: Vector3 = Vector3.ZERO
	var found_surface: bool = false

	var aim_q := PhysicsRayQueryParameters3D.create(origin, aim_end, 1, excludes)
	var aim_hit: Dictionary = space_state.intersect_ray(aim_q)
	if aim_hit.is_empty():
		return

	var hit_n: Vector3 = aim_hit.get("normal", Vector3.UP)
	var hit_p: Vector3 = aim_hit["position"] as Vector3
	if hit_n.y >= 0.45:
		patch_pos = hit_p
		found_surface = true
	elif dir.y <= 0.15:
		var drop_from: Vector3 = hit_p - dir * 0.25 + Vector3(0.0, 0.2, 0.0)
		var drop_hit: Dictionary = space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(drop_from, drop_from - Vector3(0.0, 2.4, 0.0), 1, excludes)
		)
		if not drop_hit.is_empty():
			var drop_n: Vector3 = drop_hit.get("normal", Vector3.UP)
			if drop_n.y >= 0.45:
				patch_pos = drop_hit["position"] as Vector3
				found_surface = true

	if not found_surface:
		return
	# Non-water surface check (water surface is HeroCharacter.WATER_LEVEL = 0.0; submerged terrain is below -0.25)
	if patch_pos.y < HeroCharacter.WATER_LEVEL - 0.25:
		return

	var patch_root: Node = context.get("projectiles_root", owner_hero.get_parent()) as Node
	if patch_root == null:
		return

	# Refresh existing friendly patch nearby instead of stacking overlapping nodes
	var existing_patches: Array[Node] = []
	for ch in patch_root.get_children():
		if ch is DemolisherSkills.FirePatchEntity:
			existing_patches.append(ch)
	if owner_hero.is_inside_tree():
		for gp in owner_hero.get_tree().get_nodes_in_group("fire_patches"):
			if gp is DemolisherSkills.FirePatchEntity and not existing_patches.has(gp):
				existing_patches.append(gp)

	for ep in existing_patches:
		var fp_existing: DemolisherSkills.FirePatchEntity = ep as DemolisherSkills.FirePatchEntity
		if not is_instance_valid(fp_existing) or fp_existing.is_queued_for_deletion():
			continue
		if fp_existing.owner_id != owner_hero.entity_id:
			continue
		var ep_pos: Vector3 = fp_existing.global_position if fp_existing.is_inside_tree() else fp_existing.position
		if ep_pos.distance_to(patch_pos) <= 2.0:
			fp_existing._lifetime_elapsed = 0.0
			NetworkManager.broadcast_game_event("fire_patch_vfx", {
				"pos": ep_pos,
				"owner_id": owner_hero.entity_id,
				"radius": fp_existing.radius,
			})
			return

	var fp := DemolisherSkills.FirePatchEntity.new()
	fp.owner_id = owner_hero.entity_id
	fp.owner_team = owner_hero.team
	fp.max_lifetime = 6.0
	fp.position = patch_pos
	fp._context = context
	patch_root.add_child(fp)

	NetworkManager.broadcast_game_event("fire_patch_spawn", {
		"owner_id": owner_hero.entity_id,
		"team": owner_hero.team,
		"pos": patch_pos,
		"radius": fp.radius,
		"lifetime": fp.max_lifetime,
	})
	NetworkManager.broadcast_game_event("fire_patch_vfx", {
		"pos": patch_pos,
		"owner_id": owner_hero.entity_id,
		"radius": fp.radius,
	})
