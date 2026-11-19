class_name MarksmanSkills
extends SkillManager

## Marksman's 5 Heroic Skills:
## 0: Sprint (+60% move speed while held, 0..100 energy, 0s CD)
## 1: Flashbang (oblique throw, 18m directional/distance look-angle blind)
## 2: UAV (1.0s team minimap-only enemy reveal, zero 3D X-ray)
## 3: Granada de Cabo (oblique spinning thrown stick grenade, 110 AoE)
## 4: Last Stand (3.0s Pickaxe auto-forward W + 0.5s 40-dmg swings + deferred-death immortality)

const SPRINT_SPEED_MULT: float = 1.6
const SPRINT_DRAIN_PER_SEC: float = 25.0
const SPRINT_RECHARGE_PER_SEC: float = 20.0
const SPRINT_REENGAGE_MIN: float = 10.0
const UAV_DURATION: float = 1.0
const LAST_STAND_DURATION: float = 3.0
const LAST_STAND_SWING_INTERVAL: float = 0.5
const LAST_STAND_MAX_SWINGS: int = 6
const LAST_STAND_SWING_DAMAGE: int = 40
const LAST_STAND_RANGE: float = 3.1

var sprint_energy: float = 100.0
var is_sprinting: bool = false
var _sprint_exhausted: bool = false
var _suppress_slot0_edge: bool = false

var uav_timer: float = 0.0

var last_stand_timer: float = 0.0
var _last_stand_swing_accum: float = 0.0
var _last_stand_swings_done: int = 0
var _last_context: Dictionary = {}


func _init() -> void:
	skill_names = ["Sprint", "Flashbang", "UAV", "Granada de Cabo", "Last Stand"]
	skill_ranks = [5, 5, 5, 5, 5]
	skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0]
	skill_max_cooldowns = [0.0, 15.0, 18.0, 14.0, 22.0]


func _ready() -> void:
	super._ready()
	if owner_hero != null:
		if not owner_hero.defeated.is_connected(_on_owner_defeated):
			owner_hero.defeated.connect(_on_owner_defeated)
		if not owner_hero.respawned.is_connected(_on_owner_respawned):
			owner_hero.respawned.connect(_on_owner_respawned)


func _on_owner_defeated(_killer_id: int, _explosive: bool) -> void:
	_reset_active_states()


func _on_owner_respawned() -> void:
	_reset_active_states()
	sprint_energy = 100.0
	_sprint_exhausted = false


func _finish_or_abort_last_stand() -> void:
	var was_active: bool = last_stand_timer > 0.0
	last_stand_timer = 0.0
	_last_stand_swing_accum = 0.0
	_last_stand_swings_done = 0
	if was_active:
		_sync_hero_buffs()
	if owner_hero != null and not owner_hero.is_defeated and owner_hero._last_stand_pending_death:
		owner_hero._complete_defeat(owner_hero._last_stand_killer_id, owner_hero._last_stand_killer_explosive)


func _reset_active_states() -> void:
	is_sprinting = false
	uav_timer = 0.0
	if owner_hero != null:
		StatusEffectContainer.sync_team_uav_timer(owner_hero.team, 0.0)
	if owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.has_method("set_sprint_active"):
		owner_hero.status_effects.set_sprint_active(false)
	_finish_or_abort_last_stand()
	_sync_hero_buffs()


func is_uav_active() -> bool:
	return uav_timer > 0.0


func is_last_stand_active() -> bool:
	return last_stand_timer > 0.0


func blocks_weapon_fire() -> bool:
	return is_last_stand_active()


func get_active_buff_flags() -> int:
	var flags: int = 0
	if is_sprinting:
		flags |= NetSerializer.BUFF_MARKSMAN_SPRINT
	if uav_timer > 0.0:
		flags |= NetSerializer.BUFF_MARKSMAN_UAV
	if last_stand_timer > 0.0:
		flags |= NetSerializer.BUFF_MARKSMAN_LAST_STAND
	return flags


