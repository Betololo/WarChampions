class_name HeroMeshBuilder
extends RefCounted

## Builds sculpted smooth cartoon hero parts (lofts with superellipse cross-sections,
## smooth vertex normals, painted fabric/skin textures, headgear, and detailed 3D weapons)
## matching classic Battlefield Heroes proportions instead of blocky primitives.

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _prim_cache: Dictionary = {}
static var _weapon_cache: Dictionary = {}
static var default_shadow_mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


static func clear_caches() -> void:
	_mesh_cache.clear()
	_mat_cache.clear()
	_prim_cache.clear()
	_weapon_cache.clear()


static func _store_mesh(key: String, mesh: ArrayMesh) -> ArrayMesh:
	_mesh_cache[key] = mesh
	return mesh


static func _emit_ring_strip(
	st: SurfaceTool,
	ring_pts: Array,
	ring_cols: Array,
	radial_seg: int,
	cap_ends: bool,
	bot_center: Vector3,
	top_center: Vector3,
	v_coords: PackedFloat32Array
) -> void:
	var n_rings: int = ring_pts.size()
	for r_idx in range(n_rings - 1):
		var p0: PackedVector3Array = ring_pts[r_idx]
		var p1: PackedVector3Array = ring_pts[r_idx + 1]
		var c0: PackedColorArray = ring_cols[r_idx]
		var c1: PackedColorArray = ring_cols[r_idx + 1]
		var v0: float = v_coords[r_idx]
		var v1: float = v_coords[r_idx + 1]

		for i in range(radial_seg):
			var u0: float = float(i) / float(radial_seg)
			var u1: float = float(i + 1) / float(radial_seg)

			# Triangle A
			st.set_color(c0[i])
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0[i])
			st.set_color(c0[i + 1])
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p0[i + 1])
			st.set_color(c1[i + 1])
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p1[i + 1])

			# Triangle B
			st.set_color(c0[i])
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0[i])
			st.set_color(c1[i + 1])
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p1[i + 1])
			st.set_color(c1[i])
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p1[i])

	if cap_ends and n_rings >= 2:
		var bot_pts: PackedVector3Array = ring_pts[0]
		var bot_cols: PackedColorArray = ring_cols[0]
		for i in range(radial_seg):
			st.set_color(bot_cols[i])
			st.set_uv(Vector2(0.5, v_coords[0]))
			st.add_vertex(bot_center)
			st.set_color(bot_cols[i + 1])
			st.set_uv(Vector2(0.5, v_coords[0]))
			st.add_vertex(bot_pts[i + 1])
			st.set_color(bot_cols[i])
			st.set_uv(Vector2(0.5, v_coords[0]))
			st.add_vertex(bot_pts[i])

		var top_pts: PackedVector3Array = ring_pts[n_rings - 1]
		var top_cols: PackedColorArray = ring_cols[n_rings - 1]
		for i in range(radial_seg):
			st.set_color(top_cols[i])
			st.set_uv(Vector2(0.5, v_coords[n_rings - 1]))
			st.add_vertex(top_center)
			st.set_color(top_cols[i])
			st.set_uv(Vector2(0.5, v_coords[n_rings - 1]))
			st.add_vertex(top_pts[i])
			st.set_color(top_cols[i + 1])
			st.set_uv(Vector2(0.5, v_coords[n_rings - 1]))
			st.add_vertex(top_pts[i + 1])


## Appends a superellipse loft into an existing SurfaceTool with optional transform and smooth group.
static func add_loft_to_st(
	st: SurfaceTool,
	rings: Array,
	radial_seg: int = 16,
	cap_ends: bool = true,
	xform: Transform3D = Transform3D.IDENTITY,
	smooth_group: int = 0
) -> void:
	if rings.size() < 2:
		return
	st.set_smooth_group(smooth_group)
	var ring_pts: Array = []
	var ring_cols: Array = []
	var v_coords := PackedFloat32Array()
	var n_rings: int = rings.size()

	for r_idx in range(n_rings):
		var r: Dictionary = rings[r_idx]
		var ry: float = float(r.get("y", 0.0))
		var rx_off: float = float(r.get("x", 0.0))
		var rz_off: float = float(r.get("z", 0.0))
		var rx: float = maxf(0.004, float(r.get("rx", 0.1)))
		var rz: float = maxf(0.004, float(r.get("rz", 0.1)))
		var p: float = maxf(1.5, float(r.get("p", 2.0)))
		var exp_val: float = 2.0 / p
		var col: Color = r.get("col", Color.WHITE)
		var side_ao: float = float(r.get("side_ao", 0.0))
		var default_v: float = 1.0 - float(r_idx) / float(maxi(1, n_rings - 1))
		v_coords.append(float(r.get("v", default_v)))

		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		for i in range(radial_seg + 1):
			var a: float = (float(i) / float(radial_seg)) * TAU
			var sx: float = sin(a)
			var cz: float = -cos(a)
			var px: float = rx_off + signf(sx) * pow(absf(sx), exp_val) * rx
			var pz: float = rz_off + signf(cz) * pow(absf(cz), exp_val) * rz
			pts.append(xform * Vector3(px, ry, pz))
			var v_col: Color = col.darkened(side_ao * sx * sx) if side_ao > 0.0 else col
			cols.append(v_col)
		ring_pts.append(pts)
		ring_cols.append(cols)

	var r0: Dictionary = rings[0]
	var r_last: Dictionary = rings[n_rings - 1]
	var bot_c: Vector3 = xform * Vector3(float(r0.get("x", 0.0)), float(r0.get("y", 0.0)), float(r0.get("z", 0.0)))
	var top_c: Vector3 = xform * Vector3(float(r_last.get("x", 0.0)), float(r_last.get("y", 0.0)), float(r_last.get("z", 0.0)))
	_emit_ring_strip(st, ring_pts, ring_cols, radial_seg, cap_ends, bot_c, top_c, v_coords)


## Sweeps a rounded strap/bandolier ribbon along a 3D torso-hugging path into a SurfaceTool.
static func add_ribbon_to_st(
	st: SurfaceTool,
	path_pts: PackedVector3Array,
	half_w: float,
	thickness: float,
	col: Color,
	smooth_group: int = 0
) -> void:
	var n_pts: int = path_pts.size()
	if n_pts < 2:
		return
	st.set_smooth_group(smooth_group)
	var segs: int = 8
	var ring_pts: Array = []
	var ring_cols: Array = []
	var v_coords := PackedFloat32Array()

	for i in range(n_pts):
		var p: Vector3 = path_pts[i]
		var prev_p: Vector3 = path_pts[maxi(0, i - 1)]
		var next_p: Vector3 = path_pts[mini(n_pts - 1, i + 1)]
		var tan_v: Vector3 = (next_p - prev_p).normalized()
		if tan_v.length_squared() < 0.0001:
			tan_v = Vector3.UP
		# Blend horizontal torso radial normal with upward shoulder normal above mid-chest
		var out_n := Vector3(p.x, maxf(0.0, (p.y - 0.44) * 1.6), p.z).normalized()
		if out_n.length_squared() < 0.0001:
			out_n = Vector3.FORWARD
		var side_v: Vector3 = tan_v.cross(out_n).normalized()
		if side_v.length_squared() < 0.0001:
			side_v = Vector3.RIGHT
		var up_n: Vector3 = side_v.cross(tan_v).normalized()

		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		for j in range(segs + 1):
			var a: float = (float(j) / float(segs)) * TAU
			var ox: float = cos(a) * half_w
			var oy: float = sin(a) * thickness
			pts.append(p + side_v * ox + up_n * oy)
			cols.append(col.darkened(0.14) if sin(a) < 0.0 else col)
		ring_pts.append(pts)
		ring_cols.append(cols)
		v_coords.append(float(i) / float(n_pts - 1))

	_emit_ring_strip(st, ring_pts, ring_cols, segs, true, path_pts[0], path_pts[n_pts - 1], v_coords)


