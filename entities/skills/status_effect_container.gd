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
var hero_shield_timer: float = 0.0
var speed_boost_timer: float = 0.0
var leg_it_timer: float = 0.0
var elixir_timer: float = 0.0
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
var stealth_infinite: bool = false
var stealth_detection_radius: float = 10.0

var sixth_sense_timer: float = 0.0
var sixth_sense_radius: float = 55.0

const SIXTH_SENSE_RADIUS: float = 55.0
const MARK_TARGET_MAX_RANGE: float = 2500.0
const MARK_CROSSHAIR_MAX_ANGLE_DEG: float = 2.8

static var _sixth_sense_casters_royal: Array[HeroCharacter] = []
static var _sixth_sense_casters_national: Array[HeroCharacter] = []
static var _sixth_sense_cache_active: bool = false
static var _sixth_sense_cache_dict: Dictionary = {}
static var _sixth_sense_cache_proc_frame: int = -1
static var _sixth_sense_cache_phys_frame: int = -1

var hot_timer: float = 0.0
var hot_tick_accum: float = 0.0
var hot_heal_per_tick: int = 4

var bandage_channel_timer: float = 0.0
var bandage_heal_amount: int = 40

var fire_immunity_timer: float = 0.0

var haste_timer: float = 0.0
var haste_fire_mult: float = 1.0
var haste_reload_mult: float = 1.0

var permanent_vest_shield: int = 0
var carried_shield_active: bool = false
var carried_shield_hp: int = 550
var carried_shield_max_hp: int = 550
var carried_shield_swing_timer: float = 0.0

var vehicle_triple_dmg_timer: float = 0.0

var tnt_rope_active: bool = false
var invuln_timer: float = 0.0

var sprint_active: bool = false
var blind_timer: float = 0.0
var blind_intensity: float = 0.0

static var _team_uav_timers: Dictionary = {}
static var _team_uav_last_phys_frame: int = -1

var marked_timer: float = 0.0
var mark_sweep_timer: float = 0.0
var mark_sweep_range: float = 120.0
var mark_sweep_context: Dictionary = {}
var mark_sweep_aim_yaw: float = 0.0
var mark_sweep_aim_pitch: float = 0.0


func _ready() -> void:
	if get_parent() is HeroCharacter:
		owner_hero = get_parent() as HeroCharacter


