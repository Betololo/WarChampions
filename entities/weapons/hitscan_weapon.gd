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

	var aim: Dictionary = get_aim_origin_and_dir(cmd)
	var origin: Vector3 = aim["origin"]
	var base_dir: Vector3 = aim["dir"]

	var spread_mult: float = 1.0
	if is_sniper and cmd.has_button(InputCmd.BTN_AIM):
		spread_mult = 0.08
	elif owner_hero.status_effects != null and owner_hero.status_effects.has_method("has_frenzy_fire"):
		if weapon_kind == WeaponKind.MG and owner_hero.status_effects.has_frenzy_fire():
			spread_mult = 0.35

	var dmg_mult: float = 1.0
	if is_sniper and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_piercing_shot_mult"):
		dmg_mult *= owner_hero.status_effects.get_piercing_shot_mult()

	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null

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
				world_3d
			)
		else:
			trace = {"hit": false, "target_hero_id": -1, "target_object": null, "is_headshot": false, "hit_pos": origin + shot_dir * max_range_m, "distance": max_range_m}

		var hit_pos: Vector3 = trace.get("hit_pos", origin + shot_dir * max_range_m)
		fired.emit(weapon_kind, origin, hit_pos)

		var target_id: int = int(trace.get("target_hero_id", -1))
		if target_id >= 0 and heroes_by_id.has(target_id):
			var victim: HeroCharacter = heroes_by_id[target_id]
			var dmg: int = compute_falloff_damage(float(trace.get("distance", 0.0)), bool(trace.get("is_headshot", false)), dmg_mult)
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

			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": hit_pos,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": target_id,
				"damage": dmg,
				"headshot": bool(trace.get("is_headshot", false)),
			})
		else:
			var obj: Variant = trace.get("target_object", null)
			if obj != null and obj is Node and (obj as Node).has_method("apply_damage_server"):
				var obj_dmg: int = compute_falloff_damage(float(trace.get("distance", 0.0)), false, dmg_mult * 0.45)
				(obj as Node).apply_damage_server(obj_dmg, owner_hero.entity_id, shot_dir, hit_pos, false)
			if bool(trace.get("hit", false)):
				NetworkManager.broadcast_game_event("hit_vfx", {
					"pos": hit_pos,
					"kind": "dust",
					"attacker_id": owner_hero.entity_id,
				})
