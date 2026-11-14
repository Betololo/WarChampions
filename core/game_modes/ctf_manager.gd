class_name CTFManager
extends Node

## Classic Capture the Flag mode between Royal and National bases.
signal score_changed(royal_score: int, national_score: int)
signal match_ended(winning_team: int)

const SCORE_TO_WIN: int = 3

var royal_flag_base: Vector3 = Vector3(-180.0, 3.0, 0.0)
var national_flag_base: Vector3 = Vector3(180.0, 3.0, 0.0)
var royal_carrier_id: int = -1 # National player carrying Royal flag
var national_carrier_id: int = -1 # Royal player carrying National flag
var royal_score: int = 0
var national_score: int = 0
var match_over: bool = false


func step_server(_delta: float, heroes_by_id: Dictionary) -> void:
	if match_over:
		return
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h == null or h.is_defeated:
			if royal_carrier_id == h.entity_id:
				royal_carrier_id = -1
			if national_carrier_id == h.entity_id:
				national_carrier_id = -1
			continue

		if h.team == NetworkManager.TEAM_ROYAL:
			if national_carrier_id == -1 and h.global_position.distance_to(national_flag_base) <= 4.0:
				national_carrier_id = h.entity_id
			elif national_carrier_id == h.entity_id and h.global_position.distance_to(royal_flag_base) <= 4.0:
				national_carrier_id = -1
				royal_score += 1
				score_changed.emit(royal_score, national_score)
		else:
			if royal_carrier_id == -1 and h.global_position.distance_to(royal_flag_base) <= 4.0:
				royal_carrier_id = h.entity_id
			elif royal_carrier_id == h.entity_id and h.global_position.distance_to(national_flag_base) <= 4.0:
				royal_carrier_id = -1
				national_score += 1
				score_changed.emit(royal_score, national_score)

	if royal_score >= SCORE_TO_WIN:
		match_over = true
		match_ended.emit(NetworkManager.TEAM_ROYAL)
	elif national_score >= SCORE_TO_WIN:
		match_over = true
		match_ended.emit(NetworkManager.TEAM_NATIONAL)
