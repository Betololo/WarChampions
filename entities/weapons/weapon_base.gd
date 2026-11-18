class_name WeaponBase
extends Node3D

## Base weapon supporting infinite reserve ammo, magazine reload,
## 3 mechanical archetypes (Balanced, Fast/Short, Slow/Long), spread, and damage falloff.

enum WeaponKind {
	SMG,
	MG,
	SHOTGUN,
	PISTOL,
	SNIPER,
	KNIFE,
	BAZOOKA,
	TNT,
	FLAMETHROWER,
	GRENADE_LAUNCHER,
	STICK_GRENADE,
	DUAL_REVOLVERS,
	DUAL_PISTOLS,
	WELDING_TORCH,
}

signal fired(weapon_kind: int, muzzle_pos: Vector3, hit_pos: Vector3)
signal ammo_changed(in_mag: int, mag_size: int, reloading: bool)

var weapon_kind: int = WeaponKind.SMG
var weapon_name: String = "SMG"
var archetype: int = NetworkManager.ARCHETYPE_BALANCED
var owner_hero: HeroCharacter = null

## Base tuning before archetype modifiers
var base_damage_max: float = 16.0
var base_damage_min: float = 9.0
var falloff_start_m: float = 20.0
var falloff_end_m: float = 55.0
var max_range_m: float = 180.0
var base_fire_interval: float = 0.11
var base_mag_size: int = 32
var reload_duration: float = 1.65
var base_spread_rad: float = 0.022
var recoil_rad: float = 0.015
var pellet_count: int = 1
var is_automatic: bool = true
var is_melee: bool = false
var is_sniper: bool = false
var is_explosive_weapon: bool = false
var bullet_speed_mps: float = 150.0
var bullet_gravity_scale: float = 0.0
var base_gravity_mps2: float = 18.0

## Runtime state (Infinite reserve ammo!)
var damage_max: float = 16.0
var damage_min: float = 9.0
var fire_interval: float = 0.11
var mag_size: int = 32
var ammo_in_mag: int = 32
var spread_rad: float = 0.022
var reserve_ammo: int = -1 # -1 represents infinite reserve
var ammo_per_shot: int = 1
var caber_spent: bool = false

var cooldown_timer: float = 0.0
var fire_cooldown: float:
	get:
		return cooldown_timer
	set(val):
		cooldown_timer = val
var reload_timer: float = 0.0
var is_reloading: bool = false
var _prev_fire_held: bool = false
var _burst_bloom: float = 0.0
var _was_first_shot: bool = true


func configure(p_owner: HeroCharacter, p_kind: int, p_archetype: int) -> void:
	owner_hero = p_owner
	weapon_kind = p_kind
	archetype = p_archetype
	_load_weapon_stats()
	_apply_archetype_modifiers()
	ammo_in_mag = mag_size
	_burst_bloom = 0.0
	_was_first_shot = true


func reset_caber_for_life() -> void:
	caber_spent = false


