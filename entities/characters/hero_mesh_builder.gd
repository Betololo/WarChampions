class_name HeroMeshBuilder
extends RefCounted

## Builds sculpted smooth cartoon hero parts (lofts with superellipse cross-sections,
## smooth vertex normals, painted fabric/skin textures, headgear, and detailed 3D weapons)
## matching classic Battlefield Heroes proportions instead of blocky primitives.


static func make_loft(rings: Array[Dictionary], radial_seg: int = 16, cap_ends: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	var ring_pts: Array = []
	var ring_cols: Array[Color] = []
	for r in rings:
		var ry: float = float(r.get("y", 0.0))
		var rx_off: float = float(r.get("x", 0.0))
		var rz_off: float = float(r.get("z", 0.0))
		var rx: float = maxf(0.004, float(r.get("rx", 0.1)))
		var rz: float = maxf(0.004, float(r.get("rz", 0.1)))
		var p: float = maxf(1.5, float(r.get("p", 2.0)))
		var exp_val: float = 2.0 / p
		var col: Color = r.get("col", Color.WHITE)
		ring_cols.append(col)

		var pts := PackedVector3Array()
		for i in range(radial_seg + 1):
			var a: float = (float(i) / float(radial_seg)) * TAU
			var sx: float = sin(a)
			var cz: float = -cos(a)
			var px: float = rx_off + signf(sx) * pow(absf(sx), exp_val) * rx
			var pz: float = rz_off + signf(cz) * pow(absf(cz), exp_val) * rz
			pts.append(Vector3(px, ry, pz))
		ring_pts.append(pts)

	var n_rings: int = ring_pts.size()
	for r_idx in range(n_rings - 1):
		var p0: PackedVector3Array = ring_pts[r_idx]
		var p1: PackedVector3Array = ring_pts[r_idx + 1]
		var c0: Color = ring_cols[r_idx]
		var c1: Color = ring_cols[r_idx + 1]
		var v0: float = float(r_idx) / float(maxi(1, n_rings - 1))
		var v1: float = float(r_idx + 1) / float(maxi(1, n_rings - 1))

		for i in range(radial_seg):
			var u0: float = float(i) / float(radial_seg)
			var u1: float = float(i + 1) / float(radial_seg)

			# Triangle A
			st.set_color(c0)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0[i])
			st.set_color(c0)
			st.set_uv(Vector2(u1, v0))
			st.add_vertex(p0[i + 1])
			st.set_color(c1)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p1[i + 1])

			# Triangle B
			st.set_color(c0)
			st.set_uv(Vector2(u0, v0))
			st.add_vertex(p0[i])
			st.set_color(c1)
			st.set_uv(Vector2(u1, v1))
			st.add_vertex(p1[i + 1])
			st.set_color(c1)
			st.set_uv(Vector2(u0, v1))
			st.add_vertex(p1[i])

	if cap_ends and n_rings >= 2:
		var bot_pts: PackedVector3Array = ring_pts[0]
		var bot_c := Vector3(float(rings[0].get("x", 0.0)), float(rings[0].get("y", 0.0)), float(rings[0].get("z", 0.0)))
		var bot_col: Color = ring_cols[0]
		for i in range(radial_seg):
			st.set_color(bot_col)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(bot_c)
			st.set_color(bot_col)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(bot_pts[i + 1])
			st.set_color(bot_col)
			st.set_uv(Vector2(0.5, 1.0))
			st.add_vertex(bot_pts[i])

		var top_pts: PackedVector3Array = ring_pts[n_rings - 1]
		var top_r: Dictionary = rings[n_rings - 1]
		var top_c := Vector3(float(top_r.get("x", 0.0)), float(top_r.get("y", 0.0)), float(top_r.get("z", 0.0)))
		var top_col: Color = ring_cols[n_rings - 1]
		for i in range(radial_seg):
			st.set_color(top_col)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(top_c)
			st.set_color(top_col)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(top_pts[i])
			st.set_color(top_col)
			st.set_uv(Vector2(0.5, 0.0))
			st.add_vertex(top_pts[i + 1])

	st.generate_normals()
	return st.commit()


