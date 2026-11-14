class_name MapSeasideFrontline
extends Node3D

## Large 2x Scale Coastal Island Map ("Seaside Frontline") for 12v12 Land, Air & Water combat.
## Features 2400m x 2400m Ocean, 1600m x 1080m Coastal Island, sculpted Mediterranean architecture
## via BuildingMeshBuilder (Town Square CentralFountain, Mercadinho, ChurchChapel, Windmill,
## CoastalLighthouse + Keeper's Cottage, 34 sculpted houses, 6 climbable Watchtowers, 220m Spawn
## Airstrips with Hangars & ATC towers, 3 Harbor Piers w/ 6 ocean Boats, and 150+ layered trees).

const WATER_SHADER: Shader = preload("res://vfx_shaders/water_toon.gdshader")
const TOON_SKY_SHADER: Shader = preload("res://vfx_shaders/toon_sky.gdshader")

var royal_spawns: Array[Vector3] = []
var national_spawns: Array[Vector3] = []
var capture_points: Array[CapturePoint] = []
var spawned_vehicles: Array[VehicleBase] = []
var _windmill_blades: Node3D
var _next_vehicle_id: int = 1


static func get_river_center_x(z: float) -> float:
	return 158.0 + sin(z * 0.007) * 26.0


static func get_terrain_height(x: float, z: float) -> float:
	var h: float = 2.15

	# 1. Outer beach shore slope down to beach plateau (1.00m) and ocean bed (-3.8m)
	var edge_dx: float = maxf(0.0, absf(x) - 710.0)
	var edge_dz: float = maxf(0.0, absf(z) - 450.0)
	var edge_dist: float = sqrt(edge_dx * edge_dx + edge_dz * edge_dz)
	var land_factor: float = 1.0
	if edge_dist > 0.0:
		if edge_dist <= 35.0:
			var t: float = edge_dist / 35.0
			h = lerpf(2.15, 1.00, t)
			land_factor = 1.0 - t
		elif edge_dist <= 80.0:
			var t: float = (edge_dist - 35.0) / 45.0
			h = lerpf(1.00, -3.80, t)
			land_factor = 0.0
		else:
			h = -3.80
			land_factor = 0.0

	# 2. Smooth rolling BFH hills/colinas (elevation gains +4.0m to +13.5m)
	var hill_gain: float = 0.0
	var hills: Array[Dictionary] = [
		{"cx": -15.0, "cz": -270.0, "rx": 110.0, "rz": 70.0, "h": 9.35},
		{"cx": -190.0, "cz": 240.0, "rx": 100.0, "rz": 85.0, "h": 6.85},
		{"cx": 450.0, "cz": -250.0, "rx": 120.0, "rz": 95.0, "h": 9.85},
		{"cx": 355.0, "cz": 255.0, "rx": 95.0, "rz": 85.0, "h": 5.85, "flat": 0.40},
		{"cx": 460.0, "cz": 290.0, "rx": 80.0, "rz": 70.0, "h": 10.85},
		{"cx": -500.0, "cz": -300.0, "rx": 95.0, "rz": 80.0, "h": 8.35},
		{"cx": -55.0, "cz": 275.0, "rx": 65.0, "rz": 55.0, "h": 5.35},
	]
	for hl in hills:
		var ddx: float = (x - float(hl["cx"])) / float(hl["rx"])
		var ddz: float = (z - float(hl["cz"])) / float(hl["rz"])
		var d2: float = ddx * ddx + ddz * ddz
		if d2 < 1.0:
			var r: float = sqrt(d2)
			var w: float = 0.0
			if hl.has("flat"):
				var ft: float = float(hl["flat"])
				if r <= ft:
					w = 1.0
				else:
					w = 0.5 * (1.0 + cos(((r - ft) / (1.0 - ft)) * PI))
			else:
				w = 0.5 * (1.0 + cos(r * PI))
			hill_gain += float(hl["h"]) * w

	# 3. Flat corridor masks (zero hill offset on critical gameplay corridors, base Y = 2.15)
	var flat_boxes: Array[PackedFloat32Array] = [
		PackedFloat32Array([-85.0, 85.0, -55.0, 115.0]),
		PackedFloat32Array([-46.0, 46.0, -210.0, 460.0]),
		PackedFloat32Array([-640.0, 640.0, 16.0, 64.0]),
		PackedFloat32Array([-300.0, 118.0, 4.0, 78.0]),
		PackedFloat32Array([204.0, 300.0, 4.0, 78.0]),
		PackedFloat32Array([-630.0, -340.0, -155.0, -35.0]),
		PackedFloat32Array([-515.0, -405.0, -55.0, 75.0]),
		PackedFloat32Array([340.0, 630.0, 45.0, 165.0]),
		PackedFloat32Array([405.0, 515.0, -45.0, 85.0]),
		PackedFloat32Array([-320.0, -140.0, -330.0, -150.0]),
		PackedFloat32Array([190.0, 370.0, -330.0, -150.0]),
		PackedFloat32Array([-540.0, -400.0, 245.0, 385.0]),
		PackedFloat32Array([-450.0, 450.0, 415.0, 475.0]),
	]
	var corridor_factor: float = 1.0
	var margin: float = 14.0
	for b in flat_boxes:
		var b_dx: float = maxf(maxf(b[0] - x, x - b[1]), 0.0)
		var b_dz: float = maxf(maxf(b[2] - z, z - b[3]), 0.0)
		var b_dist: float = sqrt(b_dx * b_dx + b_dz * b_dz)
		if b_dist <= 0.0:
			corridor_factor = 0.0
			break
		elif b_dist < margin:
			var t_box: float = b_dist / margin
			corridor_factor = minf(corridor_factor, t_box * t_box * (3.0 - 2.0 * t_box))

	h += hill_gain * corridor_factor * land_factor

	# 4. Continuous Central River Carving across all Z from -540 to +540
	var rx: float = get_river_center_x(z)
	var dist_r: float = absf(x - rx)
	if dist_r <= 15.5:
		h = minf(h, -3.80)
	elif dist_r < 30.0:
		var t_r: float = (dist_r - 15.5) / 14.5
		var s_r: float = t_r * t_r * (3.0 - 2.0 * t_r)
		h = lerpf(-3.80, h, s_r)

	return h