func _load_weapon_stats() -> void:
	ammo_per_shot = 1
	is_melee = false
	is_sniper = false
	is_explosive_weapon = false
	pellet_count = 1
	match weapon_kind:
		WeaponKind.SMG:
			weapon_name = "Submachine Gun"
			base_damage_max = 14.0
			base_damage_min = 7.0
			falloff_start_m = 18.0
			falloff_end_m = 48.0
			max_range_m = 160.0
			base_fire_interval = 0.095
			base_mag_size = 32
			reload_duration = 1.55
			base_spread_rad = 0.024
			recoil_rad = 0.012
			is_automatic = true
			bullet_speed_mps = 135.0
			bullet_gravity_scale = 0.0
		WeaponKind.MG:
			weapon_name = "Heavy Machine Gun"
			base_damage_max = 15.0
			base_damage_min = 8.5
			falloff_start_m = 22.0
			falloff_end_m = 62.0
			max_range_m = 180.0
			base_fire_interval = 0.085
			base_mag_size = 75
			reload_duration = 2.6
			base_spread_rad = 0.032
			recoil_rad = 0.016
			is_automatic = true
			bullet_speed_mps = 145.0
			bullet_gravity_scale = 0.0
		WeaponKind.SHOTGUN:
			weapon_name = "Combat Shotgun"
			base_damage_max = 10.0
			base_damage_min = 3.0
			falloff_start_m = 8.0
			falloff_end_m = 24.0
			max_range_m = 45.0
			base_fire_interval = 0.72
			base_mag_size = 8
			reload_duration = 1.85
			base_spread_rad = 0.075
			recoil_rad = 0.055
			pellet_count = 8
			is_automatic = false
			bullet_speed_mps = 105.0
			bullet_gravity_scale = 0.0
		WeaponKind.PISTOL:
			weapon_name = "Service Pistol"
			base_damage_max = 19.0
			base_damage_min = 10.0
			falloff_start_m = 15.0
			falloff_end_m = 42.0
			max_range_m = 120.0
			base_fire_interval = 0.24
			base_mag_size = 12
			reload_duration = 1.25
			base_spread_rad = 0.015
			recoil_rad = 0.022
			is_automatic = false
			bullet_speed_mps = 120.0
			bullet_gravity_scale = 0.0
		WeaponKind.SNIPER:
			weapon_name = "Sniper Rifle"
			base_damage_max = 46.0
			base_damage_min = 34.0
			falloff_start_m = 120.0
			falloff_end_m = 400.0
			max_range_m = 1500.0
			base_fire_interval = 1.1
			base_mag_size = 5
			reload_duration = 2.0
			base_spread_rad = 0.002
			recoil_rad = 0.06
			is_automatic = false
			is_sniper = true
			bullet_speed_mps = 195.0
			bullet_gravity_scale = 0.0
		WeaponKind.KNIFE:
			weapon_name = "Commando Knife"
			base_damage_max = 42.0
			base_damage_min = 42.0
			falloff_start_m = 3.6
			falloff_end_m = 4.0
			max_range_m = 3.8
			base_fire_interval = 0.48
			base_mag_size = 1
			reload_duration = 0.0
			base_spread_rad = 0.0
			recoil_rad = 0.0
			is_automatic = false
			is_melee = true
			bullet_speed_mps = 100.0
			bullet_gravity_scale = 0.0
		WeaponKind.BAZOOKA:
			weapon_name = "Bazooka"
			base_damage_max = 65.0
			base_damage_min = 25.0
			falloff_start_m = 100.0
			falloff_end_m = 200.0
			max_range_m = 250.0
			base_fire_interval = 1.6
			base_mag_size = 3
			reload_duration = 2.4
			base_spread_rad = 0.008
			recoil_rad = 0.075
			is_automatic = false
			is_explosive_weapon = true
		WeaponKind.TNT:
			weapon_name = "TNT Satchel"
			base_damage_max = 85.0
			base_damage_min = 20.0
			falloff_start_m = 30.0
			falloff_end_m = 60.0
			max_range_m = 35.0
			base_fire_interval = 1.2
			base_mag_size = 2
			reload_duration = 2.8
			base_spread_rad = 0.01
			recoil_rad = 0.02
			is_automatic = false
			is_explosive_weapon = true
		WeaponKind.FLAMETHROWER:
			var f_arch: int = clampi(archetype, 0, 2)
			base_mag_size = 100
			base_spread_rad = 0.035
			recoil_rad = 0.005
			bullet_gravity_scale = 0.0
			match f_arch:
				1:
					weapon_name = "Fire Starter"
					base_damage_max = 10.0
					base_damage_min = 10.0
					falloff_start_m = 21.0
					falloff_end_m = 21.0
					max_range_m = 21.0
					base_fire_interval = 0.25
					reload_duration = 2.2
					is_automatic = true
					ammo_per_shot = 5
				2:
					weapon_name = "Fire Breath"
					base_damage_max = 40.0
					base_damage_min = 40.0
					falloff_start_m = 32.0
					falloff_end_m = 32.0
					max_range_m = 32.0
					base_fire_interval = 0.50
					reload_duration = 2.3
					base_spread_rad = 0.012
					recoil_rad = 0.035
					is_automatic = false
					ammo_per_shot = 10
					bullet_speed_mps = 45.0
				_:
					weapon_name = "Flamethrower"
					base_damage_max = 10.0
					base_damage_min = 10.0
					falloff_start_m = 21.0
					falloff_end_m = 21.0
					max_range_m = 21.0
					base_fire_interval = 0.10
					reload_duration = 2.1
					is_automatic = true
					ammo_per_shot = 1
		WeaponKind.GRENADE_LAUNCHER:
			var g_arch: int = clampi(archetype, 0, 2)
			is_explosive_weapon = true
			is_automatic = false
			falloff_start_m = 40.0
			falloff_end_m = 90.0
			max_range_m = 120.0
			base_spread_rad = 0.01
			recoil_rad = 0.045
			match g_arch:
				1:
					weapon_name = "Trapper"
					base_mag_size = 6
					base_fire_interval = 0.52
					reload_duration = 2.1
					base_damage_max = 40.0
					base_damage_min = 40.0
				2:
					weapon_name = "Canhão"
					base_mag_size = 1
					base_fire_interval = 0.90
					reload_duration = 2.0
					base_damage_max = 100.0
					base_damage_min = 100.0
				_:
					weapon_name = "Lança-Granadas"
					base_mag_size = 6
					base_fire_interval = 0.62
					reload_duration = 2.2
					base_damage_max = 60.0
					base_damage_min = 60.0
		WeaponKind.STICK_GRENADE:
			weapon_name = "Granada de Cabo"
			base_damage_max = 35.0
			base_damage_min = 35.0
			falloff_start_m = 3.0
			falloff_end_m = 3.4
			max_range_m = 3.2
			base_fire_interval = 0.68
			base_mag_size = 1
			reload_duration = 0.0
			base_spread_rad = 0.0
			recoil_rad = 0.0
			is_automatic = false
			is_melee = true
			bullet_speed_mps = 100.0
			bullet_gravity_scale = 0.0
		WeaponKind.DUAL_REVOLVERS:
			weapon_name = "2 Revólveres"
			base_damage_max = 18.0
			base_damage_min = 11.0
			falloff_start_m = 16.0
			falloff_end_m = 45.0
			max_range_m = 125.0
			base_fire_interval = 0.22
			base_mag_size = 12
			reload_duration = 1.55
			base_spread_rad = 0.016
			recoil_rad = 0.022
			is_automatic = false
			bullet_speed_mps = 125.0
			bullet_gravity_scale = 0.0
		WeaponKind.DUAL_PISTOLS:
			weapon_name = "2 Pistolas"
			base_damage_max = 12.0
			base_damage_min = 6.5
			falloff_start_m = 14.0
			falloff_end_m = 40.0
			max_range_m = 115.0
			base_fire_interval = 0.13
			base_mag_size = 24
			reload_duration = 1.45
			base_spread_rad = 0.022
			recoil_rad = 0.015
			is_automatic = true
			bullet_speed_mps = 120.0
			bullet_gravity_scale = 0.0
		WeaponKind.WELDING_TORCH:
			weapon_name = "Maçarico de Solda"
			base_damage_max = 10.0
			base_damage_min = 10.0
			falloff_start_m = 3.6
			falloff_end_m = 3.6
			max_range_m = 3.6
			base_fire_interval = 0.12
			base_mag_size = 100
			reload_duration = 1.50
			base_spread_rad = 0.0
			recoil_rad = 0.0
			is_automatic = true
			bullet_speed_mps = 100.0
			bullet_gravity_scale = 0.0


