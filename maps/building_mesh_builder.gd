class_name BuildingMeshBuilder
extends RefCounted

## Builds sculpted Battlefield Heroes Mediterranean/European cartoon buildings,
## landmarks (CentralFountain, Mercadinho, ChurchChapel, Windmill, CoastalLighthouse,
## climbable Watchtowers, Airstrip complexes, Harbor Piers), and layered trees.
##
## Rules enforced everywhere:
## - Opaque materials (alpha >= 0.99) strictly use TRANSPARENCY_DISABLED.
## - Translucent materials (windows, beacon glass, fountain water) use alpha < 0.99 + TRANSPARENCY_ALPHA.
## - Every HeroMeshBuilder.make_loft call keeps y strictly ascending and positive radii (bad_vol == 0).
## - Local front direction is +Z (yaw = 0 faces +Z South, PI faces -Z North, PI/2 faces +X East, -PI/2 faces -X West).


static func make_mat(
	col: Color,
	tex_key: String = "",
	roughness: float = 0.80,
	metallic: float = 0.04,
	alpha: float = 1.0,
	uv_scale: Vector2 = Vector2.ONE
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var final_col: Color = col
	if alpha >= 0.99:
		final_col.a = 1.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	else:
		final_col.a = alpha
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = final_col
	mat.vertex_color_use_as_albedo = true
	mat.roughness = roughness
	mat.metallic = metallic
	if not tex_key.is_empty():
		mat.albedo_texture = CartoonAssets.get_texture(tex_key)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	return mat


static func _make_palette() -> Dictionary:
	var glass_mat := make_mat(Color(0.54, 0.80, 0.96), "", 0.12, 0.10, 0.56)
	var beacon_glass := make_mat(Color(1.0, 0.92, 0.58), "", 0.08, 0.10, 0.48)
	var glow_gold := make_mat(Color(1.0, 0.90, 0.42), "", 0.20, 0.0)
	glow_gold.emission_enabled = true
	glow_gold.emission = Color(1.0, 0.84, 0.32)
	glow_gold.emission_energy_multiplier = 2.4
	var fountain_water := make_mat(Color(0.84, 0.98, 1.0), "water_fountain", 0.14, 0.06, 0.84, Vector2(2.0, 2.0))
	return {
		"stone": make_mat(Color.WHITE, "stone_masonry", 0.86, 0.02, 1.0, Vector2(2.5, 1.5)),
		"stone_trim": make_mat(Color(0.84, 0.81, 0.76), "stone_masonry", 0.84, 0.02, 1.0, Vector2(1.2, 1.0)),
		"ochre": make_mat(Color.WHITE, "stucco_ochre", 0.84, 0.02, 1.0, Vector2(2.0, 1.5)),
		"terracotta_wall": make_mat(Color.WHITE, "stucco_terracotta", 0.84, 0.02, 1.0, Vector2(2.0, 1.5)),
		"cream": make_mat(Color.WHITE, "stucco_cream", 0.82, 0.02, 1.0, Vector2(2.0, 1.5)),
		"whitewash": make_mat(Color(0.98, 0.97, 0.94), "stucco_cream", 0.80, 0.02, 1.0, Vector2(2.0, 2.0)),
		"roof": make_mat(Color.WHITE, "roof_terracotta", 0.78, 0.04, 1.0, Vector2(4.0, 2.5)),
		"slate": make_mat(Color.WHITE, "slate_roof", 0.76, 0.08, 1.0, Vector2(3.0, 2.0)),
		"shingle": make_mat(Color.WHITE, "wood_shingle", 0.82, 0.02, 1.0, Vector2(2.5, 2.0)),
		"timber_dark": make_mat(Color(0.32, 0.20, 0.11), "bark", 0.82, 0.02, 1.0, Vector2(1.0, 2.0)),
		"timber_warm": make_mat(Color(0.62, 0.42, 0.22), "veh_wood_deck", 0.78, 0.02, 1.0, Vector2(2.0, 2.0)),
		"door_oak": make_mat(Color(0.46, 0.27, 0.14), "wood_crate", 0.76, 0.04, 1.0, Vector2(1.0, 1.5)),
		"shutter_blue": make_mat(Color(0.20, 0.48, 0.78), "", 0.68, 0.05),
		"shutter_green": make_mat(Color(0.22, 0.52, 0.28), "", 0.68, 0.05),
		"awning_red": make_mat(Color.WHITE, "awning_stripe", 0.76, 0.02, 1.0, Vector2(2.0, 1.0)),
		"awning_blue": make_mat(Color.WHITE, "awning_stripe_blue", 0.76, 0.02, 1.0, Vector2(2.0, 1.0)),
		"cobble": make_mat(Color.WHITE, "cobble", 0.84, 0.02, 1.0, Vector2(4.0, 4.0)),
		"tarmac": make_mat(Color.WHITE, "tarmac_runway", 0.88, 0.04, 1.0, Vector2(18.0, 2.5)),
		"iron": make_mat(Color(0.18, 0.20, 0.23), "", 0.48, 0.55),
		"brass": make_mat(Color(0.88, 0.70, 0.24), "", 0.34, 0.65),
		"red_paint": make_mat(Color(0.84, 0.16, 0.14), "", 0.55, 0.08),
		"white_paint": make_mat(Color(0.96, 0.96, 0.94), "", 0.58, 0.04),
		"yellow_paint": make_mat(Color(0.96, 0.80, 0.16), "", 0.55, 0.06),
		"sandbag": make_mat(Color.WHITE, "veh_sandbag", 0.92, 0.02, 1.0, Vector2(2.0, 1.0)),
		"canvas": make_mat(Color(0.95, 0.92, 0.82), "", 0.84, 0.02),
		"foliage": make_mat(Color.WHITE, "foliage", 0.84, 0.02, 1.0, Vector2(2.0, 2.0)),
		"glass": glass_mat,
		"beacon_glass": beacon_glass,
		"glow_gold": glow_gold,
		"water": fountain_water,
	}


static func _make_static_body(parent: Node3D, node_name: String, origin: Vector3, yaw: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = origin
	body.rotation.y = yaw
	parent.add_child(body, true)
	return body


static func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
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
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(parent, m, pos, rot, mat, p_name)


static func _add_cyl(
	parent: Node3D,
	r_top: float,
	r_bot: float,
	height: float,
	pos: Vector3,
	rot: Vector3,
	mat: Material,
	segs: int = 14,
	p_name: String = ""
) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = height
	c.radial_segments = segs
	return _add_mesh(parent, c, pos, rot, mat, p_name)


static func _add_prism(parent: Node3D, size: Vector3, pos: Vector3, rot: Vector3, mat: Material, p_name: String = "") -> MeshInstance3D:
	var p := PrismMesh.new()
	p.left_to_right = 0.5
	p.size = size
	return _add_mesh(parent, p, pos, rot, mat, p_name)


static func _add_box_col(body: StaticBody3D, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	col.rotation = rot
	body.add_child(col)
	return col


static func _add_cyl_col(body: StaticBody3D, radius: float, height: float, pos: Vector3) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = pos
	body.add_child(col)
	return col


static func _add_ramp_between(
	body: StaticBody3D,
	p_start: Vector3,
	p_end: Vector3,
	width: float,
	thickness: float,
	mat: Material,
	add_steps: bool = false,
	step_mat: Material = null
) -> void:
	var diff: Vector3 = p_end - p_start
	var length: float = diff.length()
	var horiz_len: float = Vector2(diff.x, diff.z).length()
	var yaw: float = atan2(diff.x, diff.z)
	var pitch: float = -atan2(diff.y, maxf(0.01, horiz_len))
	var rot := Vector3(pitch, yaw, 0.0)
	var up_n: Vector3 = Basis.from_euler(rot).y
	var mid: Vector3 = (p_start + p_end) * 0.5 - up_n * (thickness * 0.5)
	# Smooth invisible collision ramp + solid underside plank stringer
	_add_box_col(body, Vector3(width, thickness, length), mid, rot)
	_add_box(body, Vector3(width, thickness * 0.72, length), mid - up_n * (thickness * 0.14), rot, mat, "RampStringer")
	if add_steps:
		var steps: int = maxi(4, int(roundf(length / 0.48)))
		var t_mat: Material = step_mat if step_mat != null else mat
		for i in range(steps):
			var frac: float = (float(i) + 0.5) / float(steps)
			var sp: Vector3 = p_start.lerp(p_end, frac) - Vector3(0.0, 0.07, 0.0)
			_add_box(body, Vector3(width * 0.94, 0.14, (length / float(steps)) * 1.15), sp, Vector3(0.0, yaw, 0.0), t_mat)


static func _build_pitched_roof(
	parent: Node3D,
	col_body: StaticBody3D,
	width: float,
	depth: float,
	wall_top_y: float,
	gable_h: float,
	wall_mat: Material,
	roof_mat: Material,
	trim_mat: Material
) -> void:
	# Stucco triangular gable infill matching exact roof slope
	_add_prism(parent, Vector3(width - 0.04, gable_h, depth - 0.04), Vector3(0.0, wall_top_y + gable_h * 0.5, 0.0), Vector3.ZERO, wall_mat, "GableInfill")

	var hw: float = width * 0.5
	var eave_x: float = 0.65
	var eave_z: float = 0.65
	var theta: float = atan2(gable_h, hw)
	var slope_len: float = (hw + eave_x) / cos(theta)
	var roof_t: float = 0.28
	var full_d: float = depth + eave_z * 2.0

	var dir_r := Vector2(cos(theta), -sin(theta))
	var norm_r := Vector2(sin(theta), cos(theta))
	var c_r2: Vector2 = Vector2(0.0, wall_top_y + gable_h) + dir_r * (slope_len * 0.5) + norm_r * (roof_t * 0.5)
	var r_pos := Vector3(c_r2.x, c_r2.y, 0.0)
	var l_pos := Vector3(-c_r2.x, c_r2.y, 0.0)

	_add_box(parent, Vector3(slope_len, roof_t, full_d), r_pos, Vector3(0.0, 0.0, -theta), roof_mat, "RoofSlopeR")
	_add_box(parent, Vector3(slope_len, roof_t, full_d), l_pos, Vector3(0.0, 0.0, theta), roof_mat, "RoofSlopeL")
	if col_body != null:
		_add_box_col(col_body, Vector3(slope_len, roof_t, full_d), r_pos, Vector3(0.0, 0.0, -theta))
		_add_box_col(col_body, Vector3(slope_len, roof_t, full_d), l_pos, Vector3(0.0, 0.0, theta))

	# Ridge cap beam & dark oak overhanging gable bargeboards
	_add_box(parent, Vector3(0.46, 0.28, full_d + 0.14), Vector3(0.0, wall_top_y + gable_h + roof_t * 0.72, 0.0), Vector3.ZERO, roof_mat, "RidgeCap")
	for z_sign in [-1.0, 1.0]:
		var bz: float = z_sign * (depth * 0.5 + eave_z * 0.94)
		_add_box(parent, Vector3(slope_len, 0.30, 0.14), Vector3(c_r2.x, c_r2.y - 0.02, bz), Vector3(0.0, 0.0, -theta), trim_mat)
		_add_box(parent, Vector3(slope_len, 0.30, 0.14), Vector3(-c_r2.x, c_r2.y - 0.02, bz), Vector3(0.0, 0.0, theta), trim_mat)

	# Exposed timber rafter tails under eaves
	var rafter_count: int = maxi(3, int(roundf(depth / 2.2)))
	for i in range(rafter_count):
		var rz: float = lerpf(-depth * 0.44, depth * 0.44, float(i) / float(maxi(1, rafter_count - 1)))
		for x_sign in [-1.0, 1.0]:
			_add_box(parent, Vector3(0.55, 0.16, 0.14), Vector3(x_sign * (hw + 0.22), wall_top_y - 0.10, rz), Vector3(0.0, 0.0, -x_sign * theta * 0.8), trim_mat)


static func _add_shuttered_window(
	parent: Node3D,
	pos: Vector3,
	yaw: float,
	w: float,
	h: float,
	mats: Dictionary,
	shutter_mat: Material,
	with_flowerbox: bool = true
) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder, true)

	var frame_mat: Material = mats["timber_dark"]
	_add_box(holder, Vector3(w + 0.22, h + 0.22, 0.16), Vector3(0.0, 0.0, 0.04), Vector3.ZERO, frame_mat)
	_add_box(holder, Vector3(w, h, 0.06), Vector3(0.0, 0.0, 0.08), Vector3.ZERO, mats["glass"])
	# Cross mullions
	_add_box(holder, Vector3(0.08, h, 0.12), Vector3(0.0, 0.0, 0.10), Vector3.ZERO, frame_mat)
	_add_box(holder, Vector3(w, 0.08, 0.12), Vector3(0.0, 0.0, 0.10), Vector3.ZERO, frame_mat)
	# Protruding stone sill
	_add_box(holder, Vector3(w + 0.36, 0.14, 0.30), Vector3(0.0, -h * 0.5 - 0.12, 0.12), Vector3.ZERO, mats["stone_trim"])
	# Flanking painted shutters
	var sw: float = w * 0.46
	for sx in [-1.0, 1.0]:
		_add_box(holder, Vector3(sw, h + 0.04, 0.10), Vector3(sx * (w * 0.5 + sw * 0.5 + 0.12), 0.0, 0.09), Vector3(0.0, sx * -0.14, 0.0), shutter_mat)
	if with_flowerbox:
		_add_box(holder, Vector3(w + 0.16, 0.22, 0.28), Vector3(0.0, -h * 0.5 - 0.22, 0.22), Vector3.ZERO, mats["timber_warm"])
		_add_box(holder, Vector3(w, 0.18, 0.22), Vector3(0.0, -h * 0.5 - 0.08, 0.22), Vector3.ZERO, mats["foliage"])
		for fx in [-w * 0.28, 0.0, w * 0.28]:
			_add_cyl(holder, 0.09, 0.09, 0.10, Vector3(fx, -h * 0.5 + 0.04, 0.24), Vector3.ZERO, mats["red_paint"] if absf(fx) > 0.05 else mats["yellow_paint"], 8)


static func _add_arched_doorway(parent: Node3D, pos: Vector3, yaw: float, w: float, h: float, mats: Dictionary) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder, true)
	# Stone threshold steps
	_add_box(holder, Vector3(w + 0.70, 0.24, 0.75), Vector3(0.0, 0.12, 0.32), Vector3.ZERO, mats["stone_trim"])
	_add_box(holder, Vector3(w + 0.35, 0.22, 0.45), Vector3(0.0, 0.34, 0.18), Vector3.ZERO, mats["stone_trim"])
	# Stone surround & lintel arch
	_add_box(holder, Vector3(w + 0.38, h + 0.26, 0.22), Vector3(0.0, h * 0.5 + 0.22, 0.06), Vector3.ZERO, mats["stone_trim"])
	_add_box(holder, Vector3(w, h, 0.14), Vector3(0.0, h * 0.5 + 0.22, 0.12), Vector3.ZERO, mats["door_oak"])
	_add_box(holder, Vector3(w * 0.84, 0.14, 0.18), Vector3(0.0, h * 0.65, 0.13), Vector3.ZERO, mats["iron"])
	_add_cyl(holder, 0.07, 0.07, 0.12, Vector3(w * 0.32, h * 0.48, 0.20), Vector3(PI * 0.5, 0.0, 0.0), mats["brass"], 8)


static func _add_chimney(parent: Node3D, pos: Vector3, height: float, mats: Dictionary) -> void:
	_add_box(parent, Vector3(0.95, height, 0.95), pos + Vector3(0.0, height * 0.5, 0.0), Vector3.ZERO, mats["stone"], "ChimneyStack")
	_add_box(parent, Vector3(1.16, 0.22, 1.16), pos + Vector3(0.0, height + 0.08, 0.0), Vector3.ZERO, mats["stone_trim"], "ChimneyCap")
	_add_cyl(parent, 0.22, 0.24, 0.50, pos + Vector3(0.0, height + 0.42, 0.0), Vector3.ZERO, mats["roof"], 10, "ChimneyFlue")


static func _add_timber_frame(parent: Node3D, width: float, height: float, depth: float, base_y: float, trim_mat: Material, quoin_mat: Material = null) -> void:
	var hw: float = width * 0.5
	var hd: float = depth * 0.5
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(parent, Vector3(0.30, height, 0.30), Vector3(sx * hw, base_y + height * 0.5, sz * hd), Vector3.ZERO, quoin_mat if quoin_mat != null else trim_mat)
	# Belt course beam
	_add_box(parent, Vector3(width + 0.24, 0.22, depth + 0.24), Vector3(0.0, base_y + height - 0.11, 0.0), Vector3.ZERO, trim_mat)


static func _add_cafe_table(parent: Node3D, col_body: StaticBody3D, pos: Vector3, mats: Dictionary) -> void:
	_add_cyl(parent, 0.68, 0.68, 0.10, pos + Vector3(0.0, 0.78, 0.0), Vector3.ZERO, mats["timber_warm"], 12)
	_add_cyl(parent, 0.10, 0.14, 0.76, pos + Vector3(0.0, 0.38, 0.0), Vector3.ZERO, mats["iron"], 10)
	_add_cyl(parent, 0.36, 0.36, 0.08, pos + Vector3(0.0, 0.04, 0.0), Vector3.ZERO, mats["iron"], 10)
	if col_body != null:
		_add_cyl_col(col_body, 0.68, 0.85, pos + Vector3(0.0, 0.42, 0.0))
	for sx in [-0.92, 0.92]:
		_add_cyl(parent, 0.24, 0.24, 0.08, pos + Vector3(sx, 0.46, 0.0), Vector3.ZERO, mats["timber_warm"], 10)
		_add_cyl(parent, 0.06, 0.06, 0.44, pos + Vector3(sx, 0.22, 0.0), Vector3.ZERO, mats["iron"], 8)


static func build_town_house(parent: Node3D, origin: Vector3, yaw: float, style_idx: int = 0) -> Node3D:
	var mats: Dictionary = _make_palette()
	var variant: int = posmod(style_idx, 3)
	var body := _make_static_body(parent, "TownHouse_%d" % variant, origin, yaw)
	var shutter_mat: Material = mats["shutter_green"] if (style_idx % 2 == 0) else mats["shutter_blue"]

	if variant == 0:
		# Country Cottage
		var w: float = 11.4
		var d: float = 9.6
		var plinth_h: float = 0.70
		var wall_h: float = 4.6
		var gable_h: float = 3.4
		_add_box(body, Vector3(w + 0.38, plinth_h, d + 0.38), Vector3(0.0, plinth_h * 0.5, 0.0), Vector3.ZERO, mats["stone"], "Plinth")
		_add_box(body, Vector3(w, wall_h, d), Vector3(0.0, plinth_h + wall_h * 0.5, 0.0), Vector3.ZERO, mats["ochre"], "Walls")
		_add_box_col(body, Vector3(w + 0.38, plinth_h + wall_h + gable_h * 0.45, d + 0.38), Vector3(0.0, (plinth_h + wall_h + gable_h * 0.45) * 0.5, 0.0))
		_add_timber_frame(body, w, wall_h, d, plinth_h, mats["timber_dark"], mats["stone_trim"])
		_build_pitched_roof(body, body, w, d, plinth_h + wall_h, gable_h, mats["ochre"], mats["roof"], mats["timber_dark"])
		_add_chimney(body, Vector3(-w * 0.30, plinth_h + wall_h + 1.4, -d * 0.22), 2.8, mats)
		_add_arched_doorway(body, Vector3(0.0, plinth_h * 0.35, d * 0.5), 0.0, 1.75, 2.8, mats)
		# Small tiled entry porch canopy
		_add_prism(body, Vector3(3.2, 0.95, 1.8), Vector3(0.0, plinth_h + 3.45, d * 0.5 + 0.85), Vector3.ZERO, mats["roof"], "PorchCanopy")
		for px in [-1.35, 1.35]:
			_add_box(body, Vector3(0.20, 3.0, 0.20), Vector3(px, plinth_h + 1.5, d * 0.5 + 1.55), Vector3.ZERO, mats["timber_dark"])
		for sx in [-3.4, 3.4]:
			_add_shuttered_window(body, Vector3(sx, plinth_h + 2.35, d * 0.5), 0.0, 1.45, 1.55, mats, shutter_mat, true)
			_add_shuttered_window(body, Vector3(sx, plinth_h + 2.35, -d * 0.5), PI, 1.45, 1.55, mats, shutter_mat, false)
		for sz in [-2.2, 2.2]:
			_add_shuttered_window(body, Vector3(w * 0.5, plinth_h + 2.35, sz), PI * 0.5, 1.35, 1.50, mats, shutter_mat, true)
			_add_shuttered_window(body, Vector3(-w * 0.5, plinth_h + 2.35, sz), -PI * 0.5, 1.35, 1.50, mats, shutter_mat, true)
		_add_cyl(body, 0.62, 0.62, 0.22, Vector3(0.0, plinth_h + wall_h + 1.45, d * 0.5 + 0.04), Vector3(PI * 0.5, 0.0, 0.0), mats["timber_dark"], 12)
	elif variant == 1:
		# Two-Story Half-Timbered Mediterranean Manor w/ Walkable Balcony & Exterior Stairs
		var w: float = 13.4
		var d: float = 11.2
		var plinth_h: float = 0.80
		var wall_h: float = 7.8
		var gable_h: float = 3.8
		var wall_mat: Material = mats["terracotta_wall"] if (style_idx % 2 == 1) else mats["cream"]
		_add_box(body, Vector3(w + 0.40, plinth_h, d + 0.40), Vector3(0.0, plinth_h * 0.5, 0.0), Vector3.ZERO, mats["stone"], "Plinth")
		_add_box(body, Vector3(w, wall_h, d), Vector3(0.0, plinth_h + wall_h * 0.5, 0.0), Vector3.ZERO, wall_mat, "Walls")
		_add_box_col(body, Vector3(w + 0.40, plinth_h + wall_h + gable_h * 0.45, d + 0.40), Vector3(0.0, (plinth_h + wall_h + gable_h * 0.45) * 0.5, 0.0))
		_add_timber_frame(body, w, wall_h * 0.52, d, plinth_h, mats["timber_dark"], mats["stone_trim"])
		_add_timber_frame(body, w + 0.08, wall_h * 0.48, d + 0.08, plinth_h + wall_h * 0.52, mats["timber_dark"], mats["timber_dark"])
		_build_pitched_roof(body, body, w, d, plinth_h + wall_h, gable_h, wall_mat, mats["roof"], mats["timber_dark"])
		_add_chimney(body, Vector3(w * 0.30, plinth_h + wall_h + 1.5, -d * 0.24), 3.0, mats)
		_add_arched_doorway(body, Vector3(-2.6, plinth_h * 0.35, d * 0.5), 0.0, 1.85, 2.9, mats)
		_add_arched_doorway(body, Vector3(0.0, plinth_h + 4.15, d * 0.5), 0.0, 1.60, 2.4, mats)
		# Upper & lower windows
		_add_shuttered_window(body, Vector3(2.8, plinth_h + 2.15, d * 0.5), 0.0, 1.6, 1.65, mats, shutter_mat, true)
		for wx in [-3.8, 3.8]:
			_add_shuttered_window(body, Vector3(wx, plinth_h + 5.85, d * 0.5), 0.0, 1.45, 1.65, mats, shutter_mat, true)
			_add_shuttered_window(body, Vector3(wx, plinth_h + 5.85, -d * 0.5), PI, 1.45, 1.65, mats, shutter_mat, false)
			_add_shuttered_window(body, Vector3(wx, plinth_h + 2.15, -d * 0.5), PI, 1.45, 1.65, mats, shutter_mat, false)
		# Walkable Front Balcony + Exterior Staircase
		var bal_y: float = plinth_h + 4.05
		var bal_z: float = d * 0.5 + 1.45
		_add_box(body, Vector3(w + 0.4, 0.34, 2.9), Vector3(0.0, bal_y - 0.17, bal_z), Vector3.ZERO, mats["timber_warm"], "BalconyDeck")
		_add_box_col(body, Vector3(w + 0.4, 0.34, 2.9), Vector3(0.0, bal_y - 0.17, bal_z))
		# Balcony support posts + full perimeter railing across balcony front, stair landing & sides
		for bx in [-w * 0.5 + 0.55, -1.2, 2.2, w * 0.5 - 0.55]:
			_add_box(body, Vector3(0.24, bal_y, 0.24), Vector3(bx, bal_y * 0.5, bal_z + 1.25), Vector3.ZERO, mats["timber_dark"])
		var rail_left: float = -w * 0.5 - 0.12
		var rail_right: float = w * 0.5 + 2.48
		var rail_cx: float = (rail_left + rail_right) * 0.5
		var rail_len: float = rail_right - rail_left
		_add_box(body, Vector3(rail_len, 0.16, 0.16), Vector3(rail_cx, bal_y + 1.0, bal_z + 1.32), Vector3.ZERO, mats["timber_dark"], "BalconyRailFront")
		_add_box(body, Vector3(rail_len, 0.12, 0.12), Vector3(rail_cx, bal_y + 0.50, bal_z + 1.32), Vector3.ZERO, mats["timber_warm"])
		_add_box_col(body, Vector3(rail_len, 1.05, 0.20), Vector3(rail_cx, bal_y + 0.52, bal_z + 1.32))
		for px in [rail_left + 0.08, -2.2, 2.2, w * 0.5 - 0.1, rail_right - 0.08]:
			_add_box(body, Vector3(0.18, 1.08, 0.18), Vector3(px, bal_y + 0.54, bal_z + 1.32), Vector3.ZERO, mats["timber_dark"])
		for side_x in [rail_left + 0.08, rail_right - 0.08]:
			_add_box(body, Vector3(0.16, 0.16, 2.75), Vector3(side_x, bal_y + 1.0, bal_z), Vector3.ZERO, mats["timber_dark"])
			_add_box(body, Vector3(0.12, 0.12, 2.75), Vector3(side_x, bal_y + 0.50, bal_z), Vector3.ZERO, mats["timber_warm"])
			_add_box_col(body, Vector3(0.20, 1.05, 2.75), Vector3(side_x, bal_y + 0.52, bal_z))
		_add_ramp_between(body, Vector3(w * 0.5 + 1.35, 0.0, -d * 0.32), Vector3(w * 0.5 + 1.35, bal_y, d * 0.5 + 0.15), 2.1, 0.36, mats["timber_dark"], true, mats["timber_warm"])
		_add_box(body, Vector3(2.4, 0.34, 2.9), Vector3(w * 0.5 + 1.35, bal_y - 0.17, bal_z), Vector3.ZERO, mats["timber_warm"])
		_add_box_col(body, Vector3(2.4, 0.34, 2.9), Vector3(w * 0.5 + 1.35, bal_y - 0.17, bal_z))
	else:
		# Corner Village Café / Shop w/ Striped Awning
		var w: float = 12.6
		var d: float = 10.6
		var plinth_h: float = 0.72
		var wall_h: float = 6.6
		var gable_h: float = 3.5
		_add_box(body, Vector3(w + 0.38, plinth_h, d + 0.38), Vector3(0.0, plinth_h * 0.5, 0.0), Vector3.ZERO, mats["stone"], "Plinth")
		_add_box(body, Vector3(w, wall_h, d), Vector3(0.0, plinth_h + wall_h * 0.5, 0.0), Vector3.ZERO, mats["cream"], "Walls")
		_add_box_col(body, Vector3(w + 0.38, plinth_h + wall_h + gable_h * 0.45, d + 0.38), Vector3(0.0, (plinth_h + wall_h + gable_h * 0.45) * 0.5, 0.0))
		_add_timber_frame(body, w, wall_h, d, plinth_h, mats["timber_dark"], mats["stone_trim"])
		_build_pitched_roof(body, body, w, d, plinth_h + wall_h, gable_h, mats["cream"], mats["roof"], mats["timber_dark"])
		_add_chimney(body, Vector3(-w * 0.28, plinth_h + wall_h + 1.5, 0.0), 2.8, mats)
		_add_arched_doorway(body, Vector3(-3.2, plinth_h * 0.35, d * 0.5), 0.0, 1.80, 2.8, mats)
		# Large shop display window + striped canvas awning
		_add_shuttered_window(body, Vector3(2.1, plinth_h + 2.0, d * 0.5), 0.0, 3.6, 1.9, mats, shutter_mat, false)
		var awn_mat: Material = mats["awning_red"] if (style_idx % 2 == 0) else mats["awning_blue"]
		_add_box(body, Vector3(w - 1.2, 0.18, 2.75), Vector3(0.0, plinth_h + 3.45, d * 0.5 + 1.25), Vector3(0.32, 0.0, 0.0), awn_mat, "ShopAwning")
		_add_box_col(body, Vector3(w - 1.2, 0.25, 2.75), Vector3(0.0, plinth_h + 3.45, d * 0.5 + 1.25), Vector3(0.32, 0.0, 0.0))
		for ax in [-w * 0.5 + 0.85, w * 0.5 - 0.85]:
			_add_box(body, Vector3(0.16, 2.9, 0.16), Vector3(ax, plinth_h + 1.5, d * 0.5 + 2.35), Vector3.ZERO, mats["iron"])
		for wx in [-3.3, 0.0, 3.3]:
			_add_shuttered_window(body, Vector3(wx, plinth_h + 5.1, d * 0.5), 0.0, 1.35, 1.45, mats, shutter_mat, true)
			_add_shuttered_window(body, Vector3(wx, plinth_h + 5.1, -d * 0.5), PI, 1.35, 1.45, mats, shutter_mat, false)
		_add_cafe_table(body, body, Vector3(2.8, 0.0, d * 0.5 + 2.4), mats)

	return body


static func build_church_chapel(parent: Node3D, origin: Vector3, yaw: float = 0.0) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, "ChurchChapel", origin, yaw)
	var nave_w: float = 14.5
	var nave_d: float = 22.0
	var plinth_h: float = 0.90
	var nave_h: float = 8.4
	var gable_h: float = 5.0

	_add_box(body, Vector3(nave_w + 0.6, plinth_h, nave_d + 0.6), Vector3(0.0, plinth_h * 0.5, 0.0), Vector3.ZERO, mats["stone"], "NavePlinth")
	_add_box(body, Vector3(nave_w, nave_h, nave_d), Vector3(0.0, plinth_h + nave_h * 0.5, 0.0), Vector3.ZERO, mats["cream"], "NaveWalls")
	_add_box_col(body, Vector3(nave_w + 0.6, plinth_h + nave_h + 2.2, nave_d + 0.6), Vector3(0.0, (plinth_h + nave_h + 2.2) * 0.5, 0.0))
	_build_pitched_roof(body, body, nave_w, nave_d, plinth_h + nave_h, gable_h, mats["cream"], mats["roof"], mats["timber_dark"])

	# Side buttresses & tall arched stained nave windows
	for sz in [-7.2, -2.4, 2.4, 7.2]:
		for sx in [-1.0, 1.0]:
			_add_box(body, Vector3(0.95, nave_h * 0.85, 1.15), Vector3(sx * (nave_w * 0.5 + 0.35), plinth_h + nave_h * 0.42, sz), Vector3.ZERO, mats["stone_trim"])
			if absf(sz) < 6.0:
				_add_box(body, Vector3(0.18, 3.6, 1.5), Vector3(sx * (nave_w * 0.5 + 0.05), plinth_h + 4.4, sz), Vector3.ZERO, mats["glass"])
				_add_box(body, Vector3(0.24, 3.85, 1.75), Vector3(sx * (nave_w * 0.5 + 0.02), plinth_h + 4.4, sz), Vector3.ZERO, mats["stone_trim"])

	# Tall Front Belltower (+Z): distinct Lower Stone Stage (0..5.2m), Upper Stucco Stage (5.2..14.3m), & Open Belfry
	var tw: float = 6.4
	var tower_z: float = nave_d * 0.5 + 1.2
	var lower_h: float = 5.2
	var belfry_y: float = plinth_h + 13.4
	var upper_h: float = belfry_y - lower_h
	_add_box(body, Vector3(tw + 0.5, lower_h, tw + 0.5), Vector3(0.0, lower_h * 0.5, tower_z), Vector3.ZERO, mats["stone"], "BellTowerLower")
	_add_box(body, Vector3(tw + 0.86, 0.34, tw + 0.86), Vector3(0.0, lower_h, tower_z), Vector3.ZERO, mats["stone_trim"], "BellTowerBelt")
	_add_box(body, Vector3(tw, upper_h, tw), Vector3(0.0, lower_h + upper_h * 0.5, tower_z), Vector3.ZERO, mats["cream"], "BellTowerUpper")
	_add_box(body, Vector3(tw + 0.64, 0.32, tw + 0.64), Vector3(0.0, belfry_y, tower_z), Vector3.ZERO, mats["stone_trim"], "BelfryCornice")
	_add_box_col(body, Vector3(tw + 0.5, lower_h, tw + 0.5), Vector3(0.0, lower_h * 0.5, tower_z))
	_add_box_col(body, Vector3(tw, upper_h + 3.2, tw), Vector3(0.0, lower_h + (upper_h + 3.2) * 0.5, tower_z))

	# Belfry open chamber with corner columns & bronze bell!
	for cx in [-2.3, 2.3]:
		for cz in [-2.3, 2.3]:
			_add_box(body, Vector3(0.85, 3.2, 0.85), Vector3(cx, belfry_y + 1.6, tower_z + cz), Vector3.ZERO, mats["stone_trim"])
	var bell_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.00, "rx": 0.92, "rz": 0.92, "p": 2.0, "col": Color(0.84, 0.78, 0.62)},
		{"y": 0.32, "rx": 0.68, "rz": 0.68, "p": 2.0, "col": Color(0.95, 0.92, 0.82)},
		{"y": 1.10, "rx": 0.56, "rz": 0.56, "p": 2.0, "col": Color.WHITE},
		{"y": 1.48, "rx": 0.28, "rz": 0.28, "p": 2.0, "col": Color.WHITE},
	], 14)
	_add_mesh(body, bell_mesh, Vector3(0.0, belfry_y + 0.75, tower_z), Vector3.ZERO, mats["brass"], "ChurchBell")

	# Pyramidal belltower spire + golden cross
	var spire_y: float = belfry_y + 3.2
	var spire_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.0, "rx": 3.8, "rz": 3.8, "p": 8.0, "col": Color(0.84, 0.80, 0.76)},
		{"y": 2.5, "rx": 2.2, "rz": 2.2, "p": 6.0, "col": Color(0.94, 0.92, 0.88)},
		{"y": 5.4, "rx": 0.22, "rz": 0.22, "p": 2.4, "col": Color.WHITE},
	], 12)
	_add_mesh(body, spire_mesh, Vector3(0.0, spire_y, tower_z), Vector3.ZERO, mats["roof"], "ChurchSpire")
	_add_box(body, Vector3(0.22, 2.2, 0.22), Vector3(0.0, spire_y + 6.2, tower_z), Vector3.ZERO, mats["brass"])
	_add_box(body, Vector3(1.25, 0.22, 0.22), Vector3(0.0, spire_y + 6.7, tower_z), Vector3.ZERO, mats["brass"])

	_add_arched_doorway(body, Vector3(0.0, 0.0, tower_z + (tw + 0.5) * 0.5), 0.0, 2.6, 3.8, mats)
	_add_cyl(body, 1.15, 1.15, 0.28, Vector3(0.0, lower_h + 4.4, tower_z + tw * 0.5 + 0.06), Vector3(PI * 0.5, 0.0, 0.0), mats["brass"], 16, "RoseWindowRim")
	_add_cyl(body, 0.92, 0.92, 0.32, Vector3(0.0, lower_h + 4.4, tower_z + tw * 0.5 + 0.08), Vector3(PI * 0.5, 0.0, 0.0), mats["glass"], 16, "RoseWindowGlass")
	return body


