class_name StatusEffectsVFX
extends Node3D

## Cartoon VFX spawner (NO blood!): dust puffs, metallic sparks, fire, poison bubbles,
## Hero Shield bubble, and Stealth visibility/refraction evaluation on clients.

const HERO_SHADER: Shader = preload("res://vfx_shaders/hero_cel_shader.gdshader")
const HERO_CLOAK_SHADER: Shader = preload("res://vfx_shaders/hero_cloak_shader.gdshader")
const XRAY_SHADER: Shader = preload("res://vfx_shaders/xray_silhouette.gdshader")

static var _xray_mat: ShaderMaterial = null


static func _get_xray_material() -> ShaderMaterial:
	if _xray_mat == null:
		_xray_mat = ShaderMaterial.new()
		_xray_mat.shader = XRAY_SHADER
	return _xray_mat


static func attach_hero_vfx_and_shader(hero: HeroCharacter) -> void:
	if hero == null:
		return
	hero.apply_character_shader(HERO_SHADER)


static func update_hero_client_visuals(hero: HeroCharacter, local_hero: HeroCharacter, _delta: float, vehicles_by_id: Dictionary = {}) -> void:
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
	if hidden_in_vehicle:
		hero.visual_root.visible = false
		return

	# Enemy Commando Stealth distance check (100% hidden beyond detection radius, refractive cloak inside)
	var is_enemy: bool = local_hero != null and hero.team != local_hero.team
	var stealthed: bool = (hero.active_flags & NetSerializer.SNAP_STEALTHED) != 0 or hero.is_stealthed
	var cloak_val: float = 0.0

	if stealthed:
		if is_enemy and local_hero != null:
			var detect_r: float = 10.0
			if hero.status_effects != null:
				detect_r = hero.status_effects.stealth_detection_radius
			var dist: float = hero.global_position.distance_to(local_hero.global_position)
			if dist > detect_r:
				hero.visual_root.visible = false
				return
			else:
				hero.visual_root.visible = not hero.is_scoping
				cloak_val = 0.88
		else:
			hero.visual_root.visible = not (hero.is_local_player and hero.is_scoping)
			cloak_val = 0.55
	else:
		hero.visual_root.visible = not (hero.is_local_player and hero.is_scoping)
		cloak_val = 0.0

	# Update shader parameters & status effect tints
	var burning: bool = (hero.active_flags & NetSerializer.SNAP_BURNING) != 0
	var poisoned: bool = (hero.active_flags & NetSerializer.SNAP_POISONED) != 0
	var shielded: bool = (hero.active_flags & NetSerializer.SNAP_SHIELDED) != 0
	var target_shader: Shader = HERO_CLOAK_SHADER if cloak_val > 0.01 else HERO_SHADER
	var marked_enemy: bool = is_enemy and ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0)
	var sensed_enemy: bool = is_enemy and local_hero != null and ((local_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0) and (hero.global_position.distance_to(local_hero.global_position) <= 55.0)
	var show_xray: bool = (marked_enemy or sensed_enemy) and not hero.is_defeated
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null

	for part in hero._mesh_parts:
		part.material_overlay = xray_ov
		if part.material_override is ShaderMaterial:
			var smat := part.material_override as ShaderMaterial
			if smat.shader != target_shader:
				smat.shader = target_shader
			smat.set_shader_parameter("cloak_amount", cloak_val)
			if burning:
				smat.set_shader_parameter("rim_color", Color(1.0, 0.35, 0.05))
				smat.set_shader_parameter("rim_strength", 1.8)
			elif poisoned:
				smat.set_shader_parameter("rim_color", Color(0.25, 0.95, 0.25))
				smat.set_shader_parameter("rim_strength", 1.8)
			elif marked_enemy:
				smat.set_shader_parameter("rim_color", Color(1.0, 0.16, 0.12))
				smat.set_shader_parameter("rim_strength", 2.0)
			elif shielded:
				smat.set_shader_parameter("rim_color", Color(0.25, 0.72, 1.0))
				smat.set_shader_parameter("rim_strength", 1.65)
			else:
				smat.set_shader_parameter("rim_color", Color(1.0, 0.95, 0.82))
				smat.set_shader_parameter("rim_strength", 0.42)


static func update_vehicle_client_visuals(veh: VehicleBase, local_hero: HeroCharacter) -> void:
	if veh == null or veh.is_destroyed or veh._visual_root == null:
		return
	var is_enemy: bool = local_hero != null and veh.team >= 0 and veh.team != local_hero.team
	var local_senses: bool = is_enemy and ((local_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0) and (veh.global_position.distance_to(local_hero.global_position) <= 55.0)
	var show_xray: bool = is_enemy and (veh.is_marked or local_senses)
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null
	_apply_overlay_recursive(veh._visual_root, xray_ov)


static func _apply_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = mat
	for ch in node.get_children():
		_apply_overlay_recursive(ch, mat)


static func spawn_cartoon_burst(parent: Node, world_pos: Vector3, kind: String, radius: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	var burst := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.28 if kind != "explosion" else clampf(radius * 0.45, 0.8, 3.5)
	sph.height = sph.radius * 2.0
	burst.mesh = sph
	burst.position = world_pos

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
			sph.radius = clampf(0.35 * radius, 0.25, 1.2)
			sph.height = sph.radius * 2.0
			mat.albedo_color = Color(0.28, 0.28, 0.30, 0.72)
		"fire":
			sph.radius = clampf(0.28 * radius, 0.2, 0.9)
			sph.height = sph.radius * 2.0
			mat.albedo_color = Color(1.0, 0.42, 0.08, 0.88)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.32, 0.04)
		_:
			mat.albedo_color = Color(0.88, 0.86, 0.8, 0.75)

	burst.material_override = mat
	parent.add_child(burst)

	var is_plume: bool = (kind == "smoke" or kind == "fire")
	var dur: float = 0.55 if is_plume else 0.26
	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst, "scale", Vector3.ONE * (2.2 if is_plume else 1.8), dur)
	if is_plume:
		tw.tween_property(burst, "position", world_pos + Vector3(randf_range(-0.3, 0.3), 2.4, randf_range(-0.3, 0.3)), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(burst.queue_free)


static func spawn_muzzle_flash(parent: Node, world_pos: Vector3, aim_dir: Vector3, weapon_kind: int) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	if weapon_kind == 5 or weapon_kind == 7: # Melee knife & thrown TNT have no muzzle flash
		return
	var flash_root := Node3D.new()
	flash_root.position = world_pos
	parent.add_child(flash_root)

	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	var base_r: float = 0.16 if weapon_kind == 6 or weapon_kind == 2 else (0.14 if weapon_kind == 4 else 0.10)
	sph.radius = base_r
	sph.height = base_r * 2.0
	core.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.90, 0.32, 0.95)
	core.material_override = mat
	flash_root.add_child(core)

	var streak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.01
	cone.bottom_radius = base_r * 0.85
	cone.height = base_r * 3.4
	streak.mesh = cone
	streak.material_override = mat
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
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.07)
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
	var box := BoxMesh.new()
	var thick: float = 0.036 if weapon_kind == 4 else 0.024
	box.size = Vector3(thick, thick, seg_len)
	tracer.mesh = box

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.94, 0.58, 0.88) if weapon_kind == 4 else Color(1.0, 0.86, 0.35, 0.80)
	tracer.material_override = mat

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
	tw.tween_property(mat, "albedo_color:a", 0.0, travel_t)
	tw.chain().tween_callback(tracer.queue_free)