static func get_variant_display_name(w_kind: int, p_archetype: int) -> String:
	var arch: int = clampi(p_archetype, 0, 2)
	match w_kind:
		WeaponKind.SMG:
			return ["Tommy Submachine", "Sten Rápida (Curto)", "MP-41 Pesada (Longo)"][arch]
		WeaponKind.MG:
			return ["Metralhadora Padrão", "Serra-Ossos (Cadência)", "Bren Precisão (Longo)"][arch]
		WeaponKind.SHOTGUN:
			return ["Escopeta Combate", "Trench Cano Serrado", "Slug Longo Alcance"][arch]
		WeaponKind.PISTOL:
			return ["Pistola de Serviço", "Automática Ágil", "Revólver Pesado .44"][arch]
		WeaponKind.SNIPER:
			return ["Rifle Sniper Padrão", "Carabina Semi-Auto", "K98k Super Dano"][arch]
		WeaponKind.KNIFE:
			return ["Faca Tática", "Estilete Rápido", "Kukri Pesado"][arch]
		WeaponKind.BAZOOKA:
			return ["Bazooka M1", "Lança-Foguete Ágil", "Super Bazooka M9"][arch]
		WeaponKind.TNT:
			return ["Carga TNT", "Dinamite Leve", "Satchel Pesada"][arch]
		WeaponKind.FLAMETHROWER:
			return ["Flamethrower", "Fire Starter", "Fire Breath"][arch]
		WeaponKind.GRENADE_LAUNCHER:
			return ["Lança-Granadas", "Trapper", "Canhão"][arch]
		WeaponKind.STICK_GRENADE:
			return "Granada de Cabo"
		WeaponKind.DUAL_REVOLVERS:
			return "2 Revólveres"
		WeaponKind.DUAL_PISTOLS:
			return "2 Pistolas"
		WeaponKind.WELDING_TORCH:
			return "Maçarico de Solda"
	return "Arma"


