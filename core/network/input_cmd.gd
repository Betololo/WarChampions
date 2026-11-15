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
const BTN_SKILL_6: int = 1 << 15
const BTN_WIDGET_1: int = 1 << 11
const BTN_WIDGET_2: int = 1 << 12
const BTN_WIDGET_3: int = 1 << 13
const BTN_WIDGET_4: int = 1 << 16
const BTN_EMOTE: int = 1 << 14

const DEFAULT_SKILL_HOTKEYS: Array[int] = [KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const DEFAULT_WIDGET_HOTKEYS: Array[int] = [KEY_Z, KEY_X, KEY_V, KEY_B]
const DEFAULT_HOTKEYS_PATH: String = "user://hotkeys.cfg"

static var skill_hotkeys: Array[int] = [KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
static var widget_hotkeys: Array[int] = [KEY_Z, KEY_X, KEY_V, KEY_B]


static func get_skill_key(slot_idx: int) -> int:
	if slot_idx >= 0 and slot_idx < skill_hotkeys.size():
		return skill_hotkeys[slot_idx]
	return KEY_NONE


static func set_skill_key(slot_idx: int, keycode: int) -> void:
	if slot_idx >= 0 and slot_idx < skill_hotkeys.size() and keycode != KEY_NONE:
		skill_hotkeys[slot_idx] = keycode


static func get_widget_key(slot_idx: int) -> int:
	if slot_idx >= 0 and slot_idx < widget_hotkeys.size():
		return widget_hotkeys[slot_idx]
	return KEY_NONE


static func set_widget_key(slot_idx: int, keycode: int) -> void:
	if slot_idx >= 0 and slot_idx < widget_hotkeys.size() and keycode != KEY_NONE:
		widget_hotkeys[slot_idx] = keycode


static func assign_unique_key(kind: String, slot_idx: int, keycode: int) -> void:
	if keycode == KEY_NONE:
		return
	var prev_key: int = KEY_NONE
	if kind == "skill":
		if slot_idx < 0 or slot_idx >= skill_hotkeys.size():
			return
		prev_key = skill_hotkeys[slot_idx]
	elif kind == "widget":
		if slot_idx < 0 or slot_idx >= widget_hotkeys.size():
			return
		prev_key = widget_hotkeys[slot_idx]
	else:
		return

	if prev_key == keycode:
		return

	for i in range(skill_hotkeys.size()):
		if not (kind == "skill" and i == slot_idx) and skill_hotkeys[i] == keycode:
			skill_hotkeys[i] = prev_key
	for j in range(widget_hotkeys.size()):
		if not (kind == "widget" and j == slot_idx) and widget_hotkeys[j] == keycode:
			widget_hotkeys[j] = prev_key

	if kind == "skill":
		skill_hotkeys[slot_idx] = keycode
	else:
		widget_hotkeys[slot_idx] = keycode


static func reset_default_hotkeys() -> void:
	skill_hotkeys = DEFAULT_SKILL_HOTKEYS.duplicate()
	widget_hotkeys = DEFAULT_WIDGET_HOTKEYS.duplicate()


static func save_hotkeys_to_config(path: String = DEFAULT_HOTKEYS_PATH) -> int:
	if path.is_empty():
		return OK
	var cfg := ConfigFile.new()
	for i in range(skill_hotkeys.size()):
		cfg.set_value("hotkeys", "skill_%d" % i, skill_hotkeys[i])
	for i in range(widget_hotkeys.size()):
		cfg.set_value("hotkeys", "widget_%d" % i, widget_hotkeys[i])
	return cfg.save(path)


static func load_hotkeys_from_config(path: String = DEFAULT_HOTKEYS_PATH) -> bool:
	if path.is_empty():
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	for i in range(skill_hotkeys.size()):
		var raw: Variant = cfg.get_value("hotkeys", "skill_%d" % i, skill_hotkeys[i])
		var k: int = int(raw)
		if k > 0 and k != KEY_ESCAPE:
			skill_hotkeys[i] = k
	for i in range(widget_hotkeys.size()):
		var raw: Variant = cfg.get_value("hotkeys", "widget_%d" % i, widget_hotkeys[i])
		var k: int = int(raw)
		if k > 0 and k != KEY_ESCAPE:
			widget_hotkeys[i] = k
	return true


static func is_key_assigned_anywhere(keycode: int) -> bool:
	return skill_hotkeys.has(keycode) or widget_hotkeys.has(keycode)


static func key_short_label(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "-"
	var s: String = OS.get_keycode_string(keycode)
	if s.begins_with("Kp "):
		s = s.substr(3)
	return s.to_upper()

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
