class_name StatusEffectContainer
extends Node

## Server-authoritative status effect processor (DoTs, Shields, Speed Modifiers, Stealth, Buffs).
var owner_hero: HeroCharacter = null

## DoTs
var burn_timer: float = 0.0
var burn_dps: float = 0.0
var burn_attacker_id: int = -1
var _burn_tick_accum: float = 0.0

var poison_timer: float = 0.0
var poison_dps: float = 0.0
var poison_attacker_id: int = -1
var _poison_tick_accum: float = 0.0

## Buffs
var shield_timer: float = 0.0
var speed_boost_timer: float = 0.0
var speed_boost_mult: float = 1.0
var slow_timer: float = 0.0
var slow_mult: float = 1.0

var burning_bullets_timer: float = 0.0
var burning_bullets_dps: float = 8.0

var poisoned_blade_timer: float = 0.0
var poisoned_blade_dps: float = 12.0

var frenzy_timer: float = 0.0
var frenzy_heal_amount: int = 8

var eat_grenades_timer: float = 0.0

var piercing_timer: float = 0.0
var piercing_mult: float = 1.5

var stealth_timer: float = 0.0
var stealth_detection_radius: float = 12.0

var sixth_sense_timer: float = 0.0
var sixth_sense_radius: float = 45.0


func _ready() -> void:
	if get_parent() is HeroCharacter:
		owner_hero = get_parent() as HeroCharacter


func _physics_process(delta: float) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		clear_all()
		return

	if not (multiplayer.is_server() or multiplayer.multiplayer_peer == null):
		return

	# Process Burn DoT (1 tick/sec)
	if burn_timer > 0.0:
		burn_timer -= delta
		_burn_tick_accum += delta
		if _burn_tick_accum >= 0.5:
			_burn_tick_accum -= 0.5
			var dmg: int = maxi(1, int(roundf(burn_dps * 0.5)))
			owner_hero.apply_damage_server(dmg, burn_attacker_id, false)
			break_stealth()
		if burn_timer <= 0.0:
			burn_timer = 0.0
			_burn_tick_accum = 0.0

	# Process Poison DoT (1 tick/0.5s)
	if poison_timer > 0.0:
		poison_timer -= delta
		_poison_tick_accum += delta
		if _poison_tick_accum >= 0.5:
			_poison_tick_accum -= 0.5
			var pdmg: int = maxi(1, int(roundf(poison_dps * 0.5)))
			owner_hero.apply_damage_server(pdmg, poison_attacker_id, false)
			break_stealth()
		if poison_timer <= 0.0:
			poison_timer = 0.0
			_poison_tick_accum = 0.0

	# Shield expiry
	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_timer = 0.0
			owner_hero.shield = 0
			owner_hero.stats_changed.emit()

	# Speed modifiers
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_timer = 0.0
			speed_boost_mult = 1.0
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_mult = 1.0

	owner_hero.speed_multiplier = speed_boost_mult * slow_mult

	# Combat buffs
	burning_bullets_timer = maxf(0.0, burning_bullets_timer - delta)
	poisoned_blade_timer = maxf(0.0, poisoned_blade_timer - delta)
	frenzy_timer = maxf(0.0, frenzy_timer - delta)
	eat_grenades_timer = maxf(0.0, eat_grenades_timer - delta)
	piercing_timer = maxf(0.0, piercing_timer - delta)
	sixth_sense_timer = maxf(0.0, sixth_sense_timer - delta)

	if stealth_timer > 0.0:
		stealth_timer -= delta
		if stealth_timer <= 0.0:
			stealth_timer = 0.0
			owner_hero.is_stealthed = false

	_sync_flags()


