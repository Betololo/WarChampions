class_name HitscanWeapon
extends WeaponBase

## Hitscan weapons (SMG, MG, Shotgun, Pistol, Sniper, Knife) using Server-Side Lag Compensation.

var _frenzy_hit_counter: int = 0


func fire_server(cmd: InputCmd, context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return

	# Attacking breaks Commando Stealth immediately
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("break_stealth"):
		owner_hero.status_effects.break_stealth()

	var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var aim: Dictionary = get_aim_origin_and_dir(cmd, space_state, lag_comp, heroes_by_id)
	var origin: Vector3 = aim["origin"]
	var base_dir: Vector3 = aim["dir"]

	var is_aiming: bool = cmd.has_button(InputCmd.BTN_AIM)
	var has_frenzy: bool = owner_hero.status_effects != null and owner_hero.status_effects.has_method("has_frenzy_fire") and owner_hero.status_effects.has_frenzy_fire()
	var spread_mult: float = get_current_spread_mult(is_aiming, has_frenzy, owner_hero.is_crouching)

	var dmg_mult: float = 1.0
	if is_sniper and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_piercing_shot_mult"):
		dmg_mult *= owner_hero.status_effects.get_piercing_shot_mult()

	var exclude_rids: Array[RID] = []
	if owner_hero.current_vehicle_id >= 0 and owner_hero.is_inside_tree():
		for v_node in owner_hero.get_tree().get_nodes_in_group("vehicles"):
			if v_node is VehicleBase and (v_node as VehicleBase).id == owner_hero.current_vehicle_id:
				exclude_rids.append((v_node as CollisionObject3D).get_rid())

	var pellet_hits: Array[Vector3] = []
	var pellet_arcs: Array[PackedVector3Array] = []
	var dmg_by_victim: Dictionary = {}
	var pos_by_victim: Dictionary = {}
	var crit_by_victim: Dictionary = {}

	var is_piercing: bool = is_sniper and owner_hero.status_effects != null and owner_hero.status_effects.has_method("has_piercing_shot") and owner_hero.status_effects.has_piercing_shot()

	for _pellet in range(pellet_count):
		var shot_dir: Vector3 = apply_spread(base_dir, spread_mult)
		if is_piercing and lag_comp != null:
			var p_trace: Dictionary = lag_comp.trace_rewound_ray_piercing(
				owner_hero,
				origin,
				shot_dir,
				max_range_m,
				cmd.view_interp_tick_delta,
				NetworkManager.server_tick,
				heroes_by_id,
				world_3d,
				exclude_rids
			)
			var stop_pos: Vector3 = p_trace.get("hit_pos", origin + shot_dir * max_range_m)
			var arc_pts := PackedVector3Array([origin, stop_pos])
			pellet_hits.append(stop_pos)
			pellet_arcs.append(arc_pts)
			fired.emit(weapon_kind, origin, stop_pos)
			for hh in p_trace.get("hero_hits", []):
				var hid: int = int(hh.get("target_hero_id", -1))
				if hid >= 0 and heroes_by_id.has(hid):
					_apply_hero_hit(
						heroes_by_id[hid] as HeroCharacter,
						shot_dir,
						float(hh.get("distance", 0.0)),
						bool(hh.get("is_headshot", false)),
						hh.get("hit_pos", stop_pos),
						dmg_mult,
						context,
						dmg_by_victim,
						pos_by_victim,
						crit_by_victim
					)
			var p_obj: Variant = p_trace.get("target_object", null)
			if p_obj != null and p_obj is Node and (p_obj as Node).has_method("apply_damage_server"):
				var p_obj_dmg: int = compute_falloff_damage(float(p_trace.get("distance", 0.0)), false, dmg_mult)
				var is_p_veh: bool = (p_obj as Node).is_in_group("vehicles")
				(p_obj as Node).apply_damage_server(p_obj_dmg, owner_hero.entity_id, shot_dir, stop_pos, false)
				if not is_p_veh:
					NetworkManager.broadcast_game_event("hit_vfx", {"pos": stop_pos, "kind": "spark", "attacker_id": owner_hero.entity_id, "damage": p_obj_dmg, "headshot": false})
			elif bool(p_trace.get("hit_world", false)):
				NetworkManager.broadcast_game_event("hit_vfx", {"pos": stop_pos, "kind": "dust", "attacker_id": owner_hero.entity_id})
			continue

		var trace: Dictionary
		if lag_comp != null:
			trace = lag_comp.trace_rewound_ray(
				owner_hero,
				origin,
				shot_dir,
				max_range_m,
				cmd.view_interp_tick_delta,
				NetworkManager.server_tick,
				heroes_by_id,
				world_3d,
				exclude_rids
			)
		else:
			var fallback_end: Vector3 = origin + shot_dir * max_range_m
			trace = {
				"hit": false,
				"target_hero_id": -1,
				"target_object": null,
				"is_headshot": false,
				"hit_pos": fallback_end,
				"distance": max_range_m,
				"arc_points": PackedVector3Array([origin, fallback_end]),
			}

		var hit_pos: Vector3 = trace.get("hit_pos", origin + shot_dir * max_range_m)
		var target_id: int = int(trace.get("target_hero_id", -1))
		if is_melee and target_id < 0:
			var owner_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
			var shot_xz := Vector3(shot_dir.x, 0.0, shot_dir.z)
			if shot_xz.length_squared() > 0.0001:
				shot_xz = shot_xz.normalized()
			else:
				shot_xz = (-Basis(Vector3.UP, cmd.aim_yaw).z).normalized()
			var max_cleave_dist: float = max_range_m + 0.55
			var best_melee_dist: float = max_cleave_dist + 0.01
			var best_melee_enemy: HeroCharacter = null
			var cleave_space: PhysicsDirectSpaceState3D = owner_hero.get_world_3d().direct_space_state if owner_hero.is_inside_tree() and owner_hero.get_world_3d() != null else null
			var cleave_exclude: Array[RID] = [owner_hero.get_rid()]
			for hid_key in heroes_by_id.keys():
				var cand: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
				if cand == null or not is_instance_valid(cand) or cand.is_defeated:
					continue
				if cand.entity_id == owner_hero.entity_id or cand.team == owner_hero.team:
					continue
				if cand.current_vehicle_id >= 0 and cand.current_seat_enclosed:
					continue
				var cand_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
				var d: float = owner_pos.distance_to(cand_pos)
				if d > max_cleave_dist:
					continue
				var to_cand_xz := Vector3(cand_pos.x - owner_pos.x, 0.0, cand_pos.z - owner_pos.z)
				if to_cand_xz.length_squared() > 0.0001 and to_cand_xz.normalized().dot(shot_xz) < 0.45:
					continue
				if cleave_space != null and owner_pos.distance_squared_to(cand_pos) > 0.001:
					var wall_q := PhysicsRayQueryParameters3D.create(
						owner_pos + Vector3(0.0, 1.15, 0.0),
						cand_pos + Vector3(0.0, 1.15, 0.0),
						1,
						cleave_exclude
					)
					var wall_hit: Dictionary = cleave_space.intersect_ray(wall_q)
					if not wall_hit.is_empty():
						continue
				if d < best_melee_dist:
					best_melee_dist = d
					best_melee_enemy = cand
			if best_melee_enemy != null:
				var best_pos: Vector3 = best_melee_enemy.global_position if best_melee_enemy.is_inside_tree() else best_melee_enemy.position
				target_id = best_melee_enemy.entity_id
				hit_pos = best_pos + Vector3(0.0, 1.15, 0.0)
				trace["target_hero_id"] = target_id
				trace["hit_pos"] = hit_pos
				trace["distance"] = best_melee_dist
				trace["hit"] = true

		var arc_pts := PackedVector3Array([origin, hit_pos])
		pellet_hits.append(hit_pos)
		pellet_arcs.append(arc_pts)
		fired.emit(weapon_kind, origin, hit_pos)

		if target_id >= 0 and heroes_by_id.has(target_id):
			_apply_hero_hit(
				heroes_by_id[target_id] as HeroCharacter,
				shot_dir,
				float(trace.get("distance", 0.0)),
				bool(trace.get("is_headshot", false)),
				hit_pos,
				dmg_mult,
				context,
				dmg_by_victim,
				pos_by_victim,
				crit_by_victim
			)
		else:
			var obj: Variant = trace.get("target_object", null)
			var is_veh: bool = (obj != null and obj is Node and (obj as Node).is_in_group("vehicles"))
			if obj != null and obj is Node and (obj as Node).has_method("apply_damage_server"):
				var obj_dmg: int = compute_falloff_damage(float(trace.get("distance", 0.0)), false, dmg_mult)
				var impact_dir: Vector3 = shot_dir
				if arc_pts.size() >= 2:
					var seg_d: Vector3 = arc_pts[arc_pts.size() - 1] - arc_pts[arc_pts.size() - 2]
					if seg_d.length_squared() > 0.0001:
						impact_dir = seg_d.normalized()
				(obj as Node).apply_damage_server(obj_dmg, owner_hero.entity_id, impact_dir, hit_pos, false)
				if not is_veh:
					NetworkManager.broadcast_game_event("hit_vfx", {
						"pos": hit_pos,
						"kind": "spark",
						"attacker_id": owner_hero.entity_id,
						"damage": obj_dmg,
					})
			elif bool(trace.get("hit", false)):
				NetworkManager.broadcast_game_event("hit_vfx", {
					"pos": hit_pos,
					"kind": "dust",
					"attacker_id": owner_hero.entity_id,
				})

	for vid in dmg_by_victim.keys():
		NetworkManager.broadcast_game_event("hit_vfx", {
			"pos": pos_by_victim[vid],
			"kind": "spark",
			"attacker_id": owner_hero.entity_id,
			"victim_id": int(vid),
			"damage": int(dmg_by_victim[vid]),
			"headshot": bool(crit_by_victim.get(vid, false)),
		})

	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": weapon_kind,
		"origin": origin,
		"dir": base_dir,
		"hits": pellet_hits,
		"arcs": pellet_arcs,
	})


