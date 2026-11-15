class_name StatusEffectsVFX
extends Node3D

## Cartoon VFX spawner (NO blood!): shared cached primitive meshes & materials,
## dirty-state cached hero/vehicle status shaders, foot speed trails, and thematic
## multi-part 3D VFX for all 16 heroic skills and 4 widgets.

const HERO_SHADER: Shader = preload("res://vfx_shaders/hero_cel_shader.gdshader")
const HERO_CLOAK_SHADER: Shader = preload("res://vfx_shaders/hero_cloak_shader.gdshader")
const XRAY_SHADER: Shader = preload("res://vfx_shaders/xray_silhouette.gdshader")

const MAX_OVERHEAD_BUFF_SLOTS: int = 6
const BUFF_ICON_TABLE: Array[Array] = [
	[NetSerializer.BUFF_HERO_SHIELD, "icon_skill_1_0"],
	[NetSerializer.BUFF_LEG_IT, "icon_skill_1_1"],
	[NetSerializer.BUFF_ELIXIR, "icon_skill_2_4"],
	[NetSerializer.BUFF_BURNING_BULLETS, "icon_skill_0_1"],
	[NetSerializer.BUFF_POISONED_BLADE, "icon_skill_2_2"],
	[NetSerializer.BUFF_FRENZY_FIRE, "icon_skill_1_3"],
	[NetSerializer.BUFF_PIERCING_SHOT, "icon_skill_2_1"],
	[NetSerializer.BUFF_EAT_GRENADES, "icon_skill_1_4"],
	[NetSerializer.BUFF_SIXTH_SENSE, "icon_skill_0_4"],
	[NetSerializer.BUFF_COMBAT_MED_HOT, "icon_skill_0_0"],
	[NetSerializer.BUFF_BANDAGE, "icon_widget_0"],
	[NetSerializer.BUFF_FIREPROOF, "icon_widget_2"],
]

static var _xray_mat: ShaderMaterial = null
static var _shared_meshes: Dictionary = {}
static var _shared_mats: Dictionary = {}


static func _get_xray_material() -> ShaderMaterial:
	if _xray_mat == null:
		_xray_mat = ShaderMaterial.new()
		_xray_mat.shader = XRAY_SHADER
	return _xray_mat


static func warm_shared_meshes() -> void:
	_get_shared_box()
	_get_shared_sphere()
	_get_shared_cylinder()
	_get_shared_cone()
	_get_shared_torus()


static func _get_shared_box() -> BoxMesh:
	if _shared_meshes.has("box"):
		return _shared_meshes["box"] as BoxMesh
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	_shared_meshes["box"] = m
	return m


static func _get_shared_sphere() -> SphereMesh:
	if _shared_meshes.has("sphere"):
		return _shared_meshes["sphere"] as SphereMesh
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 6
	_shared_meshes["sphere"] = m
	return m


static func _get_shared_cylinder() -> CylinderMesh:
	if _shared_meshes.has("cylinder"):
		return _shared_meshes["cylinder"] as CylinderMesh
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	_shared_meshes["cylinder"] = m
	return m


static func _get_shared_cone() -> CylinderMesh:
	if _shared_meshes.has("cone"):
		return _shared_meshes["cone"] as CylinderMesh
	var m := CylinderMesh.new()
	m.top_radius = 0.01
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	_shared_meshes["cone"] = m
	return m


static func _get_shared_torus() -> TorusMesh:
	if _shared_meshes.has("torus"):
		return _shared_meshes["torus"] as TorusMesh
	var m := TorusMesh.new()
	m.inner_radius = 0.38
	m.outer_radius = 0.50
	m.rings = 16
	m.ring_segments = 8
	_shared_meshes["torus"] = m
	return m


