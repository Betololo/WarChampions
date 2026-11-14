class_name CartoonAssets
extends RefCounted

## Generates crisp hand-painted cartoon surface textures and 2D HUD sprites
## (flags, portraits, weapons, skills, widgets, health cross, bullet icon) in memory.

static var _cache: Dictionary = {}


static func get_texture(key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _generate_texture(key)
	_cache[key] = tex
	return tex


static func make_standard_material(tex_key: String, tint: Color = Color.WHITE, uv_scale: Vector2 = Vector2.ONE, roughness: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = get_texture(tex_key)
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = roughness
	return mat


static func _generate_texture(key: String) -> ImageTexture:
	match key:
		"grass":
			return _tex_grass()
		"cobble":
			return _tex_cobble()
		"sidewalk":
			return _tex_sidewalk()
		"wood_crate":
			return _tex_wood_crate()
		"stucco_yellow":
			return _tex_stucco(Color(0.95, 0.86, 0.56), Color(0.84, 0.72, 0.42))
		"stucco_cream":
			return _tex_stucco(Color(0.94, 0.90, 0.78), Color(0.82, 0.76, 0.62))
		"stucco_ochre":
			return _tex_stucco_masonry(Color(0.95, 0.86, 0.60), Color(0.85, 0.72, 0.44), Color(0.72, 0.66, 0.56))
		"stucco_terracotta":
			return _tex_stucco_masonry(Color(0.92, 0.65, 0.46), Color(0.81, 0.53, 0.36), Color(0.70, 0.58, 0.50))
		"stone_masonry":
			return _tex_stone_masonry()
		"awning_stripe":
			return _tex_awning_stripe(Color(0.84, 0.18, 0.16), Color(0.97, 0.94, 0.85))
		"awning_stripe_blue":
			return _tex_awning_stripe(Color(0.16, 0.44, 0.82), Color(0.97, 0.94, 0.85))
		"tarmac_runway":
			return _tex_tarmac_runway()
		"water_fountain":
			return _tex_water_fountain()
		"terracotta", "roof_terracotta":
			return _tex_roof_tiles(Color(0.84, 0.34, 0.20), Color(0.66, 0.24, 0.14))
		"slate_roof":
			return _tex_roof_tiles(Color(0.32, 0.42, 0.54), Color(0.20, 0.28, 0.38))
		"wood_shingle":
			return _tex_roof_tiles(Color(0.56, 0.40, 0.24), Color(0.38, 0.26, 0.14))
		"foliage":
			return _tex_foliage()
		"bark":
			return _tex_bark()
		"sand":
			return _tex_stucco(Color(0.94, 0.85, 0.58), Color(0.86, 0.75, 0.48))
		"hero_jacket_royal":
			return _tex_jacket(Color(0.45, 0.37, 0.25), Color(0.30, 0.24, 0.16), Color(0.68, 0.58, 0.38))
		"hero_jacket_national":
			return _tex_jacket(Color(0.32, 0.34, 0.38), Color(0.18, 0.19, 0.22), Color(0.65, 0.18, 0.18))
		"hero_coat_commando":
			return _tex_jacket(Color(0.18, 0.19, 0.22), Color(0.09, 0.10, 0.12), Color(0.58, 0.18, 0.18))
		"hero_coat_commando_royal":
			return _tex_jacket(Color(0.46, 0.45, 0.30), Color(0.28, 0.28, 0.18), Color(0.70, 0.60, 0.36))
		"hero_gunner_vest":
			return _tex_jacket(Color(0.76, 0.74, 0.68), Color(0.52, 0.50, 0.45), Color(0.40, 0.35, 0.25))
		"hero_cloth_royal":
			return _tex_cloth(Color(0.45, 0.37, 0.25), Color(0.30, 0.24, 0.16), Color(0.68, 0.58, 0.38))
		"hero_cloth_national":
			return _tex_cloth(Color(0.32, 0.34, 0.38), Color(0.18, 0.19, 0.22), Color(0.65, 0.18, 0.18))
		"hero_cloth_commando_royal":
			return _tex_cloth(Color(0.46, 0.45, 0.30), Color(0.28, 0.28, 0.18), Color(0.70, 0.60, 0.36))
		"hero_cloth_commando_national":
			return _tex_cloth(Color(0.18, 0.19, 0.22), Color(0.09, 0.10, 0.12), Color(0.58, 0.18, 0.18))
		"hero_cloth_gunner_royal":
			return _tex_cloth(Color(0.76, 0.74, 0.68), Color(0.52, 0.50, 0.45), Color(0.40, 0.35, 0.25))
		"hero_skin":
			return _tex_skin()
		"hero_arm_tattoo":
			return _tex_arm_tattoo()
		"hero_arm_forearm_wrap":
			return _tex_arm_forearm_wrap()
		"hero_rucksack":
			return _tex_rucksack()
		"hero_leather":
			return _tex_leather()
		"hero_pants_royal":
			return _tex_pants(Color(0.44, 0.37, 0.26), Color(0.32, 0.26, 0.18), Color(0.64, 0.54, 0.36))
		"hero_pants_national":
			return _tex_pants(Color(0.26, 0.27, 0.30), Color(0.17, 0.18, 0.21), Color(0.58, 0.18, 0.18))
		"hero_gun_wood":
			return _tex_stucco(Color(0.50, 0.30, 0.15), Color(0.36, 0.20, 0.09))
		"veh_olive":
			return _tex_armor_plate(Color(0.42, 0.50, 0.28), Color(0.24, 0.29, 0.15), Color(0.56, 0.63, 0.37), Color(0.76, 0.78, 0.56), Color(0.88, 0.80, 0.34), true)
		"veh_panzer":
			return _tex_armor_plate(Color(0.36, 0.38, 0.43), Color(0.18, 0.19, 0.23), Color(0.50, 0.53, 0.58), Color(0.62, 0.65, 0.70), Color(0.72, 0.18, 0.18), false)
		"veh_steel":
			return _tex_armor_plate(Color(0.48, 0.51, 0.56), Color(0.26, 0.28, 0.32), Color(0.66, 0.69, 0.74), Color(0.76, 0.79, 0.84), Color(0.38, 0.40, 0.45), false)
		"veh_track":
			return _tex_veh_track()
		"veh_tire":
			return _tex_veh_tire()
		"veh_wood_deck":
			return _tex_veh_wood_deck()
		"veh_plane_royal":
			return _tex_armor_plate(Color(0.24, 0.50, 0.86), Color(0.14, 0.30, 0.58), Color(0.38, 0.65, 0.96), Color(0.82, 0.88, 0.96), Color(0.95, 0.78, 0.22), true)
		"veh_plane_national":
			return _tex_armor_plate(Color(0.34, 0.37, 0.42), Color(0.18, 0.20, 0.24), Color(0.48, 0.52, 0.58), Color(0.70, 0.73, 0.78), Color(0.86, 0.18, 0.18), false)
		"veh_sandbag":
			return _tex_veh_sandbag()
		"flag_royal":
			return _sprite_flag(true)
		"flag_national":
			return _sprite_flag(false)
		"icon_hp":
			return _sprite_hp_cross()
		"icon_ammo":
			return _sprite_bullet()
		"portrait_royal_0", "portrait_royal_1", "portrait_royal_2":
			return _sprite_portrait(0, int(key.right(1)))
		"portrait_national_0", "portrait_national_1", "portrait_national_2":
			return _sprite_portrait(1, int(key.right(1)))
		_:
			if key.begins_with("icon_weapon_"):
				return _sprite_weapon(key.trim_prefix("icon_weapon_"))
			if key.begins_with("icon_skill_"):
				return _sprite_skill(key.trim_prefix("icon_skill_"))
			if key.begins_with("icon_widget_"):
				return _sprite_widget(key.trim_prefix("icon_widget_"))
			return _tex_stucco(Color.WHITE, Color(0.9, 0.9, 0.9))


static func _new_img(w: int, h: int, fill: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img


static func _draw_rect(img: Image, x0: int, y0: int, w: int, h: int, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	for y in range(maxi(0, y0), mini(ih, y0 + h)):
		for x in range(maxi(0, x0), mini(iw, x0 + w)):
			img.set_pixel(x, y, col)


static func _draw_circle(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var r2: float = r * r
	for y in range(maxi(0, int(cy - r - 1)), mini(ih, int(cy + r + 2))):
		for x in range(maxi(0, int(cx - r - 1)), mini(iw, int(cx + r + 2))):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			if dx * dx + dy * dy <= r2:
				img.set_pixel(x, y, col)


static func _draw_ring(img: Image, cx: float, cy: float, r_outer: float, r_inner: float, col: Color) -> void:
	var iw: int = img.get_width()
	var ih: int = img.get_height()
	var ro2: float = r_outer * r_outer
	var ri2: float = r_inner * r_inner
	for y in range(maxi(0, int(cy - r_outer - 1)), mini(ih, int(cy + r_outer + 2))):
		for x in range(maxi(0, int(cx - r_outer - 1)), mini(iw, int(cx + r_outer + 2))):
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d2: float = dx * dx + dy * dy
			if d2 <= ro2 and d2 >= ri2:
				img.set_pixel(x, y, col)


static func _draw_line(img: Image, p0: Vector2, p1: Vector2, thickness: float, col: Color) -> void:
	var steps: int = maxi(2, int(p0.distance_to(p1) * 2.0))
	for i in range(steps + 1):
		var p: Vector2 = p0.lerp(p1, float(i) / float(steps))
		_draw_circle(img, p.x, p.y, thickness * 0.5, col)


static func _tex_grass() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.26, 0.66, 0.24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	for _i in range(280):
		var x: int = rng.randi_range(0, 120)
		var y: int = rng.randi_range(0, 120)
		var col := Color(0.32, 0.74, 0.26) if rng.randf() > 0.5 else Color(0.20, 0.56, 0.20)
		_draw_rect(img, x, y, rng.randi_range(4, 10), rng.randi_range(2, 5), col)
	return ImageTexture.create_from_image(img)


static func _tex_cobble() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.30, 0.34, 0.40))
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	for row in range(8):
		var y: int = row * 16
		var offset: int = 8 if (row % 2 == 1) else 0
		for col_idx in range(9):
			var x: int = (col_idx * 16 + offset) % 128
			var shade: float = rng.randf_range(0.40, 0.56)
			_draw_rect(img, x + 1, y + 1, 13, 13, Color(shade * 0.92, shade * 0.97, shade * 1.08))
	return ImageTexture.create_from_image(img)


static func _tex_sidewalk() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.68, 0.70, 0.72))
	for i in range(0, 128, 32):
		_draw_rect(img, i, 0, 2, 128, Color(0.48, 0.50, 0.52))
		_draw_rect(img, 0, i, 128, 2, Color(0.48, 0.50, 0.52))
	return ImageTexture.create_from_image(img)


static func _tex_wood_crate() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.56, 0.46, 0.30))
	var border := Color(0.36, 0.28, 0.16)
	var plank := Color(0.46, 0.37, 0.23)
	_draw_rect(img, 0, 0, 128, 12, border)
	_draw_rect(img, 0, 116, 128, 12, border)
	_draw_rect(img, 0, 0, 12, 128, border)
	_draw_rect(img, 116, 0, 12, 128, border)
	for y in [32, 64, 96]:
		_draw_rect(img, 12, y, 104, 3, plank)
	_draw_line(img, Vector2(12, 12), Vector2(116, 116), 9.0, border)
	return ImageTexture.create_from_image(img)


