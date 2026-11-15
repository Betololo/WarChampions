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

	for _pellet in range(pellet_count):
		var shot_dir: Vector3 = apply_spread(base_dir, spread_mult)
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
		var arc_pts := PackedVector3Array([origin, hit_pos])
		pellet_hits.append(hit_pos)
		pellet_arcs.append(arc_pts)
		fired.emit(weapon_kind, origin, hit_pos)

		var target_id: int = int(trace.get("target_hero_id", -1))
		if target_id >= 0 and heroes_by_id.has(target_id):
			var victim: HeroCharacter = heroes_by_id[target_id]
			var is_hs: bool = bool(trace.get("is_headshot", false))
			var dmg: int = compute_falloff_damage(float(trace.get("distance", 0.0)), is_hs, dmg_mult)
			var dealt: int = victim.apply_damage_server(dmg, owner_hero.entity_id, false)

			# Apply Burning Bullets DoT (SMG / Pistol) or Poisoned Blade DoT (Knife)
			if victim.status_effects != null and owner_hero.status_effects != null:
				if (weapon_kind == WeaponKind.SMG or weapon_kind == WeaponKind.PISTOL) and owner_hero.status_effects.has_method("has_burning_bullets") and owner_hero.status_effects.has_burning_bullets():
					victim.status_effects.apply_burn(owner_hero.entity_id, owner_hero.status_effects.get_burning_dps(), 4.5)
				elif weapon_kind == WeaponKind.KNIFE and owner_hero.status_effects.has_method("has_poisoned_blade") and owner_hero.status_effects.has_poisoned_blade():
					victim.status_effects.apply_poison(owner_hero.entity_id, owner_hero.status_effects.get_poison_dps(), 5.0)

			# Frenzy Fire: Every 4th accurate MG hit heals Gunner
			if weapon_kind == WeaponKind.MG and owner_hero.status_effects != null and owner_hero.status_effects.has_method("has_frenzy_fire") and owner_hero.status_effects.has_frenzy_fire():
				_frenzy_hit_counter += 1
				if _frenzy_hit_counter >= 4:
					_frenzy_hit_counter = 0
					owner_hero.heal_server(owner_hero.status_effects.get_frenzy_heal_amount())

			var xp_cb: Callable = context.get("on_damage_dealt", Callable())
			if xp_cb.is_valid():
				xp_cb.call(owner_hero, victim, dealt)

			dmg_by_victim[target_id] = int(dmg_by_victim.get(target_id, 0)) + dmg
			pos_by_victim[target_id] = hit_pos
			crit_by_victim[target_id] = bool(crit_by_victim.get(target_id, false)) or is_hs
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
