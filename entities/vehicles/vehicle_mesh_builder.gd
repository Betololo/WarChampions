class_name VehicleMeshBuilder
extends RefCounted

## Builds sculpted Battlefield Heroes cartoon vehicle models (Tank, Jeep, Fighter Plane,
## Patrol Boat, AA Flak Bunker) with lofted curved silhouettes, hand-painted textures,
## opaque Z-buffered armor/hulls, translucent tinted cockpit glass, and animated sub-pivots.


static func make_mat(
	col: Color,
	tex_key: String = "",
	roughness: float = 0.65,
	metallic: float = 0.15,
	alpha: float = 1.0,
	uv_scale: Vector2 = Vector2.ONE
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var final_col: Color = col
	final_col.a = alpha
	mat.albedo_color = final_col
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	if not tex_key.is_empty():
		mat.albedo_texture = CartoonAssets.get_texture(tex_key)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	# Keep opaque parts strictly in Godot's opaque Z-buffer; allow alpha only for cockpit/windshield glass.
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return mat


static func add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not p_name.is_empty():
		mi.name = p_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi, true)
	return mi


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
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
	var cyl := CylinderMesh.new()
	cyl.top_radius = r_top
	cyl.bottom_radius = r_bot
	cyl.height = height
	cyl.radial_segments = radial_seg
	return add_part(parent, cyl, pos, rot, mat, p_name)


static func _make_palette(team: int) -> Dictionary:
	var is_royal: bool = (team != 1)
	var accent_col: Color = Color(0.95, 0.78, 0.22) if is_royal else Color(0.84, 0.16, 0.18)
	var armor_tex: String = "veh_olive" if is_royal else "veh_panzer"
	var head_mat := make_mat(Color(1.0, 0.95, 0.72), "", 0.18, 0.0)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.90, 0.55)
	head_mat.emission_energy_multiplier = 1.35
	return {
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


static func add_wheel(parent: Node3D, radius: float, width: float, pos: Vector3, tire_mat: Material, hub_mat: Material) -> Node3D:
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	wheel.position = pos
	wheel.set_meta("wheel_radius", radius)
	parent.add_child(wheel, true)

	# Beveled cartoon tire loft (rings strictly ascending in local Y, rotated onto X axle)
	var hw: float = width * 0.5
	var tire_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -hw, "rx": radius * 0.74, "rz": radius * 0.74, "p": 2.0, "col": Color(0.80, 0.80, 0.82)},
		{"y": -hw * 0.76, "rx": radius * 0.98, "rz": radius * 0.98, "p": 2.0, "col": Color(0.95, 0.95, 0.96)},
		{"y": 0.0, "rx": radius, "rz": radius, "p": 2.0, "col": Color.WHITE},
		{"y": hw * 0.76, "rx": radius * 0.98, "rz": radius * 0.98, "p": 2.0, "col": Color(0.95, 0.95, 0.96)},
		{"y": hw, "rx": radius * 0.74, "rz": radius * 0.74, "p": 2.0, "col": Color(0.80, 0.80, 0.82)},
	], 18)
	add_part(wheel, tire_mesh, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), tire_mat, "Tire")

	# Painted rim dish, center hubcap & visible cross spoke rib so rolling rotation reads clearly
	_add_cyl(wheel, radius * 0.58, radius * 0.58, width * 1.03, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), hub_mat, 14, "Rim")
	_add_cyl(wheel, radius * 0.24, radius * 0.24, width * 1.12, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), hub_mat, 10, "Hubcap")
	_add_box(wheel, Vector3(width * 1.07, radius * 0.96, radius * 0.16), Vector3.ZERO, Vector3.ZERO, hub_mat, "SpokeA")
	_add_box(wheel, Vector3(width * 1.07, radius * 0.16, radius * 0.96), Vector3.ZERO, Vector3.ZERO, hub_mat, "SpokeB")
	return wheel