func build_map(conquest: ConquestManager, vehicles_parent: Node3D, combat_context: Dictionary) -> void:
	_build_sky_and_lighting()
	_build_ocean_and_terrain()
	_build_roads_and_sidewalks()
	_build_runways_and_harbors()
	_build_landmarks_and_village()
	_build_watchtowers()
	_build_hillside_boulders()
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
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = TOON_SKY_SHADER
	sky.sky_material = sky_mat
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

	# Underwater foundation slab (1600m x 1080m) tucked beneath island base
	_create_solid_box("BeachBase", Vector3(1600.0, 1.0, 1080.0), Vector3(0.0, -4.5, 0.0), CartoonAssets.make_standard_material("sand", Color.WHITE, Vector2(64, 44)))

	# Continuous Sculpted Heightfield Terrain (1600m x 1080m grid with rolling hills, valleys & carved river)
	var nx: int = 134
	var nz: int = 90
	var dx: float = 1600.0 / float(nx)
	var dz: float = 1080.0 / float(nz)
	var grid_pts: Array[Vector3] = []
	var grid_cols: Array[Color] = []
	var grid_uvs: Array[Vector2] = []
	grid_pts.resize((nx + 1) * (nz + 1))
	grid_cols.resize((nx + 1) * (nz + 1))
	grid_uvs.resize((nx + 1) * (nz + 1))

	for j in range(nz + 1):
		var gz: float = -540.0 + float(j) * dz
		for i in range(nx + 1):
			var gx: float = -800.0 + float(i) * dx
			var gy: float = get_terrain_height(gx, gz)
			var g_idx: int = j * (nx + 1) + i
			grid_pts[g_idx] = Vector3(gx, gy, gz)
			grid_uvs[g_idx] = Vector2((gx + 800.0) * 0.075, (gz + 540.0) * 0.075)

			var c: Color
			if gy < 0.35:
				c = Color(0.72, 0.65, 0.52)
			elif gy < 1.85:
				var t_sand: float = (gy - 0.35) / 1.50
				c = Color(0.72, 0.65, 0.52).lerp(Color(0.92, 0.86, 0.68), t_sand)
			elif gy < 5.5:
				var t_grass: float = (gy - 1.85) / 3.65
				c = Color(0.92, 0.86, 0.68).lerp(Color(0.92, 0.98, 0.88), t_grass)
			else:
				var t_hill: float = clampf((gy - 5.5) / 7.0, 0.0, 1.0)
				c = Color(0.92, 0.98, 0.88).lerp(Color(1.04, 1.02, 0.88), t_hill)
			grid_cols[g_idx] = c

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_faces := PackedVector3Array()
	top_faces.resize(nx * nz * 6)
	var tf_idx: int = 0

	# 1. Upper terrain surface (outward CW from above)
	for j in range(nz):
		for i in range(nx):
			var i00: int = j * (nx + 1) + i
			var i10: int = j * (nx + 1) + (i + 1)
			var i11: int = (j + 1) * (nx + 1) + (i + 1)
			var i01: int = (j + 1) * (nx + 1) + i

			var p00: Vector3 = grid_pts[i00]
			var p10: Vector3 = grid_pts[i10]
			var p11: Vector3 = grid_pts[i11]
			var p01: Vector3 = grid_pts[i01]

			var c00: Color = grid_cols[i00]
			var c10: Color = grid_cols[i10]
			var c11: Color = grid_cols[i11]
			var c01: Color = grid_cols[i01]

			var u00: Vector2 = grid_uvs[i00]
			var u10: Vector2 = grid_uvs[i10]
			var u11: Vector2 = grid_uvs[i11]
			var u01: Vector2 = grid_uvs[i01]

			st.set_color(c00); st.set_uv(u00); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(u10); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(u11); st.add_vertex(p11)
			top_faces[tf_idx] = p00; top_faces[tf_idx + 1] = p10; top_faces[tf_idx + 2] = p11
			tf_idx += 3

			st.set_color(c00); st.set_uv(u00); st.add_vertex(p00)
			st.set_color(c11); st.set_uv(u11); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(u01); st.add_vertex(p01)
			top_faces[tf_idx] = p00; top_faces[tf_idx + 1] = p11; top_faces[tf_idx + 2] = p01
			tf_idx += 3

	# 2. Watertight bottom plate at Y = -8.0 (outward CW from below)
	var bot_col := Color(0.28, 0.28, 0.28)
	var bot_y: float = -8.0
	for j in range(nz):
		for i in range(nx):
			var p00: Vector3 = grid_pts[j * (nx + 1) + i]
			var p10: Vector3 = grid_pts[j * (nx + 1) + (i + 1)]
			var p11: Vector3 = grid_pts[(j + 1) * (nx + 1) + (i + 1)]
			var p01: Vector3 = grid_pts[(j + 1) * (nx + 1) + i]

			var b00 := Vector3(p00.x, bot_y, p00.z)
			var b10 := Vector3(p10.x, bot_y, p10.z)
			var b11 := Vector3(p11.x, bot_y, p11.z)
			var b01 := Vector3(p01.x, bot_y, p01.z)

			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b00)
			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b01)
			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b11)

			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b00)
			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b11)
			st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b10)

	# 3. 4 Perimeter Skirts connecting boundary down to Y = -8.0
	# North skirt (j = 0, z = -540.0)
	for i in range(nx):
		var t0: Vector3 = grid_pts[i]
		var t1: Vector3 = grid_pts[i + 1]
		var b0 := Vector3(t0.x, bot_y, t0.z)
		var b1 := Vector3(t1.x, bot_y, t1.z)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)

		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)

	# South skirt (j = nz, z = +540.0)
	for i in range(nx):
		var t0: Vector3 = grid_pts[nz * (nx + 1) + i]
		var t1: Vector3 = grid_pts[nz * (nx + 1) + (i + 1)]
		var b0 := Vector3(t0.x, bot_y, t0.z)
		var b1 := Vector3(t1.x, bot_y, t1.z)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)

		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)

	# West skirt (i = 0, x = -800.0)
	for j in range(nz):
		var t0: Vector3 = grid_pts[j * (nx + 1)]
		var t1: Vector3 = grid_pts[(j + 1) * (nx + 1)]
		var b0 := Vector3(t0.x, bot_y, t0.z)
		var b1 := Vector3(t1.x, bot_y, t1.z)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)

		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)

	# East skirt (i = nx, x = +800.0)
	for j in range(nz):
		var t0: Vector3 = grid_pts[j * (nx + 1) + nx]
		var t1: Vector3 = grid_pts[(j + 1) * (nx + 1) + nx]
		var b0 := Vector3(t0.x, bot_y, t0.z)
		var b1 := Vector3(t1.x, bot_y, t1.z)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)

		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(t1)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b0)
		st.set_color(bot_col); st.set_uv(Vector2.ZERO); st.add_vertex(b1)

	st.generate_normals()
	var terrain_mesh: ArrayMesh = st.commit()

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "SculptedTerrain"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0

	var terrain_col := CollisionShape3D.new()
	terrain_col.name = "CollisionShape3D"
	var concave_shape := ConcavePolygonShape3D.new()
	concave_shape.set_faces(top_faces)
	terrain_col.shape = concave_shape
	terrain_body.add_child(terrain_col)

	var terrain_mi := MeshInstance3D.new()
	terrain_mi.name = "TerrainMesh"
	terrain_mi.mesh = terrain_mesh
	var terrain_mat: StandardMaterial3D = CartoonAssets.make_standard_material("grass", Color.WHITE, Vector2(120, 90))
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	terrain_mi.material_override = terrain_mat
	terrain_body.add_child(terrain_mi)

	add_child(terrain_body)

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

	# Main East-West Cobblestone Boulevard split around central river channel
	# West section: X in [-640, 122], East section: X in [208, 640]
	_create_solid_box("MainRoadEW", Vector3(762.0, 0.24, 16.0), Vector3(-259.0, 2.155, 40.0), cobble_ew)
	_create_solid_box("MainRoadEW_E", Vector3(432.0, 0.24, 16.0), Vector3(424.0, 2.155, 40.0), cobble_ew)
	_create_solid_box("SidewalkNorthW", Vector3(587.0, 0.34, 2.8), Vector3(-346.5, 2.19, 30.6), sw_ew)
	_create_solid_box("SidewalkNorthE_Mid", Vector3(69.0, 0.34, 2.8), Vector3(87.5, 2.19, 30.6), sw_ew)
	_create_solid_box("SidewalkNorthE", Vector3(432.0, 0.34, 2.8), Vector3(424.0, 2.19, 30.6), sw_ew)
	_create_solid_box("SidewalkSouthW", Vector3(587.0, 0.34, 2.8), Vector3(-346.5, 2.19, 49.4), sw_ew)
	_create_solid_box("SidewalkSouthE_Mid", Vector3(69.0, 0.34, 2.8), Vector3(87.5, 2.19, 49.4), sw_ew)
	_create_solid_box("SidewalkSouthE", Vector3(432.0, 0.34, 2.8), Vector3(424.0, 2.19, 49.4), sw_ew)

	# Cross Town North-South Avenue (reaches South Harbor Coastal Loop at Z = 460)
	_create_solid_box("CrossRoadNS", Vector3(15.0, 0.24, 820.0), Vector3(0.0, 2.14, 50.0), cobble_ns)
	_create_solid_box("CrossWalkW", Vector3(2.8, 0.32, 353.0), Vector3(-8.9, 2.17, -183.5), sw_ns)
	_create_solid_box("CrossWalkE", Vector3(2.8, 0.32, 353.0), Vector3(8.9, 2.17, -183.5), sw_ns)

	# Central Town Square Cobblestone Plaza Apron (top Y = 2.295m cleanly above roads)
	_create_solid_box("TownSquarePlaza", Vector3(106.0, 0.26, 94.0), Vector3(0.0, 2.165, 40.0), cobble_plaza)

	# South Harbor Coastal Link Road split around central river channel
	# West section: X in [-420, 122], East section: X in [202, 420]
	var cobble_sc := CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(36, 2))
	_create_solid_box("SouthCoastalRoad", Vector3(542.0, 0.22, 13.0), Vector3(-149.0, 2.14, 444.0), cobble_sc)
	_create_solid_box("SouthCoastalRoad_E", Vector3(218.0, 0.22, 13.0), Vector3(311.0, 2.14, 444.0), cobble_sc)
	_create_solid_box("WestCoveRoad", Vector3(13.0, 0.22, 412.0), Vector3(-345.0, 2.14, 246.0), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(2, 22)))

	# Main & South Arched River Bridges spanning central river with >=4.6m headroom clearance
	var rx_main: float = get_river_center_x(40.0)
	BuildingMeshBuilder.build_river_bridge(self, Vector3(rx_main, 0.0, 40.0), 0.0, 64.0, 18.0, 5.4, "MainRiverBridge")

	var rx_south: float = get_river_center_x(444.0)
	BuildingMeshBuilder.build_river_bridge(self, Vector3(rx_south, 0.0, 444.0), 0.0, 64.0, 15.0, 5.4, "SouthRiverBridge")

	_build_streetlamps_and_bunting()