func _sync_hero_buffs() -> void:
	if owner_hero == null:
		return
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("_sync_buffs"):
		owner_hero.status_effects._sync_buffs()
	else:
		var mask: int = ~(NetSerializer.BUFF_MARKSMAN_SPRINT | NetSerializer.BUFF_MARKSMAN_UAV | NetSerializer.BUFF_MARKSMAN_LAST_STAND)
		owner_hero.active_buffs = (owner_hero.active_buffs & mask) | get_active_buff_flags()


func sync_sprint_energy_from_server(energy_val: int) -> void:
	sprint_energy = clampf(float(energy_val), 0.0, 100.0)
	var server_sprinting: bool = owner_hero != null and (owner_hero.active_buffs & NetSerializer.BUFF_MARKSMAN_SPRINT) != 0
	is_sprinting = server_sprinting
	if sprint_energy <= 0.0 and not server_sprinting:
		_sprint_exhausted = true
	elif sprint_energy >= SPRINT_REENGAGE_MIN:
		_sprint_exhausted = false


func predict_sprint_client(cmd: InputCmd, delta: float) -> void:
	if owner_hero == null or owner_hero.is_defeated or owner_hero.current_vehicle_id >= 0:
		is_sprinting = false
		return
	var held: bool = cmd != null and cmd.has_button(InputCmd.BTN_SKILL_1) and not owner_hero.is_last_stand_active()
	if held and not _sprint_exhausted and sprint_energy > 0.0:
		is_sprinting = true
		sprint_energy = maxf(0.0, sprint_energy - SPRINT_DRAIN_PER_SEC * delta)
		if sprint_energy <= 0.0:
			sprint_energy = 0.0
			is_sprinting = false
			_sprint_exhausted = true
	else:
		is_sprinting = false
		sprint_energy = minf(100.0, sprint_energy + SPRINT_RECHARGE_PER_SEC * delta)
		if _sprint_exhausted and sprint_energy >= SPRINT_REENGAGE_MIN:
			_sprint_exhausted = false
	owner_hero.speed_multiplier = SPRINT_SPEED_MULT if is_sprinting else 1.0


func try_activate_skill(slot_idx: int, cmd: InputCmd, context: Dictionary) -> bool:
	if slot_idx == 0 and _suppress_slot0_edge:
		return false
	return super.try_activate_skill(slot_idx, cmd, context)


func _step_uav(delta: float, context: Dictionary) -> void:
	if uav_timer <= 0.0:
		return
	uav_timer = maxf(0.0, uav_timer - delta)
	if owner_hero != null:
		var max_team_uav: float = uav_timer
		var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
		for hid_key in heroes_by_id.keys():
			var ally: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
			if ally != null and ally != owner_hero and not ally.is_defeated and ally.team == owner_hero.team:
				if ally.skill_manager is MarksmanSkills:
					max_team_uav = maxf(max_team_uav, (ally.skill_manager as MarksmanSkills).uav_timer)
		StatusEffectContainer.sync_team_uav_timer(owner_hero.team, max_team_uav)
	if uav_timer <= 0.0:
		_sync_hero_buffs()


func step_cooldowns_and_widgets_only(delta: float, hero: HeroCharacter = null) -> void:
	if owner_hero == null and hero != null:
		owner_hero = hero
	_step_uav(delta, _last_context)
	_step_sprint(delta, null, false)
	if last_stand_timer > 0.0:
		_finish_or_abort_last_stand()
	super.step_server(delta, null, _last_context, false)


