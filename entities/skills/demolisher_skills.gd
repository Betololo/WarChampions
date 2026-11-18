class_name DemolisherSkills
extends SkillManager

## Demolisher's 5 Heroic Skills:
## 0: Escudo Balístico (Em Mãos), 1: Haste, 2: Corda de TNTs (TNT Rope),
## 3: Kit de 5 Coletes (+70 Escudo), 4: Quebra-Tanques (3x Vehicle Damage)

var _prev_tnt_fire_held: bool = false
var _suppress_fire_until_release: bool = false
var _active_armor_kit: ArmorKitEntity = null


func _ready() -> void:
	super._ready()
	skill_names = ["Escudo Balístico (Em Mãos)", "Haste", "Corda de TNTs", "Kit de 5 Coletes", "Quebra-Tanques"]
	skill_ranks = [5, 5, 5, 5, 5]
	skill_cooldowns = [0.0, 0.0, 0.0, 0.0, 0.0]
	skill_max_cooldowns = [16.0, 16.0, 15.0, 17.0, 18.0]


func _defers_cooldown_until_exit(slot_idx: int) -> bool:
	return slot_idx == 0 or slot_idx == 2 or slot_idx == 3


func start_carried_shield_exit_cooldown() -> void:
	if skill_cooldowns.size() > 0 and skill_max_cooldowns.size() > 0:
		skill_cooldowns[0] = skill_max_cooldowns[0]
		skill_activated.emit(0, skill_cooldowns[0])


func _on_armor_kit_emptied() -> void:
	_active_armor_kit = null
	if skill_cooldowns.size() > 3 and skill_max_cooldowns.size() > 3:
		skill_cooldowns[3] = skill_max_cooldowns[3]
		skill_activated.emit(3, skill_cooldowns[3])


func try_activate_skill(slot_idx: int, cmd: InputCmd, context: Dictionary) -> bool:
	if slot_idx == 0 and owner_hero != null and not owner_hero.is_defeated and owner_hero.status_effects != null:
		if owner_hero.status_effects.carried_shield_active and skill_cooldowns.size() > 0 and skill_cooldowns[0] <= 0.0:
			owner_hero.status_effects.deactivate_carried_shield(true)
			return true
	return super.try_activate_skill(slot_idx, cmd, context)


func blocks_weapon_fire() -> bool:
	if _suppress_fire_until_release:
		return true
	return owner_hero != null and owner_hero.status_effects != null and owner_hero.status_effects.tnt_rope_active