func _physics_process(delta: float) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		clear_all()
		return

	if not NetworkManager.is_server_authority():
		return

	if owner_hero != null and owner_hero.is_in_water and burn_timer > 0.0:
		burn_timer = 0.0
		burn_dps = 0.0
		_burn_tick_accum = 0.0
		_sync_flags()

	# Process Burn DoT (1 tick/sec)
	if burn_timer > 0.0:
		burn_timer -= delta
		_burn_tick_accum += delta
		if _burn_tick_accum >= 0.5:
			_burn_tick_accum -= 0.5
			var dmg: int = maxi(1, int(roundf(burn_dps * 0.5)))
			owner_hero.apply_damage_server(dmg, burn_attacker_id, false, false, true)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": owner_hero.global_position + Vector3(0.0, 1.9, 0.0),
				"kind": "spark",
				"attacker_id": burn_attacker_id,
				"victim_id": owner_hero.entity_id,
				"damage": dmg,
				"dot": "burn",
			})
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
			owner_hero.apply_damage_server(pdmg, poison_attacker_id, false, false, true)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": owner_hero.global_position + Vector3(0.0, 1.9, 0.0),
				"kind": "spark",
				"attacker_id": poison_attacker_id,
				"victim_id": owner_hero.entity_id,
				"damage": pdmg,
				"dot": "poison",
			})
		if poison_timer <= 0.0:
			poison_timer = 0.0
			_poison_tick_accum = 0.0

	# Shield expiry (preserve non-decaying permanent vest shield!)
	if shield_timer > 0.0:
		shield_timer -= delta
		if shield_timer <= 0.0:
			shield_timer = 0.0
			hero_shield_timer = 0.0
			if permanent_vest_shield <= 0:
				owner_hero.shield = 0
			else:
				owner_hero.shield = mini(owner_hero.shield, permanent_vest_shield)
			owner_hero.stats_changed.emit()
	if hero_shield_timer > 0.0:
		hero_shield_timer = maxf(0.0, hero_shield_timer - delta)
		if owner_hero.shield <= 0:
			hero_shield_timer = 0.0

	# Speed modifiers
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
		if speed_boost_timer <= 0.0:
			speed_boost_timer = 0.0
			speed_boost_mult = 1.0
	leg_it_timer = maxf(0.0, leg_it_timer - delta)
	elixir_timer = maxf(0.0, elixir_timer - delta)
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_timer = 0.0
			slow_mult = 1.0

	var sprint_mult: float = 1.6 if sprint_active else 1.0
	owner_hero.speed_multiplier = maxf(speed_boost_mult, sprint_mult) * slow_mult

	if blind_timer > 0.0:
		blind_timer = maxf(0.0, blind_timer - delta)
		if blind_timer <= 0.0:
			blind_intensity = 0.0

	# Combat buffs
	burning_bullets_timer = maxf(0.0, burning_bullets_timer - delta)
	poisoned_blade_timer = maxf(0.0, poisoned_blade_timer - delta)
	frenzy_timer = maxf(0.0, frenzy_timer - delta)
	eat_grenades_timer = maxf(0.0, eat_grenades_timer - delta)
	piercing_timer = maxf(0.0, piercing_timer - delta)
	sixth_sense_timer = maxf(0.0, sixth_sense_timer - delta)
	fire_immunity_timer = maxf(0.0, fire_immunity_timer - delta)
	marked_timer = maxf(0.0, marked_timer - delta)

	if haste_timer > 0.0:
		haste_timer -= delta
		if haste_timer <= 0.0:
			haste_timer = 0.0
			haste_fire_mult = 1.0
			haste_reload_mult = 1.0

	if carried_shield_swing_timer > 0.0:
		carried_shield_swing_timer = maxf(0.0, carried_shield_swing_timer - delta)
	if carried_shield_active and (owner_hero.selected_weapon_slot != 2 or owner_hero.current_vehicle_id >= 0):
		deactivate_carried_shield(true)

	vehicle_triple_dmg_timer = maxf(0.0, vehicle_triple_dmg_timer - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)

	# Combat Medicine Heal-over-Time
	if hot_timer > 0.0:
		hot_timer = maxf(0.0, hot_timer - delta)
		hot_tick_accum += delta
		while hot_tick_accum >= 0.5:
			hot_tick_accum -= 0.5
			owner_hero.heal_server(hot_heal_per_tick)
	else:
		hot_tick_accum = 0.0

	# Bandages 2.0s channel (completes if uninterrupted by direct damage)
	if bandage_channel_timer > 0.0:
		bandage_channel_timer -= delta
		if bandage_channel_timer <= 0.0:
			bandage_channel_timer = 0.0
			owner_hero.heal_server(bandage_heal_amount)

	# Single-target Mark Target is resolved instantaneously on crosshair press (no multi-target sweep)
	mark_sweep_timer = 0.0

	if stealth_infinite:
		if marked_timer > 0.0:
			break_stealth()
	elif stealth_timer > 0.0:
		stealth_timer -= delta
		if stealth_timer <= 0.0:
			stealth_timer = 0.0
			break_stealth()

	_sync_flags()


