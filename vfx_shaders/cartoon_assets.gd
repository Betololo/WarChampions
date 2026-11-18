class_name CartoonAssets
extends RefCounted

## Generates crisp hand-painted cartoon surface textures and 2D HUD sprites
## (flags, portraits, weapons, skills, widgets, health cross, bullet icon) in memory.

static var _cache: Dictionary = {}


static func get_texture(key: String) -> ImageTexture:
	if _cache.has(key):
		return _cache[key]
	var tex: ImageTexture = _generate_texture(key)
	if tex != null and not (key.begins_with("icon_") or key.begins_with("flag_") or key.begins_with("portrait_")):
		var img: Image = tex.get_image()
		if img != null and not img.has_mipmaps():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func make_standard_material(tex_key: String, tint: Color = Color.WHITE, uv_scale: Vector2 = Vector2.ONE, roughness: float = 0.85) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.albedo_texture = get_texture(tex_key)
	mat.uv1_scale = Vector3(uv_scale.x, uv_scale.y, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
		"portrait_royal_0", "portrait_royal_1", "portrait_royal_2", "portrait_royal_3":
			return _sprite_portrait(0, int(key.right(1)))
		"portrait_national_0", "portrait_national_1", "portrait_national_2", "portrait_national_3":
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
	var size: int = 256
	var img := _new_img(size, size, Color(0.27, 0.65, 0.24))
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	# Soft painterly seamless meadow washes (low contrast + radial wrap prevents micro-blocks & distance moire)
	for _i in range(42):
		var cx: float = rng.randf_range(0.0, float(size))
		var cy: float = rng.randf_range(0.0, float(size))
		var rx: float = rng.randf_range(26.0, 56.0)
		var ry: float = rng.randf_range(22.0, 48.0)
		var col: Color = Color(0.31, 0.70, 0.26) if rng.randf() > 0.45 else Color(0.22, 0.57, 0.21)
		var max_r: float = maxf(rx, ry)
		var y0: int = int(floor(cy - ry))
		var y1: int = int(ceil(cy + ry))
		var x0: int = int(floor(cx - rx))
		var x1: int = int(ceil(cx + rx))
		for py in range(y0, y1 + 1):
			var wy: int = posmod(py, size)
			var dy: float = (float(py) - cy) / maxf(1.0, ry)
			var dy2: float = dy * dy
			if dy2 >= 1.0:
				continue
			for px in range(x0, x1 + 1):
				var wx: int = posmod(px, size)
				var dx: float = (float(px) - cx) / maxf(1.0, rx)
				var d2: float = dx * dx + dy2
				if d2 >= 1.0:
					continue
				var w: float = (1.0 - d2)
				var alpha: float = w * w * 0.22
				var cur: Color = img.get_pixel(wx, wy)
				img.set_pixel(wx, wy, cur.lerp(col, alpha))
	# Delicate painted blade wisps so close grass looks organic without high-frequency grid aliasing
	for _b in range(96):
		var bx: float = rng.randf_range(0.0, float(size))
		var by: float = rng.randf_range(0.0, float(size))
		var b_len: float = rng.randf_range(6.0, 12.0)
		var tilt: float = rng.randf_range(-0.35, 0.35)
		var b_col: Color = Color(0.33, 0.73, 0.27) if rng.randf() > 0.5 else Color(0.21, 0.54, 0.19)
		var steps: int = int(b_len)
		for s in range(steps):
			var t: float = float(s) / float(maxi(1, steps))
			var sx: int = posmod(int(round(bx + tilt * float(s))), size)
			var sy: int = posmod(int(round(by - float(s))), size)
			var cur_p: Color = img.get_pixel(sx, sy)
			img.set_pixel(sx, sy, cur_p.lerp(b_col, 0.16 * (1.0 - t * 0.6)))
	img.generate_mipmaps()
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
	var img := _new_img(40, 52, Color(0, 0, 0, 0))
	var cx: float = 19.5
	var outline := Color(0.10, 0.08, 0.06, 0.96)

	# Helper closure via row profile for crisp outlined vertical BFH brass cartridge
	for y in range(4, 48):
		var half_w: float = -1.0
		var is_tip: bool = false
		var is_groove: bool = false
		var is_rim: bool = false
		if y >= 6 and y <= 17:
			# Pointed copper-jacketed ogive bullet tip (Y=6..17)
			var t: float = float(y - 6) / 12.0
			half_w = 1.1 + 4.3 * pow(t, 0.62)
			is_tip = true
		elif y >= 18 and y <= 21:
			# Shoulder taper (Y=18..21)
			var t_sh: float = float(y - 18) / 4.0
			half_w = lerpf(5.4, 7.5, t_sh)
		elif y >= 22 and y <= 41:
			# Cylindrical brass casing (Y=22..41)
			half_w = 7.5
		elif y == 42:
			# Extractor groove (Y=42)
			half_w = 6.2
			is_groove = true
		elif y >= 43 and y <= 45:
			# Extractor rim (Y=43..45)
			half_w = 8.2
			is_rim = true

		# Outline cap rows (y=4..5 above tip, y=46..47 below rim)
		var outer_hw: float = half_w + 1.8 if half_w > 0.0 else (2.4 if y == 5 else (1.5 if y == 4 else 9.2))
		var x_min: int = maxi(0, int(floorf(cx - outer_hw)))
		var x_max: int = mini(39, int(ceilf(cx + outer_hw)))
		for x in range(x_min, x_max + 1):
			var dx: float = absf(float(x) - cx)
			if half_w < 0.0:
				if dx <= outer_hw:
					img.set_pixel(x, y, outline)
				continue
			if dx > half_w and dx <= outer_hw:
				img.set_pixel(x, y, outline)
			elif dx <= half_w:
				# Normalized horizontal coordinate across cartridge (-1 = left, +1 = right)
				var u: float = (float(x) - cx) / maxf(0.5, half_w)
				var col: Color
				if is_tip:
					var base_cu := Color(0.86, 0.44, 0.16)
					var hi_cu := Color(1.0, 0.80, 0.48)
					var sh_cu := Color(0.56, 0.24, 0.08)
					if u < -0.15 and u > -0.62:
						col = hi_cu
					elif u > 0.35:
						col = base_cu.lerp(sh_cu, clampf((u - 0.35) / 0.65, 0.0, 1.0))
					else:
						col = base_cu
				elif is_groove:
					col = Color(0.48, 0.31, 0.08)
				elif is_rim:
					var base_rim := Color(0.92, 0.72, 0.22)
					col = Color(1.0, 0.92, 0.56) if (u < -0.15 and u > -0.60 and y == 43) else (Color(0.62, 0.42, 0.10) if (u > 0.35 or y == 45) else base_rim)
				else:
					var base_br := Color(0.95, 0.73, 0.18)
					var hi_br := Color(1.0, 0.94, 0.58)
					var sh_br := Color(0.66, 0.44, 0.10)
					if u >= -0.60 and u <= -0.22:
						col = hi_br
					elif u > 0.32:
						col = base_br.lerp(sh_br, clampf((u - 0.32) / 0.68, 0.0, 1.0))
					elif u < -0.75:
						col = base_br.lerp(sh_br, 0.45)
					else:
						col = base_br
					if y == 18 or y == 21:
						col = col.darkened(0.10)
				img.set_pixel(x, y, col)
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
	# Eyes / Sunglasses / Blast Goggles
	if class_id == 3:
		_draw_rect(img, 21, 46, 30, 8, jacket.lightened(0.12)) # Heavy blast collar
		_draw_rect(img, 25, 29, 10, 7, Color(0.16, 0.16, 0.18))
		_draw_rect(img, 37, 29, 10, 7, Color(0.16, 0.16, 0.18))
		_draw_rect(img, 27, 30, 6, 5, Color(0.98, 0.56, 0.14))
		_draw_rect(img, 39, 30, 6, 5, Color(0.98, 0.56, 0.14))
		_draw_rect(img, 28, 41, 16, 4, Color(0.24, 0.15, 0.10)) # Heavy mustache
	elif class_id == 1 or class_id == 2:
		_draw_rect(img, 26, 31, 9, 5, Color(0.1, 0.1, 0.12))
		_draw_rect(img, 37, 31, 9, 5, Color(0.1, 0.1, 0.12))
	else:
		_draw_rect(img, 28, 32, 4, 4, Color(0.12, 0.12, 0.12))
		_draw_rect(img, 40, 32, 4, 4, Color(0.12, 0.12, 0.12))
		_draw_rect(img, 29, 41, 14, 4, Color(0.28, 0.18, 0.12)) # Mustache
	# Hat / Beret / Visor Helmet
	var hat_col := Color(0.75, 0.16, 0.16) if class_id == 1 else (Color(0.12, 0.12, 0.14) if class_id == 2 else (Color(0.32, 0.36, 0.28) if (class_id == 3 and team == 0) else (Color(0.22, 0.24, 0.28) if class_id == 3 else jacket.darkened(0.25))))
	_draw_rect(img, 20, 14, 32, 10, hat_col)
	if class_id == 2:
		_draw_rect(img, 12, 21, 48, 4, hat_col)
	elif class_id == 3:
		_draw_rect(img, 18, 21, 36, 5, Color(0.22, 0.24, 0.28))
		_draw_rect(img, 24, 21, 24, 2, Color(0.92, 0.52, 0.14))
	_draw_ring(img, 36, 36, 34.0, 30.0, Color(0.92, 0.92, 0.95))
	return ImageTexture.create_from_image(img)


static func _apply_cartoon_outline(src: Image, outline_col: Color, radius: int = 2) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var out := _new_img(w, h, Color(0, 0, 0, 0))
	var r2: int = radius * radius

	for y in range(h):
		for x in range(w):
			if src.get_pixel(x, y).a > 0.05:
				for dy in range(-radius, radius + 1):
					var ny: int = y + dy
					if ny < 0 or ny >= h:
						continue
					for dx in range(-radius, radius + 1):
						var nx: int = x + dx
						if nx < 0 or nx >= w:
							continue
						if dx * dx + dy * dy <= r2:
							if out.get_pixel(nx, ny).a < 0.05:
								out.set_pixel(nx, ny, outline_col)

	for y in range(h):
		for x in range(w):
			var c: Color = src.get_pixel(x, y)
			if c.a > 0.05:
				out.set_pixel(x, y, c)

	return out


static func _sprite_weapon(kind_str: String) -> ImageTexture:
	var parts: PackedStringArray = kind_str.split("_")
	var base_kind: String = parts[0] if parts.size() >= 1 else kind_str
	var arch: int = clampi(int(parts[1]), 0, 2) if parts.size() >= 2 else 0

	var img := _new_img(96, 64, Color(0, 0, 0, 0))
	var steel_hi := Color(0.85, 0.90, 0.98)
	var steel_mid := Color(0.55, 0.60, 0.68)
	var steel_dark := Color(0.24, 0.28, 0.35)
	var walnut_hi := Color(0.76, 0.48, 0.26)
	var walnut_mid := Color(0.52, 0.30, 0.15)
	var walnut_dark := Color(0.32, 0.18, 0.08)
	var brass_hi := Color(0.96, 0.84, 0.36)
	var brass_mid := Color(0.78, 0.60, 0.20)
	var copper_hi := Color(0.86, 0.48, 0.28)
	var olive_hi := Color(0.50, 0.68, 0.35)
	var olive_dark := Color(0.28, 0.44, 0.20)
	var red_hi := Color(0.94, 0.28, 0.24)
	var red_dark := Color(0.68, 0.14, 0.12)
	var glass_cyan := Color(0.55, 0.85, 0.98)
	var white := Color(0.98, 0.98, 0.98)

	match base_kind:
		"0": # SMG (arch 0=Classic Wood, 1=Compact Wire+Stick Mag, 2=Long Carbine+Reflex+Drum)
			if arch == 1:
				_draw_rect(img, 10, 26, 18, 3, steel_mid)
				_draw_rect(img, 8, 26, 4, 15, steel_dark)
				_draw_rect(img, 28, 36, 7, 13, steel_dark)
				_draw_rect(img, 28, 22, 28, 6, copper_hi)
				_draw_rect(img, 28, 28, 28, 7, steel_dark)
				_draw_rect(img, 56, 25, 22, 6, steel_dark)
				_draw_rect(img, 42, 35, 7, 22, steel_mid)
				_draw_rect(img, 42, 43, 7, 4, brass_hi)
			elif arch == 2:
				_draw_rect(img, 6, 27, 22, 6, walnut_hi)
				_draw_rect(img, 6, 33, 22, 8, walnut_dark)
				_draw_rect(img, 28, 37, 7, 13, walnut_mid)
				_draw_rect(img, 28, 23, 34, 6, steel_hi)
				_draw_rect(img, 28, 29, 34, 7, steel_dark)
				_draw_rect(img, 36, 17, 12, 5, brass_hi)
				_draw_rect(img, 46, 18, 3, 3, glass_cyan)
				_draw_rect(img, 62, 26, 28, 4, steel_hi)
				_draw_rect(img, 62, 34, 14, 6, walnut_hi)
				_draw_circle(img, 45, 45, 9.0, brass_mid)
				_draw_circle(img, 45, 45, 6.0, brass_hi)
			else:
				_draw_rect(img, 8, 28, 22, 5, walnut_hi)
				_draw_rect(img, 8, 33, 22, 7, walnut_dark)
				_draw_rect(img, 6, 26, 5, 16, steel_dark)
				_draw_rect(img, 28, 38, 7, 12, walnut_mid)
				_draw_rect(img, 30, 42, 5, 8, walnut_dark)
				_draw_rect(img, 28, 24, 30, 6, steel_hi)
				_draw_rect(img, 28, 30, 30, 8, steel_dark)
				_draw_rect(img, 38, 20, 6, 4, steel_mid)
				_draw_rect(img, 58, 27, 26, 3, steel_hi)
				_draw_rect(img, 58, 30, 26, 4, steel_dark)
				_draw_rect(img, 80, 22, 3, 5, steel_dark)
				_draw_line(img, Vector2(44, 38), Vector2(40, 56), 7.0, steel_dark)
				_draw_line(img, Vector2(44, 38), Vector2(40, 56), 4.0, steel_mid)

		"1": # Heavy MG (arch 0=Drum, 1=Copper Box-Mag Assault, 2=Long Bipod Heavy)
			if arch == 1:
				_draw_rect(img, 10, 25, 16, 4, steel_hi)
				_draw_rect(img, 8, 25, 4, 15, steel_dark)
				_draw_rect(img, 26, 37, 7, 13, steel_dark)
				_draw_rect(img, 26, 20, 34, 8, copper_hi)
				_draw_rect(img, 26, 28, 34, 8, steel_dark)
				_draw_rect(img, 60, 24, 24, 6, steel_hi)
				_draw_rect(img, 60, 30, 24, 4, steel_dark)
				_draw_rect(img, 36, 36, 20, 16, brass_hi)
				_draw_rect(img, 38, 39, 16, 10, brass_mid)
			elif arch == 2:
				_draw_rect(img, 5, 26, 20, 7, walnut_dark)
				_draw_rect(img, 5, 33, 20, 8, walnut_mid)
				_draw_rect(img, 25, 38, 7, 12, walnut_mid)
				_draw_rect(img, 24, 21, 34, 8, steel_dark)
				_draw_rect(img, 24, 29, 34, 8, steel_mid)
				_draw_rect(img, 58, 24, 30, 5, steel_hi)
				_draw_rect(img, 84, 21, 8, 12, brass_hi)
				_draw_circle(img, 42, 44, 13.0, steel_dark)
				_draw_ring(img, 42, 44, 13.0, 10.0, brass_hi)
				_draw_line(img, Vector2(72, 30), Vector2(64, 52), 4.0, steel_mid)
				_draw_line(img, Vector2(74, 30), Vector2(82, 52), 4.0, steel_dark)
			else:
				_draw_rect(img, 6, 26, 18, 6, walnut_hi)
				_draw_rect(img, 6, 32, 18, 8, walnut_dark)
				_draw_rect(img, 24, 38, 7, 12, walnut_mid)
				_draw_rect(img, 24, 22, 34, 7, steel_hi)
				_draw_rect(img, 24, 29, 34, 9, steel_dark)
				_draw_rect(img, 58, 22, 26, 6, steel_mid)
				_draw_rect(img, 58, 28, 26, 8, steel_dark)
				_draw_rect(img, 84, 20, 6, 18, steel_hi)
				_draw_rect(img, 86, 23, 4, 12, steel_dark)
				_draw_circle(img, 42, 44, 13.0, olive_dark)
				_draw_circle(img, 42, 44, 10.0, olive_hi)
				_draw_ring(img, 42, 44, 13.0, 11.0, brass_hi)
				_draw_rect(img, 36, 26, 12, 6, brass_hi)
				_draw_rect(img, 36, 14, 16, 4, walnut_hi)
				_draw_rect(img, 36, 18, 4, 4, steel_dark)
				_draw_rect(img, 48, 18, 4, 4, steel_dark)

		"2": # Shotgun (arch 0=Pump, 1=Sawed-Off Shorty Double Barrel, 2=Over-Under Long Marksman)
			if arch == 1:
				_draw_rect(img, 14, 32, 16, 8, walnut_hi)
				_draw_rect(img, 12, 38, 12, 12, walnut_dark)
				_draw_rect(img, 28, 25, 16, 12, brass_hi)
				_draw_rect(img, 44, 23, 30, 5, steel_hi)
				_draw_rect(img, 44, 29, 30, 5, steel_dark)
				_draw_rect(img, 48, 34, 18, 7, walnut_hi)
			elif arch == 2:
				_draw_rect(img, 5, 28, 25, 6, walnut_dark)
				_draw_rect(img, 5, 34, 25, 8, walnut_mid)
				_draw_rect(img, 30, 25, 20, 12, copper_hi)
				_draw_rect(img, 50, 23, 42, 4, steel_hi)
				_draw_rect(img, 50, 28, 40, 4, steel_dark)
				_draw_rect(img, 50, 20, 38, 3, brass_hi)
				_draw_rect(img, 52, 33, 20, 7, walnut_dark)
			else:
				_draw_rect(img, 6, 28, 26, 6, walnut_hi)
				_draw_rect(img, 6, 34, 26, 8, walnut_dark)
				_draw_rect(img, 14, 24, 12, 4, walnut_hi)
				_draw_rect(img, 30, 38, 7, 12, walnut_mid)
				_draw_rect(img, 32, 26, 24, 6, steel_hi)
				_draw_rect(img, 32, 32, 24, 7, steel_dark)
				_draw_rect(img, 42, 28, 8, 4, steel_mid)
				_draw_rect(img, 56, 26, 34, 3, steel_hi)
				_draw_rect(img, 56, 29, 34, 3, steel_dark)
				_draw_rect(img, 56, 33, 26, 4, steel_dark)
				_draw_circle(img, 88, 24, 2.0, brass_hi)
				_draw_rect(img, 58, 32, 16, 8, walnut_hi)
				for rx in [62, 66, 70]:
					_draw_rect(img, rx, 32, 2, 8, walnut_dark)

		"3": # Service Pistol (arch 0=Classic, 1=Suppressed Tactical, 2=Brass Magnum Revolver)
			if arch == 1:
				_draw_rect(img, 20, 32, 13, 18, steel_dark)
				_draw_rect(img, 22, 46, 10, 7, copper_hi)
				_draw_rect(img, 16, 20, 40, 6, steel_hi)
				_draw_rect(img, 16, 26, 40, 6, steel_dark)
				_draw_rect(img, 56, 21, 30, 10, steel_dark)
				_draw_rect(img, 56, 21, 5, 10, brass_hi)
			elif arch == 2:
				_draw_rect(img, 22, 34, 13, 18, walnut_hi)
				_draw_rect(img, 24, 36, 9, 14, walnut_dark)
				_draw_rect(img, 32, 22, 18, 12, brass_hi)
				_draw_circle(img, 44, 28, 7.0, steel_hi)
				_draw_rect(img, 50, 21, 32, 6, steel_hi)
				_draw_rect(img, 50, 27, 30, 4, steel_dark)
				_draw_rect(img, 50, 18, 30, 3, brass_hi)
			else:
				_draw_rect(img, 32, 32, 14, 18, walnut_dark)
				_draw_rect(img, 34, 34, 10, 14, walnut_hi)
				_draw_ring(img, 46, 40, 6.0, 4.0, steel_dark)
				_draw_rect(img, 45, 38, 2, 5, brass_hi)
				_draw_rect(img, 28, 20, 46, 6, steel_hi)
				_draw_rect(img, 28, 26, 46, 7, steel_dark)
				_draw_rect(img, 30, 16, 4, 4, steel_dark)
				_draw_rect(img, 68, 16, 3, 4, steel_dark)

		"4": # Sniper (arch 0=Classic Walnut, 1=Compact Recon Box-Mag, 2=Heavy Anti-Materiel)
			if arch == 1:
				_draw_rect(img, 8, 28, 22, 10, steel_dark)
				_draw_rect(img, 30, 38, 7, 11, steel_mid)
				_draw_rect(img, 30, 25, 28, 11, steel_mid)
				_draw_rect(img, 42, 36, 9, 14, steel_dark)
				_draw_rect(img, 58, 28, 26, 5, steel_hi)
				_draw_rect(img, 80, 26, 8, 9, copper_hi)
				_draw_rect(img, 36, 15, 22, 7, steel_hi)
				_draw_rect(img, 54, 16, 4, 5, glass_cyan)
			elif arch == 2:
				_draw_rect(img, 4, 28, 26, 14, walnut_dark)
				_draw_rect(img, 30, 24, 26, 12, steel_hi)
				_draw_rect(img, 56, 27, 28, 6, steel_dark)
				_draw_rect(img, 82, 23, 10, 14, brass_hi)
				_draw_rect(img, 26, 11, 46, 9, steel_dark)
				_draw_rect(img, 24, 9, 5, 13, brass_hi)
				_draw_rect(img, 69, 9, 5, 13, brass_hi)
				_draw_rect(img, 25, 11, 3, 9, glass_cyan)
				_draw_line(img, Vector2(68, 33), Vector2(60, 52), 4.0, steel_mid)
				_draw_line(img, Vector2(70, 33), Vector2(78, 52), 4.0, steel_dark)
			else:
				_draw_rect(img, 6, 30, 28, 5, walnut_hi)
				_draw_rect(img, 6, 35, 28, 8, walnut_dark)
				_draw_rect(img, 12, 26, 14, 4, walnut_hi)
				_draw_rect(img, 32, 38, 6, 11, walnut_mid)
				_draw_rect(img, 34, 26, 22, 6, steel_hi)
				_draw_rect(img, 34, 32, 22, 6, steel_dark)
				_draw_rect(img, 42, 22, 5, 4, steel_hi)
				_draw_rect(img, 56, 28, 34, 3, steel_hi)
				_draw_rect(img, 56, 31, 34, 3, steel_dark)
				_draw_rect(img, 88, 27, 4, 9, steel_hi)
				_draw_rect(img, 32, 14, 36, 4, brass_hi)
				_draw_rect(img, 32, 18, 36, 4, brass_mid)
				_draw_rect(img, 38, 22, 4, 4, steel_dark)
				_draw_rect(img, 58, 22, 4, 4, steel_dark)
				_draw_rect(img, 30, 12, 3, 12, brass_hi)
				_draw_rect(img, 67, 12, 3, 12, brass_hi)
				_draw_rect(img, 31, 14, 2, 8, glass_cyan)
				_draw_rect(img, 66, 14, 2, 8, glass_cyan)

		"5": # Commando Knife (arch 0=Dagger, 1=Curved Karambit Ring, 2=Heavy Bowie Machete)
			if arch == 1:
				_draw_ring(img, 18, 36, 8.0, 4.0, brass_hi)
				_draw_line(img, Vector2(24, 36), Vector2(44, 30), 8.0, steel_dark)
				_draw_line(img, Vector2(44, 30), Vector2(66, 24), 9.0, copper_hi)
				_draw_line(img, Vector2(64, 24), Vector2(82, 38), 7.0, steel_hi)
			elif arch == 2:
				_draw_rect(img, 10, 32, 22, 10, walnut_hi)
				_draw_rect(img, 32, 24, 6, 26, brass_hi)
				_draw_rect(img, 38, 28, 40, 14, steel_hi)
				_draw_rect(img, 38, 26, 42, 4, brass_hi)
				_draw_line(img, Vector2(78, 28), Vector2(88, 38), 6.0, steel_mid)
				_draw_line(img, Vector2(76, 42), Vector2(88, 38), 5.0, steel_hi)
			else:
				_draw_circle(img, 16, 38, 5.0, brass_hi)
				_draw_rect(img, 20, 34, 18, 8, walnut_dark)
				for hx in [24, 28, 32]:
					_draw_rect(img, hx, 34, 2, 8, walnut_hi)
				_draw_rect(img, 38, 24, 5, 28, brass_hi)
				_draw_rect(img, 36, 22, 4, 5, brass_hi)
				_draw_rect(img, 41, 49, 4, 5, brass_hi)
				_draw_line(img, Vector2(43, 38), Vector2(84, 38), 10.0, steel_mid)
				_draw_line(img, Vector2(43, 36), Vector2(80, 36), 4.0, steel_hi)
				_draw_line(img, Vector2(43, 40), Vector2(80, 40), 4.0, steel_hi)
				_draw_line(img, Vector2(45, 38), Vector2(72, 38), 2.0, steel_dark)
				_draw_line(img, Vector2(80, 36), Vector2(86, 38), 3.0, steel_hi)
				_draw_line(img, Vector2(80, 40), Vector2(86, 38), 3.0, steel_hi)

		"6": # Bazooka (arch 0=Olive, 1=Shielded Dark Red-Cone, 2=Copper Siege Optic Brass)
			if arch == 1:
				_draw_rect(img, 14, 25, 62, 12, steel_dark)
				_draw_rect(img, 58, 12, 7, 36, steel_hi)
				_draw_rect(img, 58, 12, 7, 6, red_hi)
				_draw_line(img, Vector2(76, 31), Vector2(89, 31), 10.0, red_hi)
				_draw_rect(img, 34, 37, 7, 13, steel_mid)
				_draw_rect(img, 50, 37, 7, 12, steel_mid)
			elif arch == 2:
				_draw_rect(img, 6, 24, 74, 14, copper_hi)
				_draw_rect(img, 76, 18, 14, 26, brass_hi)
				_draw_rect(img, 44, 14, 18, 9, steel_hi)
				_draw_rect(img, 59, 16, 4, 5, glass_cyan)
				_draw_rect(img, 36, 38, 7, 14, walnut_hi)
				_draw_rect(img, 56, 38, 7, 13, walnut_hi)
			else:
				_draw_rect(img, 12, 25, 72, 6, olive_hi)
				_draw_rect(img, 12, 31, 72, 8, olive_dark)
				_draw_rect(img, 6, 21, 8, 22, olive_hi)
				_draw_rect(img, 6, 26, 4, 12, steel_dark)
				_draw_rect(img, 82, 21, 6, 22, olive_hi)
				_draw_line(img, Vector2(88, 32), Vector2(93, 32), 8.0, steel_dark)
				_draw_line(img, Vector2(88, 30), Vector2(93, 32), 4.0, steel_hi)
				_draw_rect(img, 28, 23, 5, 18, steel_dark)
				_draw_rect(img, 64, 23, 5, 18, steel_dark)
				_draw_ring(img, 76, 18, 5.0, 3.0, steel_mid)
				_draw_rect(img, 40, 39, 7, 14, walnut_hi)
				_draw_rect(img, 58, 39, 7, 13, walnut_hi)

		"7": # TNT (arch 0=4-Stick Clockwork, 1=Satchel Plunger, 2=Steel-Cage 6-Stick Horned Mine)
			if arch == 1:
				_draw_rect(img, 20, 22, 54, 30, olive_dark)
				_draw_rect(img, 22, 24, 50, 12, olive_hi)
				_draw_rect(img, 30, 22, 6, 30, walnut_dark)
				_draw_rect(img, 58, 22, 6, 30, walnut_dark)
				_draw_rect(img, 44, 10, 6, 14, brass_hi)
				_draw_rect(img, 40, 8, 14, 4, red_hi)
				_draw_circle(img, 54, 18, 4.0, glass_cyan)
			elif arch == 2:
				for ry in [16, 26, 36]:
					_draw_rect(img, 14, ry, 58, 8, red_hi)
				_draw_rect(img, 22, 14, 9, 34, steel_hi)
				_draw_rect(img, 54, 14, 9, 34, steel_hi)
				_draw_circle(img, 42, 30, 10.0, brass_hi)
				_draw_circle(img, 42, 30, 7.0, white)
				_draw_line(img, Vector2(30, 14), Vector2(24, 7), 4.0, brass_hi)
				_draw_line(img, Vector2(54, 14), Vector2(60, 7), 4.0, brass_hi)
			else:
				_draw_rect(img, 14, 20, 56, 6, red_hi)
				_draw_rect(img, 14, 26, 56, 7, red_dark)
				_draw_rect(img, 14, 33, 56, 6, red_hi)
				_draw_rect(img, 14, 39, 56, 7, red_dark)
				_draw_rect(img, 24, 18, 7, 30, walnut_dark)
				_draw_rect(img, 52, 18, 7, 30, walnut_dark)
				_draw_rect(img, 25, 18, 5, 5, brass_hi)
				_draw_rect(img, 53, 18, 5, 5, brass_hi)
				_draw_circle(img, 39, 32, 11.0, brass_hi)
				_draw_circle(img, 39, 32, 9.0, white)
				_draw_line(img, Vector2(39, 32), Vector2(39, 26), 2.0, steel_dark)
				_draw_line(img, Vector2(39, 32), Vector2(44, 32), 2.0, steel_dark)
				_draw_circle(img, 39, 32, 2.0, brass_mid)
				_draw_line(img, Vector2(68, 24), Vector2(76, 18), 3.0, brass_mid)
				_draw_line(img, Vector2(76, 18), Vector2(82, 25), 3.0, brass_mid)
				_draw_line(img, Vector2(82, 25), Vector2(78, 32), 3.0, brass_mid)

		"8": # Flamethrower (arch 0=Industrial Tank+Nozzle, 1=Double-Tank Napalm, 2=Dragon Fire Cannon)
			if arch == 1:
				_draw_rect(img, 12, 34, 8, 14, steel_dark)
				_draw_rect(img, 12, 20, 38, 11, steel_hi)
				_draw_rect(img, 16, 31, 24, 15, red_hi)
				_draw_rect(img, 22, 33, 24, 15, red_dark)
				_draw_rect(img, 50, 22, 26, 6, copper_hi)
				_draw_rect(img, 74, 19, 10, 14, brass_hi)
				_draw_triangle(img, Vector2(84, 22), Vector2(93, 25), Vector2(84, 30), Color(1.0, 0.56, 0.12))
			elif arch == 2:
				_draw_rect(img, 8, 28, 16, 10, walnut_mid)
				_draw_rect(img, 20, 36, 7, 14, walnut_dark)
				_draw_rect(img, 22, 20, 32, 12, copper_hi)
				_draw_rect(img, 26, 32, 24, 14, red_hi)
				_draw_rect(img, 54, 22, 26, 8, steel_dark)
				_draw_rect(img, 76, 17, 13, 17, brass_hi)
				_draw_triangle(img, Vector2(78, 17), Vector2(86, 10), Vector2(89, 17), red_hi)
				_draw_triangle(img, Vector2(88, 20), Vector2(95, 25), Vector2(88, 31), Color(1.0, 0.78, 0.16))
			else:
				_draw_rect(img, 14, 36, 7, 13, steel_dark)
				_draw_rect(img, 12, 22, 36, 10, olive_hi)
				_draw_rect(img, 20, 32, 24, 15, red_hi)
				_draw_rect(img, 20, 38, 24, 4, red_dark)
				_draw_rect(img, 48, 24, 28, 5, steel_hi)
				_draw_rect(img, 74, 21, 9, 11, brass_hi)
				_draw_triangle(img, Vector2(83, 23), Vector2(92, 26), Vector2(83, 30), Color(1.0, 0.62, 0.14))

		"9": # Grenade Launcher (arch 0=6-Chamber Drum, 1=Twin-Rail Sticky Trapper, 2=Pirate Cannon)
			if arch == 1:
				_draw_rect(img, 8, 26, 18, 9, steel_dark)
				_draw_rect(img, 26, 36, 7, 13, steel_dark)
				_draw_rect(img, 26, 23, 24, 12, steel_mid)
				_draw_rect(img, 50, 20, 32, 5, steel_hi)
				_draw_rect(img, 50, 31, 32, 5, steel_hi)
				_draw_rect(img, 58, 25, 6, 6, glass_cyan)
				_draw_rect(img, 70, 25, 6, 6, glass_cyan)
				_draw_rect(img, 36, 35, 14, 12, brass_hi)
			elif arch == 2:
				_draw_rect(img, 8, 29, 20, 11, walnut_hi)
				_draw_rect(img, 22, 38, 7, 13, walnut_dark)
				_draw_rect(img, 24, 19, 54, 18, steel_dark)
				_draw_rect(img, 24, 21, 54, 7, steel_mid)
				_draw_rect(img, 76, 17, 10, 22, brass_hi)
				_draw_circle(img, 84, 28, 6.0, steel_hi)
			else:
				_draw_rect(img, 8, 27, 20, 9, walnut_hi)
				_draw_rect(img, 26, 37, 7, 13, walnut_dark)
				_draw_rect(img, 28, 23, 24, 11, steel_mid)
				_draw_circle(img, 42, 33, 12.0, steel_dark)
				_draw_circle(img, 42, 33, 9.0, steel_mid)
				_draw_circle(img, 42, 28, 2.5, steel_dark)
				_draw_circle(img, 37, 35, 2.5, steel_dark)
				_draw_circle(img, 47, 35, 2.5, steel_dark)
				_draw_rect(img, 52, 24, 28, 10, steel_hi)
				_draw_rect(img, 76, 22, 6, 14, brass_hi)

		"10": # Stick Grenade (Caber: wooden shaft + iron pommel + segmented explosive head)
			_draw_circle(img, 18, 48, 5.0, steel_mid)
			_draw_line(img, Vector2(20, 46), Vector2(54, 24), 7.0, walnut_hi)
			_draw_line(img, Vector2(21, 47), Vector2(55, 25), 3.0, walnut_dark)
			_draw_line(img, Vector2(52, 24), Vector2(72, 12), 18.0, olive_dark)
			_draw_line(img, Vector2(53, 23), Vector2(71, 13), 13.0, olive_hi)
			_draw_line(img, Vector2(58, 20), Vector2(66, 16), 14.0, red_hi)

		_: # Default to Pistol
			_draw_rect(img, 32, 32, 14, 18, walnut_dark)
			_draw_rect(img, 34, 34, 10, 14, walnut_hi)
			_draw_ring(img, 46, 40, 6.0, 4.0, steel_dark)
			_draw_rect(img, 45, 38, 2, 5, brass_hi)
			_draw_rect(img, 28, 20, 46, 6, steel_hi)
			_draw_rect(img, 28, 26, 46, 7, steel_dark)

	var outlined_img := _apply_cartoon_outline(img, Color(0.08, 0.08, 0.10, 1.0), 2)
	return ImageTexture.create_from_image(outlined_img)


static func _draw_triangle(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, col: Color) -> void:
	var min_x: int = maxi(0, int(floor(minf(p0.x, minf(p1.x, p2.x)))))
	var max_x: int = mini(img.get_width() - 1, int(ceil(maxf(p0.x, maxf(p1.x, p2.x)))))
	var min_y: int = maxi(0, int(floor(minf(p0.y, minf(p1.y, p2.y)))))
	var max_y: int = mini(img.get_height() - 1, int(ceil(maxf(p0.y, maxf(p1.y, p2.y)))))
	var denom: float = (p1.y - p2.y) * (p0.x - p2.x) + (p2.x - p1.x) * (p0.y - p2.y)
	if absf(denom) < 0.0001:
		return
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var px: float = float(x) + 0.5
			var py: float = float(y) + 0.5
			var a: float = ((p1.y - p2.y) * (px - p2.x) + (p2.x - p1.x) * (py - p2.y)) / denom
			var b: float = ((p2.y - p0.y) * (px - p2.x) + (p0.x - p2.x) * (py - p2.y)) / denom
			var c: float = 1.0 - a - b
			if a >= 0.0 and b >= 0.0 and c >= 0.0:
				img.set_pixel(x, y, col)


static func _draw_rounded_badge(img: Image, bg_top: Color, bg_bot: Color, rim_col: Color) -> void:
	var x0: int = 3
	var y0: int = 3
	var x1: int = 36
	var y1: int = 36
	var r: float = 6.0
	var inner_r: float = r - 1.5
	for y in range(y0, y1 + 1):
		var t: float = float(y - y0) / float(y1 - y0)
		var fill_col: Color = bg_top.lerp(bg_bot, t)
		for x in range(x0, x1 + 1):
			var cx: float = clampf(float(x), float(x0) + r, float(x1) - r)
			var cy: float = clampf(float(y), float(y0) + r, float(y1) - r)
			var dist: float = Vector2(float(x) - cx, float(y) - cy).length()
			if dist <= r + 0.25:
				var on_edge: bool = (
					x <= x0 + 1 or x >= x1 - 1 or y <= y0 + 1 or y >= y1 - 1
					or dist >= inner_r
				)
				img.set_pixel(x, y, rim_col if on_edge else fill_col)


static func _draw_mini_grenade(img: Image, cx: int, cy: int, body_col: Color, hi_col: Color, spark_col: Color) -> void:
	var ink := Color(0.10, 0.11, 0.14)
	_draw_circle(img, float(cx), float(cy), 6.5, ink)
	_draw_circle(img, float(cx), float(cy), 5.3, body_col)
	_draw_circle(img, float(cx - 2), float(cy - 2), 2.0, hi_col)
	_draw_rect(img, cx - 2, cy - 3, 4, 1, ink)
	_draw_rect(img, cx - 2, cy + 1, 4, 1, ink)
	_draw_rect(img, cx - 1, cy - 8, 3, 3, Color(0.55, 0.58, 0.62))
	_draw_line(img, Vector2(float(cx), float(cy - 8)), Vector2(float(cx + 4), float(cy - 10)), 1.6, spark_col)
	_draw_circle(img, float(cx + 4), float(cy - 10), 2.0, Color(1.0, 0.96, 0.45))


static func _sprite_skill(slot_str: String) -> ImageTexture:
	var norm_key: String = slot_str.strip_edges()
	if not norm_key.contains("_"):
		norm_key = "0_%d" % clampi(int(norm_key), 0, 5)

	var img := _new_img(40, 40, Color(0, 0, 0, 0))
	var ink := Color(0.08, 0.09, 0.12)
	var white := Color(0.97, 0.98, 1.0)

	match norm_key:
		"0_0": # Combat Medicine: Emerald badge + bold white/red cross + glowing vial droplets
			_draw_rounded_badge(img, Color(0.14, 0.64, 0.40), Color(0.06, 0.34, 0.22), Color(0.45, 0.96, 0.68))
			_draw_rect(img, 15, 8, 10, 24, ink)
			_draw_rect(img, 8, 15, 24, 10, ink)
			_draw_rect(img, 16, 9, 8, 22, white)
			_draw_rect(img, 9, 16, 22, 8, white)
			_draw_rect(img, 18, 11, 4, 18, Color(0.92, 0.20, 0.24))
			_draw_rect(img, 11, 18, 18, 4, Color(0.92, 0.20, 0.24))
			_draw_circle(img, 11.0, 10.0, 2.3, Color(0.55, 1.0, 0.85))
			_draw_circle(img, 29.0, 29.0, 2.5, Color(0.55, 1.0, 0.85))

		"0_1": # Burning Bullets: Amber-orange badge + brass bullet silhouette + bright red/yellow flame licks
			_draw_rounded_badge(img, Color(0.86, 0.42, 0.10), Color(0.48, 0.14, 0.05), Color(1.0, 0.78, 0.28))
			# Flames behind bullet
			_draw_triangle(img, Vector2(9, 24), Vector2(18, 8), Vector2(24, 24), Color(0.96, 0.22, 0.12))
			_draw_triangle(img, Vector2(16, 26), Vector2(26, 7), Vector2(31, 24), Color(1.0, 0.48, 0.10))
			_draw_triangle(img, Vector2(13, 25), Vector2(22, 12), Vector2(27, 25), Color(1.0, 0.92, 0.25))
			# Angled brass bullet foreground
			_draw_line(img, Vector2(11, 29), Vector2(24, 16), 7.5, ink)
			_draw_line(img, Vector2(11, 29), Vector2(22, 18), 5.2, Color(0.88, 0.68, 0.22))
			_draw_line(img, Vector2(18, 22), Vector2(26, 14), 4.8, Color(1.0, 0.86, 0.36))
			_draw_circle(img, 27.0, 13.0, 2.2, Color(1.0, 0.96, 0.65))

		"0_2": # Grenade Spam: Olive/gold badge + 2 overlapping pineapple grenades with yellow fuse sparks
			_draw_rounded_badge(img, Color(0.44, 0.50, 0.18), Color(0.22, 0.26, 0.08), Color(0.96, 0.84, 0.28))
			_draw_mini_grenade(img, 14, 22, Color(0.32, 0.48, 0.20), Color(0.56, 0.75, 0.34), Color(1.0, 0.75, 0.15))
			_draw_mini_grenade(img, 25, 24, Color(0.38, 0.56, 0.22), Color(0.66, 0.86, 0.40), Color(1.0, 0.82, 0.20))

		"0_3": # Blasting Strike: Cyan/gold badge + outward radiating concentric shockwave arcs + central burst star
			_draw_rounded_badge(img, Color(0.14, 0.56, 0.78), Color(0.08, 0.26, 0.48), Color(1.0, 0.86, 0.30))
			_draw_ring(img, 20.0, 20.0, 13.5, 11.2, Color(0.55, 0.95, 1.0))
			_draw_ring(img, 20.0, 20.0, 9.5, 7.6, Color(1.0, 0.88, 0.30))
			_draw_circle(img, 20.0, 20.0, 5.2, ink)
			_draw_star(img, 20.0, 20.0, 6.2, Color(1.0, 0.94, 0.42))
			_draw_circle(img, 20.0, 20.0, 2.4, white)

		"0_4": # Sixth Sense: Purple/gold badge + stylized eye/radar sweep rings + glowing pupil
			_draw_rounded_badge(img, Color(0.46, 0.20, 0.68), Color(0.22, 0.09, 0.36), Color(0.96, 0.80, 0.26))
			_draw_ring(img, 20.0, 20.0, 13.0, 11.5, Color(0.84, 0.60, 1.0))
			# Eye almond shape via two opposing triangles + center ellipse
			_draw_triangle(img, Vector2(7, 20), Vector2(20, 12), Vector2(33, 20), ink)
			_draw_triangle(img, Vector2(7, 20), Vector2(20, 28), Vector2(33, 20), ink)
			_draw_triangle(img, Vector2(9, 20), Vector2(20, 13.5), Vector2(31, 20), white)
			_draw_triangle(img, Vector2(9, 20), Vector2(20, 26.5), Vector2(31, 20), white)
			_draw_circle(img, 20.0, 20.0, 4.8, Color(0.95, 0.72, 0.16))
			_draw_circle(img, 20.0, 20.0, 2.4, ink)
			_draw_circle(img, 18.8, 18.8, 1.1, white)

		"1_0": # Hero Shield: Deep-blue badge + bright cyan kite shield silhouette + metallic inner rim
			_draw_rounded_badge(img, Color(0.10, 0.26, 0.64), Color(0.06, 0.12, 0.34), Color(0.42, 0.88, 1.0))
			_draw_rect(img, 10, 9, 20, 13, ink)
			_draw_triangle(img, Vector2(10, 22), Vector2(30, 22), Vector2(20, 32), ink)
			_draw_rect(img, 11, 10, 18, 12, Color(0.24, 0.82, 1.0))
			_draw_triangle(img, Vector2(11, 22), Vector2(29, 22), Vector2(20, 30), Color(0.24, 0.82, 1.0))
			_draw_rect(img, 13, 12, 14, 9, Color(0.65, 0.96, 1.0))
			_draw_triangle(img, Vector2(13, 21), Vector2(27, 21), Vector2(20, 27), Color(0.45, 0.90, 1.0))
			_draw_rect(img, 19, 13, 2, 12, white)

		"1_1": # Leg It: Sky/lime badge + winged sprinting boot silhouette + 3 horizontal speed lines behind heel
			_draw_rounded_badge(img, Color(0.18, 0.60, 0.74), Color(0.18, 0.56, 0.24), Color(0.72, 1.0, 0.42))
			# 3 speed lines behind heel
			_draw_line(img, Vector2(6, 14), Vector2(14, 14), 2.2, white)
			_draw_line(img, Vector2(5, 20), Vector2(13, 20), 2.2, Color(0.82, 1.0, 0.55))
			_draw_line(img, Vector2(7, 26), Vector2(14, 26), 2.2, white)
			# Sprinting boot
			_draw_rect(img, 16, 11, 8, 14, ink)
			_draw_rect(img, 16, 22, 15, 7, ink)
			_draw_rect(img, 17, 12, 6, 12, Color(0.95, 0.76, 0.22))
			_draw_rect(img, 17, 23, 13, 5, Color(0.95, 0.76, 0.22))
			# Wing on boot
			_draw_triangle(img, Vector2(14, 18), Vector2(25, 11), Vector2(23, 20), white)

		"1_2": # Explosive Keg: Dark-crimson/orange badge + red wooden/steel barrel with hazard yellow stripes & spark fuse
			_draw_rounded_badge(img, Color(0.68, 0.16, 0.14), Color(0.32, 0.08, 0.06), Color(1.0, 0.62, 0.20))
			_draw_rect(img, 11, 12, 18, 20, ink)
			_draw_rect(img, 12, 13, 16, 18, Color(0.86, 0.18, 0.16))
			_draw_rect(img, 12, 16, 16, 3, Color(0.98, 0.84, 0.18))
			_draw_rect(img, 12, 24, 16, 3, Color(0.98, 0.84, 0.18))
			_draw_rect(img, 12, 13, 16, 2, Color(0.62, 0.66, 0.72))
			_draw_rect(img, 12, 29, 16, 2, Color(0.62, 0.66, 0.72))
			_draw_line(img, Vector2(20, 12), Vector2(25, 7), 2.0, Color(0.95, 0.78, 0.32))
			_draw_circle(img, 26.0, 7.0, 2.4, Color(1.0, 0.94, 0.35))

		"1_3": # Frenzy Fire: Gold/red badge + triple ascending vertical brass cartridge streaks + red heart pulse
			_draw_rounded_badge(img, Color(0.78, 0.50, 0.10), Color(0.52, 0.14, 0.12), Color(1.0, 0.88, 0.32))
			for bx in [11, 19, 27]:
				var top_y: int = 10 if bx == 19 else 13
				_draw_rect(img, bx - 2, top_y, 5, 16, ink)
				_draw_rect(img, bx - 1, top_y + 2, 3, 13, Color(0.96, 0.80, 0.24))
				_draw_triangle(img, Vector2(bx - 2, top_y + 2), Vector2(bx + 0.5, top_y - 3), Vector2(bx + 3, top_y + 2), Color(1.0, 0.52, 0.18))
			# Red heart pulse at bottom center
			_draw_circle(img, 17.5, 27.0, 3.3, Color(0.95, 0.18, 0.24))
			_draw_circle(img, 22.5, 27.0, 3.3, Color(0.95, 0.18, 0.24))
			_draw_triangle(img, Vector2(14, 28), Vector2(26, 28), Vector2(20, 34), Color(0.95, 0.18, 0.24))

		"1_4": # I Eat Grenades: Lime/emerald badge + chomping jagged jaws biting a dark round grenade bomb
			_draw_rounded_badge(img, Color(0.32, 0.72, 0.16), Color(0.10, 0.38, 0.14), Color(0.76, 1.0, 0.35))
			# Dark round grenade bomb in center
			_draw_circle(img, 21.0, 20.0, 7.2, Color(0.16, 0.20, 0.18))
			_draw_circle(img, 19.0, 18.0, 2.2, Color(0.45, 0.52, 0.48))
			_draw_rect(img, 19, 11, 4, 3, Color(0.70, 0.74, 0.78))
			# Upper & lower jagged white chomping jaws
			_draw_rect(img, 9, 8, 22, 4, ink)
			_draw_rect(img, 9, 28, 22, 4, ink)
			for tx in [10, 16, 22, 27]:
				_draw_triangle(img, Vector2(tx, 10), Vector2(tx + 4, 10), Vector2(tx + 2, 16), white)
				_draw_triangle(img, Vector2(tx, 30), Vector2(tx + 4, 30), Vector2(tx + 2, 24), white)

		"2_0": # Stealth: Midnight-indigo badge + translucent ghost/hooded spy silhouette + stealth fade slashes
			_draw_rounded_badge(img, Color(0.14, 0.18, 0.44), Color(0.06, 0.08, 0.22), Color(0.56, 0.72, 1.0))
			_draw_circle(img, 20.0, 15.0, 6.2, Color(0.70, 0.82, 1.0, 0.85))
			_draw_triangle(img, Vector2(11, 31), Vector2(20, 15), Vector2(29, 31), Color(0.58, 0.72, 0.96, 0.75))
			_draw_circle(img, 18.0, 15.0, 1.3, Color(0.10, 0.14, 0.30))
			_draw_circle(img, 22.0, 15.0, 1.3, Color(0.10, 0.14, 0.30))
			# Diagonal stealth fade slashes
			_draw_line(img, Vector2(8, 28), Vector2(16, 11), 2.0, Color(0.35, 0.92, 1.0, 0.85))
			_draw_line(img, Vector2(24, 29), Vector2(32, 12), 2.0, Color(0.35, 0.92, 1.0, 0.85))

		"2_1": # Piercing Shot: Crimson/steel badge + sharp sniper bullet punching through 2 vertical armor plates + laser streak
			_draw_rounded_badge(img, Color(0.62, 0.12, 0.22), Color(0.22, 0.14, 0.22), Color(0.86, 0.90, 0.98))
			# Two vertical steel armor plates with pierced gap
			_draw_rect(img, 14, 9, 4, 9, Color(0.68, 0.74, 0.84))
			_draw_rect(img, 14, 22, 4, 9, Color(0.68, 0.74, 0.84))
			_draw_rect(img, 23, 9, 4, 9, Color(0.55, 0.62, 0.72))
			_draw_rect(img, 23, 22, 4, 9, Color(0.55, 0.62, 0.72))
			# Laser streak + piercing sniper round
			_draw_line(img, Vector2(6, 20), Vector2(34, 20), 2.6, Color(1.0, 0.32, 0.28))
			_draw_rect(img, 9, 17, 17, 6, ink)
			_draw_rect(img, 10, 18, 15, 4, Color(0.98, 0.84, 0.28))
			_draw_triangle(img, Vector2(25, 17), Vector2(34, 20), Vector2(25, 23), white)

		"2_2": # Poisoned Blade: Toxic-green badge + gleaming steel dagger diagonally angled with dripping neon-green venom drops
			_draw_rounded_badge(img, Color(0.14, 0.44, 0.16), Color(0.06, 0.22, 0.08), Color(0.42, 1.0, 0.35))
			# Dagger blade & hilt diagonally
			_draw_line(img, Vector2(9, 30), Vector2(14, 25), 4.5, Color(0.36, 0.22, 0.12))
			_draw_line(img, Vector2(12, 22), Vector2(18, 28), 3.2, Color(0.88, 0.76, 0.28))
			_draw_line(img, Vector2(15, 24), Vector2(30, 9), 5.6, ink)
			_draw_line(img, Vector2(16, 23), Vector2(29, 10), 3.6, Color(0.86, 0.92, 0.98))
			_draw_line(img, Vector2(20, 19), Vector2(29, 10), 2.2, Color(0.42, 1.0, 0.32))
			# Dripping neon venom drops
			_draw_circle(img, 22.0, 26.0, 2.3, Color(0.38, 1.0, 0.28))
			_draw_circle(img, 28.0, 21.0, 2.5, Color(0.38, 1.0, 0.28))
			_draw_circle(img, 28.0, 30.0, 2.0, Color(0.65, 1.0, 0.45))

		"2_3": # Troop Trap: Slate/amber badge + spiked round landmine base with glowing red-orange trip prongs & warning glow
			_draw_rounded_badge(img, Color(0.28, 0.32, 0.38), Color(0.26, 0.18, 0.08), Color(1.0, 0.74, 0.22))
			# Warning glow
			_draw_circle(img, 20.0, 22.0, 11.5, Color(1.0, 0.42, 0.10, 0.45))
			# Prongs
			_draw_line(img, Vector2(20, 18), Vector2(12, 11), 2.4, ink)
			_draw_line(img, Vector2(20, 18), Vector2(20, 9), 2.4, ink)
			_draw_line(img, Vector2(20, 18), Vector2(28, 11), 2.4, ink)
			_draw_circle(img, 12.0, 11.0, 2.0, Color(1.0, 0.30, 0.15))
			_draw_circle(img, 20.0, 9.0, 2.2, Color(1.0, 0.42, 0.15))
			_draw_circle(img, 28.0, 11.0, 2.0, Color(1.0, 0.30, 0.15))
			# Landmine body
			_draw_circle(img, 20.0, 24.0, 8.5, ink)
			_draw_circle(img, 20.0, 24.0, 7.0, Color(0.42, 0.46, 0.38))
			_draw_circle(img, 20.0, 24.0, 3.2, Color(1.0, 0.22, 0.16))

		"2_4": # Elixir: Teal/gold badge + rounded potion flask with glowing yellow-lime lightning liquid & cork
			_draw_rounded_badge(img, Color(0.10, 0.52, 0.56), Color(0.08, 0.26, 0.34), Color(1.0, 0.84, 0.28))
			# Cork + neck
			_draw_rect(img, 17, 7, 6, 4, Color(0.76, 0.52, 0.26))
			_draw_rect(img, 16, 11, 8, 5, ink)
			_draw_rect(img, 17, 11, 6, 5, Color(0.78, 0.94, 0.98))
			# Flask bulb
			_draw_circle(img, 20.0, 24.0, 9.2, ink)
			_draw_circle(img, 20.0, 24.0, 7.6, Color(0.68, 0.98, 0.24))
			_draw_circle(img, 17.5, 21.5, 2.4, Color(1.0, 1.0, 0.72))
			# Lightning zig-zag inside flask
			_draw_line(img, Vector2(21, 18), Vector2(17, 24), 2.2, Color(1.0, 0.92, 0.22))
			_draw_line(img, Vector2(17, 24), Vector2(23, 24), 2.2, Color(1.0, 0.92, 0.22))
			_draw_line(img, Vector2(23, 24), Vector2(19, 30), 2.2, Color(1.0, 0.92, 0.22))

		"2_5": # Mark Target: Crimson-black badge + sharp sniper crosshair reticle centered on a bright red target dot
			_draw_rounded_badge(img, Color(0.48, 0.08, 0.12), Color(0.14, 0.06, 0.08), Color(1.0, 0.34, 0.30))
			_draw_ring(img, 20.0, 20.0, 12.2, 10.2, white)
			_draw_line(img, Vector2(20, 6), Vector2(20, 14), 2.2, white)
			_draw_line(img, Vector2(20, 26), Vector2(20, 34), 2.2, white)
			_draw_line(img, Vector2(6, 20), Vector2(14, 20), 2.2, white)
			_draw_line(img, Vector2(26, 20), Vector2(34, 20), 2.2, white)
			_draw_triangle(img, Vector2(15, 16), Vector2(25, 16), Vector2(20, 25), Color(1.0, 0.18, 0.18))
			_draw_circle(img, 20.0, 20.0, 2.5, Color(1.0, 0.88, 0.30))

		"3_0": # Escudo Balístico (Em Mãos): heavy tactical shield + stick grenade melee combo
			_draw_rounded_badge(img, Color(0.24, 0.34, 0.48), Color(0.10, 0.14, 0.22), Color(0.68, 0.82, 0.96))
			_draw_rect(img, 8, 9, 16, 22, ink)
			_draw_rect(img, 9, 10, 14, 20, Color(0.42, 0.48, 0.56))
			_draw_rect(img, 11, 13, 10, 4, Color(0.45, 0.88, 1.0))
			_draw_rect(img, 9, 20, 14, 3, Color(0.90, 0.62, 0.18))
			_draw_circle(img, 11.5, 27.5, 1.3, white)
			_draw_circle(img, 20.5, 27.5, 1.3, white)
			# Stick grenade angled on right side
			_draw_line(img, Vector2(26, 29), Vector2(31, 16), 3.6, ink)
			_draw_line(img, Vector2(26, 29), Vector2(30, 18), 2.0, Color(0.76, 0.52, 0.24))
			_draw_rect(img, 27, 9, 7, 8, ink)
			_draw_rect(img, 28, 10, 5, 6, Color(0.36, 0.48, 0.28))

		"3_1": # Haste (Adrenalina): orange-gold badge + sharp lightning bolt & speed chevrons
			_draw_rounded_badge(img, Color(0.88, 0.44, 0.10), Color(0.48, 0.16, 0.06), Color(1.0, 0.86, 0.28))
			_draw_line(img, Vector2(7, 15), Vector2(14, 15), 2.2, white)
			_draw_line(img, Vector2(6, 21), Vector2(13, 21), 2.2, white)
			_draw_line(img, Vector2(7, 27), Vector2(14, 27), 2.2, white)
			_draw_triangle(img, Vector2(21, 7), Vector2(15, 21), Vector2(24, 21), ink)
			_draw_triangle(img, Vector2(17, 19), Vector2(27, 19), Vector2(19, 33), ink)
			_draw_triangle(img, Vector2(21, 9), Vector2(16, 20), Vector2(23, 20), Color(1.0, 0.94, 0.32))
			_draw_triangle(img, Vector2(18, 20), Vector2(25, 20), Vector2(19, 31), Color(1.0, 0.88, 0.22))

		"3_2": # Corda de TNTs (TNT Rope): crimson/amber badge + bundled red dynamite sticks tied with rope + fuse spark
			_draw_rounded_badge(img, Color(0.66, 0.16, 0.14), Color(0.28, 0.08, 0.08), Color(1.0, 0.72, 0.24))
			for dx in [12, 18, 24]:
				_draw_rect(img, dx - 1, 13, 6, 18, ink)
				_draw_rect(img, dx, 14, 4, 16, Color(0.92, 0.20, 0.16))
			_draw_rect(img, 10, 19, 20, 3, Color(0.76, 0.56, 0.28))
			_draw_rect(img, 10, 24, 20, 3, Color(0.76, 0.56, 0.28))
			_draw_line(img, Vector2(20, 13), Vector2(26, 8), 2.0, Color(0.90, 0.75, 0.36))
			_draw_circle(img, 27.0, 8.0, 2.6, Color(1.0, 0.95, 0.38))

		"3_3": # Kit de 5 Coletes (+70 Escudo): supply crate + tactical cyan/steel ballistic armor vest
			_draw_rounded_badge(img, Color(0.14, 0.42, 0.62), Color(0.14, 0.22, 0.18), Color(0.45, 0.92, 1.0))
			# Crate base
			_draw_rect(img, 8, 23, 24, 9, ink)
			_draw_rect(img, 9, 24, 22, 7, Color(0.32, 0.38, 0.28))
			# Tactical armor vest on top
			_draw_rect(img, 12, 10, 16, 15, ink)
			_draw_rect(img, 13, 11, 14, 13, Color(0.28, 0.78, 0.96))
			_draw_rect(img, 17, 10, 6, 4, Color(0.12, 0.22, 0.32))
			_draw_rect(img, 18, 15, 4, 7, white)
			_draw_rect(img, 16, 17, 8, 3, white)

		"3_4": # Quebra-Tanques (Vehicle Buster): olive/gold badge + tank silhouette + 3x explosive burst
			_draw_rounded_badge(img, Color(0.40, 0.44, 0.16), Color(0.24, 0.14, 0.08), Color(1.0, 0.82, 0.24))
			_draw_rect(img, 8, 22, 22, 8, ink)
			_draw_rect(img, 9, 23, 20, 6, Color(0.36, 0.46, 0.26))
			_draw_rect(img, 13, 17, 11, 6, Color(0.44, 0.54, 0.30))
			_draw_rect(img, 24, 18, 9, 3, Color(0.65, 0.70, 0.75))
			_draw_star(img, 20.0, 16.0, 7.0, Color(1.0, 0.42, 0.12))
			_draw_circle(img, 20.0, 16.0, 2.8, Color(1.0, 0.94, 0.38))

		_: # Fallback outlined badge
			_draw_rounded_badge(img, Color(0.24, 0.36, 0.56), Color(0.12, 0.18, 0.30), Color(0.75, 0.85, 0.98))
			_draw_star(img, 20.0, 20.0, 8.0, white)

	var outlined: Image = _apply_cartoon_outline(img, Color(0.06, 0.07, 0.10, 1.0), 2)
	return ImageTexture.create_from_image(outlined)


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
	elif idx == 2: # Fireproof
		_draw_rect(img, 11, 10, 18, 22, Color(0.25, 0.78, 0.96))
		_draw_circle(img, 20, 21, 5.5, Color(1.0, 0.56, 0.14))
	else: # Antidote
		_draw_rect(img, 13, 12, 14, 22, Color(0.24, 0.88, 0.42))
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
