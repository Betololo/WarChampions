class_name MapSeasideFrontline
extends Node3D

## Large 1200m x 1200m Coastal Island Map ("Seaside Frontline") for 12v12 Land, Air & Water combat.
## Features hand-painted cartoon textures, cobblestone roads & sidewalks, 20+ detailed buildings,
## 60+ lush stylized trees, 4 diamond Capture Points, 3-layer verticality, 140m runways, harbors,
## bridges, destructible crates/fences/barrels, AA guns, and Jeep/Tank/Plane/Boat spawners.

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
	mat.sky_top_color = Color(0.16, 0.56, 0.98)
	mat.sky_horizon_color = Color(0.62, 0.86, 1.0)
	mat.ground_bottom_color = Color(0.12, 0.44, 0.68)
	mat.ground_horizon_color = Color(0.62, 0.86, 1.0)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.72

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.rotation_degrees = Vector3(-48.0, 36.0, 0.0)
	sun.shadow_enabled = not DisplayServer.get_name().contains("headless")
	add_child(sun)


func _build_ocean_and_terrain() -> void:
	# 1200m x 1200m Navigable Ocean Plane at Y = 0.0
	var ocean_mesh := MeshInstance3D.new()
	ocean_mesh.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200.0, 1200.0)
	plane.subdivide_width = 64
	plane.subdivide_depth = 64
	ocean_mesh.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	ocean_mesh.material_override = water_mat
	add_child(ocean_mesh)

	# Seafloor under ocean
	_create_solid_box("Seafloor", Vector3(1200.0, 2.0, 1200.0), Vector3(0.0, -7.0, 0.0), CartoonAssets.make_standard_material("sand", Color(0.5, 0.6, 0.55), Vector2(30, 30)))

	# Main Island Plateau (820m x 640m coastal landmass)
	_create_solid_box("BeachBase", Vector3(820.0, 2.4, 540.0), Vector3(0.0, 0.2, 0.0), CartoonAssets.make_standard_material("sand", Color.WHITE, Vector2(36, 24)))
	_create_solid_box("GrassMainland", Vector3(740.0, 2.6, 460.0), Vector3(0.0, 0.8, 0.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(44, 28)))

	# North-West Windmill Hill (Flag B) + 2 broad driving ramps
	_create_solid_box("WindmillPlateau", Vector3(110.0, 10.0, 110.0), Vector3(-115.0, 7.0, -125.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(8, 8)))
	_create_ramp("WindmillRampS", Vector3(22.0, 2.0, 56.0), Vector3(-115.0, 6.2, -52.0), Vector3(0.20, 0.0, 0.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 6)))
	_create_ramp("WindmillRampW", Vector3(56.0, 2.0, 22.0), Vector3(-188.0, 6.2, -125.0), Vector3(0.0, 0.0, 0.20), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(6, 2)))

	# North-East Harbor Ruins Cliff (Flag D) + ramp
	_create_solid_box("RuinsCliff", Vector3(105.0, 6.0, 105.0), Vector3(145.0, 4.5, -135.0), CartoonAssets.make_standard_material("grass", Color(0.85, 0.92, 0.78), Vector2(8, 8)))
	_create_ramp("RuinsRamp", Vector3(22.0, 2.0, 42.0), Vector3(145.0, 4.2, -68.0), Vector3(0.15, 0.0, 0.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 4)))

	# South-West Lighthouse Cliff (Flag A) + ramp
	_create_solid_box("LighthouseCliff", Vector3(95.0, 3.6, 95.0), Vector3(-140.0, 2.7, 150.0), CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(7, 7)))
	_create_ramp("LighthouseRamp", Vector3(20.0, 2.0, 32.0), Vector3(-140.0, 2.8, 92.0), Vector3(-0.12, 0.0, 0.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 4)))