func _sync_flags() -> void:
	if owner_hero == null:
		return
	var f: int = owner_hero.active_flags
	f &= ~(NetSerializer.SNAP_BURNING | NetSerializer.SNAP_POISONED | NetSerializer.SNAP_SPEED_BOOST | NetSerializer.SNAP_SIXTH_SENSE | NetSerializer.SNAP_EAT_GRENADES | NetSerializer.SNAP_STEALTHED | NetSerializer.SNAP_SHIELDED)
	if burn_timer > 0.0:
		f |= NetSerializer.SNAP_BURNING
	if poison_timer > 0.0:
		f |= NetSerializer.SNAP_POISONED
	if speed_boost_timer > 0.0:
		f |= NetSerializer.SNAP_SPEED_BOOST
	if sixth_sense_timer > 0.0:
		f |= NetSerializer.SNAP_SIXTH_SENSE
	if eat_grenades_timer > 0.0:
		f |= NetSerializer.SNAP_EAT_GRENADES
	if owner_hero.is_stealthed:
		f |= NetSerializer.SNAP_STEALTHED
	if owner_hero.shield > 0:
		f |= NetSerializer.SNAP_SHIELDED
	owner_hero.active_flags = f


func apply_burn(attacker_id: int, dps: float, duration: float) -> void:
	burn_attacker_id = attacker_id
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)
	break_stealth()


func apply_poison(attacker_id: int, dps: float, duration: float) -> void:
	poison_attacker_id = attacker_id
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration)
	break_stealth()


func cleanse_burn_and_poison() -> void:
	burn_timer = 0.0
	burn_dps = 0.0
	poison_timer = 0.0
	poison_dps = 0.0
	_sync_flags()


func apply_shield(amount: int, duration: float) -> void:
	if owner_hero == null:
		return
	owner_hero.shield = maxi(owner_hero.shield, amount)
	shield_timer = maxf(shield_timer, duration)
	owner_hero.stats_changed.emit()


func apply_speed_boost(mult: float, duration: float) -> void:
	speed_boost_mult = maxf(speed_boost_mult, mult)
	speed_boost_timer = maxf(speed_boost_timer, duration)


func apply_concussion_slow(mult: float, duration: float) -> void:
	slow_mult = minf(slow_mult, mult)
	slow_timer = maxf(slow_timer, duration)


func activate_burning_bullets(dps: float, duration: float) -> void:
	burning_bullets_dps = dps
	burning_bullets_timer = duration


func activate_poisoned_blade(dps: float, duration: float) -> void:
	poisoned_blade_dps = dps
	poisoned_blade_timer = duration


func activate_frenzy_fire(heal_amount: int, duration: float) -> void:
	frenzy_heal_amount = heal_amount
	frenzy_timer = duration


func activate_eat_grenades(duration: float) -> void:
	eat_grenades_timer = duration


func activate_piercing_shot(mult: float, duration: float) -> void:
	piercing_mult = mult
	piercing_timer = duration


func activate_stealth(detection_radius: float, duration: float) -> void:
	stealth_detection_radius = detection_radius
	stealth_timer = duration
	if owner_hero != null:
		owner_hero.is_stealthed = true


func break_stealth() -> void:
	stealth_timer = 0.0
	if owner_hero != null:
		owner_hero.is_stealthed = false


func activate_sixth_sense(radius: float, duration: float) -> void:
	sixth_sense_radius = maxf(sixth_sense_radius, radius)
	sixth_sense_timer = maxf(sixth_sense_timer, duration)


func has_burning_bullets() -> bool:
	return burning_bullets_timer > 0.0


func get_burning_dps() -> float:
	return burning_bullets_dps


func has_poisoned_blade() -> bool:
	return poisoned_blade_timer > 0.0


func get_poison_dps() -> float:
	return poisoned_blade_dps


func has_frenzy_fire() -> bool:
	return frenzy_timer > 0.0


func get_frenzy_heal_amount() -> int:
	return frenzy_heal_amount


func can_eat_grenades() -> bool:
	return eat_grenades_timer > 0.0


func get_piercing_shot_mult() -> float:
	return piercing_mult if piercing_timer > 0.0 else 1.0


func clear_all() -> void:
	burn_timer = 0.0
	poison_timer = 0.0
	shield_timer = 0.0
	speed_boost_timer = 0.0
	speed_boost_mult = 1.0
	slow_timer = 0.0
	slow_mult = 1.0
	burning_bullets_timer = 0.0
	poisoned_blade_timer = 0.0
	frenzy_timer = 0.0
	eat_grenades_timer = 0.0
	piercing_timer = 0.0
	stealth_timer = 0.0
	sixth_sense_timer = 0.0
	if owner_hero != null:
		owner_hero.is_stealthed = false
		owner_hero.shield = 0
		owner_hero.speed_multiplier = 1.0