func _build_streetlamps_and_bunting() -> void:
	var pole_mat := BuildingMeshBuilder.make_mat(Color(0.20, 0.22, 0.25), "", 0.50, 0.45)
	var wood_mat := CartoonAssets.make_standard_material("bark")
	var bulb_mat := BuildingMeshBuilder.make_mat(Color(1.0, 0.92, 0.58), "", 0.18, 0.0)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.86, 0.40)
	bulb_mat.emission_energy_multiplier = 2.0

	# Boulevard Utility Poles & Town Square Streetlamps (skip central open plaza [-54, +54] and river channel)
	for x in range(-360, 380, 65):
		var px_n: float = float(x)
		var px_s: float = float(x) + 32.0
		if absf(px_n - get_river_center_x(29.2)) < 36.0 or absf(px_s - get_river_center_x(50.8)) < 36.0:
			continue
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

	# Festive Battlefield Heroes Triangle Pennant Bunting across Town Square Plaza (grounded posts at both ends)
	var pennant_mats: Array[Material] = [
		BuildingMeshBuilder.make_mat(Color(0.88, 0.18, 0.16)),
		BuildingMeshBuilder.make_mat(Color(0.96, 0.80, 0.18)),
		BuildingMeshBuilder.make_mat(Color(0.16, 0.48, 0.92)),
		BuildingMeshBuilder.make_mat(Color(0.24, 0.72, 0.30)),
	]
	var finial_mat := BuildingMeshBuilder.make_mat(Color(0.86, 0.68, 0.22), "", 0.35, 0.75)
	for bx in [-36.0, -14.0, 14.0, 36.0]:
		for end_tag in [{"z": 29.0, "suffix": "N"}, {"z": 51.0, "suffix": "S"}]:
			var pz_post: float = float(end_tag["z"])
			_create_solid_box("BuntingPost_%d_%s" % [int(bx), str(end_tag["suffix"])], Vector3(0.28, 7.1, 0.28), Vector3(bx, 2.295 + 3.55, pz_post), pole_mat)
			_create_solid_box("BuntingBase_%d_%s" % [int(bx), str(end_tag["suffix"])], Vector3(0.56, 0.36, 0.56), Vector3(bx, 2.295 + 0.18, pz_post), pole_mat)
			var finial := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.20
			fm.height = 0.40
			finial.mesh = fm
			finial.position = Vector3(bx, 9.48, pz_post)
			finial.material_override = finial_mat
			add_child(finial)
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
	# 1. Town Square Centerpiece: Sculpted Multi-Tier Fountain + Bustling Mercadinho + Church Chapel on flush plaza/parvis
	BuildingMeshBuilder.build_central_fountain(self, Vector3(0.0, 2.295, 40.0))
	BuildingMeshBuilder.build_mercadinho_complex(self, Vector3(28.0, 2.295, 66.0))
	_create_solid_box("ChurchParvis", Vector3(18.0, 0.18, 23.0), Vector3(28.0, 2.205, -18.5), CartoonAssets.make_standard_material("cobble", Color.WHITE, Vector2(4, 5)))
	BuildingMeshBuilder.build_church_chapel(self, Vector3(28.0, 2.295, -16.0), 0.0)

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
		# East Boulevard North & South (clear of central river corridor X in [130, 200])
		{"pos": Vector3(98.0, 2.15, 16.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(224.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(264.0, 2.15, 16.0), "yaw": 0.0, "style": 1},
		{"pos": Vector3(304.0, 2.15, 16.0), "yaw": 0.0, "style": 2},
		{"pos": Vector3(344.0, 2.15, 16.0), "yaw": 0.0, "style": 0},
		{"pos": Vector3(98.0, 2.15, 66.0), "yaw": PI, "style": 0},
		{"pos": Vector3(224.0, 2.15, 66.0), "yaw": PI, "style": 1},
		{"pos": Vector3(264.0, 2.15, 66.0), "yaw": PI, "style": 2},
		{"pos": Vector3(304.0, 2.15, 66.0), "yaw": PI, "style": 0},
		{"pos": Vector3(344.0, 2.15, 66.0), "yaw": PI, "style": 1},
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
	_create_solid_box("RuinArchBaseL", Vector3(4.2, 0.75, 4.2), Vector3(270.0, 7.65 + 0.375, -206.0), trim_stone)
	_create_solid_box("RuinArchBaseR", Vector3(4.2, 0.75, 4.2), Vector3(290.0, 7.65 + 0.375, -206.0), trim_stone)
	_create_solid_box("RuinArchPillarL", Vector3(3.4, 4.9, 3.4), Vector3(270.0, 7.65 + 2.45, -206.0), masonry)
	_create_solid_box("RuinArchPillarR", Vector3(3.4, 4.9, 3.4), Vector3(290.0, 7.65 + 2.45, -206.0), masonry)
	_create_solid_box("RuinArchCapL", Vector3(4.0, 0.55, 4.0), Vector3(270.0, 7.65 + 4.65, -206.0), trim_stone)
	_create_solid_box("RuinArchCapR", Vector3(4.0, 0.55, 4.0), Vector3(290.0, 7.65 + 4.65, -206.0), trim_stone)
	_create_solid_box("RuinArchLintel", Vector3(24.0, 2.0, 3.6), Vector3(280.0, 7.65 + 5.8, -206.0), trim_stone)

	# 6. Rural Farmstead (Fazenda) on South-East Scenic Hill/Terrace
	var fazenda_y: float = get_terrain_height(365.0, 255.0)
	BuildingMeshBuilder.build_farm_complex(self, Vector3(365.0, fazenda_y, 255.0), 0.0, "Fazenda")

	# 7. Rural North Orchard Barn Outpost in Northwest Countryside
	var barn_y: float = get_terrain_height(-410.0, -280.0)
	BuildingMeshBuilder.build_farm_complex(self, Vector3(-410.0, barn_y, -280.0), 0.45, "NorthOrchardBarn")

	# 8. 2 River Docks with Mooring Jetty and Bank Stairs
	var rz_town: float = -40.0
	var rx_town: float = get_river_center_x(rz_town)
	BuildingMeshBuilder.build_river_dock(self, Vector3(rx_town - 21.0, 0.0, rz_town), -PI * 0.5, "RiverTownDock")

	var rz_north: float = -260.0
	var rx_north: float = get_river_center_x(rz_north)
	BuildingMeshBuilder.build_river_dock(self, Vector3(rx_north - 21.0, 0.0, rz_north), -PI * 0.5, "RiverNorthDock")


func _build_watchtowers() -> void:
	var specs: Array[Dictionary] = [
		{"name": "Watchtower_1", "pos": Vector3(-155.0, 2.15, 102.0), "yaw": 0.0},
		{"name": "Watchtower_2", "pos": Vector3(105.0, 2.15, -12.0), "yaw": PI},
		{"name": "Watchtower_3", "pos": Vector3(-24.0, 2.15, 412.0), "yaw": 0.0},
		{"name": "Watchtower_4", "pos": Vector3(-125.0, 2.15, -290.0), "yaw": -PI * 0.5},
		{"name": "Watchtower_5", "pos": Vector3(-365.0, 2.15, -18.0), "yaw": PI * 0.5},
		{"name": "Watchtower_6", "pos": Vector3(365.0, 2.15, 24.0), "yaw": -PI * 0.5},
	]
	for w in specs:
		var p: Vector3 = w["pos"]
		p.y = get_terrain_height(p.x, p.z)
		BuildingMeshBuilder.build_watchtower(self, p, float(w["yaw"]), str(w["name"]))


func _build_hillside_boulders() -> void:
	var rock_mat: StandardMaterial3D = BuildingMeshBuilder.make_mat(Color(0.78, 0.74, 0.68), "stone_masonry", 0.90, 0.02, 1.0, Vector2(1.5, 1.5))
	var boulder_spots: Array[Vector3] = [
		Vector3(-25.0, 0.0, -285.0),
		Vector3(12.0, 0.0, -260.0),
		Vector3(-45.0, 0.0, -250.0),
		Vector3(-180.0, 0.0, 225.0),
		Vector3(-205.0, 0.0, 255.0),
		Vector3(435.0, 0.0, -235.0),
		Vector3(468.0, 0.0, -265.0),
		Vector3(420.0, 0.0, -270.0),
		Vector3(445.0, 0.0, 275.0),
		Vector3(475.0, 0.0, 305.0),
		Vector3(-485.0, 0.0, -285.0),
		Vector3(-515.0, 0.0, -315.0),
		Vector3(-60.0, 0.0, 280.0),
	]
	for idx in range(boulder_spots.size()):
		var b_pos: Vector3 = boulder_spots[idx]
		b_pos.y = get_terrain_height(b_pos.x, b_pos.z)
		var b_body := StaticBody3D.new()
		b_body.name = "HillsideBoulder_%d" % idx
		b_body.collision_layer = 1
		b_body.collision_mask = 0
		b_body.position = b_pos
		add_child(b_body)

		var b_size := Vector3(3.2 + float(idx % 3) * 0.8, 2.2 + float(idx % 2) * 0.6, 2.8 + float((idx + 1) % 3) * 0.6)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b_size
		col.shape = shape
		col.position = Vector3(0.0, b_size.y * 0.45, 0.0)
		b_body.add_child(col)

		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = b_size
		mi.mesh = mesh
		mi.position = Vector3(0.0, b_size.y * 0.45, 0.0)
		mi.rotation = Vector3(0.12 * float(idx % 4), float(idx) * 0.5, 0.08 * float(idx % 3))
		mi.material_override = rock_mat
		b_body.add_child(mi)


func _build_trees_and_foliage() -> void:
	var tree_specs: Array[Dictionary] = []

	# 1. Hand-placed Boulevard & Town Square Oak/Cypress Trees (clear of doors, sidewalks & river)
	for bx in [-296.0, -251.0, -205.0, -161.0, -119.0, 102.0, 225.0, 265.0, 305.0, 345.0]:
		if absf(bx - get_river_center_x(40.0)) < 32.0:
			continue
		tree_specs.append({"pos": Vector3(bx, 2.15, 27.2), "var": 1 if int(absf(bx)) % 2 == 1 else 0, "scale": 1.0})
		tree_specs.append({"pos": Vector3(bx, 2.15, 52.8), "var": 0 if int(absf(bx)) % 2 == 1 else 1, "scale": 1.0})
	for px in [-48.0, 48.0]:
		for pz in [-2.0, 82.0]:
			tree_specs.append({"pos": Vector3(px, 2.15, pz), "var": 1, "scale": 1.05})

	# 2. Coastal Palm Trees along sandy beaches (top Y = 1.00, clear of harbor piers & river mouth!)
	for px in range(-700, 740, 82):
		var fx: float = float(px)
		if absf(fx - get_river_center_x(488.0)) < 36.0 or absf(fx - get_river_center_x(-492.0)) < 36.0:
			continue
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

	# 4. Orchard fruit trees around NorthOrchardBarn
	for op in [Vector2(-435.0, -260.0), Vector2(-435.0, -300.0), Vector2(-385.0, -260.0), Vector2(-385.0, -300.0), Vector2(-445.0, -280.0), Vector2(-375.0, -280.0)]:
		tree_specs.append({"pos": Vector3(op.x, get_terrain_height(op.x, op.y), op.y), "var": 0, "scale": 1.05})

	# 5. Countryside Meadow Groves across the island grounded cleanly to terrain
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var attempts: int = 0
	while tree_specs.size() < 168 and attempts < 700:
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
		var ty: float = get_terrain_height(tx, tz)
		tree_specs.append({"pos": Vector3(tx, ty, tz), "var": v_kind, "scale": rng.randf_range(0.88, 1.28)})

	for i in range(tree_specs.size()):
		var ts: Dictionary = tree_specs[i]
		var t_node: Node3D = BuildingMeshBuilder.build_layered_tree(self, ts["pos"], int(ts["var"]), float(ts["scale"]))
		t_node.name = "Tree_%d" % i


func _is_tree_zone_blocked(tx: float, tz: float) -> bool:
	# Central river corridor (within 34m of river center)
	if absf(tx - get_river_center_x(tz)) < 34.0:
		return true
	# Farmstead Fazenda footprint
	if absf(tx - 365.0) < 40.0 and absf(tz - 255.0) < 35.0:
		return true
	# NorthOrchardBarn outpost footprint
	if absf(tx - (-410.0)) < 30.0 and absf(tz - (-280.0)) < 28.0:
		return true

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
		Vector2(-155.0, 102.0), Vector2(105.0, -12.0), Vector2(-24.0, 412.0),
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
		{"kind": DestructibleProp.PropKind.WHITE_FENCE, "pos": Vector3(225.0, 2.15, 52.5), "rot": 0.0},
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

	# 4 River Patrol Boats inside central river channel beside river docks
	var rz_town: float = -40.0
	var rx_town: float = get_river_center_x(rz_town)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_ROYAL, Vector3(rx_town - 8.0, -0.15, rz_town - 6.0), 0.0)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), -1, Vector3(rx_town + 6.0, -0.15, rz_town + 6.0), PI)

	var rz_north: float = -260.0
	var rx_north: float = get_river_center_x(rz_north)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), NetworkManager.TEAM_NATIONAL, Vector3(rx_north - 8.0, -0.15, rz_north - 6.0), 0.0)
	_spawn_vehicle(vehicles_parent, VehicleBoat.new(), -1, Vector3(rx_north + 6.0, -0.15, rz_north + 6.0), PI)

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