static func _get_shared_mat(col: Color, additive: bool = false) -> StandardMaterial3D:
	var key: String = "%08x_%d" % [col.to_rgba32(), 1 if additive else 0]
	if _shared_mats.has(key):
		return _shared_mats[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	_shared_mats[key] = mat
	return mat


static func _vfx_part(
	parent: Node3D,
	mesh: Mesh,
	mat: Material,
	pos: Vector3,
	scale_v: Vector3,
	rot: Vector3 = Vector3.ZERO,
	fade_list: Array[MeshInstance3D] = []
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	fade_list.append(mi)
	return mi


static func _vfx_plus_cross(
	parent: Node3D,
	mat: Material,
	pos: Vector3,
	size: float,
	thickness: float,
	fade_list: Array[MeshInstance3D] = []
) -> Node3D:
	var cross := Node3D.new()
	cross.position = pos
	parent.add_child(cross)
	var box: BoxMesh = _get_shared_box()
	_vfx_part(cross, box, mat, Vector3.ZERO, Vector3(thickness, size, thickness), Vector3.ZERO, fade_list)
	_vfx_part(cross, box, mat, Vector3.ZERO, Vector3(size, thickness, thickness), Vector3.ZERO, fade_list)
	return cross


static func _collect_active_buff_icon_keys(hero: HeroCharacter, stealthed: bool, is_enemy: bool) -> Array[String]:
	var keys: Array[String] = []
	for entry in BUFF_ICON_TABLE:
		var bit: int = int(entry[0])
		if (hero.active_buffs & bit) != 0:
			keys.append(str(entry[1]))
			if keys.size() >= MAX_OVERHEAD_BUFF_SLOTS:
				return keys
	if stealthed and not is_enemy and keys.size() < MAX_OVERHEAD_BUFF_SLOTS:
		keys.append("icon_skill_2_0")
	return keys


static func _update_overhead_buff_icons(hero: HeroCharacter, stealthed: bool, is_enemy: bool, vis: bool) -> void:
	if hero == null or hero.visual_root == null:
		return
	var keys: Array[String] = []
	if vis and not hero.is_defeated:
		keys = _collect_active_buff_icon_keys(hero, stealthed, is_enemy)
	var count: int = keys.size()
	var row: Node3D = hero._overhead_buff_row
	if row == null or not is_instance_valid(row) or row.is_queued_for_deletion():
		if count == 0:
			return
		row = Node3D.new()
		row.name = "OverheadBuffRow"
		row.position = Vector3(0.0, 2.38, 0.0)
		hero.visual_root.add_child(row)
		hero._overhead_buff_row = row
		hero._overhead_buff_slots.clear()
		for i in range(MAX_OVERHEAD_BUFF_SLOTS):
			var sp := Sprite3D.new()
			sp.name = "BuffIcon_%d" % i
			sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sp.pixel_size = 0.011
			sp.no_depth_test = false
			sp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			sp.transparent = true
			sp.render_priority = 4
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sp.visible = false
			row.add_child(sp)
			hero._overhead_buff_slots.append(sp)

	if count == 0:
		row.visible = false
		for sp in hero._overhead_buff_slots:
			if is_instance_valid(sp):
				sp.visible = false
				sp.texture = null
		return

	row.visible = true
	for i in range(hero._overhead_buff_slots.size()):
		var sp: Sprite3D = hero._overhead_buff_slots[i]
		if not is_instance_valid(sp):
			continue
		if i < count:
			sp.texture = CartoonAssets.get_texture(keys[i])
			sp.position = Vector3((float(i) - float(count - 1) * 0.5) * 0.50, 0.0, 0.0)
			sp.visible = sp.texture != null
		else:
			sp.visible = false
			sp.texture = null


static func attach_hero_vfx_and_shader(hero: HeroCharacter) -> void:
	if hero == null:
		return
	hero.apply_character_shader(HERO_SHADER)


static func update_hero_client_visuals(hero: HeroCharacter, local_hero: HeroCharacter, delta: float, vehicles_by_id: Dictionary = {}) -> void:
	if hero == null or hero.visual_root == null:
		return

	if hero.current_vehicle_id >= 0 and vehicles_by_id.has(hero.current_vehicle_id):
		var v: VehicleBase = vehicles_by_id[hero.current_vehicle_id] as VehicleBase
		if v != null:
			var seat: VehicleBase.SeatSlot = v.get_seat(hero.current_seat_index)
			if seat != null:
				hero.current_seat_enclosed = seat.is_enclosed
				hero.current_seat_pose = seat.seat_pose
				hero.current_seat_can_shoot = seat.can_shoot
	elif hero.current_vehicle_id < 0:
		hero.current_seat_enclosed = false
		hero.current_seat_pose = ""
		hero.current_seat_can_shoot = false

	var hidden_in_vehicle: bool = (hero.current_vehicle_id >= 0 and hero.current_seat_pose == "hidden" and not hero.is_defeated)
	var is_enemy: bool = local_hero != null and hero.team != local_hero.team
	var stealthed: bool = (hero.active_flags & NetSerializer.SNAP_STEALTHED) != 0 or hero.is_stealthed
	var cloak_val: float = 0.0
	var vis: bool = true

	if hidden_in_vehicle:
		vis = false
	elif stealthed:
		if is_enemy and local_hero != null:
			var detect_r: float = hero.status_effects.stealth_detection_radius if hero.status_effects != null else 10.0
			var dist_sq: float = hero.global_position.distance_squared_to(local_hero.global_position)
			if dist_sq > detect_r * detect_r:
				vis = false
			else:
				vis = not hero.is_scoping
				cloak_val = 0.88
		else:
			vis = not (hero.is_local_player and hero.is_scoping)
			cloak_val = 0.55
	else:
		vis = not (hero.is_local_player and hero.is_scoping)
		cloak_val = 0.0

	# Rate-limited foot dust/wind puffs when speed-boosted (Leg It / Elixir) and sprinting
	if vis and not hero.is_defeated and hero.current_vehicle_id < 0:
		var is_boosted: bool = ((hero.active_flags & NetSerializer.SNAP_SPEED_BOOST) != 0) or (hero.speed_multiplier > 1.15)
		if is_boosted:
			var horiz_sq: float = hero.velocity.x * hero.velocity.x + hero.velocity.z * hero.velocity.z
			if horiz_sq > 6.25:
				hero._speed_trail_timer -= delta
				if hero._speed_trail_timer <= 0.0:
					hero._speed_trail_timer = 0.18
					var parent_node: Node = hero.get_parent()
					if parent_node != null and not DisplayServer.get_name().contains("headless"):
						_spawn_foot_speed_puff(parent_node, hero.global_position, hero.aim_yaw)

	var burning: bool = (hero.active_flags & NetSerializer.SNAP_BURNING) != 0
	var poisoned: bool = (hero.active_flags & NetSerializer.SNAP_POISONED) != 0
	var shielded: bool = (hero.active_flags & NetSerializer.SNAP_SHIELDED) != 0
	var marked_enemy: bool = is_enemy and ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0)
	var sensed_enemy: bool = is_enemy and local_hero != null and ((local_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0) and (hero.global_position.distance_squared_to(local_hero.global_position) <= 3025.0)
	var show_xray: bool = (marked_enemy or sensed_enemy) and not hero.is_defeated
	var speed_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_SPEED_BOOST) != 0) else 0
	var eat_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_EAT_GRENADES) != 0) else 0
	var frenzy_flag: int = 1 if ((hero.active_buffs & NetSerializer.BUFF_FRENZY_FIRE) != 0 or (hero.status_effects != null and hero.status_effects.frenzy_timer > 0.0)) else 0
	var pierce_flag: int = 1 if ((hero.active_buffs & NetSerializer.BUFF_PIERCING_SHOT) != 0 or (hero.status_effects != null and hero.status_effects.piercing_timer > 0.0)) else 0
	var stealth_ally_flag: int = 1 if (stealthed and not is_enemy) else 0
	var mark_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0) else 0
	var cloak_q: int = int(roundf(clampf(cloak_val, 0.0, 1.0) * 100.0))

	var state_key: String = "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d" % [
		1 if hero.current_vehicle_id >= 0 else 0,
		0 if vis else 1,
		1 if hero.is_defeated else 0,
		1 if show_xray else 0,
		1 if burning else 0,
		1 if poisoned else 0,
		1 if shielded else 0,
		1 if marked_enemy else 0,
		speed_flag,
		eat_flag,
		frenzy_flag,
		pierce_flag,
		cloak_q,
		hero.active_buffs,
		stealth_ally_flag,
		mark_flag,
	]

	if state_key == hero._last_vfx_key:
		return
	hero._last_vfx_key = state_key
	hero.visual_root.visible = vis
	_update_overhead_buff_icons(hero, stealthed, is_enemy, vis)
	if not vis:
		return

	var target_shader: Shader = HERO_CLOAK_SHADER if cloak_val > 0.01 else HERO_SHADER
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null
	var rim_col := Color(1.0, 0.95, 0.82)
	var rim_str: float = 0.42
	if burning:
		rim_col = Color(1.0, 0.35, 0.05)
		rim_str = 1.8
	elif poisoned:
		rim_col = Color(0.25, 0.95, 0.25)
		rim_str = 1.8
	elif marked_enemy:
		rim_col = Color(1.0, 0.16, 0.12)
		rim_str = 2.0
	elif shielded:
		rim_col = Color(0.25, 0.72, 1.0)
		rim_str = 1.65
	elif eat_flag == 1:
		rim_col = Color(0.32, 1.0, 0.45)
		rim_str = 1.55
	elif frenzy_flag == 1:
		rim_col = Color(1.0, 0.78, 0.18)
		rim_str = 1.45
	elif pierce_flag == 1:
		rim_col = Color(1.0, 0.28, 0.22)
		rim_str = 1.45
	elif speed_flag == 1:
		rim_col = Color(0.72, 1.0, 0.32)
		rim_str = 1.35

	for part in hero._mesh_parts:
		if not is_instance_valid(part):
			continue
		part.visible = true
		part.material_overlay = xray_ov
		if part.material_override is ShaderMaterial:
			var smat := part.material_override as ShaderMaterial
			if smat.shader != target_shader:
				smat.shader = target_shader
			smat.set_shader_parameter("cloak_amount", cloak_val)
			smat.set_shader_parameter("rim_color", rim_col)
			smat.set_shader_parameter("rim_strength", rim_str)


