class_name DemolisherSkills
extends SkillManager

## Demolisher's 5 Heroic Skills:
## 0: Escudo Balístico (Riot Shield), 1: Haste, 2: Corda de TNTs (TNT Rope),
## 3: Dreno de Escudo (Damage -> Temp Shield), 4: Quebra-Tanques (3x Vehicle Damage)

var _prev_tnt_fire_held: bool = false
var _suppress_fire_until_release: bool = false


func _ready() -> void:
	super._ready()
	skill_names = ["Escudo Balístico", "Haste", "Corda de TNTs", "Dreno de Escudo", "Quebra-Tanques"]
	skill_ranks = [5, 5, 5, 5, 5]
	skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0]
	skill_max_cooldowns = [16.0, 16.0, 15.0, 17.0, 18.0]


func _defers_cooldown_until_exit(slot_idx: int) -> bool:
	return slot_idx == 2


func blocks_weapon_fire() -> bool:
	if _suppress_fire_until_release:
		return true
	return owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.tnt_rope_active


func step_server(delta: float, cmd: InputCmd, context: Dictionary) -> void:
	if _suppress_fire_until_release and (cmd == null or not cmd.has_button(InputCmd.BTN_FIRE)):
		_suppress_fire_until_release = false

	var was_tnt_active: bool = (
		owner_hero != null
		and not owner_hero.is_defeated
		and owner_hero.status_effects != null
		and owner_hero.status_effects.tnt_rope_active
	)

	super.step_server(delta, cmd, context)

	if owner_hero == null or owner_hero.is_defeated or owner_hero.status_effects == null:
		_prev_tnt_fire_held = false
		_suppress_fire_until_release = false
		return

	if was_tnt_active and owner_hero.status_effects.tnt_rope_active and cmd != null:
		var fire_held: bool = cmd.has_button(InputCmd.BTN_FIRE)
		if fire_held and not _prev_tnt_fire_held:
			throw_tnt_rope(cmd, context)
			_suppress_fire_until_release = true
		_prev_tnt_fire_held = fire_held
	elif owner_hero.status_effects.tnt_rope_active and cmd != null:
		_prev_tnt_fire_held = cmd.has_button(InputCmd.BTN_FIRE)
	else:
		_prev_tnt_fire_held = false


