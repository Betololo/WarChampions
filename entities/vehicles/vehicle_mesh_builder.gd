class_name VehicleMeshBuilder
extends RefCounted

## Builds sculpted Battlefield Heroes cartoon vehicle models (Tank, Jeep, Fighter Plane,
## Patrol Boat, AA Flak Bunker) with lofted curved silhouettes, hand-painted textures,
## opaque Z-buffered armor/hulls, translucent tinted cockpit glass, and animated sub-pivots.


static var _mat_cache: Dictionary = {}
static var _palette_cache: Dictionary = {}
static var _prim_cache: Dictionary = {}


static func clear_caches() -> void:
	_mat_cache.clear()
	_palette_cache.clear()
	_prim_cache.clear()


static func make_mat(
	col: Color,
	tex_key: String = "",
	roughness: float = 0.65,
	metallic: float = 0.15,
	alpha: float = 1.0,
	uv_scale: Vector2 = Vector2.ONE
) -> StandardMaterial3D:
	var final_col: Color = col
	var is_opaque: bool = alpha >= 0.99
	final_col.a = 1.0 if is_opaque else alpha
	var cache_key := "%s|%s|%.3f|%.3f|%.3f|%.2f,%.2f" % [
		final_col.to_html(true), tex_key, roughness, metallic, final_col.a, uv_scale.x, uv_scale.y
	]
	if _mat_cache.has(cache_key):
		return _mat_cache[cache_key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = final_col
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	if not tex_key.is_empty():
		mat.albedo_texture = CartoonAssets.get_texture(tex_key)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	# Keep opaque parts strictly in Godot's opaque Z-buffer; allow alpha only for cockpit/windshield glass.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if is_opaque else BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[cache_key] = mat
	return mat


static func add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not p_name.is_empty():
		mi.name = p_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	var no_shadow: bool = (mat is StandardMaterial3D and (mat as StandardMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED)
	if not no_shadow and not p_name.is_empty():
		no_shadow = (
			p_name in ["Rim", "Hubcap", "SpokeA", "SpokeB", "ExhaustRow", "WindscreenFrameTop", "RoundelOut", "RoundelMid", "RoundelCore", "CrossH", "CrossV", "Headlight", "HeadlightL", "HeadlightR"]
			or p_name.begins_with("Gauge") or p_name.begins_with("Dial") or p_name.begins_with("Steering")
		)
	if no_shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 260.0
	parent.add_child(mi, true)
	return mi


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
	var key := "box|%.4f,%.4f,%.4f" % [size.x, size.y, size.z]
	var box: BoxMesh = _prim_cache.get(key)
	if box == null:
		box = BoxMesh.new()
		box.size = size
		_prim_cache[key] = box
	return add_part(parent, box, pos, rot, mat, p_name)


static func _add_cyl(
	parent: Node3D,
	r_top: float,
	r_bot: float,
	height: float,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	radial_seg: int = 16,
	p_name: String = ""
) -> MeshInstance3D:
	var key := "cyl|%.4f,%.4f,%.4f|%d" % [r_top, r_bot, height, radial_seg]
	var cyl: CylinderMesh = _prim_cache.get(key)
	if cyl == null:
		cyl = CylinderMesh.new()
		cyl.top_radius = r_top
		cyl.bottom_radius = r_bot
		cyl.height = height
		cyl.radial_segments = radial_seg
		_prim_cache[key] = cyl
	return add_part(parent, cyl, pos, rot, mat, p_name)


static func _make_palette(team: int) -> Dictionary:
	var t_key: int = 1 if team == 1 else 0
	if _palette_cache.has(t_key):
		return _palette_cache[t_key] as Dictionary
	var is_royal: bool = (t_key == 0)
	var accent_col: Color = Color(0.95, 0.78, 0.22) if is_royal else Color(0.84, 0.16, 0.18)
	var armor_tex: String = "veh_olive" if is_royal else "veh_panzer"
	var head_mat := StandardMaterial3D.new()
	head_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	head_mat.albedo_color = Color(1.0, 0.95, 0.72, 1.0)
	head_mat.roughness = 0.18
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.90, 0.55)
	head_mat.emission_energy_multiplier = 1.35
	var pal := {
		"is_royal": is_royal,
		"armor_mat": make_mat(Color.WHITE, armor_tex, 0.70, 0.18),
		"armor_hi": make_mat(Color(1.0, 1.0, 0.98), armor_tex, 0.64, 0.22),
		"trim_mat": make_mat(accent_col, "", 0.40, 0.28),
		"steel_mat": make_mat(Color.WHITE, "veh_steel", 0.38, 0.58),
		"dark_metal": make_mat(Color(0.20, 0.21, 0.24), "", 0.42, 0.55),
		"track_mat": make_mat(Color.WHITE, "veh_track", 0.78, 0.28, 1.0, Vector2(1.0, 6.0)),
		"tire_mat": make_mat(Color.WHITE, "veh_tire", 0.86, 0.04, 1.0, Vector2(2.0, 1.0)),
		"wood_mat": make_mat(Color.WHITE, "veh_wood_deck", 0.72, 0.04),
		"sandbag_mat": make_mat(Color.WHITE, "veh_sandbag", 0.92, 0.02),
		"leather_mat": make_mat(Color(0.46, 0.28, 0.16), "", 0.74, 0.05),
		"glass_mat": make_mat(Color(0.56, 0.82, 0.98), "", 0.10, 0.12, 0.40),
		"headlight_mat": head_mat,
	}
	_palette_cache[t_key] = pal
	return pal


static func add_wheel(parent: Node3D, radius: float, width: float, pos: Vector3, tire_mat: Material, hub_mat: Material) -> Node3D:
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = pos
	wheel.set_meta("wheel_radius", radius)
	parent.add_child(wheel, true)

	# Beveled cartoon tire loft (rings strictly ascending in local Y, rotated onto X axle)
	var tire_key := "tire|%.4f,%.4f" % [radius, width]
	var tire_mesh: ArrayMesh = _prim_cache.get(tire_key) as ArrayMesh
	if tire_mesh == null:
		var hw: float = width * 0.5
		tire_mesh = HeroMeshBuilder.make_loft([
			{"y": -hw, "rx": radius * 0.74, "rz": radius * 0.74, "p": 2.0, "col": Color(0.80, 0.80, 0.82)},
			{"y": -hw * 0.76, "rx": radius * 0.98, "rz": radius * 0.98, "p": 2.0, "col": Color(0.95, 0.95, 0.96)},
			{"y": 0.0, "rx": radius, "rz": radius, "p": 2.0, "col": Color.WHITE},
			{"y": hw * 0.76, "rx": radius * 0.98, "rz": radius * 0.98, "p": 2.0, "col": Color(0.95, 0.95, 0.96)},
			{"y": hw, "rx": radius * 0.74, "rz": radius * 0.74, "p": 2.0, "col": Color(0.80, 0.80, 0.82)},
		], 18)
		_prim_cache[tire_key] = tire_mesh
	add_part(wheel, tire_mesh, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), tire_mat, "Tire")

	# Painted rim dish, center hubcap & visible cross spoke rib so rolling rotation reads clearly
	_add_cyl(wheel, radius * 0.58, radius * 0.58, width * 1.03, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), hub_mat, 14, "Rim")
	_add_cyl(wheel, radius * 0.24, radius * 0.24, width * 1.12, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), hub_mat, 10, "Hubcap")
	_add_box(wheel, Vector3(width * 1.07, radius * 0.96, radius * 0.16), Vector3.ZERO, Vector3.ZERO, hub_mat, "SpokeA")
	_add_box(wheel, Vector3(width * 1.07, radius * 0.16, radius * 0.96), Vector3.ZERO, Vector3.ZERO, hub_mat, "SpokeB")
	return wheel


static func _add_seat_cushion(parent: Node3D, pos: Vector3, width: float, mat: Material, back_h: float = 0.52, back_aft: float = 0.0) -> void:
	_add_box(parent, Vector3(width, 0.12, 0.48), pos, Vector3.ZERO, mat)
	_add_box(parent, Vector3(width, back_h, 0.12), pos + Vector3(0.0, back_h * 0.5 + 0.02, 0.22 + back_aft), Vector3(0.14, 0.0, 0.0), mat)