static func build_windmill(parent: Node3D, origin: Vector3, yaw: float = 0.0) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, "Windmill", origin, yaw)

	# Conical masonry + whitewash stone tower loft (strictly ascending Y)
	var tower_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.0, "rx": 4.6, "rz": 4.6, "p": 2.0, "col": Color(0.84, 0.84, 0.82)},
		{"y": 3.5, "rx": 4.2, "rz": 4.2, "p": 2.0, "col": Color(0.92, 0.92, 0.90)},
		{"y": 11.5, "rx": 3.1, "rz": 3.1, "p": 2.0, "col": Color(0.98, 0.98, 0.96)},
		{"y": 14.5, "rx": 2.85, "rz": 2.85, "p": 2.0, "col": Color.WHITE},
	], 20)
	_add_mesh(body, tower_mesh, Vector3.ZERO, Vector3.ZERO, mats["stone"], "MillTower")
	_add_cyl_col(body, 3.8, 14.5, Vector3(0.0, 7.25, 0.0))

	# Upper timber gallery ring + conical cedar/terracotta roof cap
	_add_cyl(body, 3.45, 3.25, 0.45, Vector3(0.0, 14.4, 0.0), Vector3.ZERO, mats["timber_dark"], 18)
	var cap_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.0, "rx": 3.45, "rz": 3.45, "p": 2.0, "col": Color(0.86, 0.82, 0.78)},
		{"y": 1.8, "rx": 2.35, "rz": 2.35, "p": 2.0, "col": Color(0.96, 0.94, 0.90)},
		{"y": 4.0, "rx": 0.22, "rz": 0.22, "p": 2.0, "col": Color.WHITE},
	], 18)
	_add_mesh(body, cap_mesh, Vector3(0.0, 14.55, 0.0), Vector3.ZERO, mats["roof"], "MillRoof")
	_add_arched_doorway(body, Vector3(0.0, 0.25, 4.35), 0.0, 1.8, 2.8, mats)

	# Rotating hub & 4 slatted canvas sails on +Z face
	var blades := Node3D.new()
	blades.name = "WindmillBlades"
	blades.position = Vector3(0.0, 13.0, 3.35)
	body.add_child(blades)
	_add_cyl(blades, 0.52, 0.64, 1.6, Vector3(0.0, 0.0, -0.35), Vector3(PI * 0.5, 0.0, 0.0), mats["timber_dark"], 12, "Hub")
	for i in range(4):
		var arm := Node3D.new()
		arm.rotation.z = float(i) * (PI * 0.5)
		blades.add_child(arm)
		_add_box(arm, Vector3(0.32, 8.6, 0.28), Vector3(0.0, 4.3, 0.0), Vector3.ZERO, mats["timber_dark"])
		_add_box(arm, Vector3(1.65, 6.2, 0.10), Vector3(0.95, 5.2, 0.06), Vector3(0.0, 0.14, 0.0), mats["canvas"])
		for ry in [2.6, 4.2, 5.8, 7.4]:
			_add_box(arm, Vector3(1.75, 0.14, 0.16), Vector3(0.95, ry, 0.08), Vector3(0.0, 0.14, 0.0), mats["timber_warm"])
	return body