func step_server(delta: float, cmd: InputCmd, context: Dictionary, allow_class_skills: bool = true) -> void:
	_last_context = context

	_step_uav(delta, context)

	if last_stand_timer > 0.0:
		if owner_hero == null or owner_hero.is_defeated or owner_hero.current_vehicle_id >= 0:
			_finish_or_abort_last_stand()
		else:
			last_stand_timer = maxf(0.0, last_stand_timer - delta)
			_last_stand_swing_accum += delta
			while _last_stand_swing_accum >= LAST_STAND_SWING_INTERVAL and _last_stand_swings_done < LAST_STAND_MAX_SWINGS:
				_last_stand_swing_accum -= LAST_STAND_SWING_INTERVAL
				_last_stand_swings_done += 1
				_perform_pickaxe_swing(context)
			if last_stand_timer <= 0.0:
				_finish_or_abort_last_stand()

	_step_sprint(delta, cmd, allow_class_skills)

	_suppress_slot0_edge = true
	super.step_server(delta, cmd, context, allow_class_skills and not is_last_stand_active())
	_suppress_slot0_edge = false


func _step_sprint(delta: float, cmd: InputCmd, allow_class_skills: bool) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		is_sprinting = false
		if owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.has_method("set_sprint_active"):
			owner_hero.status_effects.set_sprint_active(false)
		return

	var sprint_held: bool = (
		allow_class_skills
		and cmd != null
		and cmd.has_button(InputCmd.BTN_SKILL_1)
		and not is_last_stand_active()
		and owner_hero.current_vehicle_id < 0
	)
	var was_sprinting: bool = is_sprinting

	if sprint_held and not _sprint_exhausted and sprint_energy > 0.0:
		is_sprinting = true
		sprint_energy = maxf(0.0, sprint_energy - SPRINT_DRAIN_PER_SEC * delta)
		if sprint_energy <= 0.0:
			sprint_energy = 0.0
			is_sprinting = false
			_sprint_exhausted = true
	else:
		is_sprinting = false
		sprint_energy = minf(100.0, sprint_energy + SPRINT_RECHARGE_PER_SEC * delta)
		if _sprint_exhausted and sprint_energy >= SPRINT_REENGAGE_MIN:
			_sprint_exhausted = false

	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("set_sprint_active"):
		owner_hero.status_effects.set_sprint_active(is_sprinting)

	if is_sprinting != was_sprinting:
		_sync_hero_buffs()
		if is_sprinting:
			NetworkManager.broadcast_game_event("skill_vfx", {
				"hero_id": owner_hero.entity_id,
				"slot": 0,
				"class_id": owner_hero.class_id,
				"skill_name": skill_names[0],
				"pos": owner_hero.global_position,
			})


func _get_throw_origin_and_dir(cmd: InputCmd, context: Dictionary) -> Dictionary:
	var aim_yaw_val: float = cmd.aim_yaw if cmd != null else owner_hero.aim_yaw
	var aim_pitch_val: float = cmd.aim_pitch if cmd != null else owner_hero.aim_pitch
	if not owner_hero.weapons.is_empty() and owner_hero.weapons[0] is WeaponBase:
		var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
		var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
		var lag_comp: LagCompensator = context.get("lag_compensator", null)
		var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
		var aim_cmd := cmd if cmd != null else InputCmd.new()
		var aim: Dictionary = (owner_hero.weapons[0] as WeaponBase).get_aim_origin_and_dir(aim_cmd, space_state, lag_comp, heroes_by_id)
		var dir: Vector3 = (aim["dir"] as Vector3).normalized()
		var origin: Vector3 = (aim["origin"] as Vector3) + dir * 0.65
		return {"origin": origin, "dir": dir}
	var h_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var aim_basis := Basis.from_euler(Vector3(aim_pitch_val, aim_yaw_val, 0.0))
	var fallback_dir: Vector3 = (-aim_basis.z).normalized()
	var fallback_origin: Vector3 = h_pos + Vector3(0.0, 1.48, 0.0) + fallback_dir * 0.65
	return {"origin": fallback_origin, "dir": fallback_dir}


