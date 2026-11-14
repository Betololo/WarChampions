class_name MapSeasideFrontline
extends Node3D

## Large 2x Scale Coastal Island Map ("Seaside Frontline") for 12v12 Land, Air & Water combat.
## Features 2400m x 2400m Ocean, 1600m x 1080m Coastal Island, sculpted Mediterranean architecture
## via BuildingMeshBuilder (Town Square CentralFountain, Mercadinho, ChurchChapel, Windmill,
## CoastalLighthouse + Keeper's Cottage, 34 sculpted houses, 6 climbable Watchtowers, 220m Spawn
## Airstrips with Hangars & ATC towers, 3 Harbor Piers w/ 6 ocean Boats, and 150+ layered trees).

const WATER_SHADER: Shader = preload("res://vfx_shaders/water_toon.gdshader")

var royal_spawns: Array[Vector3] = []
var national_spawns: Array[Vector3] = []
var capture_points: Array[CapturePoint] = []
var spawned_vehicles: Array[VehicleBase] = []
var _windmill_blades: Node3D
var _next_vehicle_id: int = 1


func build_map(conquest: ConquestManager, vehicles_parent: Node3D, combat_context: Dictionary) -> void:
	_build_sky_and_lighting()
	_build_ocean_and_terrain()
	_build_roads_and_sidewalks()
	_build_runways_and_harbors()
	_build_landmarks_and_village()
	_build_watchtowers()
	_build_trees_and_foliage()
	_build_destructible_props(combat_context)
	_build_capture_points(conquest)
	_build_spawn_points()
	_spawn_all_vehicles(vehicles_parent)


func _process(delta: float) -> void:
	if _windmill_blades != null:
		_windmill_blades.rotation.z += 0.95 * delta


func _build_sky_and_lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.14, 0.54, 0.98)
	mat.sky_horizon_color = Color(0.64, 0.88, 1.0)
	mat.ground_bottom_color = Color(0.10, 0.42, 0.66)
	mat.ground_horizon_color = Color(0.64, 0.88, 1.0)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.78
	# Subtle distant aerial haze past 950m so the entire 1600m island remains vivid and crisp
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.68, 0.88, 1.0)
	env.fog_sky_affect = 0.20
	env.fog_depth_begin = 950.0
	env.fog_depth_end = 2750.0

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_energy = 1.52
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.rotation_degrees = Vector3(-46.0, 36.0, 0.0)
	sun.directional_shadow_max_distance = 260.0
	sun.shadow_enabled = not DisplayServer.get_name().contains("headless")
	add_child(sun)


