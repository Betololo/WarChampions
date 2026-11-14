class_name InputCmd
extends RefCounted

## Bitmask flags for player input buttons packed into 16 bits.
const BTN_JUMP: int = 1 << 0
const BTN_CROUCH: int = 1 << 1
const BTN_FIRE: int = 1 << 2
const BTN_AIM: int = 1 << 3
const BTN_RELOAD: int = 1 << 4
const BTN_INTERACT: int = 1 << 5
const BTN_SKILL_1: int = 1 << 6
const BTN_SKILL_2: int = 1 << 7
const BTN_SKILL_3: int = 1 << 8
const BTN_SKILL_4: int = 1 << 9
const BTN_SKILL_5: int = 1 << 10
const BTN_WIDGET_1: int = 1 << 11
const BTN_WIDGET_2: int = 1 << 12
const BTN_WIDGET_3: int = 1 << 13
const BTN_EMOTE: int = 1 << 14

var tick: int = 0
var move_dir: Vector2 = Vector2.ZERO
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var buttons: int = 0
var selected_weapon_slot: int = 0
var view_interp_tick_delta: int = 0


func has_button(flag: int) -> bool:
	return (buttons & flag) != 0


func set_button(flag: int, pressed: bool) -> void:
	if pressed:
		buttons |= flag
	else:
		buttons &= ~flag


func duplicate_cmd() -> InputCmd:
	var copy := InputCmd.new()
	copy.tick = tick
	copy.move_dir = move_dir
	copy.aim_yaw = aim_yaw
	copy.aim_pitch = aim_pitch
	copy.buttons = buttons
	copy.selected_weapon_slot = selected_weapon_slot
	copy.view_interp_tick_delta = view_interp_tick_delta
	return copy