static func build_central_fountain(parent: Node3D, origin: Vector3) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, "CentralFountain", origin, 0.0)

	# Octagonal cobblestone plaza border pad
	_add_cyl(body, 11.5, 11.8, 0.14, Vector3(0.0, 0.07, 0.0), Vector3.ZERO, mats["cobble"], 16, "PlazaPad")

	# Lower stone pool rim & basin floor
	_add_cyl(body, 5.2, 5.5, 0.42, Vector3(0.0, 0.21, 0.0), Vector3.ZERO, mats["stone"], 8, "BasinStep")
	for i in range(8):
		var a: float = (float(i) / 8.0) * TAU + PI / 8.0
		var seg_pos := Vector3(cos(a) * 4.55, 0.72, sin(a) * 4.55)
		_add_box(body, Vector3(0.68, 0.85, 3.85), seg_pos, Vector3(0.0, -a, 0.0), mats["stone_trim"])
	_add_cyl_col(body, 5.1, 1.05, Vector3(0.0, 0.52, 0.0))

	# Sparkling translucent lower water pool (TRANSPARENCY_ALPHA strictly on water)
	_add_cyl(body, 4.35, 4.35, 0.18, Vector3(0.0, 0.74, 0.0), Vector3.ZERO, mats["water"], 16, "LowerWater")

	# Sculpted central carved pedestal + upper bowl + finial spout
	var ped_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.20, "rx": 1.65, "rz": 1.65, "p": 2.0, "col": Color(0.84, 0.82, 0.78)},
		{"y": 0.90, "rx": 0.95, "rz": 0.95, "p": 2.0, "col": Color(0.92, 0.90, 0.88)},
		{"y": 2.25, "rx": 0.72, "rz": 0.72, "p": 2.0, "col": Color.WHITE},
		{"y": 2.75, "rx": 2.15, "rz": 2.15, "p": 2.0, "col": Color.WHITE},
		{"y": 3.15, "rx": 2.25, "rz": 2.25, "p": 2.0, "col": Color(0.95, 0.94, 0.90)},
	], 16)
	_add_mesh(body, ped_mesh, Vector3.ZERO, Vector3.ZERO, mats["stone_trim"], "CenterPedestal")
	_add_cyl_col(body, 1.4, 3.6, Vector3(0.0, 1.8, 0.0))
	_add_cyl(body, 1.85, 1.85, 0.10, Vector3(0.0, 3.19, 0.0), Vector3.ZERO, mats["water"], 14, "UpperWater")

	var spout_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 3.05, "rx": 0.65, "rz": 0.65, "p": 2.0, "col": Color(0.90, 0.88, 0.85)},
		{"y": 3.85, "rx": 0.36, "rz": 0.36, "p": 2.0, "col": Color.WHITE},
		{"y": 4.45, "rx": 0.16, "rz": 0.16, "p": 2.0, "col": Color.WHITE},
	], 12)
	_add_mesh(body, spout_mesh, Vector3.ZERO, Vector3.ZERO, mats["stone_trim"], "TopSpout")

	# 4 falling sparkling water arc jets from upper bowl into lower basin
	for i in range(4):
		var ang: float = float(i) * PI * 0.5 + PI * 0.25
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		for s in range(5):
			var t: float = (float(s) + 0.5) / 5.0
			var r_dist: float = lerpf(1.75, 3.35, t)
			var y_arc: float = lerpf(3.18, 0.85, t * t)
			_add_cyl(body, 0.10, 0.14, 0.55, dir * r_dist + Vector3(0.0, y_arc, 0.0), Vector3(0.0, -ang, 0.45 + t * 0.75), mats["water"], 8)
	return body


