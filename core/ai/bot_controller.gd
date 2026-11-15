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


func setup(p_hero: HeroCharacter) -> void:
	bot_hero = p_hero
	name = "BotAI_%d" % p_hero.entity_id
	_retarget_timer = randf_range(0.0, 1.5)
	_strafe_dir = -1.0 if randf() < 0.5 else 1.0
	_aim_seed = float(p_hero.entity_id) * 1.731 + randf_range(0.0, TAU)


func has_line_of_sight(space_state: PhysicsDirectSpaceState3D, target: HeroCharacter) -> bool:
	if bot_hero == null or target == null or target.is_defeated or space_state == null:
		return false
	var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var target_pos: Vector3 = target.global_position if target.is_inside_tree() else target.position
	var eye_from: Vector3 = bot_pos + Vector3(0.0, LOS_EYE_HEIGHT, 0.0)
	var chest_to: Vector3 = target_pos + Vector3(0.0, LOS_TARGET_HEIGHT, 0.0)
	var query := PhysicsRayQueryParameters3D.create(eye_from, chest_to, 1)
	query.hit_from_inside = true
	query.exclude = [bot_hero.get_rid()]
	var ray: Dictionary = space_state.intersect_ray(query)
	return ray.is_empty()


func compute_input(
	delta: float,
	capture_points: Array[CapturePoint] = [],
	heroes_by_id: Dictionary = {},
	vehicles: Array[VehicleBase] = []
) -> InputCmd:
	return step_ai(delta, capture_points, heroes_by_id, vehicles)


func step_ai(delta: float, capture_points: Array[CapturePoint], heroes_by_id: Dictionary, vehicles: Array[VehicleBase]) -> InputCmd:
	var cmd := InputCmd.new()
	_ai_tick += 1
	cmd.tick = _ai_tick

	if bot_hero == null or bot_hero.is_defeated:
		_engaged_target_id = -1
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

	# 1. Look for nearest visible enemy hero (stagger full scan every 6th tick per bot; validate engaged target in between)
	var target_enemy: HeroCharacter = null
	var do_full_scan: bool = (_ai_tick == 1) or (((_ai_tick + bot_hero.entity_id) % 6) == 0)
	if not do_full_scan and _engaged_target_id >= 0:
		var cand: HeroCharacter = heroes_by_id.get(_engaged_target_id) as HeroCharacter
		if cand != null and is_instance_valid(cand) and not cand.is_defeated and cand.team != bot_hero.team:
			var b_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
			var c_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
			var dist_sq: float = b_pos.distance_squared_to(c_pos)
			var detect_r: float = cand.status_effects.stealth_detection_radius if cand.status_effects != null else 8.0
			var visible_stealth: bool = (not cand.is_stealthed) or (dist_sq <= detect_r * detect_r)
			if dist_sq <= MAX_DETECT_RANGE * MAX_DETECT_RANGE and visible_stealth:
				if has_line_of_sight(space_state, cand):
					target_enemy = cand
	elif do_full_scan:
		target_enemy = _find_nearest_visible_enemy(heroes_by_id, space_state)
	var desired_pos: Vector3 = _target_flag.global_position if _target_flag != null else Vector3.ZERO

	# Heal or cleanse status effects if injured/burning/poisoned
	if bot_hero.hp < int(float(bot_hero.max_hp) * 0.5):
		cmd.set_button(InputCmd.BTN_WIDGET_1, true)
		if bot_hero.class_id == NetworkManager.CLASS_SOLDIER or bot_hero.class_id == NetworkManager.CLASS_GUNNER:
			cmd.set_button(InputCmd.BTN_SKILL_1, true)
	if bot_hero.status_effects != null:
		if bot_hero.status_effects.is_burning():
			cmd.set_button(InputCmd.BTN_WIDGET_3, true)
		if bot_hero.status_effects.is_poisoned():
			cmd.set_button(InputCmd.BTN_WIDGET_4, true)

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
		var flat_dir := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if flat_dir.length_squared() > 0.001:
			var base_yaw: float = atan2(-flat_dir.x, -flat_dir.z)
			var base_pitch: float = clampf(atan2(to_enemy.y, flat_dir.length()), -1.1, 1.1)
			_aim_time += delta
			var speed_factor: float = clampf(target_enemy.velocity.length() / 10.0, 0.0, 1.0)
			var dist_factor: float = clampf(dist / 65.0, 0.0, 1.0)
			var err_amp: float = lerpf(0.032, 0.060, clampf(0.35 * dist_factor + 0.45 * speed_factor + 0.20, 0.0, 1.0))
			var sway_yaw: float = sin(_aim_time * 3.7 + _aim_seed) * err_amp * 0.72 + randf_range(-err_amp * 0.35, err_amp * 0.35)
			var sway_pitch: float = cos(_aim_time * 4.3 + _aim_seed * 1.7) * err_amp * 0.58 + randf_range(-err_amp * 0.28, err_amp * 0.28)
			cmd.aim_yaw = base_yaw + sway_yaw
			cmd.aim_pitch = clampf(base_pitch + sway_pitch, -1.1, 1.1)

		var can_fire: bool = (_reaction_timer <= 0.0) and _burst_firing and (dist < MAX_FIRE_RANGE)
		cmd.set_button(InputCmd.BTN_FIRE, can_fire)
		cmd.set_button(InputCmd.BTN_SKILL_2, can_fire and (_ai_tick % 180) == 0)
		cmd.set_button(InputCmd.BTN_SKILL_3, can_fire and (_ai_tick % 240) == 0)
		cmd.set_button(InputCmd.BTN_SKILL_4, can_fire and (_ai_tick % 300) == 0)
		cmd.set_button(InputCmd.BTN_SKILL_5, can_fire and (_ai_tick % 360) == 0)
		cmd.set_button(InputCmd.BTN_SKILL_6, can_fire and bot_hero.class_id == NetworkManager.CLASS_COMMANDO and (_ai_tick % 420) == 0)

		if dist > 18.0:
			cmd.move_dir = Vector2(_strafe_dir * 0.4, -0.9)
		else:
			cmd.move_dir = Vector2(_strafe_dir * 0.85, 0.15)
	else:
		# Target occluded or none visible: never fire or aim through walls!
		cmd.set_button(InputCmd.BTN_FIRE, false)
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