static func add_part(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, parts_list: Array[MeshInstance3D]) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)
	parts_list.append(mi)
	return mi


static func make_sculpted_mat(col: Color, tex_key: String = "", roughness: float = 0.68) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.vertex_color_use_as_albedo = true
	if not tex_key.is_empty():
		mat.albedo_texture = CartoonAssets.get_texture(tex_key)
		mat.set_meta("tex_key", tex_key)
	mat.roughness = roughness
	return mat


static func build_torso_mesh(class_id: int) -> ArrayMesh:
	var c_shade := Color(0.84, 0.84, 0.88)
	var c_mid := Color(0.95, 0.95, 0.97)
	var c_lit := Color.WHITE
	if class_id == 1: # Gunner broad muscular V-chest
		return make_loft([
			{"y": -0.06, "rx": 0.21, "rz": 0.145, "p": 2.4, "col": c_shade},
			{"y": 0.06, "rx": 0.195, "rz": 0.135, "p": 2.5, "col": c_mid},
			{"y": 0.24, "rx": 0.27, "rz": 0.175, "p": 2.4, "col": c_lit},
			{"y": 0.44, "rx": 0.355, "rz": 0.205, "p": 2.4, "col": c_lit},
			{"y": 0.56, "rx": 0.33, "rz": 0.185, "p": 2.2, "col": c_lit},
			{"y": 0.63, "rx": 0.17, "rz": 0.135, "p": 2.0, "col": c_mid},
		], 18)
	elif class_id == 2: # Commando tailored trenchcoat
		return make_loft([
			{"y": -0.24, "rx": 0.26, "rz": 0.20, "p": 2.4, "col": c_shade},
			{"y": -0.02, "rx": 0.195, "rz": 0.145, "p": 2.4, "col": c_mid},
			{"y": 0.08, "rx": 0.175, "rz": 0.13, "p": 2.4, "col": c_shade},
			{"y": 0.30, "rx": 0.225, "rz": 0.155, "p": 2.4, "col": c_lit},
			{"y": 0.52, "rx": 0.28, "rz": 0.165, "p": 2.4, "col": c_lit},
			{"y": 0.61, "rx": 0.175, "rz": 0.135, "p": 2.2, "col": c_mid},
			{"y": 0.68, "rx": 0.145, "rz": 0.13, "p": 2.2, "col": c_shade},
		], 18)
	# Soldier iconic tailored jacket + hip skirt
	return make_loft([
		{"y": -0.14, "rx": 0.22, "rz": 0.16, "p": 2.4, "col": c_shade},
		{"y": 0.04, "rx": 0.185, "rz": 0.135, "p": 2.4, "col": c_shade},
		{"y": 0.22, "rx": 0.23, "rz": 0.16, "p": 2.5, "col": c_mid},
		{"y": 0.44, "rx": 0.295, "rz": 0.18, "p": 2.5, "col": c_lit},
		{"y": 0.57, "rx": 0.285, "rz": 0.165, "p": 2.2, "col": c_lit},
		{"y": 0.64, "rx": 0.145, "rz": 0.125, "p": 2.0, "col": c_mid},
	], 18)


static func build_head_mesh() -> ArrayMesh:
	# Smooth sculpted cartoon cranium with tapered square jaw (NO cubes!)
	return make_loft([
		{"y": 0.00, "rx": 0.078, "rz": 0.075, "p": 2.0, "col": Color(0.84, 0.80, 0.78)}, # neck base
		{"y": 0.08, "rx": 0.085, "rz": 0.082, "p": 2.1, "col": Color(0.90, 0.86, 0.84)},
		{"y": 0.11, "z": -0.015, "rx": 0.112, "rz": 0.118, "p": 3.0, "col": Color(0.95, 0.92, 0.90)}, # strong jaw
		{"y": 0.19, "z": -0.01, "rx": 0.122, "rz": 0.125, "p": 2.6, "col": Color.WHITE}, # cheeks
		{"y": 0.28, "z": 0.00, "rx": 0.124, "rz": 0.130, "p": 2.2, "col": Color.WHITE}, # brow
		{"y": 0.35, "z": 0.005, "rx": 0.110, "rz": 0.118, "p": 2.0, "col": Color.WHITE}, # forehead
		{"y": 0.39, "z": 0.008, "rx": 0.068, "rz": 0.072, "p": 2.0, "col": Color.WHITE}, # crown
	], 18)