static func build_mercadinho_complex(parent: Node3D, origin: Vector3) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, "Mercadinho", origin, 0.0)

	# Cobble market apron
	_add_box(body, Vector3(26.0, 0.14, 18.0), Vector3(0.0, 0.07, 0.0), Vector3.ZERO, mats["cobble"], "MarketApron")
	_add_box_col(body, Vector3(26.0, 0.14, 18.0), Vector3(0.0, 0.07, 0.0))

	var produce_colors: Array[Material] = [
		mats["red_paint"],
		make_mat(Color(0.96, 0.54, 0.12), "", 0.65, 0.02),
		mats["foliage"],
		mats["yellow_paint"],
	]
	# 4 Open-Air Stalls framing a wide 6m center walkway
	var stall_specs: Array[Dictionary] = [
		{"pos": Vector3(-7.0, 0.14, -4.8), "yaw": 0.0, "awning": mats["awning_red"]},
		{"pos": Vector3(7.0, 0.14, -4.8), "yaw": 0.0, "awning": mats["awning_blue"]},
		{"pos": Vector3(-7.0, 0.14, 4.8), "yaw": PI, "awning": mats["awning_blue"]},
		{"pos": Vector3(7.0, 0.14, 4.8), "yaw": PI, "awning": mats["awning_red"]},
	]
	for idx in range(stall_specs.size()):
		var sp: Dictionary = stall_specs[idx]
		var holder := Node3D.new()
		holder.position = sp["pos"]
		holder.rotation.y = float(sp["yaw"])
		body.add_child(holder, true)
		# Timber corner posts
		for px in [-2.6, 2.6]:
			for pz in [-1.5, 1.5]:
				var ph: float = 3.2 if pz < 0.0 else 2.75
				_add_box(holder, Vector3(0.22, ph, 0.22), Vector3(px, ph * 0.5, pz), Vector3.ZERO, mats["timber_dark"])
		# Sloped striped canvas canopy
		_add_box(holder, Vector3(6.0, 0.16, 4.1), Vector3(0.0, 3.05, 0.15), Vector3(0.22, 0.0, 0.0), sp["awning"], "MarketAwning_%d" % idx)
		# Wooden shop counter + rear shelving
		_add_box(holder, Vector3(5.2, 1.05, 1.15), Vector3(0.0, 0.52, 0.85), Vector3.ZERO, mats["timber_warm"], "Counter_%d" % idx)
		var local_col_pos: Vector3 = holder.position + Vector3(0.0, 0.52, 0.85).rotated(Vector3.UP, holder.rotation.y)
		_add_box_col(body, Vector3(5.2, 1.1, 1.25), local_col_pos)
		_add_box(holder, Vector3(5.0, 1.9, 0.55), Vector3(0.0, 0.95, -1.25), Vector3.ZERO, mats["timber_dark"])
		# Colorful produce crates & fruit piles atop counter
		for cx in [-1.7, 0.0, 1.7]:
			var pmat: Material = produce_colors[(idx + int(absf(cx))) % produce_colors.size()]
			_add_box(holder, Vector3(1.25, 0.42, 0.85), Vector3(cx, 1.24, 0.85), Vector3(0.18, 0.0, 0.0), mats["timber_dark"])
			_add_box(holder, Vector3(1.05, 0.32, 0.65), Vector3(cx, 1.44, 0.85), Vector3(0.18, 0.0, 0.0), pmat)
		# Hanging warm market lantern
		_add_cyl(holder, 0.18, 0.14, 0.34, Vector3(0.0, 2.55, 1.45), Vector3.ZERO, mats["glow_gold"], 10)

	# Market entry signboard archway & café seating
	for sx in [-3.4, 3.4]:
		_add_box(body, Vector3(0.26, 4.2, 0.26), Vector3(sx, 2.1, -8.2), Vector3.ZERO, mats["timber_dark"])
	_add_box(body, Vector3(7.6, 1.05, 0.24), Vector3(0.0, 3.85, -8.2), Vector3.ZERO, mats["timber_warm"], "MercadinhoSign")
	_add_box(body, Vector3(7.2, 0.78, 0.28), Vector3(0.0, 3.85, -8.2), Vector3.ZERO, mats["red_paint"])
	_add_cafe_table(body, body, Vector3(-11.2, 0.14, 0.0), mats)
	_add_cafe_table(body, body, Vector3(11.2, 0.14, 0.0), mats)
	return body


