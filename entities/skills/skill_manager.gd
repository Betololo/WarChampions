class_name SkillManager
extends Node

## Manages RPG Levels (1..30), Hero Points (earned every 2 levels),
## 5 Class Skills (ranks 1..5), and 3 Widgets (Bandages, Wrench, Fireproof/Antidote).

signal progression_changed(level: int, xp: int, xp_next: int, hero_points: int)
signal skill_activated(slot_idx: int, cooldown: float)
signal widget_activated(widget_idx: int, cooldown: float)

const MAX_LEVEL: int = 30
const MAX_SKILL_RANK: int = 5

var owner_hero: HeroCharacter = null

## RPG Progression
var level: int = 1
var xp: int = 0
var hero_points: int = 2 # Starting Hero Points to customize initial build
var skill_ranks: Array[int] = [1, 1, 1, 0, 0] # Ranks 0..5 for skills 1..5
var skill_cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var skill_max_cooldowns: Array[float] = [14.0, 16.0, 18.0, 14.0, 20.0]
var skill_names: Array[String] = ["Skill 1", "Skill 2", "Skill 3", "Skill 4", "Skill 5"]

## 3 Consumable Widgets: 0 = Bandages, 1 = Wrench, 2 = Fireproof Underwear / Antidote
var widget_cooldowns: Array[float] = [0.0, 0.0, 0.0]
var widget_max_cooldowns: Array[float] = [12.0, 8.0, 14.0]
var widget_names: Array[String] = ["Bandages", "Wrench", "Antidote/Underwear"]

var _prev_skill_btns: int = 0
var _prev_widget_btns: int = 0


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
		if level % 2 == 0:
			hero_points += 1
	progression_changed.emit(level, xp, get_xp_for_next_level(), hero_points)


func upgrade_skill(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= 5:
		return false
	if hero_points <= 0 or skill_ranks[slot_idx] >= MAX_SKILL_RANK:
		return false
	hero_points -= 1
	skill_ranks[slot_idx] += 1
	progression_changed.emit(level, xp, get_xp_for_next_level(), hero_points)
	return true


func step_server(delta: float, cmd: InputCmd, context: Dictionary) -> void:
	for i in range(5):
		if skill_cooldowns[i] > 0.0:
			skill_cooldowns[i] = maxf(0.0, skill_cooldowns[i] - delta)
	for j in range(3):
		if widget_cooldowns[j] > 0.0:
			widget_cooldowns[j] = maxf(0.0, widget_cooldowns[j] - delta)

	if owner_hero == null or owner_hero.is_defeated:
		return

	var skill_flags: Array[int] = [
		InputCmd.BTN_SKILL_1,
		InputCmd.BTN_SKILL_2,
		InputCmd.BTN_SKILL_3,
		InputCmd.BTN_SKILL_4,
		InputCmd.BTN_SKILL_5,
	]
	for i in range(5):
		var pressed: bool = cmd.has_button(skill_flags[i])
		var was_pressed: bool = (_prev_skill_btns & skill_flags[i]) != 0
		if pressed and not was_pressed:
			try_activate_skill(i, cmd, context)
	_prev_skill_btns = cmd.buttons & (InputCmd.BTN_SKILL_1 | InputCmd.BTN_SKILL_2 | InputCmd.BTN_SKILL_3 | InputCmd.BTN_SKILL_4 | InputCmd.BTN_SKILL_5)

	var widget_flags: Array[int] = [InputCmd.BTN_WIDGET_1, InputCmd.BTN_WIDGET_2, InputCmd.BTN_WIDGET_3]
	for j in range(3):
		var pressed_w: bool = cmd.has_button(widget_flags[j])
		var was_pressed_w: bool = (_prev_widget_btns & widget_flags[j]) != 0
		if pressed_w and not was_pressed_w:
			try_activate_widget(j, context)
	_prev_widget_btns = cmd.buttons & (InputCmd.BTN_WIDGET_1 | InputCmd.BTN_WIDGET_2 | InputCmd.BTN_WIDGET_3)


func try_activate_skill(slot_idx: int, cmd: InputCmd, context: Dictionary) -> bool:
	if slot_idx < 0 or slot_idx >= 5:
		return false
	var rank: int = skill_ranks[slot_idx]
	if rank <= 0 or skill_cooldowns[slot_idx] > 0.0:
		return false
	if _execute_class_skill(slot_idx, rank, cmd, context):
		skill_cooldowns[slot_idx] = skill_max_cooldowns[slot_idx]
		skill_activated.emit(slot_idx, skill_cooldowns[slot_idx])
		NetworkManager.broadcast_game_event("skill_vfx", {
			"hero_id": owner_hero.entity_id,
			"slot": slot_idx,
			"class_id": owner_hero.class_id,
			"pos": owner_hero.global_position,
		})
		return true
	return false


func try_activate_widget(widget_idx: int, context: Dictionary) -> bool:
	if widget_idx < 0 or widget_idx >= 3 or owner_hero == null:
		return false
	if widget_cooldowns[widget_idx] > 0.0:
		return false

	match widget_idx:
		0: # Bandages: Instant HP heal
			owner_hero.heal_server(40)
		1: # Wrench: Repair nearest allied vehicle (including vehicle hero is riding!)
			var repaired: bool = _repair_nearest_vehicle(context)
			if not repaired:
				return false
		2: # Fireproof Underwear / Antidote: Cleanse burn & poison immediately
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("cleanse_burn_and_poison"):
				owner_hero.status_effects.cleanse_burn_and_poison()

	widget_cooldowns[widget_idx] = widget_max_cooldowns[widget_idx]
	widget_activated.emit(widget_idx, widget_cooldowns[widget_idx])
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