func _apply_archetype_modifiers() -> void:
	weapon_name = get_variant_display_name(weapon_kind, archetype)
	damage_max = base_damage_max
	damage_min = base_damage_min
	fire_interval = base_fire_interval
	mag_size = base_mag_size
	spread_rad = base_spread_rad

	if (
		is_explosive_weapon
		or weapon_kind == WeaponKind.FLAMETHROWER
		or weapon_kind == WeaponKind.GRENADE_LAUNCHER
		or weapon_kind == WeaponKind.STICK_GRENADE
		or weapon_kind == WeaponKind.DUAL_REVOLVERS
		or weapon_kind == WeaponKind.DUAL_PISTOLS
		or weapon_kind == WeaponKind.WELDING_TORCH
	):
		return

	if is_melee:
		match archetype:
			NetworkManager.ARCHETYPE_FAST_SHORT:
				fire_interval = base_fire_interval * 0.72
				damage_max = base_damage_max * 0.85
				damage_min = damage_max
			NetworkManager.ARCHETYPE_SLOW_LONG:
				fire_interval = base_fire_interval * 1.25
				damage_max = base_damage_max * 1.28
				damage_min = damage_max
		return

	match archetype:
		NetworkManager.ARCHETYPE_BALANCED:
			pass
		NetworkManager.ARCHETYPE_FAST_SHORT:
			# Huge mag, rapid fire, wider spread, faster dropoff
			mag_size = int(ceilf(float(base_mag_size) * 1.5))
			fire_interval = base_fire_interval * 0.68
			damage_max = base_damage_max * 0.85
			damage_min = base_damage_min * 0.60
			falloff_start_m = base_falloff_scale(0.65)
			falloff_end_m = falloff_end_m * 0.68
			spread_rad = base_spread_rad * 1.45
		NetworkManager.ARCHETYPE_SLOW_LONG:
			# Smaller mag, slower cadence, surgical accuracy, high damage at range
			mag_size = maxi(2, int(roundf(float(base_mag_size) * 0.78)))
			fire_interval = base_fire_interval * 1.32
			damage_max = base_damage_max * 1.28
			damage_min = base_damage_min * 1.42
			falloff_start_m = falloff_start_m * 1.45
			falloff_end_m = falloff_end_m * 1.45
			spread_rad = base_spread_rad * 0.45


func base_falloff_scale(mult: float) -> float:
	return falloff_start_m * mult


func _get_haste_fire_mult() -> float:
	if owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_haste_fire_mult"):
		return maxf(1.0, float(owner_hero.status_effects.get_haste_fire_mult()))
	return 1.0


func _get_haste_reload_mult() -> float:
	if owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.has_method("get_haste_reload_mult"):
		return maxf(1.0, float(owner_hero.status_effects.get_haste_reload_mult()))
	return 1.0


func _is_fire_blocked_by_tnt_rope() -> bool:
	if owner_hero == null:
		return false
	if (owner_hero.active_buffs & NetSerializer.BUFF_TNT_ROPE) != 0:
		return true
	if owner_hero.status_effects != null and owner_hero.status_effects.has_method("is_tnt_rope_active") and bool(owner_hero.status_effects.is_tnt_rope_active()):
		return true
	if owner_hero.skill_manager != null and owner_hero.skill_manager.has_method("blocks_weapon_fire"):
		return bool(owner_hero.skill_manager.blocks_weapon_fire())
	return false


func step_timers(delta: float, cmd: InputCmd) -> void:
	var fire_mult: float = _get_haste_fire_mult()
	var reload_mult: float = _get_haste_reload_mult()

	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta * fire_mult)

	# Decay over 0.85s so automatic SMG/MG fire builds continuous bloom (~0.10-0.11 decay vs +0.24/shot)
	# while slow-cadence Pistol (>=0.24s) and Sniper (1.1s) naturally reset cleanly between shots.
	_burst_bloom = maxf(0.0, _burst_bloom - delta / 0.85)
	if _burst_bloom <= 0.05:
		_was_first_shot = true

	if is_reloading:
		reload_timer -= delta * reload_mult
		if reload_timer <= 0.0:
			is_reloading = false
			ammo_in_mag = mag_size
			ammo_changed.emit(ammo_in_mag, mag_size, false)
	elif not is_melee and cmd.has_button(InputCmd.BTN_RELOAD) and ammo_in_mag < mag_size:
		start_reload()


