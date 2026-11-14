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
		"terracotta":
			return _tex_roof_tiles(Color(0.84, 0.34, 0.20), Color(0.66, 0.24, 0.14))
		"foliage":
			return _tex_foliage()
		"bark":
			return _tex_bark()
		"sand":
			return _tex_stucco(Color(0.94, 0.85, 0.58), Color(0.86, 0.75, 0.48))
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