static func _make_arch_mesh(rx: float, ry: float, tube_r: float, start_ang: float = -0.65, arc_segs: int = 16, tube_segs: int = 8) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[Array] = []
	var centers: Array[Vector3] = []
	var end_ang: float = PI - start_ang
	for i in range(arc_segs + 1):
		var a: float = lerpf(start_ang, end_ang, float(i) / float(arc_segs))
		var c := Vector3(cos(a) * rx, sin(a) * ry, 0.0)
		var tang := Vector3(-sin(a) * rx, cos(a) * ry, 0.0).normalized()
		var n_xy := Vector3(tang.y, -tang.x, 0.0)
		var ring: Array[Vector3] = []
		for j in range(tube_segs):
			var phi: float = TAU * float(j) / float(tube_segs)
			ring.append(c + n_xy * (cos(phi) * tube_r) + Vector3.BACK * (sin(phi) * tube_r))
		rings.append(ring)
		centers.append(c)
	for i in range(arc_segs):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for j in range(tube_segs):
			var jn: int = (j + 1) % tube_segs
			st.add_vertex(r0[j])
			st.add_vertex(r0[jn])
			st.add_vertex(r1[j])
			st.add_vertex(r0[jn])
			st.add_vertex(r1[jn])
			st.add_vertex(r1[j])
	for j in range(tube_segs):
		var jn: int = (j + 1) % tube_segs
		st.add_vertex(centers[0])
		st.add_vertex(rings[0][jn])
		st.add_vertex(rings[0][j])
		st.add_vertex(centers[arc_segs])
		st.add_vertex(rings[arc_segs][j])
		st.add_vertex(rings[arc_segs][jn])
	st.generate_normals()
	return st.commit()


static func _add_headlight_pod(parent: Node3D, pos: Vector3, radius: float, shell_mat: Material, lens_mat: Material) -> void:
	_add_cyl(parent, radius, radius * 0.82, radius * 1.3, pos, Vector3(-PI * 0.5, 0.0, 0.0), shell_mat, 12)
	_add_cyl(parent, radius * 0.82, radius * 0.82, 0.04, pos + Vector3(0.0, 0.0, -radius * 0.66), Vector3(-PI * 0.5, 0.0, 0.0), lens_mat, 12)


static func build_tank_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var is_royal: bool = pal["is_royal"]
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]
	var track_mat: Material = pal["track_mat"]

	# Lower armored tub & sloped glacis upper hull (loft extruded stern->nose along -Z)
	_add_box(root, Vector3(2.26, 0.52, 4.90), Vector3(0.0, 0.62, 0.02), Vector3.ZERO, armor_mat, "LowerHull")
	var hull_p: float = 2.6 if is_royal else 3.8
	var hull_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -2.65, "z": 0.00, "rx": 1.18, "rz": 0.34, "p": hull_p, "col": Color(0.84, 0.84, 0.86), "side_ao": 0.10},
		{"y": -1.65, "z": 0.02, "rx": 1.24, "rz": 0.38, "p": hull_p, "col": Color(0.95, 0.95, 0.96), "side_ao": 0.10},
		{"y": 1.05, "z": 0.04, "rx": 1.28, "rz": 0.42, "p": hull_p, "col": Color.WHITE, "side_ao": 0.10},
		{"y": 2.25, "z": -0.08, "rx": 1.20, "rz": 0.24, "p": 3.0, "col": Color(0.95, 0.95, 0.96), "side_ao": 0.08},
		{"y": 2.68, "z": -0.16, "rx": 1.04, "rz": 0.14, "p": 2.8, "col": Color(0.86, 0.86, 0.88)},
	], 18)
	add_part(root, hull_mesh, Vector3(0.0, 1.15, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), armor_mat, "UpperHull")

	# Engine louvers, twin exhaust stacks, headlights, driver visor & rear passenger grab rail
	for lx in [-0.52, 0.52]:
		_add_box(root, Vector3(0.66, 0.07, 0.96), Vector3(lx, 1.54, 1.65), Vector3.ZERO, dark_mat, "EngineGrille")
		_add_cyl(root, 0.09, 0.10, 0.72, Vector3(lx * 1.35, 1.26, 2.70), Vector3(0.22, 0.0, 0.0), steel_mat, 10, "Exhaust")
		_add_headlight_pod(root, Vector3(lx * 1.95, 1.34, -2.28), 0.12, steel_mat, pal["headlight_mat"])
	_add_box(root, Vector3(0.56, 0.16, 0.22), Vector3(-0.48, 1.37, -1.96), Vector3(-0.24, 0.0, 0.0), dark_mat, "DriverVisor")
	_add_cyl(root, 0.045, 0.045, 0.55, Vector3(0.45, 1.24, -2.55), Vector3(PI * 0.5, 0.0, 0.0), dark_mat, 8, "HullMG")
	_add_box(root, Vector3(1.50, 0.06, 0.06), Vector3(0.0, 1.88, 2.66), Vector3.ZERO, steel_mat, "RearGrabBar")
	for gx in [-0.72, 0.72]:
		_add_box(root, Vector3(0.06, 0.34, 0.06), Vector3(gx, 1.71, 2.66), Vector3.ZERO, steel_mat)

	# Track sponsons, fenders, optional Panzer side skirts & 14 spinning road/idler/sprocket wheels
	var wheels: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var tx: float = sx * 1.54
		_add_box(root, Vector3(0.62, 0.09, 5.34), Vector3(tx, 1.14, 0.0), Vector3.ZERO, armor_hi, "Fender")
		_add_box(root, Vector3(0.54, 0.11, 4.86), Vector3(tx, 1.04, 0.0), Vector3.ZERO, track_mat, "TrackTop")
		_add_box(root, Vector3(0.54, 0.11, 4.30), Vector3(tx, 0.19, 0.0), Vector3.ZERO, track_mat, "TrackBot")
		_add_box(root, Vector3(0.54, 0.11, 0.94), Vector3(tx, 0.52, -2.30), Vector3(0.62, 0.0, 0.0), track_mat)
		_add_box(root, Vector3(0.54, 0.11, 0.94), Vector3(tx, 0.52, 2.30), Vector3(-0.62, 0.0, 0.0), track_mat)
		if not is_royal:
			_add_box(root, Vector3(0.07, 0.58, 4.42), Vector3(sx * 1.88, 0.84, 0.04), Vector3.ZERO, armor_hi, "SideSkirt")
			_add_box(root, Vector3(0.08, 0.10, 1.20), Vector3(sx * 1.89, 0.92, -0.35), Vector3.ZERO, trim_mat)
		for rz in [-1.66, -0.83, 0.0, 0.83, 1.66]:
			wheels.append(add_wheel(root, 0.34, 0.46, Vector3(tx, 0.48, rz), dark_mat, armor_hi))
		wheels.append(add_wheel(root, 0.28, 0.44, Vector3(tx, 0.72, -2.42), dark_mat, steel_mat))
		wheels.append(add_wheel(root, 0.30, 0.46, Vector3(tx, 0.72, 2.42), dark_mat, trim_mat))

	# 360-degree rotating cast/angular turret + commander cupola + radio whip + elevating barrel pivot
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.60, -0.26)
	root.add_child(turret)

	var tur_p: float = 2.05 if is_royal else 3.6
	var tur_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 1.02, "rz": 1.22, "p": tur_p, "col": Color(0.86, 0.86, 0.88), "side_ao": 0.10},
		{"y": 0.26, "rx": 1.08, "rz": 1.28, "p": tur_p, "col": Color.WHITE, "side_ao": 0.10},
		{"y": 0.60, "rx": 0.92, "rz": 1.08, "p": tur_p, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 0.74, "rx": 0.74, "rz": 0.86, "p": tur_p, "col": Color(0.95, 0.95, 0.98)},
	], 18)
	add_part(turret, tur_mesh, Vector3.ZERO, Vector3.ZERO, armor_hi, "TurretBody")
	_add_box(turret, Vector3(1.16 if not is_royal else 0.94, 0.48, 0.62), Vector3(0.0, 0.38, 1.22), Vector3.ZERO, armor_mat, "TurretBustle")
	_add_box(turret, Vector3(1.20 if not is_royal else 0.98, 0.10, 0.64), Vector3(0.0, 0.56, 1.22), Vector3.ZERO, trim_mat)
	_add_cyl(turret, 0.34, 0.38, 0.20, Vector3(0.32, 0.80, 0.24), Vector3.ZERO, armor_mat, 14, "Cupola")
	_add_cyl(turret, 0.36, 0.36, 0.06, Vector3(0.32, 0.92, 0.24), Vector3.ZERO, trim_mat, 14, "HatchLid")
	_add_cyl(turret, 0.015, 0.025, 1.35, Vector3(-0.56, 1.36, 0.82), Vector3(0.08, 0.0, -0.05), steel_mat, 8, "Antenna")

	var barrel_piv := Node3D.new()
	barrel_piv.name = "BarrelPivot"
	barrel_piv.position = Vector3(0.0, 0.38, -1.04)
	turret.add_child(barrel_piv)
	_add_cyl(barrel_piv, 0.26, 0.26, 0.86, Vector3(0.0, 0.0, -0.06), Vector3(0.0, 0.0, PI * 0.5), armor_hi, 14, "Mantlet")
	var barrel_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.145, "rz": 0.145, "p": 2.0, "col": Color(0.92, 0.92, 0.94)},
		{"y": 0.55, "rx": 0.115, "rz": 0.115, "p": 2.0, "col": Color.WHITE},
		{"y": 2.55, "rx": 0.092, "rz": 0.092, "p": 2.0, "col": Color.WHITE},
	], 14)
	add_part(barrel_piv, barrel_mesh, Vector3(0.0, 0.0, -0.15), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, "CannonBarrel")
	_add_cyl(barrel_piv, 0.145, 0.115, 0.34, Vector3(0.0, 0.0, -2.76), Vector3(-PI * 0.5, 0.0, 0.0), trim_mat, 12, "MuzzleBrake")
	_add_cyl(barrel_piv, 0.032, 0.036, 0.52, Vector3(0.28, 0.04, -0.34), Vector3(PI * 0.5, 0.0, 0.0), dark_mat, 8, "CoaxMG")

	return {"turret": turret, "barrel": barrel_piv, "wheels": wheels}