static func build_coastal_lighthouse(parent: Node3D, origin: Vector3) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, "CoastalLighthouse", origin, 0.0)

	# Stone masonry seawall terrace
	_add_cyl(body, 8.2, 8.8, 2.0, Vector3(0.0, 1.0, 0.0), Vector3.ZERO, mats["stone"], 16, "SeawallTerrace")
	_add_cyl_col(body, 8.4, 2.0, Vector3(0.0, 1.0, 0.0))

	# 28m Red & White Striped Tapered Lighthouse Tower (5 stacked ascending loft bands)
	var base_y: float = 2.0
	var bands: Array[Dictionary] = [
		{"y0": 0.0, "y1": 4.1, "r0": 3.45, "r1": 3.12, "mat": mats["white_paint"]},
		{"y0": 4.1, "y1": 8.2, "r0": 3.12, "r1": 2.80, "mat": mats["red_paint"]},
		{"y0": 8.2, "y1": 12.3, "r0": 2.80, "r1": 2.48, "mat": mats["white_paint"]},
		{"y0": 12.3, "y1": 16.4, "r0": 2.48, "r1": 2.18, "mat": mats["red_paint"]},
		{"y0": 16.4, "y1": 20.5, "r0": 2.18, "r1": 1.92, "mat": mats["white_paint"]},
	]
	for b_idx in range(bands.size()):
		var bd: Dictionary = bands[b_idx]
		var band_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
			{"y": float(bd["y0"]), "rx": float(bd["r0"]), "rz": float(bd["r0"]), "p": 2.0, "col": Color(0.90, 0.90, 0.92)},
			{"y": float(bd["y1"]), "rx": float(bd["r1"]), "rz": float(bd["r1"]), "p": 2.0, "col": Color.WHITE},
		], 20)
		_add_mesh(body, band_mesh, Vector3(0.0, base_y, 0.0), Vector3.ZERO, bd["mat"], "LighthouseBand_%d" % b_idx)
	_add_cyl_col(body, 2.8, 21.0, Vector3(0.0, base_y + 10.5, 0.0))
	_add_arched_doorway(body, Vector3(0.0, base_y, 3.25), 0.0, 1.5, 2.6, mats)

	# Spiral slit windows ascending the tower
	for w_idx in range(4):
		var wy: float = base_y + 4.8 + float(w_idx) * 3.8
		var wang: float = float(w_idx) * 1.15
		var wr: float = lerpf(3.0, 2.2, float(w_idx) / 3.0)
		_add_box(body, Vector3(0.75, 1.3, 0.32), Vector3(sin(wang) * wr, wy, cos(wang) * wr), Vector3(0.0, wang, 0.0), mats["timber_dark"])

	# Upper cantilevered gallery deck + iron railing
	var gal_y: float = base_y + 20.5
	_add_cyl(body, 2.95, 2.45, 0.55, Vector3(0.0, gal_y + 0.25, 0.0), Vector3.ZERO, mats["stone_trim"], 18, "GalleryDeck")
	for i in range(12):
		var a: float = (float(i) / 12.0) * TAU
		_add_cyl(body, 0.06, 0.06, 1.15, Vector3(cos(a) * 2.72, gal_y + 1.05, sin(a) * 2.72), Vector3.ZERO, mats["iron"], 6)
	_add_cyl(body, 2.75, 2.75, 0.10, Vector3(0.0, gal_y + 1.55, 0.0), Vector3.ZERO, mats["iron"], 18)

	# Glowing Golden Beacon Lantern + Conical Red Roof + Lightning Rod
	var lantern_y: float = gal_y + 0.55
	_add_cyl(body, 1.25, 1.25, 2.2, Vector3(0.0, lantern_y + 1.1, 0.0), Vector3.ZERO, mats["glow_gold"], 14, "BeaconCore")
	_add_cyl(body, 1.72, 1.72, 2.7, Vector3(0.0, lantern_y + 1.35, 0.0), Vector3.ZERO, mats["beacon_glass"], 16, "BeaconGlass")
	var roof_y: float = lantern_y + 2.7
	var cone_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.0, "rx": 2.15, "rz": 2.15, "p": 2.0, "col": Color(0.88, 0.88, 0.88)},
		{"y": 1.6, "rx": 1.15, "rz": 1.15, "p": 2.0, "col": Color.WHITE},
		{"y": 2.9, "rx": 0.16, "rz": 0.16, "p": 2.0, "col": Color.WHITE},
	], 18)
	_add_mesh(body, cone_mesh, Vector3(0.0, roof_y, 0.0), Vector3.ZERO, mats["red_paint"], "LighthouseRoof")
	_add_cyl(body, 0.05, 0.09, 1.8, Vector3(0.0, roof_y + 3.6, 0.0), Vector3.ZERO, mats["brass"], 8, "LightningRod")

	# Keeper's Cottage (Casa do Faroleiro) beside the Lighthouse
	var cot := Node3D.new()
	cot.name = "KeepersCottage"
	cot.position = Vector3(8.6, 0.0, -2.0)
	cot.rotation.y = -0.25
	body.add_child(cot, true)
	var cw: float = 8.4
	var cd: float = 7.2
	_add_box(cot, Vector3(cw + 0.35, 0.65, cd + 0.35), Vector3(0.0, 0.325, 0.0), Vector3.ZERO, mats["stone"])
	_add_box(cot, Vector3(cw, 4.2, cd), Vector3(0.0, 0.65 + 2.1, 0.0), Vector3.ZERO, mats["whitewash"])
	_add_box_col(body, Vector3(cw + 0.35, 6.2, cd + 0.35), cot.position + Vector3(0.0, 3.1, 0.0), cot.rotation)
	_build_pitched_roof(cot, null, cw, cd, 4.85, 2.8, mats["whitewash"], mats["slate"], mats["timber_dark"])
	_add_chimney(cot, Vector3(2.1, 4.85 + 1.1, -1.4), 2.5, mats)
	_add_arched_doorway(cot, Vector3(0.0, 0.25, cd * 0.5), 0.0, 1.5, 2.5, mats)
	_add_shuttered_window(cot, Vector3(-2.3, 2.6, cd * 0.5), 0.0, 1.25, 1.35, mats, mats["shutter_blue"], true)
	_add_shuttered_window(cot, Vector3(2.3, 2.6, cd * 0.5), 0.0, 1.25, 1.35, mats, mats["shutter_blue"], true)
	return body


static func build_watchtower(parent: Node3D, origin: Vector3, yaw: float = 0.0, tower_name: String = "Watchtower") -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, tower_name, origin, yaw)
	var deck_y: float = 6.0
	var half: float = 2.4

	# 4 corner timber posts + stone footings
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx * half
			var pz: float = sz * half
			_add_box(body, Vector3(0.75, 0.70, 0.75), Vector3(px, 0.35, pz), Vector3.ZERO, mats["stone"])
			_add_box(body, Vector3(0.34, 9.6, 0.34), Vector3(px, 4.8, pz), Vector3.ZERO, mats["timber_dark"])
			_add_box_col(body, Vector3(0.45, 9.6, 0.45), Vector3(px, 4.8, pz))

	# Cross-bracing on the 3 non-stair sides (North -Z, East +X, South +Z)
	_add_box(body, Vector3(4.6, 0.18, 0.16), Vector3(0.0, 3.0, -half), Vector3(0.0, 0.0, 0.65), mats["timber_dark"])
	_add_box(body, Vector3(4.6, 0.18, 0.16), Vector3(0.0, 3.0, -half), Vector3(0.0, 0.0, -0.65), mats["timber_dark"])
	_add_box(body, Vector3(0.16, 0.18, 4.6), Vector3(half, 3.0, 0.0), Vector3(0.65, 0.0, 0.0), mats["timber_dark"])
	_add_box(body, Vector3(0.16, 0.18, 4.6), Vector3(half, 3.0, 0.0), Vector3(-0.65, 0.0, 0.0), mats["timber_dark"])

	# Wide 5.4m x 5.4m Planked Lookout Platform at Y = 6.0m
	_add_box(body, Vector3(5.4, 0.32, 5.4), Vector3(0.0, deck_y - 0.16, 0.0), Vector3.ZERO, mats["timber_warm"], "LookoutDeck")
	_add_box_col(body, Vector3(5.4, 0.32, 5.4), Vector3(0.0, deck_y - 0.16, 0.0))

	# Waist-high parapets on North (-Z), South (+Z), East (+X), and lower half of West (-X) leaving -Z/-X entry open!
	var p_h: float = 1.05
	_add_box(body, Vector3(5.4, p_h, 0.28), Vector3(0.0, deck_y + p_h * 0.5, -2.56), Vector3.ZERO, mats["sandbag"])
	_add_box_col(body, Vector3(5.4, p_h, 0.28), Vector3(0.0, deck_y + p_h * 0.5, -2.56))
	_add_box(body, Vector3(5.4, p_h, 0.28), Vector3(0.0, deck_y + p_h * 0.5, 2.56), Vector3.ZERO, mats["sandbag"])
	_add_box_col(body, Vector3(5.4, p_h, 0.28), Vector3(0.0, deck_y + p_h * 0.5, 2.56))
	_add_box(body, Vector3(0.28, p_h, 5.1), Vector3(2.56, deck_y + p_h * 0.5, 0.0), Vector3.ZERO, mats["sandbag"])
	_add_box_col(body, Vector3(0.28, p_h, 5.1), Vector3(2.56, deck_y + p_h * 0.5, 0.0))
	_add_box(body, Vector3(0.28, p_h, 3.1), Vector3(-2.56, deck_y + p_h * 0.5, 1.05), Vector3.ZERO, mats["timber_warm"])
	_add_box_col(body, Vector3(0.28, p_h, 3.1), Vector3(-2.56, deck_y + p_h * 0.5, 1.05))

	# Pyramidal Cedar Shingle Roof overhead (Y = 9.4..11.6m)
	var roof_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 0.0, "rx": 3.4, "rz": 3.4, "p": 8.0, "col": Color(0.86, 0.84, 0.82)},
		{"y": 1.2, "rx": 1.8, "rz": 1.8, "p": 6.0, "col": Color(0.96, 0.94, 0.92)},
		{"y": 2.2, "rx": 0.18, "rz": 0.18, "p": 2.4, "col": Color.WHITE},
	], 12)
	_add_mesh(body, roof_mesh, Vector3(0.0, 9.4, 0.0), Vector3.ZERO, mats["shingle"], "WatchtowerRoof")
	_add_box_col(body, Vector3(6.2, 0.40, 6.2), Vector3(0.0, 9.6, 0.0))

	# Walkable 2-Flight Exterior Timber Staircase (Flight 1 along +Z -> Mid-Landing -> Flight 2 along -X -> Top Landing)
	_add_ramp_between(body, Vector3(2.6, 0.0, 4.4), Vector3(-2.6, 3.0, 4.4), 1.9, 0.34, mats["timber_dark"], true, mats["timber_warm"])
	_add_box(body, Vector3(2.1, 0.32, 2.1), Vector3(-3.65, 3.0 - 0.16, 4.4), Vector3.ZERO, mats["timber_warm"], "MidLanding")
	_add_box_col(body, Vector3(2.1, 0.32, 2.1), Vector3(-3.65, 3.0 - 0.16, 4.4))
	for lx in [-4.5, -2.8]:
		for lz in [3.5, 5.2]:
			_add_box(body, Vector3(0.22, 3.0, 0.22), Vector3(lx, 1.5, lz), Vector3.ZERO, mats["timber_dark"])
	_add_ramp_between(body, Vector3(-3.65, 3.0, 3.35), Vector3(-3.65, deck_y, -0.95), 1.9, 0.34, mats["timber_dark"], true, mats["timber_warm"])
	_add_box(body, Vector3(2.1, 0.32, 1.85), Vector3(-3.65, deck_y - 0.16, -1.85), Vector3.ZERO, mats["timber_warm"], "TopLanding")
	_add_box_col(body, Vector3(2.1, 0.32, 1.85), Vector3(-3.65, deck_y - 0.16, -1.85))
	for lx in [-4.5, -2.8]:
		_add_box(body, Vector3(0.22, deck_y, 0.22), Vector3(lx, deck_y * 0.5, -2.55), Vector3.ZERO, mats["timber_dark"])
	return body


