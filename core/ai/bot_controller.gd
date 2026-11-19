class_name BotController
extends Node

## Server-side AI Brain for 12v12 War Champions bots:
## Enforces strict Layer-1 Line-of-Sight anti-wallhack targeting, human reaction delay,
## burst-fire cadence, realistic sinusoidal + noisy aim sway, objective capture, and vehicles.

const LOS_EYE_HEIGHT: float = 1.55
const LOS_TARGET_HEIGHT: float = 1.25
const MAX_DETECT_RANGE: float = 85.0
const MAX_FIRE_RANGE: float = 75.0
const MEMORY_PURSUIT_SEC: float = 1.0
const FOV_HALF_ANGLE_DEG: float = 65.0
const FOV_MIN_COS: float = 0.422618

var bot_hero: HeroCharacter = null
var _ai_tick: int = 0
var _retarget_timer: float = 0.0
var _target_flag: CapturePoint = null
var _strafe_dir: float = 1.0

var _engaged_target_id: int = -1
var _last_seen_pos: Vector3 = Vector3.ZERO
var _memory_timer: float = 0.0
var _reaction_timer: float = 0.0
var _burst_timer: float = 0.0
var _burst_firing: bool = true
var _aim_time: float = 0.0
var _aim_seed: float = 0.0
var _reusable_cmd: InputCmd = InputCmd.new()
var _ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
var _ray_exclude: Array[RID] = []
var _los_cache_ticks: int = 0
var _los_cache_target_id: int = -1
var _los_cache_ok: bool = false
var _obj_candidates: Array[CapturePoint] = []
var _scan_heroes: Array[HeroCharacter] = []
var _scan_dists: Array[float] = []


func setup(p_hero: HeroCharacter) -> void:
	bot_hero = p_hero
	name = "BotAI_%d" % p_hero.entity_id
	_retarget_timer = randf_range(0.0, 1.5)
	_strafe_dir = -1.0 if randf() < 0.5 else 1.0
	_aim_seed = float(p_hero.entity_id) * 1.731 + randf_range(0.0, TAU)
	_ray_query.collision_mask = 1
	_ray_query.hit_from_inside = true
	_ray_exclude.clear()
	if bot_hero != null:
		_ray_exclude.append(bot_hero.get_rid())
		_ray_query.exclude = _ray_exclude


func is_in_vision_cone(target: HeroCharacter) -> bool:
	if bot_hero == null or target == null:
		return false
	var b_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var t_pos: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var flat_to := Vector3(t_pos.x - b_pos.x, 0.0, t_pos.z - b_pos.z)
	var len_sq: float = flat_to.length_squared()
	if len_sq < 0.0001:
		return true
	var fwd := Vector3(-sin(bot_hero.aim_yaw), 0.0, -cos(bot_hero.aim_yaw))
	return (flat_to / sqrt(len_sq)).dot(fwd) >= FOV_MIN_COS


func has_line_of_sight(space_state: PhysicsDirectSpaceState3D, target: HeroCharacter) -> bool:
	if bot_hero == null or target == null or target.is_defeated or space_state == null:
		return false
	var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var target_pos: Vector3 = target.global_position if target.is_inside_tree() else target.position
	_ray_query.from = bot_pos + Vector3(0.0, LOS_EYE_HEIGHT, 0.0)
	_ray_query.to = target_pos + Vector3(0.0, LOS_TARGET_HEIGHT, 0.0)
	_ray_query.collision_mask = 1
	_ray_query.hit_from_inside = true
	var bot_rid: RID = bot_hero.get_rid()
	if _ray_exclude.size() != 1 or _ray_exclude[0] != bot_rid:
		_ray_exclude.resize(1)
		_ray_exclude[0] = bot_rid
		_ray_query.exclude = _ray_exclude
	var ray: Dictionary = space_state.intersect_ray(_ray_query)
	return ray.is_empty()


func compute_input(
	delta: float,
	capture_points: Array[CapturePoint] = [],
	heroes_by_id: Dictionary = {},
	vehicles: Array[VehicleBase] = []
) -> InputCmd:
	return step_ai(delta, capture_points, heroes_by_id, vehicles).duplicate_cmd()