static func _commit_lofts(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in range(parts.size()):
		var spec: Dictionary = parts[idx]
		var rings: Array = spec.get("rings", [])
		var radial_seg: int = int(spec.get("seg", 14))
		var cap: bool = bool(spec.get("cap", true))
		var xform: Transform3D = spec.get("xform", Transform3D.IDENTITY)
		add_loft_to_st(st, rings, radial_seg, cap, xform, idx)
	st.generate_normals()
	return st.commit()


static func _xform(pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(rot), pos)


static func make_loft(rings: Array[Dictionary], radial_seg: int = 16, cap_ends: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_loft_to_st(st, rings, radial_seg, cap_ends, Transform3D.IDENTITY, 0)
	st.generate_normals()
	return st.commit()


static func add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, parts_list: Array[MeshInstance3D], part_name: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if not part_name.is_empty():
		mi.name = part_name
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.cast_shadow = default_shadow_mode
	parent.add_child(mi)
	parts_list.append(mi)
	return mi


static func make_sculpted_mat(col: Color, tex_key: String = "", roughness: float = 0.68, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%.3f|%.3f" % [col.to_html(true), tex_key, roughness, metallic]
	if _mat_cache.has(key):
		return _mat_cache[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	if col.a < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.vertex_color_use_as_albedo = true
	if not tex_key.is_empty():
		mat.albedo_texture = CartoonAssets.get_texture(tex_key)
		mat.set_meta("tex_key", tex_key)
	mat.roughness = roughness
	mat.metallic = metallic
	_mat_cache[key] = mat
	return mat


## Shared torso sizing profile so coats, belts, collars, and bandoliers align flush per class.
static func get_torso_profile(class_id: int) -> Dictionary:
	if class_id == 1:
		return {"waist_rx": 0.205, "waist_rz": 0.142, "chest_rx": 0.375, "chest_rz": 0.215, "hem_y": -0.10}
	elif class_id == 2:
		return {"waist_rx": 0.170, "waist_rz": 0.128, "chest_rx": 0.295, "chest_rz": 0.172, "hem_y": -0.32}
	elif class_id == 3:
		return {"waist_rx": 0.195, "waist_rz": 0.138, "chest_rx": 0.345, "chest_rz": 0.200, "hem_y": -0.16}
	elif class_id == 4:
		return {"waist_rx": 0.186, "waist_rz": 0.136, "chest_rx": 0.320, "chest_rz": 0.188, "hem_y": -0.14}
	return {"waist_rx": 0.180, "waist_rz": 0.132, "chest_rx": 0.305, "chest_rz": 0.182, "hem_y": -0.18}


static func build_torso_mesh(class_id: int) -> ArrayMesh:
	var k := "torso_%d" % class_id
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var c_hem := Color(0.64, 0.65, 0.72)
	var c_shade := Color(0.82, 0.83, 0.88)
	var c_mid := Color(0.95, 0.95, 0.98)
	var c_lit := Color.WHITE
	if class_id == 1: # Gunner broad barrel chest enveloping deltoid sockets & flared hem over heavy thighs
		return _store_mesh(k, make_loft([
			{"y": -0.10, "rx": 0.306, "rz": 0.178, "p": 2.4, "col": c_hem, "side_ao": 0.12, "v": 1.00},
			{"y": -0.02, "rx": 0.258, "rz": 0.160, "p": 2.4, "col": c_shade, "side_ao": 0.10, "v": 0.88},
			{"y": 0.06, "rx": 0.208, "rz": 0.144, "p": 2.5, "col": c_shade, "side_ao": 0.08, "v": 0.75},
			{"y": 0.24, "rx": 0.298, "rz": 0.188, "p": 2.5, "col": c_mid, "side_ao": 0.12, "v": 0.52},
			{"y": 0.46, "rx": 0.378, "rz": 0.218, "p": 2.4, "col": c_lit, "side_ao": 0.14, "v": 0.24},
			{"y": 0.54, "rx": 0.368, "rz": 0.202, "p": 2.3, "col": c_lit, "side_ao": 0.08, "v": 0.13},
			{"y": 0.60, "rx": 0.265, "rz": 0.158, "p": 2.1, "col": c_lit, "side_ao": 0.04, "v": 0.05},
			{"y": 0.64, "rx": 0.122, "rz": 0.110, "p": 2.0, "col": c_mid.lightened(0.03), "v": 0.00},
		], 20))
	elif class_id == 2: # Commando sharp V-taper & dramatic long flared trenchcoat skirt
		return _store_mesh(k, make_loft([
			{"y": -0.32, "z": 0.015, "rx": 0.298, "rz": 0.228, "p": 2.4, "col": c_hem, "side_ao": 0.14, "v": 1.00},
			{"y": -0.14, "z": 0.008, "rx": 0.244, "rz": 0.184, "p": 2.4, "col": c_shade, "side_ao": 0.10, "v": 0.87},
			{"y": 0.06, "rx": 0.170, "rz": 0.128, "p": 2.4, "col": c_shade, "side_ao": 0.08, "v": 0.74},
			{"y": 0.26, "rx": 0.228, "rz": 0.158, "p": 2.4, "col": c_mid, "side_ao": 0.10, "v": 0.48},
			{"y": 0.48, "rx": 0.298, "rz": 0.175, "p": 2.4, "col": c_lit, "side_ao": 0.12, "v": 0.22},
			{"y": 0.57, "rx": 0.258, "rz": 0.152, "p": 2.2, "col": c_lit, "side_ao": 0.05, "v": 0.10},
			{"y": 0.65, "rx": 0.112, "rz": 0.104, "p": 2.1, "col": c_lit, "v": 0.00},
		], 20))
	elif class_id == 3: # Demolisher heavy armored EOD blast vest with broad chest & padded hem
		return _store_mesh(k, make_loft([
			{"y": -0.16, "z": 0.008, "rx": 0.278, "rz": 0.188, "p": 2.5, "col": c_hem, "side_ao": 0.12, "v": 1.00},
			{"y": -0.04, "rx": 0.236, "rz": 0.162, "p": 2.5, "col": c_shade, "side_ao": 0.10, "v": 0.86},
			{"y": 0.06, "rx": 0.196, "rz": 0.138, "p": 2.5, "col": c_shade, "side_ao": 0.08, "v": 0.74},
			{"y": 0.24, "rx": 0.282, "rz": 0.182, "p": 2.6, "col": c_mid, "side_ao": 0.12, "v": 0.50},
			{"y": 0.45, "rx": 0.348, "rz": 0.204, "p": 2.5, "col": c_lit, "side_ao": 0.14, "v": 0.24},
			{"y": 0.55, "rx": 0.336, "rz": 0.192, "p": 2.4, "col": c_lit, "side_ao": 0.08, "v": 0.12},
			{"y": 0.61, "rx": 0.262, "rz": 0.158, "p": 2.2, "col": c_lit, "side_ao": 0.04, "v": 0.05},
			{"y": 0.65, "rx": 0.126, "rz": 0.114, "p": 2.1, "col": c_lit, "v": 0.00},
		], 20))
	elif class_id == 4: # Field Engineer utility vest & heavy leather workshop apron
		return _store_mesh(k, make_loft([
			{"y": -0.14, "z": 0.006, "rx": 0.244, "rz": 0.178, "p": 2.4, "col": c_hem, "side_ao": 0.12, "v": 1.00},
			{"y": -0.02, "rx": 0.214, "rz": 0.156, "p": 2.4, "col": c_shade, "side_ao": 0.10, "v": 0.86},
			{"y": 0.06, "rx": 0.186, "rz": 0.136, "p": 2.4, "col": c_shade, "side_ao": 0.08, "v": 0.74},
			{"y": 0.23, "rx": 0.254, "rz": 0.172, "p": 2.5, "col": c_mid, "side_ao": 0.10, "v": 0.50},
			{"y": 0.45, "rx": 0.322, "rz": 0.190, "p": 2.5, "col": c_lit, "side_ao": 0.12, "v": 0.24},
			{"y": 0.54, "rx": 0.312, "rz": 0.180, "p": 2.3, "col": c_lit, "side_ao": 0.08, "v": 0.12},
			{"y": 0.60, "rx": 0.252, "rz": 0.152, "p": 2.2, "col": c_lit, "side_ao": 0.04, "v": 0.05},
			{"y": 0.64, "rx": 0.114, "rz": 0.106, "p": 2.1, "col": c_lit, "v": 0.00},
		], 20))
	# Soldier tailored WWII jacket with pinched waist & flared coat tail
	return _store_mesh(k, make_loft([
		{"y": -0.18, "z": 0.006, "rx": 0.238, "rz": 0.178, "p": 2.4, "col": c_hem, "side_ao": 0.12, "v": 1.00},
		{"y": -0.04, "rx": 0.206, "rz": 0.152, "p": 2.4, "col": c_shade, "side_ao": 0.08, "v": 0.86},
		{"y": 0.06, "rx": 0.180, "rz": 0.132, "p": 2.4, "col": c_shade, "side_ao": 0.08, "v": 0.74},
		{"y": 0.22, "rx": 0.238, "rz": 0.165, "p": 2.5, "col": c_mid, "side_ao": 0.10, "v": 0.52},
		{"y": 0.44, "rx": 0.304, "rz": 0.185, "p": 2.5, "col": c_lit, "side_ao": 0.12, "v": 0.24},
		{"y": 0.52, "rx": 0.308, "rz": 0.180, "p": 2.4, "col": c_lit, "side_ao": 0.08, "v": 0.15},
		{"y": 0.59, "rx": 0.248, "rz": 0.150, "p": 2.2, "col": c_lit, "side_ao": 0.04, "v": 0.06},
		{"y": 0.64, "rx": 0.110, "rz": 0.102, "p": 2.0, "col": c_lit, "v": 0.00},
	], 20))


## Builds sculpted neck collar rim and open front V-lapels sealing the neck-to-torso transition.
static func build_collar_lapels_mesh(class_id: int) -> ArrayMesh:
	var k := "collar_%d" % class_id
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var col_rim := Color(0.95, 0.95, 0.98)
	var col_lapel := Color.WHITE
	var collar_top_y: float = 0.740 if class_id == 2 else (0.710 if class_id == 3 else (0.688 if class_id == 4 else (0.662 if class_id == 1 else 0.678)))
	var collar_z: float = 0.012 if class_id == 2 else 0.006
	var collar_rx: float = 0.124 if class_id == 3 else (0.118 if class_id == 1 else (0.114 if class_id == 4 else (0.112 if class_id == 2 else 0.108)))
	var collar_rz: float = 0.114 if class_id == 3 else (0.108 if class_id == 1 else (0.105 if class_id == 4 else (0.104 if class_id == 2 else 0.100)))
	var lapel_z: float = -0.194 if class_id == 1 else (-0.186 if class_id == 3 else (-0.175 if class_id == 4 else (-0.162 if class_id == 2 else -0.168)))
	var lapel_h: float = 0.19 if class_id == 1 else (0.28 if class_id == 2 else (0.21 if class_id == 4 else 0.22))

	var parts: Array[Dictionary] = [
		{
			"seg": 18,
			"rings": [
				{"y": 0.605, "z": 0.002, "rx": collar_rx * 1.06, "rz": collar_rz * 1.06, "p": 2.1, "col": Color(0.66, 0.66, 0.72), "side_ao": 0.16},
				{"y": (0.605 + collar_top_y) * 0.5, "z": collar_z * 0.6, "rx": collar_rx, "rz": collar_rz, "p": 2.1, "col": col_rim},
				{"y": collar_top_y, "z": collar_z, "rx": collar_rx * 0.90, "rz": collar_rz * 0.90, "p": 2.1, "col": col_lapel},
			],
		},
	]
	for side_sign in [-1.0, 1.0]:
		parts.append({
			"seg": 10,
			"xform": _xform(Vector3(side_sign * 0.072, 0.61 - lapel_h * 0.45, lapel_z), Vector3(0.18, 0.0, side_sign * -0.28)),
			"rings": [
				{"y": -lapel_h * 0.5, "rx": 0.018, "rz": 0.014, "p": 2.4, "col": Color(0.84, 0.84, 0.88)},
				{"y": 0.0, "rx": 0.044, "rz": 0.018, "p": 2.6, "col": col_lapel},
				{"y": lapel_h * 0.5, "rx": 0.036, "rz": 0.016, "p": 2.4, "col": col_lapel},
			],
		})
	return _store_mesh("collar_%d" % class_id, _commit_lofts(parts))


## Builds detailed 3D back gear per class (Soldier rucksack+bedroll, Gunner twin canisters, Commando satchel+coat flaps).
static func build_backpack_mesh(class_id: int) -> ArrayMesh:
	var k := "pack_%d" % class_id
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var c_pack := Color(0.95, 0.95, 0.92)
	var c_flap := Color.WHITE
	var c_strap := Color(0.30, 0.22, 0.16)
	var c_brass := Color(0.88, 0.72, 0.28)
	var parts: Array[Dictionary] = []

	if class_id == 1: # Gunner: Heavy twin-canister ammo pack + canvas backing + top roll
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.32, 0.215)),
			"rings": [
				{"y": -0.16, "rx": 0.175, "rz": 0.060, "p": 2.6, "col": Color(0.60, 0.58, 0.52)},
				{"y": 0.00, "rx": 0.188, "rz": 0.068, "p": 2.6, "col": Color(0.72, 0.70, 0.64)},
				{"y": 0.16, "rx": 0.172, "rz": 0.060, "p": 2.5, "col": Color(0.68, 0.66, 0.60)},
			],
		})
		for sx in [-0.105, 0.105]:
			parts.append({
				"seg": 14,
				"xform": _xform(Vector3(sx, 0.30, 0.268)),
				"rings": [
					{"y": -0.15, "rx": 0.072, "rz": 0.072, "p": 2.1, "col": Color(0.42, 0.48, 0.38)},
					{"y": -0.02, "rx": 0.076, "rz": 0.076, "p": 2.1, "col": Color(0.50, 0.56, 0.44)},
					{"y": 0.08, "rx": 0.078, "rz": 0.078, "p": 2.1, "col": Color(0.32, 0.32, 0.34)},
					{"y": 0.15, "rx": 0.068, "rz": 0.068, "p": 2.1, "col": Color(0.56, 0.60, 0.48)},
				],
			})
		for sx in [-0.105, 0.105]:
			parts.append({
				"seg": 8,
				"xform": _xform(Vector3(sx, 0.44, 0.145), Vector3(0.48, 0.0, 0.0)),
				"rings": [
					{"y": -0.08, "rx": 0.018, "rz": 0.010, "p": 2.2, "col": Color(0.20, 0.15, 0.10)},
					{"y": 0.08, "rx": 0.018, "rz": 0.010, "p": 2.2, "col": Color(0.28, 0.21, 0.15)},
				],
			})
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(0.0, 0.50, 0.235), Vector3(0.0, 0.0, PI * 0.5)),
			"rings": [
				{"y": -0.17, "rx": 0.048, "rz": 0.048, "p": 2.0, "col": Color(0.74, 0.70, 0.58)},
				{"y": 0.17, "rx": 0.048, "rz": 0.048, "p": 2.0, "col": Color(0.78, 0.74, 0.62)},
			],
		})
	elif class_id == 2: # Commando: Hip courier leather satchel & clasp (rear coat pleat rendered in cloth)
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(-0.145, 0.08, 0.175), Vector3(0.08, -0.22, 0.14)),
			"rings": [
				{"y": -0.095, "rx": 0.105, "rz": 0.052, "p": 2.6, "col": Color(0.68, 0.64, 0.58)},
				{"y": 0.030, "rx": 0.112, "rz": 0.058, "p": 2.6, "col": Color(0.92, 0.88, 0.84)},
				{"y": 0.095, "rx": 0.102, "rz": 0.052, "p": 2.5, "col": Color.WHITE},
			],
		})
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(-0.145, 0.06, 0.228), Vector3(0.08, -0.22, 0.14)),
			"rings": [
				{"y": -0.022, "rx": 0.022, "rz": 0.012, "p": 2.4, "col": Color(1.0, 0.88, 0.42)},
				{"y": 0.022, "rx": 0.022, "rz": 0.012, "p": 2.4, "col": Color(1.0, 0.92, 0.50)},
			],
		})
	elif class_id == 3: # Demolisher: Pressurized fuel tank + spare explosive drum + brass valves
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.31, 0.210)),
			"rings": [
				{"y": -0.16, "rx": 0.165, "rz": 0.056, "p": 2.6, "col": Color(0.55, 0.55, 0.58)},
				{"y": 0.00, "rx": 0.175, "rz": 0.062, "p": 2.6, "col": Color(0.68, 0.68, 0.70)},
				{"y": 0.16, "rx": 0.162, "rz": 0.056, "p": 2.5, "col": Color(0.62, 0.62, 0.65)},
			],
		})
		parts.append({
			"seg": 16,
			"xform": _xform(Vector3(-0.075, 0.31, 0.278)),
			"rings": [
				{"y": -0.17, "rx": 0.068, "rz": 0.068, "p": 2.0, "col": Color(0.76, 0.22, 0.14)},
				{"y": 0.00, "rx": 0.080, "rz": 0.080, "p": 2.0, "col": Color(0.88, 0.26, 0.16)},
				{"y": 0.15, "rx": 0.076, "rz": 0.076, "p": 2.0, "col": Color(0.76, 0.22, 0.14)},
				{"y": 0.19, "rx": 0.042, "rz": 0.042, "p": 2.0, "col": c_brass},
			],
		})
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.095, 0.29, 0.270)),
			"rings": [
				{"y": -0.14, "rx": 0.064, "rz": 0.064, "p": 2.1, "col": Color(0.32, 0.36, 0.28)},
				{"y": 0.02, "rx": 0.068, "rz": 0.068, "p": 2.1, "col": Color(0.42, 0.46, 0.34)},
				{"y": 0.14, "rx": 0.058, "rz": 0.058, "p": 2.0, "col": c_brass},
			],
		})
		for sx in [-0.095, 0.095]:
			parts.append({
				"seg": 8,
				"xform": _xform(Vector3(sx, 0.44, 0.145), Vector3(0.48, 0.0, 0.0)),
				"rings": [
					{"y": -0.08, "rx": 0.018, "rz": 0.010, "p": 2.2, "col": c_strap},
					{"y": 0.08, "rx": 0.018, "rz": 0.010, "p": 2.2, "col": c_strap.lightened(0.15)},
				],
			})
	elif class_id == 4: # Field Engineer: Twin compact welding gas cylinders + brass gauge + canvas tool roll
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.30, 0.200)),
			"rings": [
				{"y": -0.15, "rx": 0.150, "rz": 0.052, "p": 2.5, "col": Color(0.46, 0.44, 0.38)},
				{"y": 0.00, "rx": 0.158, "rz": 0.058, "p": 2.5, "col": Color(0.56, 0.52, 0.44)},
				{"y": 0.15, "rx": 0.148, "rz": 0.052, "p": 2.4, "col": Color(0.46, 0.44, 0.38)},
			],
		})
		for sx in [-0.078, 0.078]:
			var cyl_col: Color = Color(0.22, 0.48, 0.68) if sx < 0.0 else Color(0.72, 0.36, 0.16)
			parts.append({
				"seg": 14,
				"xform": _xform(Vector3(sx, 0.32, 0.264)),
				"rings": [
					{"y": -0.16, "rx": 0.054, "rz": 0.054, "p": 2.0, "col": cyl_col.darkened(0.18)},
					{"y": 0.02, "rx": 0.058, "rz": 0.058, "p": 2.0, "col": cyl_col},
					{"y": 0.14, "rx": 0.050, "rz": 0.050, "p": 2.0, "col": cyl_col.darkened(0.10)},
					{"y": 0.18, "rx": 0.024, "rz": 0.024, "p": 2.0, "col": c_brass},
				],
			})
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(0.0, 0.505, 0.220), Vector3(0.0, 0.0, PI * 0.5)),
			"rings": [
				{"y": -0.155, "rx": 0.048, "rz": 0.048, "p": 2.0, "col": Color(0.36, 0.32, 0.24)},
				{"y": 0.0, "rx": 0.052, "rz": 0.052, "p": 2.0, "col": c_brass},
				{"y": 0.155, "rx": 0.048, "rz": 0.048, "p": 2.0, "col": Color(0.36, 0.32, 0.24)},
			],
		})
	else: # Soldier: WWII field rucksack + top bedroll cylinder + leather straps
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.31, 0.205)),
			"rings": [
				{"y": -0.15, "rx": 0.142, "rz": 0.075, "p": 2.6, "col": Color(0.84, 0.84, 0.80)},
				{"y": 0.04, "rx": 0.152, "rz": 0.085, "p": 2.6, "col": c_pack},
				{"y": 0.15, "rx": 0.146, "rz": 0.080, "p": 2.5, "col": c_flap},
			],
		})
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(0.0, 0.41, 0.215)),
			"rings": [
				{"y": -0.055, "rx": 0.158, "rz": 0.088, "p": 2.6, "col": c_pack},
				{"y": 0.055, "rx": 0.152, "rz": 0.086, "p": 2.5, "col": c_flap},
			],
		})
		for sx in [-0.075, 0.075]:
			parts.append({
				"seg": 8,
				"xform": _xform(Vector3(sx, 0.32, 0.292)),
				"rings": [
					{"y": -0.11, "rx": 0.020, "rz": 0.012, "p": 2.4, "col": Color(0.20, 0.14, 0.09)},
					{"y": -0.02, "rx": 0.022, "rz": 0.014, "p": 2.4, "col": c_brass},
					{"y": 0.11, "rx": 0.020, "rz": 0.012, "p": 2.4, "col": Color(0.20, 0.14, 0.09)},
				],
			})
		for sx in [-0.095, 0.095]:
			parts.append({
				"seg": 8,
				"xform": _xform(Vector3(sx, 0.42, 0.135), Vector3(0.52, 0.0, 0.0)),
				"rings": [
					{"y": -0.08, "rx": 0.016, "rz": 0.010, "p": 2.2, "col": Color(0.20, 0.14, 0.09)},
					{"y": 0.08, "rx": 0.016, "rz": 0.010, "p": 2.2, "col": Color(0.30, 0.22, 0.15)},
				],
			})
		parts.append({
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.515, 0.202), Vector3(0.0, 0.0, PI * 0.5)),
			"rings": [
				{"y": -0.175, "rx": 0.056, "rz": 0.056, "p": 2.0, "col": Color(0.74, 0.76, 0.66)},
				{"y": 0.0, "rx": 0.060, "rz": 0.060, "p": 2.0, "col": Color(0.84, 0.86, 0.74)},
				{"y": 0.175, "rx": 0.056, "rz": 0.056, "p": 2.0, "col": Color(0.74, 0.76, 0.66)},
			],
		})
	return _store_mesh("pack_%d" % class_id, _commit_lofts(parts))


## Builds rear Commando trenchcoat box-pleat vent flap flush along the flared coat tail (rendered in coat cloth).
static func build_coat_tail_flap_mesh() -> ArrayMesh:
	if _mesh_cache.has("coat_flap"):
		return _mesh_cache["coat_flap"] as ArrayMesh
	return _store_mesh("coat_flap", _commit_lofts([
		{
			"seg": 10,
			"xform": _xform(Vector3(0.0, -0.12, 0.192), Vector3(-0.295, 0.0, 0.0)),
			"rings": [
				{"y": -0.18, "rx": 0.070, "rz": 0.016, "p": 2.5, "col": Color(0.84, 0.84, 0.88)},
				{"y": 0.16, "rx": 0.042, "rz": 0.014, "p": 2.4, "col": Color(0.96, 0.96, 0.98)},
			],
		},
	]))


## Builds a sculpted leather utility pouch with overhanging lid flap and brass stud.
static func build_belt_pouch_mesh() -> ArrayMesh:
	if _mesh_cache.has("belt_pouch"):
		return _mesh_cache["belt_pouch"] as ArrayMesh
	return _store_mesh("belt_pouch", _commit_lofts([
		{
			"seg": 12,
			"rings": [
				{"y": -0.055, "rx": 0.054, "rz": 0.036, "p": 2.6, "col": Color(0.82, 0.80, 0.78)},
				{"y": 0.015, "rx": 0.058, "rz": 0.038, "p": 2.6, "col": Color(0.94, 0.92, 0.90)},
				{"y": 0.055, "rx": 0.054, "rz": 0.035, "p": 2.5, "col": Color.WHITE},
			],
		},
		{
			"seg": 8,
			"xform": _xform(Vector3(0.0, 0.006, -0.038)),
			"rings": [
				{"y": -0.012, "rx": 0.014, "rz": 0.008, "p": 2.2, "col": Color(0.92, 0.76, 0.28)},
				{"y": 0.012, "rx": 0.014, "rz": 0.008, "p": 2.2, "col": Color(0.98, 0.84, 0.36)},
			],
		},
	]))


## Builds a tailored waist belt matching each class's waist contour.
static func build_waist_belt_mesh(class_id: int) -> ArrayMesh:
	var k := "belt_%d" % class_id
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var prof: Dictionary = get_torso_profile(class_id)
	var wrx: float = float(prof["waist_rx"]) + 0.012
	var wrz: float = float(prof["waist_rz"]) + 0.012
	return _store_mesh(k, make_loft([
		{"y": 0.045, "rx": wrx, "rz": wrz, "p": 2.4, "col": Color(0.84, 0.84, 0.86)},
		{"y": 0.075, "rx": wrx + 0.004, "rz": wrz + 0.004, "p": 2.4, "col": Color.WHITE},
		{"y": 0.105, "rx": wrx, "rz": wrz, "p": 2.4, "col": Color(0.90, 0.90, 0.92)},
	], 20))