func start_reload() -> void:
	if is_melee or is_reloading or ammo_in_mag >= mag_size:
		return
	is_reloading = true
	reload_timer = reload_duration
	_burst_bloom = 0.0
	_was_first_shot = true
	ammo_changed.emit(ammo_in_mag, mag_size, true)


func try_consume_fire(cmd: InputCmd) -> bool:
	var fire_held: bool = cmd.has_button(InputCmd.BTN_FIRE)
	var wants_fire: bool = fire_held if is_automatic else (fire_held and not _prev_fire_held)
	_prev_fire_held = fire_held

	if _is_fire_blocked_by_tnt_rope():
		return false

	if not wants_fire or is_reloading or cooldown_timer > 0.0:
		return false

	if not is_melee and ammo_in_mag < ammo_per_shot:
		start_reload()
		return false

	_was_first_shot = (_burst_bloom <= 0.05)
	var bloom_step: float = 0.24 if is_automatic else 0.25
	_burst_bloom = minf(1.0, _burst_bloom + bloom_step)

	cooldown_timer = fire_interval
	if not is_melee:
		ammo_in_mag = maxi(0, ammo_in_mag - ammo_per_shot)
		ammo_changed.emit(ammo_in_mag, mag_size, false)
		if ammo_in_mag < ammo_per_shot:
			start_reload()
	return true


func is_first_shot() -> bool:
	return _was_first_shot or _burst_bloom <= 0.05


func get_current_spread_mult(is_aiming: bool = false, has_frenzy_fire: bool = false, is_crouching: bool = false) -> float:
	var crouch_mult: float = 0.55 if is_crouching else 1.0
	if pellet_count > 1:
		return 1.0 * crouch_mult
	if is_sniper and is_aiming:
		return 0.0
	# First shot (and fully settled tap-fire) is always 100% pinpoint across all non-pellet weapons
	if is_first_shot():
		return 0.0
	# Automatic weapons (SMG / MG) ramp up genuine bullet spread during sustained fire
	if is_automatic:
		var auto_mult: float = lerpf(0.70, 1.85, _burst_bloom)
		if weapon_kind == WeaponKind.MG and has_frenzy_fire:
			auto_mult *= 0.45
		return auto_mult * crouch_mult
	# Semi-auto / bolt follow-up shots before bloom settles
	return lerpf(0.25, 1.0, _burst_bloom) * crouch_mult


func reset_weapon() -> void:
	ammo_in_mag = mag_size
	is_reloading = false
	reload_timer = 0.0
	cooldown_timer = 0.0
	_burst_bloom = 0.0
	_was_first_shot = true
	_prev_fire_held = false
	caber_spent = false
	ammo_changed.emit(ammo_in_mag, mag_size, false)


func compute_falloff_damage(distance_m: float, is_headshot: bool, bonus_mult: float = 1.0) -> int:
	var t: float = clampf((distance_m - falloff_start_m) / maxf(falloff_end_m - falloff_start_m, 0.01), 0.0, 1.0)
	var dmg: float = lerpf(damage_max, damage_min, t)
	if is_headshot and not is_melee:
		var hs_mult: float = 1.7 if weapon_kind == WeaponKind.SNIPER else 1.5
		dmg *= hs_mult
	dmg *= bonus_mult
	return maxi(1, int(roundf(dmg)))


