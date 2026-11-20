class_name GameCache
extends RefCounted

## Central Asset, Mesh, Material, and GPU Shader Pipeline Pre-Warming Cache.
## Populates CartoonAssets textures, Hero/Building/Vehicle meshes & palettes,
## and compiles Vulkan/Forward+ shader pipelines during the Loading Screen so
## entering Town Square or combat produces zero first-frame hitching.

static var _textures_warmed: bool = false
static var _meshes_warmed: bool = false
static var _gpu_warmed: bool = false

const ALL_TEXTURE_KEYS: Array[String] = [
	"grass", "cobble", "sidewalk", "wood_crate",
	"stucco_yellow", "stucco_cream", "stucco_ochre", "stucco_terracotta",
	"stone_masonry", "awning_stripe", "awning_stripe_blue", "tarmac_runway",
	"water_fountain", "roof_terracotta", "slate_roof", "wood_shingle",
	"foliage", "bark", "sand",
	"hero_jacket_royal", "hero_jacket_national", "hero_coat_commando",
	"hero_coat_commando_royal", "hero_gunner_vest",
	"hero_cloth_royal", "hero_cloth_national",
	"hero_cloth_commando_royal", "hero_cloth_commando_national",
	"hero_cloth_gunner_royal", "hero_skin", "hero_arm_tattoo",
	"hero_arm_forearm_wrap", "hero_rucksack", "hero_leather",
	"hero_pants_royal", "hero_pants_national", "hero_gun_wood",
	"veh_olive", "veh_panzer", "veh_steel", "veh_track", "veh_tire",
	"veh_wood_deck", "veh_plane_royal", "veh_plane_national", "veh_sandbag",
	"flag_royal", "flag_national", "icon_hp", "icon_ammo",
	"portrait_royal_0", "portrait_royal_1", "portrait_royal_2", "portrait_royal_3", "portrait_royal_4", "portrait_royal_5",
	"portrait_national_0", "portrait_national_1", "portrait_national_2", "portrait_national_3", "portrait_national_4", "portrait_national_5",
]

const SHADER_PATHS: Array[String] = [
	"res://vfx_shaders/fountain_water.gdshader",
	"res://vfx_shaders/hero_cel_shader.gdshader",
	"res://vfx_shaders/hero_cloak_shader.gdshader",
	"res://vfx_shaders/toon_sky.gdshader",
	"res://vfx_shaders/water_toon.gdshader",
	"res://vfx_shaders/xray_silhouette.gdshader",
]


static func clear_all() -> void:
	_textures_warmed = false
	_meshes_warmed = false
	_gpu_warmed = false


static func is_textures_warmed() -> bool:
	return _textures_warmed


static func is_meshes_warmed() -> bool:
	return _meshes_warmed


static func is_gpu_warmed() -> bool:
	return _gpu_warmed


## Pre-generates and caches every procedural albedo texture and HUD/portrait icon.
static func warm_textures() -> void:
	if _textures_warmed:
		return
	for k in ALL_TEXTURE_KEYS:
		CartoonAssets.get_texture(k)
	for wk in range(16):
		CartoonAssets.get_texture("icon_weapon_%d" % wk)
		for arch in range(3):
			CartoonAssets.get_texture("icon_weapon_%d_%d" % [wk, arch])
	for cls in range(6):
		var sk_count: int = 6 if cls == NetworkManager.CLASS_COMMANDO else 5
		for sk in range(sk_count):
			CartoonAssets.get_texture("icon_skill_%d_%d" % [cls, sk])
	for wi in range(4):
		CartoonAssets.get_texture("icon_widget_%d" % wi)
	_textures_warmed = true