static func update_vehicle_client_visuals(veh: VehicleBase, local_hero: HeroCharacter) -> void:
	if veh == null or veh.is_destroyed or veh._visual_root == null:
		return
	var is_enemy: bool = local_hero != null and veh.team >= 0 and veh.team != local_hero.team
	var local_senses: bool = is_enemy and ((local_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0) and (veh.global_position.distance_squared_to(local_hero.global_position) <= 3025.0)
	var show_xray: bool = is_enemy and (veh.is_marked or local_senses)
	var next_xray: int = 1 if show_xray else 0
	var meshes: Array[MeshInstance3D] = veh.get_cached_visual_meshes()
	if next_xray == veh._last_xray_state:
		return
	veh._last_xray_state = next_xray
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = xray_ov


static func _spawn_foot_speed_puff(parent: Node, world_pos: Vector3, aim_yaw: float) -> void:
	var puff := MeshInstance3D.new()
	puff.mesh = _get_shared_sphere()
	puff.material_override = _get_shared_mat(Color(0.86, 0.88, 0.72, 0.48), false)
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var back_dir := Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	puff.position = world_pos + Vector3(0.0, 0.14, 0.0) + back_dir * 0.28
	puff.scale = Vector3(0.24, 0.16, 0.24)
	parent.add_child(puff)
	if puff.is_inside_tree():
		var tw: Tween = puff.create_tween()
		tw.set_parallel(true)
		tw.tween_property(puff, "scale", Vector3(0.55, 0.30, 0.55), 0.26)
		tw.tween_property(puff, "position", puff.position + back_dir * 0.45 + Vector3(0.0, 0.18, 0.0), 0.26)
		tw.tween_property(puff, "transparency", 1.0, 0.26)
		tw.chain().tween_callback(puff.queue_free)


static func spawn_cartoon_burst(parent: Node, world_pos: Vector3, kind: String, radius: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	var burst := MeshInstance3D.new()
	burst.mesh = _get_shared_sphere()
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var base_r: float = 0.28 if kind != "explosion" else clampf(radius * 0.45, 0.8, 3.5)

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match kind:
		"spark":
			mat.albedo_color = Color(1.0, 0.86, 0.2, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.72, 0.1)
		"explosion":
			mat.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.35, 0.05)
		"heal":
			mat.albedo_color = Color(0.25, 0.95, 0.45, 0.85)
		"smoke":
			base_r = clampf(0.35 * radius, 0.25, 1.2)
			mat.albedo_color = Color(0.28, 0.28, 0.30, 0.72)
		"fire":
			base_r = clampf(0.28 * radius, 0.2, 0.9)
			mat.albedo_color = Color(1.0, 0.42, 0.08, 0.88)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.32, 0.04)
		_:
			mat.albedo_color = Color(0.88, 0.86, 0.8, 0.75)

	var diam: float = base_r * 2.0
	burst.scale = Vector3.ONE * diam
	burst.position = world_pos
	burst.material_override = mat
	parent.add_child(burst)

	var is_plume: bool = (kind == "smoke" or kind == "fire")
	var dur: float = 0.55 if is_plume else 0.26
	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst, "scale", Vector3.ONE * (diam * (2.2 if is_plume else 1.8)), dur)
	if is_plume:
		tw.tween_property(burst, "position", world_pos + Vector3(randf_range(-0.3, 0.3), 2.4, randf_range(-0.3, 0.3)), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(burst.queue_free)


static func spawn_muzzle_flash(parent: Node, world_pos: Vector3, aim_dir: Vector3, weapon_kind: int) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	if weapon_kind == 5 or weapon_kind == 7:
		return
	var flash_root := Node3D.new()
	flash_root.position = world_pos
	parent.add_child(flash_root)

	var base_r: float = 0.16 if weapon_kind == 6 or weapon_kind == 2 else (0.14 if weapon_kind == 4 else 0.10)
	var mat: StandardMaterial3D = _get_shared_mat(Color(1.0, 0.90, 0.32, 0.95), true)

	var core := MeshInstance3D.new()
	core.mesh = _get_shared_sphere()
	core.scale = Vector3.ONE * (base_r * 2.0)
	core.material_override = mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_root.add_child(core)

	var streak := MeshInstance3D.new()
	streak.mesh = _get_shared_cone()
	streak.scale = Vector3(base_r * 1.7, base_r * 3.4, base_r * 1.7)
	streak.material_override = mat
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dir_n: Vector3 = aim_dir.normalized() if aim_dir.length_squared() > 0.001 else Vector3.FORWARD
	var look_target: Vector3 = world_pos + dir_n
	if absf(dir_n.dot(Vector3.UP)) < 0.98:
		flash_root.look_at(look_target, Vector3.UP)
	streak.rotation.x = -PI * 0.5
	streak.position.z = -base_r * 1.5
	flash_root.add_child(streak)

	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash_root, "scale", Vector3.ONE * 1.55, 0.07)
	tw.tween_property(core, "transparency", 1.0, 0.07)
	tw.tween_property(streak, "transparency", 1.0, 0.07)
	tw.chain().tween_callback(flash_root.queue_free)