static func _tex_stucco(base: Color, accent: Color) -> ImageTexture:
	var img := _new_img(128, 128, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	for _i in range(90):
		_draw_rect(img, rng.randi_range(0, 118), rng.randi_range(0, 118), rng.randi_range(6, 14), rng.randi_range(4, 10), accent)
	return ImageTexture.create_from_image(img)


static func _tex_roof_tiles(base: Color, dark: Color) -> ImageTexture:
	var img := _new_img(128, 128, base)
	for y in range(0, 128, 16):
		_draw_rect(img, 0, y + 13, 128, 3, dark)
		for x in range(0, 128, 16):
			_draw_rect(img, x + (8 if (y / 16) % 2 == 1 else 0), y, 2, 14, dark)
	return ImageTexture.create_from_image(img)


static func _tex_foliage() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.22, 0.58, 0.16))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for _i in range(180):
		var col := Color(0.32, 0.72, 0.20) if rng.randf() > 0.4 else Color(0.16, 0.46, 0.12)
		_draw_circle(img, rng.randf_range(4, 124), rng.randf_range(4, 124), rng.randf_range(5, 11), col)
	return ImageTexture.create_from_image(img)


static func _tex_bark() -> ImageTexture:
	var img := _new_img(64, 64, Color(0.38, 0.26, 0.16))
	for x in range(4, 64, 10):
		_draw_rect(img, x, 0, 3, 64, Color(0.28, 0.18, 0.10))
	return ImageTexture.create_from_image(img)


