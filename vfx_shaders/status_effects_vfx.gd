class_name StatusEffectsVFX
extends Node3D

## Cartoon VFX spawner (NO blood!): dust puffs, metallic sparks, fire, poison bubbles,
## Hero Shield bubble, and Stealth visibility/refraction evaluation on clients.

const HERO_SHADER: Shader = preload("res://vfx_shaders/hero_cel_shader.gdshader")


static func attach_hero_vfx_and_shader(hero: HeroCharacter) -> void:
	if hero == null:
		return
	hero.apply_character_shader(HERO_SHADER)


static func update_hero_client_visuals(hero: HeroCharacter, local_hero: HeroCharacter, _delta: float) -> void:
	if hero == null or hero.visual_root == null:
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

	for part in hero._mesh_parts:
		if part.material_override is ShaderMaterial:
			var smat := part.material_override as ShaderMaterial
			smat.set_shader_parameter("cloak_amount", cloak_val)
			if burning:
				smat.set_shader_parameter("rim_color", Color(1.0, 0.35, 0.05))
				smat.set_shader_parameter("rim_strength", 1.8)
			elif poisoned:
				smat.set_shader_parameter("rim_color", Color(0.25, 0.95, 0.25))
				smat.set_shader_parameter("rim_strength", 1.8)
			elif shielded:
				smat.set_shader_parameter("rim_color", Color(0.25, 0.72, 1.0))
				smat.set_shader_parameter("rim_strength", 1.65)
			else:
				smat.set_shader_parameter("rim_color", Color(1.0, 0.95, 0.82))
				smat.set_shader_parameter("rim_strength", 0.42)


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
		_:
			mat.albedo_color = Color(0.88, 0.86, 0.8, 0.75)

	burst.material_override = mat
	parent.add_child(burst)

	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(burst, "scale", Vector3.ONE * 1.8, 0.26)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.26)
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


static func spawn_bullet_tracer(parent: Node, start_pos: Vector3, end_pos: Vector3, weapon_kind: int) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	if weapon_kind == 5 or weapon_kind == 7 or weapon_kind == 6:
		return
	var diff: Vector3 = end_pos - start_pos
	var full_len: float = diff.length()
	if full_len < 0.6:
		return
	var dir: Vector3 = diff / full_len
	var seg_len: float = clampf(full_len * 0.38, 1.4, 14.0 if weapon_kind == 4 else 7.5)

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

	var p_a: Vector3 = start_pos + dir * (seg_len * 0.5 + 0.15)
	var p_b: Vector3 = end_pos - dir * minf(full_len * 0.15, seg_len * 0.35)
	tracer.position = p_a
	parent.add_child(tracer)
	if absf(dir.dot(Vector3.UP)) < 0.98:
		tracer.look_at(p_a + dir, Vector3.UP)

	var travel_t: float = clampf(full_len / 260.0, 0.055, 0.14)
	var tw: Tween = parent.create_tween()
	tw.set_parallel(true)
	tw.tween_property(tracer, "position", p_b, travel_t)
	tw.tween_property(mat, "albedo_color:a", 0.0, travel_t)
	tw.chain().tween_callback(tracer.queue_free)
