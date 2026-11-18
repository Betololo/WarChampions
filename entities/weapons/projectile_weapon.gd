class_name ProjectileWeapon
extends WeaponBase

## Projectile launchers and thrown explosives (Bazooka, TNT, Grenade Launcher).
var projectile_speed: float = 46.0
var _active_stickies: Array[ProjectileEntity] = []
var _prev_aim_det_held: bool = false


func _load_weapon_stats() -> void:
	super._load_weapon_stats()
	if weapon_kind == WeaponKind.BAZOOKA:
		projectile_speed = 42.0
	elif weapon_kind == WeaponKind.TNT:
		projectile_speed = 15.0
	elif weapon_kind == WeaponKind.GRENADE_LAUNCHER:
		match clampi(archetype, 0, 2):
			1:
				projectile_speed = 28.0
			2:
				projectile_speed = 72.0
			_:
				projectile_speed = 30.0


func reset_weapon() -> void:
	super.reset_weapon()
	_prev_aim_det_held = false
	_prune_stickies()


func _prune_stickies() -> void:
	var kept: Array[ProjectileEntity] = []
	for s in _active_stickies:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and not s._exploded:
			kept.append(s)
	_active_stickies = kept


func try_detonate_stickies(cmd: InputCmd) -> bool:
	var aim_held: bool = cmd != null and cmd.has_button(InputCmd.BTN_AIM)
	var rising: bool = aim_held and not _prev_aim_det_held
	_prev_aim_det_held = aim_held
	if not rising:
		return false
	if owner_hero == null or owner_hero.is_defeated:
		return false
	if weapon_kind != WeaponKind.GRENADE_LAUNCHER or clampi(archetype, 0, 2) != 1:
		return false
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("is_tnt_rope_active") and owner_hero.status_effects.is_tnt_rope_active():
		return false
	if owner_hero.skill_manager != null and owner_hero.skill_manager.has_method("blocks_weapon_fire") and bool(owner_hero.skill_manager.blocks_weapon_fire()):
		return false

	_prune_stickies()
	var candidates: Array[ProjectileEntity] = []
	for s in _active_stickies:
		candidates.append(s)
	if owner_hero.is_inside_tree():
		for grp_node in owner_hero.get_tree().get_nodes_in_group("destructible_stickies"):
			if grp_node is ProjectileEntity and not candidates.has(grp_node):
				candidates.append(grp_node as ProjectileEntity)

	var detonated_any: bool = false
	for sticky in candidates:
		if not is_instance_valid(sticky) or sticky.is_queued_for_deletion():
			continue
		if sticky.kind != ProjectileEntity.ProjectileKind.TRAPPER_STICKY:
			continue
		if sticky.owner_id != owner_hero.entity_id:
			continue
		if sticky.can_detonate():
			sticky._detonate()
			detonated_any = true
	_prune_stickies()
	return detonated_any


func fire_server(cmd: InputCmd, context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return

	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("break_stealth"):
		owner_hero.status_effects.break_stealth()

	var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
	var lag_comp: LagCompensator = context.get("lag_compensator", null)
	var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
	var aim: Dictionary = get_aim_origin_and_dir(cmd, space_state, lag_comp, heroes_by_id)
	var aim_origin: Vector3 = aim["origin"] as Vector3
	var dir: Vector3 = apply_spread(aim["dir"] as Vector3)
	var origin: Vector3 = aim_origin + dir * 0.55
	if space_state != null:
		var spawn_q := PhysicsRayQueryParameters3D.create(aim_origin, aim_origin + dir * 0.75, 1)
		spawn_q.exclude = [owner_hero.get_rid()]
		var spawn_hit: Dictionary = space_state.intersect_ray(spawn_q)
		if not spawn_hit.is_empty():
			var hit_p: Vector3 = spawn_hit["position"]
			var dist_to_hit: float = aim_origin.distance_to(hit_p)
			if dist_to_hit <= 0.63:
				origin = aim_origin + dir * maxf(0.05, dist_to_hit - 0.08)
	var pkind: int = ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET
	var dmg_override: float = -1.0
	var launch_vel: Vector3 = dir * projectile_speed

	if weapon_kind == WeaponKind.TNT:
		pkind = ProjectileEntity.ProjectileKind.TNT_SATCHEL
		launch_vel += Vector3(0.0, 4.5, 0.0)
	elif weapon_kind == WeaponKind.GRENADE_LAUNCHER:
		var g_arch: int = clampi(archetype, 0, 2)
		var lob_scale: float = clampf(1.0 - maxf(0.0, -dir.y), 0.15, 1.0)
		dmg_override = damage_max
		match g_arch:
			1:
				pkind = ProjectileEntity.ProjectileKind.TRAPPER_STICKY
				launch_vel += Vector3(0.0, 2.2 * lob_scale, 0.0)
			2:
				pkind = ProjectileEntity.ProjectileKind.CANNON_BALL
			_:
				pkind = ProjectileEntity.ProjectileKind.BOUNCE_GRENADE
				launch_vel += Vector3(0.0, 2.4 * lob_scale, 0.0)

	var spawned: ProjectileEntity = ProjectileEntity.spawn_server_projectile(pkind, owner_hero.entity_id, owner_hero.team, origin, launch_vel, context, dmg_override, owner_hero.get_parent())
	if pkind == ProjectileEntity.ProjectileKind.TRAPPER_STICKY and spawned != null:
		_prune_stickies()
		_active_stickies.append(spawned)
		while _active_stickies.size() > 6:
			var oldest: ProjectileEntity = _active_stickies.pop_front()
			if is_instance_valid(oldest) and not oldest.is_queued_for_deletion():
				oldest.destroy_by_enemy(false)

	var end_pos: Vector3 = origin + dir * 20.0
	fired.emit(weapon_kind, origin, end_pos)
	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": weapon_kind,
		"origin": origin,
		"dir": dir,
		"hits": [end_pos],
	})