static func _tex_stucco_masonry(base: Color, accent: Color, stone_peek: Color) -> ImageTexture:
	var img := _new_img(128, 128, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(base.r * 1000.0) + 77
	# Soft hand-painted plaster brush shading
	for _i in range(95):
		var col: Color = accent if rng.randf() > 0.35 else base.lightened(0.06)
		_draw_rect(img, rng.randi_range(0, 114), rng.randi_range(0, 118), rng.randi_range(8, 18), rng.randi_range(4, 10), col)
	# Subtle weathered base mortar & delicate exposed stone peeks near corners/base
	for y in range(108, 128):
		var t: float = float(y - 108) / 20.0
		_draw_rect(img, 0, y, 128, 1, base.lerp(stone_peek.darkened(0.18), t * 0.45))
	for sp in [Vector2i(14, 96), Vector2i(26, 104), Vector2i(86, 98), Vector2i(102, 108), Vector2i(52, 112)]:
		_draw_rect(img, sp.x - 1, sp.y - 1, 14, 9, stone_peek.darkened(0.22))
		_draw_rect(img, sp.x, sp.y, 12, 7, stone_peek)
	return ImageTexture.create_from_image(img)


static func _tex_stone_masonry() -> ImageTexture:
	var mortar := Color(0.50, 0.48, 0.44)
	var img := _new_img(128, 128, mortar)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var block_h: int = 16
	var block_w: int = 32
	for row in range(8):
		var y: int = row * block_h
		var offset: int = (block_w / 2) if (row % 2 == 1) else 0
		for col_idx in range(5):
			var x: int = (col_idx * block_w + offset) - block_w / 2
			var shade: float = rng.randf_range(0.64, 0.80)
			var warm: float = rng.randf_range(-0.03, 0.04)
			var stone_col := Color(shade + warm, shade + warm * 0.5, shade - 0.04)
			var x0: int = maxi(0, x + 2)
			var w0: int = mini(128, x + block_w - 2) - x0
			if w0 > 0:
				_draw_rect(img, x0, y + 2, w0, block_h - 4, stone_col)
				_draw_rect(img, x0, y + 2, w0, 2, stone_col.lightened(0.14))
				_draw_rect(img, x0, y + block_h - 4, w0, 2, stone_col.darkened(0.16))
	# Occasional coastal moss flecks along mortar joints
	for _m in range(28):
		_draw_circle(img, rng.randf_range(4, 124), float(rng.randi_range(1, 7) * 16), rng.randf_range(1.5, 3.0), Color(0.32, 0.48, 0.22))
	return ImageTexture.create_from_image(img)


static func _tex_awning_stripe(stripe_col: Color, cream_col: Color) -> ImageTexture:
	var img := _new_img(128, 128, cream_col)
	var stripe_w: int = 16
	for x in range(0, 128, stripe_w * 2):
		_draw_rect(img, x, 0, stripe_w, 128, stripe_col)
		# Crisp fabric highlight & stitched edge
		_draw_rect(img, x + 2, 0, 2, 128, stripe_col.lightened(0.12))
	# Subtle canvas weave + scalloped lower valance shadow band
	for y in range(0, 128, 6):
		_draw_rect(img, 0, y, 128, 1, Color(0.0, 0.0, 0.0, 0.06))
	_draw_rect(img, 0, 114, 128, 4, stripe_col.darkened(0.30))
	_draw_rect(img, 0, 118, 128, 10, cream_col.darkened(0.08))
	return ImageTexture.create_from_image(img)


static func _tex_tarmac_runway() -> ImageTexture:
	var base := Color(0.24, 0.25, 0.28)
	var img := _new_img(128, 128, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	# Aggregate grit & weathered tread streaks
	for _i in range(320):
		var c: Color = base.lightened(rng.randf_range(0.04, 0.14)) if rng.randf() > 0.48 else base.darkened(rng.randf_range(0.05, 0.14))
		_draw_rect(img, rng.randi_range(0, 125), rng.randi_range(0, 125), rng.randi_range(1, 3), rng.randi_range(1, 3), c)
	for sy in [34, 42, 86, 94]:
		_draw_rect(img, 0, sy, 128, 2, base.darkened(0.20))
	_draw_line(img, Vector2(18, 12), Vector2(64, 38), 1.4, base.darkened(0.28))
	_draw_line(img, Vector2(72, 84), Vector2(118, 106), 1.4, base.darkened(0.28))
	return ImageTexture.create_from_image(img)


static func _tex_water_fountain() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.20, 0.76, 0.88))
	var deep := Color(0.12, 0.56, 0.76)
	var foam := Color(0.76, 0.96, 1.0)
	for y in range(128):
		var wave: float = 0.5 + 0.5 * sin(float(y) * 0.24)
		_draw_rect(img, 0, y, 128, 1, deep.lerp(Color(0.26, 0.84, 0.94), wave))
	for cy in [32.0, 96.0]:
		for cx in [32.0, 96.0]:
			_draw_ring(img, cx, cy, 24.0, 21.0, foam)
			_draw_ring(img, cx, cy, 13.0, 10.5, Color(0.54, 0.90, 0.98))
			_draw_circle(img, cx - 3.0, cy - 3.0, 2.8, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _draw_dashed_h(img: Image, x0: int, x1: int, y: int, step: int, col: Color) -> void:
	for x in range(x0, x1, step):
		_draw_rect(img, x, y, maxi(1, step / 2), 1, col)


static func _draw_dashed_v(img: Image, x: int, y0: int, y1: int, step: int, col: Color) -> void:
	for y in range(y0, y1, step):
		_draw_rect(img, x, y, 1, maxi(1, step / 2), col)


static func _new_cloth_canvas(base: Color, seam: Color, highlight: Color) -> Image:
	var img := _new_img(128, 128, base)
	for y in range(128):
		var vy: float = float(y) / 127.0
		var row_col: Color = base
		if vy > 0.80:
			row_col = base.lerp(seam, (vy - 0.80) * 2.2)
		elif vy < 0.18:
			row_col = base.lerp(highlight, (0.18 - vy) * 3.8)
		_draw_rect(img, 0, y, 128, 1, row_col)
		if y % 4 == 0:
			for x in range((y % 8), 128, 8):
				_draw_rect(img, x, y, 3, 1, row_col.lightened(0.04))
	return img


## Clean herringbone weave & seam stitching for sleeves, collars, epaulets & coat tails (zero chest buttons/pockets).
static func _tex_cloth(base: Color, seam: Color, accent: Color) -> ImageTexture:
	var highlight: Color = base.lightened(0.11)
	var shade: Color = base.lerp(seam, 0.45)
	var stitch: Color = accent.lerp(highlight, 0.45)
	var img := _new_cloth_canvas(base, seam, highlight)
	for px in [31, 63, 95]:
		_draw_rect(img, px, 0, 2, 128, shade)
	_draw_dashed_v(img, 61, 8, 124, 5, stitch)
	_draw_dashed_h(img, 0, 128, 118, 4, stitch)
	return ImageTexture.create_from_image(img)


static func _tex_jacket(base: Color, seam: Color, accent: Color) -> ImageTexture:
	var shade: Color = base.lerp(seam, 0.48)
	var highlight: Color = base.lightened(0.11)
	var stitch: Color = accent.lerp(highlight, 0.45)
	var brass: Color = Color(0.88, 0.72, 0.28)
	var img := _new_cloth_canvas(base, seam, highlight)

	# Horizontal shoulder yoke & topstitching across back (visible in TPS)
	_draw_rect(img, 30, 23, 68, 3, highlight)
	_draw_rect(img, 30, 26, 68, 3, seam)
	_draw_dashed_h(img, 32, 96, 29, 4, stitch)

	# Underarm fold shadows & rear back-pleat folds
	for sx in [29, 93]:
		_draw_rect(img, sx, 26, 6, 74, shade)
	for px in [46, 80]:
		_draw_rect(img, px, 30, 2, 56, shade)

	# Shoulder insignia rank stripes on outer sleeve/shoulder zones (u ~ 0.25 & 0.75)
	for ix in [25, 91]:
		_draw_rect(img, ix, 18, 12, 3, accent)
		_draw_rect(img, ix, 23, 12, 3, accent)

	# Center back seam + split coat hem vent
	_draw_rect(img, 63, 14, 2, 82, seam)
	_draw_rect(img, 62, 96, 4, 32, seam.darkened(0.15))
	_draw_dashed_v(img, 60, 20, 124, 5, stitch)

	# Waist cinch seam & hem stitching
	_draw_rect(img, 0, 92, 128, 6, shade)
	_draw_dashed_h(img, 0, 128, 91, 4, stitch)
	_draw_dashed_h(img, 0, 128, 122, 4, stitch)

	# Front lapels, placket closure, brass buttons & pocket flaps (u ~ 0.0 & 1.0)
	_draw_rect(img, 0, 0, 5, 124, seam)
	_draw_rect(img, 123, 0, 5, 124, seam)
	_draw_rect(img, 5, 8, 14, 26, highlight)
	_draw_rect(img, 109, 8, 14, 26, highlight)
	_draw_line(img, Vector2(5, 8), Vector2(18, 34), 2.0, seam)
	_draw_line(img, Vector2(122, 8), Vector2(109, 34), 2.0, seam)
	for by in [38, 54, 70, 86]:
		_draw_circle(img, 6, by, 2.1, brass)
		_draw_circle(img, 121, by, 2.1, brass)
	for kx in [9, 103]:
		_draw_rect(img, kx, 42, 16, 15, shade)
		_draw_rect(img, kx, 42, 16, 4, accent)
		_draw_circle(img, kx + 8, 48, 1.8, brass)
		_draw_rect(img, kx - 1, 76, 18, 14, shade)
		_draw_rect(img, kx - 1, 76, 18, 4, accent)
	return ImageTexture.create_from_image(img)


static func _tex_pants(base: Color, shadow: Color, accent: Color) -> ImageTexture:
	var img := _new_img(128, 128, base)
	var hi: Color = base.lightened(0.08)
	for y in range(128):
		var vy: float = float(y) / 127.0
		var row_col: Color = base
		if vy > 0.45 and vy < 0.60:
			row_col = base.lerp(shadow, 0.35) # knee fold AO
		elif vy > 0.86:
			row_col = shadow # boot cuff shadow
		elif vy < 0.16:
			row_col = hi
		_draw_rect(img, 0, y, 128, 1, row_col)
		if y % 6 == 0:
			for x in range((y % 12), 128, 12):
				_draw_rect(img, x, y, 4, 1, row_col.lightened(0.03))
	# Vertical trouser pleats & outer side piping/stitching
	for px in [0, 63, 126]:
		_draw_rect(img, px, 6, 2, 114, shadow)
	for sx in [31, 95]:
		_draw_rect(img, sx, 0, 3, 128, shadow)
		_draw_rect(img, sx + 1, 0, 1, 128, accent.lerp(base, 0.45))
	_draw_dashed_h(img, 0, 128, 112, 4, accent.lerp(hi, 0.4))
	return ImageTexture.create_from_image(img)


static func _tex_skin() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.92, 0.72, 0.58))
	# Warm crown/forehead highlight, subtle cheek blush & soft jaw/neck shadow
	_draw_rect(img, 0, 0, 128, 28, Color(0.96, 0.78, 0.64))
	_draw_rect(img, 0, 96, 128, 32, Color(0.78, 0.58, 0.46))
	for cx in [18, 110]:
		_draw_circle(img, cx, 56, 12.0, Color(0.92, 0.64, 0.52))
	_draw_rect(img, 0, 40, 128, 6, Color(0.85, 0.65, 0.52)) # subtle brow crease
	return ImageTexture.create_from_image(img)