static func build_hair_cap_mesh() -> ArrayMesh:
	# Back & top hair silhouette visible from behind in 3rd person!
	return make_loft([
		{"y": 0.14, "z": 0.055, "rx": 0.105, "rz": 0.088, "p": 2.2, "col": Color(0.85, 0.85, 0.85)}, # nape trim
		{"y": 0.24, "z": 0.032, "rx": 0.126, "rz": 0.115, "p": 2.1, "col": Color.WHITE},
		{"y": 0.34, "z": 0.012, "rx": 0.125, "rz": 0.128, "p": 2.0, "col": Color.WHITE},
		{"y": 0.40, "z": 0.005, "rx": 0.085, "rz": 0.092, "p": 2.0, "col": Color.WHITE},
	], 16)


static func build_beret_mesh() -> ArrayMesh:
	return make_loft([
		{"y": 0.00, "rx": 0.122, "rz": 0.128, "p": 2.1, "col": Color(0.82, 0.82, 0.85)},
		{"y": 0.035, "x": -0.025, "rx": 0.165, "rz": 0.160, "p": 2.0, "col": Color.WHITE},
		{"y": 0.085, "x": -0.030, "rx": 0.155, "rz": 0.150, "p": 2.0, "col": Color.WHITE},
		{"y": 0.115, "x": -0.020, "rx": 0.085, "rz": 0.085, "p": 2.0, "col": Color.WHITE},
	], 18)


static func build_fedora_mesh() -> ArrayMesh:
	return make_loft([
		{"y": 0.00, "rx": 0.32, "rz": 0.34, "p": 2.0, "col": Color(0.86, 0.86, 0.88)}, # curved wide brim outer
		{"y": 0.022, "rx": 0.22, "rz": 0.23, "p": 2.0, "col": Color.WHITE},
		{"y": 0.032, "rx": 0.135, "rz": 0.145, "p": 2.1, "col": Color(0.75, 0.75, 0.78)}, # hatband
		{"y": 0.095, "rx": 0.128, "rz": 0.140, "p": 2.2, "col": Color.WHITE},
		{"y": 0.140, "rx": 0.085, "rz": 0.105, "p": 2.3, "col": Color.WHITE}, # pinched crown
	], 20)


static func build_arm_segment_mesh(r_top: float, r_bot: float, length: float) -> ArrayMesh:
	return make_loft([
		{"y": -length, "rx": r_bot, "rz": r_bot, "p": 2.1, "col": Color(0.88, 0.88, 0.90)},
		{"y": -length * 0.5, "rx": (r_top + r_bot) * 0.54, "rz": (r_top + r_bot) * 0.54, "p": 2.1, "col": Color.WHITE},
		{"y": 0.0, "rx": r_top, "rz": r_top, "p": 2.0, "col": Color.WHITE},
	], 14)


static func build_leg_mesh(thigh_r: float) -> ArrayMesh:
	return make_loft([
		{"y": -0.58, "rx": thigh_r * 0.68, "rz": thigh_r * 0.68, "p": 2.1, "col": Color(0.82, 0.82, 0.86)},
		{"y": -0.34, "rx": thigh_r * 0.85, "rz": thigh_r * 0.88, "p": 2.1, "col": Color(0.95, 0.95, 0.97)},
		{"y": -0.02, "rx": thigh_r, "rz": thigh_r * 1.05, "p": 2.1, "col": Color.WHITE},
	], 14)