func _sync_flags() -> void:
	if owner_hero == null:
		return
	var prev_ss: bool = (owner_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0
	var f: int = owner_hero.active_flags
	f &= ~(NetSerializer.SNAP_BURNING | NetSerializer.SNAP_POISONED | NetSerializer.SNAP_SPEED_BOOST | NetSerializer.SNAP_SIXTH_SENSE | NetSerializer.SNAP_EAT_GRENADES | NetSerializer.SNAP_STEALTHED | NetSerializer.SNAP_SHIELDED | NetSerializer.SNAP_MARKED_TARGET | NetSerializer.SNAP_KEG_CONCUSSED)
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
	if marked_timer > 0.0:
		f |= NetSerializer.SNAP_MARKED_TARGET
	if slow_timer > 0.0:
		f |= NetSerializer.SNAP_KEG_CONCUSSED
	owner_hero.active_flags = f
	if ((f & NetSerializer.SNAP_SIXTH_SENSE) != 0) != prev_ss:
		invalidate_sixth_sense_cache()
	_sync_buffs()


func _sync_buffs() -> void:
	if owner_hero == null:
		return
	var b: int = 0
	if hero_shield_timer > 0.0 and owner_hero.shield > 0:
		b |= NetSerializer.BUFF_HERO_SHIELD
	if leg_it_timer > 0.0:
		b |= NetSerializer.BUFF_LEG_IT
	if elixir_timer > 0.0:
		b |= NetSerializer.BUFF_ELIXIR
	if burning_bullets_timer > 0.0:
		b |= NetSerializer.BUFF_BURNING_BULLETS
	if poisoned_blade_timer > 0.0:
		b |= NetSerializer.BUFF_POISONED_BLADE
	if frenzy_timer > 0.0:
		b |= NetSerializer.BUFF_FRENZY_FIRE
	if piercing_timer > 0.0:
		b |= NetSerializer.BUFF_PIERCING_SHOT
	if eat_grenades_timer > 0.0:
		b |= NetSerializer.BUFF_EAT_GRENADES
	if sixth_sense_timer > 0.0:
		b |= NetSerializer.BUFF_SIXTH_SENSE
	if hot_timer > 0.0:
		b |= NetSerializer.BUFF_COMBAT_MED_HOT
	if bandage_channel_timer > 0.0:
		b |= NetSerializer.BUFF_BANDAGE
	if fire_immunity_timer > 0.0:
		b |= NetSerializer.BUFF_FIREPROOF
	if haste_timer > 0.0:
		b |= NetSerializer.BUFF_HASTE
	if carried_shield_active:
		b |= NetSerializer.BUFF_CARRIED_SHIELD
	if vehicle_triple_dmg_timer > 0.0:
		b |= NetSerializer.BUFF_VEHICLE_BUSTER
	if tnt_rope_active:
		b |= NetSerializer.BUFF_TNT_ROPE
	if invuln_timer > 0.0:
		b |= NetSerializer.BUFF_ENGINEER_INVULN
	if owner_hero.skill_manager != null and owner_hero.skill_manager.has_method("get_active_buff_flags"):
		b |= int(owner_hero.skill_manager.get_active_buff_flags())
	owner_hero.active_buffs = b


func apply_burn(attacker_id: int, dps: float, duration: float) -> void:
	if (owner_hero != null and owner_hero.is_in_water) or fire_immunity_timer > 0.0:
		return
	burn_attacker_id = attacker_id
	burn_dps = maxf(burn_dps, dps)
	burn_timer = maxf(burn_timer, duration)
	_sync_flags()


func apply_poison(attacker_id: int, dps: float, duration: float) -> void:
	poison_attacker_id = attacker_id
	poison_dps = maxf(poison_dps, dps)
	poison_timer = maxf(poison_timer, duration)
	_poison_tick_accum = 0.0
	_sync_flags()


func cleanse_burn_and_grant_immunity(immunity_sec: float = 2.0) -> void:
	burn_timer = 0.0
	burn_dps = 0.0
	_burn_tick_accum = 0.0
	fire_immunity_timer = maxf(fire_immunity_timer, immunity_sec)
	_sync_flags()


func cleanse_poison() -> void:
	poison_timer = 0.0
	poison_dps = 0.0
	_poison_tick_accum = 0.0
	_sync_flags()


func cleanse_burn_and_poison() -> void:
	cleanse_burn_and_grant_immunity(2.0)
	cleanse_poison()


func apply_shield(amount: int, duration: float, is_hero_shield: bool = true) -> void:
	if owner_hero == null:
		return
	owner_hero.shield = maxi(owner_hero.shield, amount)
	shield_timer = maxf(shield_timer, duration)
	if is_hero_shield:
		hero_shield_timer = maxf(hero_shield_timer, duration)
	owner_hero.stats_changed.emit()
	_sync_flags()


func apply_speed_boost(mult: float, duration: float, is_elixir: bool = false) -> void:
	speed_boost_mult = maxf(speed_boost_mult, mult)
	speed_boost_timer = maxf(speed_boost_timer, duration)
	if is_elixir:
		elixir_timer = maxf(elixir_timer, duration)
	else:
		leg_it_timer = maxf(leg_it_timer, duration)
	_sync_flags()


func apply_concussion_slow(mult: float, duration: float) -> void:
	slow_mult = minf(slow_mult, mult)
	slow_timer = maxf(slow_timer, duration)
	_sync_flags()


func activate_burning_bullets(dps: float, duration: float) -> void:
	burning_bullets_dps = dps
	burning_bullets_timer = duration
	_sync_flags()


func activate_poisoned_blade(dps: float, duration: float) -> void:
	poisoned_blade_dps = dps
	poisoned_blade_timer = duration
	_sync_flags()


func activate_frenzy_fire(heal_amount: int, duration: float) -> void:
	frenzy_heal_amount = heal_amount
	frenzy_timer = duration
	_sync_flags()


func activate_eat_grenades(duration: float) -> void:
	eat_grenades_timer = duration
	_sync_flags()


func activate_piercing_shot(mult: float, duration: float) -> void:
	piercing_mult = mult
	piercing_timer = duration
	_sync_flags()


func apply_heal_over_time(total_amount: int, duration: float) -> void:
	var ticks: int = maxi(1, int(roundf(duration / 0.5)))
	hot_heal_per_tick = maxi(1, int(ceilf(float(total_amount) / float(ticks))))
	hot_timer = maxf(hot_timer, duration)
	_sync_flags()


func start_bandage_channel(heal_amount: int = 40, duration: float = 2.0) -> void:
	bandage_heal_amount = heal_amount
	bandage_channel_timer = duration
	_sync_flags()


func interrupt_bandage_channel() -> void:
	bandage_channel_timer = 0.0
	_sync_flags()


func is_burning() -> bool:
	return burn_timer > 0.0


func is_poisoned() -> bool:
	return poison_timer > 0.0


func is_marked() -> bool:
	return marked_timer > 0.0


func apply_marked(duration: float = 12.0) -> void:
	marked_timer = maxf(marked_timer, duration)
	break_stealth()
	_sync_flags()


func clear_marked() -> void:
	marked_timer = 0.0
	_sync_flags()


func _clear_all_other_marks(heroes_by_id: Dictionary, vehs: Array) -> void:
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if h != null and h.status_effects != null and h.status_effects.is_marked():
			h.status_effects.clear_marked()
	for v in vehs:
		if v is VehicleBase and (v as VehicleBase).is_marked:
			(v as VehicleBase).clear_marked()


func try_mark_crosshair_target(context: Dictionary, aim_yaw: float, aim_pitch: float, mark_duration: float = 12.0) -> bool:
	if owner_hero == null or owner_hero.is_defeated:
		return false
	mark_sweep_timer = 0.0
	var hero_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var eye_offset: float = 1.05 if owner_hero.is_crouching else 1.50
	var eye_pos: Vector3 = hero_pos + Vector3(0.0, eye_offset, 0.0)
	var cam_ray: Dictionary = HeroCamera.compute_aim_ray(
		hero_pos,
		aim_yaw,
		aim_pitch,
		owner_hero.is_scoping,
		owner_hero.current_vehicle_id >= 0,
		owner_hero.is_crouching
	)
	var pivot_pos: Vector3 = cam_ray.get("pivot", eye_pos)
	var look_dir: Vector3 = (-Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)).z).normalized()
	var space: PhysicsDirectSpaceState3D = owner_hero.get_world_3d().direct_space_state if (owner_hero.is_inside_tree() and owner_hero.get_world_3d() != null) else null
	var min_cos: float = cos(deg_to_rad(MARK_CROSSHAIR_MAX_ANGLE_DEG))
	var ray_excludes: Array[RID] = [owner_hero.get_rid()]

	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")

	var best_kind: String = "" # "hero" | "vehicle"
	var best_hero: HeroCharacter = null
	var best_veh: VehicleBase = null
	var best_dot: float = -2.0
	var best_dist: float = MARK_TARGET_MAX_RANGE + 1.0

	for id_key in heroes_by_id.keys():
		var cand: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if cand == null or cand.is_defeated or cand.team == owner_hero.team:
			continue
		var c_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
		var target_pos: Vector3 = c_pos + Vector3(0.0, 1.15, 0.0)
		var to_eye: Vector3 = target_pos - eye_pos
		var dist: float = to_eye.length()
		if dist > MARK_TARGET_MAX_RANGE or dist < 0.1:
			continue
		var dot_eye: float = (to_eye / dist).dot(look_dir)
		var to_cam: Vector3 = target_pos - pivot_pos
		var cam_len: float = maxf(0.1, to_cam.length())
		var dot_cam: float = (to_cam / cam_len).dot(look_dir)
		var align_dot: float = maxf(dot_eye, dot_cam)
		var proj: float = maxf(0.0, to_eye.dot(look_dir))
		var perp_dist: float = (to_eye - look_dir * proj).length()
		var in_crosshair: bool = (align_dot >= min_cos) or (dist <= 30.0 and to_eye.dot(look_dir) > 0.0 and perp_dist <= 1.15)
		if not in_crosshair:
			continue
		if space != null:
			var q := PhysicsRayQueryParameters3D.create(eye_pos, target_pos, 1 | 64)
			q.exclude = ray_excludes
			if not space.intersect_ray(q).is_empty():
				continue
		if align_dot > best_dot + 0.0002 or (absf(align_dot - best_dot) <= 0.0002 and dist < best_dist):
			best_kind = "hero"
			best_hero = cand
			best_veh = null
			best_dot = align_dot
			best_dist = dist

	for v in vehs:
		if not (v is VehicleBase):
			continue
		var vb := v as VehicleBase
		if vb.is_destroyed or vb.team == owner_hero.team:
			continue
		var v_pos: Vector3 = vb.global_position if vb.is_inside_tree() else vb.position
		var target_pos: Vector3 = v_pos + Vector3(0.0, 1.2, 0.0)
		var to_eye: Vector3 = target_pos - eye_pos
		var vdist: float = to_eye.length()
		if vdist > MARK_TARGET_MAX_RANGE or vdist < 0.1:
			continue
		var dot_eye: float = (to_eye / vdist).dot(look_dir)
		var to_cam: Vector3 = target_pos - pivot_pos
		var cam_len: float = maxf(0.1, to_cam.length())
		var dot_cam: float = (to_cam / cam_len).dot(look_dir)
		var align_dot: float = maxf(dot_eye, dot_cam)
		var proj: float = maxf(0.0, to_eye.dot(look_dir))
		var perp_dist: float = (to_eye - look_dir * proj).length()
		var in_crosshair: bool = (align_dot >= min_cos) or (vdist <= 35.0 and to_eye.dot(look_dir) > 0.0 and perp_dist <= 2.6)
		if not in_crosshair:
			continue
		if space != null:
			var qv := PhysicsRayQueryParameters3D.create(eye_pos, target_pos, 1 | 64)
			qv.exclude = ray_excludes
			if not space.intersect_ray(qv).is_empty():
				continue
		if align_dot > best_dot + 0.0002 or (absf(align_dot - best_dot) <= 0.0002 and vdist < best_dist):
			best_kind = "vehicle"
			best_veh = vb
			best_hero = null
			best_dot = align_dot
			best_dist = vdist

	if best_kind == "hero" and best_hero != null and best_hero.status_effects != null:
		_clear_all_other_marks(heroes_by_id, vehs)
		best_hero.status_effects.apply_marked(mark_duration)
		return true
	if best_kind == "vehicle" and best_veh != null:
		_clear_all_other_marks(heroes_by_id, vehs)
		best_veh.apply_marked(mark_duration)
		return true
	return false