func _build_roads_and_sidewalks() -> void:
	var cobble_mat := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(28, 2))
	var cobble_ns := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 18))
	var sw_mat := CartoonAssets.make_standard_material("sidewalk", Color.WHITE, Vector2(28, 1))
	var sw_ns := CartoonAssets.make_standard_material("sidewalk", Color.WHITE, Vector2(1, 18))

	# Main East-West Cobblestone Boulevard through Town Square
	_create_solid_box("MainRoadEW", Vector3(640.0, 0.22, 14.0), Vector3(0.0, 2.05, 55.0), cobble_mat)
	_create_solid_box("SidewalkNorth", Vector3(640.0, 0.36, 3.2), Vector3(0.0, 2.10, 46.5), sw_mat)
	_create_solid_box("SidewalkSouth", Vector3(640.0, 0.36, 3.2), Vector3(0.0, 2.10, 63.5), sw_mat)

	# Cross Town North-South Avenue
	_create_solid_box("CrossRoadNS", Vector3(14.0, 0.22, 340.0), Vector3(35.0, 2.04, 0.0), cobble_ns)
	_create_solid_box("CrossWalkW", Vector3(3.0, 0.34, 340.0), Vector3(26.5, 2.08, 0.0), sw_ns)
	_create_solid_box("CrossWalkE", Vector3(3.0, 0.34, 340.0), Vector3(43.5, 2.08, 0.0), sw_ns)

	# Street Utility Poles along the boulevard (like Image 1!)
	for x in range(-200, 220, 55):
		_create_solid_box("PoleN_%d" % x, Vector3(0.35, 9.0, 0.35), Vector3(float(x), 6.5, 45.2), CartoonAssets.make_standard_material("bark"))
		_create_solid_box("PoleS_%d" % x, Vector3(0.35, 9.0, 0.35), Vector3(float(x) + 25.0, 6.5, 64.8), CartoonAssets.make_standard_material("bark"))


func _build_runways_and_harbors() -> void:
	var tarmac := CartoonAssets.make_standard_material("sidewalk", Color(0.45, 0.47, 0.50), Vector2(10, 2))
	var wood := CartoonAssets.make_standard_material("wood_crate", Color(0.85, 0.72, 0.56), Vector2(4, 6))

	# Royal West Airfield (140m clear runway + hangar + tower)
	_create_solid_box("RoyalRunway", Vector3(140.0, 0.6, 24.0), Vector3(-285.0, 2.0, -25.0), tarmac)
	_create_detailed_building("RoyalHangar", Vector3(-320.0, 2.1, -60.0), Vector3(18.0, 8.0, 20.0), "stucco_cream", "terracotta", false)
	# Royal Harbor Pier extending into navigable ocean (South-West)
	_create_solid_box("RoyalPier", Vector3(36.0, 1.8, 60.0), Vector3(-250.0, 1.2, 265.0), wood)

	# National East Airfield (140m clear runway + hangar)
	_create_solid_box("NationalRunway", Vector3(140.0, 0.6, 24.0), Vector3(285.0, 2.0, 25.0), tarmac)
	_create_detailed_building("NationalHangar", Vector3(320.0, 2.1, 60.0), Vector3(18.0, 8.0, 20.0), "stucco_cream", "terracotta", false)
	# National Harbor Pier extending into navigable ocean (North-East)
	_create_solid_box("NationalPier", Vector3(36.0, 1.8, 60.0), Vector3(250.0, 1.2, -265.0), wood)