static func build_airstrip_complex(parent: Node3D, origin: Vector3, yaw: float, team: int, runway_name: String) -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, runway_name, origin, yaw)
	var is_royal: bool = (team != 1)
	var accent: Material = make_mat(Color(0.18, 0.48, 0.88) if is_royal else Color(0.82, 0.16, 0.16), "", 0.60, 0.12)
	var hangar_steel: Material = make_mat(Color(0.56, 0.60, 0.66) if is_royal else Color(0.38, 0.40, 0.44), "veh_steel", 0.52, 0.42, 1.0, Vector2(4.0, 2.0))

	# 220m x 22m flush walkable Tarmac Runway (zero obstacles on strip!)
	_add_box(body, Vector3(220.0, 0.28, 22.0), Vector3(0.0, -0.13, 0.0), Vector3.ZERO, mats["tarmac"], "TarmacStrip")
	_add_box_col(body, Vector3(220.0, 0.28, 22.0), Vector3(0.0, -0.13, 0.0))

	# Runway threshold zebra bars, yellow taxi edge stripes, and centerline dashes
	for x_end in [-102.0, 102.0]:
		for z_bar in [-7.5, -4.5, -1.5, 1.5, 4.5, 7.5]:
			_add_box(body, Vector3(6.5, 0.03, 1.3), Vector3(x_end, 0.02, z_bar), Vector3.ZERO, mats["white_paint"])
	for z_edge in [-10.2, 10.2]:
		_add_box(body, Vector3(216.0, 0.03, 0.45), Vector3(0.0, 0.02, z_edge), Vector3.ZERO, mats["yellow_paint"])
	for dx in range(-90, 96, 14):
		_add_box(body, Vector3(7.5, 0.03, 0.65), Vector3(float(dx), 0.02, 0.0), Vector3.ZERO, mats["white_paint"])

	# Arched Corrugated Steel Aircraft Hangar positioned safely off-runway (Z = -34m)
	var hang := Node3D.new()
	hang.name = "AircraftHangar"
	hang.position = Vector3(-18.0, 0.0, -34.0)
	body.add_child(hang, true)
	var hw: float = 16.0
	var hd: float = 20.0
	var wall_h: float = 5.2
	_add_box(hang, Vector3(hw + 1.0, 0.24, hd + 1.0), Vector3(0.0, 0.12, 0.0), Vector3.ZERO, mats["stone_trim"])
	for sx in [-1.0, 1.0]:
		_add_box(hang, Vector3(0.95, wall_h, hd), Vector3(sx * hw * 0.5, wall_h * 0.5, 0.0), Vector3.ZERO, mats["stone"])
		_add_box_col(body, Vector3(1.0, wall_h, hd), hang.position + Vector3(sx * hw * 0.5, wall_h * 0.5, 0.0))
	# Vaulted arch steel roof ribs along Z
	var segs: int = 7
	for s in range(segs):
		var a0: float = lerpf(-0.45 * PI, 0.45 * PI, float(s) / float(segs - 1))
		var rx: float = sin(a0) * (hw * 0.54)
		var ry: float = wall_h + cos(a0) * 3.4
		_add_box(hang, Vector3(2.95, 0.32, hd + 0.6), Vector3(rx, ry, 0.0), Vector3(0.0, 0.0, -a0 * 0.85), hangar_steel)
	_add_box_col(body, Vector3(hw + 0.8, 0.8, hd), hang.position + Vector3(0.0, wall_h + 2.8, 0.0))
	_add_box(hang, Vector3(hw * 0.68, 0.9, 0.25), Vector3(0.0, wall_h + 1.4, hd * 0.5 + 0.15), Vector3.ZERO, accent, "HangarStripeF")
	_add_box(hang, Vector3(hw * 0.68, 0.9, 0.25), Vector3(0.0, wall_h + 1.4, -hd * 0.5 - 0.15), Vector3.ZERO, accent, "HangarStripeB")

	# Wooden ATC Flight Shack / Control Tower off-runway (X = +18, Z = -32)
	var atc := Node3D.new()
	atc.name = "ATCFlightShack"
	atc.position = Vector3(18.0, 0.0, -32.0)
	body.add_child(atc, true)
	_add_box(atc, Vector3(6.2, 6.2, 6.2), Vector3(0.0, 3.1, 0.0), Vector3.ZERO, mats["stone"])
	_add_box(atc, Vector3(7.2, 2.8, 7.2), Vector3(0.0, 7.6, 0.0), Vector3.ZERO, mats["timber_warm"])
	_add_box(atc, Vector3(6.6, 1.5, 7.3), Vector3(0.0, 7.8, 0.0), Vector3.ZERO, mats["glass"])
	_add_box(atc, Vector3(7.3, 1.5, 6.6), Vector3(0.0, 7.8, 0.0), Vector3.ZERO, mats["glass"])
	_add_box_col(body, Vector3(7.2, 9.2, 7.2), atc.position + Vector3(0.0, 4.6, 0.0))
	_build_pitched_roof(atc, null, 7.4, 7.4, 9.0, 2.2, mats["timber_warm"], mats["roof"], mats["timber_dark"])

	# Windsock mast, sandbag revetment, and fuel drums off-runway
	_add_cyl(body, 0.10, 0.14, 6.5, Vector3(-42.0, 3.25, -18.0), Vector3.ZERO, mats["iron"], 8, "WindsockMast")
	_add_cyl(body, 0.34, 0.16, 1.8, Vector3(-41.0, 6.15, -18.0), Vector3(0.0, 0.0, -PI * 0.42), mats["red_paint"], 10, "WindsockCone")
	_add_box(body, Vector3(8.5, 1.25, 1.15), Vector3(42.0, 0.62, -24.0), Vector3.ZERO, mats["sandbag"])
	_add_box_col(body, Vector3(8.5, 1.25, 1.15), Vector3(42.0, 0.62, -24.0))
	for dx in [34.2, 35.4, 36.6]:
		_add_cyl(body, 0.44, 0.44, 1.2, Vector3(dx, 0.6, -24.0), Vector3.ZERO, mats["red_paint"], 10)
	return body


static func build_harbor_pier(parent: Node3D, origin: Vector3, yaw: float, pier_name: String = "HarborPier") -> Node3D:
	var mats: Dictionary = _make_palette()
	var body := _make_static_body(parent, pier_name, origin, yaw)
	var barnacle_wood: Material = make_mat(Color(0.28, 0.22, 0.16), "bark", 0.90, 0.02)

	# Gentle approach boardwalk ramp from mainland grass (y = 2.15, z = 0) down to pier deck (y = 1.15, z = 28)
	_add_ramp_between(body, Vector3(0.0, 2.15, -2.0), Vector3(0.0, 1.15, 28.0), 8.2, 0.42, mats["timber_warm"], false)
	# Main timber pier deck extending out over deep ocean (z = 28..118, total length 120m from origin!)
	_add_box(body, Vector3(8.0, 0.44, 90.0), Vector3(0.0, 1.15 - 0.22, 73.0), Vector3.ZERO, mats["timber_warm"], "PierDeck")
	_add_box_col(body, Vector3(8.0, 0.44, 90.0), Vector3(0.0, 1.15 - 0.22, 73.0))

	# Lowered boat-boarding apron fingers at deep-water end (z = 92..118, y_top = 0.80m)
	_add_ramp_between(body, Vector3(0.0, 1.15, 86.0), Vector3(0.0, 0.80, 94.0), 7.8, 0.38, mats["timber_warm"], false)
	_add_box(body, Vector3(8.4, 0.38, 25.0), Vector3(0.0, 0.80 - 0.19, 106.5), Vector3.ZERO, mats["timber_warm"], "BoatDockApron")
	_add_box_col(body, Vector3(8.4, 0.38, 25.0), Vector3(0.0, 0.80 - 0.19, 106.5))

	# Barnacle-dark timber pilings reaching seafloor + mooring bollards
	for pz in range(32, 120, 12):
		for px in [-3.6, 3.6]:
			_add_cyl(body, 0.26, 0.30, 10.2, Vector3(px, -3.2, float(pz)), Vector3.ZERO, barnacle_wood, 10)
			if pz >= 88:
				_add_cyl(body, 0.18, 0.22, 0.72, Vector3(px * 1.04, 1.25, float(pz)), Vector3.ZERO, mats["iron"], 10)
				_add_cyl_col(body, 0.24, 0.85, Vector3(px * 1.04, 1.25, float(pz)))
	# Harbor pier lanterns & lifebuoy ring posts
	for lz in [44.0, 82.0, 115.0]:
		_add_box(body, Vector3(0.18, 3.4, 0.18), Vector3(-3.6, 2.7, lz), Vector3.ZERO, mats["iron"])
		_add_cyl(body, 0.22, 0.22, 0.36, Vector3(-3.6, 4.45, lz), Vector3.ZERO, mats["glow_gold"], 10)
	return body


static func build_layered_tree(parent: Node3D, origin: Vector3, variant: int = 0, scale_f: float = 1.0) -> Node3D:
	var v_kind: int = posmod(variant, 3)
	var tree := StaticBody3D.new()
	tree.name = "LayeredTree_%d" % v_kind
	tree.collision_layer = 1
	tree.collision_mask = 0
	tree.position = origin
	var s: float = maxf(0.6, scale_f)
	tree.scale = Vector3(s, s, s)

	var bark_mat := make_mat(Color.WHITE, "bark", 0.90, 0.02, 1.0, Vector2(1.0, 2.5))
	var leaf_main := make_mat(Color.WHITE, "foliage", 0.84, 0.02, 1.0, Vector2(2.0, 2.0))
	var leaf_bright := make_mat(Color(1.08, 1.12, 0.94), "foliage", 0.82, 0.02, 1.0, Vector2(2.0, 2.0))
	var leaf_deep := make_mat(Color(0.68, 0.84, 0.68), "foliage", 0.86, 0.02, 1.0, Vector2(2.0, 2.0))

	if v_kind == 0:
		# Broadleaf Mediterranean Oak (tapered loft trunk + fork branches + layered foliage clusters)
		_add_cyl_col(tree, 0.58, 5.6, Vector3(0.0, 2.8, 0.0))
		var trunk_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
			{"y": 0.0, "rx": 0.66, "rz": 0.64, "p": 2.0, "col": Color(0.84, 0.82, 0.80)},
			{"y": 2.4, "rx": 0.44, "rz": 0.44, "p": 2.0, "col": Color(0.95, 0.94, 0.92)},
			{"y": 4.8, "rx": 0.28, "rz": 0.28, "p": 2.0, "col": Color.WHITE},
		], 10)
		_add_mesh(tree, trunk_mesh, Vector3.ZERO, Vector3.ZERO, bark_mat, "Trunk")
		_add_cyl(tree, 0.16, 0.26, 2.5, Vector3(-0.75, 4.6, 0.25), Vector3(0.12, 0.0, 0.55), bark_mat, 8)
		_add_cyl(tree, 0.16, 0.26, 2.4, Vector3(0.75, 4.7, -0.25), Vector3(-0.12, 0.0, -0.52), bark_mat, 8)
		var blobs: Array[Dictionary] = [
			{"pos": Vector3(0.0, 6.8, 0.0), "r": 2.9, "mat": leaf_main},
			{"pos": Vector3(-1.7, 5.9, 0.8), "r": 2.15, "mat": leaf_deep},
			{"pos": Vector3(1.8, 6.0, -0.7), "r": 2.20, "mat": leaf_bright},
			{"pos": Vector3(0.2, 8.2, 0.2), "r": 2.05, "mat": leaf_bright},
		]
		for b in blobs:
			var sm := SphereMesh.new()
			sm.radius = float(b["r"])
			sm.height = sm.radius * 1.48
			_add_mesh(tree, sm, b["pos"], Vector3.ZERO, b["mat"])
	elif v_kind == 1:
		# Tall Slender Mediterranean Cypress (conical tiered spires)
		_add_cyl_col(tree, 0.42, 7.5, Vector3(0.0, 3.75, 0.0))
		_add_cyl(tree, 0.26, 0.44, 3.2, Vector3(0.0, 1.6, 0.0), Vector3.ZERO, bark_mat, 8, "CypressTrunk")
		var tiers: Array[Dictionary] = [
			{"y0": 2.0, "y1": 6.4, "r0": 1.65, "r1": 0.95, "mat": leaf_deep},
			{"y0": 4.8, "y1": 9.2, "r0": 1.38, "r1": 0.65, "mat": leaf_main},
			{"y0": 7.6, "y1": 11.4, "r0": 0.96, "r1": 0.14, "mat": leaf_bright},
		]
		for t in tiers:
			var spire: ArrayMesh = HeroMeshBuilder.make_loft([
				{"y": float(t["y0"]), "rx": float(t["r0"]), "rz": float(t["r0"]), "p": 2.0, "col": Color(0.84, 0.88, 0.84)},
				{"y": float(t["y1"]), "rx": float(t["r1"]), "rz": float(t["r1"]), "p": 2.0, "col": Color.WHITE},
			], 12)
			_add_mesh(tree, spire, Vector3.ZERO, Vector3.ZERO, t["mat"])
	else:
		# Curved Coastal Palm Tree (arched loft trunk + drooping palm fronds + coconuts)
		_add_cyl_col(tree, 0.42, 6.2, Vector3(0.35, 3.1, 0.0))
		var palm_trunk: ArrayMesh = HeroMeshBuilder.make_loft([
			{"y": 0.0, "x": 0.0, "rx": 0.44, "rz": 0.44, "p": 2.0, "col": Color(0.84, 0.80, 0.76)},
			{"y": 2.2, "x": 0.35, "rx": 0.36, "rz": 0.36, "p": 2.0, "col": Color(0.92, 0.88, 0.84)},
			{"y": 4.8, "x": 0.82, "rx": 0.29, "rz": 0.29, "p": 2.0, "col": Color(0.96, 0.94, 0.90)},
			{"y": 7.2, "x": 1.15, "rx": 0.24, "rz": 0.24, "p": 2.0, "col": Color.WHITE},
		], 10)
		_add_mesh(tree, palm_trunk, Vector3.ZERO, Vector3.ZERO, bark_mat, "PalmTrunk")
		var crown_pos := Vector3(1.15, 7.25, 0.0)
		for c_idx in range(3):
			var ca: float = float(c_idx) * (TAU / 3.0)
			var nut := SphereMesh.new()
			nut.radius = 0.22
			nut.height = 0.44
			_add_mesh(tree, nut, crown_pos + Vector3(cos(ca) * 0.28, -0.22, sin(ca) * 0.28), Vector3.ZERO, bark_mat)
		for f_idx in range(7):
			var fa: float = float(f_idx) * (TAU / 7.0)
			var frond := Node3D.new()
			frond.position = crown_pos
			frond.rotation.y = fa
			tree.add_child(frond)
			_add_box(frond, Vector3(0.95, 0.10, 2.2), Vector3(0.0, 0.16, 1.05), Vector3(0.20, 0.0, 0.0), leaf_bright)
			_add_box(frond, Vector3(0.75, 0.09, 2.0), Vector3(0.0, -0.28, 2.85), Vector3(0.42, 0.0, 0.0), leaf_main)

	parent.add_child(tree, true)
	return tree