static func _tex_arm_tattoo() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.92, 0.72, 0.58))
	_draw_rect(img, 0, 0, 128, 20, Color(0.96, 0.78, 0.64))
	_draw_rect(img, 0, 102, 128, 26, Color(0.84, 0.64, 0.50))
	var ink := Color(0.22, 0.28, 0.34)
	var ink_hi := Color(0.36, 0.40, 0.44)
	# Twin bicep armbands & stylized nautical anchor-wing tattoos on outer upper arms (u ~ 0.25 & 0.75)
	_draw_rect(img, 0, 30, 128, 5, ink)
	_draw_rect(img, 0, 38, 128, 3, ink_hi)
	for cx in [32, 96]:
		for s in range(-12, 13, 6):
			_draw_line(img, Vector2(cx + s, 30), Vector2(cx + s + 3, 23), 2.5, ink)
		_draw_line(img, Vector2(cx, 52), Vector2(cx, 84), 3.4, ink)
		_draw_line(img, Vector2(cx - 10, 60), Vector2(cx + 10, 60), 3.0, ink)
		_draw_line(img, Vector2(cx - 12, 75), Vector2(cx, 86), 3.2, ink)
		_draw_line(img, Vector2(cx + 12, 75), Vector2(cx, 86), 3.2, ink)
		_draw_circle(img, cx, 50, 3.8, ink_hi)
	return ImageTexture.create_from_image(img)