func activate_mark_target_window(_duration: float, _max_range_m: float, context: Dictionary, aim_yaw: float, aim_pitch: float) -> void:
	try_mark_crosshair_target(context, aim_yaw, aim_pitch, 12.0)


func activate_stealth(detection_radius: float, duration: float = -1.0) -> void:
	if marked_timer > 0.0:
		return
	stealth_detection_radius = detection_radius
	stealth_infinite = (duration < 0.0)
	stealth_timer = maxf(0.0, duration)
	if owner_hero != null:
		owner_hero.is_stealthed = true
	_sync_flags()


func break_stealth() -> void:
	var was_stealthed: bool = (owner_hero != null and owner_hero.is_stealthed) or stealth_infinite or stealth_timer > 0.0
	stealth_timer = 0.0
	stealth_infinite = false
	if owner_hero != null:
		owner_hero.is_stealthed = false
		if was_stealthed and owner_hero.skill_manager != null and owner_hero.class_id == NetworkManager.CLASS_COMMANDO:
			owner_hero.skill_manager.start_stealth_exit_cooldown()
	_sync_flags()


func has_piercing_shot() -> bool:
	return piercing_timer > 0.0


func activate_sixth_sense(radius: float, duration: float) -> void:
	sixth_sense_radius = maxf(sixth_sense_radius, radius)
	sixth_sense_timer = maxf(sixth_sense_timer, duration)
	invalidate_sixth_sense_cache()
	_sync_flags()