func throw_tnt_rope(cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null or owner_hero.is_defeated or owner_hero.status_effects == null:
		return false
	if not owner_hero.status_effects.tnt_rope_active:
		return false

	var aim_yaw_val: float = cmd.aim_yaw if cmd != null else owner_hero.aim_yaw
	var aim_pitch_val: float = cmd.aim_pitch if cmd != null else owner_hero.aim_pitch
	var origin: Vector3
	var dir: Vector3
	if not owner_hero.weapons.is_empty() and owner_hero.weapons[0] is WeaponBase:
		var world_3d: World3D = owner_hero.get_world_3d() if owner_hero.is_inside_tree() else null
		var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state if world_3d != null else null
		var lag_comp: LagCompensator = context.get("lag_compensator", null)
		var heroes_by_id: Dictionary = context.get("heroes_by_id", {})
		var aim_cmd := cmd if cmd != null else InputCmd.new()
		var aim: Dictionary = (owner_hero.weapons[0] as WeaponBase).get_aim_origin_and_dir(aim_cmd, space_state, lag_comp, heroes_by_id)
		dir = aim["dir"] as Vector3
		origin = (aim["origin"] as Vector3) + dir * 0.9
	else:
		var h_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
		var aim_basis := Basis.from_euler(Vector3(aim_pitch_val, aim_yaw_val, 0.0))
		dir = (-aim_basis.z).normalized()
		origin = h_pos + Vector3(0.0, 1.45, 0.0) + dir * 0.9

	var launch_vel: Vector3 = dir * 18.0 + Vector3(0.0, 5.0, 0.0)
	ProjectileEntity.spawn_server_projectile(
		ProjectileEntity.ProjectileKind.TNT_SATCHEL,
		owner_hero.entity_id,
		owner_hero.team,
		origin,
		launch_vel,
		context,
		110.0,
		owner_hero.get_parent()
	)

	owner_hero.status_effects.clear_tnt_rope()
	_suppress_fire_until_release = true
	if skill_cooldowns.size() > 2 and skill_max_cooldowns.size() > 2:
		skill_cooldowns[2] = skill_max_cooldowns[2]
		skill_activated.emit(2, skill_cooldowns[2])
	NetworkManager.broadcast_game_event("shot_vfx", {
		"shooter_id": owner_hero.entity_id,
		"weapon_kind": WeaponBase.WeaponKind.TNT,
		"origin": origin,
		"dir": dir,
		"hits": [origin + dir * 12.0],
	})
	return true


class FirePatchEntity extends Node3D:
	var owner_id: int = -1
	var owner_team: int = 0
	var max_lifetime: float = 6.0
	var radius: float = 2.6
	var _lifetime_elapsed: float = 0.0
	var _contact_cooldowns: Dictionary = {}
	var _context: Dictionary = {}
	var _is_visual_only: bool = false

	static var _shared_disc_mesh: CylinderMesh = null
	static var _shared_flame_mesh: CylinderMesh = null
	static var _shared_disc_mat: StandardMaterial3D = null
	static var _shared_flame_mat: StandardMaterial3D = null

	func _ready() -> void:
		add_to_group("fire_patches")
		_is_visual_only = bool(get_meta("visual_only", false))
		_build_visuals()

	func _build_visuals() -> void:
		if _shared_disc_mesh == null:
			_shared_disc_mesh = CylinderMesh.new()
			_shared_disc_mesh.top_radius = 1.0
			_shared_disc_mesh.bottom_radius = 1.0
			_shared_disc_mesh.height = 0.06
			_shared_disc_mesh.radial_segments = 14
		if _shared_flame_mesh == null:
			_shared_flame_mesh = CylinderMesh.new()
			_shared_flame_mesh.top_radius = 0.02
			_shared_flame_mesh.bottom_radius = 0.28
			_shared_flame_mesh.height = 0.65
			_shared_flame_mesh.radial_segments = 8
		if _shared_disc_mat == null:
			_shared_disc_mat = StandardMaterial3D.new()
			_shared_disc_mat.albedo_color = Color(0.95, 0.36, 0.06, 0.55)
			_shared_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if _shared_flame_mat == null:
			_shared_flame_mat = StandardMaterial3D.new()
			_shared_flame_mat.albedo_color = Color(1.0, 0.72, 0.14, 0.85)
			_shared_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_shared_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

		var disc := MeshInstance3D.new()
		disc.mesh = _shared_disc_mesh
		disc.material_override = _shared_disc_mat
		disc.scale = Vector3(radius, 1.0, radius)
		disc.position = Vector3(0.0, 0.04, 0.0)
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(disc)

		for i in range(5):
			var ang: float = float(i) * (TAU / 5.0)
			var r_off: float = radius * 0.48 if i > 0 else 0.0
			var tongue := MeshInstance3D.new()
			tongue.mesh = _shared_flame_mesh
			tongue.material_override = _shared_flame_mat
			tongue.position = Vector3(cos(ang) * r_off, 0.32, sin(ang) * r_off)
			tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tongue)

	func _physics_process(delta: float) -> void:
		step_hazard(delta, _context)

	func step_hazard(delta: float, context: Dictionary = {}) -> void:
		_lifetime_elapsed += delta
		if _lifetime_elapsed >= max_lifetime:
			queue_free()
			return
		if _is_visual_only or not NetworkManager.is_server_authority():
			return

		for hid_key in _contact_cooldowns.keys():
			var cd: float = float(_contact_cooldowns[hid_key]) - delta
			_contact_cooldowns[hid_key] = maxf(0.0, cd)

		var eff_ctx: Dictionary = context if not context.is_empty() else _context
		var heroes_by_id: Dictionary = eff_ctx.get("heroes_by_id", {})
		var self_pos: Vector3 = global_position if is_inside_tree() else position
		var owner_hero: HeroCharacter = heroes_by_id.get(owner_id, null) as HeroCharacter

		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
			if h == null or not is_instance_valid(h) or h.is_defeated:
				continue
			if h.team == owner_team:
				continue
			if h.is_in_water:
				continue
			if h.status_effects != null and h.status_effects.fire_immunity_timer > 0.0:
				continue

			var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
			var horiz_dist: float = Vector2(h_pos.x - self_pos.x, h_pos.z - self_pos.z).length()
			if horiz_dist > radius or absf(h_pos.y - self_pos.y) > 2.2:
				continue

			var hid: int = h.entity_id
			if not _contact_cooldowns.has(hid):
				var dealt: int = h.apply_damage_server(20, owner_id, false)
				if dealt > 0:
					if owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.has_method("notify_damage_dealt_server"):
						owner_hero.status_effects.notify_damage_dealt_server(dealt)
					NetworkManager.broadcast_game_event("hit_vfx", {
						"pos": h_pos + Vector3(0.0, 1.2, 0.0),
						"kind": "fire",
						"attacker_id": owner_id,
						"victim_id": hid,
						"damage": dealt,
					})
				if h.status_effects != null and h.status_effects.has_method("apply_burn"):
					h.status_effects.apply_burn(owner_id, 10.0, 3.0)
				_contact_cooldowns[hid] = 0.5
			elif float(_contact_cooldowns[hid]) <= 0.0:
				if h.status_effects != null and h.status_effects.has_method("apply_burn"):
					h.status_effects.apply_burn(owner_id, 10.0, 3.0)
				_contact_cooldowns[hid] = 0.5

	static func extinguish_near(pos: Vector3, extinguish_radius: float, root: Node) -> int:
		var extinguished: int = 0
		var candidates: Array[FirePatchEntity] = []
		if root != null and is_instance_valid(root):
			for child in root.get_children():
				if child is FirePatchEntity:
					candidates.append(child as FirePatchEntity)
			if root.is_inside_tree():
				for grp_node in root.get_tree().get_nodes_in_group("fire_patches"):
					if grp_node is FirePatchEntity and not candidates.has(grp_node):
						candidates.append(grp_node as FirePatchEntity)
		for fp in candidates:
			if not is_instance_valid(fp) or fp.is_queued_for_deletion():
				continue
			var fp_pos: Vector3 = fp.global_position if fp.is_inside_tree() else fp.position
			if fp_pos.distance_to(pos) <= extinguish_radius:
				fp.queue_free()
				extinguished += 1
		if extinguished > 0 and NetworkManager.is_server_authority():
			NetworkManager.broadcast_game_event("fire_patch_extinguish", {
				"pos": pos,
				"radius": extinguish_radius,
			})
		return extinguished