static func build_river_bridge(
	parent: Node3D,
	center_pos: Vector3,
	yaw: float = 0.0,
	span_len: float = 64.0,
	bridge_width: float = 18.0,
	deck_y: float = 5.4,
	name_prefix: String = "RiverBridge"
) -> StaticBody3D:
	var body := _make_static_body(parent, name_prefix, center_pos, yaw)
	var mats: Dictionary = _make_palette()
	var ground_y: float = 2.15
	var half_span: float = span_len * 0.5
	var half_w: float = bridge_width * 0.5
	var deck_thickness: float = 0.60
	var deck_top: float = deck_y
	var deck_bot: float = deck_y - deck_thickness

	# 1. Main horizontal bridge deck span across the central river (local X from -half_span to +half_span)
	_add_box(body, Vector3(span_len, deck_thickness, bridge_width), Vector3(0.0, deck_top - deck_thickness * 0.5, 0.0), Vector3.ZERO, mats["cobble"], "BridgeDeck")
	_add_box_col(body, Vector3(span_len, deck_thickness, bridge_width), Vector3(0.0, deck_top - deck_thickness * 0.5, 0.0))

	# 2. Side stone parapets / railings along bridge edges (local Z = +/- (half_w - 0.35))
	var parapet_h: float = 1.15
	var parapet_w: float = 0.70
	var parapet_total_len: float = span_len + 56.0
	for sz in [-1.0, 1.0]:
		var pz: float = sz * (half_w - parapet_w * 0.5)
		_add_box(body, Vector3(span_len, parapet_h, parapet_w), Vector3(0.0, deck_top + parapet_h * 0.5, pz), Vector3.ZERO, mats["stone_trim"], "Parapet_%s" % ("L" if sz < 0.0 else "R"))
		_add_box_col(body, Vector3(span_len, parapet_h, parapet_w), Vector3(0.0, deck_top + parapet_h * 0.5, pz))

	# 3. Two solid stone masonry abutment piers anchored in the riverbanks (local X <= -22m and X >= +22m)
	# Central >= 40m navigable boat channel is completely clear of piers!
	var pier_thickness: float = 12.0
	var pier_w: float = bridge_width + 1.2
	var pier_h: float = deck_bot - (-4.2)
	var pier_cy: float = (-4.2 + deck_bot) * 0.5
	for sx in [-1.0, 1.0]:
		var pier_cx: float = sx * (22.0 + pier_thickness * 0.5) # sx * 28.0m
		_add_box(body, Vector3(pier_thickness, pier_h, pier_w), Vector3(pier_cx, pier_cy, 0.0), Vector3.ZERO, mats["stone"], "AbutmentPier_%s" % ("W" if sx < 0.0 else "E"))
		_add_box_col(body, Vector3(pier_thickness, pier_h, pier_w), Vector3(pier_cx, pier_cy, 0.0))

	# 4. Smooth cobble driving approach ramps connecting deck_y down to ground_y (2.15m) on both riverbanks
	# West approach ramp: X from -60.0 to -32.0
	_add_ramp_between(body, Vector3(-half_span - 28.0, ground_y, 0.0), Vector3(-half_span, deck_top, 0.0), bridge_width, deck_thickness, mats["cobble"], false)
	# East approach ramp: X from +32.0 to +60.0
	_add_ramp_between(body, Vector3(half_span, deck_top, 0.0), Vector3(half_span + 28.0, ground_y, 0.0), bridge_width, deck_thickness, mats["cobble"], false)

	# Side parapets along the approach ramps
	for sz in [-1.0, 1.0]:
		var pz: float = sz * (half_w - parapet_w * 0.5)
		_add_ramp_between(body, Vector3(-half_span - 28.0, ground_y + parapet_h, pz), Vector3(-half_span, deck_top + parapet_h, pz), parapet_w, parapet_h, mats["stone_trim"], false)
		_add_ramp_between(body, Vector3(half_span, deck_top + parapet_h, pz), Vector3(half_span + 28.0, ground_y + parapet_h, pz), parapet_w, parapet_h, mats["stone_trim"], false)

	# 5. Decorative arch fascia ribs & keystone under deck edges for Mediterranean stone aesthetic
	for sz in [-1.0, 1.0]:
		var pz: float = sz * (half_w - 0.25)
		_add_box(body, Vector3(span_len, 0.42, 0.38), Vector3(0.0, deck_bot - 0.21, pz), Vector3.ZERO, mats["stone_trim"])
		_add_box(body, Vector3(6.5, 1.8, 0.38), Vector3(-20.0, deck_bot - 0.9, pz), Vector3(0.0, 0.0, 0.32), mats["stone_trim"])
		_add_box(body, Vector3(6.5, 1.8, 0.38), Vector3(20.0, deck_bot - 0.9, pz), Vector3(0.0, 0.0, -0.32), mats["stone_trim"])
		# Keystone medallion at center
		_add_box(body, Vector3(2.2, 1.1, 0.55), Vector3(0.0, deck_bot - 0.35, pz * 1.03), Vector3.ZERO, mats["stone"])

	return body


static func build_river_dock(
	parent: Node3D,
	pos: Vector3,
	yaw: float = 0.0,
	dock_name: String = "RiverDock"
) -> StaticBody3D:
	var body := _make_static_body(parent, dock_name, pos, yaw)
	var mats: Dictionary = _make_palette()
	var wood_deck: StandardMaterial3D = mats["timber_warm"]
	var wood_post: StandardMaterial3D = mats["timber_dark"]
	var iron_mat: StandardMaterial3D = mats["iron"]
	var deck_y: float = 0.95
	var deck_thickness: float = 0.36

	# Timber Jetty Deck: 12.0m along bank (local X) x 6.5m extending out over water (local Z)
	_add_box(body, Vector3(12.0, deck_thickness, 6.5), Vector3(0.0, deck_y - deck_thickness * 0.5, 2.25), Vector3.ZERO, wood_deck, "DockDeck")
	_add_box_col(body, Vector3(12.0, deck_thickness, 6.5), Vector3(0.0, deck_y - deck_thickness * 0.5, 2.25))

	# Wooden steps / ramp connecting mainland bank (Y = 2.15) down to jetty deck (Y = 0.95)
	var ramp_dz: float = 4.2
	var ramp_dy: float = 2.15 - deck_y
	var ramp_len: float = sqrt(ramp_dz * ramp_dz + ramp_dy * ramp_dy)
	var ramp_pitch: float = atan2(ramp_dy, ramp_dz)
	_add_box(body, Vector3(5.0, deck_thickness, ramp_len), Vector3(0.0, (2.15 + deck_y) * 0.5 - deck_thickness * 0.5, -2.1), Vector3(ramp_pitch, 0.0, 0.0), wood_deck, "BankStairs")
	_add_box_col(body, Vector3(5.0, deck_thickness, ramp_len), Vector3(0.0, (2.15 + deck_y) * 0.5 - deck_thickness * 0.5, -2.1), Vector3(ramp_pitch, 0.0, 0.0))

	# Timber pilings reaching riverbed Y = -4.0
	for px in [-5.2, 0.0, 5.2]:
		for pz in [-0.6, 2.4, 5.2]:
			_add_cyl(body, 0.22, 0.26, 5.2, Vector3(px, -1.6, pz), Vector3.ZERO, wood_post, 8)

	# Mooring bollards on outer jetty edges
	for px in [-5.0, -1.8, 1.8, 5.0]:
		_add_cyl(body, 0.16, 0.18, 0.58, Vector3(px, deck_y + 0.29, 5.2), Vector3.ZERO, iron_mat, 8)
		_add_cyl_col(body, 0.20, 0.65, Vector3(px, deck_y + 0.32, 5.2))

	# Riverside lantern post at dock entrance
	_add_box(body, Vector3(0.20, 3.4, 0.20), Vector3(-4.8, deck_y + 1.7, -0.6), Vector3.ZERO, wood_post)
	_add_cyl(body, 0.22, 0.22, 0.36, Vector3(-4.8, deck_y + 3.4, -0.6), Vector3.ZERO, mats["glow_gold"], 8)

	return body