func get_aim_origin_and_dir(
	cmd: InputCmd,
	space_state: PhysicsDirectSpaceState3D = null,
	lag_comp: LagCompensator = null,
	heroes_by_id: Dictionary = {},
	hand_side: int = 0
) -> Dictionary:
	var crouch: bool = owner_hero != null and owner_hero.is_crouching
	var eye_offset: float = 1.05 if crouch else 1.52
	if owner_hero == null:
		var fallback_origin: Vector3 = global_position + Vector3(0.0, eye_offset, 0.0)
		var fallback_basis := Basis.from_euler(Vector3(cmd.aim_pitch, cmd.aim_yaw, 0.0))
		return {"origin": fallback_origin, "dir": (-fallback_basis.z).normalized()}

	var hero_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var in_vehicle: bool = owner_hero.current_vehicle_id >= 0
	var scoped: bool = owner_hero.is_scoping or (is_sniper and cmd.has_button(InputCmd.BTN_AIM) and not in_vehicle)
	var cam_ray: Dictionary = HeroCamera.compute_aim_ray(hero_pos, cmd.aim_yaw, cmd.aim_pitch, scoped, in_vehicle, crouch)
	var cam_origin: Vector3 = cam_ray["origin"]
	var cam_dir: Vector3 = cam_ray["dir"]

	if scoped:
		return {"origin": cam_origin, "dir": cam_dir}

	var aim_basis := Basis.from_euler(Vector3(cmd.aim_pitch, cmd.aim_yaw, 0.0))
	var right_vec: Vector3 = aim_basis.x.normalized()
	var fwd_vec: Vector3 = (-aim_basis.z).normalized()
	var side_sign: float = -1.0 if hand_side == 1 else 1.0
	var origin: Vector3 = hero_pos + Vector3(0.0, eye_offset, 0.0) + right_vec * (0.24 * side_sign) - fwd_vec * 0.25

	var pivot_pt: Vector3 = cam_ray.get("pivot", cam_origin)
	var spring_len: float = float(cam_ray.get("spring_length", 0.0))
	var convergence_range: float = clampf(spring_len + maxf(max_range_m, 30.0), spring_len + 2.0, maxf(260.0, max_range_m))
	var min_dist: float = maxf(1.4, spring_len + 0.45)

	var best_hit_dist: float = convergence_range
	var target_pt: Vector3 = cam_origin + cam_dir * convergence_range

	if space_state != null:
		var ray_end: Vector3 = cam_origin + cam_dir * convergence_range
		var mask: int = (1 | 8 | 64) if lag_comp != null else (1 | 2 | 8 | 64)
		var query := PhysicsRayQueryParameters3D.create(pivot_pt, ray_end, mask)
		query.hit_from_inside = true
		var excludes: Array[RID] = [owner_hero.get_rid()]
		if in_vehicle and owner_hero.is_inside_tree():
			for v_node in owner_hero.get_tree().get_nodes_in_group("vehicles"):
				if v_node is VehicleBase and (v_node as VehicleBase).id == owner_hero.current_vehicle_id:
					excludes.append((v_node as CollisionObject3D).get_rid())
					if v_node.has_method("get_shield_rid"):
						var s_rid: RID = v_node.get_shield_rid()
						if s_rid.is_valid():
							excludes.append(s_rid)
		query.exclude = excludes
		var hit: Dictionary = space_state.intersect_ray(query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"]
			var dist_from_cam: float = (hit_pos - cam_origin).dot(cam_dir)
			if dist_from_cam < best_hit_dist:
				best_hit_dist = dist_from_cam
				target_pt = hit_pos

	if lag_comp != null and best_hit_dist - spring_len > 0.001:
		var hero_hit: Dictionary = lag_comp.find_closest_rewound_hero_hit(
			owner_hero,
			pivot_pt,
			cam_dir,
			best_hit_dist - spring_len,
			cmd.view_interp_tick_delta,
			NetworkManager.server_tick,
			heroes_by_id
		)
		if bool(hero_hit.get("hit", false)):
			var h_pos: Vector3 = hero_hit["pos"]
			var dist_from_cam: float = (h_pos - cam_origin).dot(cam_dir)
			if dist_from_cam < best_hit_dist:
				best_hit_dist = dist_from_cam
				target_pt = h_pos

	if best_hit_dist < min_dist:
		target_pt = cam_origin + cam_dir * min_dist

	var dir: Vector3 = (target_pt - origin).normalized()
	return {"origin": origin, "dir": dir}


func apply_spread(dir: Vector3, spread_mult: float = 1.0) -> Vector3:
	var s: float = spread_rad * spread_mult
	if s <= 0.0001:
		return dir
	var ang: float = randf_range(0.0, TAU)
	var rad: float = sqrt(randf()) * s
	var rx: float = cos(ang) * rad
	var ry: float = sin(ang) * rad
	var right: Vector3 = dir.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	else:
		right = right.normalized()
	var up: Vector3 = right.cross(dir).normalized()
	return (dir + right * rx + up * ry).normalized()


## Overridden by HitscanWeapon and ProjectileWeapon
func fire_server(_cmd: InputCmd, _context: Dictionary) -> void:
	pass
