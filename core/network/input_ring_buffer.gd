class_name InputRingBuffer
extends RefCounted

const CAPACITY: int = 128


class RingEntry extends RefCounted:
	var tick: int = -1
	var cmd: InputCmd = null
	var position: Vector3 = Vector3.ZERO
	var velocity: Vector3 = Vector3.ZERO
	var is_parachuting: bool = false
	var is_crouching: bool = false
	var is_grounded: bool = false
	var prev_jump_held: bool = false


var _slots: Array[RingEntry] = []


func _init() -> void:
	_slots.resize(CAPACITY)
	for i in range(CAPACITY):
		_slots[i] = RingEntry.new()


func push(
	tick: int,
	cmd: InputCmd,
	pos: Vector3,
	vel: Vector3,
	parachuting: bool,
	crouching: bool,
	grounded: bool,
	prev_jump: bool = false
) -> void:
	var idx: int = posmod(tick, CAPACITY)
	var entry: RingEntry = _slots[idx]
	entry.tick = tick
	entry.cmd = cmd.duplicate_cmd() if cmd != null else InputCmd.new()
	entry.position = pos
	entry.velocity = vel
	entry.is_parachuting = parachuting
	entry.is_crouching = crouching
	entry.is_grounded = grounded
	entry.prev_jump_held = prev_jump


func get_entry(tick: int) -> RingEntry:
	if tick < 0:
		return null
	var idx: int = posmod(tick, CAPACITY)
	var entry: RingEntry = _slots[idx]
	if entry.tick == tick:
		return entry
	return null


func get_entries_range(start_tick_inclusive: int, end_tick_inclusive: int) -> Array[RingEntry]:
	var out: Array[RingEntry] = []
	if end_tick_inclusive < start_tick_inclusive:
		return out
	for t in range(start_tick_inclusive, end_tick_inclusive + 1):
		var entry: RingEntry = get_entry(t)
		if entry != null:
			out.append(entry)
	return out


func clear() -> void:
	for i in range(CAPACITY):
		_slots[i].tick = -1
		_slots[i].cmd = null