static func build_jeep_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]
	var tire_mat: Material = pal["tire_mat"]
	var leather_mat: Material = pal["leather_mat"]

	# Steel chassis frame, open tub floor & front/rear steel bumpers
	_add_box(root, Vector3(1.86, 0.12, 4.02), Vector3(0.0, 0.48, 0.0), Vector3.ZERO, dark_mat, "ChassisFloor")
	_add_box(root, Vector3(2.14, 0.18, 0.20), Vector3(0.0, 0.54, -2.16), Vector3.ZERO, steel_mat, "FrontBumper")
	_add_box(root, Vector3(2.10, 0.18, 0.18), Vector3(0.0, 0.54, 2.14), Vector3.ZERO, steel_mat, "RearBumper")

	# Sculpted Willys/Kubelwagen tapered hood (back->front along -Z) + radiator grille slats + headlights
	var hood_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.92, "rz": 0.35, "p": 2.6, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 0.68, "rx": 0.82, "rz": 0.33, "p": 2.6, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 1.38, "rx": 0.66, "rz": 0.29, "p": 2.6, "col": Color(0.88, 0.88, 0.90)},
	], 16)
	add_part(root, hood_mesh, Vector3(0.0, 0.82, -0.68), Vector3(-PI * 0.5, 0.0, 0.0), armor_mat, "Hood")
	_add_box(root, Vector3(1.18, 0.44, 0.08), Vector3(0.0, 0.84, -2.09), Vector3.ZERO, dark_mat, "GrilleRecess")
	for gx in range(-3, 4):
		_add_box(root, Vector3(0.07, 0.46, 0.10), Vector3(float(gx) * 0.15, 0.84, -2.10), Vector3.ZERO, armor_hi)
	for sx in [-1.0, 1.0]:
		_add_headlight_pod(root, Vector3(sx * 0.58, 1.00, -2.06), 0.13, steel_mat, pal["headlight_mat"])
		# Cut-down door sills (framing seated driver/passengers without clipping shoulders) + rear quarters & flared fenders
		_add_box(root, Vector3(0.16, 0.38, 1.24), Vector3(sx * 0.98, 0.70, -0.05), Vector3.ZERO, armor_mat, "DoorSill")
		_add_box(root, Vector3(0.16, 0.66, 1.48), Vector3(sx * 0.98, 0.86, 1.30), Vector3.ZERO, armor_mat, "RearQuarter")
		_add_box(root, Vector3(0.17, 0.10, 1.46), Vector3(sx * 0.99, 1.12, 1.30), Vector3.ZERO, trim_mat)
		_add_box(root, Vector3(0.46, 0.09, 0.92), Vector3(sx * 1.04, 0.98, -1.45), Vector3.ZERO, armor_hi, "FrontArch")
		_add_box(root, Vector3(0.46, 0.09, 0.92), Vector3(sx * 1.04, 0.98, 1.45), Vector3.ZERO, armor_hi, "RearArch")
	_add_box(root, Vector3(1.98, 0.64, 0.14), Vector3(0.0, 0.84, 2.02), Vector3.ZERO, armor_mat, "Tailgate")
	_add_box(root, Vector3(0.55, 0.04, 1.24), Vector3(0.0, 1.145, -1.36), Vector3(-0.044, 0.0, 0.0), trim_mat, "HoodStripe")

	# Framed translucent tinted windshield, dashboard, steering wheel & leather seats
	var ws_piv := Node3D.new()
	ws_piv.name = "WindshieldFrame"
	ws_piv.position = Vector3(0.0, 1.18, -0.74)
	ws_piv.rotation.x = 0.22
	root.add_child(ws_piv)
	_add_box(ws_piv, Vector3(1.88, 0.62, 0.03), Vector3(0.0, 0.34, 0.0), Vector3.ZERO, pal["glass_mat"], "WindshieldGlass")
	_add_box(ws_piv, Vector3(1.94, 0.07, 0.07), Vector3(0.0, 0.66, 0.0), Vector3.ZERO, armor_hi)
	_add_box(ws_piv, Vector3(1.94, 0.07, 0.07), Vector3(0.0, 0.03, 0.0), Vector3.ZERO, armor_hi)
	for px in [-0.94, 0.0, 0.94]:
		_add_box(ws_piv, Vector3(0.07, 0.66, 0.07), Vector3(px, 0.34, 0.0), Vector3.ZERO, armor_hi)

	_add_box(root, Vector3(1.84, 0.28, 0.24), Vector3(0.0, 1.00, -0.66), Vector3.ZERO, dark_mat, "Dashboard")
	_add_cyl(root, 0.035, 0.035, 0.44, Vector3(-0.46, 1.00, -0.58), Vector3(0.85, 0.0, 0.0), dark_mat, 8, "SteeringCol")
	var wheel_ring := TorusMesh.new()
	wheel_ring.inner_radius = 0.17
	wheel_ring.outer_radius = 0.22
	add_part(root, wheel_ring, Vector3(-0.46, 1.15, -0.42), Vector3(0.85, 0.0, 0.0), dark_mat, "SteeringWheel")
	_add_seat_cushion(root, Vector3(-0.46, 0.60, -0.05), 0.56, leather_mat)
	_add_seat_cushion(root, Vector3(0.46, 0.60, -0.05), 0.56, leather_mat)
	_add_seat_cushion(root, Vector3(0.0, 0.64, 0.98), 1.56, leather_mat)

	# Rear spare wheel (non-spinning decorative mount) + jerrycan + 4 spinning road wheels
	var spare_holder := Node3D.new()
	spare_holder.name = "SpareWheelMount"
	spare_holder.position = Vector3(0.32, 1.02, 2.22)
	spare_holder.rotation.y = PI * 0.5
	root.add_child(spare_holder)
	add_wheel(spare_holder, 0.39, 0.26, Vector3.ZERO, tire_mat, armor_hi)
	_add_box(root, Vector3(0.32, 0.46, 0.20), Vector3(-0.48, 1.02, 2.18), Vector3.ZERO, trim_mat, "Jerrycan")

	var wheels: Array[Node3D] = []
	for wx in [-1.06, 1.06]:
		for wz in [-1.45, 1.45]:
			wheels.append(add_wheel(root, 0.45, 0.34, Vector3(wx, 0.45, wz), tire_mat, armor_hi))
	return {"wheels": wheels}