## Builds a gleaming sculpted front belt buckle plate.
static func build_buckle_mesh() -> ArrayMesh:
	if _mesh_cache.has("buckle"):
		return _mesh_cache["buckle"] as ArrayMesh
	return _store_mesh("buckle", make_loft([
		{"y": -0.036, "rx": 0.048, "rz": 0.014, "p": 2.8, "col": Color(0.88, 0.88, 0.92)},
		{"y": 0.000, "rx": 0.052, "rz": 0.016, "p": 2.8, "col": Color.WHITE},
		{"y": 0.036, "rx": 0.048, "rz": 0.014, "p": 2.8, "col": Color.WHITE},
	], 12))


## Builds snug chest/back leather Y-suspenders (Soldier) or diagonal ammo bandolier (Gunner/Commando).
static func build_bandolier_mesh(class_id: int) -> ArrayMesh:
	var k := "band_%d" % class_id
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var prof: Dictionary = get_torso_profile(class_id)
	var crx: float = float(prof["chest_rx"])
	var crz: float = float(prof["chest_rz"])
	var wrx: float = float(prof["waist_rx"])
	var wrz: float = float(prof["waist_rz"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	if class_id == 0: # Soldier Y-suspenders over left & right shoulders (front to back)
		for sx in [-1.0, 1.0]:
			var pts := PackedVector3Array([
				Vector3(sx * wrx * 0.56, 0.09, -(wrz + 0.010)),
				Vector3(sx * crx * 0.42, 0.32, -(crz * 0.94 + 0.012)),
				Vector3(sx * crx * 0.46, 0.51, -(crz * 0.76 + 0.014)),
				Vector3(sx * crx * 0.48, 0.595, 0.0),
				Vector3(sx * crx * 0.46, 0.51, crz * 0.76 + 0.014),
				Vector3(sx * crx * 0.32, 0.32, crz * 0.92 + 0.014),
				Vector3(sx * wrx * 0.30, 0.09, wrz + 0.010),
			])
			add_ribbon_to_st(st, pts, 0.022, 0.009, Color(0.94, 0.92, 0.90), int(sx + 2))
	else: # Gunner / Commando diagonal chest-to-hip bandolier loop
		var mid_rx: float = lerpf(wrx, crx, 0.45)
		var mid_rz: float = lerpf(wrz, crz, 0.45)
		var pts := PackedVector3Array([
			Vector3(-crx * 0.45, 0.585, 0.0),
			Vector3(-crx * 0.36, 0.50, -(crz * 0.90 + 0.018)),
			Vector3(-crx * 0.08, 0.34, -(crz * 0.98 + 0.018)),
			Vector3(mid_rx * 0.48, 0.16, -(mid_rz * 0.90 + 0.018)),
			Vector3(wrx + 0.016, 0.09, 0.0),
			Vector3(mid_rx * 0.48, 0.16, mid_rz * 0.90 + 0.018),
			Vector3(-crx * 0.08, 0.34, crz * 0.98 + 0.018),
			Vector3(-crx * 0.36, 0.50, crz * 0.90 + 0.018),
			Vector3(-crx * 0.45, 0.585, 0.0),
		])
		add_ribbon_to_st(st, pts, 0.030 if (class_id == 1 or class_id == 3) else 0.024, 0.011, Color(0.90, 0.88, 0.86), 0)
		if class_id == 1: # Brass ammo shells studded along Gunner chest bandolier
			var shell_col := Color(0.95, 0.78, 0.28)
			for t in [0.16, 0.23, 0.30, 0.37]:
				var idx: float = t * float(pts.size() - 1)
				var i0: int = clampi(int(idx), 0, pts.size() - 2)
				var sp: Vector3 = pts[i0].lerp(pts[i0 + 1], idx - float(i0))
				add_loft_to_st(st, [
					{"y": -0.022, "rx": 0.011, "rz": 0.011, "p": 2.0, "col": shell_col},
					{"y": 0.022, "rx": 0.010, "rz": 0.010, "p": 2.0, "col": shell_col},
				], 8, true, _xform(sp + Vector3(0.0, 0.0, -0.012), Vector3(0.0, 0.0, 0.62)), 10 + i0)
		elif class_id == 3: # Chunky 40mm grenade cartridges along Demolisher chest bandolier
			var gren_body := Color(0.30, 0.42, 0.24)
			var gren_cap := Color(0.94, 0.74, 0.22)
			for t in [0.15, 0.24, 0.33, 0.41]:
				var idx: float = t * float(pts.size() - 1)
				var i0: int = clampi(int(idx), 0, pts.size() - 2)
				var sp: Vector3 = pts[i0].lerp(pts[i0 + 1], idx - float(i0))
				add_loft_to_st(st, [
					{"y": -0.028, "rx": 0.019, "rz": 0.019, "p": 2.0, "col": gren_body},
					{"y": 0.012, "rx": 0.019, "rz": 0.019, "p": 2.0, "col": gren_body},
					{"y": 0.028, "rx": 0.016, "rz": 0.016, "p": 2.0, "col": gren_cap},
				], 10, true, _xform(sp + Vector3(0.0, 0.0, -0.016), Vector3(0.0, 0.0, 0.58)), 20 + i0)

		elif class_id == 4: # Wrench & brass gauge tool harness along Engineer chest strap
			var tool_steel := Color(0.72, 0.76, 0.82)
			var brass_gauge := Color(0.92, 0.72, 0.24)
			for t in [0.16, 0.26, 0.36]:
				var idx: float = t * float(pts.size() - 1)
				var i0: int = clampi(int(idx), 0, pts.size() - 2)
				var sp: Vector3 = pts[i0].lerp(pts[i0 + 1], idx - float(i0))
				add_loft_to_st(st, [
					{"y": -0.024, "rx": 0.013, "rz": 0.013, "p": 2.2, "col": tool_steel if t > 0.20 else brass_gauge},
					{"y": 0.024, "rx": 0.015, "rz": 0.015, "p": 2.2, "col": tool_steel},
				], 8, true, _xform(sp + Vector3(0.0, 0.0, -0.014), Vector3(0.0, 0.0, 0.52)), 30 + i0)

	st.generate_normals()
	return _store_mesh("band_%d" % class_id, st.commit())


static func build_epaulet_mesh(is_pauldron: bool = false) -> ArrayMesh:
	var k := "epaulet_%s" % str(is_pauldron)
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	if is_pauldron:
		return _store_mesh(k, make_loft([
			{"y": -0.032, "rx": 0.095, "rz": 0.125, "p": 2.4, "col": Color(0.84, 0.84, 0.88)},
			{"y": 0.012, "rx": 0.098, "rz": 0.122, "p": 2.4, "col": Color.WHITE},
			{"y": 0.036, "rx": 0.068, "rz": 0.088, "p": 2.2, "col": Color.WHITE},
		], 14))
	return _store_mesh(k, _commit_lofts([
		{
			"seg": 10,
			"rings": [
				{"y": 0.0, "rx": 0.038, "rz": 0.088, "p": 2.5, "col": Color(0.90, 0.90, 0.94)},
				{"y": 0.018, "rx": 0.034, "rz": 0.082, "p": 2.4, "col": Color.WHITE},
			],
		},
		{
			"seg": 8,
			"xform": _xform(Vector3(0.0, 0.020, -0.045)),
			"rings": [
				{"y": -0.005, "rx": 0.012, "rz": 0.012, "p": 2.0, "col": Color(0.96, 0.80, 0.28)},
				{"y": 0.008, "rx": 0.011, "rz": 0.011, "p": 2.0, "col": Color(1.0, 0.86, 0.36)},
			],
		},
	]))


static func build_rolled_sleeve_cap_mesh(r_top: float) -> ArrayMesh:
	var k := "rcap_%.4f" % r_top
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, make_loft([
		{"y": -0.072, "rx": r_top * 1.12, "rz": r_top * 1.10, "p": 2.1, "col": Color(0.90, 0.90, 0.92)},
		{"y": -0.036, "rx": r_top * 1.15, "rz": r_top * 1.12, "p": 2.1, "col": Color.WHITE},
		{"y": 0.010, "rx": r_top * 1.06, "rz": r_top * 1.04, "p": 2.0, "col": Color.WHITE},
		{"y": 0.056, "rx": r_top * 0.56, "rz": r_top * 0.56, "p": 2.0, "col": Color(0.94, 0.94, 0.96)},
	], 14))


static func build_cuff_mesh(r_cuff: float) -> ArrayMesh:
	var k := "cuff_%.4f" % r_cuff
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, make_loft([
		{"y": -0.022, "rx": r_cuff * 1.12, "rz": r_cuff * 1.10, "p": 2.2, "col": Color(0.86, 0.86, 0.90)},
		{"y": 0.000, "rx": r_cuff * 1.16, "rz": r_cuff * 1.14, "p": 2.2, "col": Color.WHITE},
		{"y": 0.022, "rx": r_cuff * 1.10, "rz": r_cuff * 1.08, "p": 2.2, "col": Color(0.94, 0.94, 0.96)},
	], 14))


static func build_scarf_mesh() -> ArrayMesh:
	if _mesh_cache.has("scarf"):
		return _mesh_cache["scarf"] as ArrayMesh
	return _store_mesh("scarf", _commit_lofts([
		{
			"seg": 16,
			"rings": [
				{"y": 0.588, "rx": 0.128, "rz": 0.122, "p": 2.1, "col": Color(0.84, 0.84, 0.86)},
				{"y": 0.632, "rx": 0.132, "rz": 0.124, "p": 2.1, "col": Color.WHITE},
				{"y": 0.678, "rx": 0.100, "rz": 0.096, "p": 2.1, "col": Color(0.94, 0.94, 0.96)},
			],
		},
		{
			"seg": 10,
			"xform": _xform(Vector3(0.0, 0.545, -0.142), Vector3(0.24, 0.0, 0.08)),
			"rings": [
				{"y": -0.065, "rx": 0.056, "rz": 0.018, "p": 2.4, "col": Color(0.84, 0.84, 0.86)},
				{"y": 0.045, "rx": 0.046, "rz": 0.024, "p": 2.2, "col": Color.WHITE},
			],
		},
	]))


static func build_head_mesh() -> ArrayMesh:
	if _mesh_cache.has("head"):
		return _mesh_cache["head"] as ArrayMesh
	# Smooth sculpted cartoon cranium with chiseled square jaw, cheekbones & brow ridge
	return _store_mesh("head", make_loft([
		{"y": 0.000, "rx": 0.082, "rz": 0.078, "p": 2.0, "col": Color(0.84, 0.80, 0.78), "v": 1.00},
		{"y": 0.080, "rx": 0.088, "rz": 0.084, "p": 2.1, "col": Color(0.90, 0.86, 0.84), "v": 0.80},
		{"y": 0.115, "z": -0.018, "rx": 0.118, "rz": 0.122, "p": 3.2, "col": Color(0.95, 0.92, 0.90), "v": 0.68},
		{"y": 0.200, "z": -0.012, "rx": 0.128, "rz": 0.128, "p": 2.6, "col": Color.WHITE, "v": 0.48},
		{"y": 0.275, "z": -0.014, "rx": 0.126, "rz": 0.132, "p": 2.4, "col": Color.WHITE, "v": 0.30},
		{"y": 0.345, "z": 0.002, "rx": 0.112, "rz": 0.120, "p": 2.0, "col": Color.WHITE, "v": 0.14},
		{"y": 0.395, "z": 0.008, "rx": 0.068, "rz": 0.072, "p": 2.0, "col": Color.WHITE, "v": 0.00},
	], 20))


static func build_hair_cap_mesh() -> ArrayMesh:
	if _mesh_cache.has("hair_cap"):
		return _mesh_cache["hair_cap"] as ArrayMesh
	# Full temple/brow hairline & nape hair wrap visible under hats without exposed bald forehead
	return _store_mesh("hair_cap", _commit_lofts([
		{
			"seg": 18,
			"rings": [
				{"y": 0.145, "z": 0.048, "rx": 0.112, "rz": 0.096, "p": 2.2, "col": Color(0.84, 0.84, 0.84)},
				{"y": 0.220, "z": 0.016, "rx": 0.132, "rz": 0.124, "p": 2.2, "col": Color(0.94, 0.94, 0.94)},
				{"y": 0.292, "z": -0.008, "rx": 0.130, "rz": 0.136, "p": 2.3, "col": Color.WHITE},
				{"y": 0.352, "z": 0.000, "rx": 0.118, "rz": 0.126, "p": 2.0, "col": Color.WHITE},
				{"y": 0.402, "z": 0.006, "rx": 0.076, "rz": 0.080, "p": 2.0, "col": Color.WHITE},
			],
		},
		{
			"seg": 10,
			"xform": _xform(Vector3(0.0, 0.300, -0.134), Vector3(-0.34, 0.0, 0.0)),
			"rings": [
				{"y": -0.018, "rx": 0.104, "rz": 0.020, "p": 2.4, "col": Color(0.92, 0.92, 0.92)},
				{"y": 0.022, "rx": 0.112, "rz": 0.022, "p": 2.4, "col": Color.WHITE},
			],
		},
	]))


static func build_ear_mesh() -> ArrayMesh:
	if _mesh_cache.has("ear"):
		return _mesh_cache["ear"] as ArrayMesh
	return _store_mesh("ear", make_loft([
		{"y": -0.036, "rx": 0.018, "rz": 0.026, "p": 2.1, "col": Color(0.88, 0.84, 0.82)},
		{"y": 0.0, "rx": 0.024, "rz": 0.034, "p": 2.1, "col": Color.WHITE},
		{"y": 0.036, "rx": 0.016, "rz": 0.024, "p": 2.1, "col": Color.WHITE},
	], 10))


static func build_nose_mesh() -> ArrayMesh:
	if _mesh_cache.has("nose"):
		return _mesh_cache["nose"] as ArrayMesh
	return _store_mesh("nose", make_loft([
		{"y": -0.024, "z": -0.006, "rx": 0.024, "rz": 0.026, "p": 2.3, "col": Color(0.94, 0.88, 0.86)},
		{"y": 0.006, "z": -0.002, "rx": 0.020, "rz": 0.022, "p": 2.2, "col": Color.WHITE},
		{"y": 0.036, "z": 0.004, "rx": 0.013, "rz": 0.015, "p": 2.0, "col": Color.WHITE},
	], 10))


static func build_eyes_mesh() -> ArrayMesh:
	if _mesh_cache.has("eyes"):
		return _mesh_cache["eyes"] as ArrayMesh
	var parts: Array[Dictionary] = []
	for sx in [-1.0, 1.0]:
		parts.append({
			"seg": 10,
			"xform": _xform(Vector3(sx * 0.044, 0.0, 0.0), Vector3(0.0, sx * -0.16, 0.0)),
			"rings": [
				{"y": -0.016, "rx": 0.022, "rz": 0.014, "p": 2.2, "col": Color(0.96, 0.96, 0.98)},
				{"y": 0.0, "rx": 0.025, "rz": 0.016, "p": 2.2, "col": Color.WHITE},
				{"y": 0.016, "rx": 0.020, "rz": 0.013, "p": 2.2, "col": Color(0.94, 0.94, 0.96)},
			],
		})
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(sx * 0.043, -0.001, -0.013), Vector3(0.0, sx * -0.16, 0.0)),
			"rings": [
				{"y": -0.009, "rx": 0.011, "rz": 0.006, "p": 2.0, "col": Color(0.12, 0.14, 0.18)},
				{"y": 0.009, "rx": 0.011, "rz": 0.006, "p": 2.0, "col": Color(0.16, 0.18, 0.22)},
			],
		})
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(sx * 0.045, 0.022, -0.008), Vector3(0.0, sx * -0.14, sx * -0.14)),
			"rings": [
				{"y": -0.006, "rx": 0.030, "rz": 0.013, "p": 2.5, "col": Color(0.28, 0.18, 0.12)},
				{"y": 0.006, "rx": 0.028, "rz": 0.012, "p": 2.5, "col": Color(0.36, 0.24, 0.16)},
			],
		})
	return _store_mesh("eyes", _commit_lofts(parts))


## Builds metal-rimmed aviator sunglasses with bridge bar and ear temples.
static func build_sunglasses_mesh() -> ArrayMesh:
	if _mesh_cache.has("shades"):
		return _mesh_cache["shades"] as ArrayMesh
	var frame_col := Color(0.84, 0.78, 0.64)
	var lens_col := Color(0.26, 0.26, 0.30)
	var parts: Array[Dictionary] = [
		{
			"seg": 8,
			"xform": _xform(Vector3(0.0, 0.014, -0.006), Vector3(0.0, 0.0, PI * 0.5)),
			"rings": [
				{"y": -0.055, "rx": 0.006, "rz": 0.006, "p": 2.0, "col": frame_col},
				{"y": 0.055, "rx": 0.006, "rz": 0.006, "p": 2.0, "col": frame_col},
			],
		},
	]
	for sx in [-1.0, 1.0]:
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(sx * 0.050, -0.002, -0.005), Vector3(0.0, 0.0, sx * 0.08)),
			"rings": [
				{"y": -0.022, "rx": 0.032, "rz": 0.013, "p": 2.5, "col": lens_col},
				{"y": 0.002, "rx": 0.042, "rz": 0.014, "p": 2.7, "col": lens_col.lightened(0.08)},
				{"y": 0.018, "rx": 0.040, "rz": 0.013, "p": 2.6, "col": frame_col},
			],
		})
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(sx * 0.116, 0.006, 0.072), Vector3(PI * 0.5, 0.0, 0.0)),
			"rings": [
				{"y": -0.075, "rx": 0.005, "rz": 0.005, "p": 2.0, "col": frame_col},
				{"y": 0.075, "rx": 0.005, "rz": 0.005, "p": 2.0, "col": frame_col},
			],
		})
	return _store_mesh("shades", _commit_lofts(parts))


