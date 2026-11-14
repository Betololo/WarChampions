class_name BotController
extends Node

## Server-side AI Brain for 12v12 War Champions bots:
## Captures flags, engages visible enemies (respecting Commando Stealth!),
## jumps/parachutes off cliffs, uses class skills & bandages, and rides/drives nearby vehicles.

var bot_hero: HeroCharacter = null
var _ai_tick: int = 0
var _retarget_timer: float = 0.0
var _target_flag: CapturePoint = null
var _strafe_dir: float = 1.0


func setup(p_hero: HeroCharacter) -> void:
	bot_hero = p_hero
	name = "BotAI_%d" % p_hero.entity_id
	_retarget_timer = randf_range(0.0, 1.5)
	_strafe_dir = -1.0 if randf() < 0.5 else 1.0


func step_ai(delta: float, capture_points: Array[CapturePoint], heroes_by_id: Dictionary, vehicles: Array[VehicleBase]) -> InputCmd:
	var cmd := InputCmd.new()
	_ai_tick += 1
	cmd.tick = _ai_tick

	if bot_hero == null or bot_hero.is_defeated:
		return cmd

	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or _target_flag == null:
		_retarget_timer = randf_range(1.6, 3.0)
		_strafe_dir = -_strafe_dir
		_pick_objective(capture_points)

	# 1. Look for nearest visible enemy hero (respects Stealth!)
	var target_enemy: HeroCharacter = _find_nearest_visible_enemy(heroes_by_id)
	var desired_pos: Vector3 = _target_flag.global_position if _target_flag != null else Vector3.ZERO

	# Heal if injured
	if bot_hero.hp < int(float(bot_hero.max_hp) * 0.5):
		cmd.set_button(InputCmd.BTN_WIDGET_1, true)
		if bot_hero.class_id == NetworkManager.CLASS_SOLDIER:
			cmd.set_button(InputCmd.BTN_SKILL_1, true)
		elif bot_hero.class_id == NetworkManager.CLASS_GUNNER:
			cmd.set_button(InputCmd.BTN_SKILL_1, true)

	if target_enemy != null:
		var to_enemy: Vector3 = (target_enemy.global_position + Vector3(0.0, 1.1, 0.0)) - (bot_hero.global_position + Vector3(0.0, 1.5, 0.0))
		var dist: float = to_enemy.length()
		var flat_dir := Vector3(to_enemy.x, 0.0, to_enemy.z)
		if flat_dir.length_squared() > 0.001:
			cmd.aim_yaw = atan2(-flat_dir.x, -flat_dir.z)
			cmd.aim_pitch = clampf(atan2(to_enemy.y, flat_dir.length()), -1.1, 1.1)

		cmd.set_button(InputCmd.BTN_FIRE, dist < 75.0)
		cmd.set_button(InputCmd.BTN_SKILL_2, (_ai_tick % 180) == 0)
		cmd.set_button(InputCmd.BTN_SKILL_3, (_ai_tick % 240) == 0)

		if dist > 18.0:
			cmd.move_dir = Vector2(_strafe_dir * 0.4, -0.9)
		else:
			cmd.move_dir = Vector2(_strafe_dir * 0.85, 0.15)
	else:
		var to_obj: Vector3 = desired_pos - bot_hero.global_position
		var flat := Vector3(to_obj.x, 0.0, to_obj.z)
		if flat.length() > 3.5:
			cmd.aim_yaw = atan2(-flat.x, -flat.z)
			cmd.aim_pitch = -0.05
			cmd.move_dir = Vector2(0.0, -1.0)
		else:
			cmd.move_dir = Vector2(_strafe_dir * 0.5, 0.0)

		# Periodically hop into an unoccupied nearby ground/water vehicle when far from flag
		if bot_hero.current_vehicle_id < 0 and flat.length() > 55.0 and (_ai_tick % 120) == 0:
			for v in vehicles:
				if not v.is_destroyed and v.vehicle_type != VehicleBase.VehicleType.PLANE:
					if v.global_position.distance_to(bot_hero.global_position) <= 5.0:
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


func _find_nearest_visible_enemy(heroes_by_id: Dictionary) -> HeroCharacter:
	var best: HeroCharacter = null
	var best_dist: float = 85.0
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h == null or h.is_defeated or h.team == bot_hero.team:
			continue
		var d: float = h.global_position.distance_to(bot_hero.global_position)
		if h.is_stealthed:
			var detect_r: float = h.status_effects.stealth_detection_radius if h.status_effects != null else 8.0
			if d > detect_r:
				continue
		if d < best_dist:
			best_dist = d
			best = h
	return best