## Pre-builds shared Building/Tree/Vehicle palettes, Hero sculpted meshes, and 3D weapon parts.
static func warm_meshes() -> void:
	if _meshes_warmed:
		return
	BuildingMeshBuilder._make_palette()
	for tree_v in range(3):
		BuildingMeshBuilder.get_cached_tree_mesh(tree_v)
	VehicleMeshBuilder._make_palette(NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder._make_palette(NetworkManager.TEAM_NATIONAL)
	var tmp_v := Node3D.new()
	VehicleMeshBuilder.build_tank_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_tank_visuals(tmp_v, NetworkManager.TEAM_NATIONAL)
	VehicleMeshBuilder.build_jeep_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_plane_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_plane_visuals(tmp_v, NetworkManager.TEAM_NATIONAL)
	VehicleMeshBuilder.build_boat_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_aa_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_motorcycle_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_apc_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	VehicleMeshBuilder.build_mounted_mg_visuals(tmp_v, NetworkManager.TEAM_ROYAL)
	tmp_v.free()

	# Warm common Hero meshes across all 6 classes (Soldier 0 .. Marksman 5)
	HeroMeshBuilder.build_head_mesh()
	HeroMeshBuilder.build_hair_cap_mesh()
	HeroMeshBuilder.build_ear_mesh()
	HeroMeshBuilder.build_nose_mesh()
	HeroMeshBuilder.build_eyes_mesh()
	HeroMeshBuilder.build_sunglasses_mesh()
	HeroMeshBuilder.build_coat_tail_flap_mesh()
	HeroMeshBuilder.build_belt_pouch_mesh()
	HeroMeshBuilder.build_buckle_mesh()
	HeroMeshBuilder.build_scarf_mesh()
	HeroMeshBuilder.build_beret_mesh()
	HeroMeshBuilder.build_badge_mesh()
	HeroMeshBuilder.build_boot_mesh()
	HeroMeshBuilder.build_officer_cap_mesh()
	HeroMeshBuilder.build_fedora_mesh()
	HeroMeshBuilder.build_helmet_mesh(true)
	HeroMeshBuilder.build_helmet_mesh(false)
	HeroMeshBuilder.build_visor_helmet_mesh(true)
	HeroMeshBuilder.build_visor_helmet_mesh(false)
	HeroMeshBuilder.build_engineer_cap_mesh(true)
	HeroMeshBuilder.build_engineer_cap_mesh(false)
	HeroMeshBuilder.build_ranger_cap_mesh(true)
	HeroMeshBuilder.build_ranger_cap_mesh(false)
	HeroMeshBuilder.build_epaulet_mesh(true)
	HeroMeshBuilder.build_epaulet_mesh(false)
	for bs in range(3):
		HeroMeshBuilder.build_beard_mesh(bs)

	for cls in range(6):
		HeroMeshBuilder.build_torso_mesh(cls)
		HeroMeshBuilder.build_collar_lapels_mesh(cls)
		HeroMeshBuilder.build_backpack_mesh(cls)
		HeroMeshBuilder.build_waist_belt_mesh(cls)
		HeroMeshBuilder.build_bandolier_mesh(cls)

	var arm_r_scales: Array[float] = [1.0, 1.22, 0.96, 1.12, 1.02, 1.02]
	var arm_len_scales: Array[float] = [1.0, 1.12, 1.0, 1.05, 1.0, 1.02]
	var thigh_radii: Array[float] = [0.095, 0.115, 0.090, 0.106, 0.094, 0.095]
	for i in range(6):
		var ars: float = arm_r_scales[i]
		var als: float = arm_len_scales[i]
		HeroMeshBuilder.build_arm_segment_mesh(0.088 * ars, 0.072 * ars, 0.30 * als, true)
		HeroMeshBuilder.build_arm_segment_mesh(0.068 * ars, 0.056 * ars, 0.28 * als, false)
		HeroMeshBuilder.build_hand_mesh(ars)
		HeroMeshBuilder.build_rolled_sleeve_cap_mesh(0.088 * ars)
		HeroMeshBuilder.build_cuff_mesh(0.062 * ars)
		HeroMeshBuilder.build_thigh_mesh(thigh_radii[i])
		HeroMeshBuilder.build_calf_mesh(thigh_radii[i])

	var tmp_w := Node3D.new()
	for wk in range(16):
		for arch in range(3):
			HeroMeshBuilder.populate_weapon_root(tmp_w, wk, arch)
	HeroMeshBuilder.populate_tnt_rope_root(tmp_w)
	HeroMeshBuilder.populate_build_wrench_root(tmp_w)
	HeroMeshBuilder.populate_mortar_tube_root(tmp_w)
	tmp_w.free()
	StatusEffectsVFX.warm_shared_meshes()
	_meshes_warmed = true


## Spawns tiny offscreen/micro meshes for every ShaderMaterial, StandardMaterial variant,
## and GPUParticles3D pipeline so Vulkan compiles all shaders while LoadingOverlay is visible.
static func prewarm_gpu_pipelines(host_node: Node3D) -> Node3D:
	if _gpu_warmed or host_node == null:
		return null
	var root := Node3D.new()
	root.name = "GpuPipelinePrewarm"
	host_node.add_child(root)

	var cam := host_node.get_viewport().get_camera_3d() if host_node.get_viewport() != null else null
	var anchor: Vector3 = Vector3(0.0, 4.0, 40.0)
	if cam != null:
		anchor = cam.global_position + (-cam.global_basis.z * 2.0)
	else:
		var prewarm_cam := Camera3D.new()
		prewarm_cam.position = anchor + Vector3(0.0, 0.0, 2.5)
		root.add_child(prewarm_cam)
		prewarm_cam.current = true

	var tiny_box := BoxMesh.new()
	tiny_box.size = Vector3(0.01, 0.01, 0.01)

	for i in range(SHADER_PATHS.size()):
		var sh: Shader = load(SHADER_PATHS[i]) as Shader
		if sh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = tiny_box
		mi.position = anchor + Vector3(float(i) * 0.02, 0.0, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sm := ShaderMaterial.new()
		sm.shader = sh
		mi.material_override = sm
		root.add_child(mi)

	var hero_tex_sh: Shader = load("res://vfx_shaders/hero_cel_shader.gdshader") as Shader
	if hero_tex_sh != null:
		var mi_tex := MeshInstance3D.new()
		mi_tex.mesh = tiny_box
		mi_tex.position = anchor + Vector3(0.0, 0.01, 0.0)
		mi_tex.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sm_tex := ShaderMaterial.new()
		sm_tex.shader = hero_tex_sh
		sm_tex.set_shader_parameter("use_tex", true)
		sm_tex.set_shader_parameter("albedo_tex", CartoonAssets.get_texture("hero_jacket_royal"))
		sm_tex.set_shader_parameter("cloak_amount", 0.0)
		mi_tex.material_override = sm_tex
		root.add_child(mi_tex)

	var pal: Dictionary = BuildingMeshBuilder._make_palette()
	var sample_mats: Array[Material] = [
		pal.get("stone"),
		pal.get("glass"),
		pal.get("glow_gold"),
	]
	for vfx_m in StatusEffectsVFX.get_prewarm_materials():
		sample_mats.append(vfx_m)
	for j in range(sample_mats.size()):
		if sample_mats[j] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = tiny_box
		mi.position = anchor + Vector3(0.0, 0.02 + float(j) * 0.02, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = sample_mats[j]
		root.add_child(mi)

	var lbl3d := Label3D.new()
	lbl3d.text = "."
	lbl3d.pixel_size = 0.001
	lbl3d.position = anchor
	root.add_child(lbl3d)

	if not OS.has_feature("web"):
		var gp := GPUParticles3D.new()
		gp.position = anchor
		gp.amount = 2
		gp.lifetime = 0.1
		gp.one_shot = true
		gp.emitting = true
		gp.draw_pass_1 = tiny_box
		gp.process_material = ParticleProcessMaterial.new()
		gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(gp)

	_gpu_warmed = true
	return root


static func cleanup_prewarm(node: Node) -> void:
	if node != null and is_instance_valid(node):
		var p: Node = node.get_parent()
		if p != null:
			p.remove_child(node)
		node.queue_free()