func _execute_class_skill(slot_idx: int, _rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null or owner_hero.is_defeated:
		return false

	match slot_idx:
		0: # Sprint fallback if triggered directly
			if _sprint_exhausted or sprint_energy <= 0.0 or is_last_stand_active() or owner_hero.current_vehicle_id >= 0:
				return false
			is_sprinting = true
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("set_sprint_active"):
				owner_hero.status_effects.set_sprint_active(true)
			_sync_hero_buffs()
			return true

		1: # Flashbang
			if is_last_stand_active():
				return false
			var throw_info: Dictionary = _get_throw_origin_and_dir(cmd, context)
			var origin: Vector3 = throw_info["origin"] as Vector3
			var dir: Vector3 = throw_info["dir"] as Vector3
			var lob_scale: float = clampf(1.0 - maxf(0.0, -dir.y), 0.25, 1.0)
			var launch_vel: Vector3 = dir * 23.0 + Vector3(0.0, 3.6 * lob_scale, 0.0)
			ProjectileEntity.spawn_server_projectile(
				ProjectileEntity.ProjectileKind.FLASHBANG,
				owner_hero.entity_id,
				owner_hero.team,
				origin,
				launch_vel,
				context,
				0.0,
				owner_hero.get_parent()
			)
			return true

		2: # UAV (1.0s minimap-only reveal)
			if is_last_stand_active():
				return false
			uav_timer = UAV_DURATION
			StatusEffectContainer.trigger_team_uav(owner_hero.team, UAV_DURATION)
			_sync_hero_buffs()
			NetworkManager.broadcast_game_event("uav_pulse", {
				"team": owner_hero.team,
				"duration": UAV_DURATION,
				"hero_id": owner_hero.entity_id,
				"pos": owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position,
			})
			return true

		3: # Granada de Cabo (Thrown Stick Grenade)
			if is_last_stand_active():
				return false
			var throw_sg: Dictionary = _get_throw_origin_and_dir(cmd, context)
			var sg_origin: Vector3 = throw_sg["origin"] as Vector3
			var sg_dir: Vector3 = throw_sg["dir"] as Vector3
			var sg_lob: float = clampf(1.0 - maxf(0.0, -sg_dir.y), 0.25, 1.0)
			var sg_vel: Vector3 = sg_dir * 21.0 + Vector3(0.0, 4.4 * sg_lob, 0.0)
			ProjectileEntity.spawn_server_projectile(
				ProjectileEntity.ProjectileKind.THROWN_STICK_GRENADE,
				owner_hero.entity_id,
				owner_hero.team,
				sg_origin,
				sg_vel,
				context,
				110.0,
				owner_hero.get_parent()
			)
			return true

		4: # Last Stand (3.0s Pickaxe auto-advance + 0.5s 40-dmg swings + deferred death)
			if owner_hero.current_vehicle_id >= 0 or is_last_stand_active():
				return false
			is_sprinting = false
			if owner_hero.status_effects != null and owner_hero.status_effects.has_method("set_sprint_active"):
				owner_hero.status_effects.set_sprint_active(false)
			last_stand_timer = LAST_STAND_DURATION
			_last_stand_swing_accum = 0.0
			_last_stand_swings_done = 1
			_sync_hero_buffs()
			_perform_pickaxe_swing(context)
			return true

	return false


func _perform_pickaxe_swing(context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return
	var owner_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var fwd: Vector3 = (-Basis(Vector3.UP, owner_hero.aim_yaw).z)
	fwd.y = 0.0
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	NetworkManager.broadcast_game_event("pickaxe_swing", {
		"hero_id": owner_hero.entity_id,
		"pos": owner_pos,
		"yaw": owner_hero.aim_yaw,
	})

	var space: PhysicsDirectSpaceState3D = owner_hero.get_world_3d().direct_space_state if (owner_hero.is_inside_tree() and owner_hero.get_world_3d() != null) else null
	var exclude_rids: Array[RID] = [owner_hero.get_rid()]
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var xp_cb: Callable = context.get("on_damage_dealt", Callable())

	for hid_key in heroes_by_id.keys():
		var cand: HeroCharacter = heroes_by_id[hid_key] as HeroCharacter
		if cand == null or not is_instance_valid(cand) or cand.is_defeated:
			continue
		if cand.entity_id == owner_hero.entity_id or cand.team == owner_hero.team:
			continue
		if cand.current_vehicle_id >= 0 and cand.current_seat_enclosed:
			continue
		var cand_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
		if absf(cand_pos.y - owner_pos.y) > 2.2:
			continue
		var to_cand := Vector3(cand_pos.x - owner_pos.x, 0.0, cand_pos.z - owner_pos.z)
		var horiz_dist: float = to_cand.length()
		if horiz_dist > LAST_STAND_RANGE + cand.capsule_radius * 0.5:
			continue
		if horiz_dist > 0.05 and to_cand.normalized().dot(fwd) < 0.35:
			continue
		if space != null and horiz_dist > 0.25:
			var wall_q := PhysicsRayQueryParameters3D.create(
				owner_pos + Vector3(0.0, 1.15, 0.0),
				cand_pos + Vector3(0.0, 1.15, 0.0),
				1,
				exclude_rids
			)
			if not space.intersect_ray(wall_q).is_empty():
				continue

		var hit_pos: Vector3 = cand_pos + Vector3(0.0, 1.15, 0.0)
		var atk_from_target := Vector3(owner_pos.x - cand_pos.x, 0.0, owner_pos.z - cand_pos.z)
		if cand.status_effects != null and cand.status_effects.has_method("is_frontal_carried_shield_block_dir") and cand.status_effects.is_frontal_carried_shield_block_dir(atk_from_target):
			cand.status_effects.damage_carried_shield(LAST_STAND_SWING_DAMAGE)
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": hit_pos,
				"kind": "spark",
				"attacker_id": owner_hero.entity_id,
				"victim_id": cand.entity_id,
				"damage": 0,
				"headshot": false,
			})
			continue

		var dealt: int = cand.apply_damage_server(LAST_STAND_SWING_DAMAGE, owner_hero.entity_id, false)
		if dealt > 0 and xp_cb.is_valid():
			xp_cb.call(owner_hero, cand, dealt)
		NetworkManager.broadcast_game_event("hit_vfx", {
			"pos": hit_pos,
			"kind": "spark",
			"attacker_id": owner_hero.entity_id,
			"victim_id": cand.entity_id,
			"damage": LAST_STAND_SWING_DAMAGE,
			"headshot": false,
		})

	var vehs: Array = context.get("vehicles", [])
	if vehs.is_empty() and owner_hero.is_inside_tree():
		vehs = owner_hero.get_tree().get_nodes_in_group("vehicles")
	for v in vehs:
		if not (v is Node3D) or not v.has_method("apply_damage_server"):
			continue
		if v is VehicleBase and (v as VehicleBase).team >= 0 and (v as VehicleBase).team == owner_hero.team:
			continue
		var v_pos: Vector3 = (v as Node3D).global_position if (v as Node3D).is_inside_tree() else (v as Node3D).position
		var to_v := Vector3(v_pos.x - owner_pos.x, 0.0, v_pos.z - owner_pos.z)
		var v_dist: float = to_v.length()
		if v_dist > LAST_STAND_RANGE + 1.8:
			continue
		if v_dist > 0.25 and to_v.normalized().dot(fwd) < 0.25:
			continue
		v.apply_damage_server(LAST_STAND_SWING_DAMAGE, owner_hero.entity_id, fwd, v_pos, false)

	if owner_hero.is_inside_tree():
		for d in owner_hero.get_tree().get_nodes_in_group("destructible"):
			if not (d is Node3D) or not d.has_method("apply_damage_server"):
				continue
			var d_pos: Vector3 = (d as Node3D).global_position
			var to_d := Vector3(d_pos.x - owner_pos.x, 0.0, d_pos.z - owner_pos.z)
			if to_d.length() <= LAST_STAND_RANGE + 1.2 and (to_d.length() <= 0.25 or to_d.normalized().dot(fwd) >= 0.25):
				d.apply_damage_server(LAST_STAND_SWING_DAMAGE, owner_hero.entity_id, fwd, d_pos, false)
