class_name HitscanWeapon
extends WeaponBase

## Hitscan weapons (SMG, MG, Shotgun, Pistol, Sniper, Knife) using Server-Side Lag Compensation.

var _frenzy_hit_counter: int = 0
var _dual_hand_idx: int = 0


func fire_server(cmd: InputCmd, context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return

	# Attacking breaks Commando Stealth immediately
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("break_stealth"):
		owner_hero.status_effects.break_stealth()
	if weapon_kind == WeaponKind.STICK_GRENADE and owner_hero.status_effects != null and owner_hero.status_effects.has_method("trigger_carried_shield_swing_gap"):
		owner_hero.status_effects.trigger_carried_shield_swing_gap(0.48)

	var is_dual: bool = (weapon_kind == WeaponKind.DUAL_REVOLVERS or weapon_kind == WeaponKind.DUAL_PISTOLS)
	var used_hand: int = _dual_hand_idx if is_dual else 0
	if is_dual:
		_dual_hand_idx = 1 - _dual_hand_idx

	var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var aim: Dictionary = get_aim_origin_and_dir(cmd, space_state, lag_comp, heroes_by_id, used_hand)
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
				if v_node.has_method("get_shield_rid"):
					var s_rid: RID = v_node.get_shield_rid()
					if s_rid.is_valid():
						exclude_rids.append(s_rid)

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
				var p_allied_veh: bool = (p_obj is VehicleBase and (p_obj as VehicleBase).team >= 0 and (p_obj as VehicleBase).team == owner_hero.team)
				if not p_allied_veh:
					var is_p_veh: bool = (p_obj as Node).is_in_group("vehicles")
					var p_veh_mult: float = 1.0
					if is_p_veh and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_vehicle_damage_mult"):
						p_veh_mult = float(owner_hero.status_effects.get_vehicle_damage_mult())
					var p_obj_dmg: int = compute_falloff_damage(float(p_trace.get("distance", 0.0)), false, dmg_mult * p_veh_mult)
					(p_obj as Node).apply_damage_server(p_obj_dmg, owner_hero.entity_id, shot_dir, stop_pos, false)
					if not is_p_veh:
						NetworkManager.broadcast_game_event("hit_vfx", {"pos": stop_pos, "kind": "spark", "attacker_id": owner_hero.entity_id, "damage": p_obj_dmg, "headshot": false})
			elif bool(p_trace.get("hit_world", false)):
				NetworkManager.broadcast_game_event("hit_vfx", {"pos": stop_pos, "kind": "dust", "attacker_id": owner_hero.entity_id})
			_destroy_enemy_stickies_along_ray(origin, shot_dir, float(p_trace.get("distance", max_range_m)))
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
			if space_state != null:
				var fb_q := PhysicsRayQueryParameters3D.create(origin, fallback_end, 1 | 8 | 64)
				fb_q.hit_from_inside = true
				var fb_excl: Array[RID] = []
				if owner_hero.is_inside_tree():
					fb_excl.append(owner_hero.get_rid())
				for rid in exclude_rids:
					if not fb_excl.has(rid):
						fb_excl.append(rid)
				fb_q.exclude = fb_excl
				var fb_hit: Dictionary = space_state.intersect_ray(fb_q)
				if not fb_hit.is_empty():
					var fb_pos: Vector3 = fb_hit["position"]
					var fb_col: Object = fb_hit.get("collider", null)
					var fb_obj: Node = null
					if fb_col is Node:
						var cn: Node = fb_col as Node
						if cn.is_in_group("vehicles") or cn.is_in_group("destructible"):
							fb_obj = cn
						if cn is VehicleBase:
							fb_obj = cn
						elif cn.get_parent() is VehicleBase:
							fb_obj = cn.get_parent()
					trace = {
						"hit": true,
						"target_hero_id": -1,
						"target_object": fb_obj,
						"is_headshot": false,
						"hit_pos": fb_pos,
						"distance": origin.distance_to(fb_pos),
						"arc_points": PackedVector3Array([origin, fb_pos]),
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

		var sticky_hit: Dictionary = _find_closest_enemy_sticky(origin, shot_dir, float(trace.get("distance", max_range_m)))
		if not sticky_hit.is_empty():
			var hit_sticky: ProjectileEntity = sticky_hit["sticky"] as ProjectileEntity
			hit_pos = sticky_hit["pos"] as Vector3
			hit_sticky.destroy_by_enemy()
			var s_arc := PackedVector3Array([origin, hit_pos])
			pellet_hits.append(hit_pos)
			pellet_arcs.append(s_arc)
			fired.emit(weapon_kind, origin, hit_pos)
			continue

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
				var is_allied_vehicle: bool = (obj is VehicleBase and (obj as VehicleBase).team >= 0 and (obj as VehicleBase).team == owner_hero.team)
				if is_allied_vehicle:
					NetworkManager.broadcast_game_event("hit_vfx", {
						"pos": hit_pos,
						"kind": "dust",
						"attacker_id": owner_hero.entity_id,
					})
				else:
					var veh_mult: float = 1.0
					if is_veh and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_vehicle_damage_mult"):
						veh_mult = float(owner_hero.status_effects.get_vehicle_damage_mult())
					var obj_dmg: int = compute_falloff_damage(float(trace.get("distance", 0.0)), false, dmg_mult * veh_mult)
					var impact_dir: Vector3 = shot_dir
					if arc_pts.size() >= 2:
						var seg_d: Vector3 = arc_pts[arc_pts.size() - 1] - arc_pts[arc_pts.size() - 2]
						if seg_d.length_squared() > 0.0001:
							impact_dir = seg_d.normalized()
					if weapon_kind == WeaponKind.STICK_GRENADE and not caber_spent:
						_trigger_caber_explosion(hit_pos, context)
					else:
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
		"archetype": archetype,
		"hand": used_hand,
		"origin": origin,
		"dir": base_dir,
		"hits": pellet_hits,
		"arcs": pellet_arcs,
	})