static func invalidate_sixth_sense_cache() -> void:
	_sixth_sense_cache_active = false


static func clear_sixth_sense_cache() -> void:
	_sixth_sense_cache_active = false
	_sixth_sense_casters_royal.clear()
	_sixth_sense_casters_national.clear()
	_sixth_sense_cache_dict = {}
	_sixth_sense_cache_proc_frame = -1
	_sixth_sense_cache_phys_frame = -1


static func refresh_sixth_sense_cache(heroes_by_id: Dictionary) -> void:
	_sixth_sense_casters_royal.clear()
	_sixth_sense_casters_national.clear()
	for id_key in heroes_by_id.keys():
		var ally: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if not _hero_has_sixth_sense_active(ally):
			continue
		if ally.team == NetworkManager.TEAM_ROYAL:
			_sixth_sense_casters_royal.append(ally)
		elif ally.team == NetworkManager.TEAM_NATIONAL:
			_sixth_sense_casters_national.append(ally)
	_sixth_sense_cache_dict = heroes_by_id
	_sixth_sense_cache_proc_frame = Engine.get_process_frames()
	_sixth_sense_cache_phys_frame = Engine.get_physics_frames()
	_sixth_sense_cache_active = true


static func _hero_has_sixth_sense_active(h: HeroCharacter) -> bool:
	if h == null or not is_instance_valid(h) or h.is_defeated:
		return false
	if (h.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0:
		return true
	if (h.active_buffs & NetSerializer.BUFF_SIXTH_SENSE) != 0:
		return true
	return h.status_effects != null and h.status_effects.sixth_sense_timer > 0.0


static func is_pos_sensed_by_team(world_pos: Vector3, viewer_team: int, heroes_by_id: Dictionary, fallback_viewer: HeroCharacter = null) -> bool:
	var r_sq: float = SIXTH_SENSE_RADIUS * SIXTH_SENSE_RADIUS
	if fallback_viewer != null and is_instance_valid(fallback_viewer) and fallback_viewer.team == viewer_team and _hero_has_sixth_sense_active(fallback_viewer):
		var fv_pos: Vector3 = fallback_viewer.global_position if fallback_viewer.is_inside_tree() else fallback_viewer.position
		if fv_pos.distance_squared_to(world_pos) <= r_sq:
			return true
	var use_cache: bool = (
		_sixth_sense_cache_active
		and is_same(heroes_by_id, _sixth_sense_cache_dict)
		and _sixth_sense_cache_proc_frame == Engine.get_process_frames()
		and _sixth_sense_cache_phys_frame == Engine.get_physics_frames()
	)
	if use_cache:
		var casters: Array[HeroCharacter] = _sixth_sense_casters_royal if viewer_team == NetworkManager.TEAM_ROYAL else _sixth_sense_casters_national
		if casters.is_empty():
			return false
		for ally in casters:
			if not _hero_has_sixth_sense_active(ally):
				continue
			var a_pos: Vector3 = ally.global_position if ally.is_inside_tree() else ally.position
			if a_pos.distance_squared_to(world_pos) <= r_sq:
				return true
		return false
	for id_key in heroes_by_id.keys():
		var ally: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if ally == null or not is_instance_valid(ally) or ally.team != viewer_team:
			continue
		if not _hero_has_sixth_sense_active(ally):
			continue
		var a_pos: Vector3 = ally.global_position if ally.is_inside_tree() else ally.position
		if a_pos.distance_squared_to(world_pos) <= r_sq:
			return true
	return false


static func is_enemy_sensed_by_team(enemy: HeroCharacter, viewer_team: int, heroes_by_id: Dictionary, fallback_viewer: HeroCharacter = null) -> bool:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_defeated or enemy.team == viewer_team:
		return false
	var e_pos: Vector3 = enemy.global_position if enemy.is_inside_tree() else enemy.position
	return is_pos_sensed_by_team(e_pos, viewer_team, heroes_by_id, fallback_viewer)


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


func activate_haste(speed_mult: float, fire_mult: float, reload_mult: float, duration: float) -> void:
	speed_boost_mult = maxf(speed_boost_mult, speed_mult)
	speed_boost_timer = maxf(speed_boost_timer, duration)
	haste_fire_mult = maxf(haste_fire_mult, fire_mult)
	haste_reload_mult = maxf(haste_reload_mult, reload_mult)
	haste_timer = maxf(haste_timer, duration)
	_sync_flags()


func get_haste_fire_mult() -> float:
	if haste_timer > 0.0:
		return haste_fire_mult
	if owner_hero != null and (owner_hero.active_buffs & NetSerializer.BUFF_HASTE) != 0:
		return 1.50
	return 1.0


func get_haste_reload_mult() -> float:
	if haste_timer > 0.0:
		return haste_reload_mult
	if owner_hero != null and (owner_hero.active_buffs & NetSerializer.BUFF_HASTE) != 0:
		return 1.60
	return 1.0


func apply_vest_shield(amount: int = 70) -> void:
	if owner_hero == null or owner_hero.is_defeated or amount <= 0:
		return
	owner_hero.shield = maxi(owner_hero.shield, amount)
	permanent_vest_shield = clampi(maxi(permanent_vest_shield, amount), 0, owner_hero.shield)
	owner_hero.stats_changed.emit()
	_sync_flags()


func activate_carried_shield(hp_amt: int = 550) -> void:
	carried_shield_max_hp = maxi(1, hp_amt)
	carried_shield_hp = carried_shield_max_hp
	carried_shield_active = true
	carried_shield_swing_timer = 0.0
	_sync_flags()


func deactivate_carried_shield(start_cooldown: bool = true) -> void:
	var was_active: bool = carried_shield_active
	carried_shield_active = false
	carried_shield_swing_timer = 0.0
	if was_active and start_cooldown and owner_hero != null and owner_hero.skill_manager != null:
		if owner_hero.skill_manager.has_method("start_carried_shield_exit_cooldown"):
			owner_hero.skill_manager.start_carried_shield_exit_cooldown()
	_sync_flags()


func trigger_carried_shield_swing_gap(dur: float = 0.48) -> void:
	if carried_shield_active and dur > 0.0:
		carried_shield_swing_timer = maxf(carried_shield_swing_timer, dur)


func is_frontal_carried_shield_block_dir(attack_dir_from_target: Vector3) -> bool:
	if not carried_shield_active or carried_shield_swing_timer > 0.0 or owner_hero == null or owner_hero.is_defeated:
		return false
	if owner_hero.current_vehicle_id >= 0:
		return false
	var flat_atk := Vector3(attack_dir_from_target.x, 0.0, attack_dir_from_target.z)
	if flat_atk.length_squared() < 0.0001:
		return false
	var hero_fwd := -Basis(Vector3.UP, owner_hero.aim_yaw).z
	hero_fwd.y = 0.0
	if hero_fwd.length_squared() < 0.0001:
		hero_fwd = Vector3.FORWARD
	return flat_atk.normalized().dot(hero_fwd.normalized()) >= 0.15


func is_frontal_carried_shield_block(attack_origin_pos: Vector3) -> bool:
	if owner_hero == null:
		return false
	var h_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	return is_frontal_carried_shield_block_dir(attack_origin_pos - h_pos)


func damage_carried_shield(dmg: int) -> int:
	if not carried_shield_active or dmg <= 0:
		return 0
	var absorbed: int = mini(carried_shield_hp, dmg)
	carried_shield_hp = maxi(0, carried_shield_hp - dmg)
	if carried_shield_hp <= 0:
		deactivate_carried_shield(true)
		if owner_hero != null:
			var pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": pos + Vector3(0.0, 1.15, 0.0),
				"kind": "spark",
				"victim_id": owner_hero.entity_id,
				"damage": 0,
			})
	return absorbed