static func _tex_arm_forearm_wrap() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.92, 0.72, 0.58))
	# Bare tanned forearm skin blending from elbow with a rugged leather-strapped wrist bracer wrap
	_draw_rect(img, 0, 0, 128, 24, Color(0.85, 0.65, 0.51))
	_draw_rect(img, 0, 24, 128, 58, Color(0.92, 0.72, 0.58))
	var wrap_base := Color(0.34, 0.23, 0.15)
	var wrap_dark := Color(0.22, 0.15, 0.10)
	var stitch := Color(0.68, 0.56, 0.36)
	_draw_rect(img, 0, 84, 128, 38, wrap_base)
	for wy in [86, 98, 110]:
		_draw_rect(img, 0, wy, 128, 2, wrap_dark)
	_draw_dashed_h(img, 2, 126, 85, 4, stitch)
	_draw_dashed_h(img, 2, 126, 120, 4, stitch)
	for bx in [32, 96]:
		_draw_rect(img, bx - 5, 92, 10, 14, wrap_dark)
		_draw_rect(img, bx - 3, 95, 6, 8, Color(0.86, 0.70, 0.28))
	return ImageTexture.create_from_image(img)


static func _tex_rucksack() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.48, 0.44, 0.30))
	var weave := Color(0.42, 0.38, 0.25)
	var hi := Color(0.56, 0.51, 0.36)
	var strap := Color(0.24, 0.17, 0.12)
	for y in range(0, 128, 4):
		_draw_rect(img, 0, y, 128, 1, weave)
	for x in range(0, 128, 4):
		_draw_rect(img, x, 0, 1, 128, weave)
	_draw_rect(img, 0, 38, 128, 6, Color(0.30, 0.26, 0.18))
	_draw_dashed_h(img, 4, 124, 36, 4, hi)
	for sx in [26, 92]:
		_draw_rect(img, sx, 0, 10, 128, strap)
		_draw_rect(img, sx + 1, 44, 8, 8, Color(0.84, 0.68, 0.26))
	return ImageTexture.create_from_image(img)