static func build_farm_complex(
	parent: Node3D,
	center_pos: Vector3,
	yaw: float = 0.0,
	name_prefix: String = "Fazenda"
) -> Node3D:
	var farm := Node3D.new()
	farm.name = name_prefix
	farm.position = center_pos
	farm.rotation.y = yaw
	parent.add_child(farm, true)

	var mats: Dictionary = _make_palette()
	var red_wood: StandardMaterial3D = mats["red_paint"]
	var white_wood: StandardMaterial3D = mats["white_paint"]
	var roof_mat: StandardMaterial3D = mats["roof"]
	var timber_mat: StandardMaterial3D = mats["timber_warm"]
	var stone_mat: StandardMaterial3D = mats["stone"]
	var iron_mat: StandardMaterial3D = mats["iron"]
	var hay_mat: StandardMaterial3D = make_mat(Color(0.92, 0.82, 0.34), "wood_crate", 0.90, 0.02, 1.0, Vector2(1.5, 1.5))
	var soil_mat: StandardMaterial3D = make_mat(Color(0.28, 0.22, 0.16), "bark", 0.92, 0.01, 1.0, Vector2(4.0, 4.0))
	var crop_green: StandardMaterial3D = mats["foliage"]

	# ========================================================
	# 1. RedBarn: Main Red Countryside Wooden Barn
	# Dimensions: 15.0m wide (X) x 8.0m tall (Y) x 18.0m deep (Z)
	# ========================================================
	var barn := _make_static_body(farm, "RedBarn", Vector3.ZERO)
	# Ground foundation stone footing
	_add_box(barn, Vector3(15.4, 0.6, 18.4), Vector3(0.0, 0.3, 0.0), Vector3.ZERO, stone_mat)
	_add_box_col(barn, Vector3(15.4, 0.6, 18.4), Vector3(0.0, 0.3, 0.0))
	# Red barn walls
	_add_box(barn, Vector3(14.8, 5.4, 17.8), Vector3(0.0, 3.3, 0.0), Vector3.ZERO, red_wood, "BarnBody")
	_add_box_col(barn, Vector3(14.8, 5.4, 17.8), Vector3(0.0, 3.3, 0.0))
	# White corner trim posts
	for cx in [-7.4, 7.4]:
		for cz in [-8.9, 8.9]:
			_add_box(barn, Vector3(0.42, 5.6, 0.42), Vector3(cx, 3.4, cz), Vector3.ZERO, white_wood)

	# Pitched Barn Roof (sloped left & right faces + overhang eaves)
	var roof_pitch: float = 0.52
	var roof_half_w: float = 8.6
	var roof_h_rise: float = roof_half_w * sin(roof_pitch)
	# Left roof slope
	_add_box(barn, Vector3(roof_half_w + 0.6, 0.28, 19.2), Vector3(-4.4, 6.0 + roof_h_rise * 0.5, 0.0), Vector3(0.0, 0.0, roof_pitch), roof_mat, "BarnRoofL")
	_add_box_col(barn, Vector3(roof_half_w + 0.6, 0.28, 19.2), Vector3(-4.4, 6.0 + roof_h_rise * 0.5, 0.0), Vector3(0.0, 0.0, roof_pitch))
	# Right roof slope
	_add_box(barn, Vector3(roof_half_w + 0.6, 0.28, 19.2), Vector3(4.4, 6.0 + roof_h_rise * 0.5, 0.0), Vector3(0.0, 0.0, -roof_pitch), roof_mat, "BarnRoofR")
	_add_box_col(barn, Vector3(roof_half_w + 0.6, 0.28, 19.2), Vector3(4.4, 6.0 + roof_h_rise * 0.5, 0.0), Vector3(0.0, 0.0, -roof_pitch))
	# Gable ends (front and back triangular fascia)
	for gz in [-8.95, 8.95]:
		var gable := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.left_to_right = 0.5
		pm.size = Vector3(14.8, roof_h_rise * 2.0, 0.36)
		gable.mesh = pm
		gable.position = Vector3(0.0, 6.0 + roof_h_rise * 0.5, gz)
		gable.material_override = red_wood
		barn.add_child(gable)

	# White X-braced sliding double barn doors on Front (+Z)
	_add_box(barn, Vector3(5.6, 4.2, 0.24), Vector3(0.0, 2.7, 9.0), Vector3.ZERO, timber_mat)
	# X-bracing diagonal slats
	_add_box(barn, Vector3(0.22, 4.4, 0.32), Vector3(-1.4, 2.7, 9.08), Vector3(0.0, 0.0, 0.64), white_wood)
	_add_box(barn, Vector3(0.22, 4.4, 0.32), Vector3(-1.4, 2.7, 9.08), Vector3(0.0, 0.0, -0.64), white_wood)
	_add_box(barn, Vector3(0.22, 4.4, 0.32), Vector3(1.4, 2.7, 9.08), Vector3(0.0, 0.0, 0.64), white_wood)
	_add_box(barn, Vector3(0.22, 4.4, 0.32), Vector3(1.4, 2.7, 9.08), Vector3(0.0, 0.0, -0.64), white_wood)
	_add_box(barn, Vector3(5.8, 0.22, 0.32), Vector3(0.0, 4.85, 9.08), Vector3.ZERO, white_wood)
	_add_box(barn, Vector3(5.8, 0.22, 0.32), Vector3(0.0, 0.65, 9.08), Vector3.ZERO, white_wood)

	# Hayloft gable window with white shutters + hoist beam extending forward
	_add_box(barn, Vector3(2.2, 2.4, 0.22), Vector3(0.0, 7.8, 9.06), Vector3.ZERO, mats["door_oak"])
	_add_box(barn, Vector3(0.22, 0.22, 2.6), Vector3(0.0, 9.6, 9.8), Vector3.ZERO, timber_mat, "HoistBeam")

	# ========================================================
	# 2. GrainSilo: Beside Barn (X = -11.5, Z = -2.0)
	# ========================================================
	var silo := _make_static_body(farm, "GrainSilo", Vector3(-11.5, 0.0, -2.0))
	var silo_r: float = 2.6
	var silo_h: float = 12.0
	_add_cyl(silo, silo_r, silo_r, silo_h, Vector3(0.0, silo_h * 0.5, 0.0), Vector3.ZERO, stone_mat, 16, "SiloBody")
	_add_cyl_col(silo, silo_r + 0.1, silo_h, Vector3(0.0, silo_h * 0.5, 0.0))
	# Silo domed cap
	var dome_mesh: ArrayMesh = HeroMeshBuilder.make_loft([
		{"y": 12.0, "rx": 2.65, "rz": 2.65, "p": 2.0, "col": Color(0.85, 0.88, 0.92)},
		{"y": 13.5, "rx": 2.20, "rz": 2.20, "p": 2.0, "col": Color.WHITE},
		{"y": 14.5, "rx": 1.20, "rz": 1.20, "p": 2.0, "col": Color.WHITE},
		{"y": 15.0, "rx": 0.25, "rz": 0.25, "p": 2.0, "col": Color.WHITE},
	], 14)
	_add_mesh(silo, dome_mesh, Vector3.ZERO, Vector3.ZERO, iron_mat, "SiloDome")
	_add_cyl(silo, 0.14, 0.14, 1.2, Vector3(0.0, 15.5, 0.0), Vector3.ZERO, iron_mat, 8)

	# ========================================================
	# 3. FarmWindPump: Steel-legged water-pumping windmill
	# Position: (X = 14.0, Z = -6.0)
	# ========================================================
	var pump := _make_static_body(farm, "FarmWindPump", Vector3(14.0, 0.0, -6.0))
	var leg_w0: float = 1.6
	var leg_w1: float = 0.55
	var leg_mat: StandardMaterial3D = iron_mat
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var leg_p0 := Vector3(sx * leg_w0, 0.0, sz * leg_w0)
			var leg_p1 := Vector3(sx * leg_w1, 9.5, sz * leg_w1)
			_add_ramp_between(pump, leg_p0, leg_p1, 0.14, 0.14, leg_mat, false)
	# Cross braces
	for by in [2.6, 5.2, 7.8]:
		var bw: float = lerpf(leg_w0, leg_w1, by / 9.5) * 2.0
		_add_box(pump, Vector3(bw, 0.10, 0.10), Vector3(0.0, by, -bw * 0.5), Vector3.ZERO, leg_mat)
		_add_box(pump, Vector3(bw, 0.10, 0.10), Vector3(0.0, by, bw * 0.5), Vector3.ZERO, leg_mat)
		_add_box(pump, Vector3(0.10, 0.10, bw), Vector3(-bw * 0.5, by, 0.0), Vector3.ZERO, leg_mat)
		_add_box(pump, Vector3(0.10, 0.10, bw), Vector3(bw * 0.5, by, 0.0), Vector3.ZERO, leg_mat)
	# Base collision
	_add_box_col(pump, Vector3(leg_w0 * 2.2, 9.5, leg_w0 * 2.2), Vector3(0.0, 4.75, 0.0))

	# Rotor fan head & tail vane atop tower
	_add_cyl(pump, 0.35, 0.35, 1.2, Vector3(0.0, 9.8, 0.0), Vector3(PI * 0.5, 0.0, 0.0), iron_mat, 8)
	for b_idx in range(12):
		var ba: float = float(b_idx) * (TAU / 12.0)
		_add_box(pump, Vector3(0.24, 1.9, 0.04), Vector3(sin(ba) * 1.1, 9.8 + cos(ba) * 1.1, 0.65), Vector3(0.0, 0.0, ba), white_wood)
	_add_box(pump, Vector3(0.06, 0.95, 2.2), Vector3(0.0, 9.8, -1.5), Vector3.ZERO, white_wood)

	# Water trough at base of windpump
	_add_box(pump, Vector3(2.4, 0.65, 1.2), Vector3(0.0, 0.325, 2.4), Vector3.ZERO, stone_mat)
	_add_box(pump, Vector3(2.1, 0.15, 0.9), Vector3(0.0, 0.55, 2.4), Vector3.ZERO, mats["water"])

	# ========================================================
	# 4. HayBales: Golden straw bale stacks beside barn
	# ========================================================
	var hay_spots: Array[Vector3] = [
		Vector3(-8.8, 0.5, 7.5),
		Vector3(-8.8, 0.5, 9.4),
		Vector3(-8.8, 0.5, 11.3),
		Vector3(-8.8, 1.5, 8.45),
		Vector3(-8.8, 1.5, 10.35),
		Vector3(-8.8, 2.5, 9.4),
	]
	for idx in range(hay_spots.size()):
		var hp: Vector3 = hay_spots[idx]
		_add_box(barn, Vector3(1.7, 1.0, 1.7), hp, Vector3.ZERO, hay_mat, "HayBale_%d" % idx)
		_add_box_col(barn, Vector3(1.7, 1.0, 1.7), hp)

	# ========================================================
	# 5. WoodPaddockFence: Timber post-and-rail fences
	# ========================================================
	var fence_body := _make_static_body(farm, "WoodPaddockFence", Vector3.ZERO)
	var fence_segments: Array[Dictionary] = [
		{"p0": Vector3(10.0, 0.0, 14.0), "p1": Vector3(24.0, 0.0, 14.0)},
		{"p0": Vector3(24.0, 0.0, 14.0), "p1": Vector3(24.0, 0.0, 2.0)},
		{"p0": Vector3(24.0, 0.0, 2.0), "p1": Vector3(18.0, 0.0, 2.0)},
	]
	for seg in fence_segments:
		var p0: Vector3 = seg["p0"]
		var p1: Vector3 = seg["p1"]
		var diff: Vector3 = p1 - p0
		var seg_len: float = diff.length()
		var n_posts: int = maxi(2, int(seg_len / 3.0) + 1)
		for pi in range(n_posts):
			var post_pos: Vector3 = p0.lerp(p1, float(pi) / float(n_posts - 1))
			_add_cyl(fence_body, 0.12, 0.14, 1.45, post_pos + Vector3(0.0, 0.725, 0.0), Vector3.ZERO, timber_mat, 8)
			_add_cyl_col(fence_body, 0.15, 1.45, post_pos + Vector3(0.0, 0.725, 0.0))
		for ry in [0.55, 1.15]:
			_add_ramp_between(fence_body, p0 + Vector3(0.0, ry, 0.0), p1 + Vector3(0.0, ry, 0.0), 0.10, 0.14, timber_mat, false)

	# ========================================================
	# 6. CropRows: Tilled dark soil furrow beds + green crops
	# ========================================================
	_add_box(farm, Vector3(10.0, 0.16, 8.0), Vector3(17.0, 0.08, 8.0), Vector3.ZERO, soil_mat, "CropFurrowBed")
	for rz in range(5, 12, 2):
		_add_box(farm, Vector3(9.2, 0.32, 0.65), Vector3(17.0, 0.28, float(rz)), Vector3.ZERO, crop_green, "CropRow_%d" % rz)

	return farm