func activate_vehicle_triple_dmg(duration: float) -> void:
	vehicle_triple_dmg_timer = maxf(vehicle_triple_dmg_timer, duration)
	_sync_flags()


func get_vehicle_damage_mult() -> float:
	return 3.0 if vehicle_triple_dmg_timer > 0.0 else 1.0


func activate_tnt_rope() -> void:
	tnt_rope_active = true
	_sync_flags()


func clear_tnt_rope() -> void:
	tnt_rope_active = false
	_sync_flags()


func is_tnt_rope_active() -> bool:
	return tnt_rope_active


func activate_invulnerability(duration: float = 1.5) -> void:
	invuln_timer = maxf(invuln_timer, duration)
	_sync_flags()


func is_invulnerable() -> bool:
	if invuln_timer > 0.0:
		return true
	return owner_hero != null and (owner_hero.active_buffs & NetSerializer.BUFF_ENGINEER_INVULN) != 0


func set_sprint_active(active: bool) -> void:
	sprint_active = active
	if owner_hero != null:
		var sprint_mult: float = 1.6 if sprint_active else 1.0
		owner_hero.speed_multiplier = maxf(speed_boost_mult, sprint_mult) * slow_mult
		_sync_flags()


func is_sprint_active() -> bool:
	return sprint_active