func _build_ocean_and_terrain() -> void:
	# 2400m x 2400m Navigable Ocean Plane at Y = -0.35 (water surface Y = 0.0 physics)
	var ocean_mesh := MeshInstance3D.new()
	ocean_mesh.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(2400.0, 2400.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	ocean_mesh.mesh = plane
	ocean_mesh.position = Vector3(0.0, -0.35, 0.0)
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	ocean_mesh.material_override = water_mat
	add_child(ocean_mesh)

	# Deep Seafloor under ocean (top Y = -7.0)
	_create_solid_box("Seafloor", Vector3(2400.0, 2.0, 2400.0), Vector3(0.0, -8.0, 0.0), CartoonAssets.make_standard_material("sand", Color(0.46, 0.56, 0.52), Vector2(48, 48)))

	# Doubled Coastal Island Base (1600m x 1080m sandy beach @ top Y=1.0, 1440m x 920m grass @ top Y=2.15)
	_create_solid_box("BeachBase", Vector3(1600.0, 2.4, 1080.0), Vector3(0.0, -0.2, 0.0), CartoonAssets.make_standard_material("sand", Color.WHITE, Vector2(64, 44)))
	_create_solid_box("GrassMainland", Vector3(1440.0, 2.6, 920.0), Vector3(0.0, 0.85, 0.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(88, 56)))

	# Sandy coastal beach-to-grass access ramps around the island perimeter
	var beach_ramp_mat := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(3, 3))
	_create_ramp("BeachRampW", Vector3(26.0, 1.4, 18.0), Vector3(-728.0, 1.0, 40.0), Vector3(0.0, 0.0, 0.08), beach_ramp_mat)
	_create_ramp("BeachRampE", Vector3(26.0, 1.4, 18.0), Vector3(728.0, 1.0, 40.0), Vector3(0.0, 0.0, -0.08), beach_ramp_mat)
	_create_ramp("BeachRampSW", Vector3(18.0, 1.4, 24.0), Vector3(-190.0, 1.0, 466.0), Vector3(-0.08, 0.0, 0.0), beach_ramp_mat)
	_create_ramp("BeachRampSE", Vector3(18.0, 1.4, 24.0), Vector3(190.0, 1.0, 466.0), Vector3(-0.08, 0.0, 0.0), beach_ramp_mat)

	# North-West Windmill Hill (Flag B, top Y = 12.15) with limestone cliff walls + turf cap & 3 driving ramps
	var cliff_stone := BuildingMeshBuilder.make_mat(Color(0.84, 0.79, 0.72), "stone_masonry", 0.88, 0.02, 1.0, Vector2(18.0, 3.0))
	_create_solid_box("WindmillPlateau", Vector3(159.2, 9.35, 159.2), Vector3(-230.0, 6.825, -240.0), cliff_stone)
	_create_solid_box("WindmillTurfCap", Vector3(160.0, 0.66, 160.0), Vector3(-230.0, 11.82, -240.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(12, 12)))
	_create_ramp("WindmillRampS", Vector3(26.0, 2.0, 62.0), Vector3(-230.0, 6.20, -132.0), Vector3(0.165, 0.0, 0.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(3, 8)))
	_create_ramp("WindmillRampW", Vector3(62.0, 2.0, 26.0), Vector3(-338.0, 6.20, -240.0), Vector3(0.0, 0.0, 0.165), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(8, 3)))
	_create_ramp("WindmillRampE", Vector3(62.0, 2.0, 26.0), Vector3(-122.0, 6.20, -240.0), Vector3(0.0, 0.0, -0.165), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(8, 3)))

	# North-East Harbor Ruins Cliff (Flag D, top Y = 7.65) with limestone cliff walls + turf cap & 2 driving ramps
	_create_solid_box("RuinsCliff", Vector3(159.2, 4.85, 159.2), Vector3(280.0, 4.575, -240.0), cliff_stone)
	_create_solid_box("RuinsTurfCap", Vector3(160.0, 0.66, 160.0), Vector3(280.0, 7.32, -240.0), CartoonAssets.make_standard_material("grass", Color(0.86, 0.93, 0.78), Vector2(12, 12)))
	_create_ramp("RuinsRampS", Vector3(26.0, 2.0, 42.0), Vector3(280.0, 3.90, -140.0), Vector3(0.137, 0.0, 0.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(3, 5)))
	_create_ramp("RuinsRampW", Vector3(42.0, 2.0, 26.0), Vector3(180.0, 3.90, -240.0), Vector3(0.0, 0.0, 0.137), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(5, 3)))

	# South-West Lighthouse Cliff (top Y = 6.15 overlooking ocean cove & Flag A) with limestone cliff walls + turf cap
	_create_solid_box("LighthouseCliff", Vector3(119.2, 3.35, 119.2), Vector3(-470.0, 3.825, 315.0), cliff_stone)
	_create_solid_box("LighthouseTurfCap", Vector3(120.0, 0.66, 120.0), Vector3(-470.0, 5.82, 315.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(9, 9)))
	_create_ramp("LighthouseRampE", Vector3(42.0, 2.0, 24.0), Vector3(-390.0, 3.15, 315.0), Vector3(0.0, 0.0, -0.10), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(5, 3)))