## Builds sculpted cartoon facial hair: 0 = full beard+mustache, 1 = chevron mustache, 2 = goatee.
static func build_beard_mesh(style: int = 0) -> ArrayMesh:
	var k := "beard_%d" % style
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var parts: Array[Dictionary] = []
	var c_dark := Color(0.84, 0.84, 0.86)
	var c_lit := Color.WHITE

	if style == 0: # Full sculpted Royal Soldier beard + handlebar mustache
		parts.append({
			"seg": 16,
			"xform": _xform(Vector3(0.0, -0.020, 0.088)),
			"rings": [
				{"y": -0.068, "rx": 0.094, "rz": 0.096, "p": 2.6, "col": c_dark},
				{"y": -0.018, "rx": 0.132, "rz": 0.120, "p": 3.0, "col": c_lit},
				{"y": 0.024, "rx": 0.136, "rz": 0.118, "p": 3.0, "col": c_lit},
			],
		})
	elif style == 2: # Rugged Gunner chin goatee
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(0.0, -0.032, 0.008)),
			"rings": [
				{"y": -0.036, "rx": 0.044, "rz": 0.034, "p": 2.4, "col": c_dark},
				{"y": 0.014, "rx": 0.056, "rz": 0.038, "p": 2.5, "col": c_lit},
			],
		})

	# Handlebar / chevron mustache wings across upper lip
	for sx in [-1.0, 1.0]:
		parts.append({
			"seg": 10,
			"xform": _xform(Vector3(sx * 0.030, 0.018, -0.006), Vector3(0.0, 0.0, sx * -0.26)),
			"rings": [
				{"y": -0.016, "rx": 0.038, "rz": 0.018, "p": 2.4, "col": c_dark},
				{"y": 0.014, "rx": 0.042, "rz": 0.020, "p": 2.3, "col": c_lit},
			],
		})
	return _store_mesh("beard_%d" % style, _commit_lofts(parts))


## Builds domed M1 steel helmet (is_royal=true) or flared Stahlhelm (is_royal=false) with strap.
static func build_helmet_mesh(is_royal: bool) -> ArrayMesh:
	var k := "helmet_%s" % str(is_royal)
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var shell_col := Color(0.34, 0.40, 0.24) if is_royal else Color(0.30, 0.32, 0.36)
	var c_band := shell_col.darkened(0.18)
	var c_rim := shell_col.darkened(0.28)
	var c_flange := shell_col.darkened(0.36)
	var c_strap := Color(0.30, 0.21, 0.13)
	var parts: Array[Dictionary] = []

	if is_royal:
		parts.append({
			"seg": 20,
			"rings": [
				{"y": -0.022, "z": -0.004, "rx": 0.158, "rz": 0.170, "p": 2.2, "col": c_flange},
				{"y": -0.012, "z": -0.002, "rx": 0.154, "rz": 0.166, "p": 2.2, "col": c_rim},
				{"y": 0.015, "rx": 0.144, "rz": 0.156, "p": 2.1, "col": c_band},
				{"y": 0.045, "rx": 0.146, "rz": 0.158, "p": 2.1, "col": shell_col},
				{"y": 0.108, "rx": 0.128, "rz": 0.138, "p": 2.0, "col": shell_col.lightened(0.06)},
				{"y": 0.162, "rx": 0.068, "rz": 0.074, "p": 2.0, "col": shell_col.lightened(0.08)},
			],
		})
	else:
		parts.append({
			"seg": 20,
			"rings": [
				{"y": -0.032, "z": 0.018, "rx": 0.166, "rz": 0.178, "p": 2.3, "col": c_flange},
				{"y": -0.018, "z": 0.012, "rx": 0.160, "rz": 0.170, "p": 2.3, "col": c_rim},
				{"y": 0.012, "rx": 0.144, "rz": 0.154, "p": 2.2, "col": shell_col},
				{"y": 0.078, "rx": 0.134, "rz": 0.142, "p": 2.1, "col": shell_col.lightened(0.05)},
				{"y": 0.152, "rx": 0.072, "rz": 0.078, "p": 2.0, "col": shell_col.lightened(0.08)},
			],
		})

	for sx in [-1.0, 1.0]:
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(sx * 0.140, -0.095, -0.012), Vector3(0.0, 0.0, sx * -0.10)),
			"rings": [
				{"y": -0.090, "rx": 0.011, "rz": 0.013, "p": 2.2, "col": c_strap},
				{"y": 0.090, "rx": 0.012, "rz": 0.014, "p": 2.2, "col": c_strap},
			],
		})
	return _store_mesh("helmet_%s" % str(is_royal), _commit_lofts(parts))


## Builds Demolisher EOD blast helmet with armored brow visor guard.
static func build_visor_helmet_mesh(is_royal: bool) -> ArrayMesh:
	var k := "visor_helmet_%s" % str(is_royal)
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var shell_col := Color(0.38, 0.42, 0.28) if is_royal else Color(0.26, 0.28, 0.32)
	var visor_col := Color(0.24, 0.26, 0.30) if is_royal else Color(0.18, 0.20, 0.24)
	var accent_col := Color(0.88, 0.62, 0.18) if is_royal else Color(0.78, 0.18, 0.16)
	var parts: Array[Dictionary] = [
		{
			"seg": 20,
			"rings": [
				{"y": -0.025, "z": 0.005, "rx": 0.164, "rz": 0.176, "p": 2.2, "col": shell_col.darkened(0.25)},
				{"y": 0.018, "rx": 0.154, "rz": 0.166, "p": 2.1, "col": shell_col},
				{"y": 0.095, "rx": 0.138, "rz": 0.148, "p": 2.0, "col": shell_col.lightened(0.06)},
				{"y": 0.162, "rx": 0.072, "rz": 0.078, "p": 2.0, "col": shell_col.lightened(0.08)},
			],
		},
		{
			"seg": 14,
			"xform": _xform(Vector3(0.0, 0.008, -0.142), Vector3(-0.22, 0.0, 0.0)),
			"rings": [
				{"y": -0.028, "rx": 0.126, "rz": 0.026, "p": 2.5, "col": visor_col},
				{"y": 0.008, "rx": 0.134, "rz": 0.030, "p": 2.5, "col": accent_col},
				{"y": 0.032, "rx": 0.122, "rz": 0.024, "p": 2.4, "col": visor_col},
			],
		},
	]
	for sx in [-1.0, 1.0]:
		parts.append({
			"seg": 8,
			"xform": _xform(Vector3(sx * 0.150, -0.055, -0.012)),
			"rings": [
				{"y": -0.045, "rx": 0.024, "rz": 0.034, "p": 2.4, "col": visor_col},
				{"y": 0.045, "rx": 0.024, "rz": 0.034, "p": 2.4, "col": accent_col},
			],
		})
	return _store_mesh(k, _commit_lofts(parts))


## Builds Field Engineer mechanic cap with brass-rimmed welding goggles resting on brow.
static func build_engineer_cap_mesh(is_royal: bool) -> ArrayMesh:
	var k := "ecap_%s" % str(is_royal)
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var cap_col := Color(0.32, 0.40, 0.28) if is_royal else Color(0.24, 0.26, 0.30)
	var brim_col := Color(0.16, 0.14, 0.12)
	var brass_col := Color(0.86, 0.66, 0.24)
	var lens_col := Color(0.22, 0.82, 0.92)
	var parts: Array[Dictionary] = [
		{
			"seg": 18,
			"rings": [
				{"y": -0.018, "rx": 0.156, "rz": 0.168, "p": 2.2, "col": cap_col.darkened(0.20)},
				{"y": 0.032, "rx": 0.150, "rz": 0.162, "p": 2.1, "col": cap_col},
				{"y": 0.098, "rx": 0.132, "rz": 0.144, "p": 2.0, "col": cap_col.lightened(0.08)},
				{"y": 0.132, "rx": 0.072, "rz": 0.082, "p": 2.0, "col": cap_col.lightened(0.10)},
			],
		},
		{
			"seg": 12,
			"xform": _xform(Vector3(0.0, -0.005, -0.158), Vector3(0.22, 0.0, 0.0)),
			"rings": [
				{"y": -0.008, "rx": 0.122, "rz": 0.056, "p": 2.5, "col": brim_col},
				{"y": 0.008, "rx": 0.118, "rz": 0.052, "p": 2.4, "col": brim_col.lightened(0.08)},
			],
		},
	]
	for sx in [-0.054, 0.054]:
		parts.append({
			"seg": 12,
			"xform": _xform(Vector3(sx, 0.036, -0.162), Vector3(PI * 0.5, 0.0, 0.0)),
			"rings": [
				{"y": -0.016, "rx": 0.038, "rz": 0.034, "p": 2.0, "col": brass_col},
				{"y": 0.012, "rx": 0.034, "rz": 0.030, "p": 2.0, "col": brass_col},
				{"y": 0.018, "rx": 0.025, "rz": 0.022, "p": 2.0, "col": lens_col},
			],
		})
	return _store_mesh(k, _commit_lofts(parts))


## Builds peaked National Officer Visor Cap with dark glossy brim, cap band, and brass cockade.
static func build_officer_cap_mesh(crown_col: Color = Color(0.28, 0.30, 0.34)) -> ArrayMesh:
	var k := "ocap_%s" % crown_col.to_html(false)
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, _commit_lofts([
		{
			"seg": 20,
			"rings": [
				{"y": 0.000, "rx": 0.130, "rz": 0.136, "p": 2.1, "col": Color(0.16, 0.16, 0.18)},
				{"y": 0.036, "rx": 0.134, "rz": 0.140, "p": 2.1, "col": Color(0.76, 0.16, 0.18)},
				{"y": 0.048, "z": -0.004, "rx": 0.146, "rz": 0.152, "p": 2.1, "col": crown_col},
				{"y": 0.128, "z": -0.016, "rx": 0.168, "rz": 0.180, "p": 2.2, "col": crown_col.lightened(0.06)},
				{"y": 0.162, "z": -0.018, "rx": 0.122, "rz": 0.134, "p": 2.1, "col": crown_col.lightened(0.08)},
			],
		},
		{
			"seg": 14,
			"xform": _xform(Vector3(0.0, -0.005, -0.108), Vector3(-0.24, 0.0, 0.0)),
			"rings": [
				{"y": -0.008, "rx": 0.128, "rz": 0.088, "p": 2.3, "col": Color(0.10, 0.10, 0.12)},
				{"y": 0.010, "rx": 0.124, "rz": 0.082, "p": 2.3, "col": Color(0.18, 0.18, 0.20)},
			],
		},
		{
			"seg": 10,
			"xform": _xform(Vector3(0.0, 0.088, -0.165), Vector3(-0.18, 0.0, 0.0)),
			"rings": [
				{"y": -0.022, "rx": 0.026, "rz": 0.014, "p": 2.4, "col": Color(0.94, 0.78, 0.26)},
				{"y": 0.022, "rx": 0.030, "rz": 0.014, "p": 2.4, "col": Color(1.0, 0.88, 0.38)},
			],
		},
	]))


static func build_beret_mesh() -> ArrayMesh:
	if _mesh_cache.has("beret"):
		return _mesh_cache["beret"] as ArrayMesh
	return _store_mesh("beret", make_loft([
		{"y": -0.008, "rx": 0.124, "rz": 0.130, "p": 2.1, "col": Color(0.26, 0.26, 0.28)},
		{"y": 0.012, "rx": 0.128, "rz": 0.134, "p": 2.1, "col": Color(0.76, 0.76, 0.80)},
		{"y": 0.042, "x": -0.026, "rx": 0.168, "rz": 0.162, "p": 2.0, "col": Color.WHITE},
		{"y": 0.090, "x": -0.032, "rx": 0.156, "rz": 0.152, "p": 2.0, "col": Color.WHITE},
		{"y": 0.118, "x": -0.020, "rx": 0.086, "rz": 0.086, "p": 2.0, "col": Color.WHITE},
	], 18))


## Builds sculpted heraldic crest badge for beret front.
static func build_badge_mesh() -> ArrayMesh:
	if _mesh_cache.has("badge"):
		return _mesh_cache["badge"] as ArrayMesh
	return _store_mesh("badge", make_loft([
		{"y": -0.022, "rx": 0.014, "rz": 0.010, "p": 2.4, "col": Color(0.86, 0.86, 0.90)},
		{"y": 0.004, "rx": 0.024, "rz": 0.012, "p": 2.6, "col": Color.WHITE},
		{"y": 0.022, "rx": 0.020, "rz": 0.010, "p": 2.5, "col": Color.WHITE},
	], 10))


static func build_fedora_mesh(band_col: Color = Color(0.75, 0.20, 0.20), crown_col: Color = Color(0.14, 0.14, 0.16)) -> ArrayMesh:
	var k := "fedora_%s_%s" % [band_col.to_html(false), crown_col.to_html(false)]
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, _commit_lofts([
		{
			"seg": 20,
			"rings": [
				{"y": -0.006, "rx": 0.280, "rz": 0.295, "p": 2.0, "col": crown_col.darkened(0.10)},
				{"y": 0.022, "rx": 0.205, "rz": 0.215, "p": 2.0, "col": crown_col},
				{"y": 0.030, "rx": 0.136, "rz": 0.146, "p": 2.1, "col": crown_col},
				{"y": 0.098, "rx": 0.128, "rz": 0.140, "p": 2.2, "col": crown_col.lightened(0.06)},
				{"y": 0.142, "rx": 0.082, "rz": 0.104, "p": 2.4, "col": crown_col.lightened(0.08)},
			],
		},
		{
			"seg": 20,
			"rings": [
				{"y": 0.025, "rx": 0.142, "rz": 0.152, "p": 2.1, "col": band_col},
				{"y": 0.052, "rx": 0.139, "rz": 0.149, "p": 2.1, "col": band_col.lightened(0.10)},
			],
		},
	]))


## Builds upper arm with rounded deltoid cap (is_upper=true) or forearm overlapping inside elbow (is_upper=false).
static func build_arm_segment_mesh(r_top: float, r_bot: float, length: float, is_upper: bool = false) -> ArrayMesh:
	var k := "arm_%.4f_%.4f_%.4f_%s" % [r_top, r_bot, length, str(is_upper)]
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	var c_lit := Color.WHITE
	var c_mid := Color(0.94, 0.94, 0.96)
	var c_shade := Color(0.84, 0.84, 0.88)
	if is_upper:
		return _store_mesh(k, make_loft([
			{"y": -length - 0.030, "rx": r_bot * 0.74, "rz": r_bot * 0.74, "p": 2.0, "col": c_shade, "v": 1.00},
			{"y": -length, "rx": r_bot, "rz": r_bot, "p": 2.0, "col": c_shade, "v": 0.90},
			{"y": -length * 0.72, "rx": lerpf(r_top, r_bot, 0.70), "rz": lerpf(r_top, r_bot, 0.70), "p": 2.1, "col": c_mid, "v": 0.66},
			{"y": -length * 0.34, "rx": r_top * 0.98, "rz": r_top * 0.96, "p": 2.1, "col": c_lit, "v": 0.36},
			{"y": 0.000, "rx": r_top, "rz": r_top * 0.96, "p": 2.0, "col": c_lit, "v": 0.14},
			{"y": 0.032, "rx": r_top * 0.84, "rz": r_top * 0.82, "p": 2.0, "col": c_lit, "v": 0.06},
			{"y": 0.055, "rx": r_top * 0.48, "rz": r_top * 0.48, "p": 2.0, "col": c_mid, "v": 0.00},
		], 16))
	return _store_mesh(k, make_loft([
		{"y": -length * 0.94, "rx": r_bot, "rz": r_bot * 0.96, "p": 2.1, "col": c_shade, "v": 1.00},
		{"y": -length * 0.68, "rx": lerpf(r_top, r_bot, 0.64), "rz": lerpf(r_top, r_bot, 0.64), "p": 2.1, "col": c_mid, "v": 0.72},
		{"y": -length * 0.28, "rx": r_top * 1.05, "rz": r_top * 1.02, "p": 2.1, "col": c_lit, "v": 0.34},
		{"y": 0.000, "rx": r_top, "rz": r_top * 0.98, "p": 2.0, "col": c_lit, "v": 0.10},
		{"y": 0.014, "rx": r_top * 0.90, "rz": r_top * 0.90, "p": 2.0, "col": c_mid, "v": 0.04},
		{"y": 0.032, "rx": r_top * 0.56, "rz": r_top * 0.56, "p": 2.0, "col": c_shade, "v": 0.00},
	], 16))


