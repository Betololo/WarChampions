class_name HeroOfTheHillManager
extends Node

## Hero of the Hill (Rocket): Both teams compete to control a single central V2 Rocket hill.
signal hill_progress_changed(royal_sec: float, national_sec: float)
signal match_ended(winning_team: int)

const GOAL_SECONDS: float = 120.0
const HILL_RADIUS: float = 14.0

var hill_position: Vector3 = Vector3.ZERO
var royal_time: float = 0.0
var national_time: float = 0.0
var match_over: bool = false


func step_server(delta: float, heroes_by_id: Dictionary) -> void:
	if match_over:
		return
	var royal_count: int = 0
	var national_count: int = 0
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h != null and not h.is_defeated and h.global_position.distance_to(hill_position) <= HILL_RADIUS:
			if h.team == NetworkManager.TEAM_ROYAL:
				royal_count += 1
			else:
				national_count += 1

	if royal_count > national_count:
		royal_time = minf(GOAL_SECONDS, royal_time + delta)
	elif national_count > royal_count:
		national_time = minf(GOAL_SECONDS, national_time + delta)

	hill_progress_changed.emit(royal_time, national_time)
	if royal_time >= GOAL_SECONDS:
		match_over = true
		match_ended.emit(NetworkManager.TEAM_ROYAL)
	elif national_time >= GOAL_SECONDS:
		match_over = true
		match_ended.emit(NetworkManager.TEAM_NATIONAL)