func _build_landmarks_and_village() -> void:
	var stucco_y := CartoonAssets.make_standard_material("stucco_yellow", Color.WHITE, Vector2(2, 2))
	var stucco_c := CartoonAssets.make_standard_material("stucco_cream", Color.WHITE, Vector2(2, 2))
	var roof_mat := CartoonAssets.make_standard_material("terracotta", Color.WHITE, Vector2(3, 3))

	# 1. Lighthouse Tower (Flag A)
	_create_solid_box("LighthouseBase", Vector3(8.5, 16.0, 8.5), Vector3(-156.0, 12.0, 164.0), stucco_c)
	_create_solid_box("LighthouseStripe", Vector3(8.8, 4.2, 8.8), Vector3(-156.0, 14.0, 164.0), roof_mat)
	_create_solid_box("LighthouseLamp", Vector3(6.2, 3.2, 6.2), Vector3(-156.0, 21.5, 164.0), CartoonAssets.make_standard_material("stucco_yellow", Color(1.0, 0.94, 0.45)))

	# 2. Windmill Landmark (Flag B)
	_create_solid_box("WindmillTower", Vector3(8.5, 16.0, 8.5), Vector3(-130.0, 20.0, -138.0), stucco_c)
	_create_solid_box("WindmillRoof", Vector3(9.5, 3.2, 9.5), Vector3(-130.0, 29.0, -138.0), roof_mat)
	_windmill_blades = Node3D.new()
	_windmill_blades.position = Vector3(-130.0, 25.0, -133.0)
	add_child(_windmill_blades)
	_add_visual_box(_windmill_blades, Vector3(1.2, 16.0, 0.35), Vector3.ZERO, CartoonAssets.make_standard_material("wood_crate"))
	_add_visual_box(_windmill_blades, Vector3(16.0, 1.2, 0.35), Vector3.ZERO, CartoonAssets.make_standard_material("wood_crate"))

	# 3. Town Square Church (Flag C)
	_create_solid_box("ChurchBody", Vector3(16.0, 10.5, 24.0), Vector3(35.0, 7.2, 24.0), stucco_c)
	_create_solid_box("ChurchRoof", Vector3(17.2, 2.4, 25.2), Vector3(35.0, 13.4, 24.0), roof_mat)
	_create_solid_box("ChurchBellTower", Vector3(7.0, 20.0, 7.0), Vector3(35.0, 12.0, 13.0), stucco_c)
	_create_solid_box("ChurchSpire", Vector3(5.2, 5.0, 5.2), Vector3(35.0, 24.5, 13.0), roof_mat)

	# 4. Rich Urban Village Houses lining Main Road & Side Streets (20 buildings with pitched roofs, windows, balconies & stairs!)
	var house_spots: Array[Dictionary] = [
		{"pos": Vector3(-35.0, 2.1, 32.0), "size": Vector3(14, 8, 12), "wall": "stucco_yellow", "stairs": true},
		{"pos": Vector3(-5.0, 2.1, 32.0), "size": Vector3(13, 7, 12), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(68.0, 2.1, 32.0), "size": Vector3(15, 8, 13), "wall": "stucco_yellow", "stairs": true},
		{"pos": Vector3(95.0, 2.1, 32.0), "size": Vector3(13, 7, 12), "wall": "stucco_cream", "stairs": false},
		{"pos": Vector3(-35.0, 2.1, 78.0), "size": Vector3(14, 8, 12), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(2.0, 2.1, 78.0), "size": Vector3(13, 7, 12), "wall": "stucco_yellow", "stairs": true},
		{"pos": Vector3(68.0, 2.1, 78.0), "size": Vector3(14, 8, 12), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(96.0, 2.1, 78.0), "size": Vector3(13, 7, 12), "wall": "stucco_yellow", "stairs": false},
		# Outpost Cottages near Base Approaches & Countryside
		{"pos": Vector3(-165.0, 2.1, 34.0), "size": Vector3(13, 7.0, 11), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(-135.0, 2.1, 34.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_yellow", "stairs": false},
		{"pos": Vector3(-115.0, 2.1, 78.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_yellow", "stairs": true},
		{"pos": Vector3(-155.0, 2.1, 78.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_cream", "stairs": false},
		{"pos": Vector3(145.0, 2.1, 34.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(172.0, 2.1, 34.0), "size": Vector3(13, 7.0, 11), "wall": "stucco_yellow", "stairs": false},
		{"pos": Vector3(165.0, 2.1, 78.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_yellow", "stairs": false},
		{"pos": Vector3(132.0, 2.1, 78.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_cream", "stairs": true},
		{"pos": Vector3(-55.0, 2.1, -35.0), "size": Vector3(13, 7, 11), "wall": "stucco_cream", "stairs": false},
		{"pos": Vector3(85.0, 2.1, -40.0), "size": Vector3(13, 7, 11), "wall": "stucco_yellow", "stairs": true},
		{"pos": Vector3(12.0, 2.1, 130.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_yellow", "stairs": false},
		{"pos": Vector3(-65.0, 2.1, 135.0), "size": Vector3(12, 6.5, 11), "wall": "stucco_cream", "stairs": false},
	]
	for i in range(house_spots.size()):
		var h: Dictionary = house_spots[i]
		_create_detailed_building("VillageHouse_%d" % i, h["pos"], h["size"], str(h["wall"]), "terracotta", bool(h["stairs"]))

	# 5. Harbor Ruins Fortress Walls (Flag D)
	_create_solid_box("RuinWallA", Vector3(20.0, 5.2, 2.4), Vector3(138.0, 10.0, -152.0), stucco_c)
	_create_solid_box("RuinWallB", Vector3(2.4, 5.2, 18.0), Vector3(160.0, 10.0, -135.0), stucco_c)
	_create_solid_box("RuinArch", Vector3(14.0, 2.2, 4.0), Vector3(145.0, 12.2, -116.0), stucco_y)


func _create_detailed_building(b_name: String, base_pos: Vector3, size: Vector3, wall_tex: String, roof_tex: String, add_stairs: bool) -> void:
	var wall_mat := CartoonAssets.make_standard_material(wall_tex, Color.WHITE, Vector2(2, 2))
	var roof_mat := CartoonAssets.make_standard_material(roof_tex, Color.WHITE, Vector2(3, 2))
	var trim_mat := CartoonAssets.make_standard_material("wood_crate", Color(0.45, 0.30, 0.18))

	_create_solid_box(b_name + "_Body", size, base_pos + Vector3(0.0, size.y * 0.5, 0.0), wall_mat)
	# Walkable pitched/stepped terracotta roof
	_create_solid_box(b_name + "_RoofLower", Vector3(size.x + 1.4, 0.9, size.z + 1.4), base_pos + Vector3(0.0, size.y + 0.45, 0.0), roof_mat)
	_create_solid_box(b_name + "_RoofUpper", Vector3(size.x * 0.72, 1.1, size.z * 0.72), base_pos + Vector3(0.0, size.y + 1.4, 0.0), roof_mat)

	# Dark cartoon windows & front door visuals
	for wx in [-size.x * 0.28, size.x * 0.28]:
		_create_solid_box(b_name + "_WinF_%d" % int(wx * 10), Vector3(1.8, 2.0, 0.3), base_pos + Vector3(wx, size.y * 0.62, size.z * 0.5 + 0.1), trim_mat)
		_create_solid_box(b_name + "_WinB_%d" % int(wx * 10), Vector3(1.8, 2.0, 0.3), base_pos + Vector3(wx, size.y * 0.62, -size.z * 0.5 - 0.1), trim_mat)
	_create_solid_box(b_name + "_Door", Vector3(2.1, 3.0, 0.3), base_pos + Vector3(0.0, 1.5, size.z * 0.5 + 0.1), trim_mat)

	if add_stairs:
		_create_solid_box(b_name + "_Balcony", Vector3(size.x + 1.6, 0.5, 3.2), base_pos + Vector3(0.0, size.y * 0.55, size.z * 0.5 + 1.6), trim_mat)
		_create_ramp(b_name + "_Stair", Vector3(2.8, 0.5, 10.5), base_pos + Vector3(size.x * 0.5 + 1.8, size.y * 0.45, 0.0), Vector3(-0.68, 0.0, 0.0), trim_mat)


func _build_trees_and_foliage() -> void:
	var bark_mat := CartoonAssets.make_standard_material("bark", Color.WHITE, Vector2(1, 2))
	var leaf_mat := CartoonAssets.make_standard_material("foliage", Color.WHITE, Vector2(2, 2))

	# 64 lush cartoon trees framing roads, hills, village yards, and beaches (never blocking runways!)
	var tree_positions: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2009
	for i in range(68):
		var tx: float = rng.randf_range(-330.0, 330.0)
		var tz: float = rng.randf_range(-205.0, 205.0)
		# Keep runways, roads, and spawn pads clear
		if absf(tz - 55.0) < 16.0 or absf(tx - 35.0) < 15.0:
			continue
		if absf(tx + 285.0) < 85.0 and absf(tz + 25.0) < 28.0:
			continue
		if absf(tx - 285.0) < 85.0 and absf(tz - 25.0) < 28.0:
			continue
		if tx < -200.0 and tz > 20.0 and tz < 110.0:
			continue
		if tx > 200.0 and tz < -20.0 and tz > -110.0:
			continue
		var ty: float = 2.1
		if tx < -60.0 and tx > -170.0 and tz < -70.0 and tz > -180.0:
			ty = 12.0
		elif tx > 90.0 and tx < 200.0 and tz < -80.0 and tz > -190.0:
			ty = 7.5
		elif tx < -90.0 and tx > -190.0 and tz > 100.0 and tz < 200.0:
			ty = 4.5
		tree_positions.append(Vector3(tx, ty, tz))

	# Hand-placed boulevard trees framing BOTH village approaches right along sidewalks (like Image 2!)
	for bx in [-178.0, -148.0, -108.0, -75.0, -20.0, 18.0, 52.0, 115.0, 152.0, 182.0]:
		tree_positions.append(Vector3(bx, 2.1, 41.5))
		tree_positions.append(Vector3(bx + 10.0, 2.1, 68.5))

	for idx in range(tree_positions.size()):
		_create_cartoon_tree("Tree_%d" % idx, tree_positions[idx], bark_mat, leaf_mat)


func _create_cartoon_tree(t_name: String, base_pos: Vector3, bark_mat: Material, leaf_mat: Material) -> void:
	var tree := StaticBody3D.new()
	tree.name = t_name
	tree.collision_layer = 1
	tree.position = base_pos

	var col := CollisionShape3D.new()
	var cyl_col := CylinderShape3D.new()
	cyl_col.radius = 0.65
	cyl_col.height = 6.0
	col.shape = cyl_col
	col.position = Vector3(0.0, 3.0, 0.0)
	tree.add_child(col)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.42
	tm.bottom_radius = 0.72
	tm.height = 6.5
	trunk.mesh = tm
	trunk.position = Vector3(0.0, 3.25, 0.0)
	trunk.material_override = bark_mat
	tree.add_child(trunk)

	for offset in [Vector3(0.0, 7.8, 0.0), Vector3(-1.8, 6.8, 0.9), Vector3(1.8, 6.9, -0.8), Vector3(0.4, 9.2, 0.3)]:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.2 if offset.y < 8.5 else 2.5
		sm.height = sm.radius * 1.65
		crown.mesh = sm
		crown.position = offset
		crown.material_override = leaf_mat
		tree.add_child(crown)

	add_child(tree)


func _build_destructible_props(combat_context: Dictionary) -> void:
	var prop_spots: Array[Dictionary] = [
		# Stacked wooden crate cover on cobblestone street near spawns & town square (just like Image 2!)
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-168.0, 2.15, 51.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-166.6, 2.15, 51.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-167.3, 3.45, 51.0), "rot": 0.08},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(168.0, 2.15, 59.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(166.6, 2.15, 59.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(167.3, 3.45, 59.0), "rot": -0.08},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(14.0, 2.15, 51.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(15.4, 2.15, 51.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(14.7, 3.45, 51.0), "rot": 0.1},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(54.0, 2.15, 58.0), "rot": 0.2},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(55.4, 2.15, 58.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(20.0, 2.15, 44.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(50.0, 2.15, 44.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(-25.0, 2.15, 66.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(82.0, 2.15, 66.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(32.0, 2.15, 54.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-130.0, 4.5, 145.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(140.0, 7.5, -130.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-108.0, 12.0, -120.0), "rot": 0.0},
	]
	for p in prop_spots:
		var prop := DestructibleProp.new()
		prop.setup(int(p["kind"]), p["pos"], float(p["rot"]), combat_context)
		add_child(prop)


func _build_capture_points(conquest: ConquestManager) -> void:
	var specs: Array[Dictionary] = [
		{"name": "Lighthouse Cove", "pos": Vector3(-140.0, 4.5, 150.0), "owner": NetworkManager.TEAM_ROYAL},
		{"name": "Windmill Hill", "pos": Vector3(-115.0, 12.0, -125.0), "owner": -1},
		{"name": "Town Square Church", "pos": Vector3(35.0, 2.15, 55.0), "owner": -1},
		{"name": "Harbor Ruins", "pos": Vector3(145.0, 7.5, -135.0), "owner": NetworkManager.TEAM_NATIONAL},
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
	# 12 Royal & 12 National spaced spawn pads RIGHT ON THE MAIN TOWN BOULEVARD (6m apart, Y=2.3)
	for i in range(12):
		var row: int = i / 3
		var col: int = i % 3
		royal_spawns.append(Vector3(-190.0 - float(row) * 5.5, 2.3, 49.0 + float(col) * 5.0))
		national_spawns.append(Vector3(190.0 + float(row) * 5.5, 2.3, 61.0 - float(col) * 5.0))


func _spawn_all_vehicles(vehicles_parent: Node3D) -> void:
	if vehicles_parent == null:
		return
	spawned_vehicles.clear()
	_next_vehicle_id = 1

	# Land Vehicles (Jeeps & Tanks)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-182.0, 3.0, 55.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-215.0, 3.0, 74.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_ROYAL, Vector3(-230.0, 3.2, 92.0), -PI * 0.5)

	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(182.0, 3.0, 55.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(215.0, 3.0, -74.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_NATIONAL, Vector3(230.0, 3.2, -92.0), PI * 0.5)

	# Air Vehicles (Fighter Planes on 140m clear Runways)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_ROYAL, Vector3(-315.0, 3.2, -25.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_NATIONAL, Vector3(315.0, 3.2, 25.0), PI * 0.5)

	# Water Vehicles (Aquatic Patrol Boats in ocean harbors!)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-225.0, 0.8, 290.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-275.0, 0.8, 290.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(225.0, 0.8, -290.0), 0.0)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(275.0, 0.8, -290.0), 0.0)

	# Fixed Anti-Aircraft Flak Guns
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_ROYAL, Vector3(-125.0, 4.5, 136.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_NATIONAL, Vector3(135.0, 7.5, -120.0), PI * 0.5)


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


func _add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = material
	parent.add_child(mi)