## Builds sculpted chunky BFH fist/mitten palm + thumb ridge centered around Vector3.ZERO.
static func build_hand_mesh(r_scale: float = 1.0) -> ArrayMesh:
	var k := "hand_%.4f" % r_scale
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, _commit_lofts([
		{
			"seg": 14,
			"rings": [
				{"y": -0.064 * r_scale, "rx": 0.032 * r_scale, "rz": 0.028 * r_scale, "p": 2.1, "col": Color(0.86, 0.86, 0.88)},
				{"y": -0.046 * r_scale, "rx": 0.048 * r_scale, "rz": 0.044 * r_scale, "p": 2.5, "col": Color(0.95, 0.95, 0.96)},
				{"y": -0.020 * r_scale, "rx": 0.056 * r_scale, "rz": 0.052 * r_scale, "p": 2.6, "col": Color.WHITE},
				{"y": 0.006 * r_scale, "rx": 0.050 * r_scale, "rz": 0.046 * r_scale, "p": 2.4, "col": Color.WHITE},
				{"y": 0.026 * r_scale, "rx": 0.042 * r_scale, "rz": 0.038 * r_scale, "p": 2.1, "col": Color(0.90, 0.90, 0.92)},
			],
		},
		{
			"seg": 10,
			"xform": _xform(Vector3(0.044 * r_scale, -0.015 * r_scale, 0.0), Vector3(0.0, 0.0, -0.45)),
			"rings": [
				{"y": -0.026 * r_scale, "rx": 0.018 * r_scale, "rz": 0.020 * r_scale, "p": 2.1, "col": Color(0.92, 0.92, 0.94)},
				{"y": 0.004 * r_scale, "rx": 0.024 * r_scale, "rz": 0.026 * r_scale, "p": 2.2, "col": Color.WHITE},
				{"y": 0.026 * r_scale, "rx": 0.020 * r_scale, "rz": 0.022 * r_scale, "p": 2.1, "col": Color(0.92, 0.92, 0.94)},
			],
		},
	]))


static func build_leg_mesh(thigh_r: float) -> ArrayMesh:
	var k := "leg_%.4f" % thigh_r
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, make_loft([
		{"y": -0.58, "rx": thigh_r * 0.70, "rz": thigh_r * 0.72, "p": 2.1, "col": Color(0.80, 0.80, 0.84), "v": 1.00},
		{"y": -0.39, "rx": thigh_r * 0.90, "rz": thigh_r * 0.92, "p": 2.1, "col": Color(0.92, 0.92, 0.96), "v": 0.66},
		{"y": -0.33, "rx": thigh_r * 0.84, "rz": thigh_r * 0.86, "p": 2.2, "col": Color(0.84, 0.84, 0.88), "v": 0.56},
		{"y": -0.22, "rx": thigh_r * 1.06, "rz": thigh_r * 1.08, "p": 2.2, "col": Color.WHITE, "v": 0.38},
		{"y": -0.06, "rx": thigh_r * 1.02, "rz": thigh_r * 1.05, "p": 2.2, "col": Color.WHITE, "v": 0.14},
		{"y": 0.05, "rx": thigh_r * 0.92, "rz": thigh_r * 0.96, "p": 2.1, "col": Color(0.92, 0.92, 0.94), "v": 0.00},
	], 16))


static func build_thigh_mesh(thigh_r: float) -> ArrayMesh:
	var k := "thigh_%.4f" % thigh_r
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, make_loft([
		{"y": -0.35, "rx": thigh_r * 0.82, "rz": thigh_r * 0.84, "p": 2.2, "col": Color(0.84, 0.84, 0.88), "v": 0.58},
		{"y": -0.31, "rx": thigh_r * 0.90, "rz": thigh_r * 0.92, "p": 2.2, "col": Color(0.88, 0.88, 0.92), "v": 0.52},
		{"y": -0.22, "rx": thigh_r * 1.06, "rz": thigh_r * 1.08, "p": 2.2, "col": Color.WHITE, "v": 0.38},
		{"y": -0.06, "rx": thigh_r * 1.02, "rz": thigh_r * 1.05, "p": 2.2, "col": Color.WHITE, "v": 0.14},
		{"y": 0.05, "rx": thigh_r * 0.92, "rz": thigh_r * 0.96, "p": 2.1, "col": Color(0.92, 0.92, 0.94), "v": 0.00},
	], 16))


static func build_calf_mesh(thigh_r: float) -> ArrayMesh:
	var k := "calf_%.4f" % thigh_r
	if _mesh_cache.has(k):
		return _mesh_cache[k] as ArrayMesh
	return _store_mesh(k, make_loft([
		{"y": -0.24, "rx": thigh_r * 0.70, "rz": thigh_r * 0.72, "p": 2.1, "col": Color(0.80, 0.80, 0.84), "v": 1.00},
		{"y": -0.14, "rx": thigh_r * 0.86, "rz": thigh_r * 0.88, "p": 2.1, "col": Color(0.90, 0.90, 0.94), "v": 0.80},
		{"y": -0.05, "rx": thigh_r * 0.90, "rz": thigh_r * 0.92, "p": 2.1, "col": Color(0.92, 0.92, 0.96), "v": 0.66},
		{"y": 0.00, "rx": thigh_r * 0.86, "rz": thigh_r * 0.88, "p": 2.2, "col": Color(0.88, 0.88, 0.92), "v": 0.58},
		{"y": 0.02, "rx": thigh_r * 0.72, "rz": thigh_r * 0.74, "p": 2.2, "col": Color(0.84, 0.84, 0.88), "v": 0.54},
	], 16))


static func build_boot_mesh() -> ArrayMesh:
	if _mesh_cache.has("boot"):
		return _mesh_cache["boot"] as ArrayMesh
	return _store_mesh("boot", _commit_lofts([
		{
			"seg": 16,
			"rings": [
				{"y": -0.200, "z": -0.045, "rx": 0.090, "rz": 0.152, "p": 2.5, "col": Color(0.45, 0.45, 0.48)},
				{"y": -0.165, "z": -0.045, "rx": 0.092, "rz": 0.155, "p": 2.5, "col": Color(0.55, 0.55, 0.58)},
				{"y": -0.125, "z": -0.040, "rx": 0.084, "rz": 0.142, "p": 2.4, "col": Color.WHITE},
				{"y": -0.075, "z": -0.012, "rx": 0.072, "rz": 0.086, "p": 2.1, "col": Color(0.94, 0.94, 0.96)},
				{"y": 0.045, "z": 0.000, "rx": 0.078, "rz": 0.082, "p": 2.1, "col": Color(0.88, 0.88, 0.92)},
			],
		},
		{
			"seg": 12,
			"xform": _xform(Vector3(0.0, 0.036, 0.0)),
			"rings": [
				{"y": -0.020, "rx": 0.082, "rz": 0.086, "p": 2.1, "col": Color(0.82, 0.80, 0.78)},
				{"y": 0.020, "rx": 0.084, "rz": 0.088, "p": 2.1, "col": Color(0.92, 0.90, 0.88)},
			],
		},
	]))


static func _add_box_part(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, parts: Array[MeshInstance3D], part_name: String = "") -> MeshInstance3D:
	var key := "box|%.4f,%.4f,%.4f" % [size.x, size.y, size.z]
	var bm: BoxMesh = _prim_cache.get(key)
	if bm == null:
		bm = BoxMesh.new()
		bm.size = size
		_prim_cache[key] = bm
	return add_part(parent, bm, pos, rot, mat, parts, part_name)


static func _add_cyl_part(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, rot: Vector3, mat: Material, segs: int, parts: Array[MeshInstance3D], part_name: String = "") -> MeshInstance3D:
	var key := "cyl|%.4f,%.4f,%.4f|%d" % [r_top, r_bot, h, segs]
	var cm: CylinderMesh = _prim_cache.get(key)
	if cm == null:
		cm = CylinderMesh.new()
		cm.top_radius = r_top
		cm.bottom_radius = r_bot
		cm.height = h
		cm.radial_segments = segs
		_prim_cache[key] = cm
	return add_part(parent, cm, pos, rot, mat, parts, part_name)


static func build_weapon_mesh(w_kind: int, p_archetype: int = 0) -> Node3D:
	var root := Node3D.new()
	populate_weapon_root(root, w_kind, p_archetype)
	return root