func _find_closest_enemy_sticky(origin: Vector3, shot_dir: Vector3, max_dist: float) -> Dictionary:
	if owner_hero == null or not owner_hero.is_inside_tree():
		return {}
	var best_dist: float = max_dist
	var best_sticky: ProjectileEntity = null
	for node in owner_hero.get_tree().get_nodes_in_group("destructible_stickies"):
		if not (node is ProjectileEntity):
			continue
		var sticky: ProjectileEntity = node as ProjectileEntity
		if sticky._exploded or sticky.is_queued_for_deletion():
			continue
		if sticky.owner_team == owner_hero.team:
			continue
		var t: float = LagCompensator.ray_intersect_sphere(origin, shot_dir, sticky.global_position, sticky.hit_radius)
		if t >= 0.0 and t < best_dist:
			best_dist = t
			best_sticky = sticky
	if best_sticky != null:
		return {
			"sticky": best_sticky,
			"dist": best_dist,
			"pos": origin + shot_dir * best_dist,
		}
	return {}


func _destroy_enemy_stickies_along_ray(origin: Vector3, shot_dir: Vector3, max_dist: float) -> void:
	if owner_hero == null or not owner_hero.is_inside_tree():
		return
	var to_destroy: Array[ProjectileEntity] = []
	for node in owner_hero.get_tree().get_nodes_in_group("destructible_stickies"):
		if not (node is ProjectileEntity):
			continue
		var sticky: ProjectileEntity = node as ProjectileEntity
		if sticky._exploded or sticky.is_queued_for_deletion() or sticky.owner_team == owner_hero.team:
			continue
		var t: float = LagCompensator.ray_intersect_sphere(origin, shot_dir, sticky.global_position, sticky.hit_radius)
		if t >= 0.0 and t < max_dist:
			to_destroy.append(sticky)
	for s in to_destroy:
		s.destroy_by_enemy()


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

	var atk_from_target := Vector3(-shot_dir.x, 0.0, -shot_dir.z)
	if atk_from_target.length_squared() < 0.0001 and owner_hero != null:
		var o_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
		var v_pos_blk: Vector3 = victim.global_position if victim.is_inside_tree() else victim.position
		atk_from_target = Vector3(o_pos.x - v_pos_blk.x, 0.0, o_pos.z - v_pos_blk.z)
	if victim.status_effects != null and victim.status_effects.has_method("is_frontal_carried_shield_block_dir") and victim.status_effects.is_frontal_carried_shield_block_dir(atk_from_target):
		victim.status_effects.damage_carried_shield(dmg)
		NetworkManager.broadcast_game_event("hit_vfx", {
			"pos": hit_pos,
			"kind": "spark",
			"attacker_id": owner_hero.entity_id,
			"victim_id": victim.entity_id,
			"damage": 0,
			"headshot": false,
		})
		return

	if victim.current_vehicle_id >= 0:
		var vehs_by_id: Dictionary = context.get("vehicles_by_id", {})
		var v_occ: Node = vehs_by_id.get(victim.current_vehicle_id, null) as Node
		if v_occ == null:
			for v_cand in context.get("vehicles", []):
				if v_cand is VehicleBase and (v_cand as VehicleBase).id == victim.current_vehicle_id:
					v_occ = v_cand as Node
					break
		if v_occ != null and v_occ.has_method("is_frontal_shield_blocking_dir") and bool(v_occ.is_frontal_shield_blocking_dir(atk_from_target)):
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": hit_pos,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": victim.entity_id,
				"damage": 0,
				"headshot": false,
			})
			return

	# Stick Grenade (Caber) first live hit triggers clean 110 AoE + 55% (61) self-damage explosion (no extra 35 base hit)
	if weapon_kind == WeaponKind.STICK_GRENADE and not caber_spent:
		_trigger_caber_explosion(hit_pos, context)
		return

	var dealt: int = victim.apply_damage_server(dmg, owner_hero.entity_id, false)

	# Burning Bullets (SMG/Pistol) or Poisoned Blade (Knife)
	if victim.status_effects != null and owner_hero.status_effects != null:
		if (weapon_kind == WeaponKind.SMG or weapon_kind == WeaponKind.PISTOL) and owner_hero.status_effects.has_method("has_burning_bullets") and owner_hero.status_effects.has_burning_bullets():
			victim.status_effects.apply_burn(owner_hero.entity_id, owner_hero.status_effects.get_burning_dps(), 4.5)
		elif weapon_kind == WeaponKind.KNIFE and owner_hero.status_effects.has_method("has_poisoned_blade") and owner_hero.status_effects.has_poisoned_blade():
			victim.status_effects.apply_poison(owner_hero.entity_id, owner_hero.status_effects.get_poison_dps(), 6.0)
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


