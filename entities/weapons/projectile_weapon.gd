class_name ProjectileWeapon
extends WeaponBase

## Projectile launchers and thrown explosives (Bazooka, TNT).
var projectile_speed: float = 46.0


func _load_weapon_stats() -> void:
	super._load_weapon_stats()
	if weapon_kind == WeaponKind.BAZOOKA:
		projectile_speed = 42.0
	elif weapon_kind == WeaponKind.TNT:
		projectile_speed = 15.0


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
	var origin: Vector3 = aim["origin"] + (aim["dir"] as Vector3) * 0.9
	var dir: Vector3 = apply_spread(aim["dir"])
	var pkind: int = ProjectileEntity.ProjectileKind.BAZOOKA_ROCKET if weapon_kind == WeaponKind.BAZOOKA else ProjectileEntity.ProjectileKind.TNT_SATCHEL

	var launch_vel: Vector3 = dir * projectile_speed
	if pkind == ProjectileEntity.ProjectileKind.TNT_SATCHEL:
		launch_vel += Vector3(0.0, 4.5, 0.0)
	ProjectileEntity.spawn_server_projectile(pkind, owner_hero.entity_id, owner_hero.team, origin, launch_vel, context, -1.0, owner_hero.get_parent())

	var end_pos: Vector3 = origin + dir * 20.0
	fired.emit(weapon_kind, origin, end_pos)
	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": weapon_kind,
		"origin": origin,
		"dir": dir,
		"hits": [end_pos],
	})