static func spawn_bullet_tracer(parent: Node, start_pos: Vector3, end_pos: Vector3, weapon_kind: int) -> void:
	spawn_curved_tracer(parent, PackedVector3Array([start_pos, end_pos]), weapon_kind)


## Spawns unmistakable world VFX for every one of the 16 heroic skills and 4 widgets.
static func spawn_skill_vfx(parent: Node, class_id: int, slot_idx: int, world_pos: Vector3, aim_yaw: float = 0.0) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	var color := Color(0.3, 0.95, 0.45, 0.85)
	var max_scale: float = 2.6
	var is_ring: bool = true
	var dur: float = 0.48
	var y_offset: float = 1.05

	if slot_idx >= 100:
		match slot_idx - 100:
			0: color = Color(0.25, 0.96, 0.45, 0.82) # Bandages
			1: color = Color(0.95, 0.82, 0.22, 0.88) # Wrench
			2: color = Color(0.35, 0.78, 1.0, 0.85)  # Fireproof Underwear
			3: color = Color(0.22, 1.0, 0.62, 0.85)  # Antidote
	else:
		match class_id:
			NetworkManager.CLASS_SOLDIER:
				match slot_idx:
					0: color = Color(0.22, 0.95, 0.45, 0.85); max_scale = 5.5; y_offset = 0.25 # Combat Medicine aura
					1: color = Color(1.0, 0.42, 0.08, 0.90); max_scale = 2.0; y_offset = 1.25 # Burning Bullets
					2: color = Color(0.95, 0.65, 0.15, 0.85); max_scale = 2.4; y_offset = 1.35 # Grenade Spam
					3: color = Color(1.0, 0.55, 0.12, 0.92); max_scale = 7.5; y_offset = 0.45 # Blasting Strike shockwave
					4: color = Color(1.0, 0.86, 0.22, 0.72); max_scale = 9.0; is_ring = false; y_offset = 1.1; dur = 0.55 # Sixth Sense radar dome
			NetworkManager.CLASS_GUNNER:
				match slot_idx:
					0: color = Color(0.22, 0.68, 1.0, 0.78); max_scale = 3.2; is_ring = false; y_offset = 1.0 # Hero Shield dome
					1: color = Color(0.25, 0.92, 1.0, 0.88); max_scale = 3.8; y_offset = 0.2 # Leg It speed ring
					2: color = Color(0.95, 0.35, 0.12, 0.86); max_scale = 2.8; y_offset = 1.2 # Explosive Keg launch
					3: color = Color(1.0, 0.78, 0.18, 0.90); max_scale = 2.4; y_offset = 1.2 # Frenzy Fire
					4: color = Color(0.32, 1.0, 0.38, 0.85); max_scale = 4.5; y_offset = 0.8 # I Eat Grenades
			NetworkManager.CLASS_COMMANDO:
				match slot_idx:
					0: color = Color(0.75, 0.85, 0.95, 0.55); max_scale = 2.6; y_offset = 1.0 # Stealth smoke veil
					1: color = Color(1.0, 0.22, 0.22, 0.92); max_scale = 2.2; y_offset = 1.3 # Piercing Shot
					2: color = Color(0.25, 1.0, 0.25, 0.90); max_scale = 2.2; y_offset = 1.2 # Poisoned Blade
					3: color = Color(0.65, 0.58, 0.45, 0.82); max_scale = 2.2; y_offset = 0.15 # Troop Trap plant
					4: color = Color(0.55, 0.88, 1.0, 0.88); max_scale = 3.4; y_offset = 0.3 # Elixir surge
					5: color = Color(1.0, 0.18, 0.18, 0.88); max_scale = 6.0; y_offset = 1.5; dur = 0.65 # Mark Target laser sweep

	var vfx := MeshInstance3D.new()
	if is_ring:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.65
		cyl.bottom_radius = 0.75
		cyl.height = 0.14
		vfx.mesh = cyl
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.65
		sph.height = 1.3
		vfx.mesh = sph

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	vfx.material_override = mat
	vfx.position = world_pos + Vector3(0.0, y_offset, 0.0)
	vfx.rotation.y = aim_yaw
	parent.add_child(vfx)

	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(vfx, "scale", Vector3(max_scale, 1.5 if is_ring else max_scale, max_scale), dur)
	tw.tween_property(mat, "albedo_color:a", 0.0, dur)
	tw.chain().tween_callback(vfx.queue_free)