func step_server(delta: float, cmd: InputCmd, context: Dictionary, allow_class_skills: bool = true) -> void:
	if _suppress_fire_until_release and (cmd == null or not cmd.has_button(InputCmd.BTN_FIRE)):
		_suppress_fire_until_release = false

	var was_tnt_active: bool = (
		owner_hero != null
		and not owner_hero.is_defeated
		and owner_hero.status_effects != null
		and owner_hero.status_effects.tnt_rope_active
	)

	super.step_server(delta, cmd, context, allow_class_skills)

	if not allow_class_skills or owner_hero == null or owner_hero.is_defeated or owner_hero.status_effects == null:
		_prev_tnt_fire_held = false
		_suppress_fire_until_release = false
		return

	if owner_hero.status_effects.carried_shield_active and (owner_hero.selected_weapon_slot != 2 or owner_hero.current_vehicle_id >= 0):
		owner_hero.status_effects.deactivate_carried_shield(true)

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
		ProjectileEntity.ProjectileKind.TNT_ROPE_CLUSTER,
		owner_hero.entity_id,
		owner_hero.team,
		origin,
		launch_vel,
		context,
		105.0,
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
	var _ember_pool: MeshInstance3D = null
	var _flame_ribbons: Array[MeshInstance3D] = []

	static var _shared_disc_mesh: CylinderMesh = null
	static var _shared_flame_sheet_mesh: QuadMesh = null
	static var _shared_scorch_mat: StandardMaterial3D = null
	static var _shared_disc_mat: StandardMaterial3D = null
	static var _shared_flame_mat: StandardMaterial3D = null
	static var _shared_radial_tex: ImageTexture = null
	static var _shared_flame_tex: ImageTexture = null

	func _ready() -> void:
		add_to_group("fire_patches")
		_is_visual_only = bool(get_meta("visual_only", false))
		_build_visuals()

	static func _ensure_shared_textures() -> void:
		if _shared_radial_tex == null:
			var r_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for y in range(32):
				for x in range(32):
					var uv := Vector2((float(x) + 0.5) / 32.0 * 2.0 - 1.0, (float(y) + 0.5) / 32.0 * 2.0 - 1.0)
					var d: float = uv.length()
					var a: float = clampf(1.0 - d * d, 0.0, 1.0)
					a = a * a
					r_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
			_shared_radial_tex = ImageTexture.create_from_image(r_img)
		if _shared_flame_tex == null:
			var f_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for y in range(32):
				var v: float = (float(y) + 0.5) / 32.0 # 0=top, 1=bottom
				var vert_env: float = sin(v * PI) * clampf(0.35 + v * 0.85, 0.0, 1.0)
				var half_w: float = lerpf(0.24, 0.82, pow(v, 0.6))
				for x in range(32):
					var u: float = (float(x) + 0.5) / 32.0 * 2.0 - 1.0
					var wave_u: float = u + sin(v * TAU * 1.4) * 0.14
					var horiz_env: float = clampf(1.0 - absf(wave_u) / maxf(0.08, half_w), 0.0, 1.0)
					var alpha: float = clampf(vert_env * horiz_env * horiz_env, 0.0, 1.0)
					f_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
			_shared_flame_tex = ImageTexture.create_from_image(f_img)

	func _build_visuals() -> void:
		_ensure_shared_textures()
		if _shared_disc_mesh == null:
			_shared_disc_mesh = CylinderMesh.new()
			_shared_disc_mesh.top_radius = 1.0
			_shared_disc_mesh.bottom_radius = 1.0
			_shared_disc_mesh.height = 0.04
			_shared_disc_mesh.radial_segments = 16
		if _shared_flame_sheet_mesh == null:
			_shared_flame_sheet_mesh = QuadMesh.new()
			_shared_flame_sheet_mesh.size = Vector2(1.05, 0.52)
		if _shared_scorch_mat == null:
			_shared_scorch_mat = StandardMaterial3D.new()
			_shared_scorch_mat.albedo_color = Color(0.16, 0.08, 0.04, 0.62)
			_shared_scorch_mat.albedo_texture = _shared_radial_tex
			_shared_scorch_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_scorch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if _shared_disc_mat == null:
			_shared_disc_mat = StandardMaterial3D.new()
			_shared_disc_mat.albedo_color = Color(1.0, 0.44, 0.06, 0.68)
			_shared_disc_mat.albedo_texture = _shared_radial_tex
			_shared_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_shared_disc_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if _shared_flame_mat == null:
			_shared_flame_mat = StandardMaterial3D.new()
			_shared_flame_mat.albedo_color = Color(1.0, 0.64, 0.14, 0.58)
			_shared_flame_mat.albedo_texture = _shared_flame_tex
			_shared_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_shared_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_shared_flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

		var scorch_pad := MeshInstance3D.new()
		scorch_pad.mesh = _shared_disc_mesh
		scorch_pad.material_override = _shared_scorch_mat
		scorch_pad.scale = Vector3(radius * 1.08, 1.0, radius * 1.08)
		scorch_pad.position = Vector3(0.0, 0.025, 0.0)
		scorch_pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(scorch_pad)

		_ember_pool = MeshInstance3D.new()
		_ember_pool.mesh = _shared_disc_mesh
		_ember_pool.material_override = _shared_disc_mat
		_ember_pool.scale = Vector3(radius * 0.78, 1.0, radius * 0.78)
		_ember_pool.position = Vector3(0.0, 0.04, 0.0)
		_ember_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ember_pool)

		_flame_ribbons.clear()
		for i in range(4):
			var ang: float = float(i) * (TAU / 3.0) + 0.35
			var r_off: float = radius * 0.44 if i > 0 else 0.0
			var cluster_pos := Vector3(cos(ang) * r_off, 0.26, sin(ang) * r_off)
			for cross_idx in range(2):
				var ribbon := MeshInstance3D.new()
				ribbon.mesh = _shared_flame_sheet_mesh
				ribbon.material_override = _shared_flame_mat
				ribbon.position = cluster_pos
				ribbon.rotation = Vector3(0.0, ang + float(cross_idx) * (PI * 0.5) + 0.2 * float(i), 0.0)
				ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(ribbon)
				_flame_ribbons.append(ribbon)

	func _physics_process(delta: float) -> void:
		step_hazard(delta, _context)

	func step_hazard(delta: float, context: Dictionary = {}) -> void:
		_lifetime_elapsed += delta
		if _lifetime_elapsed >= max_lifetime:
			queue_free()
			return
		if not DisplayServer.get_name().contains("headless"):
			var fade_out: float = clampf((max_lifetime - _lifetime_elapsed) / 0.8, 0.0, 1.0)
			if _ember_pool != null and is_instance_valid(_ember_pool):
				var ember_r: float = (0.76 + 0.07 * sin(_lifetime_elapsed * 7.5)) * radius * fade_out
				_ember_pool.scale = Vector3(maxf(0.1, ember_r), 1.0, maxf(0.1, ember_r))
			for idx in range(_flame_ribbons.size()):
				var rib: MeshInstance3D = _flame_ribbons[idx]
				if rib == null or not is_instance_valid(rib):
					continue
				var phase: float = _lifetime_elapsed * 8.5 + float(idx) * 1.15
				var h_scale: float = (0.86 + 0.22 * sin(phase)) * fade_out
				var w_scale: float = 0.92 + 0.12 * cos(phase * 0.7)
				rib.scale = Vector3(w_scale, maxf(0.05, h_scale), 1.0)
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