static func spawn_curved_tracer(parent: Node, arc_points: PackedVector3Array, weapon_kind: int) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	if weapon_kind == 5 or weapon_kind == 7 or weapon_kind == 6:
		return
	if arc_points.size() < 2:
		return

	var cum_dist := PackedFloat32Array()
	cum_dist.resize(arc_points.size())
	cum_dist[0] = 0.0
	var total_len: float = 0.0
	for i in range(1, arc_points.size()):
		total_len += arc_points[i - 1].distance_to(arc_points[i])
		cum_dist[i] = total_len
	if total_len < 0.6:
		return

	var seg_len: float = clampf(total_len * 0.25, 1.2, 9.0 if weapon_kind == 4 else 5.5)
	var tracer := MeshInstance3D.new()
	var thick: float = 0.036 if weapon_kind == 4 else 0.024
	tracer.mesh = _get_shared_box()
	tracer.scale = Vector3(thick, thick, seg_len)
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var col := Color(1.0, 0.94, 0.58, 0.88) if weapon_kind == 4 else Color(1.0, 0.86, 0.35, 0.80)
	tracer.material_override = _get_shared_mat(col, true)

	var start_d: float = minf(total_len * 0.5, seg_len * 0.5 + 0.15)
	var end_d: float = maxf(start_d, total_len - minf(total_len * 0.12, seg_len * 0.35))
	parent.add_child(tracer)

	var update_pose := func(d: float) -> void:
		if not is_instance_valid(tracer) or not tracer.is_inside_tree():
			return
		var seg_idx: int = 0
		for i in range(arc_points.size() - 1):
			if d <= cum_dist[i + 1] or i == arc_points.size() - 2:
				seg_idx = i
				break
		var seg_span: float = maxf(0.001, cum_dist[seg_idx + 1] - cum_dist[seg_idx])
		var local_t: float = clampf((d - cum_dist[seg_idx]) / seg_span, 0.0, 1.0)
		var pos: Vector3 = arc_points[seg_idx].lerp(arc_points[seg_idx + 1], local_t)
		var seg_dir: Vector3 = arc_points[seg_idx + 1] - arc_points[seg_idx]
		tracer.position = pos
		if seg_dir.length_squared() > 0.0001:
			var dir_n: Vector3 = seg_dir.normalized()
			if absf(dir_n.dot(Vector3.UP)) < 0.98:
				tracer.look_at(pos + dir_n, Vector3.UP)

	update_pose.call(start_d)

	var travel_t: float = clampf(total_len / 300.0, 0.055, 0.36)
	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_method(update_pose, start_d, end_d, travel_t)
	tw.tween_property(tracer, "transparency", 1.0, travel_t)
	tw.chain().tween_callback(tracer.queue_free)


static func spawn_bullet_tracer(parent: Node, start_pos: Vector3, end_pos: Vector3, weapon_kind: int) -> void:
	spawn_curved_tracer(parent, PackedVector3Array([start_pos, end_pos]), weapon_kind)


