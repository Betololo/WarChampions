class_name SkillManager
extends Node

## Manages Combat Mastery Levels (5..30), Max-Rank Class Skills (rank 5 unlocked immediately),
## and 4 Widgets (Bandages, Wrench, Fireproof, Antidote).

signal progression_changed(level: int, xp: int, xp_next: int, hero_points: int)
signal skill_activated(slot_idx: int, cooldown: float)
signal widget_activated(widget_idx: int, cooldown: float)

const MAX_LEVEL: int = 30
const MAX_SKILL_RANK: int = 5
const SKILL_BUTTON_FLAGS: Array[int] = [
	InputCmd.BTN_SKILL_1,
	InputCmd.BTN_SKILL_2,
	InputCmd.BTN_SKILL_3,
	InputCmd.BTN_SKILL_4,
	InputCmd.BTN_SKILL_5,
	InputCmd.BTN_SKILL_6,
]
const WIDGET_BUTTON_FLAGS: Array[int] = [
	InputCmd.BTN_WIDGET_1,
	InputCmd.BTN_WIDGET_2,
	InputCmd.BTN_WIDGET_3,
	InputCmd.BTN_WIDGET_4,
]

var owner_hero: HeroCharacter = null

## RPG Progression (all skills unlocked at max rank 5 immediately; no hero point gating)
var level: int = 5
var xp: int = 0
var hero_points: int = 0
var skill_ranks: Array[int] = [5, 5, 5, 5, 5] # Ranks 0..5 (all start at MAX_SKILL_RANK)
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var skill_max_cooldowns: Array[float] = [14.0, 16.0, 18.0, 14.0, 20.0]
var skill_names: Array[String] = ["Skill 1", "Skill 2", "Skill 3", "Skill 4", "Skill 5"]

## 4 Consumable Widgets: 0 = Bandages, 1 = Wrench, 2 = Fireproof Underwear, 3 = Antidote
var widget_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0]
var widget_max_cooldowns: Array[float] = [15.0, 8.0, 14.0, 14.0]
var widget_names: Array[String] = ["Bandages", "Wrench", "Fireproof", "Antidote"]

var _prev_skill_btns: int = 0
var _prev_widget_btns: int = 0
var _last_aoe_radius: float = 0.0
var _last_aoe_origin: Vector3 = Vector3.ZERO
var _last_aoe_target_ids: Array[int] = []


func _ready() -> void:
	if get_parent() is HeroCharacter:
		owner_hero = get_parent() as HeroCharacter


func get_xp_for_next_level() -> int:
	return 100 + (level - 1) * 65


func award_xp(amount: int) -> void:
	if amount <= 0 or level >= MAX_LEVEL:
		return
	xp += amount
	while level < MAX_LEVEL and xp >= get_xp_for_next_level():
		xp -= get_xp_for_next_level()
		level += 1
	progression_changed.emit(level, xp, get_xp_for_next_level(), hero_points)


func upgrade_skill(_slot_idx: int) -> bool:
	return false


func start_stealth_exit_cooldown() -> void:
	if skill_cooldowns.size() > 0:
		skill_cooldowns[0] = skill_max_cooldowns[0]
		skill_activated.emit(0, skill_cooldowns[0])


func step_server(delta: float, cmd: InputCmd, context: Dictionary) -> void:
	var n_skills: int = mini(skill_ranks.size(), SKILL_BUTTON_FLAGS.size())
	for i in range(n_skills):
		if skill_cooldowns[i] > 0.0:
			skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
	for j in range(4):
		if widget_cooldowns[j] > 0.0:
			widget_cooldowns[j] = maxf(0.0, widget_cooldowns[j] - delta)

	if owner_hero == null or owner_hero.is_defeated:
		return

	var next_skill_btns: int = 0
	for i in range(n_skills):
		var flag: int = SKILL_BUTTON_FLAGS[i]
		var pressed: bool = cmd.has_button(flag)
		var was_pressed: bool = (_prev_skill_btns & flag) != 0
		if pressed:
			next_skill_btns |= flag
			if not was_pressed:
				try_activate_skill(i, cmd, context)
	_prev_skill_btns = next_skill_btns

	var next_widget_btns: int = 0
	for j in range(4):
		var w_flag: int = WIDGET_BUTTON_FLAGS[j]
		var pressed_w: bool = cmd.has_button(w_flag)
		var was_pressed_w: bool = (_prev_widget_btns & w_flag) != 0
		if pressed_w:
			next_widget_btns |= w_flag
			if not was_pressed_w:
				try_activate_widget(j, context)
	_prev_widget_btns = next_widget_btns