class ArmorKitEntity extends Node3D:
	var owner_id: int = -1
	var owner_team: int = 0
	var kit_uid: int = 0
	var charges: int = 5
	var vest_shield_amount: int = 70
	var pickup_radius: float = 2.0
	var on_kit_emptied: Callable = Callable()
	var _pickup_cooldowns: Dictionary = {}
	var _context: Dictionary = {}
	var _is_visual_only: bool = false
	var _vest_nodes: Array[MeshInstance3D] = []
	var _halo_ring: MeshInstance3D = null
	var _anim_t: float = 0.0

	static var _shared_crate_mesh: BoxMesh = null
	static var _shared_rail_mesh: BoxMesh = null
	static var _shared_vest_mesh: BoxMesh = null
	static var _shared_ring_mesh: TorusMesh = null
	static var _shared_crate_mat: StandardMaterial3D = null
	static var _shared_trim_mat: StandardMaterial3D = null
	static var _shared_vest_mat_royal: StandardMaterial3D = null
	static var _shared_vest_mat_nat: StandardMaterial3D = null
	static var _shared_ring_mat: StandardMaterial3D = null

	func _ready() -> void:
		add_to_group("armor_kits")
		_is_visual_only = bool(get_meta("visual_only", false))
		_build_visuals()
		set_charges_visual(charges)

	func _build_visuals() -> void:
		if _shared_crate_mesh == null:
			_shared_crate_mesh = BoxMesh.new()
			_shared_crate_mesh.size = Vector3(0.92, 0.16, 0.68)
		if _shared_rail_mesh == null:
			_shared_rail_mesh = BoxMesh.new()
			_shared_rail_mesh.size = Vector3(0.96, 0.12, 0.08)
		if _shared_vest_mesh == null:
			_shared_vest_mesh = BoxMesh.new()
			_shared_vest_mesh.size = Vector3(0.58, 0.085, 0.46)
		if _shared_ring_mesh == null:
			_shared_ring_mesh = TorusMesh.new()
			_shared_ring_mesh.inner_radius = 0.90
			_shared_ring_mesh.outer_radius = 1.00
			_shared_ring_mesh.rings = 20
			_shared_ring_mesh.ring_segments = 6
		if _shared_crate_mat == null:
			_shared_crate_mat = StandardMaterial3D.new()
			_shared_crate_mat.albedo_color = Color(0.24, 0.28, 0.22)
			_shared_crate_mat.roughness = 0.72
		if _shared_trim_mat == null:
			_shared_trim_mat = StandardMaterial3D.new()
			_shared_trim_mat.albedo_color = Color(0.32, 0.36, 0.40)
			_shared_trim_mat.roughness = 0.45
			_shared_trim_mat.metallic = 0.45
		if _shared_vest_mat_royal == null:
			_shared_vest_mat_royal = StandardMaterial3D.new()
			_shared_vest_mat_royal.albedo_color = Color(0.22, 0.56, 0.92)
			_shared_vest_mat_royal.roughness = 0.55
		if _shared_vest_mat_nat == null:
			_shared_vest_mat_nat = StandardMaterial3D.new()
			_shared_vest_mat_nat.albedo_color = Color(0.84, 0.24, 0.22)
			_shared_vest_mat_nat.roughness = 0.55
		if _shared_ring_mat == null:
			_shared_ring_mat = StandardMaterial3D.new()
			_shared_ring_mat.albedo_color = Color(0.28, 0.86, 1.0, 0.55)
			_shared_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_shared_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_shared_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

		var base_crate := MeshInstance3D.new()
		base_crate.mesh = _shared_crate_mesh
		base_crate.material_override = _shared_crate_mat
		base_crate.position = Vector3(0.0, 0.08, 0.0)
		base_crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(base_crate)

		for z_s in [-0.30, 0.30]:
			var rail := MeshInstance3D.new()
			rail.mesh = _shared_rail_mesh
			rail.material_override = _shared_trim_mat
			rail.position = Vector3(0.0, 0.18, z_s)
			rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(rail)

		_halo_ring = MeshInstance3D.new()
		_halo_ring.mesh = _shared_ring_mesh
		_halo_ring.material_override = _shared_ring_mat
		_halo_ring.position = Vector3(0.0, 0.03, 0.0)
		_halo_ring.scale = Vector3(pickup_radius, 0.35, pickup_radius)
		_halo_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo_ring)

		var vest_mat: StandardMaterial3D = _shared_vest_mat_royal if owner_team == NetworkManager.TEAM_ROYAL else _shared_vest_mat_nat
		_vest_nodes.clear()
		for i in range(5):
			var vest := MeshInstance3D.new()
			vest.name = "VestPlate_%d" % i
			vest.mesh = _shared_vest_mesh
			vest.material_override = vest_mat
			vest.position = Vector3(0.0, 0.21 + float(i) * 0.095, 0.0)
			vest.rotation.y = 0.06 if (i % 2 == 0) else -0.06
			vest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(vest)
			_vest_nodes.append(vest)

	func set_charges_visual(new_charges: int) -> void:
		charges = clampi(new_charges, 0, 5)
		for i in range(_vest_nodes.size()):
			var vn: MeshInstance3D = _vest_nodes[i]
			if vn != null and is_instance_valid(vn):
				vn.visible = (i < charges)

	func _physics_process(delta: float) -> void:
		step_kit(delta, _context)

	func step_kit(delta: float, context: Dictionary = {}) -> void:
		_anim_t += delta
		if not DisplayServer.get_name().contains("headless") and _halo_ring != null and is_instance_valid(_halo_ring):
			var pulse_r: float = pickup_radius * (0.94 + 0.06 * sin(_anim_t * 4.5))
			_halo_ring.scale = Vector3(pulse_r, 0.35, pulse_r)
		if _is_visual_only or not NetworkManager.is_server_authority():
			return
		if charges <= 0:
			return

		for hid_key in _pickup_cooldowns.keys():
			var cd: float = float(_pickup_cooldowns[hid_key]) - delta
			if cd <= 0.0:
				_pickup_cooldowns.erase(hid_key)
			else:
				_pickup_cooldowns[hid_key] = cd

		var eff_ctx: Dictionary = context if not context.is_empty() else _context
		var heroes_by_id: Dictionary = eff_ctx.get("heroes_by_id", {})
		var self_pos: Vector3 = global_position if is_inside_tree() else position

		for id_key in heroes_by_id.keys():
			if charges <= 0:
				break
			var h: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
			if h == null or not is_instance_valid(h) or h.is_defeated:
				continue
			if h.team != owner_team:
				continue
			if h.shield >= vest_shield_amount:
				continue
			if _pickup_cooldowns.has(h.entity_id):
				continue

			var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
			var horiz_dist: float = Vector2(h_pos.x - self_pos.x, h_pos.z - self_pos.z).length()
			if horiz_dist > pickup_radius or absf(h_pos.y - self_pos.y) > 2.2:
				continue

			if h.status_effects != null and h.status_effects.has_method("apply_vest_shield"):
				h.status_effects.apply_vest_shield(vest_shield_amount)
			else:
				h.shield = maxi(h.shield, vest_shield_amount)
				h.stats_changed.emit()

			_pickup_cooldowns[h.entity_id] = 0.5
			charges -= 1
			set_charges_visual(charges)

			NetworkManager.broadcast_game_event("armor_kit_vfx", {
				"kit_uid": kit_uid,
				"hero_id": h.entity_id,
				"pos": self_pos + Vector3(0.0, 0.45, 0.0),
				"charges": charges,
			})
			if charges <= 0:
				if on_kit_emptied.is_valid():
					on_kit_emptied.call()
				NetworkManager.broadcast_game_event("armor_kit_empty", {"kit_uid": kit_uid})
				queue_free()
				return
			else:
				NetworkManager.broadcast_game_event("armor_kit_update", {
					"kit_uid": kit_uid,
					"charges": charges,
				})