class RiotShieldEntity extends StaticBody3D:
	var max_hp: int = 150
	var hp: int = 150
	var owner_id: int = -1
	var owner_team: int = 0
	var shield_uid: int = 0
	var lifetime_remaining: float = 25.0
	var _context: Dictionary = {}
	var _is_visual_only: bool = false

	static var _shared_plate_mesh: BoxMesh = null
	static var _shared_trim_mesh: BoxMesh = null
	static var _shared_glass_mesh: BoxMesh = null
	static var _shared_steel_mat: StandardMaterial3D = null
	static var _shared_glass_mat: StandardMaterial3D = null

	func _ready() -> void:
		_is_visual_only = bool(get_meta("visual_only", false))
		if _is_visual_only:
			collision_layer = 0
			collision_mask = 0
		else:
			collision_layer = 1 | 64
			collision_mask = 1 | 2 | 8
			add_to_group("destructible")
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.85, 1.90, 0.24)
			col.shape = shape
			col.position = Vector3(0.0, 0.95, 0.0)
			add_child(col)
		_build_visuals()

	func _build_visuals() -> void:
		if _shared_plate_mesh == null:
			_shared_plate_mesh = BoxMesh.new()
			_shared_plate_mesh.size = Vector3(1.82, 1.32, 0.14)
		if _shared_trim_mesh == null:
			_shared_trim_mesh = BoxMesh.new()
			_shared_trim_mesh.size = Vector3(1.88, 0.20, 0.18)
		if _shared_glass_mesh == null:
			_shared_glass_mesh = BoxMesh.new()
			_shared_glass_mesh.size = Vector3(1.16, 0.34, 0.10)
		if _shared_steel_mat == null:
			_shared_steel_mat = StandardMaterial3D.new()
			_shared_steel_mat.albedo_color = Color(0.22, 0.25, 0.30)
			_shared_steel_mat.roughness = 0.45
			_shared_steel_mat.metallic = 0.45
		if _shared_glass_mat == null:
			_shared_glass_mat = StandardMaterial3D.new()
			_shared_glass_mat.albedo_color = Color(0.45, 0.80, 0.98, 0.55)
			_shared_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_glass_mat.roughness = 0.15

		var lower_plate := MeshInstance3D.new()
		lower_plate.mesh = _shared_plate_mesh
		lower_plate.material_override = _shared_steel_mat
		lower_plate.position = Vector3(0.0, 0.68, 0.0)
		lower_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lower_plate)

		var top_bar := MeshInstance3D.new()
		top_bar.mesh = _shared_trim_mesh
		top_bar.material_override = _shared_steel_mat
		top_bar.position = Vector3(0.0, 1.78, 0.0)
		top_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(top_bar)

		var team_col: Color = Color(0.20, 0.50, 0.90) if owner_team == NetworkManager.TEAM_ROYAL else Color(0.84, 0.20, 0.20)
		var team_mat := HeroMeshBuilder.make_sculpted_mat(team_col, "", 0.50)
		var stripe := MeshInstance3D.new()
		stripe.mesh = _shared_trim_mesh
		stripe.material_override = team_mat
		stripe.position = Vector3(0.0, 0.95, 0.0)
		stripe.scale = Vector3(0.96, 0.70, 1.05)
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stripe)

		var viewport_glass := MeshInstance3D.new()
		viewport_glass.mesh = _shared_glass_mesh
		viewport_glass.material_override = _shared_glass_mat
		viewport_glass.position = Vector3(0.0, 1.50, 0.0)
		viewport_glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(viewport_glass)

	func _physics_process(delta: float) -> void:
		lifetime_remaining -= delta
		if lifetime_remaining <= 0.0:
			if not _is_visual_only and NetworkManager.is_server_authority() and shield_uid != 0:
				NetworkManager.broadcast_game_event("riot_shield_destroyed", {"shield_uid": shield_uid})
			queue_free()

	func apply_damage_server(dmg: int, attacker_id: int, arg3: Variant = -1, _hit_pos: Vector3 = Vector3.ZERO, _is_explosive: bool = false) -> void:
		if _is_visual_only or dmg <= 0 or hp <= 0:
			return
		var attacker_team: int = -1
		if arg3 is int:
			attacker_team = int(arg3)
		else:
			var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
			var attacker_hero: HeroCharacter = heroes_by_id.get(attacker_id, null) as HeroCharacter
			if attacker_hero != null:
				attacker_team = attacker_hero.team
		if attacker_team == owner_team:
			return
		hp = maxi(0, hp - dmg)
		if hp <= 0:
			var pos: Vector3 = global_position if is_inside_tree() else position
			NetworkManager.broadcast_game_event("hit_vfx", {"pos": pos + Vector3(0.0, 1.0, 0.0), "kind": "spark"})
			if shield_uid != 0:
				NetworkManager.broadcast_game_event("riot_shield_destroyed", {"shield_uid": shield_uid})
			queue_free()