static func _tex_leather() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.38, 0.26, 0.17))
	var grain := Color(0.28, 0.18, 0.12)
	var sheen := Color(0.48, 0.34, 0.22)
	var stitch := Color(0.68, 0.54, 0.34)
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	for _i in range(110):
		var col: Color = sheen if rng.randf() > 0.5 else grain
		_draw_rect(img, rng.randi_range(0, 120), rng.randi_range(0, 122), rng.randi_range(3, 10), rng.randi_range(2, 4), col)
	_draw_dashed_h(img, 4, 124, 6, 4, stitch)
	_draw_dashed_h(img, 4, 124, 121, 4, stitch)
	_draw_dashed_v(img, 6, 4, 124, 4, stitch)
	_draw_dashed_v(img, 121, 4, 124, 4, stitch)
	return ImageTexture.create_from_image(img)


static func _sprite_flag(is_royal: bool) -> ImageTexture:
	var img := _new_img(96, 60, Color(0, 0, 0, 0))
	var bg: Color = Color(0.14, 0.52, 0.94) if is_royal else Color(0.82, 0.16, 0.16)
	var border: Color = Color(0.08, 0.20, 0.45) if is_royal else Color(0.38, 0.06, 0.06)
	_draw_rect(img, 4, 4, 88, 52, border)
	_draw_rect(img, 8, 8, 80, 44, bg)
	if is_royal:
		# White cross + gold crown emblem
		_draw_rect(img, 8, 26, 80, 8, Color(0.95, 0.97, 1.0))
		_draw_rect(img, 44, 8, 8, 44, Color(0.95, 0.97, 1.0))
		_draw_rect(img, 34, 22, 28, 16, Color(1.0, 0.84, 0.18))
		_draw_rect(img, 34, 16, 6, 8, Color(1.0, 0.84, 0.18))
		_draw_rect(img, 45, 14, 6, 10, Color(1.0, 0.84, 0.18))
		_draw_rect(img, 56, 16, 6, 8, Color(1.0, 0.84, 0.18))
	else:
		# Crossed bones + cartoon skull
		_draw_line(img, Vector2(22, 16), Vector2(74, 44), 6.0, Color(0.96, 0.94, 0.90))
		_draw_line(img, Vector2(74, 16), Vector2(22, 44), 6.0, Color(0.96, 0.94, 0.90))
		_draw_circle(img, 48, 27, 13.0, Color(0.98, 0.96, 0.92))
		_draw_rect(img, 40, 35, 16, 9, Color(0.98, 0.96, 0.92))
		_draw_circle(img, 42, 27, 3.5, Color(0.12, 0.10, 0.10))
		_draw_circle(img, 54, 27, 3.5, Color(0.12, 0.10, 0.10))
	return ImageTexture.create_from_image(img)


static func _sprite_hp_cross() -> ImageTexture:
	var img := _new_img(48, 48, Color(0, 0, 0, 0))
	_draw_rect(img, 16, 4, 16, 40, Color(0.15, 0.25, 0.45))
	_draw_rect(img, 4, 16, 40, 16, Color(0.15, 0.25, 0.45))
	_draw_rect(img, 18, 6, 12, 36, Color(0.45, 0.82, 1.0))
	_draw_rect(img, 6, 18, 36, 12, Color(0.45, 0.82, 1.0))
	return ImageTexture.create_from_image(img)


static func _sprite_bullet() -> ImageTexture:
	var img := _new_img(36, 48, Color(0, 0, 0, 0))
	_draw_rect(img, 10, 16, 16, 26, Color(0.95, 0.72, 0.18))
	_draw_circle(img, 18, 16, 8.0, Color(1.0, 0.86, 0.35))
	_draw_rect(img, 12, 38, 12, 4, Color(0.65, 0.45, 0.12))
	return ImageTexture.create_from_image(img)


static func _sprite_portrait(team: int, class_id: int) -> ImageTexture:
	var img := _new_img(72, 72, Color(0, 0, 0, 0))
	var bg := Color(0.20, 0.48, 0.88) if team == 0 else Color(0.45, 0.22, 0.20)
	_draw_circle(img, 36, 36, 33.0, Color(0.14, 0.16, 0.20))
	_draw_circle(img, 36, 36, 30.0, bg)
	# Shoulders & square jaw face
	var jacket := Color(0.42, 0.36, 0.22) if team == 0 else Color(0.24, 0.24, 0.26)
	_draw_rect(img, 16, 48, 40, 18, jacket)
	_draw_rect(img, 24, 22, 24, 28, Color(0.94, 0.76, 0.62))
	# Eyes / Sunglasses
	if class_id == 1 or class_id == 2:
		_draw_rect(img, 26, 31, 9, 5, Color(0.1, 0.1, 0.12))
		_draw_rect(img, 37, 31, 9, 5, Color(0.1, 0.1, 0.12))
	else:
		_draw_rect(img, 28, 32, 4, 4, Color(0.12, 0.12, 0.12))
		_draw_rect(img, 40, 32, 4, 4, Color(0.12, 0.12, 0.12))
		_draw_rect(img, 29, 41, 14, 4, Color(0.28, 0.18, 0.12)) # Mustache
	# Hat / Beret
	var hat_col := Color(0.75, 0.16, 0.16) if class_id == 1 else (Color(0.12, 0.12, 0.14) if class_id == 2 else jacket.darkened(0.25))
	_draw_rect(img, 20, 14, 32, 10, hat_col)
	if class_id == 2:
		_draw_rect(img, 12, 21, 48, 4, hat_col)
	_draw_ring(img, 36, 36, 34.0, 30.0, Color(0.92, 0.92, 0.95))
	return ImageTexture.create_from_image(img)