func _execute_class_skill(slot_idx: int, _rank: int, cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null or owner_hero.status_effects == null:
		return false

	match slot_idx:
		0: # Escudo Balístico (Em Mãos): equips carried 150 HP frontal shield + STICK_GRENADE (slot 2)
			if owner_hero.status_effects.carried_shield_active:
				owner_hero.status_effects.deactivate_carried_shield(true)
				return false
			owner_hero.force_server_weapon_slot(2, cmd.tick if cmd != null else -1)
			owner_hero.status_effects.activate_carried_shield(150)
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

		3: # Kit de 5 Coletes: drops ground 5-vest ArmorKitEntity (+70 permanent-until-damaged shield)
			if _active_armor_kit != null and is_instance_valid(_active_armor_kit) and not _active_armor_kit.is_queued_for_deletion() and _active_armor_kit.charges > 0:
				return false
			var kit := ArmorKitEntity.new()
			kit.owner_id = owner_hero.entity_id
			kit.owner_team = owner_hero.team
			kit.kit_uid = kit.get_instance_id()
			kit.charges = 5
			kit.vest_shield_amount = 70
			kit.pickup_radius = 2.0
			kit._context = context
			kit.on_kit_emptied = Callable(self, "_on_armor_kit_emptied")
			var hero_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
			kit.position = hero_pos
			var root: Node = context.get("projectiles_root", owner_hero.get_parent())
			if root != null:
				root.add_child(kit)
			_active_armor_kit = kit
			NetworkManager.broadcast_game_event("armor_kit_spawn", {
				"kit_uid": kit.kit_uid,
				"owner_id": owner_hero.entity_id,
				"team": owner_hero.team,
				"pos": kit.position,
				"charges": kit.charges,
			})
			return true

		4: # Quebra-Tanques (3x Vehicle Damage): 3.0s
			owner_hero.status_effects.activate_vehicle_triple_dmg(3.0)
			return true

	return false