func _execute_class_skill(slot_idx: int, _rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null or owner_hero.status_effects == null:
		return false

	match slot_idx:
		0: # Escudo Balístico (Riot Shield): spawns 150 HP RiotShieldEntity 2.0m ahead facing aim yaw
			var yaw: float = cmd.aim_yaw if cmd != null else owner_hero.aim_yaw
			var fwd: Vector3 = -Basis(Vector3.UP, yaw).z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
			var hero_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
			var shield := RiotShieldEntity.new()
			shield.owner_id = owner_hero.entity_id
			shield.owner_team = owner_hero.team
			shield.max_hp = 150
			shield.hp = 150
			shield.shield_uid = shield.get_instance_id()
			shield._context = context
			shield.position = hero_pos + fwd * 2.0
			shield.rotation.y = yaw
			var root: Node = context.get("projectiles_root", owner_hero.get_parent())
			if root != null:
				root.add_child(shield)
			NetworkManager.broadcast_game_event("riot_shield_spawn", {
				"shield_uid": shield.shield_uid,
				"owner_id": owner_hero.entity_id,
				"team": owner_hero.team,
				"pos": shield.position,
				"yaw": yaw,
				"lifetime": shield.lifetime_remaining,
			})
			return true

		1: # Haste (Adrenalina): 1.38x move, 1.50x fire rate, 1.60x reload for 6.0s
			owner_hero.status_effects.activate_haste(1.38, 1.50, 1.60, 6.0)
			return true

		2: # Corda de TNTs (TNT Rope): no max duration, blocks normal firing until thrown
			if owner_hero.status_effects.tnt_rope_active:
				return false
			owner_hero.status_effects.activate_tnt_rope()
			_prev_tnt_fire_held = cmd != null and cmd.has_button(InputCmd.BTN_FIRE)
			return true

		3: # Dreno de Escudo (Damage -> Temp Shield): 3.0s
			owner_hero.status_effects.activate_damage_to_shield(3.0)
			return true

		4: # Quebra-Tanques (3x Vehicle Damage): 3.0s
			owner_hero.status_effects.activate_vehicle_triple_dmg(3.0)
			return true

	return false