func _trigger_caber_explosion(exp_pos: Vector3, context: Dictionary) -> void:
	if caber_spent or owner_hero == null:
		return
	caber_spent = true
	if owner_hero.has_method("set_caber_spent_visual"):
		owner_hero.set_caber_spent_visual(true)
	NetworkManager.broadcast_game_event("caber_spent", {
		"hero_id": owner_hero.entity_id,
		"spent": true,
	})

	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var caber_radius: float = 6.0
	const CABER_AOE_BASE: float = 110.0
	var xp_cb: Callable = context.get("on_damage_dealt", Callable())
	for hid_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
		if h == null or h.is_defeated or h.team == owner_hero.team:
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var dist: float = minf(h_pos.distance_to(exp_pos), (h_pos + Vector3(0.0, 1.05, 0.0)).distance_to(exp_pos))
		var eff_dist: float = maxf(0.0, dist - h.capsule_radius)
		if eff_dist <= caber_radius:
			var falloff: float = clampf(1.0 - (eff_dist / caber_radius) * 0.72, 0.25, 1.0)
			var aoe_dmg: int = maxi(1, int(roundf(CABER_AOE_BASE * falloff)))
			if h.status_effects != null and h.status_effects.can_eat_grenades():
				var heal_amt: int = maxi(1, int(roundf(float(aoe_dmg) * 0.55)))
				h.heal_server(heal_amt)
				NetworkManager.broadcast_game_event("eat_grenades", {
					"hero_id": h.entity_id,
					"pos": h_pos,
					"heal": heal_amt,
				})
				continue
			var aoe_dealt: int = h.apply_damage_server(aoe_dmg, owner_hero.entity_id, true)
			if aoe_dealt > 0:
				if xp_cb.is_valid():
					xp_cb.call(owner_hero, h, aoe_dealt)
				NetworkManager.broadcast_game_event("hit_vfx", {
					"pos": h_pos + Vector3(0.0, 1.35, 0.0),
					"kind": "spark",
					"attacker_id": owner_hero.entity_id,
					"victim_id": h.entity_id,
					"damage": aoe_dealt,
					"headshot": false,
				})
			var horiz_vec := Vector3(h_pos.x - exp_pos.x, 0.0, h_pos.z - exp_pos.z)
			var horiz_dir: Vector3 = horiz_vec.normalized() if horiz_vec.length_squared() > 0.001 else Vector3.FORWARD
			var kb_dir: Vector3 = (horiz_dir * 0.78 + Vector3.UP * 0.62).normalized()
			h.apply_knockback(kb_dir * 18.0 * falloff)

	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	var veh_mult: float = 1.0
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_vehicle_damage_mult"):
		veh_mult = float(owner_hero.status_effects.get_vehicle_damage_mult())
	for v in vehs:
		if v is VehicleBase and (v as VehicleBase).team >= 0 and (v as VehicleBase).team == owner_hero.team:
			continue
		if v is Node3D and v.has_method("apply_damage_server"):
			var v_pos: Vector3 = (v as Node3D).global_position if (v as Node3D).is_inside_tree() else (v as Node3D).position
			if v_pos.distance_to(exp_pos) <= caber_radius + 1.5:
				var v_dir: Vector3 = (v_pos - exp_pos).normalized()
				var v_dmg: int = int(roundf(CABER_AOE_BASE * veh_mult))
				v.apply_damage_server(v_dmg, owner_hero.entity_id, v_dir, exp_pos, true)

	if owner_hero.is_inside_tree():
		for s in owner_hero.get_tree().get_nodes_in_group("destructible_stickies"):
			if not (s is ProjectileEntity):
				continue
			var sticky: ProjectileEntity = s as ProjectileEntity
			if sticky.owner_team != owner_hero.team and sticky.global_position.distance_to(exp_pos) <= caber_radius:
				sticky.destroy_by_enemy()

	var self_dmg: int = int(roundf(CABER_AOE_BASE * 0.55))
	owner_hero.apply_damage_server(self_dmg, owner_hero.entity_id, true, false, false)
	if not owner_hero.is_defeated:
		var self_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
		var self_vec := Vector3(self_pos.x - exp_pos.x, 0.0, self_pos.z - exp_pos.z)
		var self_dir: Vector3 = self_vec.normalized() if self_vec.length_squared() > 0.001 else Vector3.BACK
		owner_hero.apply_knockback((self_dir * 0.72 + Vector3.UP * 0.69).normalized() * 14.0)

	NetworkManager.broadcast_game_event("explosion_vfx", {
		"pos": exp_pos,
		"radius": caber_radius,
		"kind": WeaponKind.STICK_GRENADE,
		"attacker_id": owner_hero.entity_id,
	})