static func build_plane_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var is_royal: bool = pal["is_royal"]
	var plane_tex: String = "veh_plane_royal" if is_royal else "veh_plane_national"
	var body_mat := make_mat(Color.WHITE, plane_tex, 0.38, 0.24)
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]

	# Sculpted teardrop fuselage split around open cockpit bay (z in [-0.55, 0.35])
	var fore_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.55, "z": -0.06, "rx": 0.58, "rz": 0.48, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 1.40, "z": -0.04, "rx": 0.56, "rz": 0.49, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 2.30, "z": 0.00, "rx": 0.52, "rz": 0.50, "p": 2.1, "col": Color(0.96, 0.96, 0.98)},
		{"y": 2.86, "z": 0.00, "rx": 0.38, "rz": 0.38, "p": 2.0, "col": Color(0.90, 0.90, 0.94)},
	], 20)
	add_part(root, fore_mesh, Vector3(0.0, 1.02, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), body_mat, "Fuselage")

	var aft_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -3.05, "z": 0.12, "rx": 0.13, "rz": 0.24, "p": 2.0, "col": Color(0.86, 0.86, 0.90)},
		{"y": -1.85, "z": 0.04, "rx": 0.34, "rz": 0.42, "p": 2.1, "col": Color(0.95, 0.95, 0.98), "side_ao": 0.08},
		{"y": -0.75, "z": -0.04, "rx": 0.52, "rz": 0.46, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
		{"y": -0.35, "z": -0.06, "rx": 0.56, "rz": 0.47, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
	], 20)
	add_part(root, aft_mesh, Vector3(0.0, 1.02, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), body_mat, "AftFuselage")

	_add_cyl(root, 0.42, 0.48, 0.32, Vector3(0.0, 1.02, -2.68), Vector3(PI * 0.5, 0.0, 0.0), trim_mat, 18, "NoseTrimBand")

	# Open fighter Cockpit tub: deep belly floor, side walls, dark tub, seat backrest & controls
	_add_box(root, Vector3(0.98, 0.48, 0.92), Vector3(0.0, 0.74, -0.10), Vector3.ZERO, body_mat, "CockpitBelly")
	_add_box(root, Vector3(0.14, 0.42, 0.92), Vector3(-0.43, 1.15, -0.10), Vector3.ZERO, body_mat, "CockpitWallL")
	_add_box(root, Vector3(0.14, 0.42, 0.92), Vector3(0.43, 1.15, -0.10), Vector3.ZERO, body_mat, "CockpitWallR")
	_add_box(root, Vector3(0.70, 0.06, 0.88), Vector3(0.0, 0.80, -0.10), Vector3.ZERO, dark_mat, "CockpitFloor")

	var leather_mat := make_mat(Color(0.28, 0.18, 0.11), "", 0.70, 0.08)
	_add_box(root, Vector3(0.48, 0.46, 0.12), Vector3(0.0, 1.22, 0.32), Vector3(0.14, 0.0, 0.0), leather_mat, "PilotSeatBack")
	_add_box(root, Vector3(0.58, 0.32, 0.08), Vector3(0.0, 1.25, -0.52), Vector3(-0.16, 0.0, 0.0), dark_mat, "DashboardPanel")
	var white_gauge_mat := make_mat(Color(0.95, 0.96, 0.98), "", 0.42, 0.12)
	_add_cyl(root, 0.055, 0.055, 0.02, Vector3(-0.14, 1.27, -0.50), Vector3(-0.16, 0.0, 0.0), white_gauge_mat, 10, "DialL")
	_add_cyl(root, 0.070, 0.070, 0.02, Vector3(0.0, 1.29, -0.50), Vector3(-0.16, 0.0, 0.0), trim_mat, 12, "DialC")
	_add_cyl(root, 0.055, 0.055, 0.02, Vector3(0.14, 1.27, -0.50), Vector3(-0.16, 0.0, 0.0), white_gauge_mat, 10, "DialR")
	_add_cyl(root, 0.022, 0.018, 0.34, Vector3(0.0, 0.96, -0.32), Vector3(0.18, 0.0, 0.0), steel_mat, 8, "ControlStick")
	_add_cyl(root, 0.028, 0.028, 0.08, Vector3(0.0, 1.12, -0.29), Vector3(0.18, 0.0, 0.0), dark_mat, 8, "StickGrip")

	# Quilted padded leather coaming collar around cockpit rim
	var coaming_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -0.44, "rx": 0.44, "rz": 0.055, "p": 2.2, "col": Color(0.32, 0.20, 0.12)},
		{"y": 0.00, "rx": 0.46, "rz": 0.060, "p": 2.2, "col": Color(0.36, 0.24, 0.14)},
		{"y": 0.44, "rx": 0.44, "rz": 0.055, "p": 2.2, "col": Color(0.32, 0.20, 0.12)},
	], 16)
	add_part(root, coaming_mesh, Vector3(0.0, 1.34, -0.10), Vector3.ZERO, leather_mat, "CockpitCoaming")
	_add_cyl(root, 0.045, 0.045, 0.90, Vector3(-0.43, 1.34, -0.10), Vector3(PI * 0.5, 0.0, 0.0), leather_mat, 10, "CoamingL")
	_add_cyl(root, 0.045, 0.045, 0.90, Vector3(0.43, 1.34, -0.10), Vector3(PI * 0.5, 0.0, 0.0), leather_mat, 10, "CoamingR")
	_add_cyl(root, 0.048, 0.048, 0.70, Vector3(0.0, 1.36, 0.33), Vector3(0.0, 0.0, PI * 0.5), leather_mat, 10, "CoamingAft")

	# Compact angled fighter windscreen ahead of pilot (leaving top, sides & rear 100% open)
	var screen_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -0.16, "rx": 0.34, "rz": 0.024, "p": 2.0},
		{"y": 0.00, "rx": 0.32, "rz": 0.024, "p": 2.0},
		{"y": 0.16, "rx": 0.28, "rz": 0.024, "p": 2.0},
	], 12)
	add_part(root, screen_mesh, Vector3(0.0, 1.48, -0.58), Vector3(-0.50, 0.0, 0.0), pal["glass_mat"], "WindscreenGlass")
	_add_box(root, Vector3(0.50, 0.028, 0.028), Vector3(0.0, 1.61, -0.52), Vector3(-0.50, 0.0, 0.0), body_mat, "WindscreenFrameTop")

	# Nose spinner + spinning 3-blade propeller
	var prop := Node3D.new()
	prop.name = "Propeller"
	prop.position = Vector3(0.0, 1.02, -2.92)
	root.add_child(prop)
	var spinner_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.37, "rz": 0.37, "p": 2.0, "col": Color(0.90, 0.90, 0.92)},
		{"y": 0.32, "rx": 0.26, "rz": 0.26, "p": 2.0, "col": Color.WHITE},
		{"y": 0.58, "rx": 0.05, "rz": 0.05, "p": 2.0, "col": Color.WHITE},
	], 16)
	add_part(prop, spinner_mesh, Vector3.ZERO, Vector3(-PI * 0.5, 0.0, 0.0), trim_mat, "Spinner")
	for b_idx in range(3):
		var blade_piv := Node3D.new()
		blade_piv.rotation.z = float(b_idx) * (TAU / 3.0)
		prop.add_child(blade_piv)
		_add_box(blade_piv, Vector3(0.18, 0.96, 0.04), Vector3(0.0, 0.66, -0.16), Vector3(0.0, 0.28, 0.0), dark_mat, "Blade")
		_add_box(blade_piv, Vector3(0.17, 0.16, 0.045), Vector3(0.0, 1.08, -0.16), Vector3(0.0, 0.28, 0.0), trim_mat, "BladeTip")

	# Swept cambered wings (Spitfire elliptical for Royal vs Bf-109 angular tapered for National)
	var wing_rings: Array[Dictionary] = [
		{"y": 0.00, "z": 0.00, "rx": 0.15, "rz": 1.12, "p": 2.1, "col": Color(0.92, 0.92, 0.95)},
		{"y": 1.50, "z": 0.08, "rx": 0.13, "rz": 1.04 if is_royal else 0.94, "p": 2.1, "col": Color.WHITE},
		{"y": 3.00, "z": 0.16, "rx": 0.10, "rz": 0.86 if is_royal else 0.72, "p": 2.0, "col": Color.WHITE},
		{"y": 4.25, "z": 0.24, "rx": 0.06, "rz": 0.42 if is_royal else 0.48, "p": 1.9 if is_royal else 3.2, "col": Color(0.96, 0.96, 0.98)},
	]
	var wing_mesh: ArrayMesh = HeroMeshBuilder.make_loft(wing_rings, 16)
	var white_mat := make_mat(Color(0.95, 0.96, 0.98), "", 0.42, 0.12)
	var royal_blue_mat := make_mat(Color(0.14, 0.34, 0.78), "", 0.40, 0.15)
	var wheels: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		add_part(root, wing_mesh, Vector3(sx * 0.48, 0.88, -0.02), Vector3(0.0, 0.0, -sx * (PI * 0.5 - 0.04)), body_mat, "MainWing")
		# Wing roundels (Royal) or Balkenkreuz cross medallions (National) tilted flush above dihedral wing surface
		var mark_rot := Vector3(0.0, 0.0, sx * 0.04)
		if is_royal:
			_add_cyl(root, 0.48, 0.48, 0.032, Vector3(sx * 2.85, 1.100, 0.10), mark_rot, royal_blue_mat, 18, "RoundelOut")
			_add_cyl(root, 0.32, 0.32, 0.036, Vector3(sx * 2.85, 1.102, 0.10), mark_rot, white_mat, 18, "RoundelMid")
			_add_cyl(root, 0.15, 0.15, 0.040, Vector3(sx * 2.85, 1.104, 0.10), mark_rot, trim_mat, 16, "RoundelCore")
		else:
			_add_box(root, Vector3(0.84, 0.034, 0.22), Vector3(sx * 2.85, 1.100, 0.10), mark_rot, white_mat, "CrossH")
			_add_box(root, Vector3(0.22, 0.034, 0.84), Vector3(sx * 2.85, 1.100, 0.10), mark_rot, white_mat, "CrossV")
			_add_box(root, Vector3(0.72, 0.038, 0.12), Vector3(sx * 2.85, 1.104, 0.10), mark_rot, dark_mat)
			_add_box(root, Vector3(0.12, 0.038, 0.72), Vector3(sx * 2.85, 1.104, 0.10), mark_rot, dark_mat)
		_add_cyl(root, 0.04, 0.045, 0.72, Vector3(sx * 1.48, 0.86, -1.02), Vector3(PI * 0.5, 0.0, 0.0), dark_mat, 8, "WingGun")
		_add_box(root, Vector3(0.14, 0.10, 0.65), Vector3(sx * 0.54, 1.04, -1.85), Vector3.ZERO, dark_mat, "ExhaustRow")
		_add_cyl(root, 0.055, 0.055, 0.62, Vector3(sx * 1.02, 0.60, -0.82), Vector3(0.24, 0.0, sx * 0.22), steel_mat, 10, "GearStrut")
		wheels.append(add_wheel(root, 0.24, 0.17, Vector3(sx * 1.12, 0.34, -0.94), pal["tire_mat"], trim_mat))

	# Empennage: sculpted vertical tail fin + horizontal stabilizers + tailwheel
	var tail_fin: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "z": 0.00, "rx": 0.09, "rz": 0.68, "p": 2.2, "col": Color(0.92, 0.92, 0.95)},
		{"y": 0.68, "z": 0.14, "rx": 0.06, "rz": 0.48, "p": 2.1, "col": Color.WHITE},
		{"y": 1.16, "z": 0.26, "rx": 0.035, "rz": 0.26, "p": 2.0, "col": Color.WHITE},
	], 12)
	add_part(root, tail_fin, Vector3(0.0, 1.16, 2.48), Vector3.ZERO, trim_mat, "TailFin")
	var stab_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.065, "rz": 0.50, "p": 2.1},
		{"y": 1.42, "rx": 0.035, "rz": 0.28, "p": 2.0},
	], 10)
	for sx in [-1.0, 1.0]:
		add_part(root, stab_mesh, Vector3(sx * 0.18, 1.12, 2.52), Vector3(0.0, 0.0, -sx * PI * 0.5), body_mat, "Tailplane")
	_add_cyl(root, 0.035, 0.035, 0.34, Vector3(0.0, 0.72, 2.86), Vector3(0.32, 0.0, 0.0), steel_mat, 8, "TailStrut")

	return {"propeller": prop, "wheels": wheels}