func apply_blind(duration: float, intensity: float) -> void:
	if duration <= 0.0 or intensity <= 0.0:
		return
	var clamped_int: float = clampf(intensity, 0.0, 1.0)
	if duration >= blind_timer:
		blind_timer = duration
		blind_intensity = clamped_int
	else:
		blind_intensity = maxf(blind_intensity, clamped_int)


func is_blinded() -> bool:
	return blind_timer > 0.0 and blind_intensity > 0.01


func get_blind_intensity() -> float:
	return blind_intensity if blind_timer > 0.0 else 0.0


static func trigger_team_uav(p_team: int, duration: float = 1.0) -> void:
	_team_uav_timers[p_team] = maxf(float(_team_uav_timers.get(p_team, 0.0)), duration)


static func sync_team_uav_timer(p_team: int, remaining: float) -> void:
	_team_uav_timers[p_team] = maxf(0.0, remaining)


static func step_team_uav(delta: float) -> void:
	var pf: int = Engine.get_physics_frames()
	if _team_uav_last_phys_frame == pf:
		return
	_team_uav_last_phys_frame = pf
	for t_key in _team_uav_timers.keys():
		_team_uav_timers[t_key] = maxf(0.0, float(_team_uav_timers[t_key]) - delta)


static func clear_team_uav() -> void:
	_team_uav_timers.clear()
	_team_uav_last_phys_frame = -1


