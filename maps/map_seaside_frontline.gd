class_name MapSeasideFrontline
extends Node3D

## Large 800m x 800m Coastal Island Map ("Seaside Frontline") for 12v12 Land, Air & Water combat.
## Features 4 diamond/zig-zag Capture Points, 3-layer urban verticality, 110m runways, harbors,
## destructible props, AA guns, and Jeep/Tank/Plane/Boat spawners.

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
	_build_runways_and_harbors()
	_build_landmarks_and_village()
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
	mat.sky_top_color = Color(0.20, 0.58, 0.98)
	mat.sky_horizon_color = Color(0.64, 0.86, 0.99)
	mat.ground_bottom_color = Color(0.12, 0.44, 0.68)
	mat.ground_horizon_color = Color(0.64, 0.86, 0.99)
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_energy = 1.4
	sun.light_color = Color(1.0, 0.96, 0.86)
	sun.rotation_degrees = Vector3(-48.0, 36.0, 0.0)
	sun.shadow_enabled = not DisplayServer.get_name().contains("headless")
	add_child(sun)


func _build_ocean_and_terrain() -> void:
	# 840m x 840m Navigable Ocean Plane at Y = 0.0
	var ocean_mesh := MeshInstance3D.new()
	ocean_mesh.name = "Ocean"
	var plane := PlaneMesh.new()
	plane.size = Vector2(840.0, 840.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	ocean_mesh.mesh = plane
	var water_mat := ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	ocean_mesh.material_override = water_mat
	add_child(ocean_mesh)

	# Seafloor under ocean (so sunken objects/characters stop cleanly)
	_create_solid_box("Seafloor", Vector3(840.0, 2.0, 840.0), Vector3(0.0, -7.0, 0.0), Color(0.18, 0.34, 0.42))

	# Main Island Plateau (Emerald Green Grass + Sandy Beach Rim)
	_create_solid_box("BeachBase", Vector3(540.0, 2.4, 340.0), Vector3(0.0, 0.2, 0.0), Color(0.92, 0.83, 0.56))
	_create_solid_box("GrassMainland", Vector3(480.0, 2.6, 280.0), Vector3(0.0, 0.8, 0.0), Color(0.22, 0.68, 0.28))

	# Elevated Hill for Windmill (North-West, Flag B) + gentle ramps
	_create_solid_box("WindmillPlateau", Vector3(85.0, 10.0, 85.0), Vector3(-85.0, 7.0, -95.0), Color(0.25, 0.72, 0.30))
	_create_ramp("WindmillRampS", Vector3(18.0, 2.0, 48.0), Vector3(-85.0, 6.2, -36.0), Vector3(0.22, 0.0, 0.0), Color(0.68, 0.60, 0.44))
	_create_ramp("WindmillRampW", Vector3(48.0, 2.0, 18.0), Vector3(-144.0, 6.2, -95.0), Vector3(0.0, 0.0, 0.22), Color(0.68, 0.60, 0.44))

	# Elevated Ruin Cliff (North-East, Flag D) + ramp
	_create_solid_box("RuinsCliff", Vector3(80.0, 6.0, 80.0), Vector3(115.0, 4.5, -105.0), Color(0.46, 0.52, 0.38))
	_create_ramp("RuinsRamp", Vector3(20.0, 2.0, 36.0), Vector3(115.0, 4.2, -52.0), Vector3(0.16, 0.0, 0.0), Color(0.66, 0.58, 0.42))

	# Coastal Cliff for Lighthouse (South-West, Flag A) + ramp
	_create_solid_box("LighthouseCliff", Vector3(72.0, 3.5, 68.0), Vector3(-105.0, 2.6, 115.0), Color(0.76, 0.72, 0.52))
	_create_ramp("LighthouseRamp", Vector3(18.0, 2.0, 26.0), Vector3(-105.0, 2.8, 72.0), Vector3(-0.14, 0.0, 0.0), Color(0.66, 0.58, 0.42))


func _build_runways_and_harbors() -> void:
	# Royal Main Base Airfield (West, 120m clear obstacle-free runway)
	_create_solid_box("RoyalRunway", Vector3(120.0, 1.0, 22.0), Vector3(-235.0, 1.9, 10.0), Color(0.32, 0.34, 0.36))
	# Royal Harbor Pier extending into navigable ocean (South-West)
	_create_solid_box("RoyalPier", Vector3(34.0, 1.8, 48.0), Vector3(-210.0, 1.2, 182.0), Color(0.56, 0.40, 0.24))

	# National Main Base Airfield (East, 120m clear obstacle-free runway)
	_create_solid_box("NationalRunway", Vector3(120.0, 1.0, 22.0), Vector3(235.0, 1.9, -10.0), Color(0.32, 0.34, 0.36))
	# National Harbor Pier extending into navigable ocean (North-East)
	_create_solid_box("NationalPier", Vector3(34.0, 1.8, 48.0), Vector3(210.0, 1.2, -182.0), Color(0.56, 0.40, 0.24))


func _build_landmarks_and_village() -> void:
	# 1. Lighthouse Tower (Flag A)
	_create_solid_box("LighthouseBase", Vector3(8.0, 14.0, 8.0), Vector3(-120.0, 11.0, 126.0), Color(0.95, 0.95, 0.95))
	_create_solid_box("LighthouseStripe", Vector3(8.2, 4.0, 8.2), Vector3(-120.0, 12.5, 126.0), Color(0.86, 0.18, 0.16))
	_create_solid_box("LighthouseLamp", Vector3(6.0, 3.0, 6.0), Vector3(-120.0, 19.5, 126.0), Color(1.0, 0.92, 0.4))

	# 2. Windmill Landmark (Flag B)
	_create_solid_box("WindmillTower", Vector3(8.0, 15.0, 8.0), Vector3(-98.0, 19.5, -108.0), Color(0.92, 0.86, 0.72))
	_create_solid_box("WindmillRoof", Vector3(9.0, 3.0, 9.0), Vector3(-98.0, 28.0, -108.0), Color(0.76, 0.32, 0.20))
	_windmill_blades = Node3D.new()
	_windmill_blades.position = Vector3(-98.0, 24.5, -103.5)
	add_child(_windmill_blades)
	_add_visual_box(_windmill_blades, Vector3(1.2, 16.0, 0.3), Vector3.ZERO, Color(0.62, 0.42, 0.22))
	_add_visual_box(_windmill_blades, Vector3(16.0, 1.2, 0.3), Vector3.ZERO, Color(0.62, 0.42, 0.22))

	# 3. Town Square Church & Multi-Layer Urban Village (Flag C: Street -> Balconies -> Rooftops)
	_create_solid_box("ChurchBody", Vector3(14.0, 9.5, 22.0), Vector3(35.0, 6.8, 28.0), Color(0.94, 0.90, 0.80))
	_create_solid_box("ChurchRoof", Vector3(15.2, 2.2, 23.2), Vector3(35.0, 12.6, 28.0), Color(0.78, 0.34, 0.22))
	_create_solid_box("ChurchBellTower", Vector3(6.5, 18.0, 6.5), Vector3(35.0, 11.0, 19.0), Color(0.92, 0.88, 0.78))
	_create_solid_box("ChurchSpire", Vector3(5.0, 4.5, 5.0), Vector3(35.0, 22.2, 19.0), Color(0.78, 0.34, 0.22))

	# Flanking Town Houses with Balconies & Rooftop Ramps (3-Layer Verticality!)
	var house_positions: Array[Vector3] = [
		Vector3(12.0, 5.5, 52.0),
		Vector3(58.0, 5.5, 52.0),
		Vector3(10.0, 5.5, 24.0),
		Vector3(60.0, 5.5, 24.0),
	]
	for idx in range(house_positions.size()):
		var hp: Vector3 = house_positions[idx]
		_create_solid_box("House_%d" % idx, Vector3(12.0, 7.0, 12.0), hp, Color(0.92, 0.85, 0.72))
		# Terracotta walkable rooftop
		_create_solid_box("HouseRoof_%d" % idx, Vector3(13.0, 0.8, 13.0), hp + Vector3(0.0, 3.9, 0.0), Color(0.80, 0.36, 0.24))
		# 2nd-floor Balcony
		_create_solid_box("HouseBalcony_%d" % idx, Vector3(14.5, 0.5, 4.0), hp + Vector3(0.0, 1.2, 7.2), Color(0.58, 0.42, 0.26))
		# External Stairs/Ramp up to Balcony & Rooftop
		_create_ramp("HouseStair_%d" % idx, Vector3(3.2, 0.6, 11.0), hp + Vector3(7.6, 0.2, 0.0), Vector3(-0.62, 0.0, 0.0), Color(0.56, 0.40, 0.24))

	# 4. Harbor Ruins Walls (Flag D)
	_create_solid_box("RuinWallA", Vector3(18.0, 4.8, 2.2), Vector3(108.0, 9.8, -118.0), Color(0.62, 0.60, 0.54))
	_create_solid_box("RuinWallB", Vector3(2.2, 4.8, 16.0), Vector3(128.0, 9.8, -104.0), Color(0.62, 0.60, 0.54))
	_create_solid_box("RuinArch", Vector3(12.0, 2.0, 4.0), Vector3(115.0, 12.0, -90.0), Color(0.58, 0.56, 0.50))


func _build_destructible_props(combat_context: Dictionary) -> void:
	var prop_spots: Array[Dictionary] = [
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(24.0, 2.1, 40.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(46.0, 2.1, 40.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(20.0, 2.1, 60.0), "rot": 1.57},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(30.0, 2.1, 36.0), "rot": 0.3},
		{"kind": DestructibleProp.PropKind.CRATE, "pos": Vector3(-88.0, 12.0, -86.0), "rot": 0.2},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(38.0, 2.1, 44.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-98.0, 4.4, 110.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(112.0, 7.5, -98.0), "rot": 0.0},
		{"kind": DestructibleProp.PropKind.RED_BARREL, "pos": Vector3(-78.0, 12.0, -92.0), "rot": 0.0},
	]
	for p in prop_spots:
		var prop := DestructibleProp.new()
		prop.setup(int(p["kind"]), p["pos"], float(p["rot"]), combat_context)
		add_child(prop)


func _build_capture_points(conquest: ConquestManager) -> void:
	var specs: Array[Dictionary] = [
		{"name": "Lighthouse Cove", "pos": Vector3(-105.0, 4.4, 115.0), "owner": NetworkManager.TEAM_ROYAL},
		{"name": "Windmill Hill", "pos": Vector3(-85.0, 12.0, -95.0), "owner": -1},
		{"name": "Town Square Church", "pos": Vector3(35.0, 2.1, 45.0), "owner": -1},
		{"name": "Harbor Ruins", "pos": Vector3(115.0, 7.5, -105.0), "owner": NetworkManager.TEAM_NATIONAL},
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
	# 12 Royal & 12 National initial spawns (for 12v12!)
	for i in range(12):
		var row: int = i / 4
		var col: int = i % 4
		royal_spawns.append(Vector3(-235.0 - float(row) * 4.5, 3.0, 40.0 + float(col) * 4.5))
		national_spawns.append(Vector3(235.0 + float(row) * 4.5, 3.0, -40.0 - float(col) * 4.5))


func _spawn_all_vehicles(vehicles_parent: Node3D) -> void:
	if vehicles_parent == null:
		return
	spawned_vehicles.clear()
	_next_vehicle_id = 1

	# Land Vehicles (Jeeps & Tanks)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-200.0, 3.2, 35.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_ROYAL, Vector3(-195.0, 3.2, 55.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_ROYAL, Vector3(-210.0, 3.4, 72.0), -PI * 0.5)

	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(200.0, 3.2, -35.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleJeep.new(), NetworkManager.TEAM_NATIONAL, Vector3(195.0, 3.2, -55.0), PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehicleTank.new(), NetworkManager.TEAM_NATIONAL, Vector3(210.0, 3.4, -72.0), PI * 0.5)

	# Air Vehicles (Fighter Planes on 120m clear Runways)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_ROYAL, Vector3(-265.0, 3.4, 10.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, VehiclePlane.new(), NetworkManager.TEAM_NATIONAL, Vector3(265.0, 3.4, -10.0), PI * 0.5)

	# Water Vehicles (Aquatic Patrol / Landing Boats in ocean harbors!)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-185.0, 0.8, 200.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(-235.0, 0.8, 200.0), PI)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(185.0, 0.8, -200.0), 0.0)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(235.0, 0.8, -200.0), 0.0)

	# Fixed Anti-Aircraft Flak Guns
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_ROYAL, Vector3(-95.0, 4.4, 102.0), -PI * 0.5)
	_spawn_vehicle(vehicles_parent, AAGun.new(), NetworkManager.TEAM_NATIONAL, Vector3(105.0, 7.5, -92.0), PI * 0.5)


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
	return Vector3(0.0, 5.0, 0.0)


func _create_solid_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mi.material_override = mat
	body.add_child(mi)

	add_child(body)
	return body


func _create_ramp(node_name: String, size: Vector3, pos: Vector3, rot: Vector3, color: Color) -> StaticBody3D:
	var body := _create_solid_box(node_name, size, pos, color)
	body.rotation = rot
	return body


func _add_visual_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