static func build_boat_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var hull_col: Color = Color(0.24, 0.44, 0.70) if pal["is_royal"] else Color(0.30, 0.33, 0.38)
	var hull_mat := make_mat(hull_col, "", 0.52, 0.16)
	var cabin_mat: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var wood_mat: Material = pal["wood_mat"]

	# Flared V-hull keeping sheer cleanly beneath WoodDeck (deck top Y=0.76) with contoured closed bow stem
	var hull_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -3.05, "z": 0.00, "rx": 1.28, "rz": 0.35, "p": 2.8, "col": Color(0.84, 0.84, 0.88), "side_ao": 0.10},
		{"y": -1.40, "z": 0.00, "rx": 1.44, "rz": 0.36, "p": 2.8, "col": Color(0.95, 0.95, 0.98), "side_ao": 0.10},
		{"y": 0.40, "z": 0.00, "rx": 1.46, "rz": 0.36, "p": 2.8, "col": Color.WHITE, "side_ao": 0.10},
		{"y": 1.55, "z": 0.00, "rx": 1.38, "rz": 0.36, "p": 2.7, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 2.45, "z": 0.01, "rx": 0.94, "rz": 0.35, "p": 2.6, "col": Color.WHITE},
		{"y": 3.05, "z": 0.02, "rx": 0.48, "rz": 0.34, "p": 2.5, "col": Color.WHITE},
		{"y": 3.44, "z": 0.05, "rx": 0.19, "rz": 0.30, "p": 2.4, "col": Color(0.95, 0.95, 0.98)},
	], 18)
	add_part(root, hull_mesh, Vector3(0.0, 0.34, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), hull_mat, "VHull")

	# Golden-brown planked wooden deck & contoured bow/stern gunwale coaming rails
	var deck_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -2.98, "rx": 1.24, "rz": 0.04, "p": 3.2, "col": Color(0.95, 0.95, 0.95)},
		{"y": 0.40, "rx": 1.38, "rz": 0.04, "p": 3.2, "col": Color.WHITE},
		{"y": 1.55, "rx": 1.31, "rz": 0.04, "p": 3.0, "col": Color.WHITE},
		{"y": 2.45, "rx": 0.88, "rz": 0.04, "p": 2.7, "col": Color.WHITE},
		{"y": 3.24, "rx": 0.14, "rz": 0.04, "p": 2.3, "col": Color.WHITE},
	], 16)
	add_part(root, deck_mesh, Vector3(0.0, 0.72, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, "WoodDeck")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.14, 0.36, 4.57), Vector3(sx * 1.36, 0.90, 0.735), Vector3.ZERO, wood_mat, "Gunwale")
		_add_box(root, Vector3(0.14, 0.35, 1.08), Vector3(sx * 1.11, 0.91, -2.00), Vector3(0.0, sx * 0.507, 0.0), wood_mat, "BowGunwale")
		_add_box(root, Vector3(0.14, 0.34, 1.18), Vector3(sx * 0.47, 0.92, -2.865), Vector3(0.0, sx * 0.754, 0.0), wood_mat, "BowGunwaleTip")
		_add_box(root, Vector3(0.08, 0.12, 4.50), Vector3(sx * 1.46, 0.68, 0.70), Vector3.ZERO, trim_mat, "TeamStripe")
	_add_box(root, Vector3(0.22, 0.38, 0.22), Vector3(0.0, 0.88, -3.28), Vector3(0.0, PI * 0.25, 0.0), wood_mat, "BowStem")
	_add_box(root, Vector3(2.60, 0.36, 0.14), Vector3(0.0, 0.90, 2.98), Vector3.ZERO, wood_mat, "SternTransom")

	# Extended armored wheelhouse giving helmsman (0.0, 0.85, 0.35) full seated legroom behind CabinFrontWall
	_add_box(root, Vector3(1.88, 0.68, 0.14), Vector3(0.0, 1.08, -0.62), Vector3.ZERO, cabin_mat, "CabinFrontWall")
	_add_box(root, Vector3(1.88, 0.68, 0.14), Vector3(0.0, 1.08, 1.04), Vector3.ZERO, cabin_mat, "CabinRearWall")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.14, 0.68, 1.66), Vector3(sx * 0.87, 1.08, 0.21), Vector3.ZERO, cabin_mat, "CabinSideWall")
		for pz in [-0.56, 0.98]:
			_add_box(root, Vector3(0.12, 0.88, 0.12), Vector3(sx * 0.86, 1.86, pz), Vector3.ZERO, cabin_mat, "CabinPillar")
	_add_box(root, Vector3(1.66, 0.78, 0.04), Vector3(0.0, 1.84, -0.58), Vector3(-0.12, 0.0, 0.0), pal["glass_mat"], "HelmWindshield")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.04, 0.76, 1.42), Vector3(sx * 0.86, 1.84, 0.21), Vector3.ZERO, pal["glass_mat"], "HelmSideGlass")
	_add_box(root, Vector3(2.02, 0.14, 1.90), Vector3(0.0, 2.34, 0.21), Vector3.ZERO, cabin_mat, "CabinRoof")
	_add_box(root, Vector3(2.06, 0.07, 1.94), Vector3(0.0, 2.38, 0.21), Vector3.ZERO, trim_mat)
	_add_cyl(root, 0.02, 0.03, 1.15, Vector3(0.0, 2.95, 0.45), Vector3.ZERO, steel_mat, 8, "Mast")
	_add_headlight_pod(root, Vector3(0.0, 2.52, -0.58), 0.12, steel_mat, pal["headlight_mat"])
	_add_cyl(root, 0.035, 0.035, 0.36, Vector3(0.0, 1.16, -0.40), Vector3(0.85, 0.0, 0.0), pal["dark_metal"], 8, "HelmCol")
	var helm_wheel := TorusMesh.new()
	helm_wheel.inner_radius = 0.16
	helm_wheel.outer_radius = 0.20
	add_part(root, helm_wheel, Vector3(0.0, 1.28, -0.26), Vector3(0.85, 0.0, 0.0), pal["dark_metal"], "HelmWheel")

	# Red & white lifebuoy rings mounted on cabin flanks + forward/stern crew benches
	var buoy_mesh := TorusMesh.new()
	buoy_mesh.inner_radius = 0.14
	buoy_mesh.outer_radius = 0.27
	var buoy_red := make_mat(Color(0.92, 0.22, 0.16), "", 0.48, 0.05)
	var buoy_white := make_mat(Color(0.96, 0.96, 0.98), "", 0.48, 0.05)
	for sx in [-1.0, 1.0]:
		add_part(root, buoy_mesh, Vector3(sx * 0.97, 1.18, 0.36), Vector3(0.0, 0.0, PI * 0.5), buoy_red, "Lifebuoy")
		_add_box(root, Vector3(0.06, 0.12, 0.12), Vector3(sx * 0.98, 1.38, 0.36), Vector3.ZERO, buoy_white)
		_add_box(root, Vector3(0.06, 0.12, 0.12), Vector3(sx * 0.98, 0.98, 0.36), Vector3.ZERO, buoy_white)
		_add_box(root, Vector3(0.46, 0.24, 1.25), Vector3(sx * 0.92, 0.84, 1.92), Vector3.ZERO, wood_mat, "RearBench")

	# Mounted twin bow MG behind sloped steel gun shield (rotating turret + elevating barrels)
	var bow_turret := Node3D.new()
	bow_turret.name = "Turret"
	bow_turret.position = Vector3(0.0, 1.04, -2.42)
	root.add_child(bow_turret)
	_add_cyl(bow_turret, 0.10, 0.14, 0.62, Vector3.ZERO, Vector3.ZERO, steel_mat, 10, "BowMount")
	_add_box(bow_turret, Vector3(0.76, 0.48, 0.06), Vector3(0.0, 0.34, -0.10), Vector3(0.24, 0.0, 0.0), steel_mat, "BowShield")

	var bow_barrel := Node3D.new()
	bow_barrel.name = "BarrelPivot"
	bow_barrel.position = Vector3(0.0, 0.36, -0.10)
	bow_turret.add_child(bow_barrel)
	for bx in [-0.11, 0.11]:
		_add_cyl(bow_barrel, 0.032, 0.038, 0.98, Vector3(bx, 0.0, -0.32), Vector3(PI * 0.5, 0.0, 0.0), pal["dark_metal"], 8, "BowMG")

	return {"turret": bow_turret, "barrel": bow_barrel}