static func _sprite_weapon(kind_str: String) -> ImageTexture:
	var img := _new_img(48, 32, Color(0, 0, 0, 0))
	var gun := Color(0.94, 0.96, 1.0)
	match kind_str:
		"0", "1": # SMG / MG
			_draw_rect(img, 6, 12, 34, 6, gun)
			_draw_rect(img, 18, 18, 6, 10, gun)
			_draw_rect(img, 4, 14, 6, 10, Color(0.75, 0.55, 0.25))
		"2": # Shotgun
			_draw_rect(img, 4, 13, 40, 5, gun)
			_draw_rect(img, 6, 16, 10, 7, Color(0.75, 0.45, 0.22))
		"3": # Pistol
			_draw_rect(img, 14, 10, 22, 6, gun)
			_draw_rect(img, 14, 16, 7, 10, gun)
		"4": # Sniper
			_draw_rect(img, 3, 14, 42, 4, gun)
			_draw_rect(img, 18, 8, 14, 4, Color(0.8, 0.9, 1.0))
			_draw_rect(img, 4, 16, 12, 6, Color(0.72, 0.44, 0.22))
		"5": # Knife
			_draw_line(img, Vector2(10, 24), Vector2(36, 6), 5.0, gun)
			_draw_rect(img, 8, 20, 8, 6, Color(0.65, 0.42, 0.22))
		"6": # Bazooka
			_draw_rect(img, 4, 10, 40, 10, Color(0.45, 0.65, 0.35))
			_draw_rect(img, 38, 8, 6, 14, Color(0.95, 0.65, 0.2))
		"7": # TNT
			_draw_rect(img, 12, 8, 24, 18, Color(0.90, 0.20, 0.16))
			_draw_rect(img, 18, 4, 12, 4, Color(1.0, 0.85, 0.2))
	return ImageTexture.create_from_image(img)


static func _sprite_skill(slot_str: String) -> ImageTexture:
	var img := _new_img(40, 40, Color(0, 0, 0, 0))
	var idx: int = int(slot_str)
	var colors: Array[Color] = [
		Color(0.28, 0.90, 0.45),
		Color(1.0, 0.48, 0.16),
		Color(0.95, 0.80, 0.20),
		Color(0.35, 0.72, 1.0),
		Color(0.85, 0.35, 0.95),
	]
	var c: Color = colors[posmod(idx, colors.size())]
	_draw_circle(img, 20, 20, 16.0, Color(0.12, 0.15, 0.20, 0.85))
	_draw_circle(img, 20, 20, 12.0, c)
	_draw_ring(img, 20, 20, 17.0, 15.0, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _sprite_widget(slot_str: String) -> ImageTexture:
	var img := _new_img(40, 40, Color(0, 0, 0, 0))
	var idx: int = int(slot_str)
	if idx == 0: # Bandage
		_draw_rect(img, 6, 12, 28, 16, Color(0.95, 0.95, 0.92))
		_draw_rect(img, 17, 14, 6, 12, Color(0.9, 0.2, 0.2))
		_draw_rect(img, 14, 17, 12, 6, Color(0.9, 0.2, 0.2))
	elif idx == 1: # Wrench
		_draw_line(img, Vector2(10, 30), Vector2(30, 10), 6.0, Color(0.85, 0.88, 0.92))
		_draw_circle(img, 30, 10, 6.0, Color(0.75, 0.80, 0.88))
	else: # Antidote / Fireproof
		_draw_rect(img, 13, 12, 14, 22, Color(0.25, 0.85, 0.95))
		_draw_rect(img, 16, 6, 8, 6, Color(0.85, 0.65, 0.35))
	return ImageTexture.create_from_image(img)


static func _draw_star(img: Image, cx: float, cy: float, r_outer: float, col: Color) -> void:
	for i in range(5):
		var a0: float = -PI * 0.5 + float(i) * (TAU / 5.0)
		var a1: float = a0 + (TAU / 5.0) * 2.0
		var p0 := Vector2(cx + cos(a0) * r_outer, cy + sin(a0) * r_outer)
		var p1 := Vector2(cx + cos(a1) * r_outer, cy + sin(a1) * r_outer)
		_draw_line(img, Vector2(cx, cy), p0, 2.2, col)
		_draw_line(img, p0, p1, 1.8, col)


static func _tex_armor_plate(
	base: Color,
	seam: Color,
	highlight: Color,
	rivet: Color,
	accent: Color,
	has_star: bool
) -> ImageTexture:
	var img := _new_img(128, 128, base)
	# Soft vertical armor plate shading & weathered brush marks
	for y in range(128):
		var t: float = float(y % 64) / 63.0
		var row_col: Color = base.lerp(highlight, 0.22 * (1.0 - t)) if t < 0.35 else base.lerp(seam, 0.16 * ((t - 0.35) / 0.65))
		_draw_rect(img, 0, y, 128, 1, row_col)
	var rng := RandomNumberGenerator.new()
	rng.seed = 606
	for _i in range(42):
		var sc: Color = highlight.lerp(base, 0.55) if rng.randf() > 0.5 else seam.lerp(base, 0.65)
		_draw_rect(img, rng.randi_range(4, 110), rng.randi_range(4, 120), rng.randi_range(8, 22), rng.randi_range(2, 4), sc)
	# Crisp armor panel seams + beveled highlight line
	for p in [0, 64]:
		_draw_rect(img, 0, p, 128, 2, seam)
		_draw_rect(img, 0, (p + 2) % 128, 128, 1, highlight)
		_draw_rect(img, p, 0, 2, 128, seam)
		_draw_rect(img, (p + 2) % 128, 0, 1, 128, highlight)
	# Accent trim wash strip along top panel edge
	_draw_rect(img, 0, 56, 128, 5, accent.lerp(base, 0.35))
	# Corner & edge rivets along armor panels
	for py in [6, 58, 70, 122]:
		for px in range(8, 128, 16):
			_draw_circle(img, float(px) + 0.8, float(py) + 0.8, 1.8, seam)
			_draw_circle(img, float(px), float(py), 1.6, rivet)
	if has_star:
		_draw_circle(img, 32.0, 32.0, 11.0, base.lerp(seam, 0.35))
		_draw_star(img, 32.0, 32.0, 9.0, accent.lerp(Color.WHITE, 0.35))
	else:
		_draw_rect(img, 20, 24, 24, 5, accent.lerp(base, 0.25))
		_draw_rect(img, 29, 15, 5, 24, accent.lerp(base, 0.25))
	return ImageTexture.create_from_image(img)


static func _tex_veh_track() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.20, 0.21, 0.23))
	var cleat_dark := Color(0.11, 0.12, 0.13)
	var cleat_hi := Color(0.45, 0.48, 0.52)
	var mud := Color(0.27, 0.22, 0.17)
	for y in range(0, 128, 16):
		_draw_rect(img, 0, y, 128, 3, cleat_dark)
		_draw_rect(img, 0, y + 3, 128, 6, Color(0.30, 0.32, 0.35))
		_draw_rect(img, 0, y + 3, 128, 2, cleat_hi)
		_draw_rect(img, 0, y + 10, 128, 5, mud)
		# Center guide teeth & track link pins
		_draw_rect(img, 58, y + 1, 12, 13, cleat_dark)
		_draw_rect(img, 60, y + 2, 8, 9, cleat_hi)
		for px in [10, 114]:
			_draw_circle(img, float(px), float(y + 6), 2.4, cleat_hi)
	return ImageTexture.create_from_image(img)