static func populate_weapon_root(root: Node3D, w_kind: int, p_archetype: int = 0) -> Dictionary:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

	var arch: int = clampi(p_archetype, 0, 2)
	var cache_key: String = "%d_%d" % [w_kind, arch]
	if _weapon_cache.has(cache_key):
		var cached: Dictionary = _weapon_cache[cache_key]
		var parts_tpl: Array = cached["parts"]
		var parts_by_name: Dictionary = {}
		for p_dict in parts_tpl:
			var mi := MeshInstance3D.new()
			mi.mesh = p_dict["mesh"]
			mi.position = p_dict.get("base_pos", p_dict["pos"])
			mi.rotation = p_dict["rot"]
			mi.material_override = p_dict["mat"]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 220.0
			var p_name: String = str(p_dict.get("name", ""))
			if not p_name.is_empty():
				mi.name = p_name
				parts_by_name[p_name] = mi
			root.add_child(mi)
		var out_info: Dictionary = (cached["info"] as Dictionary).duplicate()
		out_info["parts_by_name"] = parts_by_name
		return out_info

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var metal_mat := make_sculpted_mat(Color(0.20, 0.22, 0.26), "", 0.45, 0.35)
	var blued_metal_mat := make_sculpted_mat(Color(0.16, 0.20, 0.25), "", 0.38, 0.45)
	var steel_mat := make_sculpted_mat(Color(0.48, 0.52, 0.56), "", 0.35, 0.55)
	var brass_mat := make_sculpted_mat(Color(0.72, 0.58, 0.24), "", 0.32, 0.65)
	var copper_mat := make_sculpted_mat(Color(0.78, 0.42, 0.26), "", 0.35, 0.50)
	var wood_mat := make_sculpted_mat(Color.WHITE, "hero_gun_wood", 0.65)
	var leather_mat := make_sculpted_mat(Color(0.28, 0.18, 0.11), "", 0.70, 0.08)
	var baz_mat := make_sculpted_mat(Color(0.26, 0.38, 0.22), "", 0.60)
	var red_dyn_mat := make_sculpted_mat(Color(0.84, 0.18, 0.14), "", 0.65)
	var white_dial_mat := make_sculpted_mat(Color(0.96, 0.96, 0.94), "", 0.40)
	var lens_mat := make_sculpted_mat(Color(0.45, 0.75, 0.95), "", 0.12, 0.65)
	var dummy: Array[MeshInstance3D] = []

	# Origin (0, 0, 0) = Trigger / Right Hand Grip.
	# +Z = Buttstock behind grip, -Z = Receiver + Foregrip + Barrel forward!
	var info := {
		"grip": Vector3(0.0, -0.04, 0.0),
		"foregrip": Vector3(0.0, -0.015, -0.24),
		"muzzle": Vector3(0.0, 0.035, -0.58),
		"two_handed": true,
	}

	var p_grip := BoxMesh.new()
	p_grip.size = Vector3(0.034, 0.11, 0.044)

	match w_kind:
		4: # Sniper Rifle (arch 0=Classic Walnut, 1=Compact Recon Semi, 2=Heavy Anti-Materiel)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.28, 0.0, 0.0), metal_mat, dummy)
				var stock_1 := make_loft([
					{"y": 0.00, "rx": 0.018, "rz": 0.042, "p": 2.2},
					{"y": 0.22, "rx": 0.022, "rz": 0.032, "p": 2.2},
				], 12)
				add_part(root, stock_1, Vector3(0.0, -0.005, 0.22), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				_add_box_part(root, Vector3(0.042, 0.048, 0.26), Vector3(0.0, 0.028, -0.10), Vector3.ZERO, metal_mat, dummy)
				_add_box_part(root, Vector3(0.024, 0.095, 0.055), Vector3(0.0, -0.042, -0.12), Vector3(0.12, 0.0, 0.0), blued_metal_mat, dummy)
				_add_cyl_part(root, 0.015, 0.013, 0.42, Vector3(0.0, 0.038, -0.42), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
				_add_cyl_part(root, 0.021, 0.018, 0.075, Vector3(0.0, 0.038, -0.61), Vector3(PI * 0.5, 0.0, 0.0), copper_mat, 10, dummy)
				_add_box_part(root, Vector3(0.036, 0.036, 0.14), Vector3(0.0, 0.082, -0.06), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.019, 0.019, 0.01, Vector3(0.0, 0.082, -0.13), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 10, dummy)
				_add_cyl_part(root, 0.006, 0.006, 0.045, Vector3(0.026, 0.036, -0.06), Vector3(0.0, 0.0, PI * 0.4), steel_mat, 8, dummy, "Bolt")
				info["foregrip"] = Vector3(0.0, -0.015, -0.22)
				info["muzzle"] = Vector3(0.0, 0.038, -0.64)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.052, 0.098, 0.29), Vector3(0.0, -0.005, 0.17), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.056, 0.068, 0.34), Vector3(0.0, 0.036, -0.12), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.022, 0.020, 0.68, Vector3(0.0, 0.042, -0.56), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 12, dummy)
				_add_box_part(root, Vector3(0.068, 0.042, 0.095), Vector3(0.0, 0.042, -0.90), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.030, 0.024, 0.34, Vector3(0.0, 0.105, -0.08), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy)
				_add_cyl_part(root, 0.026, 0.026, 0.012, Vector3(0.0, 0.105, -0.25), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 12, dummy)
				_add_cyl_part(root, 0.009, 0.009, 0.22, Vector3(-0.08, -0.07, -0.45), Vector3(0.2, 0.0, 0.45), metal_mat, 8, dummy)
				_add_cyl_part(root, 0.009, 0.009, 0.22, Vector3(0.08, -0.07, -0.45), Vector3(0.2, 0.0, -0.45), metal_mat, 8, dummy)
				_add_cyl_part(root, 0.008, 0.008, 0.055, Vector3(0.034, 0.042, -0.06), Vector3(0.0, 0.0, PI * 0.4), steel_mat, 8, dummy, "Bolt")
				info["foregrip"] = Vector3(0.0, -0.015, -0.27)
				info["muzzle"] = Vector3(0.0, 0.042, -0.95)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				var stock := make_loft([
					{"y": 0.00, "rx": 0.022, "rz": 0.056, "p": 2.2, "col": Color(0.9, 0.9, 0.9)},
					{"y": 0.16, "rx": 0.025, "rz": 0.048, "p": 2.2, "col": Color.WHITE},
					{"y": 0.28, "rx": 0.028, "rz": 0.038, "p": 2.2, "col": Color.WHITE},
				], 12)
				add_part(root, stock, Vector3(0.0, -0.01, 0.28), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				var forend := make_loft([
					{"y": 0.00, "rx": 0.026, "rz": 0.034, "p": 2.2, "col": Color.WHITE},
					{"y": 0.38, "rx": 0.020, "rz": 0.026, "p": 2.1, "col": Color.WHITE},
				], 12)
				add_part(root, forend, Vector3(0.0, 0.005, 0.02), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				var rec_s := make_loft([
					{"y": 0.00, "rx": 0.025, "rz": 0.028, "p": 2.2},
					{"y": 0.24, "rx": 0.025, "rz": 0.028, "p": 2.2},
				], 12)
				add_part(root, rec_s, Vector3(0.0, 0.038, 0.02), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				_add_cyl_part(root, 0.006, 0.006, 0.045, Vector3(0.028, 0.042, -0.05), Vector3(0.0, 0.0, PI * 0.4), steel_mat, 8, dummy, "Bolt")
				var barrel := make_loft([
					{"y": 0.00, "rx": 0.017, "rz": 0.017, "p": 2.0},
					{"y": 0.52, "rx": 0.013, "rz": 0.013, "p": 2.0},
					{"y": 0.55, "rx": 0.016, "rz": 0.016, "p": 2.0},
				], 10)
				add_part(root, barrel, Vector3(0.0, 0.042, -0.22), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
				var scope := make_loft([
					{"y": 0.00, "rx": 0.026, "rz": 0.026, "p": 2.0},
					{"y": 0.06, "rx": 0.020, "rz": 0.020, "p": 2.0},
					{"y": 0.22, "rx": 0.020, "rz": 0.020, "p": 2.0},
					{"y": 0.28, "rx": 0.028, "rz": 0.028, "p": 2.0},
				], 12)
				add_part(root, scope, Vector3(0.0, 0.095, 0.05), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, dummy)
				_add_box_part(root, Vector3(0.018, 0.035, 0.02), Vector3(0.0, 0.065, -0.04), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.018, 0.035, 0.02), Vector3(0.0, 0.065, -0.16), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.024, 0.024, 0.01, Vector3(0.0, 0.095, -0.23), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 12, dummy)
				_add_cyl_part(root, 0.022, 0.022, 0.01, Vector3(0.0, 0.095, 0.05), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 12, dummy)
				info["foregrip"] = Vector3(0.0, -0.015, -0.26)
				info["muzzle"] = Vector3(0.0, 0.042, -0.76)

		0: # SMG (arch 0=Classic Walnut, 1=Compact Wire-Stock Fast, 2=Long Carbine Brass)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.050, 0.01), Vector3(-0.26, 0.0, 0.0), metal_mat, dummy)
				_add_cyl_part(root, 0.008, 0.008, 0.20, Vector3(0.0, 0.015, 0.13), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 8, dummy)
				_add_box_part(root, Vector3(0.014, 0.075, 0.018), Vector3(0.0, -0.01, 0.23), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.026, 0.026, 0.24, Vector3(0.0, 0.032, -0.12), Vector3(PI * 0.5, 0.0, 0.0), copper_mat, 12, dummy)
				_add_cyl_part(root, 0.019, 0.016, 0.18, Vector3(0.0, 0.032, -0.33), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 10, dummy)
				_add_box_part(root, Vector3(0.026, 0.16, 0.036), Vector3(0.0, -0.055, -0.14), Vector3(0.08, 0.0, 0.0), blued_metal_mat, dummy)
				_add_box_part(root, Vector3(0.030, 0.028, 0.042), Vector3(0.0, -0.045, -0.14), Vector3.ZERO, brass_mat, dummy)
				info["foregrip"] = Vector3(0.0, -0.015, -0.20)
				info["muzzle"] = Vector3(0.0, 0.032, -0.44)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.050, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.044, 0.090, 0.27), Vector3(0.0, -0.012, 0.14), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.054, 0.062, 0.34), Vector3(0.0, 0.028, -0.14), Vector3.ZERO, metal_mat, dummy)
				_add_box_part(root, Vector3(0.046, 0.036, 0.19), Vector3(0.0, -0.008, -0.24), Vector3.ZERO, wood_mat, dummy)
				_add_cyl_part(root, 0.017, 0.015, 0.34, Vector3(0.0, 0.035, -0.48), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
				_add_box_part(root, Vector3(0.024, 0.028, 0.09), Vector3(0.0, 0.072, -0.08), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.012, 0.012, 0.01, Vector3(0.0, 0.072, -0.125), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 8, dummy)
				_add_cyl_part(root, 0.042, 0.042, 0.048, Vector3(0.0, -0.032, -0.13), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				info["foregrip"] = Vector3(0.0, -0.018, -0.26)
				info["muzzle"] = Vector3(0.0, 0.035, -0.66)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.050, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				var butt_smg := make_loft([
					{"y": 0.00, "rx": 0.022, "rz": 0.045, "p": 2.2, "col": Color(0.9, 0.9, 0.9)},
					{"y": 0.14, "rx": 0.024, "rz": 0.038, "p": 2.2, "col": Color.WHITE},
					{"y": 0.24, "rx": 0.026, "rz": 0.030, "p": 2.2, "col": Color.WHITE},
				], 12)
				add_part(root, butt_smg, Vector3(0.0, -0.01, 0.24), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				var rec_smg := make_loft([
					{"y": 0.00, "rx": 0.028, "rz": 0.034, "p": 2.2},
					{"y": 0.16, "rx": 0.030, "rz": 0.035, "p": 2.2},
					{"y": 0.28, "rx": 0.028, "rz": 0.034, "p": 2.2},
				], 12)
				add_part(root, rec_smg, Vector3(0.0, 0.030, -0.02), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				var shroud := make_loft([
					{"y": 0.00, "rx": 0.020, "rz": 0.020, "p": 2.0},
					{"y": 0.22, "rx": 0.015, "rz": 0.015, "p": 2.0},
				], 10)
				add_part(root, shroud, Vector3(0.0, 0.035, -0.29), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
				_add_box_part(root, Vector3(0.008, 0.018, 0.012), Vector3(0.0, 0.054, -0.48), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.008, 0.008, 0.022, Vector3(-0.032, 0.040, -0.16), Vector3(0.0, 0.0, PI * 0.5), steel_mat, 8, dummy)
				var mag := make_loft([
					{"y": 0.00, "rx": 0.014, "rz": 0.024, "p": 2.0},
					{"y": 0.10, "rx": 0.014, "rz": 0.024, "p": 2.0},
					{"y": 0.20, "rx": 0.013, "rz": 0.022, "p": 2.0},
				], 10)
				add_part(root, mag, Vector3(0.0, 0.01, -0.14), Vector3(PI * 0.5 + 0.18, 0.0, 0.0), metal_mat, dummy)
				info["foregrip"] = Vector3(0.0, -0.015, -0.23)
				info["muzzle"] = Vector3(0.0, 0.035, -0.52)

		1: # Heavy MG (arch 0=Water-Cooled Drum, 1=Rapid Assault Finned Box-Mag, 2=Heavy Long Bipod)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.040, 0.01), Vector3(-0.22, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.032, 0.064, 0.20), Vector3(0.0, 0.012, 0.12), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.076, 0.082, 0.30), Vector3(0.0, 0.026, -0.12), Vector3.ZERO, copper_mat, dummy)
				_add_cyl_part(root, 0.032, 0.028, 0.28, Vector3(0.0, 0.030, -0.41), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 12, dummy)
				_add_box_part(root, Vector3(0.11, 0.085, 0.095), Vector3(0.0, -0.055, -0.14), Vector3.ZERO, brass_mat, dummy)
				_add_box_part(root, Vector3(0.028, 0.026, 0.07), Vector3(0.0, 0.082, -0.08), Vector3.ZERO, steel_mat, dummy)
				info["foregrip"] = Vector3(-0.02, 0.04, -0.24)
				info["muzzle"] = Vector3(0.0, 0.030, -0.58)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.040, 0.01), Vector3(-0.22, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.054, 0.085, 0.25), Vector3(0.0, 0.008, 0.13), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.095, 0.098, 0.36), Vector3(0.0, 0.028, -0.15), Vector3.ZERO, metal_mat, dummy)
				_add_cyl_part(root, 0.038, 0.034, 0.44, Vector3(0.0, 0.032, -0.55), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 14, dummy)
				_add_box_part(root, Vector3(0.068, 0.048, 0.09), Vector3(0.0, 0.032, -0.82), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.082, 0.082, 0.10, Vector3(-0.085, -0.025, -0.16), Vector3(0.0, 0.0, PI * 0.5), metal_mat, 14, dummy)
				_add_cyl_part(root, 0.082, 0.082, 0.10, Vector3(0.085, -0.025, -0.16), Vector3(0.0, 0.0, PI * 0.5), metal_mat, 14, dummy)
				_add_cyl_part(root, 0.010, 0.010, 0.24, Vector3(-0.09, -0.08, -0.58), Vector3(0.25, 0.0, 0.42), steel_mat, 8, dummy)
				_add_cyl_part(root, 0.010, 0.010, 0.24, Vector3(0.09, -0.08, -0.58), Vector3(0.25, 0.0, -0.42), steel_mat, 8, dummy)
				info["foregrip"] = Vector3(-0.03, 0.09, -0.25)
				info["muzzle"] = Vector3(0.0, 0.032, -0.88)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.040, 0.01), Vector3(-0.22, 0.0, 0.0), wood_mat, dummy)
				var mg_stock := make_loft([
					{"y": 0.00, "rx": 0.026, "rz": 0.042, "p": 2.2},
					{"y": 0.22, "rx": 0.028, "rz": 0.032, "p": 2.2},
				], 12)
				add_part(root, mg_stock, Vector3(0.0, 0.010, 0.22), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				var mg_rec := make_loft([
					{"y": 0.00, "rx": 0.044, "rz": 0.046, "p": 2.3},
					{"y": 0.32, "rx": 0.044, "rz": 0.046, "p": 2.3},
				], 12)
				add_part(root, mg_rec, Vector3(0.0, 0.025, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				var jacket := make_loft([
					{"y": 0.00, "rx": 0.042, "rz": 0.042, "p": 2.0},
					{"y": 0.28, "rx": 0.038, "rz": 0.038, "p": 2.0},
					{"y": 0.36, "rx": 0.048, "rz": 0.048, "p": 2.0},
				], 14)
				add_part(root, jacket, Vector3(0.0, 0.030, -0.32), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
				_add_cyl_part(root, 0.016, 0.016, 0.12, Vector3(0.0, 0.030, -0.68), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 10, dummy)
				_add_cyl_part(root, 0.095, 0.095, 0.11, Vector3(-0.08, -0.03, -0.16), Vector3(0.0, 0.0, PI * 0.5), baz_mat, 16, dummy)
				_add_cyl_part(root, 0.098, 0.098, 0.02, Vector3(-0.08, -0.03, -0.16), Vector3(0.0, 0.0, PI * 0.5), brass_mat, 16, dummy)
				_add_box_part(root, Vector3(0.03, 0.04, 0.14), Vector3(-0.07, 0.03, -0.16), Vector3.ZERO, brass_mat, dummy)
				var handle := make_loft([
					{"y": 0.00, "rx": 0.012, "rz": 0.012, "p": 2.0},
					{"y": 0.12, "rx": 0.014, "rz": 0.014, "p": 2.0},
				], 8)
				add_part(root, handle, Vector3(-0.02, 0.105, -0.14), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.025, 0.05, 0.04), Vector3(0.0, -0.025, -0.42), Vector3.ZERO, steel_mat, dummy)
				info["foregrip"] = Vector3(-0.03, 0.10, -0.22)
				info["muzzle"] = Vector3(0.0, 0.030, -0.74)

		2: # Combat Shotgun (arch 0=Pump Walnut, 1=Sawed-Off Double-Barrel Shorty, 2=Long Over-Under Marksman)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.044, 0.03), Vector3(-0.48, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.058, 0.054, 0.14), Vector3(0.0, 0.022, -0.04), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.019, 0.019, 0.30, Vector3(-0.020, 0.044, -0.25), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 10, dummy)
				_add_cyl_part(root, 0.019, 0.019, 0.30, Vector3(0.020, 0.044, -0.25), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 10, dummy)
				_add_box_part(root, Vector3(0.062, 0.036, 0.13), Vector3(0.0, 0.016, -0.18), Vector3.ZERO, wood_mat, dummy, "Pump")
				info["foregrip"] = Vector3(0.0, 0.0, -0.20)
				info["muzzle"] = Vector3(0.0, 0.044, -0.42)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.042, 0.01), Vector3(-0.26, 0.0, 0.0), leather_mat, dummy)
				_add_box_part(root, Vector3(0.048, 0.095, 0.28), Vector3(0.0, -0.008, 0.16), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.052, 0.065, 0.23), Vector3(0.0, 0.032, -0.09), Vector3.ZERO, copper_mat, dummy)
				_add_cyl_part(root, 0.018, 0.016, 0.52, Vector3(0.0, 0.052, -0.44), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
				_add_cyl_part(root, 0.017, 0.015, 0.50, Vector3(0.0, 0.022, -0.43), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 10, dummy)
				_add_box_part(root, Vector3(0.014, 0.012, 0.48), Vector3(0.0, 0.070, -0.44), Vector3.ZERO, brass_mat, dummy)
				_add_box_part(root, Vector3(0.044, 0.040, 0.19), Vector3(0.0, 0.014, -0.29), Vector3.ZERO, wood_mat, dummy, "Pump")
				info["foregrip"] = Vector3(0.0, -0.012, -0.32)
				info["muzzle"] = Vector3(0.0, 0.052, -0.71)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.042, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				var s_butt := make_loft([
					{"y": 0.00, "rx": 0.024, "rz": 0.054, "p": 2.3},
					{"y": 0.14, "rx": 0.026, "rz": 0.048, "p": 2.3},
					{"y": 0.26, "rx": 0.028, "rz": 0.036, "p": 2.2},
				], 12)
				add_part(root, s_butt, Vector3(0.0, -0.01, 0.26), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
				var s_rec := make_loft([
					{"y": 0.00, "rx": 0.026, "rz": 0.034, "p": 2.2},
					{"y": 0.22, "rx": 0.026, "rz": 0.034, "p": 2.2},
				], 12)
				add_part(root, s_rec, Vector3(0.0, 0.030, 0.02), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				_add_box_part(root, Vector3(0.010, 0.018, 0.055), Vector3(0.024, 0.036, -0.09), Vector3.ZERO, steel_mat, dummy)
				var s_brl := make_loft([
					{"y": 0.00, "rx": 0.019, "rz": 0.019, "p": 2.0},
					{"y": 0.38, "rx": 0.016, "rz": 0.016, "p": 2.0},
				], 10)
				add_part(root, s_brl, Vector3(0.0, 0.045, -0.19), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
				_add_cyl_part(root, 0.014, 0.014, 0.28, Vector3(0.0, 0.018, -0.32), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 10, dummy)
				_add_cyl_part(root, 0.004, 0.004, 0.008, Vector3(0.0, 0.062, -0.56), Vector3.ZERO, brass_mat, 6, dummy)
				var pump := make_loft([
					{"y": 0.00, "rx": 0.024, "rz": 0.026, "p": 2.2},
					{"y": 0.16, "rx": 0.024, "rz": 0.026, "p": 2.2},
				], 12)
				add_part(root, pump, Vector3(0.0, 0.016, -0.22), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy, "Pump")
				info["foregrip"] = Vector3(0.0, -0.015, -0.29)
				info["muzzle"] = Vector3(0.0, 0.045, -0.58)

		6: # Bazooka (arch 0=Olive WWII, 1=Shielded Rapid Dark, 2=Heavy Optic Brass Siege)
			if arch == 1:
				_add_cyl_part(root, 0.062, 0.062, 0.94, Vector3(0.0, 0.0, -0.16), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 14, dummy)
				_add_cyl_part(root, 0.068, 0.068, 0.04, Vector3(0.0, 0.0, 0.31), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy, "Bolt")
				_add_box_part(root, Vector3(0.32, 0.28, 0.016), Vector3(0.0, 0.06, -0.34), Vector3.ZERO, metal_mat, dummy)
				_add_box_part(root, Vector3(0.33, 0.045, 0.020), Vector3(0.0, 0.15, -0.34), Vector3.ZERO, red_dyn_mat, dummy)
				_add_cyl_part(root, 0.055, 0.012, 0.16, Vector3(0.0, 0.0, -0.69), Vector3(-PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy, "Warhead")
				add_part(root, p_grip, Vector3(0.0, -0.09, 0.0), Vector3(-0.18, 0.0, 0.0), metal_mat, dummy)
				add_part(root, p_grip, Vector3(0.0, -0.085, -0.22), Vector3.ZERO, metal_mat, dummy)
				info["grip"] = Vector3(0.0, -0.10, 0.0)
				info["foregrip"] = Vector3(0.0, -0.095, -0.22)
				info["muzzle"] = Vector3(0.0, 0.0, -0.76)
			elif arch == 2:
				var tube_2 := make_loft([
					{"y": 0.00, "rx": 0.105, "rz": 0.105, "p": 2.0},
					{"y": 0.20, "rx": 0.074, "rz": 0.074, "p": 2.0},
					{"y": 1.32, "rx": 0.074, "rz": 0.074, "p": 2.0},
					{"y": 1.48, "rx": 0.112, "rz": 0.112, "p": 2.0},
				], 16)
				add_part(root, tube_2, Vector3(0.0, 0.0, 0.48), Vector3(-PI * 0.5, 0.0, 0.0), copper_mat, dummy)
				_add_cyl_part(root, 0.106, 0.106, 0.04, Vector3(0.0, 0.0, 0.48), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 14, dummy, "Bolt")
				_add_cyl_part(root, 0.115, 0.080, 0.14, Vector3(0.0, 0.0, -0.92), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, 14, dummy)
				_add_cyl_part(root, 0.060, 0.012, 0.16, Vector3(0.0, 0.0, -0.96), Vector3(-PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy, "Warhead")
				_add_box_part(root, Vector3(0.052, 0.056, 0.18), Vector3(0.065, 0.088, -0.45), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.022, 0.022, 0.012, Vector3(0.065, 0.088, -0.54), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 10, dummy)
				add_part(root, p_grip, Vector3(0.0, -0.105, 0.0), Vector3(-0.18, 0.0, 0.0), wood_mat, dummy)
				add_part(root, p_grip, Vector3(0.0, -0.100, -0.26), Vector3.ZERO, wood_mat, dummy)
				info["grip"] = Vector3(0.0, -0.115, 0.0)
				info["foregrip"] = Vector3(0.0, -0.110, -0.26)
				info["muzzle"] = Vector3(0.0, 0.0, -1.00)
			else:
				var tube := make_loft([
					{"y": 0.00, "rx": 0.096, "rz": 0.096, "p": 2.0},
					{"y": 0.16, "rx": 0.068, "rz": 0.068, "p": 2.0},
					{"y": 1.10, "rx": 0.068, "rz": 0.068, "p": 2.0},
					{"y": 1.24, "rx": 0.092, "rz": 0.092, "p": 2.0},
				], 16)
				add_part(root, tube, Vector3(0.0, 0.0, 0.42), Vector3(-PI * 0.5, 0.0, 0.0), baz_mat, dummy)
				_add_cyl_part(root, 0.095, 0.095, 0.04, Vector3(0.0, 0.0, 0.42), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy, "Bolt")
				_add_cyl_part(root, 0.076, 0.076, 0.04, Vector3(0.0, 0.0, 0.08), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy)
				_add_cyl_part(root, 0.076, 0.076, 0.04, Vector3(0.0, 0.0, -0.38), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy)
				_add_box_part(root, Vector3(0.045, 0.045, 0.010), Vector3(0.065, 0.070, -0.72), Vector3.ZERO, steel_mat, dummy)
				var warhead := make_loft([
					{"y": 0.00, "rx": 0.060, "rz": 0.060, "p": 2.0},
					{"y": 0.08, "rx": 0.052, "rz": 0.052, "p": 2.0},
					{"y": 0.15, "rx": 0.010, "rz": 0.010, "p": 2.0},
				], 12)
				add_part(root, warhead, Vector3(0.0, 0.0, -0.80), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy, "Warhead")
				add_part(root, p_grip, Vector3(0.0, -0.10, 0.0), Vector3(-0.18, 0.0, 0.0), wood_mat, dummy)
				add_part(root, p_grip, Vector3(0.0, -0.095, -0.24), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.014, 0.045, 0.055), Vector3(0.0, -0.065, -0.05), Vector3.ZERO, steel_mat, dummy)
				info["grip"] = Vector3(0.0, -0.11, 0.0)
				info["foregrip"] = Vector3(0.0, -0.105, -0.24)
				info["muzzle"] = Vector3(0.0, 0.0, -0.85)

		5: # Commando Knife (arch 0=Dagger, 1=Curved Fast Karambit/Kukri, 2=Heavy Cleaver Bowie)
			if arch == 1:
				_add_cyl_part(root, 0.028, 0.028, 0.014, Vector3(0.0, 0.0, 0.075), Vector3(0.0, 0.0, PI * 0.5), brass_mat, 12, dummy)
				_add_box_part(root, Vector3(0.022, 0.026, 0.12), Vector3(0.0, 0.0, 0.0), Vector3(0.12, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.010, 0.046, 0.11), Vector3(0.0, -0.008, -0.105), Vector3(0.18, 0.0, 0.0), copper_mat, dummy)
				_add_box_part(root, Vector3(0.008, 0.042, 0.105), Vector3(0.0, -0.032, -0.195), Vector3(0.42, 0.0, 0.0), steel_mat, dummy)
				info["grip"] = Vector3(0.0, 0.0, 0.01)
				info["foregrip"] = Vector3.ZERO
				info["muzzle"] = Vector3(0.0, -0.025, -0.26)
				info["two_handed"] = false
			elif arch == 2:
				_add_box_part(root, Vector3(0.028, 0.034, 0.13), Vector3(0.0, 0.0, 0.01), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.024, 0.095, 0.022), Vector3(0.0, 0.0, -0.06), Vector3.ZERO, brass_mat, dummy)
				_add_box_part(root, Vector3(0.010, 0.068, 0.24), Vector3(0.0, 0.012, -0.19), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.012, 0.018, 0.25), Vector3(0.0, 0.044, -0.195), Vector3.ZERO, brass_mat, dummy)
				_add_box_part(root, Vector3(0.008, 0.046, 0.085), Vector3(0.0, 0.016, -0.34), Vector3(-0.32, 0.0, 0.0), steel_mat, dummy)
				info["grip"] = Vector3(0.0, 0.0, 0.01)
				info["foregrip"] = Vector3.ZERO
				info["muzzle"] = Vector3(0.0, 0.012, -0.40)
				info["two_handed"] = false
			else:
				var hdl := make_loft([
					{"y": 0.00, "rx": 0.018, "rz": 0.022, "p": 2.1},
					{"y": 0.06, "rx": 0.020, "rz": 0.024, "p": 2.1},
					{"y": 0.12, "rx": 0.018, "rz": 0.022, "p": 2.1},
				], 10)
				add_part(root, hdl, Vector3(0.0, 0.0, 0.06), Vector3(-PI * 0.5, 0.0, 0.0), leather_mat, dummy)
				_add_cyl_part(root, 0.022, 0.020, 0.018, Vector3(0.0, 0.0, 0.065), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 10, dummy)
				_add_box_part(root, Vector3(0.080, 0.016, 0.018), Vector3(0.0, 0.0, -0.065), Vector3(0.0, 0.18, 0.0), brass_mat, dummy)
				var blade := make_loft([
					{"y": 0.00, "rx": 0.006, "rz": 0.024, "p": 2.4},
					{"y": 0.14, "rx": 0.005, "rz": 0.022, "p": 2.2},
					{"y": 0.22, "rx": 0.003, "rz": 0.005, "p": 2.0},
				], 10)
				add_part(root, blade, Vector3(0.0, 0.005, -0.075), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
				info["grip"] = Vector3(0.0, 0.0, 0.01)
				info["foregrip"] = Vector3.ZERO
				info["muzzle"] = Vector3(0.0, 0.005, -0.30)
				info["two_handed"] = false

		7: # TNT (arch 0=4-Stick Clockwork, 1=Compact Canvas Satchel Plunger, 2=Armored 6-Stick Mine Charge)
			if arch == 1:
				_add_box_part(root, Vector3(0.19, 0.14, 0.16), Vector3(0.0, 0.0, -0.03), Vector3.ZERO, baz_mat, dummy)
				_add_box_part(root, Vector3(0.20, 0.038, 0.17), Vector3(0.0, 0.06, -0.03), Vector3.ZERO, leather_mat, dummy)
				_add_cyl_part(root, 0.024, 0.024, 0.12, Vector3(-0.045, 0.085, -0.03), Vector3.ZERO, brass_mat, 10, dummy)
				_add_cyl_part(root, 0.018, 0.018, 0.02, Vector3(-0.045, 0.15, -0.03), Vector3.ZERO, red_dyn_mat, 10, dummy)
				_add_cyl_part(root, 0.014, 0.014, 0.08, Vector3(0.045, 0.09, -0.03), Vector3.ZERO, lens_mat, 10, dummy)
			elif arch == 2:
				for dx in [-0.056, 0.0, 0.056]:
					for dy in [-0.045, 0.045]:
						_add_cyl_part(root, 0.034, 0.034, 0.25, Vector3(dx, dy, -0.04), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 10, dummy)
				_add_box_part(root, Vector3(0.21, 0.175, 0.042), Vector3(0.0, 0.0, 0.04), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.21, 0.175, 0.042), Vector3(0.0, 0.0, -0.12), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.048, 0.048, 0.028, Vector3(0.0, 0.095, -0.04), Vector3.ZERO, brass_mat, 12, dummy)
				_add_cyl_part(root, 0.040, 0.040, 0.030, Vector3(0.0, 0.097, -0.04), Vector3.ZERO, white_dial_mat, 12, dummy)
				_add_cyl_part(root, 0.010, 0.004, 0.075, Vector3(-0.075, 0.095, -0.04), Vector3(0.0, 0.0, 0.45), brass_mat, 8, dummy)
				_add_cyl_part(root, 0.010, 0.004, 0.075, Vector3(0.075, 0.095, -0.04), Vector3(0.0, 0.0, -0.45), brass_mat, 8, dummy)
			else:
				for dx in [-0.042, 0.042]:
					for dy in [-0.042, 0.042]:
						_add_cyl_part(root, 0.038, 0.038, 0.22, Vector3(dx, dy, -0.04), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy)
				_add_box_part(root, Vector3(0.185, 0.185, 0.030), Vector3(0.0, 0.0, 0.03), Vector3.ZERO, leather_mat, dummy)
				_add_box_part(root, Vector3(0.185, 0.185, 0.030), Vector3(0.0, 0.0, -0.11), Vector3.ZERO, leather_mat, dummy)
				_add_box_part(root, Vector3(0.030, 0.030, 0.034), Vector3(0.0, 0.095, 0.03), Vector3.ZERO, brass_mat, dummy)
				_add_box_part(root, Vector3(0.030, 0.030, 0.034), Vector3(0.0, 0.095, -0.11), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.052, 0.052, 0.024, Vector3(0.0, 0.096, -0.04), Vector3.ZERO, brass_mat, 14, dummy)
				_add_cyl_part(root, 0.044, 0.044, 0.026, Vector3(0.0, 0.098, -0.04), Vector3.ZERO, white_dial_mat, 14, dummy)
				_add_box_part(root, Vector3(0.006, 0.030, 0.028), Vector3(0.008, 0.100, -0.04), Vector3(0.0, 0.45, 0.0), metal_mat, dummy)
				_add_cyl_part(root, 0.006, 0.006, 0.09, Vector3(0.035, 0.055, 0.08), Vector3(0.4, 0.2, 0.5), copper_mat, 8, dummy)
				_add_cyl_part(root, 0.006, 0.006, 0.09, Vector3(-0.035, 0.055, 0.08), Vector3(-0.4, -0.2, 0.5), copper_mat, 8, dummy)
			info["grip"] = Vector3(0.0, -0.02, 0.02)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.0, -0.16)
			info["two_handed"] = false

		8: # Flamethrower (arch 0=Industrial Fuel Tank + Igniter, 1=Double-Tank Napalm, 2=Dragon-Head Fire Cannon)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.02), Vector3(-0.24, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.072, 0.078, 0.34), Vector3(0.0, 0.025, -0.10), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.042, 0.042, 0.24, Vector3(-0.048, -0.025, -0.14), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy)
				_add_cyl_part(root, 0.042, 0.042, 0.24, Vector3(0.048, -0.025, -0.14), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy)
				_add_cyl_part(root, 0.022, 0.022, 0.34, Vector3(0.0, 0.034, -0.42), Vector3(PI * 0.5, 0.0, 0.0), copper_mat, 12, dummy)
				_add_cyl_part(root, 0.042, 0.028, 0.11, Vector3(0.0, 0.034, -0.62), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				_add_box_part(root, Vector3(0.056, 0.022, 0.08), Vector3(0.0, -0.012, -0.58), Vector3.ZERO, steel_mat, dummy)
				info["foregrip"] = Vector3(0.0, -0.055, -0.22)
				info["muzzle"] = Vector3(0.0, 0.034, -0.68)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.02), Vector3(-0.22, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.074, 0.084, 0.38), Vector3(0.0, 0.026, -0.12), Vector3.ZERO, copper_mat, dummy)
				_add_cyl_part(root, 0.054, 0.054, 0.28, Vector3(0.0, -0.042, -0.15), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 14, dummy)
				_add_cyl_part(root, 0.030, 0.024, 0.48, Vector3(0.0, 0.034, -0.52), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 12, dummy)
				var snout := make_loft([
					{"y": 0.00, "rx": 0.038, "rz": 0.038, "p": 2.2},
					{"y": 0.10, "rx": 0.058, "rz": 0.054, "p": 2.4},
					{"y": 0.18, "rx": 0.046, "rz": 0.044, "p": 2.2},
				], 12)
				add_part(root, snout, Vector3(0.0, 0.034, -0.74), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, dummy)
				_add_box_part(root, Vector3(0.016, 0.045, 0.14), Vector3(0.0, 0.082, -0.76), Vector3(0.18, 0.0, 0.0), red_dyn_mat, dummy)
				info["foregrip"] = Vector3(0.0, -0.055, -0.25)
				info["muzzle"] = Vector3(0.0, 0.034, -0.92)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.02), Vector3(-0.24, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.064, 0.070, 0.34), Vector3(0.0, 0.024, -0.10), Vector3.ZERO, baz_mat, dummy)
				_add_cyl_part(root, 0.048, 0.048, 0.24, Vector3(0.0, -0.048, -0.14), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 14, dummy)
				_add_cyl_part(root, 0.020, 0.020, 0.34, Vector3(0.0, 0.032, -0.40), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 12, dummy)
				_add_cyl_part(root, 0.032, 0.024, 0.09, Vector3(0.0, 0.032, -0.58), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				_add_cyl_part(root, 0.008, 0.008, 0.10, Vector3(0.0, 0.006, -0.54), Vector3(PI * 0.5, 0.0, 0.0), copper_mat, 8, dummy)
				info["foregrip"] = Vector3(0.0, -0.055, -0.22)
				info["muzzle"] = Vector3(0.0, 0.032, -0.64)

		9: # Grenade Launcher (arch 0=6-Chamber Drum "Drum", 1=Twin-Rail Sticky Trapper, 2=Pirate Cannon "Warhead")
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.26, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.046, 0.088, 0.24), Vector3(0.0, -0.005, 0.14), Vector3.ZERO, metal_mat, dummy)
				_add_box_part(root, Vector3(0.068, 0.072, 0.28), Vector3(0.0, 0.026, -0.10), Vector3.ZERO, blued_metal_mat, dummy)
				_add_box_part(root, Vector3(0.058, 0.020, 0.34), Vector3(0.0, 0.066, -0.36), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.058, 0.020, 0.34), Vector3(0.0, 0.006, -0.36), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.028, 0.028, 0.05, Vector3(0.0, 0.036, -0.32), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 12, dummy)
				_add_cyl_part(root, 0.028, 0.028, 0.05, Vector3(0.0, 0.036, -0.46), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 12, dummy)
				_add_cyl_part(root, 0.054, 0.054, 0.09, Vector3(0.0, -0.025, -0.15), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				info["foregrip"] = Vector3(0.0, -0.015, -0.26)
				info["muzzle"] = Vector3(0.0, 0.036, -0.56)
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.050, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.062, 0.105, 0.28), Vector3(0.0, -0.012, 0.15), Vector3.ZERO, wood_mat, dummy)
				var cannon_brl := make_loft([
					{"y": 0.00, "rx": 0.072, "rz": 0.072, "p": 2.0},
					{"y": 0.24, "rx": 0.062, "rz": 0.062, "p": 2.0},
					{"y": 0.54, "rx": 0.056, "rz": 0.056, "p": 2.0},
					{"y": 0.62, "rx": 0.078, "rz": 0.078, "p": 2.0},
				], 14)
				add_part(root, cannon_brl, Vector3(0.0, 0.036, 0.02), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				_add_cyl_part(root, 0.080, 0.080, 0.04, Vector3(0.0, 0.036, -0.58), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 14, dummy)
				_add_cyl_part(root, 0.048, 0.048, 0.08, Vector3(0.0, 0.036, -0.60), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 12, dummy, "Warhead")
				info["foregrip"] = Vector3(0.0, -0.020, -0.26)
				info["muzzle"] = Vector3(0.0, 0.036, -0.65)
			else:
				add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.26, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.048, 0.092, 0.24), Vector3(0.0, -0.008, 0.14), Vector3.ZERO, wood_mat, dummy)
				_add_box_part(root, Vector3(0.058, 0.062, 0.20), Vector3(0.0, 0.028, -0.08), Vector3.ZERO, metal_mat, dummy)
				_add_cyl_part(root, 0.068, 0.068, 0.12, Vector3(0.0, 0.024, -0.14), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 12, dummy, "Drum")
				_add_cyl_part(root, 0.030, 0.028, 0.28, Vector3(0.0, 0.034, -0.34), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 12, dummy)
				_add_cyl_part(root, 0.038, 0.036, 0.04, Vector3(0.0, 0.034, -0.47), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				info["foregrip"] = Vector3(0.0, -0.018, -0.27)
				info["muzzle"] = Vector3(0.0, 0.034, -0.50)

		10: # Stick Grenade (Caber: wooden shaft + iron pommel + segmented explosive head "CaberHead")
			_add_cyl_part(root, 0.020, 0.018, 0.28, Vector3(0.0, 0.0, -0.06), Vector3(PI * 0.5, 0.0, 0.0), wood_mat, 10, dummy)
			_add_cyl_part(root, 0.024, 0.022, 0.04, Vector3(0.0, 0.0, 0.09), Vector3(PI * 0.5, 0.0, 0.0), metal_mat, 10, dummy)
			_add_cyl_part(root, 0.054, 0.054, 0.13, Vector3(0.0, 0.0, -0.25), Vector3(PI * 0.5, 0.0, 0.0), baz_mat, 12, dummy, "CaberHead")
			_add_cyl_part(root, 0.056, 0.056, 0.025, Vector3(0.0, 0.0, -0.25), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 12, dummy)
			info["grip"] = Vector3(0.0, 0.0, 0.01)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.0, -0.34)
			info["two_handed"] = false

		11: # Dual Revolvers (Single-handed steel six-shooter with brass frame & wood grip)
			add_part(root, p_grip, Vector3(0.0, -0.058, -0.01), Vector3(0.32, 0.0, 0.0), wood_mat, dummy)
			_add_box_part(root, Vector3(0.030, 0.044, 0.11), Vector3(0.0, 0.024, -0.04), Vector3.ZERO, brass_mat, dummy)
			_add_cyl_part(root, 0.032, 0.032, 0.068, Vector3(0.0, 0.030, -0.055), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 12, dummy)
			_add_cyl_part(root, 0.016, 0.014, 0.20, Vector3(0.0, 0.038, -0.19), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
			_add_box_part(root, Vector3(0.012, 0.014, 0.19), Vector3(0.0, 0.056, -0.19), Vector3.ZERO, brass_mat, dummy)
			info["grip"] = Vector3(0.0, -0.045, 0.0)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.038, -0.29)
			info["two_handed"] = false

		12: # Dual Pistols (Single-handed blued-steel semi-auto with brass accent)
			add_part(root, p_grip, Vector3(0.0, -0.062, -0.015), Vector3(0.24, 0.0, 0.0), metal_mat, dummy)
			_add_box_part(root, Vector3(0.032, 0.042, 0.22), Vector3(0.0, 0.032, -0.08), Vector3.ZERO, blued_metal_mat, dummy)
			_add_box_part(root, Vector3(0.024, 0.012, 0.18), Vector3(0.0, 0.054, -0.08), Vector3.ZERO, brass_mat, dummy)
			_add_cyl_part(root, 0.012, 0.012, 0.08, Vector3(0.0, 0.032, -0.21), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
			info["grip"] = Vector3(0.0, -0.045, 0.0)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.032, -0.25)
			info["two_handed"] = false

		13: # Welding Torch (Regulator brass fuel canister + copper swan-neck nozzle + glowing tip)
			add_part(root, p_grip, Vector3(0.0, -0.052, 0.0), Vector3(0.22, 0.0, 0.0), wood_mat, dummy)
			_add_cyl_part(root, 0.044, 0.044, 0.18, Vector3(0.0, -0.010, -0.06), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
			_add_box_part(root, Vector3(0.046, 0.050, 0.22), Vector3(0.0, 0.030, -0.08), Vector3.ZERO, steel_mat, dummy)
			_add_cyl_part(root, 0.016, 0.013, 0.26, Vector3(0.0, 0.040, -0.28), Vector3(PI * 0.5, 0.0, 0.0), copper_mat, 10, dummy)
			_add_cyl_part(root, 0.020, 0.012, 0.06, Vector3(0.0, 0.040, -0.43), Vector3(PI * 0.5, 0.0, 0.0), lens_mat, 10, dummy)
			info["grip"] = Vector3(0.0, -0.040, 0.0)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.040, -0.46)
			info["two_handed"] = false

		_: # Service Pistol (arch 0=Classic Slide, 1=Suppressed Tactical Auto, 2=Brass Six-Shooter Revolver)
			if arch == 1:
				add_part(root, p_grip, Vector3(0.0, -0.062, -0.015), Vector3(0.24, 0.0, 0.0), metal_mat, dummy)
				_add_box_part(root, Vector3(0.024, 0.075, 0.034), Vector3(0.0, -0.078, -0.018), Vector3(0.24, 0.0, 0.0), copper_mat, dummy)
				_add_box_part(root, Vector3(0.032, 0.042, 0.22), Vector3(0.0, 0.032, -0.07), Vector3.ZERO, steel_mat, dummy)
				_add_cyl_part(root, 0.022, 0.022, 0.16, Vector3(0.0, 0.034, -0.26), Vector3(PI * 0.5, 0.0, 0.0), blued_metal_mat, 12, dummy)
				_add_cyl_part(root, 0.024, 0.024, 0.018, Vector3(0.0, 0.034, -0.19), Vector3(PI * 0.5, 0.0, 0.0), brass_mat, 12, dummy)
				info["grip"] = Vector3(0.0, -0.045, 0.0)
				info["foregrip"] = Vector3(-0.015, -0.055, -0.01)
				info["muzzle"] = Vector3(0.0, 0.034, -0.35)
				info["two_handed"] = true
			elif arch == 2:
				add_part(root, p_grip, Vector3(0.0, -0.058, -0.01), Vector3(0.32, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.030, 0.044, 0.11), Vector3(0.0, 0.024, -0.04), Vector3.ZERO, brass_mat, dummy)
				_add_cyl_part(root, 0.032, 0.032, 0.068, Vector3(0.0, 0.030, -0.055), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 12, dummy)
				_add_cyl_part(root, 0.016, 0.014, 0.20, Vector3(0.0, 0.038, -0.19), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 10, dummy)
				_add_box_part(root, Vector3(0.012, 0.014, 0.19), Vector3(0.0, 0.056, -0.19), Vector3.ZERO, brass_mat, dummy)
				info["grip"] = Vector3(0.0, -0.045, 0.0)
				info["foregrip"] = Vector3(-0.015, -0.055, -0.01)
				info["muzzle"] = Vector3(0.0, 0.038, -0.29)
				info["two_handed"] = true
			else:
				var pist_grip := make_loft([
					{"y": 0.00, "rx": 0.016, "rz": 0.024, "p": 2.2},
					{"y": 0.11, "rx": 0.018, "rz": 0.022, "p": 2.2},
				], 10)
				add_part(root, pist_grip, Vector3(0.0, -0.095, -0.015), Vector3(0.24, 0.0, 0.0), wood_mat, dummy)
				_add_box_part(root, Vector3(0.012, 0.035, 0.045), Vector3(0.0, -0.015, -0.045), Vector3.ZERO, metal_mat, dummy)
				_add_box_part(root, Vector3(0.006, 0.018, 0.010), Vector3(0.0, -0.012, -0.035), Vector3(-0.2, 0.0, 0.0), brass_mat, dummy)
				var slide := make_loft([
					{"y": 0.00, "rx": 0.018, "rz": 0.024, "p": 2.1},
					{"y": 0.22, "rx": 0.018, "rz": 0.024, "p": 2.1},
				], 12)
				add_part(root, slide, Vector3(0.0, 0.032, 0.03), Vector3(-PI * 0.5, 0.0, 0.0), blued_metal_mat, dummy)
				_add_box_part(root, Vector3(0.016, 0.008, 0.008), Vector3(0.0, 0.058, 0.01), Vector3.ZERO, steel_mat, dummy)
				_add_box_part(root, Vector3(0.006, 0.010, 0.008), Vector3(0.0, 0.058, -0.18), Vector3.ZERO, steel_mat, dummy)
				info["grip"] = Vector3(0.0, -0.045, 0.0)
				info["foregrip"] = Vector3(-0.015, -0.055, -0.01)
				info["muzzle"] = Vector3(0.0, 0.035, -0.21)
				info["two_handed"] = true

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var cached_parts: Array[Dictionary] = []
	var parts_by_name: Dictionary = {}
	for ch in root.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 220.0
			var part_name: String = String(mi.name)
			if part_name.begins_with("@"):
				part_name = ""
			if not part_name.is_empty():
				parts_by_name[part_name] = mi
			cached_parts.append({
				"mesh": mi.mesh,
				"pos": mi.position,
				"base_pos": mi.position,
				"rot": mi.rotation,
				"mat": mi.material_override,
				"name": part_name,
			})
	_weapon_cache[cache_key] = {"info": info.duplicate(), "parts": cached_parts}
	info["parts_by_name"] = parts_by_name
	return info