static func build_aa_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]
	var concrete_mat := make_mat(Color(0.54, 0.55, 0.53), "", 0.90, 0.02)

	# Concrete octagonal bunker base + bolted steel turret ring + 10 curved woven sandbags
	_add_cyl(root, 1.92, 2.04, 0.34, Vector3(0.0, 0.17, 0.0), Vector3.ZERO, concrete_mat, 8, "ConcreteBase")
	_add_cyl(root, 1.66, 1.78, 0.16, Vector3(0.0, 0.38, 0.0), Vector3.ZERO, concrete_mat, 12, "BunkerCurb")
	_add_cyl(root, 0.84, 0.92, 0.18, Vector3(0.0, 0.42, 0.0), Vector3.ZERO, steel_mat, 16, "TurretRing")

	var bag_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -0.44, "rx": 0.22, "rz": 0.16, "p": 2.4, "col": Color(0.84, 0.82, 0.80)},
		{"y": -0.20, "rx": 0.30, "rz": 0.22, "p": 2.5, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 0.20, "rx": 0.30, "rz": 0.22, "p": 2.5, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 0.44, "rx": 0.22, "rz": 0.16, "p": 2.4, "col": Color(0.84, 0.82, 0.80)},
	], 12)
	for row_idx in range(2):
		var count: int = 10
		var ring_r: float = 1.72 - float(row_idx) * 0.05
		var bag_y: float = 0.46 + float(row_idx) * 0.26
		var phase: float = float(row_idx) * (PI / float(count))
		for i in range(count):
			var ang: float = phase + float(i) * (TAU / float(count))
			var bpos := Vector3(cos(ang) * ring_r, bag_y, sin(ang) * ring_r)
			add_part(root, bag_mesh, bpos, Vector3(PI * 0.5, -ang, 0.0), pal["sandbag_mat"], "Sandbag_%02d" % [row_idx * count + i])

	# Rotating AA turret carriage + gunner seat + sloped steel gun shield + elevating dual Flak barrels
	var turret := Node3D.new()
	turret.name = "AATurret"
	turret.position = Vector3(0.0, 0.52, 0.0)
	root.add_child(turret)

	_add_cyl(turret, 0.68, 0.78, 0.20, Vector3(0.0, 0.10, 0.0), Vector3.ZERO, armor_mat, 14, "Turntable")
	_add_box(turret, Vector3(0.68, 0.48, 0.09), Vector3(0.0, 0.45, -0.34), Vector3(0.20, 0.0, 0.0), armor_mat, "LowerGunShield")
	for sx in [-1.0, 1.0]:
		_add_box(turret, Vector3(0.14, 0.72, 0.44), Vector3(sx * 0.38, 0.54, -0.08), Vector3.ZERO, armor_hi, "TrunnionArm")
		_add_box(turret, Vector3(0.46, 0.94, 0.09), Vector3(sx * 0.56, 0.70, -0.32), Vector3(0.20, sx * -0.18, 0.0), armor_mat, "GunShield")
		_add_box(turret, Vector3(0.46, 0.10, 0.10), Vector3(sx * 0.56, 1.08, -0.39), Vector3(0.20, sx * -0.18, 0.0), trim_mat, "ShieldStripe")
	_add_seat_cushion(turret, Vector3(0.0, 0.32, 0.56), 0.50, pal["leather_mat"], 0.28, 0.10)
	_add_cyl(turret, 0.18, 0.18, 0.06, Vector3(0.48, 0.56, 0.24), Vector3(0.0, 0.0, PI * 0.5), steel_mat, 12, "TraverseWheel")

	var barrel_piv := Node3D.new()
	barrel_piv.name = "AABarrelPivot"
	barrel_piv.position = Vector3(0.0, 0.88, -0.14)
	turret.add_child(barrel_piv)
	_add_box(barrel_piv, Vector3(0.56, 0.30, 0.72), Vector3(0.0, 0.0, 0.02), Vector3.ZERO, armor_hi, "BreechCradle")

	var flak_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.085, "rz": 0.085, "p": 2.0, "col": Color(0.88, 0.88, 0.90)},
		{"y": 0.52, "rx": 0.072, "rz": 0.072, "p": 2.0, "col": Color.WHITE},
		{"y": 1.98, "rx": 0.048, "rz": 0.048, "p": 2.0, "col": Color.WHITE},
	], 12)
	for bx in [-0.20, 0.20]:
		add_part(barrel_piv, flak_mesh, Vector3(bx, 0.02, -0.24), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, "FlakBarrel")
		_add_cyl(barrel_piv, 0.082, 0.048, 0.24, Vector3(bx, 0.02, -2.30), Vector3(-PI * 0.5, 0.0, 0.0), dark_mat, 12, "FlashCone")
	for sx in [-1.0, 1.0]:
		_add_cyl(barrel_piv, 0.22, 0.22, 0.16, Vector3(sx * 0.42, 0.08, 0.02), Vector3(0.0, 0.0, PI * 0.5), trim_mat, 14, "AmmoDrum")

	return {"turret": turret, "barrel": barrel_piv}