func _apply_hero_hit(
	victim: HeroCharacter,
	shot_dir: Vector3,
	dist_m: float,
	is_hs: bool,
	hit_pos: Vector3,
	dmg_mult: float,
	context: Dictionary,
	dmg_by_victim: Dictionary,
	pos_by_victim: Dictionary,
	crit_by_victim: Dictionary
) -> void:
	if victim == null:
		return
	var dmg: int = compute_falloff_damage(dist_m, is_hs, dmg_mult)
	var effective_crit: bool = is_hs

	# Commando Knife Backstab: 120-degree rear cone deals 75 damage
	if weapon_kind == WeaponKind.KNIFE:
		var victim_fwd: Vector3 = -Basis(Vector3.UP, victim.aim_yaw).z
		victim_fwd.y = 0.0
		var attack_xz: Vector3 = Vector3(shot_dir.x, 0.0, shot_dir.z)
		if victim_fwd.length_squared() > 0.001 and attack_xz.length_squared() > 0.001:
			if victim_fwd.normalized().dot(attack_xz.normalized()) >= 0.5:
				dmg = maxi(1, int(roundf(75.0 * dmg_mult)))
				effective_crit = true

	var dealt: int = victim.apply_damage_server(dmg, owner_hero.entity_id, false)

	# Burning Bullets (SMG/Pistol) or Poisoned Blade (Knife)
	if victim.status_effects != null and owner_hero.status_effects != null:
		if (weapon_kind == WeaponKind.SMG or weapon_kind == WeaponKind.PISTOL) and owner_hero.status_effects.has_method("has_burning_bullets") and owner_hero.status_effects.has_burning_bullets():
			victim.status_effects.apply_burn(owner_hero.entity_id, owner_hero.status_effects.get_burning_dps(), 4.5)
		elif weapon_kind == WeaponKind.KNIFE and owner_hero.status_effects.has_method("has_poisoned_blade") and owner_hero.status_effects.has_poisoned_blade():
			victim.status_effects.apply_poison(owner_hero.entity_id, owner_hero.status_effects.get_poison_dps(), 6.0)
			var init_pdmg: int = maxi(1, int(roundf(owner_hero.status_effects.get_poison_dps() * 0.5)))
			var p_dealt: int = victim.apply_damage_server(init_pdmg, owner_hero.entity_id, false, false, true)
			dealt += p_dealt
			if p_dealt > 0:
				dmg += p_dealt
			var v_pos: Vector3 = victim.global_position if victim.is_inside_tree() else victim.position
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": v_pos + Vector3(0.0, 1.1, 0.0),
				"kind": "heal",
			})

	# Frenzy Fire: Every 4th accurate MG hit heals Gunner
	if weapon_kind == WeaponKind.MG and owner_hero.status_effects != null and owner_hero.status_effects.has_method("has_frenzy_fire") and owner_hero.status_effects.has_frenzy_fire():
		_frenzy_hit_counter += 1
		if _frenzy_hit_counter >= 4:
			_frenzy_hit_counter = 0
			owner_hero.heal_server(owner_hero.status_effects.get_frenzy_heal_amount())

	var xp_cb: Callable = context.get("on_damage_dealt", Callable())
	if xp_cb.is_valid():
		xp_cb.call(owner_hero, victim, dealt)

	dmg_by_victim[victim.entity_id] = int(dmg_by_victim.get(victim.entity_id, 0)) + dmg
	pos_by_victim[victim.entity_id] = hit_pos
	crit_by_victim[victim.entity_id] = bool(crit_by_victim.get(victim.entity_id, false)) or effective_crit