## Builds the spinning bundled TNT Rope ("TntRope") held in hand when Demolisher Skill 2 is active.
static func populate_tnt_rope_root(root: Node3D) -> Dictionary:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bundle := Node3D.new()
	bundle.name = "TntRope"
	root.add_child(bundle)

	var red_dyn_mat := make_sculpted_mat(Color(0.86, 0.16, 0.14), "", 0.60)
	var rope_mat := make_sculpted_mat(Color(0.74, 0.56, 0.28), "", 0.78)
	var wood_mat := make_sculpted_mat(Color.WHITE, "hero_gun_wood", 0.65)
	var brass_mat := make_sculpted_mat(Color(0.78, 0.62, 0.24), "", 0.35, 0.55)
	var spark_mat := make_sculpted_mat(Color(1.0, 0.85, 0.22), "", 0.20)
	var dummy: Array[MeshInstance3D] = []

	# Lasso handle grip at Vector3.ZERO (hand hold) + taut 0.72m radial rope extending along -Z
	var handle := _add_cyl_part(bundle, 0.024, 0.026, 0.14, Vector3.ZERO, Vector3.ZERO, wood_mat, 10, dummy, "LassoHandle")
	handle.visibility_range_end = 220.0
	var grip_knot := _add_cyl_part(bundle, 0.032, 0.032, 0.036, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, rope_mat, 10, dummy, "LassoKnot")
	grip_knot.visibility_range_end = 220.0
	var radial_rope := _add_cyl_part(bundle, 0.014, 0.014, 0.72, Vector3(0.0, 0.0, -0.36), Vector3(PI * 0.5, 0.0, 0.0), rope_mat, 8, dummy, "RadialRope")
	radial_rope.visibility_range_end = 220.0

	var torus_key := "torus|0.0850,0.1080|14,8"
	var lasso_loop: TorusMesh = _prim_cache.get(torus_key)
	if lasso_loop == null:
		lasso_loop = TorusMesh.new()
		lasso_loop.inner_radius = 0.085
		lasso_loop.outer_radius = 0.108
		lasso_loop.rings = 14
		lasso_loop.ring_segments = 8
		_prim_cache[torus_key] = lasso_loop
	var hand_loop := add_part(bundle, lasso_loop, Vector3(0.0, -0.02, -0.04), Vector3(0.18, 0.0, 0.0), rope_mat, dummy, "LassoLoop")
	hand_loop.visibility_range_end = 220.0

	# 4-stick dynamite bundle mounted at the OUTER TIP of the rope (z = -0.68)
	var stick_idx: int = 0
	for dx in [-0.044, 0.044]:
		for dy in [-0.044, 0.044]:
			var stick := _add_cyl_part(bundle, 0.036, 0.036, 0.24, Vector3(dx, dy, -0.68), Vector3(PI * 0.5, 0.0, 0.0), red_dyn_mat, 10, dummy, "DynamiteStick_%d" % stick_idx)
			stick.visibility_range_end = 220.0
			stick_idx += 1
	var strap_a := _add_box_part(bundle, Vector3(0.18, 0.18, 0.032), Vector3(0.0, 0.0, -0.62), Vector3.ZERO, rope_mat, dummy)
	strap_a.visibility_range_end = 220.0
	var strap_b := _add_box_part(bundle, Vector3(0.18, 0.18, 0.032), Vector3(0.0, 0.0, -0.74), Vector3.ZERO, rope_mat, dummy)
	strap_b.visibility_range_end = 220.0
	var cap := _add_cyl_part(bundle, 0.024, 0.024, 0.06, Vector3(0.0, 0.095, -0.68), Vector3.ZERO, brass_mat, 10, dummy)
	cap.visibility_range_end = 220.0
	var spark := _add_box_part(bundle, Vector3(0.036, 0.036, 0.036), Vector3(0.02, 0.14, -0.68), Vector3(0.4, 0.5, 0.2), spark_mat, dummy)
	spark.visibility_range_end = 220.0

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return {
		"bundle": bundle,
		"grip": Vector3.ZERO,
		"foregrip": Vector3.ZERO,
		"muzzle": Vector3(0.0, 0.0, -0.78),
		"two_handed": false,
	}