static func _add_seat_cushion(parent: Node3D, pos: Vector3, width: float, mat: Material) -> void:
	_add_box(parent, Vector3(width, 0.12, 0.48), pos, Vector3.ZERO, mat)
	_add_box(parent, Vector3(width, 0.52, 0.12), pos + Vector3(0.0, 0.28, 0.22), Vector3(0.14, 0.0, 0.0), mat)


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

	# Teardrop lofted fuselage (tail -> nose along -Z; cockpit deck dips slightly so pilot sits inside glass canopy)
	var fuse_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -3.05, "z": 0.12, "rx": 0.13, "rz": 0.24, "p": 2.0, "col": Color(0.86, 0.86, 0.90)},
		{"y": -1.85, "z": 0.04, "rx": 0.34, "rz": 0.42, "p": 2.1, "col": Color(0.95, 0.95, 0.98), "side_ao": 0.08},
		{"y": -0.65, "z": -0.06, "rx": 0.54, "rz": 0.46, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 0.85, "z": -0.06, "rx": 0.58, "rz": 0.48, "p": 2.2, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 2.30, "z": 0.00, "rx": 0.52, "rz": 0.50, "p": 2.1, "col": Color(0.96, 0.96, 0.98)},
		{"y": 2.86, "z": 0.00, "rx": 0.38, "rz": 0.38, "p": 2.0, "col": Color(0.90, 0.90, 0.94)},
	], 20)
	add_part(root, fuse_mesh, Vector3(0.0, 1.02, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), body_mat, "Fuselage")
	_add_cyl(root, 0.42, 0.48, 0.32, Vector3(0.0, 1.02, -2.68), Vector3(PI * 0.5, 0.0, 0.0), trim_mat, 18, "NoseTrimBand")

	# Translucent tinted bubble glass canopy over pilot (Vector3(0.0, 0.92, -0.15)) + opaque frame arches
	var canopy_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -0.92, "z": 0.04, "rx": 0.22, "rz": 0.18, "p": 2.0},
		{"y": -0.35, "z": 0.34, "rx": 0.44, "rz": 0.48, "p": 2.0},
		{"y": 0.22, "z": 0.38, "rx": 0.46, "rz": 0.52, "p": 2.0},
		{"y": 0.72, "z": 0.22, "rx": 0.36, "rz": 0.36, "p": 2.0},
		{"y": 0.98, "z": 0.04, "rx": 0.14, "rz": 0.12, "p": 2.0},
	], 18)
	add_part(root, canopy_mesh, Vector3(0.0, 1.42, -0.10), Vector3(-PI * 0.5, 0.0, 0.0), pal["glass_mat"], "CanopyGlass")
	for fz in [-0.66, 0.28]:
		_add_cyl(root, 0.44, 0.44, 0.07, Vector3(0.0, 1.54, fz), Vector3(PI * 0.5, 0.0, 0.0), body_mat, 14, "CanopyFrame")

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
		# Wing roundels (Royal) or Balkenkreuz cross medallions (National) + wing gun barrels + exhausts + gear
		if is_royal:
			_add_cyl(root, 0.48, 0.48, 0.03, Vector3(sx * 2.85, 1.06, 0.10), Vector3.ZERO, royal_blue_mat, 18, "RoundelOut")
			_add_cyl(root, 0.32, 0.32, 0.035, Vector3(sx * 2.85, 1.065, 0.10), Vector3.ZERO, white_mat, 18, "RoundelMid")
			_add_cyl(root, 0.15, 0.15, 0.04, Vector3(sx * 2.85, 1.07, 0.10), Vector3.ZERO, trim_mat, 16, "RoundelCore")
		else:
			_add_box(root, Vector3(0.84, 0.035, 0.22), Vector3(sx * 2.85, 1.065, 0.10), Vector3.ZERO, white_mat, "CrossH")
			_add_box(root, Vector3(0.22, 0.035, 0.84), Vector3(sx * 2.85, 1.065, 0.10), Vector3.ZERO, white_mat, "CrossV")
			_add_box(root, Vector3(0.72, 0.04, 0.12), Vector3(sx * 2.85, 1.07, 0.10), Vector3.ZERO, dark_mat)
			_add_box(root, Vector3(0.12, 0.04, 0.72), Vector3(sx * 2.85, 1.07, 0.10), Vector3.ZERO, dark_mat)
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

	# Flared V-hull with extruded pointed bow along -Z (deck rests on top at Y=0.72)
	var hull_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -3.05, "z": 0.00, "rx": 1.28, "rz": 0.34, "p": 2.6, "col": Color(0.84, 0.84, 0.88), "side_ao": 0.10},
		{"y": -1.40, "z": 0.00, "rx": 1.44, "rz": 0.36, "p": 2.5, "col": Color(0.95, 0.95, 0.98), "side_ao": 0.10},
		{"y": 0.40, "z": 0.02, "rx": 1.46, "rz": 0.37, "p": 2.4, "col": Color.WHITE, "side_ao": 0.10},
		{"y": 1.45, "z": 0.06, "rx": 1.38, "rz": 0.36, "p": 2.3, "col": Color.WHITE, "side_ao": 0.08},
		{"y": 2.40, "z": 0.16, "rx": 0.92, "rz": 0.34, "p": 1.9, "col": Color.WHITE},
		{"y": 3.05, "z": 0.28, "rx": 0.36, "rz": 0.28, "p": 1.7, "col": Color.WHITE},
		{"y": 3.42, "z": 0.38, "rx": 0.08, "rz": 0.20, "p": 1.6, "col": Color(0.95, 0.95, 0.98)},
	], 18)
	add_part(root, hull_mesh, Vector3(0.0, 0.36, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), hull_mat, "VHull")

	# Golden-brown planked wooden deck & side gunwale coaming rails
	var deck_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": -2.98, "rx": 1.22, "rz": 0.04, "p": 3.2, "col": Color(0.95, 0.95, 0.95)},
		{"y": 0.40, "rx": 1.38, "rz": 0.04, "p": 3.0, "col": Color.WHITE},
		{"y": 1.45, "rx": 1.30, "rz": 0.04, "p": 2.6, "col": Color.WHITE},
		{"y": 2.40, "rx": 0.84, "rz": 0.04, "p": 2.1, "col": Color.WHITE},
		{"y": 3.12, "rx": 0.16, "rz": 0.04, "p": 1.8, "col": Color.WHITE},
	], 16)
	add_part(root, deck_mesh, Vector3(0.0, 0.72, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, "WoodDeck")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.14, 0.36, 4.38), Vector3(sx * 1.38, 0.90, 0.79), Vector3.ZERO, wood_mat, "Gunwale")
		_add_box(root, Vector3(0.14, 0.34, 1.91), Vector3(sx * 0.87, 0.92, -2.21), Vector3(0.0, sx * 0.563, 0.0), wood_mat, "BowGunwale")
		_add_box(root, Vector3(0.08, 0.12, 4.42), Vector3(sx * 1.46, 0.68, 0.76), Vector3.ZERO, trim_mat, "TeamStripe")

	# Armored wheelhouse framing the enclosed helmsman (0.0, 0.85, 0.35) + wrap-around tinted glass
	_add_box(root, Vector3(1.88, 0.68, 0.14), Vector3(0.0, 1.08, -0.34), Vector3.ZERO, cabin_mat, "CabinFrontWall")
	_add_box(root, Vector3(1.88, 0.68, 0.14), Vector3(0.0, 1.08, 1.04), Vector3.ZERO, cabin_mat, "CabinRearWall")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.14, 0.68, 1.38), Vector3(sx * 0.87, 1.08, 0.35), Vector3.ZERO, cabin_mat, "CabinSideWall")
		for pz in [-0.28, 0.98]:
			_add_box(root, Vector3(0.12, 0.88, 0.12), Vector3(sx * 0.86, 1.86, pz), Vector3.ZERO, cabin_mat, "CabinPillar")
	_add_box(root, Vector3(1.66, 0.78, 0.04), Vector3(0.0, 1.84, -0.30), Vector3(-0.12, 0.0, 0.0), pal["glass_mat"], "HelmWindshield")
	for sx in [-1.0, 1.0]:
		_add_box(root, Vector3(0.04, 0.76, 1.16), Vector3(sx * 0.86, 1.84, 0.35), Vector3.ZERO, pal["glass_mat"], "HelmSideGlass")
	_add_box(root, Vector3(2.02, 0.14, 1.62), Vector3(0.0, 2.34, 0.36), Vector3.ZERO, cabin_mat, "CabinRoof")
	_add_box(root, Vector3(2.06, 0.07, 1.66), Vector3(0.0, 2.38, 0.36), Vector3.ZERO, trim_mat)
	_add_cyl(root, 0.02, 0.03, 1.15, Vector3(0.0, 2.95, 0.55), Vector3.ZERO, steel_mat, 8, "Mast")
	_add_headlight_pod(root, Vector3(0.0, 2.52, -0.32), 0.12, steel_mat, pal["headlight_mat"])

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
		_add_seat_cushion(root, Vector3(sx * 0.72, 0.72, -1.25), 0.58, pal["leather_mat"])
		_add_box(root, Vector3(0.46, 0.24, 1.25), Vector3(sx * 0.92, 0.84, 1.92), Vector3.ZERO, wood_mat, "RearBench")

	# Mounted twin bow MG behind sloped steel gun shield
	_add_cyl(root, 0.10, 0.14, 0.62, Vector3(0.0, 1.04, -2.42), Vector3.ZERO, steel_mat, 10, "BowMount")
	_add_box(root, Vector3(0.76, 0.48, 0.06), Vector3(0.0, 1.38, -2.52), Vector3(0.24, 0.0, 0.0), steel_mat, "BowShield")
	for bx in [-0.11, 0.11]:
		_add_cyl(root, 0.032, 0.038, 0.98, Vector3(bx, 1.40, -2.84), Vector3(PI * 0.5, 0.0, 0.0), pal["dark_metal"], 8, "BowMG")

	return {}


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
	_add_seat_cushion(turret, Vector3(0.0, 0.34, 0.52), 0.50, pal["leather_mat"])
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