static func _tex_veh_tire() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.18, 0.19, 0.21))
	var groove := Color(0.10, 0.11, 0.12)
	var lug_hi := Color(0.29, 0.31, 0.34)
	# Rubber tread lugs around circumference (u) & tire shoulders (v)
	for x in range(0, 128, 16):
		_draw_rect(img, x, 14, 10, 44, lug_hi)
		_draw_rect(img, x + 10, 14, 6, 44, groove)
		_draw_rect(img, (x + 8) % 128, 70, 10, 44, lug_hi)
		_draw_rect(img, (x + 18) % 128, 70, 6, 44, groove)
	_draw_rect(img, 0, 58, 128, 12, groove)
	_draw_rect(img, 0, 0, 128, 12, Color(0.24, 0.25, 0.27))
	_draw_rect(img, 0, 116, 128, 12, Color(0.24, 0.25, 0.27))
	return ImageTexture.create_from_image(img)


static func _tex_veh_wood_deck() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.64, 0.43, 0.21))
	var caulk := Color(0.22, 0.14, 0.07)
	var plank_shades: Array[Color] = [
		Color(0.68, 0.46, 0.23),
		Color(0.60, 0.39, 0.19),
		Color(0.73, 0.50, 0.26),
		Color(0.57, 0.37, 0.18),
	]
	for i in range(8):
		var x0: int = i * 16
		var pc: Color = plank_shades[i % plank_shades.size()]
		_draw_rect(img, x0, 0, 14, 128, pc)
		_draw_rect(img, x0 + 14, 0, 2, 128, caulk)
		var butt_y: int = 32 if (i % 2 == 0) else 88
		_draw_rect(img, x0, butt_y, 14, 2, caulk)
		_draw_circle(img, float(x0 + 4), float((butt_y + 6) % 128), 1.3, Color(0.84, 0.68, 0.28))
		_draw_circle(img, float(x0 + 10), float((butt_y + 6) % 128), 1.3, Color(0.84, 0.68, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for _g in range(60):
		var gx: int = rng.randi_range(0, 124)
		var gy: int = rng.randi_range(0, 112)
		_draw_rect(img, gx, gy, 1, rng.randi_range(6, 16), Color(0.46, 0.29, 0.13))
	return ImageTexture.create_from_image(img)


static func _tex_veh_sandbag() -> ImageTexture:
	var img := _new_img(128, 128, Color(0.72, 0.62, 0.42))
	var warp := Color(0.60, 0.50, 0.32)
	var weft := Color(0.80, 0.71, 0.50)
	for y in range(0, 128, 4):
		_draw_rect(img, 0, y, 128, 1, warp)
		if y % 8 == 0:
			for x in range((y % 16) / 2, 128, 8):
				_draw_rect(img, x, y + 1, 4, 2, weft)
	for x in range(0, 128, 4):
		_draw_rect(img, x, 0, 1, 128, warp.lerp(Color(0.72, 0.62, 0.42), 0.45))
	# Bag seam & tie cord shading
	_draw_rect(img, 0, 14, 128, 4, Color(0.48, 0.39, 0.24))
	_draw_dashed_h(img, 4, 124, 12, 5, Color(0.86, 0.78, 0.58))
	_draw_rect(img, 0, 110, 128, 4, Color(0.48, 0.39, 0.24))
	return ImageTexture.create_from_image(img)