static func build_motorcycle_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]
	var tire_mat: Material = pal["tire_mat"]
	var leather_mat: Material = pal["leather_mat"]

	# Frame backbone, engine block & twin chrome exhaust pipes
	_add_box(root, Vector3(0.40, 0.32, 0.54), Vector3(0.0, 0.44, -0.10), Vector3.ZERO, dark_mat, "EngineBlock")
	_add_box(root, Vector3(0.16, 0.14, 1.54), Vector3(0.0, 0.62, 0.02), Vector3.ZERO, armor_mat, "FrameSpine")
	for sx in [-1.0, 1.0]:
		_add_cyl(root, 0.040, 0.046, 1.22, Vector3(sx * 0.24, 0.34, 0.36), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 8, "ExhaustPipe")
		_add_cyl(root, 0.034, 0.034, 0.76, Vector3(sx * 0.13, 0.72, -0.72), Vector3(-0.36, 0.0, 0.0), steel_mat, 8, "FrontFork")
		_add_box(root, Vector3(0.18, 0.34, 0.44), Vector3(sx * 0.28, 0.58, 0.74), Vector3.ZERO, leather_mat, "Saddlebag")

	# Mudguards, handlebars & headlight
	_add_box(root, Vector3(0.24, 0.06, 0.52), Vector3(0.0, 0.80, -0.88), Vector3(-0.22, 0.0, 0.0), armor_hi, "FrontFender")
	_add_box(root, Vector3(0.26, 0.07, 0.66), Vector3(0.0, 0.78, 0.88), Vector3(0.18, 0.0, 0.0), armor_hi, "RearFender")
	_add_cyl(root, 0.024, 0.024, 0.76, Vector3(0.0, 1.06, -0.54), Vector3(0.0, 0.0, PI * 0.5), steel_mat, 8, "Handlebars")
	_add_headlight_pod(root, Vector3(0.0, 0.94, -0.78), 0.11, steel_mat, pal["headlight_mat"])

	# Sculpted teardrop fuel tank & team trim stripe
	var tank_mesh: ArrayMesh = _prim_cache.get("moto_tank") as ArrayMesh
	if tank_mesh == null:
		tank_mesh = HeroMeshBuilder.make_loft([
			{"y": -0.34, "rx": 0.14, "rz": 0.12, "p": 2.2, "col": Color(0.88, 0.88, 0.90)},
			{"y": -0.05, "rx": 0.22, "rz": 0.17, "p": 2.4, "col": Color.WHITE, "side_ao": 0.08},
			{"y": 0.22, "rx": 0.20, "rz": 0.15, "p": 2.3, "col": Color.WHITE, "side_ao": 0.08},
			{"y": 0.34, "rx": 0.11, "rz": 0.10, "p": 2.1, "col": Color(0.90, 0.90, 0.92)},
		], 14)
		_prim_cache["moto_tank"] = tank_mesh
	add_part(root, tank_mesh, Vector3(0.0, 0.82, -0.36), Vector3(-PI * 0.5, 0.0, 0.0), armor_hi, "FuelTank")
	_add_box(root, Vector3(0.10, 0.035, 0.48), Vector3(0.0, 0.98, -0.36), Vector3.ZERO, trim_mat, "TankStripe")

	# Driver & rear passenger saddles
	_add_box(root, Vector3(0.34, 0.10, 0.46), Vector3(0.0, 0.66, -0.10), Vector3.ZERO, leather_mat, "DriverSaddle")
	_add_box(root, Vector3(0.32, 0.10, 0.42), Vector3(0.0, 0.74, 0.68), Vector3.ZERO, leather_mat, "PassengerSaddle")

	var wheels: Array[Node3D] = []
	wheels.append(add_wheel(root, 0.38, 0.22, Vector3(0.0, 0.38, -0.88), tire_mat, armor_hi))
	wheels.append(add_wheel(root, 0.38, 0.24, Vector3(0.0, 0.38, 0.88), tire_mat, armor_hi))
	return {"wheels": wheels}


static func build_apc_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]
	var tire_mat: Material = pal["tire_mat"]

	# Sculpted sloped armored carrier hull & chassis belly
	_add_box(root, Vector3(1.86, 0.22, 4.26), Vector3(0.0, 0.62, 0.0), Vector3.ZERO, dark_mat, "ChassisTub")
	var hull_mesh: ArrayMesh = _prim_cache.get("apc_hull") as ArrayMesh
	if hull_mesh == null:
		hull_mesh = HeroMeshBuilder.make_loft([
			{"y": -2.30, "z": 0.00, "rx": 1.18, "rz": 0.46, "p": 3.4, "col": Color(0.86, 0.86, 0.88), "side_ao": 0.10},
			{"y": -1.40, "z": 0.02, "rx": 1.24, "rz": 0.50, "p": 3.6, "col": Color(0.96, 0.96, 0.98), "side_ao": 0.10},
			{"y": 0.90, "z": 0.04, "rx": 1.26, "rz": 0.52, "p": 3.6, "col": Color.WHITE, "side_ao": 0.10},
			{"y": 1.90, "z": -0.06, "rx": 1.18, "rz": 0.38, "p": 3.2, "col": Color(0.95, 0.95, 0.98), "side_ao": 0.08},
			{"y": 2.35, "z": -0.16, "rx": 1.02, "rz": 0.22, "p": 3.0, "col": Color(0.88, 0.88, 0.90)},
		], 16)
		_prim_cache["apc_hull"] = hull_mesh
	add_part(root, hull_mesh, Vector3(0.0, 1.14, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), armor_mat, "ArmoredHull")

	# Armored driver visor, bumpers, rear ramp hatch, headlights & team trim skirts
	_add_box(root, Vector3(1.10, 0.18, 0.22), Vector3(0.0, 1.46, -1.56), Vector3(-0.24, 0.0, 0.0), dark_mat, "DriverVisor")
	_add_box(root, Vector3(2.36, 0.18, 0.22), Vector3(0.0, 0.66, -2.36), Vector3.ZERO, steel_mat, "FrontBumper")
	_add_box(root, Vector3(1.40, 0.72, 0.14), Vector3(0.0, 1.14, 2.28), Vector3.ZERO, armor_hi, "RearHatch")
	for sx in [-1.0, 1.0]:
		_add_headlight_pod(root, Vector3(sx * 0.74, 1.18, -2.18), 0.12, steel_mat, pal["headlight_mat"])
		_add_box(root, Vector3(0.10, 0.36, 4.10), Vector3(sx * 1.26, 0.96, 0.0), Vector3.ZERO, armor_hi, "SideArmor")
		_add_box(root, Vector3(0.11, 0.10, 1.80), Vector3(sx * 1.27, 1.14, -0.20), Vector3.ZERO, trim_mat, "SideStripe")

	_add_cyl(root, 0.72, 0.80, 0.14, Vector3(0.0, 1.66, 0.0), Vector3.ZERO, steel_mat, 16, "TurretRing")

	var wheels: Array[Node3D] = []
	for wx in [-1.12, 1.12]:
		for wz in [-1.65, 1.65]:
			wheels.append(add_wheel(root, 0.46, 0.36, Vector3(wx, 0.46, wz), tire_mat, armor_hi))

	# 360-degree rotating MG turret & elevating heavy MG barrel pivot
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.70, 0.0)
	root.add_child(turret)

	_add_cyl(turret, 0.62, 0.66, 0.16, Vector3(0.0, 0.08, 0.0), Vector3.ZERO, armor_hi, 14, "TurretCoaming")
	_add_box(turret, Vector3(0.86, 0.54, 0.08), Vector3(0.0, 0.46, -0.44), Vector3(0.18, 0.0, 0.0), armor_hi, "GunShield")
	_add_box(turret, Vector3(0.88, 0.09, 0.09), Vector3(0.0, 0.68, -0.48), Vector3(0.18, 0.0, 0.0), trim_mat, "ShieldStripe")
	_add_cyl(turret, 0.07, 0.10, 0.40, Vector3(0.0, 0.24, -0.34), Vector3.ZERO, dark_mat, 10, "PintleMount")

	var barrel_piv := Node3D.new()
	barrel_piv.name = "BarrelPivot"
	barrel_piv.position = Vector3(0.0, 0.45, -0.40)
	turret.add_child(barrel_piv)
	_add_box(barrel_piv, Vector3(0.18, 0.20, 0.62), Vector3(0.0, 0.0, -0.10), Vector3.ZERO, dark_mat, "MGReceiver")
	_add_cyl(barrel_piv, 0.056, 0.066, 0.70, Vector3(0.0, 0.02, -0.66), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, 10, "CoolingJacket")
	_add_cyl(barrel_piv, 0.032, 0.038, 1.15, Vector3(0.0, 0.02, -1.24), Vector3(-PI * 0.5, 0.0, 0.0), dark_mat, 10, "MGBarrel")
	_add_cyl(barrel_piv, 0.054, 0.032, 0.18, Vector3(0.0, 0.02, -1.86), Vector3(-PI * 0.5, 0.0, 0.0), trim_mat, 10, "MuzzleCone")
	_add_box(barrel_piv, Vector3(0.18, 0.22, 0.26), Vector3(0.20, -0.02, -0.08), Vector3.ZERO, trim_mat, "AmmoBox")

	return {"turret": turret, "barrel": barrel_piv, "wheels": wheels}


