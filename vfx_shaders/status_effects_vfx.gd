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
				smat.set_shader_parameter("rim_strength", 0.72)


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