static func is_team_uav_active(viewer_team: int, heroes_by_id: Dictionary = {}) -> bool:
	if float(_team_uav_timers.get(viewer_team, 0.0)) > 0.0:
		return true
	for id_key in heroes_by_id.keys():
		var ally: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if ally == null or not is_instance_valid(ally) or ally.is_defeated or ally.team != viewer_team:
			continue
		if (ally.active_buffs & NetSerializer.BUFF_MARKSMAN_UAV) != 0:
			return true
		if ally.skill_manager != null and ally.skill_manager.has_method("is_uav_active") and bool(ally.skill_manager.is_uav_active()):
			return true
	return false


func clear_all() -> void:
	burn_timer = 0.0
	burn_dps = 0.0
	_burn_tick_accum = 0.0
	poison_timer = 0.0
	poison_dps = 0.0
	_poison_tick_accum = 0.0
	shield_timer = 0.0
	hero_shield_timer = 0.0
	speed_boost_timer = 0.0
	leg_it_timer = 0.0
	elixir_timer = 0.0
	speed_boost_mult = 1.0
	slow_timer = 0.0
	slow_mult = 1.0
	burning_bullets_timer = 0.0
	poisoned_blade_timer = 0.0
	frenzy_timer = 0.0
	eat_grenades_timer = 0.0
	piercing_timer = 0.0
	stealth_timer = 0.0
	stealth_infinite = false
	sixth_sense_timer = 0.0
	hot_timer = 0.0
	hot_tick_accum = 0.0
	bandage_channel_timer = 0.0
	fire_immunity_timer = 0.0
	haste_timer = 0.0
	haste_fire_mult = 1.0
	haste_reload_mult = 1.0
	permanent_vest_shield = 0
	carried_shield_active = false
	carried_shield_hp = carried_shield_max_hp
	carried_shield_swing_timer = 0.0
	vehicle_triple_dmg_timer = 0.0
	tnt_rope_active = false
	invuln_timer = 0.0
	sprint_active = false
	blind_timer = 0.0
	blind_intensity = 0.0
	marked_timer = 0.0
	mark_sweep_timer = 0.0
	if owner_hero != null:
		owner_hero.is_stealthed = false
		owner_hero.shield = 0
		owner_hero.speed_multiplier = 1.0
		_sync_flags()