func _defers_cooldown_until_exit(_slot_idx: int) -> bool:
	return false


func _record_aoe_effect(radius: float, target_ids: Array[int], origin: Vector3 = Vector3.ZERO) -> void:
	_last_aoe_radius = radius
	_last_aoe_origin = origin
	_last_aoe_target_ids = target_ids.duplicate()


func try_activate_skill(slot_idx: int, cmd: InputCmd, context: Dictionary) -> bool:
	if slot_idx < 0 or slot_idx >= skill_ranks.size():
		return false
	var rank: int = skill_ranks[slot_idx]
	if rank <= 0 or skill_cooldowns[slot_idx] > 0.0:
		return false
	_last_aoe_radius = 0.0
	_last_aoe_origin = Vector3.ZERO
	_last_aoe_target_ids.clear()
	if _execute_class_skill(slot_idx, rank, cmd, context):
		var cd_val: float = 0.0 if _defers_cooldown_until_exit(slot_idx) else skill_max_cooldowns[slot_idx]
		skill_cooldowns[slot_idx] = cd_val
		skill_activated.emit(slot_idx, cd_val)
		var vfx_payload: Dictionary = {
			"hero_id": owner_hero.entity_id,
			"slot": slot_idx,
			"class_id": owner_hero.class_id,
			"skill_name": skill_names[slot_idx] if slot_idx < skill_names.size() else "Skill",
			"pos": owner_hero.global_position,
		}
		if _last_aoe_radius > 0.0:
			vfx_payload["aoe_radius"] = _last_aoe_radius
			vfx_payload["aoe_origin"] = _last_aoe_origin
			vfx_payload["affected_ids"] = _last_aoe_target_ids.duplicate()
		NetworkManager.broadcast_game_event("skill_vfx", vfx_payload)
		return true
	return false


func try_activate_widget(widget_idx: int, context: Dictionary) -> bool:
	if widget_idx < 0 or widget_idx >= 4 or owner_hero == null:
		return false
	if widget_cooldowns[widget_idx] > 0.0:
		return false

	match widget_idx:
		0: # Bandages: 2.0s channel healing +40 HP (interrupted if victim takes direct damage)
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("start_bandage_channel"):
				owner_hero.status_effects.start_bandage_channel(40, 2.0)
			else:
				owner_hero.heal_server(40)
		1: # Wrench: Repair nearest allied vehicle (including vehicle hero is riding!)
			var repaired: bool = _repair_nearest_vehicle(context)
			if not repaired:
				return false
		2: # Fireproof Underwear: Cleanse burn + 2.0s fire immunity
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("cleanse_burn_and_grant_immunity"):
				owner_hero.status_effects.cleanse_burn_and_grant_immunity(2.0)
		3: # Antidote: Cleanse poison + remove green screen tint immediately
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("cleanse_poison"):
				owner_hero.status_effects.cleanse_poison()

	widget_cooldowns[widget_idx] = widget_max_cooldowns[widget_idx]
	widget_activated.emit(widget_idx, widget_cooldowns[widget_idx])
	NetworkManager.broadcast_game_event("skill_vfx", {
		"hero_id": owner_hero.entity_id,
		"slot": 100 + widget_idx,
		"class_id": owner_hero.class_id,
		"skill_name": widget_names[widget_idx],
		"pos": owner_hero.global_position,
	})
	return true


func _repair_nearest_vehicle(context: Dictionary) -> bool:
	var vehicles: Array = context.get("vehicles", [])
	if vehicles.is_empty() and owner_hero.is_inside_tree():
		vehicles = owner_hero.get_tree().get_nodes_in_group("vehicles")
	var best_v: Node = null
	var best_dist: float = 8.0
	for v in vehicles:
		if not (v is Node3D) or not v.has_method("repair_server"):
			continue
		var v_team: int = int(v.get("team"))
		if v_team != -1 and v_team != owner_hero.team:
			continue
		if int(v.get("id")) == owner_hero.current_vehicle_id:
			best_v = v
			break
		var d: float = (v as Node3D).global_position.distance_to(owner_hero.global_position)
		if d <= best_dist:
			best_dist = d
			best_v = v
	if best_v != null:
		best_v.repair_server(110)
		return true
	return false


## Overridden in SoldierSkills, GunnerSkills, CommandoSkills
func _execute_class_skill(_slot_idx: int, _rank: int, _cmd: InputCmd, _context: Dictionary) -> bool:
	return false