static func build_mounted_mg_visuals(root: Node3D, team: int) -> Dictionary:
	var pal: Dictionary = _make_palette(team)
	var armor_mat: Material = pal["armor_mat"]
	var armor_hi: Material = pal["armor_hi"]
	var trim_mat: Material = pal["trim_mat"]
	var steel_mat: Material = pal["steel_mat"]
	var dark_mat: Material = pal["dark_metal"]

	# Sandbag perimeter curb + heavy steel tripod pedestal
	_add_cyl(root, 0.92, 1.06, 0.18, Vector3(0.0, 0.09, 0.0), Vector3.ZERO, steel_mat, 12, "BasePlate")
	for i in range(3):
		var ang: float = float(i) * (TAU / 3.0)
		_add_box(root, Vector3(0.14, 0.22, 1.15), Vector3(sin(ang) * 0.45, 0.20, cos(ang) * 0.45), Vector3(0.0, ang, 0.0), dark_mat, "TripodLeg")
	_add_cyl(root, 0.18, 0.24, 0.88, Vector3(0.0, 0.54, 0.0), Vector3.ZERO, steel_mat, 12, "PedestalCol")
	_add_cyl(root, 0.34, 0.36, 0.12, Vector3(0.0, 0.98, 0.0), Vector3.ZERO, armor_hi, 14, "TurretRing")

	# 360-degree rotating turret + sculpted frontal armored gun shield
	var turret := Node3D.new()
	turret.name = "Turret"
	turret.position = Vector3(0.0, 1.04, 0.0)
	root.add_child(turret)

	_add_cyl(turret, 0.24, 0.28, 0.22, Vector3(0.0, 0.10, 0.0), Vector3.ZERO, dark_mat, 12, "PintleHead")
	# Main frontal steel gun shield + angled side wings + team trim stripe
	_add_box(turret, Vector3(0.92, 0.86, 0.10), Vector3(0.0, 0.48, -0.44), Vector3(0.14, 0.0, 0.0), armor_hi, "GunShieldCenter")
	_add_box(turret, Vector3(0.96, 0.12, 0.12), Vector3(0.0, 0.86, -0.49), Vector3(0.14, 0.0, 0.0), trim_mat, "GunShieldTopTrim")
	for sx in [-1.0, 1.0]:
		_add_box(turret, Vector3(0.36, 0.82, 0.09), Vector3(sx * 0.56, 0.46, -0.34), Vector3(0.14, sx * -0.42, 0.0), armor_mat, "GunShieldWing")
		_add_box(turret, Vector3(0.38, 0.10, 0.10), Vector3(sx * 0.56, 0.82, -0.39), Vector3(0.14, sx * -0.42, 0.0), trim_mat, "WingTrim")

	# Heavy ballistic MG barrel pivot
	var barrel_piv := Node3D.new()
	barrel_piv.name = "BarrelPivot"
	barrel_piv.position = Vector3(0.0, 0.46, -0.30)
	turret.add_child(barrel_piv)
	_add_box(barrel_piv, Vector3(0.20, 0.22, 0.66), Vector3(0.0, 0.0, -0.08), Vector3.ZERO, dark_mat, "MGReceiver")
	_add_cyl(barrel_piv, 0.060, 0.068, 0.76, Vector3(0.0, 0.02, -0.68), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, 10, "CoolingJacket")
	_add_cyl(barrel_piv, 0.034, 0.040, 1.22, Vector3(0.0, 0.02, -1.28), Vector3(-PI * 0.5, 0.0, 0.0), dark_mat, 10, "MGBarrel")
	_add_cyl(barrel_piv, 0.058, 0.034, 0.20, Vector3(0.0, 0.02, -1.92), Vector3(-PI * 0.5, 0.0, 0.0), trim_mat, 10, "MuzzleCone")
	_add_box(barrel_piv, Vector3(0.18, 0.22, 0.28), Vector3(0.22, -0.02, -0.06), Vector3.ZERO, trim_mat, "AmmoBox")
	# Rear spade handles
	for sx in [-0.11, 0.11]:
		_add_cyl(barrel_piv, 0.018, 0.018, 0.22, Vector3(sx, 0.02, 0.34), Vector3.ZERO, steel_mat, 8, "SpadeGrip")

	return {"turret": turret, "barrel": barrel_piv}


static func build_engineer_armor_plates(visual_root: Node3D, vehicle_type: int, team: int) -> Node3D:
	var plates := Node3D.new()
	plates.name = "EngineerArmorPlates"
	visual_root.add_child(plates)

	var steel_mat: Material = make_mat(Color(0.56, 0.62, 0.68), "veh_steel", 0.32, 0.68)
	var trim_col: Color = Color(0.28, 0.86, 1.0) if team != 1 else Color(1.0, 0.68, 0.20)
	var glow_trim := make_mat(trim_col, "", 0.22, 0.55)

	var half_w: float = 1.25
	var skirt_len: float = 3.6
	var skirt_y: float = 0.84
	var front_z: float = -2.25
	match vehicle_type:
		VehicleBase.VehicleType.TANK:
			half_w = 1.94
			skirt_len = 4.6
			skirt_y = 0.88
			front_z = -2.65
		VehicleBase.VehicleType.APC:
			half_w = 1.34
			skirt_len = 4.2
			skirt_y = 0.98
			front_z = -2.42
		VehicleBase.VehicleType.JEEP:
			half_w = 1.14
			skirt_len = 3.5
			skirt_y = 0.72
			front_z = -2.20
		VehicleBase.VehicleType.MOTORCYCLE:
			half_w = 0.42
			skirt_len = 1.5
			skirt_y = 0.60
			front_z = -1.02
		VehicleBase.VehicleType.BOAT:
			half_w = 1.50
			skirt_len = 4.6
			skirt_y = 0.88
			front_z = -3.15
		VehicleBase.VehicleType.PLANE:
			half_w = 0.62
			skirt_len = 2.6
			skirt_y = 0.92
			front_z = -2.25
		VehicleBase.VehicleType.AA_GUN, VehicleBase.VehicleType.MOUNTED_MG:
			half_w = 0.96
			skirt_len = 1.35
			skirt_y = 0.72
			front_z = -0.96

	for sx in [-1.0, 1.0]:
		_add_box(plates, Vector3(0.08, 0.44, skirt_len), Vector3(sx * half_w, skirt_y, 0.0), Vector3.ZERO, steel_mat, "ArmorSkirt")
		_add_box(plates, Vector3(0.09, 0.08, skirt_len * 0.92), Vector3(sx * (half_w + 0.01), skirt_y + 0.16, 0.0), Vector3.ZERO, glow_trim, "ArmorTrim")
	_add_box(plates, Vector3(half_w * 1.45, 0.34, 0.10), Vector3(0.0, skirt_y + 0.04, front_z), Vector3(-0.18, 0.0, 0.0), steel_mat, "ArmorFrontPlate")
	_add_box(plates, Vector3(half_w * 1.40, 0.07, 0.11), Vector3(0.0, skirt_y + 0.18, front_z - 0.02), Vector3(-0.18, 0.0, 0.0), glow_trim, "ArmorFrontTrim")

	return plates