## Spawns unmistakable thematic multi-part 3D VFX for every one of the 16 heroic skills and 4 widgets.
static func spawn_skill_vfx(parent: Node, class_id: int, slot_idx: int, world_pos: Vector3, aim_yaw: float = 0.0) -> void:
	if parent == null:
		return
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "SkillVFX_%d_%d" % [class_id, slot_idx]
	root.position = world_pos
	root.rotation.y = aim_yaw
	parent.add_child(root)

	var box: BoxMesh = _get_shared_box()
	var sph: SphereMesh = _get_shared_sphere()
	var cyl: CylinderMesh = _get_shared_cylinder()
	var cone: CylinderMesh = _get_shared_cone()
	var torus: TorusMesh = _get_shared_torus()
	var fade_meshes: Array[MeshInstance3D] = []
	var dur: float = 0.55

	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	if slot_idx >= 100:
		match slot_idx - 100:
			0: # Bandages: 4 glowing cyan/light-blue + crosses floating upward
				dur = 0.65
				var mat_band := _get_shared_mat(Color(0.32, 0.90, 1.0, 0.92), true)
				var offsets: Array[Vector3] = [
					Vector3(-0.48, 0.85, -0.25), Vector3(0.46, 0.95, 0.22),
					Vector3(0.05, 1.10, -0.45), Vector3(-0.22, 0.78, 0.42),
				]
				for idx in range(offsets.size()):
					var c: Node3D = _vfx_plus_cross(root, mat_band, offsets[idx], 0.34, 0.10, fade_meshes)
					if tw != null:
						tw.tween_property(c, "position", offsets[idx] + Vector3(0.0, 0.95 + float(idx) * 0.14, 0.0), dur)
						tw.tween_property(c, "rotation:y", PI * 0.75, dur)
			1: # Wrench: metallic spark burst + floating yellow-gold + repair cross
				dur = 0.50
				var mat_gold := _get_shared_mat(Color(1.0, 0.84, 0.20, 0.95), true)
				var mat_silv := _get_shared_mat(Color(0.86, 0.92, 1.0, 0.92), true)
				var repair_c: Node3D = _vfx_plus_cross(root, mat_gold, Vector3(0.0, 1.15, -0.40), 0.42, 0.12, fade_meshes)
				if tw != null:
					tw.tween_property(repair_c, "position", Vector3(0.0, 1.85, -0.45), dur)
					tw.tween_property(repair_c, "rotation:y", PI, dur)
				for s_i in range(4):
					var ang: float = float(s_i) * (TAU / 4.0) + 0.4
					var sp := _vfx_part(root, box, mat_silv, Vector3(0.0, 1.15, -0.40), Vector3(0.07, 0.32, 0.07), Vector3(0.4, ang, 0.7), fade_meshes)
					if tw != null:
						tw.tween_property(sp, "position", Vector3(cos(ang) * 0.65, 1.45, -0.45 + sin(ang) * 0.65), dur)
			2: # Fireproof Underwear: cooling ice-blue protective plates + mist ring
				dur = 0.60
				var mat_ice := _get_shared_mat(Color(0.32, 0.80, 1.0, 0.78), false)
				var mat_mist := _get_shared_mat(Color(0.55, 0.92, 1.0, 0.72), true)
				var ring := _vfx_part(root, torus, mat_mist, Vector3(0.0, 1.05, 0.0), Vector3(1.4, 0.9, 1.4), Vector3.ZERO, fade_meshes)
				if tw != null:
					tw.tween_property(ring, "scale", Vector3(2.4, 1.2, 2.4), dur)
					tw.tween_property(ring, "position:y", 1.55, dur)
				for p_i in range(4):
					var a: float = float(p_i) * (TAU * 0.25)
					var plate := _vfx_part(root, box, mat_ice, Vector3(cos(a) * 0.62, 1.08, sin(a) * 0.62), Vector3(0.42, 0.56, 0.08), Vector3(0.0, -a + PI * 0.5, 0.0), fade_meshes)
					if tw != null:
						tw.tween_property(plate, "position", Vector3(cos(a) * 0.92, 1.42, sin(a) * 0.92), dur)
			_: # Antidote: emerald-green cleansing + crosses & detox droplets
				dur = 0.62
				var mat_ant := _get_shared_mat(Color(0.22, 1.0, 0.56, 0.92), true)
				var mat_drop := _get_shared_mat(Color(0.45, 1.0, 0.68, 0.85), false)
				for i in range(3):
					var ang: float = float(i) * (TAU / 3.0)
					var pos0 := Vector3(cos(ang) * 0.45, 0.75 + float(i) * 0.12, sin(ang) * 0.45)
					var ac: Node3D = _vfx_plus_cross(root, mat_ant, pos0, 0.32, 0.09, fade_meshes)
					var dr := _vfx_part(root, sph, mat_drop, pos0 * 0.75 + Vector3(0.0, 0.2, 0.0), Vector3(0.14, 0.20, 0.14), Vector3.ZERO, fade_meshes)
					if tw != null:
						tw.tween_property(ac, "position", pos0 + Vector3(0.0, 1.15, 0.0), dur)
						tw.tween_property(dr, "position", pos0 + Vector3(0.0, 1.40, 0.0), dur)
	else:
		match class_id:
			NetworkManager.CLASS_SOLDIER:
				match slot_idx:
					0: # Combat Medicine: expanding emerald-cyan ground aura ring + 5 rising + crosses
						dur = 0.72
						var mat_heal := _get_shared_mat(Color(0.22, 0.98, 0.62, 0.92), true)
						var mat_aura := _get_shared_mat(Color(0.20, 0.94, 0.78, 0.78), true)
						var aura := _vfx_part(root, torus, mat_aura, Vector3(0.0, 0.08, 0.0), Vector3(1.2, 0.7, 1.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(aura, "scale", Vector3(6.8, 0.7, 6.8), dur)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var r_off: float = 0.85 if (i % 2 == 0) else 1.35
							var p0 := Vector3(cos(a) * r_off, 0.45 + float(i) * 0.1, sin(a) * r_off)
							var hc: Node3D = _vfx_plus_cross(root, mat_heal, p0, 0.36, 0.10, fade_meshes)
							if tw != null:
								tw.tween_property(hc, "position", p0 + Vector3(0.0, 1.55, 0.0), dur)
								tw.tween_property(hc, "rotation:y", PI, dur)
					1: # Burning Bullets: swirling fiery orange/yellow flame embers & hot muzzle sparks
						dur = 0.52
						var mat_flame := _get_shared_mat(Color(1.0, 0.44, 0.06, 0.95), true)
						var mat_spark := _get_shared_mat(Color(1.0, 0.88, 0.22, 0.96), true)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.42, 0.95 + float(i) * 0.12, -0.18 + sin(a) * 0.42)
							var em := _vfx_part(root, sph if (i % 2 == 0) else box, mat_flame if (i % 2 == 0) else mat_spark, p0, Vector3(0.16, 0.26, 0.16), Vector3(0.3, a, 0.4), fade_meshes)
							if tw != null:
								tw.tween_property(em, "position", Vector3(cos(a + 1.8) * 0.62, 2.05, -0.30 + sin(a + 1.8) * 0.62), dur)
					2: # Grenade Spam: arcing fiery-orange fuse sparks & 3 forward lobbing streaks
						dur = 0.50
						var mat_fuse := _get_shared_mat(Color(1.0, 0.58, 0.10, 0.94), true)
						var mat_strk := _get_shared_mat(Color(1.0, 0.34, 0.06, 0.88), true)
						for i in range(3):
							var spread_x: float = (float(i) - 1.0) * 0.38
							var p0 := Vector3(spread_x * 0.4, 1.35, -0.35)
							var stk := _vfx_part(root, box, mat_strk, p0, Vector3(0.08, 0.08, 0.75), Vector3(-0.35, -spread_x * 0.5, 0.0), fade_meshes)
							var fsp := _vfx_part(root, sph, mat_fuse, p0 + Vector3(0.0, 0.08, -0.25), Vector3(0.18, 0.18, 0.18), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position", Vector3(spread_x * 1.4, 1.65, -2.4), dur)
								tw.tween_property(fsp, "position", Vector3(spread_x * 1.6, 1.85, -2.8), dur)
					3: # Blasting Strike: wide forward golden-orange sonic shock-cone + ground dust blast rings
						dur = 0.52
						var mat_cone := _get_shared_mat(Color(1.0, 0.62, 0.14, 0.78), true)
						var mat_ring := _get_shared_mat(Color(0.95, 0.78, 0.46, 0.68), false)
						var shock_cone := _vfx_part(root, cone, mat_cone, Vector3(0.0, 1.15, -1.2), Vector3(1.2, 1.8, 1.2), Vector3(-PI * 0.5, 0.0, 0.0), fade_meshes)
						var ring1 := _vfx_part(root, torus, mat_ring, Vector3(0.0, 0.10, -0.6), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, fade_meshes)
						var ring2 := _vfx_part(root, torus, mat_cone, Vector3(0.0, 0.16, -1.0), Vector3(0.9, 0.9, 0.9), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(shock_cone, "scale", Vector3(4.2, 4.6, 3.2), dur)
							tw.tween_property(shock_cone, "position:z", -3.2, dur)
							tw.tween_property(ring1, "scale", Vector3(6.4, 0.9, 6.4), dur)
							tw.tween_property(ring2, "scale", Vector3(5.2, 1.1, 5.2), dur)
					_: # Sixth Sense: golden overhead radar sweep arc + 2 expanding sonar pulse rings
						dur = 0.62
						var mat_rad := _get_shared_mat(Color(1.0, 0.88, 0.20, 0.92), true)
						var sweep_pivot := Node3D.new()
						sweep_pivot.position = Vector3(0.0, 2.05, 0.0)
						root.add_child(sweep_pivot)
						_vfx_part(sweep_pivot, box, mat_rad, Vector3(0.32, 0.0, -0.55), Vector3(0.08, 0.05, 1.25), Vector3(0.0, -0.45, 0.0), fade_meshes)
						_vfx_part(sweep_pivot, box, mat_rad, Vector3(-0.32, 0.0, -0.55), Vector3(0.08, 0.05, 1.25), Vector3(0.0, 0.45, 0.0), fade_meshes)
						var r_in := _vfx_part(root, torus, mat_rad, Vector3(0.0, 2.02, 0.0), Vector3(0.6, 0.7, 0.6), Vector3.ZERO, fade_meshes)
						var r_out := _vfx_part(root, torus, mat_rad, Vector3(0.0, 2.02, 0.0), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(sweep_pivot, "rotation:y", TAU, dur)
							tw.tween_property(r_in, "scale", Vector3(4.2, 0.7, 4.2), dur)
							tw.tween_property(r_out, "scale", Vector3(6.5, 0.7, 6.5), dur)

			NetworkManager.CLASS_GUNNER:
				match slot_idx:
					0: # Hero Shield: translucent cyan energy shield dome + 4 vertical ribs + belt ring
						dur = 0.60
						var mat_dome := _get_shared_mat(Color(0.22, 0.74, 1.0, 0.36), false)
						var mat_rib := _get_shared_mat(Color(0.35, 0.92, 1.0, 0.88), true)
						var dome := _vfx_part(root, sph, mat_dome, Vector3(0.0, 1.05, 0.0), Vector3(1.2, 1.4, 1.2), Vector3.ZERO, fade_meshes)
						var belt := _vfx_part(root, torus, mat_rib, Vector3(0.0, 1.05, 0.0), Vector3(1.4, 0.8, 1.4), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(dome, "scale", Vector3(2.3, 2.4, 2.3), dur)
							tw.tween_property(belt, "scale", Vector3(2.6, 0.8, 2.6), dur)
						for r_i in range(4):
							var a: float = float(r_i) * (TAU * 0.25)
							var rib := _vfx_part(root, box, mat_rib, Vector3(cos(a) * 0.68, 1.05, sin(a) * 0.68), Vector3(0.08, 1.2, 0.08), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(rib, "position", Vector3(cos(a) * 1.22, 1.05, sin(a) * 1.22), dur)
					1: # Leg It: backward-kicking movement wind streaks & light-tan dust puffs at feet
						dur = 0.54
						var mat_wind := _get_shared_mat(Color(0.45, 0.95, 1.0, 0.86), true)
						var mat_dust := _get_shared_mat(Color(0.84, 0.78, 0.64, 0.72), false)
						for i in range(4):
							var side_x: float = (float(i) - 1.5) * 0.36
							var stk := _vfx_part(root, box, mat_wind, Vector3(side_x, 0.18 + (i % 2) * 0.14, 0.25), Vector3(0.06, 0.06, 0.75), Vector3.ZERO, fade_meshes)
							var puff := _vfx_part(root, sph, mat_dust, Vector3(side_x * 0.85, 0.14, 0.15), Vector3(0.28, 0.18, 0.28), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.65, dur)
								tw.tween_property(puff, "position", Vector3(side_x * 1.1, 0.34, 1.15), dur)
								tw.tween_property(puff, "scale", Vector3(0.55, 0.35, 0.55), dur)
					2: # Explosive Keg: overhead warning orange/red stripe burst + launch dust flash
						dur = 0.52
						var mat_warn := _get_shared_mat(Color(1.0, 0.28, 0.10, 0.92), true)
						var mat_flash := _get_shared_mat(Color(0.95, 0.74, 0.38, 0.82), false)
						_vfx_part(root, box, mat_warn, Vector3(0.0, 1.88, -0.15), Vector3(0.65, 0.10, 0.10), Vector3(0.0, 0.0, 0.78), fade_meshes)
						_vfx_part(root, box, mat_warn, Vector3(0.0, 1.88, -0.15), Vector3(0.65, 0.10, 0.10), Vector3(0.0, 0.0, -0.78), fade_meshes)
						var fl1 := _vfx_part(root, sph, mat_flash, Vector3(-0.35, 1.35, -0.55), Vector3(0.32, 0.32, 0.32), Vector3.ZERO, fade_meshes)
						var fl2 := _vfx_part(root, sph, mat_flash, Vector3(0.35, 1.35, -0.55), Vector3(0.32, 0.32, 0.32), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(fl1, "position", Vector3(-0.75, 1.75, -1.65), dur)
							tw.tween_property(fl2, "position", Vector3(0.75, 1.75, -1.65), dur)
					3: # Frenzy Fire: rising golden-amber rapid-fire chevrons / hot brass flash bars
						dur = 0.50
						var mat_frz := _get_shared_mat(Color(1.0, 0.80, 0.18, 0.94), true)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.45, 0.85 + float(i) * 0.08, -0.25 + sin(a) * 0.45)
							var bar := _vfx_part(root, box, mat_frz, p0, Vector3(0.10, 0.36, 0.10), Vector3(0.25, a, 0.35), fade_meshes)
							if tw != null:
								tw.tween_property(bar, "position", p0 + Vector3(0.0, 1.25, -0.25), dur)
					_: # I Eat Grenades: inward-pulling green absorption chevrons & shrinking chomp pulse ring
						dur = 0.55
						var mat_eat := _get_shared_mat(Color(0.32, 1.0, 0.42, 0.92), true)
						var chomp_ring := _vfx_part(root, torus, mat_eat, Vector3(0.0, 1.15, 0.0), Vector3(2.2, 0.9, 2.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(chomp_ring, "scale", Vector3(0.25, 0.7, 0.25), dur)
						for i in range(4):
							var a: float = float(i) * (TAU * 0.25)
							var p_out := Vector3(cos(a) * 1.45, 1.15, sin(a) * 1.45)
							var chev := _vfx_part(root, box, mat_eat, p_out, Vector3(0.28, 0.10, 0.10), Vector3(0.0, -a, 0.45), fade_meshes)
							if tw != null:
								tw.tween_property(chev, "position", Vector3(cos(a) * 0.18, 1.15, sin(a) * 0.18), dur)

			_: # Commando
				match slot_idx:
					0: # Stealth: swirling smoky blue-grey shadow wisps + expanding veil ring
						dur = 0.58
						var mat_smk := _get_shared_mat(Color(0.62, 0.74, 0.88, 0.58), false)
						var veil_ring := _vfx_part(root, torus, mat_smk, Vector3(0.0, 0.12, 0.0), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						var swirl := Node3D.new()
						root.add_child(swirl)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.52, 0.45 + float(i) * 0.20, sin(a) * 0.52)
							var wisp := _vfx_part(swirl, sph, mat_smk, p0, Vector3(0.34, 0.24, 0.34), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(wisp, "position:y", p0.y + 0.95, dur)
								tw.tween_property(wisp, "scale", Vector3(0.58, 0.40, 0.58), dur)
						if tw != null:
							tw.tween_property(veil_ring, "scale", Vector3(2.4, 0.7, 2.4), dur)
							tw.tween_property(swirl, "rotation:y", PI * 1.5, dur)
					1: # Piercing Shot: crimson-gold 6m rail beam along -Z + muzzle shock ring
						dur = 0.44
						var mat_rail := _get_shared_mat(Color(1.0, 0.22, 0.18, 0.92), true)
						var mat_core := _get_shared_mat(Color(1.0, 0.88, 0.35, 0.96), true)
						var beam := _vfx_part(root, cyl, mat_rail, Vector3(0.0, 1.35, -3.35), Vector3(0.14, 6.0, 0.14), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var core := _vfx_part(root, cyl, mat_core, Vector3(0.0, 1.35, -3.35), Vector3(0.06, 6.0, 0.06), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var m_ring := _vfx_part(root, torus, mat_core, Vector3(0.0, 1.35, -0.55), Vector3(0.45, 0.6, 0.45), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						if tw != null:
							tw.tween_property(beam, "scale", Vector3(0.04, 6.4, 0.04), dur)
							tw.tween_property(core, "scale", Vector3(0.02, 6.4, 0.02), dur)
							tw.tween_property(m_ring, "scale", Vector3(1.65, 0.6, 1.65), dur)
					2: # Poisoned Blade: toxic neon-green venom droplets & dagger slash arc
						dur = 0.52
						var mat_ven := _get_shared_mat(Color(0.24, 1.0, 0.26, 0.92), true)
						var slash := _vfx_part(root, box, mat_ven, Vector3(0.0, 1.12, -0.55), Vector3(0.85, 0.08, 0.14), Vector3(0.0, 0.2, 0.35), fade_meshes)
						if tw != null:
							tw.tween_property(slash, "rotation:z", -0.65, dur)
							tw.tween_property(slash, "position:z", -0.85, dur)
						for i in range(4):
							var a: float = float(i) * (TAU * 0.25) + 0.3
							var drop := _vfx_part(root, sph, mat_ven, Vector3(cos(a) * 0.38, 1.10, -0.45 + sin(a) * 0.38), Vector3(0.14, 0.18, 0.14), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(drop, "position", Vector3(cos(a) * 0.65, 0.72, -0.55 + sin(a) * 0.65), dur)
					3: # Troop Trap: ground hazard X-prongs + amber arming beam snapping into floor
						dur = 0.56
						var mat_trap := _get_shared_mat(Color(0.95, 0.68, 0.18, 0.92), true)
						var mat_floor := _get_shared_mat(Color(0.92, 0.45, 0.12, 0.82), false)
						_vfx_part(root, box, mat_floor, Vector3(0.0, 0.08, -0.2), Vector3(0.95, 0.06, 0.12), Vector3(0.0, 0.78, 0.0), fade_meshes)
						_vfx_part(root, box, mat_floor, Vector3(0.0, 0.08, -0.2), Vector3(0.95, 0.06, 0.12), Vector3(0.0, -0.78, 0.0), fade_meshes)
						var arm_beam := _vfx_part(root, cyl, mat_trap, Vector3(0.0, 0.85, -0.2), Vector3(0.12, 1.2, 0.12), Vector3.ZERO, fade_meshes)
						var ring_t := _vfx_part(root, torus, mat_trap, Vector3(0.0, 0.06, -0.2), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(arm_beam, "position:y", 0.15, dur * 0.65)
							tw.tween_property(arm_beam, "scale:y", 0.15, dur * 0.65)
							tw.tween_property(ring_t, "scale", Vector3(2.2, 0.7, 2.2), dur)
					4: # Elixir: bright lime-gold speed wind streaks & foot dust puffs + adrenaline trail
						dur = 0.54
						var mat_elx := _get_shared_mat(Color(0.74, 1.0, 0.24, 0.94), true)
						var mat_edust := _get_shared_mat(Color(0.86, 0.82, 0.64, 0.72), false)
						for i in range(4):
							var sx: float = (float(i) - 1.5) * 0.34
							var stk := _vfx_part(root, box, mat_elx, Vector3(sx, 0.18 + (i % 2) * 0.14, 0.25), Vector3(0.06, 0.06, 0.75), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.70, dur)
						for j in range(3):
							var dx: float = (float(j) - 1.0) * 0.38
							var dp := _vfx_part(root, sph, mat_edust, Vector3(dx, 0.14, 0.18), Vector3(0.26, 0.18, 0.26), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(dp, "position", Vector3(dx * 1.2, 0.35, 1.15), dur)
						var adr := _vfx_part(root, box, mat_elx, Vector3(0.0, 0.75, 0.0), Vector3(0.10, 0.65, 0.10), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(adr, "position:y", 1.95, dur)
					_: # Mark Target: tactical red laser designator beam + overhead crimson target diamond
						dur = 0.65
						var mat_red := _get_shared_mat(Color(1.0, 0.16, 0.16, 0.94), true)
						var beam := _vfx_part(root, cyl, mat_red, Vector3(0.0, 1.48, -4.35), Vector3(0.07, 8.0, 0.07), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var diam_pivot := Node3D.new()
						diam_pivot.position = Vector3(0.0, 2.30, 0.0)
						root.add_child(diam_pivot)
						_vfx_part(diam_pivot, cone, mat_red, Vector3(0.0, -0.18, 0.0), Vector3(0.42, 0.42, 0.42), Vector3(PI, 0.0, 0.0), fade_meshes)
						_vfx_part(diam_pivot, cone, mat_red, Vector3(0.0, 0.18, 0.0), Vector3(0.42, 0.26, 0.42), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(beam, "scale", Vector3(0.02, 9.5, 0.02), dur)
							tw.tween_property(diam_pivot, "rotation:y", TAU, dur)
							tw.tween_property(diam_pivot, "position:y", 2.55, dur)

	if tw != null:
		for mi in fade_meshes:
			tw.tween_property(mi, "transparency", 1.0, dur)
		tw.chain().tween_callback(root.queue_free)


static func _get_aoe_theme_color(class_id: int, slot_idx: int) -> Color:
	if class_id == NetworkManager.CLASS_SOLDIER:
		match slot_idx:
			0:
				return Color(0.20, 0.95, 0.56)
			3:
				return Color(1.0, 0.56, 0.14)
			4:
				return Color(1.0, 0.86, 0.22)
	elif class_id == NetworkManager.CLASS_GUNNER and slot_idx == 1:
		return Color(0.32, 0.94, 1.0)
	return Color(1.0, 0.44, 0.12)


static func _spawn_aoe_rings_into(
	root: Node3D,
	radius: float,
	theme_col: Color,
	dur: float,
	disc_alpha: float,
	tw: Tween,
	fade_meshes: Array[MeshInstance3D]
) -> void:
	var cyl: CylinderMesh = _get_shared_cylinder()
	var torus: TorusMesh = _get_shared_torus()
	var diam: float = radius * 2.0

	var mat_disc: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, disc_alpha), false)
	var disc: MeshInstance3D = _vfx_part(
		root, cyl, mat_disc,
		Vector3(0.0, 0.08, 0.0),
		Vector3(diam, 0.03, diam),
		Vector3.ZERO, fade_meshes
	)
	disc.name = "AoEGroundDisc"

	var mat_perim: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, 0.90), true)
	var perim: MeshInstance3D = _vfx_part(
		root, torus, mat_perim,
		Vector3(0.0, 0.12, 0.0),
		Vector3(diam, 0.35, diam),
		Vector3.ZERO, fade_meshes
	)
	perim.name = "AoEPerimeterRing"

	var wave_col: Color = theme_col.lerp(Color.WHITE, 0.40)
	var mat_wave: StandardMaterial3D = _get_shared_mat(Color(wave_col.r, wave_col.g, wave_col.b, 0.92), true)
	var wave := MeshInstance3D.new()
	wave.name = "AoEWaveRing"
	wave.mesh = torus
	wave.material_override = mat_wave
	wave.position = Vector3(0.0, 0.14, 0.0)
	wave.scale = Vector3(radius * 0.4, 0.45, radius * 0.4)
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wave)

	if tw != null:
		tw.tween_property(wave, "scale", Vector3(diam, 0.45, diam), 0.45)
		tw.tween_property(wave, "transparency", 1.0, 0.45)
		tw.tween_property(disc, "transparency", 1.0, dur)
		tw.tween_property(perim, "transparency", 1.0, dur)


static func spawn_aoe_area_vfx(
	parent: Node,
	class_id: int,
	slot_idx: int,
	origin: Vector3,
	radius: float,
	affected_positions: Array[Vector3] = []
) -> Node3D:
	if parent == null or radius <= 0.0:
		return null
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "AoEAreaVFX_%d_%d" % [class_id, slot_idx]
	root.position = origin
	parent.add_child(root)

	var theme_col: Color = _get_aoe_theme_color(class_id, slot_idx)
	var dur: float = 1.1
	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	var ring_meshes: Array[MeshInstance3D] = []
	_spawn_aoe_rings_into(root, radius, theme_col, dur, 0.22, tw, ring_meshes)

	var cyl: CylinderMesh = _get_shared_cylinder()
	var torus: TorusMesh = _get_shared_torus()
	var marker_col: Color = theme_col.lerp(Color.WHITE, 0.30)
	var mat_marker: StandardMaterial3D = _get_shared_mat(Color(marker_col.r, marker_col.g, marker_col.b, 0.94), true)
	var mat_col: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, 0.42), true)
	var marker_meshes: Array[MeshInstance3D] = []
	var is_offensive: bool = (class_id == NetworkManager.CLASS_SOLDIER and slot_idx == 3)

	for idx in range(affected_positions.size()):
		var tpos: Vector3 = affected_positions[idx]
		var marker := Node3D.new()
		marker.name = "AffectedMarker_%d" % idx
		marker.position = tpos - origin
		root.add_child(marker)

		var halo: MeshInstance3D = _vfx_part(
			marker, torus, mat_marker,
			Vector3(0.0, 0.12, 0.0),
			Vector3(1.5, 0.55, 1.5),
			Vector3.ZERO, marker_meshes
		)
		var beam: MeshInstance3D = _vfx_part(
			marker, cyl, mat_col,
			Vector3(0.0, 1.15, 0.0),
			Vector3(0.42, 2.2, 0.42),
			Vector3.ZERO, marker_meshes
		)
		var emblem: Node3D = _vfx_plus_cross(
			marker, mat_marker,
			Vector3(0.0, 2.35, 0.0),
			0.42, 0.11, marker_meshes
		)
		if is_offensive:
			emblem.rotation.z = PI * 0.25

		if tw != null:
			tw.tween_property(halo, "scale", Vector3(2.1, 0.55, 2.1), 0.8)
			tw.tween_property(beam, "position:y", 1.95, 0.8)
			tw.tween_property(emblem, "position:y", 2.90, 0.8)
			tw.tween_property(emblem, "rotation:y", PI, 0.8)

	if tw != null:
		for mi in marker_meshes:
			tw.tween_property(mi, "transparency", 1.0, 0.8)
		tw.chain().tween_callback(root.queue_free)

	return root


static func spawn_explosion_area_ring(parent: Node, origin: Vector3, radius: float) -> Node3D:
	if parent == null or radius <= 0.0 or DisplayServer.get_name().contains("headless"):
		return null
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "ExplosionAreaVFX"
	root.position = origin
	parent.add_child(root)

	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	var ring_meshes: Array[MeshInstance3D] = []
	_spawn_aoe_rings_into(root, radius, Color(1.0, 0.44, 0.12), 0.65, 0.16, tw, ring_meshes)
	if tw != null:
		tw.chain().tween_callback(root.queue_free)

	return root