static func build_boot_mesh() -> ArrayMesh:
	return make_loft([
		{"y": -0.18, "z": -0.04, "rx": 0.082, "rz": 0.135, "p": 2.5, "col": Color(0.80, 0.80, 0.80)}, # sole
		{"y": -0.10, "z": -0.03, "rx": 0.080, "rz": 0.125, "p": 2.3, "col": Color.WHITE},
		{"y": 0.02, "z": 0.00, "rx": 0.072, "rz": 0.076, "p": 2.0, "col": Color.WHITE}, # cuff
	], 14)


static func populate_weapon_root(root: Node3D, w_kind: int) -> Dictionary:
	for c in root.get_children():
		c.queue_free()

	var metal_mat := make_sculpted_mat(Color(0.22, 0.24, 0.28), "", 0.45)
	var steel_mat := make_sculpted_mat(Color(0.46, 0.50, 0.54), "", 0.35)
	var brass_mat := make_sculpted_mat(Color(0.66, 0.54, 0.24), "", 0.40)
	var wood_mat := make_sculpted_mat(Color.WHITE, "hero_gun_wood", 0.65)
	var baz_mat := make_sculpted_mat(Color(0.26, 0.38, 0.22), "", 0.60)
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
		4: # Sniper Rifle (sleek walnut stock, pistol wrist, bolt receiver, elevated brass scope, long barrel)
			add_part(root, p_grip, Vector3(0.0, -0.045, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
			var stock := make_loft([
				{"y": 0.0, "rx": 0.024, "rz": 0.056, "p": 2.2, "col": Color(0.9, 0.9, 0.9)},
				{"y": 0.28, "rx": 0.028, "rz": 0.038, "p": 2.2, "col": Color.WHITE},
			], 12)
			add_part(root, stock, Vector3(0.0, -0.01, 0.26), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			var forend := make_loft([
				{"y": 0.0, "rx": 0.028, "rz": 0.036, "p": 2.2, "col": Color.WHITE},
				{"y": 0.38, "rx": 0.022, "rz": 0.028, "p": 2.1, "col": Color.WHITE},
			], 12)
			add_part(root, forend, Vector3(0.0, 0.005, 0.02), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			var rec_s := BoxMesh.new()
			rec_s.size = Vector3(0.050, 0.058, 0.26)
			add_part(root, rec_s, Vector3(0.0, 0.038, -0.10), Vector3.ZERO, metal_mat, dummy)
			var barrel := make_loft([
				{"y": 0.0, "rx": 0.017, "rz": 0.017, "p": 2.0},
				{"y": 0.52, "rx": 0.013, "rz": 0.013, "p": 2.0},
			], 10)
			add_part(root, barrel, Vector3(0.0, 0.042, -0.22), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
			var scope := make_loft([
				{"y": 0.0, "rx": 0.026, "rz": 0.026, "p": 2.0},
				{"y": 0.26, "rx": 0.028, "rz": 0.028, "p": 2.0},
			], 12)
			add_part(root, scope, Vector3(0.0, 0.095, 0.03), Vector3(-PI * 0.5, 0.0, 0.0), brass_mat, dummy)
			info["foregrip"] = Vector3(0.0, -0.015, -0.26)
			info["muzzle"] = Vector3(0.0, 0.042, -0.76)

		0: # SMG (compact MP40/Thompson chassis, walnut stock, curved vertical magazine)
			add_part(root, p_grip, Vector3(0.0, -0.050, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
			var butt_smg := make_loft([
				{"y": 0.0, "rx": 0.024, "rz": 0.048, "p": 2.3},
				{"y": 0.22, "rx": 0.026, "rz": 0.032, "p": 2.3},
			], 10)
			add_part(root, butt_smg, Vector3(0.0, -0.01, 0.22), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			var rec_smg := BoxMesh.new()
			rec_smg.size = Vector3(0.062, 0.068, 0.32)
			add_part(root, rec_smg, Vector3(0.0, 0.030, -0.14), Vector3.ZERO, metal_mat, dummy)
			var shroud := make_loft([
				{"y": 0.0, "rx": 0.022, "rz": 0.022, "p": 2.0},
				{"y": 0.22, "rx": 0.015, "rz": 0.015, "p": 2.0},
			], 10)
			add_part(root, shroud, Vector3(0.0, 0.035, -0.29), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
			var mag := BoxMesh.new()
			mag.size = Vector3(0.030, 0.18, 0.040)
			add_part(root, mag, Vector3(0.0, -0.08, -0.15), Vector3(0.18, 0.0, 0.0), metal_mat, dummy)
			info["foregrip"] = Vector3(0.0, -0.015, -0.23)
			info["muzzle"] = Vector3(0.0, 0.035, -0.52)

		1: # Heavy MG (Gunner hip-slung MG with ammo drum, heavy cooling shroud & top carry handle!)
			add_part(root, p_grip, Vector3(0.0, -0.040, 0.01), Vector3(-0.22, 0.0, 0.0), wood_mat, dummy)
			var mg_stock := BoxMesh.new()
			mg_stock.size = Vector3(0.058, 0.078, 0.20)
			add_part(root, mg_stock, Vector3(0.0, 0.010, 0.12), Vector3.ZERO, wood_mat, dummy)
			var mg_rec := BoxMesh.new()
			mg_rec.size = Vector3(0.092, 0.096, 0.34)
			add_part(root, mg_rec, Vector3(0.0, 0.025, -0.16), Vector3.ZERO, metal_mat, dummy)
			var jacket := make_loft([
				{"y": 0.0, "rx": 0.042, "rz": 0.042, "p": 2.0},
				{"y": 0.32, "rx": 0.036, "rz": 0.036, "p": 2.0},
			], 12)
			add_part(root, jacket, Vector3(0.0, 0.030, -0.32), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
			var mg_brl := CylinderMesh.new()
			mg_brl.top_radius = 0.016
			mg_brl.bottom_radius = 0.020
			mg_brl.height = 0.16
			add_part(root, mg_brl, Vector3(0.0, 0.030, -0.66), Vector3(-PI * 0.5, 0.0, 0.0), metal_mat, dummy)
			var drum := CylinderMesh.new()
			drum.top_radius = 0.095
			drum.bottom_radius = 0.095
			drum.height = 0.11
			add_part(root, drum, Vector3(-0.08, -0.03, -0.16), Vector3(0.0, 0.0, PI * 0.5), baz_mat, dummy)
			var belt := BoxMesh.new()
			belt.size = Vector3(0.03, 0.04, 0.14)
			add_part(root, belt, Vector3(-0.07, 0.03, -0.16), Vector3.ZERO, brass_mat, dummy)
			var handle := BoxMesh.new()
			handle.size = Vector3(0.028, 0.065, 0.14)
			add_part(root, handle, Vector3(-0.02, 0.105, -0.20), Vector3.ZERO, wood_mat, dummy)
			info["foregrip"] = Vector3(-0.03, 0.10, -0.22)
			info["muzzle"] = Vector3(0.0, 0.030, -0.74)

		2: # Combat Shotgun
			add_part(root, p_grip, Vector3(0.0, -0.042, 0.01), Vector3(-0.28, 0.0, 0.0), wood_mat, dummy)
			var s_butt := make_loft([
				{"y": 0.0, "rx": 0.028, "rz": 0.052, "p": 2.3},
				{"y": 0.25, "rx": 0.028, "rz": 0.040, "p": 2.3},
			], 12)
			add_part(root, s_butt, Vector3(0.0, -0.01, 0.26), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			var s_rec := BoxMesh.new()
			s_rec.size = Vector3(0.056, 0.068, 0.22)
			add_part(root, s_rec, Vector3(0.0, 0.030, -0.09), Vector3.ZERO, metal_mat, dummy)
			var s_brl := make_loft([
				{"y": 0.0, "rx": 0.020, "rz": 0.020, "p": 2.0},
				{"y": 0.38, "rx": 0.018, "rz": 0.018, "p": 2.0},
			], 10)
			add_part(root, s_brl, Vector3(0.0, 0.045, -0.19), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
			var pump := make_loft([
				{"y": 0.0, "rx": 0.026, "rz": 0.028, "p": 2.2},
				{"y": 0.18, "rx": 0.026, "rz": 0.028, "p": 2.2},
			], 10)
			add_part(root, pump, Vector3(0.0, 0.008, -0.22), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			info["foregrip"] = Vector3(0.0, -0.015, -0.29)
			info["muzzle"] = Vector3(0.0, 0.045, -0.58)

		6: # Bazooka (shoulder tube balanced around trigger grip at Y=-0.10, Z=0)
			var tube := make_loft([
				{"y": 0.0, "rx": 0.092, "rz": 0.092, "p": 2.0},
				{"y": 0.14, "rx": 0.068, "rz": 0.068, "p": 2.0},
				{"y": 1.12, "rx": 0.070, "rz": 0.070, "p": 2.0},
				{"y": 1.24, "rx": 0.096, "rz": 0.096, "p": 2.0},
			], 14)
			add_part(root, tube, Vector3(0.0, 0.0, 0.42), Vector3(-PI * 0.5, 0.0, 0.0), baz_mat, dummy)
			add_part(root, p_grip, Vector3(0.0, -0.10, 0.0), Vector3(-0.18, 0.0, 0.0), wood_mat, dummy)
			add_part(root, p_grip, Vector3(0.0, -0.095, -0.24), Vector3(0.0, 0.0, 0.0), metal_mat, dummy)
			info["grip"] = Vector3(0.0, -0.11, 0.0)
			info["foregrip"] = Vector3(0.0, -0.105, -0.24)
			info["muzzle"] = Vector3(0.0, 0.0, -0.85)

		5: # Commando Knife (tactical dagger held in palm)
			var hdl := CylinderMesh.new()
			hdl.top_radius = 0.022
			hdl.bottom_radius = 0.022
			hdl.height = 0.12
			add_part(root, hdl, Vector3(0.0, 0.0, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), wood_mat, dummy)
			var guard := BoxMesh.new()
			guard.size = Vector3(0.075, 0.018, 0.018)
			add_part(root, guard, Vector3(0.0, 0.0, -0.065), Vector3.ZERO, brass_mat, dummy)
			var blade := make_loft([
				{"y": 0.0, "rx": 0.008, "rz": 0.026, "p": 2.5},
				{"y": 0.22, "rx": 0.004, "rz": 0.005, "p": 2.0},
			], 8)
			add_part(root, blade, Vector3(0.0, 0.005, -0.075), Vector3(-PI * 0.5, 0.0, 0.0), steel_mat, dummy)
			info["grip"] = Vector3(0.0, 0.0, 0.01)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.005, -0.30)
			info["two_handed"] = false

		7: # TNT Satchel
			var pack := BoxMesh.new()
			pack.size = Vector3(0.18, 0.13, 0.12)
			add_part(root, pack, Vector3(0.0, 0.0, -0.04), Vector3.ZERO, make_sculpted_mat(Color(0.84, 0.18, 0.16), "", 0.6), dummy)
			var strap := BoxMesh.new()
			strap.size = Vector3(0.19, 0.035, 0.13)
			add_part(root, strap, Vector3(0.0, 0.0, -0.04), Vector3.ZERO, metal_mat, dummy)
			info["grip"] = Vector3(0.0, -0.02, 0.02)
			info["foregrip"] = Vector3.ZERO
			info["muzzle"] = Vector3(0.0, 0.0, -0.16)
			info["two_handed"] = false

		_: # Service Pistol
			add_part(root, p_grip, Vector3(0.0, -0.045, 0.0), Vector3(-0.22, 0.0, 0.0), wood_mat, dummy)
			var slide := BoxMesh.new()
			slide.size = Vector3(0.038, 0.052, 0.22)
			add_part(root, slide, Vector3(0.0, 0.032, -0.08), Vector3.ZERO, metal_mat, dummy)
			info["grip"] = Vector3(0.0, -0.045, 0.0)
			info["foregrip"] = Vector3(-0.015, -0.055, -0.01)
			info["muzzle"] = Vector3(0.0, 0.035, -0.21)
			info["two_handed"] = true

	return info