func _pick_objective(capture_points: Array[CapturePoint]) -> void:
	if capture_points.is_empty():
		return
	var candidates: Array[CapturePoint] = []
	for cp in capture_points:
		if cp.owner_team != bot_hero.team:
			candidates.append(cp)
	if candidates.is_empty():
		_target_flag = capture_points[randi() % capture_points.size()]
	else:
		_target_flag = candidates[randi() % candidates.size()]


func _find_nearest_visible_enemy(heroes_by_id: Dictionary, space_state: PhysicsDirectSpaceState3D = null) -> HeroCharacter:
	var max_range_sq: float = MAX_DETECT_RANGE * MAX_DETECT_RANGE
	var bot_pos: Vector3 = bot_hero.global_position if bot_hero.is_inside_tree() else bot_hero.position
	var candidates: Array = []
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated or h.team == bot_hero.team:
			continue
		var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var dist_sq: float = h_pos.distance_squared_to(bot_pos)
		if dist_sq > max_range_sq:
			continue
		if h.is_stealthed:
			var detect_r: float = h.status_effects.stealth_detection_radius if h.status_effects != null else 8.0
			if dist_sq > detect_r * detect_r:
				continue
		candidates.append([dist_sq, h])

	if candidates.size() > 1:
		candidates.sort_custom(func(a: Array, b: Array) -> bool:
			return float(a[0]) < float(b[0])
		)

	for entry in candidates:
		var cand: HeroCharacter = entry[1] as HeroCharacter
		if has_line_of_sight(space_state, cand):
			return cand
	return null