## Builds the Engineer's steel crescent wrench / hammer tool held during Skill 0..2 build channels.
static func populate_build_wrench_root(root: Node3D) -> Dictionary:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tool := Node3D.new()
	tool.name = "BuildWrench"
	root.add_child(tool)

	var grip_mat := make_sculpted_mat(Color(0.84, 0.44, 0.12), "", 0.65)
	var steel_mat := make_sculpted_mat(Color(0.56, 0.60, 0.66), "", 0.28, 0.78)
	var dark_steel_mat := make_sculpted_mat(Color(0.24, 0.27, 0.32), "", 0.36, 0.68)
	var brass_mat := make_sculpted_mat(Color(0.84, 0.66, 0.22), "", 0.32, 0.62)
	var parts: Array[MeshInstance3D] = []

	_add_cyl_part(tool, 0.022, 0.024, 0.17, Vector3(0.0, 0.02, 0.0), Vector3.ZERO, grip_mat, 10, parts, "WrenchGrip")
	_add_cyl_part(tool, 0.026, 0.026, 0.022, Vector3(0.0, -0.072, 0.0), Vector3.ZERO, dark_steel_mat, 10, parts, "WrenchPommel")
	_add_box_part(tool, Vector3(0.032, 0.24, 0.018), Vector3(0.0, 0.20, 0.0), Vector3.ZERO, steel_mat, parts, "WrenchShank")
	_add_cyl_part(tool, 0.044, 0.044, 0.024, Vector3(0.0, 0.34, 0.0), Vector3(PI * 0.5, 0.0, 0.0), steel_mat, 12, parts, "WrenchCollar")
	_add_box_part(tool, Vector3(0.022, 0.072, 0.022), Vector3(-0.029, 0.39, 0.0), Vector3(0.0, 0.0, 0.20), steel_mat, parts, "WrenchJawL")
	_add_box_part(tool, Vector3(0.022, 0.072, 0.022), Vector3(0.029, 0.39, 0.0), Vector3(0.0, 0.0, -0.20), steel_mat, parts, "WrenchJawR")
	_add_cyl_part(tool, 0.015, 0.015, 0.036, Vector3(0.0, 0.325, 0.012), Vector3(0.0, 0.0, PI * 0.5), brass_mat, 10, parts, "WrenchWormGear")
	_add_box_part(tool, Vector3(0.034, 0.044, 0.078), Vector3(0.0, 0.34, 0.024), Vector3.ZERO, dark_steel_mat, parts, "WrenchHammerPoll")

	for mi in parts:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 220.0

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return {
		"tool": tool,
		"grip": Vector3.ZERO,
		"foregrip": Vector3.ZERO,
		"muzzle": Vector3(0.0, 0.40, 0.0),
		"two_handed": false,
	}


## Builds Demolisher's carried 1.15m x 1.35m tactical ballistic riot shield with viewport, team trim & bolts.
static func build_carried_riot_shield(is_royal: bool) -> Node3D:
	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root := Node3D.new()
	root.name = "HeldRiotShield"

	var steel_mat := make_sculpted_mat(Color(0.20, 0.24, 0.29), "", 0.42, 0.50)
	var rim_mat := make_sculpted_mat(Color(0.12, 0.14, 0.18), "", 0.48, 0.45)
	var glass_mat := make_sculpted_mat(Color(0.45, 0.82, 0.98, 0.56), "", 0.14, 0.05)
	var team_col := Color(0.18, 0.46, 0.88) if is_royal else Color(0.84, 0.20, 0.20)
	var team_mat := make_sculpted_mat(team_col, "", 0.50)
	var bolt_mat := make_sculpted_mat(Color(0.76, 0.80, 0.86), "", 0.28, 0.72)
	var parts: Array[MeshInstance3D] = []

	_add_box_part(root, Vector3(1.15, 0.90, 0.09), Vector3(0.0, -0.225, 0.0), Vector3.ZERO, steel_mat, parts, "ShieldLowerPlate")
	_add_box_part(root, Vector3(1.15, 0.21, 0.10), Vector3(0.0, 0.57, 0.0), Vector3.ZERO, rim_mat, parts, "ShieldTopFrame")
	_add_box_part(root, Vector3(0.23, 0.24, 0.095), Vector3(-0.46, 0.345, 0.0), Vector3.ZERO, rim_mat, parts, "ShieldPillarL")
	_add_box_part(root, Vector3(0.23, 0.24, 0.095), Vector3(0.46, 0.345, 0.0), Vector3.ZERO, rim_mat, parts, "ShieldPillarR")
	_add_box_part(root, Vector3(0.69, 0.24, 0.05), Vector3(0.0, 0.345, 0.0), Vector3.ZERO, glass_mat, parts, "ShieldViewport")
	_add_box_part(root, Vector3(1.10, 0.12, 0.105), Vector3(0.0, 0.08, 0.0), Vector3.ZERO, team_mat, parts, "ShieldTeamTrim")
	_add_box_part(root, Vector3(0.045, 0.26, 0.065), Vector3(0.0, 0.08, 0.075), Vector3.ZERO, rim_mat, parts, "ShieldGrip")

	for bx in [-0.48, 0.48]:
		for by in [-0.56, 0.56]:
			_add_cyl_part(root, 0.032, 0.032, 0.115, Vector3(bx, by, 0.0), Vector3(PI * 0.5, 0.0, 0.0), bolt_mat, 8, parts)

	for mi in parts:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 220.0

	default_shadow_mode = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root
