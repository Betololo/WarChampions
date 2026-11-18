class_name FlameWeapon
extends WeaponBase

## Demolisher Slot 0 primary weapons:
## 0: Flamethrower (16.5m cone, 10 ammo/s, 5 dmg/tick + 3.0s Afterburn)
## 1: Fire Starter (21.0m cone + FirePatchEntity ground hazards, 20 ammo/s, 5 dmg/0.1s + 3.0s Afterburn)
## 2: Fire Breath (0.50s semi/auto, 10 ammo/shot, 45 m/s FIREBALL projectile, ~30.6m max reach)

const AFTERBURN_DPS: float = 10.0
const AFTERBURN_DURATION: float = 3.0
const FLAME_CONE_MIN_DOT: float = 0.65

var _contact_dmg_cooldown: float = 0.0


func step_timers(delta: float, cmd: InputCmd) -> void:
	super.step_timers(delta, cmd)
	if _contact_dmg_cooldown > 0.0:
		_contact_dmg_cooldown = maxf(0.0, _contact_dmg_cooldown - delta * _get_haste_fire_mult())


func reset_weapon() -> void:
	super.reset_weapon()
	_contact_dmg_cooldown = 0.0


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
	var arch: int = clampi(archetype, 0, 2)

	if arch == 2:
		var shot_dir: Vector3 = apply_spread(dir)
		var spawn_pos: Vector3 = origin + shot_dir * 0.9
		ProjectileEntity.spawn_server_projectile(
			ProjectileEntity.ProjectileKind.FIREBALL,
			owner_hero.entity_id,
			owner_hero.team,
			spawn_pos,
			shot_dir * 45.0,
			context,
			40.0,
			owner_hero.get_parent()
		)
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

	# Continuous Flamethrower (arch 0) & Fire Starter (arch 1)
	var deal_contact_dmg: bool = true
	if arch == 1:
		if _contact_dmg_cooldown > 0.0:
			deal_contact_dmg = false
		else:
			_contact_dmg_cooldown = 0.09

	var owner_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var cone_origin: Vector3 = owner_pos + Vector3(0.0, 1.35 if not owner_hero.is_crouching else 0.95, 0.0)
	var excludes_base: Array[RID] = []
	if owner_hero.is_inside_tree():
		excludes_base.append(owner_hero.get_rid())
	if owner_hero.current_vehicle_id >= 0 and owner_hero.is_inside_tree():
		for v_node in owner_hero.get_tree().get_nodes_in_group("vehicles"):
			if v_node is VehicleBase and (v_node as VehicleBase).id == owner_hero.current_vehicle_id:
				excludes_base.append((v_node as CollisionObject3D).get_rid())

	var dmg_amt: int = maxi(1, int(roundf(damage_max)))
	var xp_cb: Callable = context.get("on_damage_dealt", Callable())

	# 1. Enemy Heroes in flame cone (respecting water/fire immunity & Layer-1 LOS)
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
		if dist > 0.55 and (to_h / dist).dot(dir) < FLAME_CONE_MIN_DOT:
			continue

		if space_state != null and dist > 0.25:
			var occ_q := PhysicsRayQueryParameters3D.create(cone_origin, h_center, 1, excludes_base)
			var occ_hit: Dictionary = space_state.intersect_ray(occ_q)
			if not occ_hit.is_empty():
				continue

		if deal_contact_dmg:
			var dealt: int = h.apply_damage_server(dmg_amt, owner_hero.entity_id, false)
			if dealt > 0:
				if owner_hero.status_effects != null and owner_hero.status_effects.has_method("notify_damage_dealt_server"):
					owner_hero.status_effects.notify_damage_dealt_server(dealt)
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

	# 2. Vehicles in flame cone (3x Vehicle Buster multiplier + Shield Drain notify)
	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	var veh_mult: float = 1.0
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_vehicle_damage_mult"):
		veh_mult = float(owner_hero.status_effects.get_vehicle_damage_mult())

	for v in vehs:
		if not (v is Node3D) or not v.has_method("apply_damage_server"):
			continue
		if v is VehicleBase:
			var vb: VehicleBase = v as VehicleBase
			if vb.is_destroyed or (vb.team >= 0 and vb.team == owner_hero.team):
				continue
		var v_node: Node3D = v as Node3D
		var v_pos: Vector3 = (v_node.global_position if v_node.is_inside_tree() else v_node.position) + Vector3(0.0, 0.85, 0.0)
		var to_v: Vector3 = v_pos - cone_origin
		var v_dist: float = to_v.length()
		if v_dist > max_range_m + 2.5:
			continue
		var v_dir: Vector3 = to_v / maxf(v_dist, 0.001)
		if v_dist > 1.2 and v_dir.dot(dir) < FLAME_CONE_MIN_DOT:
			continue
		if space_state != null and v_dist > 0.4:
			var v_excl: Array[RID] = excludes_base.duplicate()
			if v_node is CollisionObject3D:
				v_excl.append((v_node as CollisionObject3D).get_rid())
			var v_occ := PhysicsRayQueryParameters3D.create(cone_origin, v_pos, 1, v_excl)
			if not space_state.intersect_ray(v_occ).is_empty():
				continue
		if deal_contact_dmg:
			var v_hp_pre: int = (v as VehicleBase).hp if v is VehicleBase else 0
			var vdmg: int = maxi(1, int(roundf(float(dmg_amt) * veh_mult)))
			v.apply_damage_server(vdmg, owner_hero.entity_id, v_dir, v_pos, false)
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("notify_damage_dealt_server"):
				var v_dealt: int = maxi(0, v_hp_pre - (v as VehicleBase).hp) if v is VehicleBase else vdmg
				if v_dealt > 0:
					owner_hero.status_effects.notify_damage_dealt_server(v_dealt)

	# 3. Enemy Riot Shields & destructible props in flame cone
	if owner_hero.is_inside_tree() and deal_contact_dmg:
		for d in owner_hero.get_tree().get_nodes_in_group("destructible"):
			if not (d is Node3D) or not d.has_method("apply_damage_server"):
				continue
			if d is DemolisherSkills.RiotShieldEntity and (d as DemolisherSkills.RiotShieldEntity).owner_team == owner_hero.team:
				continue
			var d_node: Node3D = d as Node3D
			var d_pos: Vector3 = d_node.global_position + Vector3(0.0, 0.9, 0.0)
			var to_d: Vector3 = d_pos - cone_origin
			var d_dist: float = to_d.length()
			var d_dir: Vector3 = to_d / maxf(d_dist, 0.001)
			if d_dist <= max_range_m + 0.8 and (d_dist <= 1.0 or d_dir.dot(dir) >= FLAME_CONE_MIN_DOT):
				var arg3: Variant = owner_hero.team if d is DemolisherSkills.RiotShieldEntity else d_dir
				d.apply_damage_server(dmg_amt, owner_hero.entity_id, arg3, d_pos, false)

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
