class_name ConquestManager
extends Node

## Classic Battlefield Heroes Conquest Rules supporting 12 vs 12 (24 players):
## - Both teams start with 50 Tickets and 4 Capture Points.
## - Golden Rule: Killing an enemy subtracts victim tickets ONLY if killer's team holds >= flags than victim's team.
## - Holding 3 or 4 flags activates ticket kill multipliers (2x / 3x) shown on HUD.

signal tickets_changed(royal_tickets: int, national_tickets: int)
signal match_ended(winning_team: int)

const STARTING_TICKETS: int = 50
const MAX_PLAYERS_PER_TEAM: int = 12

var royal_tickets: int = STARTING_TICKETS
var national_tickets: int = STARTING_TICKETS
var capture_points: Array[CapturePoint] = []
var match_over: bool = false
var winning_team: int = -1


func reset_match() -> void:
	royal_tickets = STARTING_TICKETS
	national_tickets = STARTING_TICKETS
	match_over = false
	winning_team = -1
	tickets_changed.emit(royal_tickets, national_tickets)


func register_capture_point(cp: CapturePoint) -> void:
	if not capture_points.has(cp):
		capture_points.append(cp)
		cp.flag_captured.connect(_on_flag_captured)


func get_flag_counts() -> Vector2i:
	var royal_flags: int = 0
	var national_flags: int = 0
	for cp in capture_points:
		if cp.owner_team == NetworkManager.TEAM_ROYAL:
			royal_flags += 1
		elif cp.owner_team == NetworkManager.TEAM_NATIONAL:
			national_flags += 1
	return Vector2i(royal_flags, national_flags)


func get_team_kill_multiplier(team: int) -> int:
	var counts: Vector2i = get_flag_counts()
	var my_flags: int = counts.x if team == NetworkManager.TEAM_ROYAL else counts.y
	var enemy_flags: int = counts.y if team == NetworkManager.TEAM_ROYAL else counts.x
	if my_flags < enemy_flags:
		return 0
	if my_flags >= 4:
		return 3
	if my_flags == 3:
		return 2
	return 1


func on_player_killed(victim_team: int, killer_team: int, killer_hero: HeroCharacter = null) -> int:
	if match_over or killer_team == victim_team or killer_team < 0:
		return 0

	if killer_hero != null and killer_hero.skill_manager != null and killer_hero.skill_manager.has_method("award_xp"):
		killer_hero.skill_manager.award_xp(100)

	var mult: int = get_team_kill_multiplier(killer_team)
	if mult <= 0:
		return 0

	if victim_team == NetworkManager.TEAM_ROYAL:
		royal_tickets = maxi(0, royal_tickets - mult)
	else:
		national_tickets = maxi(0, national_tickets - mult)

	tickets_changed.emit(royal_tickets, national_tickets)
	_check_victory()
	return mult


func _on_flag_captured(_point_idx: int, _new_owner: int, capturers: Array[HeroCharacter]) -> void:
	for h in capturers:
		if h != null and h.skill_manager != null and h.skill_manager.has_method("award_xp"):
			h.skill_manager.award_xp(65)


func _check_victory() -> void:
	if match_over:
		return
	if royal_tickets <= 0:
		match_over = true
		winning_team = NetworkManager.TEAM_NATIONAL
		match_ended.emit(winning_team)
	elif national_tickets <= 0:
		match_over = true
		winning_team = NetworkManager.TEAM_ROYAL
		match_ended.emit(winning_team)


func step_server(delta: float, heroes_by_id: Dictionary) -> void:
	if match_over:
		return
	for cp in capture_points:
		cp.step_server(delta, heroes_by_id)


func build_flags_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cp in capture_points:
		out.append(cp.build_snapshot_dict())
	return out


func apply_flags_snapshot(flags_arr: Array) -> void:
	for i in range(mini(flags_arr.size(), capture_points.size())):
		var f: Dictionary = flags_arr[i]
		capture_points[i].apply_snapshot_state(int(f.get("owner", -1)), int(f.get("capturing_team", -1)), float(f.get("progress", 0.0)))