func _build_roads_and_sidewalks() -> void:
	var cobble_ew := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(56, 2))
	var cobble_ns := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 42))
	var cobble_plaza := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(14, 12))
	var sw_ew := CartoonAssets.make_standard_material("sidewalk", Color.WHITE, Vector2(26, 1))
	var sw_ns := CartoonAssets.make_standard_material("sidewalk", Color.WHITE, Vector2(1, 24))

	# Main 1280m East-West Cobblestone Boulevard through Town Square (sidewalks flank plaza outside [-53, 53])
	_create_solid_box("MainRoadEW", Vector3(1280.0, 0.24, 16.0), Vector3(0.0, 2.155, 40.0), cobble_ew)
	_create_solid_box("SidewalkNorthW", Vector3(587.0, 0.34, 2.8), Vector3(-346.5, 2.19, 30.6), sw_ew)
	_create_solid_box("SidewalkNorthE", Vector3(587.0, 0.34, 2.8), Vector3(346.5, 2.19, 30.6), sw_ew)
	_create_solid_box("SidewalkSouthW", Vector3(587.0, 0.34, 2.8), Vector3(-346.5, 2.19, 49.4), sw_ew)
	_create_solid_box("SidewalkSouthE", Vector3(587.0, 0.34, 2.8), Vector3(346.5, 2.19, 49.4), sw_ew)

	# Cross Town North-South Avenue (reaches South Harbor Coastal Loop at Z = 460)
	_create_solid_box("CrossRoadNS", Vector3(15.0, 0.24, 820.0), Vector3(0.0, 2.14, 50.0), cobble_ns)
	_create_solid_box("CrossWalkW", Vector3(2.8, 0.32, 353.0), Vector3(-8.9, 2.17, -183.5), sw_ns)
	_create_solid_box("CrossWalkE", Vector3(2.8, 0.32, 353.0), Vector3(8.9, 2.17, -183.5), sw_ns)

	# Central Town Square Cobblestone Plaza Apron (top Y = 2.295m cleanly above roads)
	_create_solid_box("TownSquarePlaza", Vector3(106.0, 0.26, 94.0), Vector3(0.0, 2.165, 40.0), cobble_plaza)

	# South Harbor Coastal Link Road (connects RoyalPier, CentralPier & NationalPier) + West Cove Spur
	_create_solid_box("SouthCoastalRoad", Vector3(840.0, 0.22, 13.0), Vector3(0.0, 2.14, 444.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(36, 2)))
	_create_solid_box("WestCoveRoad", Vector3(13.0, 0.22, 412.0), Vector3(-345.0, 2.14, 246.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 22)))

	_build_streetlamps_and_bunting()


func _build_streetlamps_and_bunting() -> void:
	var pole_mat := BuildingMeshBuilder.make_mat(Color(0.20, 0.22, 0.25), "", 0.50, 0.45)
	var wood_mat := CartoonAssets.make_standard_material("bark")
	var bulb_mat := BuildingMeshBuilder.make_mat(Color(1.0, 0.92, 0.58), "", 0.18, 0.0)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.86, 0.40)
	bulb_mat.emission_energy_multiplier = 2.0

	# Boulevard Utility Poles & Town Square Streetlamps (skip central open plaza [-54, +54])
	for x in range(-360, 380, 65):
		var px_n: float = float(x)
		var px_s: float = float(x) + 32.0
		if absf(px_n) >= 54.0:
			_create_solid_box("PoleN_%d" % x, Vector3(0.36, 9.2, 0.36), Vector3(px_n, 6.75, 29.2), wood_mat)
		if absf(px_s) >= 54.0:
			_create_solid_box("PoleS_%d" % x, Vector3(0.36, 9.2, 0.36), Vector3(px_s, 6.75, 50.8), wood_mat)
		if absi(x) <= 260 and absf(px_n) >= 54.0:
			var lamp := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.28
			lm.bottom_radius = 0.20
			lm.height = 0.55
			lamp.mesh = lm
			lamp.position = Vector3(px_n, 8.2, 30.8)
			lamp.material_override = bulb_mat
			add_child(lamp)
			var arm := MeshInstance3D.new()
			var am := BoxMesh.new()
			am.size = Vector3(0.18, 0.18, 1.8)
			arm.mesh = am
			arm.position = Vector3(px_n, 8.5, 30.0)
			arm.material_override = pole_mat
			add_child(arm)

	# Festive Battlefield Heroes Triangle Pennant Bunting across Town Square Plaza
	var pennant_mats: Array[Material] = [
		BuildingMeshBuilder.make_mat(Color(0.88, 0.18, 0.16)),
		BuildingMeshBuilder.make_mat(Color(0.96, 0.80, 0.18)),
		BuildingMeshBuilder.make_mat(Color(0.16, 0.48, 0.92)),
		BuildingMeshBuilder.make_mat(Color(0.24, 0.72, 0.30)),
	]
	for bx in [-36.0, -14.0, 14.0, 36.0]:
		var cord := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.08, 0.08, 22.0)
		cord.mesh = cm
		cord.position = Vector3(bx, 9.2, 40.0)
		cord.material_override = pole_mat
		add_child(cord)
		for idx in range(9):
			var pz: float = lerpf(30.5, 49.5, float(idx) / 8.0)
			var sag: float = sin((float(idx) / 8.0) * PI) * 0.75
			var flag := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.left_to_right = 0.5
			pm.size = Vector3(0.08, 0.75, 0.85)
			flag.mesh = pm
			flag.position = Vector3(bx, 8.85 - sag, pz)
			flag.rotation.z = PI
			flag.material_override = pennant_mats[idx % pennant_mats.size()]
			add_child(flag)