func step_ai(delta: float, capture_points: Array[CapturePoint], heroes_by_id: Dictionary, vehicles: Array[VehicleBase]) -> InputCmd:
	var cmd: InputCmd = _reusable_cmd
	_ai_tick += 1
	cmd.tick = _ai_tick
	cmd.move_dir = Vector2.ZERO
	cmd.aim_yaw = 0.0
	cmd.aim_pitch = 0.0
	cmd.buttons = 0
	cmd.selected_weapon_slot = 0
	cmd.view_interp_tick_delta = 0

	if bot_hero == null or bot_hero.is_defeated:
		_engaged_target_id = -1
		_los_cache_target_id = -1
		_los_cache_ok = false
		_memory_timer = 0.0
		_reaction_timer = 0.0
		return cmd

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or _target_flag == null:
		_retarget_timer = randf_range(1.6, 3.0)
		_strafe_dir = -_strafe_dir
		_pick_objective(capture_points)

	var space_state: PhysicsDirectSpaceState3D = null
	if bot_hero.is_inside_tree() and bot_hero.get_world_3d() != null:
		space_state = bot_hero.get_world_3d().direct_space_state

	# 1. Look for nearest visible enemy hero (stagger full scan every 6th tick per bot; validate engaged target with 4-tick LOS cache)
	var target_enemy: HeroCharacter = null
	var do_full_scan: bool = (_ai_tick == 1) or (((_ai_tick + bot_hero.entity_id) % 6) == 0)
	if not do_full_scan and _engaged_target_id >= 0:
		var cand: HeroCharacter = heroes_by_id.get(_engaged_target_id) as HeroCharacter
		if cand != null and is_instance_valid(cand) and not cand.is_defeated and cand.team != bot_hero.team:
			var b_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
			var c_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
			var dist_sq: float = b_pos.distance_squared_to(c_pos)
			var detect_r: float = cand.status_effects.stealth_detection_radius if cand.status_effects != null else 10.0
			var visible_stealth: bool = (not cand.is_stealthed) or (dist_sq <= detect_r * detect_r) or ((cand.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0) or StatusEffectContainer.is_enemy_sensed_by_team(cand, bot_hero.team, heroes_by_id, bot_hero)
			if dist_sq <= MAX_DETECT_RANGE * MAX_DETECT_RANGE and visible_stealth and is_in_vision_cone(cand):
				var has_los: bool
				if _los_cache_target_id == _engaged_target_id and (_ai_tick - _los_cache_ticks) < 4:
					has_los = _los_cache_ok
				else:
					has_los = has_line_of_sight(space_state, cand)
					_los_cache_target_id = _engaged_target_id
					_los_cache_ticks = _ai_tick
					_los_cache_ok = has_los
				if has_los:
					target_enemy = cand
	elif do_full_scan:
		target_enemy = _find_nearest_visible_enemy(heroes_by_id, space_state)
		if target_enemy != null:
			_los_cache_target_id = target_enemy.entity_id
			_los_cache_ticks = _ai_tick
			_los_cache_ok = true
		else:
			_los_cache_target_id = -1
			_los_cache_ok = false
	var desired_pos: Vector3 = _target_flag.global_position if _target_flag != null else Vector3.ZERO

	# Heal or cleanse status effects if injured/burning/poisoned
	if bot_hero.hp < int(float(bot_hero.max_hp) * 0.5):
		cmd.set_button(InputCmd.BTN_WIDGET_1, true)
		if bot_hero.class_id == NetworkManager.CLASS_SOLDIER or bot_hero.class_id == NetworkManager.CLASS_GUNNER or bot_hero.class_id == NetworkManager.CLASS_DEMOLISHER:
			cmd.set_button(InputCmd.BTN_SKILL_1, true)
	if bot_hero.status_effects != null:
		if bot_hero.status_effects.is_burning():
			cmd.set_button(InputCmd.BTN_WIDGET_3, true)
		if bot_hero.status_effects.is_poisoned():
			cmd.set_button(InputCmd.BTN_WIDGET_4, true)

	var bot_pos_for_veh: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var near_enemy_veh: bool = false
	if bot_hero.class_id == NetworkManager.CLASS_DEMOLISHER:
		for v in vehicles:
			if v != null and not v.is_destroyed and v.team >= 0 and v.team != bot_hero.team:
				var v_pos: Vector3 = v.global_position if v.is_inside_tree() else v.position
				if v_pos.distance_to(bot_pos_for_veh) <= 45.0:
					near_enemy_veh = true
					break
	var eng_support_veh: VehicleBase = null
	var eng_support_dist: float = 14.0
	if bot_hero.class_id == NetworkManager.CLASS_ENGINEER and bot_hero.current_vehicle_id < 0:
		for v in vehicles:
			if v != null and is_instance_valid(v) and not v.is_destroyed and (v.team == bot_hero.team or v.team == -1):
				if v.hp < v.max_hp or not v.is_armored:
					var v_pos: Vector3 = v.global_position if v.is_inside_tree() else v.position
					var d_v: float = v_pos.distance_to(bot_pos_for_veh)
					if d_v <= eng_support_dist:
						eng_support_dist = d_v
						eng_support_veh = v

	if target_enemy != null:
		if target_enemy.entity_id != _engaged_target_id:
			_engaged_target_id = target_enemy.entity_id
			_reaction_timer = randf_range(0.24, 0.38)
			_burst_firing = true
			_burst_timer = randf_range(0.45, 0.85)

		_last_seen_pos = target_enemy.global_position
		_memory_timer = MEMORY_PURSUIT_SEC
		_reaction_timer = maxf(0.0, _reaction_timer - delta)

		if _reaction_timer <= 0.0:
			_burst_timer -= delta
			if _burst_timer <= 0.0:
				_burst_firing = not _burst_firing
				_burst_timer = randf_range(0.45, 0.85) if _burst_firing else randf_range(0.22, 0.42)

		var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
		var tgt_pos: Vector3 = target_enemy.global_position if target_enemy.is_inside_tree() else target_enemy.position
		var to_enemy: Vector3 = (tgt_pos + Vector3(0.0, 1.18, 0.0)) - (bot_pos + Vector3(0.0, LOS_EYE_HEIGHT, 0.0))
		var dist: float = to_enemy.length()

		var max_fire_dist: float = MAX_FIRE_RANGE
		var preferred_engage_dist: float = 18.0
		var arc_pitch_bias: float = 0.0
		if bot_hero.class_id == NetworkManager.CLASS_DEMOLISHER and not bot_hero.weapons.is_empty():
			var flam_w: WeaponBase = bot_hero.weapons[0] as WeaponBase
			var flam_arch: int = flam_w.archetype if flam_w != null else 0
			if dist < 14.0:
				cmd.selected_weapon_slot = 0
				max_fire_dist = 14.0
				preferred_engage_dist = 8.0
			elif dist < 40.0 and bot_hero.weapons.size() > 1:
				cmd.selected_weapon_slot = 1
				max_fire_dist = 40.0
				preferred_engage_dist = 12.0
				arc_pitch_bias = clampf(dist * 0.008, 0.0, 0.28)
			elif flam_arch == 2 and dist < 52.0:
				cmd.selected_weapon_slot = 0
				max_fire_dist = 52.0
				preferred_engage_dist = 14.0
			elif bot_hero.weapons.size() > 1:
				cmd.selected_weapon_slot = 1
				max_fire_dist = 40.0
				preferred_engage_dist = 12.0
		elif bot_hero.class_id == NetworkManager.CLASS_ENGINEER and not bot_hero.weapons.is_empty():
			if dist <= 3.5 and bot_hero.weapons.size() > 2:
				cmd.selected_weapon_slot = 2 # Welding Torch melee/burn
				max_fire_dist = 3.6
				preferred_engage_dist = 2.5
			elif dist <= 16.0 and bot_hero.weapons.size() > 1:
				cmd.selected_weapon_slot = 1 # Shotgun
				max_fire_dist = 24.0
				preferred_engage_dist = 10.0
			else:
				cmd.selected_weapon_slot = 0 # Dual Revolvers / Dual Pistols
				max_fire_dist = 55.0
				preferred_engage_dist = 18.0

		var flat_dir := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if flat_dir.length_squared() > 0.001:
			var base_yaw: float = atan2(-flat_dir.x, -flat_dir.z)
			var base_pitch: float = clampf(atan2(to_enemy.y, flat_dir.length()) + arc_pitch_bias, -1.1, 1.1)
			_aim_time += delta
			var speed_factor: float = clampf(target_enemy.velocity.length() / 10.0, 0.0, 1.0)
			var dist_factor: float = clampf(dist / 65.0, 0.0, 1.0)
			var err_amp: float = lerpf(0.032, 0.060, clampf(0.35 * dist_factor + 0.45 * speed_factor + 0.20, 0.0, 1.0))
			var sway_yaw: float = sin(_aim_time * 3.7 + _aim_seed) * err_amp * 0.72 + randf_range(-err_amp * 0.35, err_amp * 0.35)
			var sway_pitch: float = cos(_aim_time * 4.3 + _aim_seed * 1.7) * err_amp * 0.58 + randf_range(-err_amp * 0.28, err_amp * 0.28)
			cmd.aim_yaw = base_yaw + sway_yaw
			cmd.aim_pitch = clampf(base_pitch + sway_pitch, -1.1, 1.1)

		var can_fire: bool = (_reaction_timer <= 0.0) and _burst_firing and (dist < max_fire_dist)
		var tnt_rope_ready: bool = bot_hero.status_effects != null and bot_hero.status_effects.has_method("is_tnt_rope_active") and bool(bot_hero.status_effects.is_tnt_rope_active())
		if tnt_rope_ready:
			cmd.set_button(InputCmd.BTN_FIRE, (_ai_tick % 2) == 0)
		else:
			cmd.set_button(InputCmd.BTN_FIRE, can_fire)

		if bot_hero.class_id == NetworkManager.CLASS_DEMOLISHER:
			if can_fire and dist < 28.0 and (_ai_tick % 120) == 0:
				cmd.set_button(InputCmd.BTN_SKILL_1, true) # Riot Shield
			cmd.set_button(InputCmd.BTN_SKILL_2, (can_fire or dist < 24.0) and (_ai_tick % 90) == 0) # Haste
			cmd.set_button(InputCmd.BTN_SKILL_3, can_fire and dist < 22.0 and (_ai_tick % 240) == 0) # TNT Rope
			cmd.set_button(InputCmd.BTN_SKILL_4, can_fire and (_ai_tick % 150) == 0) # Shield Drain
			cmd.set_button(InputCmd.BTN_SKILL_5, near_enemy_veh or (can_fire and (_ai_tick % 300) == 0)) # Vehicle Buster
			if cmd.selected_weapon_slot == 1 and (_ai_tick % 36) == 0:
				cmd.set_button(InputCmd.BTN_AIM, true) # Detonate Trapper stickies when armed
		elif bot_hero.class_id == NetworkManager.CLASS_ENGINEER:
			_apply_engineer_skill_triggers(cmd, dist, can_fire, eng_support_veh, eng_support_dist, vehicles)
		else:
			cmd.set_button(InputCmd.BTN_SKILL_2, can_fire and (_ai_tick % 180) == 0)
			cmd.set_button(InputCmd.BTN_SKILL_3, can_fire and (_ai_tick % 240) == 0)
			cmd.set_button(InputCmd.BTN_SKILL_4, can_fire and (_ai_tick % 300) == 0)
			cmd.set_button(InputCmd.BTN_SKILL_5, can_fire and (_ai_tick % 360) == 0)
			cmd.set_button(InputCmd.BTN_SKILL_6, can_fire and bot_hero.class_id == NetworkManager.CLASS_COMMANDO and (_ai_tick % 420) == 0)

		if dist > preferred_engage_dist:
			cmd.move_dir = Vector2(_strafe_dir * 0.4, -0.9)
		else:
			cmd.move_dir = Vector2(_strafe_dir * 0.85, 0.15)
	else:
		# Target occluded or none visible: never fire or aim through walls!
		cmd.set_button(InputCmd.BTN_FIRE, false)
		if near_enemy_veh and bot_hero.class_id == NetworkManager.CLASS_DEMOLISHER:
			cmd.set_button(InputCmd.BTN_SKILL_5, true)
		var move_target: Vector3 = desired_pos
		if _engaged_target_id >= 0 and _memory_timer > 0.0:
			_memory_timer = maxf(0.0, _memory_timer - delta)
			move_target = _last_seen_pos
			if _memory_timer <= 0.0:
				_engaged_target_id = -1
				_reaction_timer = 0.0
		else:
			_engaged_target_id = -1
			_reaction_timer = 0.0

		var welding_ally_veh: bool = false
		if bot_hero.class_id == NetworkManager.CLASS_ENGINEER:
			var eng_sm_idle: EngineerSkills = bot_hero.skill_manager as EngineerSkills
			var eng_pulse: bool = ((_ai_tick % 12) == 0)
			if eng_pulse and _memory_timer > 0.0 and bot_hero.current_vehicle_id < 0 and bot_hero.hp < int(float(bot_hero.max_hp) * 0.45):
				if eng_sm_idle == null or eng_sm_idle.skill_cooldowns[4] <= 0.0:
					cmd.set_button(InputCmd.BTN_SKILL_5, true) # Invulnerability under fire
			if eng_support_veh != null:
				var v_pos: Vector3 = eng_support_veh.global_position if eng_support_veh.is_inside_tree() else eng_support_veh.position
				var is_building_idle: bool = eng_sm_idle != null and eng_sm_idle.is_building()
				if eng_pulse and not is_building_idle and eng_support_dist <= 7.0 and not eng_support_veh.is_armored:
					if eng_sm_idle == null or eng_sm_idle.skill_cooldowns[2] <= 0.0:
						cmd.set_button(InputCmd.BTN_SKILL_3, true) # Blindar Veículo
				if eng_support_dist <= 3.6 and eng_support_veh.hp < eng_support_veh.max_hp and bot_hero.weapons.size() > 2:
					welding_ally_veh = true
					cmd.selected_weapon_slot = 2 # Welding Torch
					cmd.set_button(InputCmd.BTN_FIRE, true)
					var to_v: Vector3 = (v_pos + Vector3(0.0, 0.8, 0.0)) - (bot_pos_for_veh + Vector3(0.0, LOS_EYE_HEIGHT, 0.0))
					var flat_v := Vector3(to_v.x, 0.0, to_v.z)
					if flat_v.length_squared() > 0.001:
						cmd.aim_yaw = atan2(-flat_v.x, -flat_v.z)
						cmd.aim_pitch = clampf(atan2(to_v.y, flat_v.length()), -1.1, 1.1)
					cmd.move_dir = Vector2.ZERO
				elif eng_support_veh.hp < eng_support_veh.max_hp or not eng_support_veh.is_armored:
					move_target = v_pos

		if not welding_ally_veh:
			var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
			var to_obj: Vector3 = move_target - bot_pos
			var flat := Vector3(to_obj.x, 0.0, to_obj.z)
			if flat.length() > 3.5:
				cmd.aim_yaw = atan2(-flat.x, -flat.z)
				cmd.aim_pitch = -0.05
				cmd.move_dir = Vector2(0.0, -1.0)
			else:
				cmd.move_dir = Vector2(_strafe_dir * 0.5, 0.0)

			# Periodically hop into an unoccupied nearby ground/water vehicle when far from flag
			if _engaged_target_id < 0 and bot_hero.current_vehicle_id < 0 and flat.length() > 55.0 and (_ai_tick % 120) == 0:
				for v in vehicles:
					if not v.is_destroyed and v.vehicle_type != VehicleBase.VehicleType.PLANE:
						if v.global_position.distance_to(bot_pos) <= 5.0:
							cmd.set_button(InputCmd.BTN_INTERACT, true)
							break

	# Parachute automatically if falling high
	if not bot_hero.is_on_floor() and bot_hero.velocity.y < -6.5 and not bot_hero.is_parachuting:
		cmd.set_button(InputCmd.BTN_JUMP, (_ai_tick % 2) == 0)

	return cmd


func _apply_engineer_skill_triggers(
	cmd: InputCmd,
	dist: float,
	can_fire: bool,
	eng_support_veh: VehicleBase,
	eng_support_dist: float,
	vehicles: Array[VehicleBase]
) -> void:
	# SkillManager.step_server() is edge-triggered: pulse on (_ai_tick % 12) == 0 so was_pressed resets between attempts.
	if (_ai_tick % 12) != 0:
		return
	var eng_sm: EngineerSkills = bot_hero.skill_manager as EngineerSkills
	if bot_hero.current_vehicle_id < 0 and bot_hero.hp < int(float(bot_hero.max_hp) * 0.45):
		if eng_sm == null or eng_sm.skill_cooldowns[4] <= 0.0:
			cmd.set_button(InputCmd.BTN_SKILL_5, true) # Skill 4: Invulnerability when low HP under fire
	var is_building_now: bool = eng_sm != null and eng_sm.is_building()
	if is_building_now:
		return
	var can_armor_veh: bool = false
	if bot_hero.current_vehicle_id >= 0:
		for v in vehicles:
			if v != null and is_instance_valid(v) and not v.is_destroyed and v.id == bot_hero.current_vehicle_id:
				can_armor_veh = not v.is_armored
				break
	elif eng_support_veh != null and eng_support_dist <= 7.0 and not eng_support_veh.is_armored:
		can_armor_veh = true
	if can_armor_veh and (eng_sm == null or eng_sm.skill_cooldowns[2] <= 0.0):
		cmd.set_button(InputCmd.BTN_SKILL_3, true) # Skill 2: Armor nearby/occupied vehicle
		return
	if bot_hero.current_vehicle_id >= 0:
		return
	var mortar_ready: bool = can_fire and (eng_sm == null or eng_sm.skill_cooldowns[3] <= 0.0)
	var turret_ready: bool = can_fire and dist < 35.0 and (eng_sm == null or (eng_sm.skill_cooldowns[1] <= 0.0 and eng_sm._active_turret == null))
	var trench_ready: bool = (can_fire or dist > 12.0) and (eng_sm == null or (eng_sm.skill_cooldowns[0] <= 0.0 and eng_sm._active_trench == null))
	var phase: int = (_ai_tick / 12) % 3
	for step_i in range(3):
		var idx: int = (phase + step_i) % 3
		if idx == 0 and mortar_ready:
			cmd.set_button(InputCmd.BTN_SKILL_4, true) # Skill 3: Bot Mortar strike
			return
		elif idx == 1 and turret_ready:
			cmd.set_button(InputCmd.BTN_SKILL_2, true) # Skill 1: Shielded MG Turret
			return
		elif idx == 2 and trench_ready:
			cmd.set_button(InputCmd.BTN_SKILL_1, true) # Skill 0: Trench
			return


func _pick_objective(capture_points: Array[CapturePoint]) -> void:
	if capture_points.is_empty():
		return
	_obj_candidates.clear()
	for cp in capture_points:
		if cp.owner_team != bot_hero.team:
			_obj_candidates.append(cp)
	if _obj_candidates.is_empty():
		_target_flag = capture_points[randi() % capture_points.size()]
	else:
		_target_flag = _obj_candidates[randi() % _obj_candidates.size()]


func _find_nearest_visible_enemy(heroes_by_id: Dictionary, space_state: PhysicsDirectSpaceState3D = null) -> HeroCharacter:
	var max_range_sq: float = MAX_DETECT_RANGE * MAX_DETECT_RANGE
	var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var best_cand: HeroCharacter = null
	var best_dist_sq: float = INF
	_scan_heroes.clear()
	_scan_dists.clear()
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated or h.team == bot_hero.team:
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var dist_sq: float = h_pos.distance_squared_to(bot_pos)
		if dist_sq > max_range_sq:
			continue
		if h.is_stealthed:
			var detect_r: float = h.status_effects.stealth_detection_radius if h.status_effects != null else 10.0
			var revealed: bool = (dist_sq <= detect_r * detect_r) or ((h.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0) or StatusEffectContainer.is_enemy_sensed_by_team(h, bot_hero.team, heroes_by_id, bot_hero)
			if not revealed:
				continue
		if not is_in_vision_cone(h):
			continue
		_scan_heroes.append(h)
		_scan_dists.append(dist_sq)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_cand = h

	if best_cand == null:
		return null
	if has_line_of_sight(space_state, best_cand):
		return best_cand
	if _scan_heroes.size() <= 1:
		return null

	# Only when closest candidate is occluded, inspect remaining candidates in ascending distance without allocating arrays
	var min_allowed: float = best_dist_sq
	for _attempt in range(_scan_heroes.size() - 1):
		var next_cand: HeroCharacter = null
		var next_dist_sq: float = INF
		for i in range(_scan_heroes.size()):
			var d_sq: float = _scan_dists[i]
			var cand_i: HeroCharacter = _scan_heroes[i]
			if cand_i == best_cand:
				continue
			if d_sq >= min_allowed and d_sq < next_dist_sq:
				next_dist_sq = d_sq
				next_cand = cand_i
		if next_cand == null:
			break
		if has_line_of_sight(space_state, next_cand):
			return next_cand
		best_cand = next_cand
		min_allowed = next_dist_sq
	return null