func _build_runways_and_harbors() -> void:
	# Royal West Airfield (220m clear runway beside Royal Spawn + Hangar + ATC shack)
	BuildingMeshBuilder.build_airstrip_complex(self, Vector3(-490.0, 2.16, -90.0), 0.0, NetworkManager.TEAM_ROYAL, "RoyalRunway")
	# National East Airfield (220m clear runway beside National Spawn + Hangar + ATC shack)
	BuildingMeshBuilder.build_airstrip_complex(self, Vector3(490.0, 2.16, 105.0), PI, NetworkManager.TEAM_NATIONAL, "NationalRunway")

	# 3 Accessible Coastal Harbor Piers extending from mainland out over open ocean (Z > 542)
	BuildingMeshBuilder.build_harbor_pier(self, Vector3(-370.0, 0.0, 458.0), 0.0, "RoyalPier")
	BuildingMeshBuilder.build_harbor_pier(self, Vector3(0.0, 0.0, 458.0), 0.0, "CentralPier")
	BuildingMeshBuilder.build_harbor_pier(self, Vector3(370.0, 0.0, 458.0), 0.0, "NationalPier")


func _build_landmarks_and_village() -> void:
	# 1. Town Square Centerpiece: Sculpted Multi-Tier Fountain + Bustling Mercadinho + Church Chapel
	BuildingMeshBuilder.build_central_fountain(self, Vector3(0.0, 2.295, 40.0))
	BuildingMeshBuilder.build_mercadinho_complex(self, Vector3(28.0, 2.295, 66.0))
	BuildingMeshBuilder.build_church_chapel(self, Vector3(28.0, 2.15, -16.0), 0.0)

	# 2. Windmill Landmark atop Windmill Hill (Flag B)
	var windmill: Node3D = BuildingMeshBuilder.build_windmill(self, Vector3(-250.0, 12.15, -262.0), 0.35)
	_windmill_blades = windmill.get_node_or_null("WindmillBlades") as Node3D

	# 3. Coastal Lighthouse + Keeper's Cottage overlooking Southwest Ocean Cove
	BuildingMeshBuilder.build_coastal_lighthouse(self, Vector3(-475.0, 6.15, 325.0))

	# 4. Sculpted Mediterranean Village Houses (34 buildings with all 3 architectural styles)
	var houses: Array[Dictionary] = [
		# Town Square Plaza perimeter
		{"pos": Vector3(-26.0, 2.15, -16.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(-24.0, 2.15, 97.0), "yaw": PI, "style": 2},
		{"pos": Vector3(-63.0, 2.15, 16.0), "yaw": PI * 0.5, "style": 2},
		{"pos": Vector3(-63.0, 2.15, 64.0), "yaw": PI * 0.5, "style": 1},
		{"pos": Vector3(63.0, 2.15, 14.0), "yaw": -PI * 0.5, "style": 1},
		{"pos": Vector3(63.0, 2.15, 64.0), "yaw": -PI * 0.5, "style": 0},
		# West Boulevard North & South
		{"pos": Vector3(-98.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(-140.0, 2.15, 16.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(-182.0, 2.15, 16.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(-228.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(-274.0, 2.15, 16.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(-98.0, 2.15, 66.0), "yaw": PI, "style": 2},
		{"pos": Vector3(-140.0, 2.15, 66.0), "yaw": PI, "style": 0},
		{"pos": Vector3(-182.0, 2.15, 66.0), "yaw": PI, "style": 1},
		{"pos": Vector3(-228.0, 2.15, 66.0), "yaw": PI, "style": 2},
		{"pos": Vector3(-274.0, 2.15, 66.0), "yaw": PI, "style": 0},
		# East Boulevard North & South
		{"pos": Vector3(98.0, 2.15, 16.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(140.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(182.0, 2.15, 16.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(228.0, 2.15, 16.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(274.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(98.0, 2.15, 66.0), "yaw": PI, "style": 0},
		{"pos": Vector3(140.0, 2.15, 66.0), "yaw": PI, "style": 1},
		{"pos": Vector3(182.0, 2.15, 66.0), "yaw": PI, "style": 2},
		{"pos": Vector3(228.0, 2.15, 66.0), "yaw": PI, "style": 0},
		{"pos": Vector3(274.0, 2.15, 66.0), "yaw": PI, "style": 1},
		# North & South Cross Avenue Cottages
		{"pos": Vector3(-26.0, 2.15, -85.0), "yaw": PI * 0.5, "style": 0},
		{"pos": Vector3(26.0, 2.15, -85.0), "yaw": -PI * 0.5, "style": 2},
		{"pos": Vector3(-26.0, 2.15, -140.0), "yaw": PI * 0.5, "style": 1},
		{"pos": Vector3(26.0, 2.15, -140.0), "yaw": -PI * 0.5, "style": 0},
		# Southern Harbor Village Cottages
		{"pos": Vector3(-325.0, 2.15, 424.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(-405.0, 2.15, 424.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(325.0, 2.15, 424.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(405.0, 2.15, 424.0), "yaw": 0.0, "style": 0},
	]
	for idx in range(houses.size()):
		var h: Dictionary = houses[idx]
		var built: Node3D = BuildingMeshBuilder.build_town_house(self, h["pos"], float(h["yaw"]), int(h["style"]))
		built.name = "VillageHouse_%d" % idx

	# 5. Harbor Ruins Stone Fortress Walls atop RuinsCliff (Flag D, Y = 7.65)
	var masonry := BuildingMeshBuilder.make_mat(Color.WHITE, "stone_masonry", 0.86, 0.02, 1.0, Vector2(4.0, 2.0))
	var trim_stone := BuildingMeshBuilder.make_mat(Color(0.84, 0.80, 0.74), "stone_masonry", 0.84, 0.02, 1.0, Vector2(2.0, 1.5))
	_create_solid_box("RuinWallN", Vector3(34.0, 5.4, 2.6), Vector3(280.0, 7.65 + 2.7, -280.0), masonry)
	_create_solid_box("RuinWallE", Vector3(2.6, 5.4, 30.0), Vector3(312.0, 7.65 + 2.7, -238.0), masonry)
	_create_solid_box("RuinBastionPillarL", Vector3(4.2, 7.2, 4.2), Vector3(262.0, 7.65 + 3.6, -280.0), trim_stone)
	_create_solid_box("RuinBastionPillarR", Vector3(4.2, 7.2, 4.2), Vector3(298.0, 7.65 + 3.6, -280.0), trim_stone)
	_create_solid_box("RuinArchLintel", Vector3(22.0, 2.0, 3.2), Vector3(280.0, 7.65 + 5.8, -206.0), trim_stone)


func _build_watchtowers() -> void:
	var specs: Array[Dictionary] = [
		{"name": "Watchtower_1", "pos": Vector3(-155.0, 2.15, 102.0), "yaw": 0.0},
		{"name": "Watchtower_2", "pos": Vector3(155.0, 2.15, -12.0), "yaw": PI},
		{"name": "Watchtower_3", "pos": Vector3(-24.0, 2.15, 412.0), "yaw": 0.0},
		{"name": "Watchtower_4", "pos": Vector3(-125.0, 2.15, -290.0), "yaw": -PI * 0.5},
		{"name": "Watchtower_5", "pos": Vector3(-365.0, 2.15, -18.0), "yaw": PI * 0.5},
		{"name": "Watchtower_6", "pos": Vector3(365.0, 2.15, 24.0), "yaw": -PI * 0.5},
	]
	for w in specs:
		BuildingMeshBuilder.build_watchtower(self, w["pos"], float(w["yaw"]), str(w["name"]))


func _build_trees_and_foliage() -> void:
	var tree_specs: Array[Dictionary] = []

	# 1. Hand-placed Boulevard & Town Square Oak/Cypress Trees (clear of doors & sidewalks)
	for bx in [-296.0, -251.0, -205.0, -161.0, -119.0, 119.0, 161.0, 205.0, 251.0, 296.0]:
		tree_specs.append({"pos": Vector3(bx, 2.15, 27.2), "var": 1 if int(absf(bx)) % 2 == 1 else 0, "scale": 1.0})
		tree_specs.append({"pos": Vector3(bx, 2.15, 52.8), "var": 0 if int(absf(bx)) % 2 == 1 else 1, "scale": 1.0})
	for px in [-48.0, 48.0]:
		for pz in [-2.0, 82.0]:
			tree_specs.append({"pos": Vector3(px, 2.15, pz), "var": 1, "scale": 1.05})

	# 2. Coastal Palm Trees along sandy beaches (top Y = 1.00, clear of harbor piers!)
	for px in range(-700, 740, 82):
		var fx: float = float(px)
		if absf(fx + 370.0) >= 24.0 and absf(fx) >= 24.0 and absf(fx - 370.0) >= 24.0:
			tree_specs.append({"pos": Vector3(fx, 1.0, 488.0 + sin(fx * 0.03) * 14.0), "var": 2, "scale": 1.05})
		tree_specs.append({"pos": Vector3(fx + 28.0, 1.0, -492.0 + cos(fx * 0.03) * 14.0), "var": 2, "scale": 1.0})
	for pz in [-360.0, -220.0, -80.0, 140.0, 280.0]:
		tree_specs.append({"pos": Vector3(-755.0, 1.0, pz), "var": 2, "scale": 1.1})
		tree_specs.append({"pos": Vector3(755.0, 1.0, pz), "var": 2, "scale": 1.1})

	# 3. Plateau decorative trees outside flag capture rings
	for corner in [Vector3(-292.0, 12.15, -302.0), Vector3(-168.0, 12.15, -302.0), Vector3(-292.0, 12.15, -178.0)]:
		tree_specs.append({"pos": corner, "var": 1, "scale": 1.1})
	for r_corner in [Vector3(218.0, 7.65, -302.0), Vector3(342.0, 7.65, -302.0), Vector3(342.0, 7.65, -178.0)]:
		tree_specs.append({"pos": r_corner, "var": 0, "scale": 1.05})

	# 4. Countryside Meadow Groves across the 1440m x 920m island (100+ deterministic trees)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var attempts: int = 0
	while tree_specs.size() < 162 and attempts < 600:
		attempts += 1
		var tx: float = rng.randf_range(-685.0, 685.0)
		var tz: float = rng.randf_range(-425.0, 405.0)
		if _is_tree_zone_blocked(tx, tz):
			continue
		var too_close: bool = false
		for existing in tree_specs:
			var ep: Vector3 = existing["pos"]
			if Vector2(ep.x, ep.z).distance_to(Vector2(tx, tz)) < 18.0:
				too_close = true
				break
		if too_close:
			continue
		var v_kind: int = 1 if (rng.randf() < 0.36) else 0
		tree_specs.append({"pos": Vector3(tx, 2.15, tz), "var": v_kind, "scale": rng.randf_range(0.88, 1.28)})

	for i in range(tree_specs.size()):
		var ts: Dictionary = tree_specs[i]
		var t_node: Node3D = BuildingMeshBuilder.build_layered_tree(self, ts["pos"], int(ts["var"]), float(ts["scale"]))
		t_node.name = "Tree_%d" % i


func _is_tree_zone_blocked(tx: float, tz: float) -> bool:
	# Keep main roads, town square, village corridor, runways, spawns, plateaus, cove & watchtowers clear
	if absf(tz - 40.0) < 34.0 or absf(tx) < 28.0:
		return true
	if absf(tx) < 305.0 and absf(tz - 40.0) < 92.0:
		return true
	if absf(tx) < 52.0 and tz > -170.0 and tz < 115.0:
		return true
	if tz > 400.0 or (absf(tx + 345.0) < 26.0 and tz > 20.0):
		return true
	# Royal & National Spawns + Vehicle Staging Zones
	if tx < -400.0 and absf(tz - 24.0) < 75.0:
		return true
	if tx > 400.0 and absf(tz - 12.0) < 75.0:
		return true
	# Wide Runway Flight Safety Corridors (280m+ takeoff lane)
	if tx >= -650.0 and tx <= -240.0 and tz >= -155.0 and tz <= -42.0:
		return true
	if tx >= 240.0 and tx <= 650.0 and tz >= 42.0 and tz <= 155.0:
		return true
	# Plateaus & Ramps + Lighthouse Cliff
	if tx >= -380.0 and tx <= -85.0 and tz >= -335.0 and tz <= -95.0:
		return true
	if tx >= 150.0 and tx <= 375.0 and tz >= -335.0 and tz <= -110.0:
		return true
	if tx >= -545.0 and tx <= -360.0 and tz >= 245.0 and tz <= 385.0:
		return true
	# Watchtowers & Capture Flag Rings
	for wpos in [
		Vector2(-155.0, 102.0), Vector2(155.0, -12.0), Vector2(-24.0, 412.0),
		Vector2(-125.0, -290.0), Vector2(-365.0, -18.0), Vector2(365.0, 24.0),
		Vector2(-335.0, 290.0),
	]:
		if Vector2(tx, tz).distance_to(wpos) < 22.0:
			return true
	return false


func _build_destructible_props(combat_context: Dictionary) -> void:
	var prop_spots: Array[Dictionary] = [
		# Town Square Plaza & Main Road cover crates
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-28.0, 2.28, 28.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-26.5, 2.28, 28.0), "rot": 0.1},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-27.2, 3.58, 28.0), "rot": 0.05},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(22.0, 2.28, 28.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(23.5, 2.28, 28.0), "rot": -0.1},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-18.0, 2.28, 52.0), "rot": 0.2},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-210.0, 2.15, 34.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-208.5, 2.15, 34.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(210.0, 2.15, 46.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(211.5, 2.15, 46.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-340.0, 2.15, 305.0), "rot": 0.3},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-218.0, 12.15, -248.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(268.0, 7.65, -242.0), "rot": 0.1},
		# White Picket Fences framing gardens & checkpoints
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(-115.0, 2.15, 27.5), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(-165.0, 2.15, 52.5), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(115.0, 2.15, 27.5), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(165.0, 2.15, 52.5), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(-355.0, 2.15, 428.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(355.0, 2.15, 428.0), "rot": 0.0},
		# Explosive Red Barrels
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-42.0, 2.28, 39.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(42.0, 2.28, 41.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-322.0, 2.15, 282.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-202.0, 12.15, -214.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(270.0, 7.65, -220.0), "rot": 0.0},
	]
	for p in prop_spots:
		var prop := DestructibleProp.new()
		prop.setup(int(p["kind"]), p["pos"], float(p["rot"]), combat_context)
		add_child(prop)


func _build_capture_points(conquest: ConquestManager) -> void:
	var specs: Array[Dictionary] = [
		{"name": "Lighthouse Cove", "pos": Vector3(-335.0, 2.15, 290.0), "owner": NetworkManager.TEAM_ROYAL},
		{"name": "Windmill Hill", "pos": Vector3(-210.0, 12.15, -220.0), "owner": -1},
		{"name": "Town Square", "pos": Vector3(-15.0, 2.28, 40.0), "owner": -1},
		{"name": "Harbor Ruins", "pos": Vector3(280.0, 7.65, -230.0), "owner": NetworkManager.TEAM_NATIONAL},
	]
	capture_points.clear()
	for i in range(specs.size()):
		var cp := CapturePoint.new()
		cp.setup(i, str(specs[i]["name"]), specs[i]["pos"], int(specs[i]["owner"]))
		add_child(cp)
		capture_points.append(cp)
		if conquest != null:
			conquest.register_capture_point(cp)


func _build_spawn_points() -> void:
	royal_spawns.clear()
	national_spawns.clear()
	# 12 Royal & 12 National spaced spawn pads RIGHT BESIDE their Airfields & Vehicle Pools (6.5m apart, clear >= 6m!)
	for i in range(12):
		var row: int = i / 3
		var col: int = i % 3
		royal_spawns.append(Vector3(-456.0 - float(row) * 6.5, 2.35, -6.0 + float(col) * 6.5))
		national_spawns.append(Vector3(456.0 + float(row) * 6.5, 2.35, 12.0 - float(col) * 6.5))


func _spawn_all_vehicles(vehicles_parent: Node3D) -> void:
	if vehicles_parent == null:
		return
	spawned_vehicles.clear()
	_next_vehicle_id = 1

	# Land Vehicles (Royal & National Staging Pads + Mid-map Contested)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-430.0, 3.0, 38.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-438.0, 3.0, 56.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_ROYAL, Vector3(-422.0, 3.2, 68.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_ROYAL, Vector3(-458.0, 3.2, 72.0), -PI * 0.5)

	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(430.0, 3.0, 38.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(438.0, 3.0, -28.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_NATIONAL, Vector3(422.0, 3.2, -40.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_NATIONAL, Vector3(458.0, 3.2, -44.0), PI * 0.5)

	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), -1, Vector3(-165.0, 3.0, -95.0), 0.0)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), -1, Vector3(0.0, 3.2, -165.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), -1, Vector3(0.0, 3.0, 260.0), 0.0)

	# Air Vehicles (2 Fighter Planes parked ready on each 220m Spawn Runway!)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_ROYAL, Vector3(-562.0, 2.65, -90.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_ROYAL, Vector3(-528.0, 2.65, -90.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_NATIONAL, Vector3(562.0, 2.65, 105.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_NATIONAL, Vector3(528.0, 2.65, 105.0), PI * 0.5)

	# Water Vehicles (6 Patrol Boats moored closely beside all 3 Harbor Piers over deep sea Z > 542!)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-376.0, -0.15, 562.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-364.0, -0.15, 562.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), -1, Vector3(-6.0, -0.15, 562.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), -1, Vector3(6.0, -0.15, 562.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(364.0, -0.15, 562.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(376.0, -0.15, 562.0), PI)

	# Fixed Anti-Aircraft Flak Guns
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_ROYAL, Vector3(-320.0, 2.15, 265.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_NATIONAL, Vector3(265.0, 7.65, -210.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, AAGun.new(), -1, Vector3(18.0, 2.15, 430.0), PI)


func _spawn_vehicle(parent: Node3D, v: VehicleBase, p_team: int, pos: Vector3, rot_y: float) -> void:
	v.id = _next_vehicle_id
	_next_vehicle_id += 1
	v.team = p_team
	v.position = pos
	v.rotation.y = rot_y
	v.name = "Vehicle_%d" % v.id
	parent.add_child(v)
	spawned_vehicles.append(v)


func get_spawn_position(team: int, slot_index: int) -> Vector3:
	if team == NetworkManager.TEAM_ROYAL and not royal_spawns.is_empty():
		return royal_spawns[posmod(slot_index, royal_spawns.size())]
	if not national_spawns.is_empty():
		return national_spawns[posmod(slot_index, national_spawns.size())]
	return Vector3(0.0, 4.0, 0.0)


func _create_solid_box(node_name: String, size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)

	add_child(body)
	return body


func _create_ramp(node_name: String, size: Vector3, pos: Vector3, rot: Vector3, material: Material) -> StaticBody3D:
	var body := _create_solid_box(node_name, size, pos, material)
	body.rotation = rot
	return body
