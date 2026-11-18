class_name HUDController
extends CanvasLayer

## Battlefield Heroes-inspired Clean HUD (matching Screenshot 1):
## - Top-Left: Circular hero portrait + XP ring + Level badge
## - Top-Center: Royal vs National ticket counts, Crown & Skull flag sprites, 1x/2x/3x multipliers, red damage arc
## - Bottom-Left: Giant '+' health sprite + bold HP (+ Shield)
## - Bottom-Right: Bold magazine ammo + golden bullet sprite + infinite reserve badge
## - Bottom-Center: Transparent 1..0 hotbar with weapon/skill/widget sprites, cooldowns, and '+' skill upgrades
## - Mid-Right: Combat Mastery / Score XP progress
## - Center: Crosshair, hitmarker, Sniper scope overlay, [ESPAÇO] Parachute prompt, [E] Vehicle prompt, Killfeed & Defeat timer.

signal upgrade_skill_requested(slot_idx: int)
signal toggle_menu_requested()


class PortraitGaugeControl extends Control:
	var xp_ratio: float = 0.0
	var team_id: int = 0

	func _draw() -> void:
		var center := Vector2(48.0, 48.0)
		var bg_col := Color(0.10, 0.14, 0.20, 0.85)
		draw_circle(center, 44.0, bg_col)
		# Outer track ring
		draw_arc(center, 41.0, deg_to_rad(130.0), deg_to_rad(410.0), 36, Color(0.22, 0.24, 0.28, 0.9), 9.0, true)
		# Green XP progress arc
		var clamped: float = clampf(xp_ratio, 0.0, 1.0)
		if clamped > 0.005:
			var end_deg: float = 130.0 + 280.0 * clamped
			draw_arc(center, 41.0, deg_to_rad(130.0), deg_to_rad(end_deg), 36, Color(0.45, 0.88, 0.22, 0.98), 7.0, true)
		var rim_col := Color(0.28, 0.62, 1.0, 0.95) if team_id == 0 else Color(0.95, 0.24, 0.22, 0.95)
		draw_arc(center, 35.0, 0.0, TAU, 36, rim_col, 3.0, true)


class DamageFlashArc extends Control:
	var flash_alpha: float = 0.0

	func _draw() -> void:
		if flash_alpha <= 0.01:
			return
		var c := Vector2(size.x * 0.5, 0.0)
		var col := Color(0.96, 0.14, 0.12, flash_alpha)
		draw_arc(c, 84.0, deg_to_rad(25.0), deg_to_rad(155.0), 28, col, 14.0, true)
		draw_arc(c, 102.0, deg_to_rad(35.0), deg_to_rad(145.0), 20, Color(1.0, 0.35, 0.25, flash_alpha * 0.7), 6.0, true)


class SniperScopeOverlay extends Control:
	func _draw() -> void:
		var s: Vector2 = size
		if s.x <= 1.0 or s.y <= 1.0:
			return
		var center: Vector2 = s * 0.5
		var radius: float = minf(s.x, s.y) * 0.43
		var outer_r: float = s.length() + 32.0
		var mask_col := Color(0.02, 0.02, 0.03, 0.98)

		# Seamless circular cutout mask across any viewport resolution
		var segs: int = 96
		for i in range(segs):
			var a0: float = (float(i) / float(segs)) * TAU
			var a1: float = (float(i + 1) / float(segs)) * TAU
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			draw_colored_polygon(
				PackedVector2Array([center + d0 * radius, center + d1 * radius, center + d1 * outer_r, center + d0 * outer_r]),
				mask_col
			)

		# Inner optic vignette shadow + blue-cyan glass glint
		draw_arc(center, radius * 0.94, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.42), radius * 0.12, true)
		draw_arc(center, radius * 0.89, deg_to_rad(205.0), deg_to_rad(255.0), 28, Color(0.62, 0.86, 1.0, 0.18), 5.0, true)

		# Metallic brass & gunmetal optic bezel ring
		draw_arc(center, radius + 7.0, 0.0, TAU, 96, Color(0.10, 0.10, 0.12, 1.0), 16.0, true)
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.56, 0.48, 0.28, 0.92), 3.0, true)

		# German #4 / Mil-Dot Sniper Reticle
		var post_col := Color(0.03, 0.03, 0.04, 0.96)
		var wire_col := Color(0.05, 0.05, 0.06, 0.92)
		var gap: float = 16.0

		# Thick outer posts (left, right, bottom)
		draw_line(Vector2(center.x - radius, center.y), Vector2(center.x - radius * 0.30, center.y), post_col, 6.0)
		draw_line(Vector2(center.x + radius * 0.30, center.y), Vector2(center.x + radius, center.y), post_col, 6.0)
		draw_line(Vector2(center.x, center.y + radius * 0.28), Vector2(center.x, center.y + radius), post_col, 6.0)

		# Crisp inner crosshairs leaving micro gap around center dot
		draw_line(Vector2(center.x - radius * 0.34, center.y), Vector2(center.x - gap, center.y), wire_col, 1.6)
		draw_line(Vector2(center.x + gap, center.y), Vector2(center.x + radius * 0.34, center.y), wire_col, 1.6)
		draw_line(Vector2(center.x, center.y - radius * 0.78), Vector2(center.x, center.y - gap), wire_col, 1.6)
		draw_line(Vector2(center.x, center.y + gap), Vector2(center.x, center.y + radius * 0.34), wire_col, 1.6)

		# Mil-dot range & windage notches
		var step: float = radius * 0.085
		for k in range(1, 4):
			var off: float = float(k) * step + gap * 0.7
			draw_line(Vector2(center.x - off, center.y - 4.0), Vector2(center.x - off, center.y + 4.0), wire_col, 1.8)
			draw_line(Vector2(center.x + off, center.y - 4.0), Vector2(center.x + off, center.y + 4.0), wire_col, 1.8)
			draw_line(Vector2(center.x - 4.0, center.y + off), Vector2(center.x + 4.0, center.y + off), wire_col, 1.8)
			draw_line(Vector2(center.x - 3.0, center.y - off), Vector2(center.x + 3.0, center.y - off), wire_col, 1.6)

		# Razor pinpoint glowing center reticle dot
		draw_circle(center, 3.2, Color(1.0, 0.30, 0.14, 0.98))
		draw_circle(center, 1.4, Color(1.0, 0.92, 0.55, 1.0))


class _TacticalMinimapControl extends Control:
	const WORLD_MIN_X: float = -780.0
	const WORLD_MAX_X: float = 780.0
	const WORLD_MIN_Z: float = -540.0
	const WORLD_MAX_Z: float = 540.0
	const MAP_PAD: float = 4.0

	var hud_owner: HUDController = null
	var mortar_active: bool = false
	var hover_local_pos: Vector2 = Vector2(-1.0, -1.0)

	func _get_effective_size() -> Vector2:
		return Vector2(
			maxf(size.x, custom_minimum_size.x),
			maxf(size.y, custom_minimum_size.y)
		)

	func _get_projection_params() -> Dictionary:
		var s: Vector2 = _get_effective_size()
		var usable_w: float = maxf(1.0, s.x - MAP_PAD * 2.0)
		var usable_h: float = maxf(1.0, s.y - MAP_PAD * 2.0)
		var world_w: float = WORLD_MAX_X - WORLD_MIN_X
		var world_h: float = WORLD_MAX_Z - WORLD_MIN_Z
		var px_per_m: float = minf(usable_w / world_w, usable_h / world_h)
		var draw_w: float = world_w * px_per_m
		var draw_h: float = world_h * px_per_m
		return {
			"origin_x": (s.x - draw_w) * 0.5,
			"origin_y": (s.y - draw_h) * 0.5,
			"px_per_m": px_per_m,
		}

	func world_to_minimap(world_pos: Vector3) -> Vector2:
		var p: Dictionary = _get_projection_params()
		var ox: float = float(p["origin_x"])
		var oy: float = float(p["origin_y"])
		var sc: float = float(p["px_per_m"])
		return Vector2(
			ox + (world_pos.x - WORLD_MIN_X) * sc,
			oy + (world_pos.z - WORLD_MIN_Z) * sc
		)

	func minimap_to_world(local_pos: Vector2) -> Vector3:
		var p: Dictionary = _get_projection_params()
		var ox: float = float(p["origin_x"])
		var oy: float = float(p["origin_y"])
		var sc: float = maxf(0.0001, float(p["px_per_m"]))
		var wx: float = WORLD_MIN_X + (local_pos.x - ox) / sc
		var wz: float = WORLD_MIN_Z + (local_pos.y - oy) / sc
		return Vector3(wx, 0.0, wz)

	func _gui_input(event: InputEvent) -> void:
		if not mortar_active or hud_owner == null:
			return
		if event is InputEventMouseMotion:
			hover_local_pos = (event as InputEventMouseMotion).position
			queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				hud_owner._on_minimap_mortar_clicked(mb.position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				hud_owner.set_mortar_targeting_mode(false)
				accept_event()

	func _build_rounded_land_poly(half_w_core: float, half_h_core: float, corner_r: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		var corners: Array[Dictionary] = [
			{"cx": half_w_core, "cz": -half_h_core, "a0": -PI * 0.5, "a1": 0.0},
			{"cx": half_w_core, "cz": half_h_core, "a0": 0.0, "a1": PI * 0.5},
			{"cx": -half_w_core, "cz": half_h_core, "a0": PI * 0.5, "a1": PI},
			{"cx": -half_w_core, "cz": -half_h_core, "a0": PI, "a1": PI * 1.5},
		]
		var steps: int = 4
		for c in corners:
			var cx: float = float(c["cx"])
			var cz: float = float(c["cz"])
			var a0: float = float(c["a0"])
			var a1: float = float(c["a1"])
			for k in range(steps + 1):
				var t: float = float(k) / float(steps)
				var ang: float = lerpf(a0, a1, t)
				var wx: float = cx + cos(ang) * corner_r
				var wz: float = cz + sin(ang) * corner_r
				pts.append(world_to_minimap(Vector3(wx, 0.0, wz)))
		return pts

	func _draw_world_rect(cx: float, cz: float, w_x: float, w_z: float, col: Color) -> void:
		var tl: Vector2 = world_to_minimap(Vector3(cx - w_x * 0.5, 0.0, cz - w_z * 0.5))
		var br: Vector2 = world_to_minimap(Vector3(cx + w_x * 0.5, 0.0, cz + w_z * 0.5))
		draw_rect(Rect2(tl, br - tl), col)

	func _draw_diamond(pos: Vector2, r: float, fill: Color, border: Color) -> void:
		var outer := PackedVector2Array([
			pos + Vector2(0.0, -r - 1.2),
			pos + Vector2(r + 1.2, 0.0),
			pos + Vector2(0.0, r + 1.2),
			pos + Vector2(-r - 1.2, 0.0),
		])
		var inner := PackedVector2Array([
			pos + Vector2(0.0, -r),
			pos + Vector2(r, 0.0),
			pos + Vector2(0.0, r),
			pos + Vector2(-r, 0.0),
		])
		draw_colored_polygon(outer, border)
		draw_colored_polygon(inner, fill)

	func _draw() -> void:
		var s: Vector2 = _get_effective_size()
		var proj: Dictionary = _get_projection_params()
		var sc: float = float(proj["px_per_m"])

		# 1. Ocean water background
		var ocean_col := Color(0.11, 0.28, 0.44)
		draw_rect(Rect2(Vector2.ZERO, s), ocean_col)

		# 2. Sculpted island coastline (sandy shore + green landmass + hill contours)
		var shore_poly: PackedVector2Array = _build_rounded_land_poly(710.0, 450.0, 46.0)
		draw_colored_polygon(shore_poly, Color(0.68, 0.62, 0.44))
		var land_poly: PackedVector2Array = _build_rounded_land_poly(710.0, 450.0, 35.0)
		draw_colored_polygon(land_poly, Color(0.24, 0.36, 0.22))

		# Subtle hill contours (Windmill Hill & Lighthouse Cliff)
		draw_circle(world_to_minimap(Vector3(-230.0, 0.0, -240.0)), maxf(4.0, 72.0 * sc), Color(0.28, 0.41, 0.25))
		draw_circle(world_to_minimap(Vector3(-470.0, 0.0, 315.0)), maxf(4.0, 56.0 * sc), Color(0.28, 0.41, 0.25))

		# 3. Winding central river ribbon
		var river_pts := PackedVector2Array()
		var r_steps: int = 24
		for ri in range(r_steps + 1):
			var z_val: float = lerpf(WORLD_MIN_Z, WORLD_MAX_Z, float(ri) / float(r_steps))
			var x_val: float = MapSeasideFrontline.get_river_center_x(z_val)
			river_pts.append(world_to_minimap(Vector3(x_val, 0.0, z_val)))
		draw_polyline(river_pts, ocean_col, maxf(3.0, 34.0 * sc), true)

		# 4. Main Roads, Plaza, Runways, Piers & River Bridges
		var road_col := Color(0.36, 0.34, 0.30)
		var runway_col := Color(0.28, 0.29, 0.32)
		var pier_col := Color(0.46, 0.38, 0.28)
		var bridge_col := Color(0.54, 0.49, 0.40)

		_draw_world_rect(-259.0, 40.0, 762.0, 16.0, road_col)
		_draw_world_rect(424.0, 40.0, 432.0, 16.0, road_col)
		_draw_world_rect(0.0, 50.0, 15.0, 820.0, road_col)
		_draw_world_rect(0.0, 40.0, 106.0, 94.0, road_col)
		_draw_world_rect(-149.0, 444.0, 542.0, 13.0, road_col)
		_draw_world_rect(311.0, 444.0, 218.0, 13.0, road_col)
		_draw_world_rect(-345.0, 246.0, 13.0, 412.0, road_col)

		# Runways
		_draw_world_rect(-490.0, -90.0, 220.0, 24.0, runway_col)
		_draw_world_rect(490.0, 105.0, 220.0, 24.0, runway_col)

		# Piers
		_draw_world_rect(-370.0, 510.0, 14.0, 104.0, pier_col)
		_draw_world_rect(0.0, 510.0, 14.0, 104.0, pier_col)
		_draw_world_rect(370.0, 510.0, 14.0, 104.0, pier_col)

		# Bridges spanning the river
		_draw_world_rect(MapSeasideFrontline.get_river_center_x(40.0), 40.0, 64.0, 18.0, bridge_col)
		_draw_world_rect(MapSeasideFrontline.get_river_center_x(444.0), 444.0, 64.0, 15.0, bridge_col)

		if hud_owner == null:
			draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.12, 0.18, 0.95), false, 2.0)
			return

		var local_hero: HeroCharacter = hud_owner._local_hero
		var local_team: int = local_hero.team if (local_hero != null and is_instance_valid(local_hero)) else NetworkManager.TEAM_ROYAL
		var font: Font = ThemeDB.fallback_font
		var font_sz: int = 12 if mortar_active else 9

		# 5. All 6 Conquest Flags A..F
		if hud_owner._conquest != null:
			var letters: PackedStringArray = PackedStringArray(["A", "B", "C", "D", "E", "F"])
			var cps: Array[CapturePoint] = hud_owner._conquest.capture_points
			for ci in range(cps.size()):
				var cp: CapturePoint = cps[ci]
				if cp == null:
					continue
				var cp_pos: Vector3 = cp.global_position if cp.is_inside_tree() else cp.position
				var mp: Vector2 = world_to_minimap(cp_pos)
				var f_col: Color = Color(0.76, 0.78, 0.82)
				if cp.owner_team == NetworkManager.TEAM_ROYAL:
					f_col = Color(0.22, 0.56, 1.0)
				elif cp.owner_team == NetworkManager.TEAM_NATIONAL:
					f_col = Color(0.94, 0.24, 0.24)
				var r_box: float = 7.0 if mortar_active else 5.5
				draw_rect(Rect2(mp - Vector2(r_box + 1.0, r_box + 1.0), Vector2((r_box + 1.0) * 2.0, (r_box + 1.0) * 2.0)), Color(0.05, 0.06, 0.08, 0.92))
				draw_rect(Rect2(mp - Vector2(r_box, r_box), Vector2(r_box * 2.0, r_box * 2.0)), f_col)
				var letter: String = letters[ci] if ci < letters.size() else str(ci)
				if font != null:
					draw_string(font, mp + Vector2(-3.5 if not mortar_active else -4.5, 3.5 if not mortar_active else 4.5), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color.WHITE)

		# 6. Structures (ArmorKit, Trench, Turret) when allied or nearby
		if hud_owner.is_inside_tree():
			var local_pos: Vector3 = local_hero.global_position if (local_hero != null and is_instance_valid(local_hero) and local_hero.is_inside_tree()) else Vector3.ZERO
			var has_local_pos: bool = (local_hero != null and is_instance_valid(local_hero))
			for grp_name in ["armor_kits", "trenches", "turrets"]:
				for node in hud_owner.get_tree().get_nodes_in_group(grp_name):
					if not (node is Node3D) or not is_instance_valid(node) or node.is_queued_for_deletion():
						continue
					var n3 := node as Node3D
					var n_pos: Vector3 = n3.global_position if n3.is_inside_tree() else n3.position
					var raw_team: Variant = n3.get("owner_team")
					if raw_team == null:
						raw_team = n3.get("team")
					var n_team: int = int(raw_team) if raw_team != null else -1
					var near_local: bool = has_local_pos and n_pos.distance_to(local_pos) <= 45.0
					if n_team != local_team and not near_local:
						continue
					var sp: Vector2 = world_to_minimap(n_pos)
					var s_col: Color = Color(0.32, 0.90, 0.96) if grp_name == "armor_kits" else (Color(0.86, 0.72, 0.36) if grp_name == "trenches" else Color(0.98, 0.62, 0.22))
					if grp_name == "turrets":
						_draw_diamond(sp, 3.2, s_col, Color(0.05, 0.06, 0.08))
					elif grp_name == "trenches":
						draw_rect(Rect2(sp - Vector2(3.5, 1.5), Vector2(7.0, 3.0)), s_col)
					else:
						draw_rect(Rect2(sp - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), s_col)

		# 7. Vehicles (allied, neutral, occupied by ally, marked, or sensed)
		for v in hud_owner._vehicles_ref:
			if v == null or not is_instance_valid(v) or v.is_destroyed:
				continue
			var v_pos: Vector3 = v.global_position if v.is_inside_tree() else v.position
			var v_sensed: bool = (v.team >= 0 and v.team != local_team) and StatusEffectContainer.is_pos_sensed_by_team(v_pos, local_team, hud_owner._heroes_ref, local_hero)
			var is_visible_v: bool = (v.team == local_team) or (v.team == -1) or v.is_marked or v_sensed
			if not is_visible_v:
				continue
			var vp: Vector2 = world_to_minimap(v_pos)
			var v_col: Color = Color(0.78, 0.76, 0.66)
			if v.team == NetworkManager.TEAM_ROYAL:
				v_col = Color(0.36, 0.74, 1.0)
			elif v.team == NetworkManager.TEAM_NATIONAL:
				v_col = Color(1.0, 0.34, 0.30)
			var v_fwd_3d: Vector3 = -v.global_transform.basis.z if v.is_inside_tree() else Vector3(0.0, 0.0, -1.0)
			var v_dir := Vector2(v_fwd_3d.x, v_fwd_3d.z)
			if v_dir.length_squared() < 0.001:
				v_dir = Vector2(0.0, -1.0)
			else:
				v_dir = v_dir.normalized()
			var v_perp := Vector2(-v_dir.y, v_dir.x)
			var vr: float = 4.6 if mortar_active else 3.8
			var tri := PackedVector2Array([
				vp + v_dir * vr,
				vp - v_dir * (vr * 0.7) + v_perp * (vr * 0.75),
				vp - v_dir * (vr * 0.7) - v_perp * (vr * 0.75),
			])
			draw_colored_polygon(tri, v_col)

		# 8. Allied Heroes & Revealed Enemy Heroes (Sixth Sense or Mark Target)
		for id_key in hud_owner._heroes_ref.keys():
			var h: HeroCharacter = hud_owner._heroes_ref[id_key] as HeroCharacter
			if h == null or not is_instance_valid(h) or h.is_defeated or h == local_hero:
				continue
			var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
			var hp_2d: Vector2 = world_to_minimap(h_pos)
			if h.team == local_team:
				var ally_col: Color = Color(0.28, 0.68, 1.0) if h.team == NetworkManager.TEAM_ROYAL else Color(0.96, 0.34, 0.30)
				draw_circle(hp_2d, 3.8, Color(0.04, 0.06, 0.08, 0.90))
				draw_circle(hp_2d, 2.7, ally_col)
			else:
				var marked: bool = (h.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0
				var sensed: bool = StatusEffectContainer.is_enemy_sensed_by_team(h, local_team, hud_owner._heroes_ref, local_hero)
				if marked or sensed:
					_draw_diamond(hp_2d, 4.0, Color(1.0, 0.16, 0.16), Color(1.0, 0.96, 0.85))

		# 9. Local Hero: Translucent FOV Wedge + White/Gold Directional Arrow
		if local_hero != null and is_instance_valid(local_hero) and not local_hero.is_defeated:
			var lh_pos: Vector3 = local_hero.global_position if local_hero.is_inside_tree() else local_hero.position
			var lp: Vector2 = world_to_minimap(lh_pos)
			var fwd3: Vector3 = -(Basis(Vector3.UP, local_hero.aim_yaw).z)
			var dir2 := Vector2(fwd3.x, fwd3.z)
			if dir2.length_squared() < 0.001:
				dir2 = Vector2(0.0, -1.0)
			else:
				dir2 = dir2.normalized()
			var base_ang: float = atan2(dir2.y, dir2.x)
			var half_fov: float = deg_to_rad(34.0)
			var cone_r: float = 34.0 if mortar_active else 24.0
			var fov_pts := PackedVector2Array([lp])
			for fi in range(9):
				var fa: float = lerpf(base_ang - half_fov, base_ang + half_fov, float(fi) / 8.0)
				fov_pts.append(lp + Vector2(cos(fa), sin(fa)) * cone_r)
			draw_colored_polygon(fov_pts, Color(1.0, 0.94, 0.65, 0.22))

			var perp2 := Vector2(-dir2.y, dir2.x)
			var ar: float = 7.0 if mortar_active else 5.5
			var arrow_out := PackedVector2Array([
				lp + dir2 * (ar + 1.5),
				lp - dir2 * (ar * 0.75) + perp2 * (ar * 0.8 + 1.2),
				lp - dir2 * (ar * 0.35),
				lp - dir2 * (ar * 0.75) - perp2 * (ar * 0.8 + 1.2),
			])
			var arrow_in := PackedVector2Array([
				lp + dir2 * ar,
				lp - dir2 * (ar * 0.65) + perp2 * (ar * 0.68),
				lp - dir2 * (ar * 0.25),
				lp - dir2 * (ar * 0.65) - perp2 * (ar * 0.68),
			])
			draw_colored_polygon(arrow_out, Color(0.05, 0.06, 0.08, 0.96))
			draw_colored_polygon(arrow_in, Color(1.0, 0.94, 0.36))

		# 10. Mortar Target Reticle when targeting mode is active
		if mortar_active and hover_local_pos.x >= 0.0 and hover_local_pos.y >= 0.0:
			var r_col := Color(1.0, 0.86, 0.24, 0.95)
			draw_arc(hover_local_pos, 14.0, 0.0, TAU, 24, r_col, 2.0, true)
			draw_line(hover_local_pos - Vector2(18.0, 0.0), hover_local_pos + Vector2(18.0, 0.0), r_col, 1.5)
			draw_line(hover_local_pos - Vector2(0.0, 18.0), hover_local_pos + Vector2(0.0, 18.0), r_col, 1.5)

		# 11. Framed Border
		var border_col := Color(1.0, 0.84, 0.26, 0.98) if mortar_active else Color(0.08, 0.12, 0.18, 0.95)
		draw_rect(Rect2(Vector2.ZERO, s), border_col, false, 3.0 if mortar_active else 2.0)


@export var hotkeys_config_path: String = InputCmd.DEFAULT_HOTKEYS_PATH

var _portrait_gauge: PortraitGaugeControl
var _portrait_tex: TextureRect
var _level_lbl: Label
var _hero_pts_lbl: Label
var _ping_lbl: Label

var _royal_ticket_lbl: Label
var _national_ticket_lbl: Label
var _royal_mult_lbl: Label
var _national_mult_lbl: Label
var _royal_flag_tex: TextureRect
var _national_flag_tex: TextureRect
var _flag_pips: Array[ColorRect] = []
var _damage_arc: DamageFlashArc

var _hp_icon_tex: TextureRect
var _hp_value_lbl: Label
var _shield_value_lbl: Label

var _ammo_icon_tex: TextureRect
var _ammo_value_lbl: Label
var _weapon_name_lbl: Label

var _hotbar_hbox: HBoxContainer
var _weapon_slot_boxes: Array[VBoxContainer] = []
var _weapon_slot_bgs: Array[PanelContainer] = []
var _weapon_slot_icons: Array[TextureRect] = []
var _weapon_slot_keys: Array[Label] = []

var _skill_slot_boxes: Array[VBoxContainer] = []
var _skill_slot_bgs: Array[PanelContainer] = []
var _skill_slot_icons: Array[TextureRect] = []
var _skill_slot_cd_lbls: Array[Label] = []
var _skill_slot_keys: Array[Label] = []
var _upgrade_buttons: Array[Button] = []

var _widget_slot_bgs: Array[PanelContainer] = []
var _widget_slot_icons: Array[TextureRect] = []
var _widget_slot_cd_lbls: Array[Label] = []
var _widget_slot_keys: Array[Label] = []

var _poison_tint_rect: ColorRect
var _poison_pulse_time: float = 0.0

var _mastery_lbl: Label
var _crosshair: Control
var _crosshair_top: ColorRect
var _crosshair_bottom: ColorRect
var _crosshair_left: ColorRect
var _crosshair_right: ColorRect
var _crosshair_dot: ColorRect
var _crosshair_spread_px: float = 6.0
var _crosshair_bloom: float = 0.0
var _bound_weapon_signals: Array[WeaponBase] = []
var _scope_overlay: Control
var _hitmarker_container: Control
var _hitmarker_lbl: Label
var _parachute_lbl: Label
var _interact_lbl: Label
var _defeat_lbl: Label
var _killfeed_lbl: Label
var _sixth_sense_layer: Control
var _marker_pool: Array[Label] = []
var _damage_numbers_layer: Control
var _floating_dmgs: Array[Dictionary] = []

var _veh_hp_panel: PanelContainer
var _veh_name_lbl: Label
var _veh_seat_lbl: Label
var _veh_hp_lbl: Label
var _veh_hp_bar_bg: ColorRect
var _veh_hp_bar_fill: ColorRect
var _veh_pulse_time: float = 0.0
var _last_hud_vehicle_id: int = -1
var _seat_diagram_panel: PanelContainer
var _seat_slot_buttons: Array[Button] = []
var _seat_slot_labels: Array[Label] = []
var _seat_style_mine: StyleBoxFlat
var _seat_style_occupied_royal: StyleBoxFlat
var _seat_style_occupied_national: StyleBoxFlat
var _seat_style_free: StyleBoxFlat
var _last_seat_states: PackedStringArray = PackedStringArray()

var _hitmarker_timer: float = 0.0
var _damage_flash_timer: float = 0.0
var _prev_hp_observed: int = -1
var _killfeed_lines: Array[String] = []
var _last_portrait_key: String = ""
var _last_hotbar_class_id: int = -1
var _slot_style_active: StyleBoxFlat
var _slot_style_idle: StyleBoxFlat
var _slot_style_drag_source: StyleBoxFlat
var _slot_style_drag_target: StyleBoxFlat
var _last_highlighted_slot: int = -1
var _last_gauge_xp: int = -1
var _last_gauge_level: int = -1
var _last_gauge_team: int = -1

var _alt_cursor_mode: bool = false
var _prev_alt_key_held: bool = false
var _drag_active: bool = false
var _drag_category: String = ""
var _drag_source_vis: int = -1
var _drag_hover_vis: int = -1
var _drag_preview: TextureRect = null
var _alt_hint_lbl: Label = null
var _hotbar_alt_hint_lbl: Label = null

var _minimap: _TacticalMinimapControl = null
var _mortar_targeting_active: bool = false
var _mortar_target_callback: Callable = Callable()
var _mortar_banner_lbl: Label = null

var _last_ping_ms: int = -1
var _last_sim_lat_ms: int = -1
var _last_royal_tickets: int = -1
var _last_national_tickets: int = -1
var _last_royal_mult: int = -1
var _last_national_mult: int = -1
var _last_flag_owners: PackedInt32Array = PackedInt32Array()
var _last_hp_val: int = -1
var _last_shield_val: int = -1
var _last_ammo_key: String = ""
var _last_interact_text: String = ""
var _last_veh_name_type: int = -99
var _last_veh_seat_txt: String = ""
var _last_veh_hp: int = -1
var _last_veh_max_hp: int = -1

var _local_hero: HeroCharacter = null
var _conquest: ConquestManager = null
var _vehicles_ref: Array[VehicleBase] = []
var _heroes_ref: Dictionary = {}


static func get_vehicle_display_name(v_type: int) -> String:
	match v_type:
		VehicleBase.VehicleType.TANK:
			return "TANQUE"
		VehicleBase.VehicleType.JEEP:
			return "JIPE"
		VehicleBase.VehicleType.PLANE:
			return "CAÇA"
		VehicleBase.VehicleType.BOAT:
			return "LANCHA"
		VehicleBase.VehicleType.AA_GUN:
			return "CANHÃO AA"
		VehicleBase.VehicleType.MOTORCYCLE:
			return "MOTO"
		VehicleBase.VehicleType.APC:
			return "BLINDADO"
		VehicleBase.VehicleType.MOUNTED_MG:
			return "Metralhadora c/ Escudo"
		_:
			return "VEÍCULO"


static func get_seat_display_name(seat_type: int, vehicle_type: int = -1) -> String:
	match seat_type:
		VehicleBase.SeatType.DRIVER:
			if vehicle_type == VehicleBase.VehicleType.BOAT or vehicle_type == VehicleBase.VehicleType.PLANE:
				return "Piloto"
			return "Motorista"
		VehicleBase.SeatType.PASSENGER:
			return "Passageiro"
		VehicleBase.SeatType.WING_RIDER:
			return "Asa"
		VehicleBase.SeatType.GUNNER:
			return "Artilheiro"
		_:
			return ""


func _ready() -> void:
	layer = 10
	add_to_group("hud_controllers")
	set_process_input(true)
	_build_hud()


func bind_context(p_conquest: ConquestManager, p_vehicles: Array[VehicleBase], p_heroes: Dictionary) -> void:
	_conquest = p_conquest
	_vehicles_ref = p_vehicles
	_heroes_ref = p_heroes


func set_local_hero(hero: HeroCharacter) -> void:
	for old_w in _bound_weapon_signals:
		if is_instance_valid(old_w) and old_w.fired.is_connected(_on_local_weapon_fired):
			old_w.fired.disconnect(_on_local_weapon_fired)
	_bound_weapon_signals.clear()

	_local_hero = hero
	_prev_hp_observed = hero.hp if hero != null else -1
	_last_portrait_key = ""
	_last_hotbar_class_id = -1
	_last_highlighted_slot = -1
	_last_gauge_level = -1
	_last_hp_val = -1
	_last_shield_val = -1
	_last_ammo_key = ""
	_last_interact_text = ""
	_reset_seat_diagram_cache()
	_crosshair_bloom = 0.0
	_crosshair_spread_px = 6.0
	_apply_crosshair_spread(_crosshair_spread_px)
	_refresh_hotbar_icons()


func trigger_crosshair_bloom(amount: float = 6.0) -> void:
	_crosshair_bloom = minf(20.0, _crosshair_bloom + amount)


func _on_local_weapon_fired(w_kind: int, _muzzle: Vector3, _hit: Vector3) -> void:
	var bump: float = 8.5 if (w_kind == WeaponBase.WeaponKind.SHOTGUN or w_kind == WeaponBase.WeaponKind.SNIPER or w_kind == WeaponBase.WeaponKind.BAZOOKA) else 5.0
	trigger_crosshair_bloom(bump)


func show_hitmarker(is_headshot: bool, is_kill: bool = false) -> void:
	var hm_col: Color
	if is_kill:
		hm_col = Color.WHITE
		_hitmarker_timer = 0.24
	elif is_headshot:
		hm_col = Color(1.0, 0.16, 0.14)
		_hitmarker_timer = 0.20
	else:
		hm_col = Color(0.76, 0.78, 0.82)
		_hitmarker_timer = 0.16
	if _hitmarker_container != null:
		_hitmarker_container.visible = true
		_hitmarker_container.modulate = hm_col
	if _hitmarker_lbl != null:
		_hitmarker_lbl.visible = true
		_hitmarker_lbl.modulate = hm_col


func trigger_damage_flash() -> void:
	_damage_flash_timer = 0.45


func add_killfeed(text: String) -> void:
	_killfeed_lines.append(text)
	while _killfeed_lines.size() > 5:
		_killfeed_lines.pop_front()
	if _killfeed_lbl != null:
		_killfeed_lbl.text = "\n".join(_killfeed_lines)


func clear_killfeed() -> void:
	_killfeed_lines.clear()
	if _killfeed_lbl != null:
		_killfeed_lbl.text = ""


func _style_label(lbl: Label, font_size: int, color: Color = Color.WHITE) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.96))
	lbl.add_theme_constant_override("outline_size", maxi(3, int(roundf(float(font_size) * 0.18))))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)


func _init_seat_styles() -> void:
	if _seat_style_mine != null:
		return
	_seat_style_mine = StyleBoxFlat.new()
	_seat_style_mine.set_corner_radius_all(4)
	_seat_style_mine.set_border_width_all(2)
	_seat_style_mine.bg_color = Color(0.85, 0.65, 0.14, 0.90)
	_seat_style_mine.border_color = Color(1.0, 0.94, 0.45)

	_seat_style_occupied_royal = StyleBoxFlat.new()
	_seat_style_occupied_royal.set_corner_radius_all(4)
	_seat_style_occupied_royal.set_border_width_all(1)
	_seat_style_occupied_royal.bg_color = Color(0.18, 0.45, 0.85, 0.85)
	_seat_style_occupied_royal.border_color = Color(0.82, 0.88, 0.96, 0.80)

	_seat_style_occupied_national = StyleBoxFlat.new()
	_seat_style_occupied_national.set_corner_radius_all(4)
	_seat_style_occupied_national.set_border_width_all(1)
	_seat_style_occupied_national.bg_color = Color(0.78, 0.22, 0.22, 0.85)
	_seat_style_occupied_national.border_color = Color(0.82, 0.88, 0.96, 0.80)

	_seat_style_free = StyleBoxFlat.new()
	_seat_style_free.set_corner_radius_all(4)
	_seat_style_free.set_border_width_all(1)
	_seat_style_free.bg_color = Color(0.16, 0.20, 0.26, 0.82)
	_seat_style_free.border_color = Color(0.45, 0.52, 0.62, 0.72)


func _reset_seat_diagram_cache() -> void:
	if _last_seat_states.size() != 4:
		_last_seat_states.resize(4)
	for i in range(4):
		_last_seat_states[i] = ""


func _hide_all_sixth_sense_markers() -> void:
	for marker in _marker_pool:
		if is_instance_valid(marker) and marker.visible:
			marker.visible = false


func _make_crosshair_bar(node_name: String, outer_size: Vector2, inner_size: Vector2, fill_col: Color = Color(0.96, 0.97, 0.98, 0.95)) -> ColorRect:
	var outline := ColorRect.new()
	outline.name = node_name
	outline.size = outer_size
	outline.color = Color(0.03, 0.04, 0.06, 0.92)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var inner := ColorRect.new()
	inner.name = "Fill"
	inner.size = inner_size
	inner.position = (outer_size - inner_size) * 0.5
	inner.color = fill_col
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outline.add_child(inner)
	return outline


func _apply_crosshair_spread(gap: float) -> void:
	if _crosshair_top != null:
		_crosshair_top.position = Vector2(-2.0, -gap - 10.0)
	if _crosshair_bottom != null:
		_crosshair_bottom.position = Vector2(-2.0, gap - 1.0)
	if _crosshair_left != null:
		_crosshair_left.position = Vector2(-gap - 10.0, -2.0)
	if _crosshair_right != null:
		_crosshair_right.position = Vector2(gap - 1.0, -2.0)


func _make_slot_style(highlighted: bool) -> StyleBoxFlat:
	if highlighted and _slot_style_active != null:
		return _slot_style_active
	if not highlighted and _slot_style_idle != null:
		return _slot_style_idle
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.10, 0.42) if not highlighted else Color(0.95, 0.85, 0.45, 0.30)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.88) if highlighted else Color(1.0, 1.0, 1.0, 0.22)
	sb.border_width_bottom = 3 if highlighted else 1
	sb.border_width_top = 1
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	if highlighted:
		_slot_style_active = sb
	else:
		_slot_style_idle = sb
	return sb


func _build_hud() -> void:
	# 0. Full-Screen Poisoned Blade Green Tint Overlay
	_poison_tint_rect = ColorRect.new()
	_poison_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_poison_tint_rect.color = Color(0.16, 0.72, 0.22, 0.26)
	_poison_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_poison_tint_rect.visible = false
	add_child(_poison_tint_rect)

	# 1. Top-Left Circular Portrait + XP Ring + Level Badge
	var tl_root := Control.new()
	tl_root.offset_left = 14.0
	tl_root.offset_top = 10.0
	tl_root.offset_right = 260.0
	tl_root.offset_bottom = 135.0
	tl_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl_root)

	_portrait_gauge = PortraitGaugeControl.new()
	_portrait_gauge.position = Vector2(0.0, 0.0)
	_portrait_gauge.size = Vector2(96.0, 96.0)
	_portrait_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_root.add_child(_portrait_gauge)

	_portrait_tex = TextureRect.new()
	_portrait_tex.position = Vector2(18.0, 16.0)
	_portrait_tex.size = Vector2(60.0, 60.0)
	_portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_tex.texture = CartoonAssets.get_texture("portrait_royal_0")
	_portrait_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl_root.add_child(_portrait_tex)

	_level_lbl = Label.new()
	_level_lbl.position = Vector2(78.0, 56.0)
	_level_lbl.text = "1"
	_style_label(_level_lbl, 22, Color(1.0, 0.96, 0.85))
	tl_root.add_child(_level_lbl)

	_hero_pts_lbl = Label.new()
	_hero_pts_lbl.position = Vector2(102.0, 26.0)
	_hero_pts_lbl.text = ""
	_hero_pts_lbl.visible = false
	_style_label(_hero_pts_lbl, 14, Color(1.0, 0.88, 0.25))
	tl_root.add_child(_hero_pts_lbl)

	_ping_lbl = Label.new()
	_ping_lbl.position = Vector2(4.0, 98.0)
	_ping_lbl.text = "Ping: 0ms | F8: Lag | ESC: Menu"
	_style_label(_ping_lbl, 12, Color(0.88, 0.92, 0.98))
	tl_root.add_child(_ping_lbl)

	# 2. Top-Center Ticket Scoreboard + Royal Crown & National Skull Flags + Multipliers + Damage Arc
	var top_anchor := Control.new()
	top_anchor.anchor_left = 0.5
	top_anchor.anchor_right = 0.5
	top_anchor.offset_left = -260.0
	top_anchor.offset_right = 260.0
	top_anchor.offset_top = 6.0
	top_anchor.offset_bottom = 150.0
	top_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_anchor)

	_damage_arc = DamageFlashArc.new()
	_damage_arc.position = Vector2(100.0, 28.0)
	_damage_arc.size = Vector2(320.0, 120.0)
	_damage_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_anchor.add_child(_damage_arc)

	var top_hbox := HBoxContainer.new()
	top_hbox.position = Vector2(0.0, 0.0)
	top_hbox.size = Vector2(520.0, 74.0)
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 18)
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_anchor.add_child(top_hbox)

	_national_ticket_lbl = Label.new()
	_national_ticket_lbl.text = "50"
	_style_label(_national_ticket_lbl, 34, Color(1.0, 0.92, 0.90))
	top_hbox.add_child(_national_ticket_lbl)

	var nat_col := VBoxContainer.new()
	nat_col.alignment = BoxContainer.ALIGNMENT_CENTER
	nat_col.add_theme_constant_override("separation", 0)
	nat_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(nat_col)

	_national_flag_tex = TextureRect.new()
	_national_flag_tex.custom_minimum_size = Vector2(66, 44)
	_national_flag_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_national_flag_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_national_flag_tex.texture = CartoonAssets.get_texture("flag_national")
	_national_flag_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nat_col.add_child(_national_flag_tex)

	_national_mult_lbl = Label.new()
	_national_mult_lbl.text = "1x"
	_national_mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_national_mult_lbl, 17, Color(1.0, 0.95, 0.85))
	nat_col.add_child(_national_mult_lbl)

	var roy_col := VBoxContainer.new()
	roy_col.alignment = BoxContainer.ALIGNMENT_CENTER
	roy_col.add_theme_constant_override("separation", 0)
	roy_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(roy_col)

	_royal_flag_tex = TextureRect.new()
	_royal_flag_tex.custom_minimum_size = Vector2(66, 44)
	_royal_flag_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_royal_flag_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_royal_flag_tex.texture = CartoonAssets.get_texture("flag_royal")
	_royal_flag_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roy_col.add_child(_royal_flag_tex)

	_royal_mult_lbl = Label.new()
	_royal_mult_lbl.text = "1x"
	_royal_mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_royal_mult_lbl, 17, Color(0.90, 0.96, 1.0))
	roy_col.add_child(_royal_mult_lbl)

	_royal_ticket_lbl = Label.new()
	_royal_ticket_lbl.text = "50"
	_style_label(_royal_ticket_lbl, 34, Color(0.92, 0.97, 1.0))
	top_hbox.add_child(_royal_ticket_lbl)

	# 6 Flag ownership pips neatly beneath the scoreboard (with A..F letters)
	var pips_hbox := HBoxContainer.new()
	pips_hbox.position = Vector2(126.0, 72.0)
	pips_hbox.size = Vector2(268.0, 18.0)
	pips_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_hbox.add_theme_constant_override("separation", 6)
	pips_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_anchor.add_child(pips_hbox)

	_last_flag_owners.resize(6)
	var flag_letters: PackedStringArray = PackedStringArray(["A", "B", "C", "D", "E", "F"])
	for i in range(6):
		_last_flag_owners[i] = -99
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 16)
		pip.color = Color(0.85, 0.85, 0.85)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pip_lbl := Label.new()
		pip_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		pip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pip_lbl.text = flag_letters[i]
		pip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(pip_lbl, 11, Color.WHITE)
		pip.add_child(pip_lbl)
		pips_hbox.add_child(pip)
		_flag_pips.append(pip)

	# 3. Bottom-Left: Giant '+' Icon + Bold HP (+ Shield)
	var bl_hbox := HBoxContainer.new()
	bl_hbox.anchor_top = 1.0
	bl_hbox.anchor_bottom = 1.0
	bl_hbox.offset_left = 20.0
	bl_hbox.offset_top = -78.0
	bl_hbox.offset_right = 280.0
	bl_hbox.offset_bottom = -14.0
	bl_hbox.add_theme_constant_override("separation", 10)
	bl_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bl_hbox)

	_hp_icon_tex = TextureRect.new()
	_hp_icon_tex.custom_minimum_size = Vector2(54, 54)
	_hp_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hp_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hp_icon_tex.texture = CartoonAssets.get_texture("icon_hp")
	_hp_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl_hbox.add_child(_hp_icon_tex)

	var hp_vbox := VBoxContainer.new()
	hp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hp_vbox.add_theme_constant_override("separation", -4)
	hp_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl_hbox.add_child(hp_vbox)

	_hp_value_lbl = Label.new()
	_hp_value_lbl.text = "110"
	_style_label(_hp_value_lbl, 34, Color.WHITE)
	hp_vbox.add_child(_hp_value_lbl)

	_shield_value_lbl = Label.new()
	_shield_value_lbl.text = ""
	_style_label(_shield_value_lbl, 14, Color(0.45, 0.85, 1.0))
	hp_vbox.add_child(_shield_value_lbl)

	# 4. Bottom-Right: Bold Magazine Ammo + Golden Bullet Sprite
	var br_hbox := HBoxContainer.new()
	br_hbox.anchor_left = 1.0
	br_hbox.anchor_right = 1.0
	br_hbox.anchor_top = 1.0
	br_hbox.anchor_bottom = 1.0
	br_hbox.offset_left = -310.0
	br_hbox.offset_top = -86.0
	br_hbox.offset_right = -20.0
	br_hbox.offset_bottom = -16.0
	br_hbox.alignment = BoxContainer.ALIGNMENT_END
	br_hbox.add_theme_constant_override("separation", 10)
	br_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br_hbox)

	var ammo_vbox := VBoxContainer.new()
	ammo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo_vbox.add_theme_constant_override("separation", -4)
	ammo_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_hbox.add_child(ammo_vbox)

	_ammo_value_lbl = Label.new()
	_ammo_value_lbl.text = "32"
	_ammo_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_ammo_value_lbl, 34, Color.WHITE)
	ammo_vbox.add_child(_ammo_value_lbl)

	_weapon_name_lbl = Label.new()
	_weapon_name_lbl.text = "SMG | ∞"
	_weapon_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_weapon_name_lbl, 13, Color(0.95, 0.90, 0.72))
	ammo_vbox.add_child(_weapon_name_lbl)

	_ammo_icon_tex = TextureRect.new()
	_ammo_icon_tex.custom_minimum_size = Vector2(34, 46)
	_ammo_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ammo_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ammo_icon_tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ammo_icon_tex.texture = CartoonAssets.get_texture("icon_ammo")
	_ammo_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_hbox.add_child(_ammo_icon_tex)

	# 5. Bottom-Center: Transparent Hotbar (Weapons 1..4, Skills 1..6, Widgets 1..4)
	_hotbar_hbox = HBoxContainer.new()
	_hotbar_hbox.anchor_left = 0.5
	_hotbar_hbox.anchor_right = 0.5
	_hotbar_hbox.anchor_top = 1.0
	_hotbar_hbox.anchor_bottom = 1.0
	_hotbar_hbox.offset_left = -335.0
	_hotbar_hbox.offset_right = 335.0
	_hotbar_hbox.offset_top = -104.0
	_hotbar_hbox.offset_bottom = -8.0
	_hotbar_hbox.clip_contents = false
	_hotbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_hbox.add_theme_constant_override("separation", 4)
	_hotbar_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar_hbox)

	# 4 possible Weapon slots (visible dynamically per class)
	for w_idx in range(4):
		var slot_v := VBoxContainer.new()
		slot_v.alignment = BoxContainer.ALIGNMENT_END
		slot_v.add_theme_constant_override("separation", 2)
		slot_v.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(38, 38)
		bg.add_theme_stylebox_override("panel", _make_slot_style(w_idx == 0))
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		bg.gui_input.connect(_on_slot_gui_input.bind("weapon", w_idx))
		slot_v.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_weapon_%d" % w_idx)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var k_lbl := Label.new()
		k_lbl.text = "%d" % (w_idx + 1)
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(k_lbl, 11, Color(0.95, 0.95, 0.95))
		slot_v.add_child(k_lbl)

		_hotbar_hbox.add_child(slot_v)
		_weapon_slot_boxes.append(slot_v)
		_weapon_slot_bgs.append(bg)
		_weapon_slot_icons.append(icon)
		_weapon_slot_keys.append(k_lbl)

	# 6 Skill slots (up to 6 for Commando, 5 for Soldier/Gunner; all start Rank 5, no '+' buttons)
	_skill_slot_boxes.clear()
	_upgrade_buttons.clear()
	for s_idx in range(6):
		var sv := VBoxContainer.new()
		sv.alignment = BoxContainer.ALIGNMENT_END
		sv.add_theme_constant_override("separation", 2)
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(38, 38)
		bg.add_theme_stylebox_override("panel", _make_slot_style(false))
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		bg.gui_input.connect(_on_slot_gui_input.bind("skill", s_idx))
		sv.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_skill_0_%d" % mini(s_idx, 4))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var cd_lbl := Label.new()
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.text = ""
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(cd_lbl, 12, Color(1.0, 0.90, 0.30))
		bg.add_child(cd_lbl)

		var kl := Label.new()
		kl.text = _format_skill_hotkey_label(s_idx)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(kl, 11, Color(0.95, 0.95, 0.95))
		sv.add_child(kl)

		_hotbar_hbox.add_child(sv)
		_skill_slot_boxes.append(sv)
		_skill_slot_bgs.append(bg)
		_skill_slot_icons.append(icon)
		_skill_slot_cd_lbls.append(cd_lbl)
		_skill_slot_keys.append(kl)

	# 4 Widget slots (Bandages, Wrench, Água, Antidote)
	_widget_slot_bgs.clear()
	var init_widget_order: Array[int] = InputCmd.get_active_widget_order(4)
	for wj in range(4):
		var logical_wj: int = init_widget_order[wj]
		var wv := VBoxContainer.new()
		wv.alignment = BoxContainer.ALIGNMENT_END
		wv.add_theme_constant_override("separation", 2)
		wv.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(38, 38)
		bg.add_theme_stylebox_override("panel", _make_slot_style(false))
		bg.mouse_filter = Control.MOUSE_FILTER_PASS
		bg.gui_input.connect(_on_slot_gui_input.bind("widget", wj))
		var w_entry: Dictionary = SkillCatalog.get_entry_by_key("icon_widget_%d" % logical_wj)
		if not w_entry.is_empty():
			bg.tooltip_text = "%s (%s) — %s\nRecarga: %s | Duração: %s | Área: %s\n%s" % [
				str(w_entry.get("name", "")),
				str(w_entry.get("category", "")),
				str(w_entry.get("effect_stats", "")),
				str(w_entry.get("cooldown", "")),
				str(w_entry.get("duration", "")),
				str(w_entry.get("area", "")),
				str(w_entry.get("description", "")),
			]
		wv.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_widget_%d" % logical_wj)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var cd_lbl := Label.new()
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.text = ""
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_label(cd_lbl, 12, Color(1.0, 0.85, 0.25))
		bg.add_child(cd_lbl)

		var kl := Label.new()
		kl.text = _format_widget_hotkey_label(wj)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(kl, 11, Color(0.95, 0.95, 0.95))
		wv.add_child(kl)

		_hotbar_hbox.add_child(wv)
		_widget_slot_bgs.append(bg)
		_widget_slot_icons.append(icon)
		_widget_slot_cd_lbls.append(cd_lbl)
		_widget_slot_keys.append(kl)

	# Subtle persistent hotbar ALT hint (non-blocking MOUSE_FILTER_IGNORE)
	_hotbar_alt_hint_lbl = Label.new()
	_hotbar_alt_hint_lbl.anchor_left = 0.5
	_hotbar_alt_hint_lbl.anchor_right = 0.5
	_hotbar_alt_hint_lbl.anchor_top = 1.0
	_hotbar_alt_hint_lbl.anchor_bottom = 1.0
	_hotbar_alt_hint_lbl.offset_left = -220.0
	_hotbar_alt_hint_lbl.offset_right = 220.0
	_hotbar_alt_hint_lbl.offset_top = -90.0
	_hotbar_alt_hint_lbl.offset_bottom = -74.0
	_hotbar_alt_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_alt_hint_lbl.text = "[ALT] Cursor / Reorganizar Barra"
	_hotbar_alt_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar_alt_hint_lbl.visible = true
	_style_label(_hotbar_alt_hint_lbl, 10, Color(0.84, 0.90, 0.98, 0.72))
	add_child(_hotbar_alt_hint_lbl)

	# Alt-mode drag hint above hotbar
	_alt_hint_lbl = Label.new()
	_alt_hint_lbl.anchor_left = 0.5
	_alt_hint_lbl.anchor_right = 0.5
	_alt_hint_lbl.anchor_top = 1.0
	_alt_hint_lbl.anchor_bottom = 1.0
	_alt_hint_lbl.offset_left = -220.0
	_alt_hint_lbl.offset_right = 220.0
	_alt_hint_lbl.offset_top = -124.0
	_alt_hint_lbl.offset_bottom = -104.0
	_alt_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alt_hint_lbl.text = "[ALT] Arraste armas, skills ou itens para reorganizar"
	_alt_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alt_hint_lbl.visible = false
	_style_label(_alt_hint_lbl, 12, Color(1.0, 0.90, 0.36))
	add_child(_alt_hint_lbl)

	# Floating Drag Preview Icon
	_drag_preview = TextureRect.new()
	_drag_preview.custom_minimum_size = Vector2(34, 34)
	_drag_preview.size = Vector2(34, 34)
	_drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
	_drag_preview.z_index = 50
	_drag_preview.visible = false
	add_child(_drag_preview)

	# 6. Mid-Right: Combat Mastery / Score XP (cleanly below Killfeed)
	_mastery_lbl = Label.new()
	_mastery_lbl.anchor_left = 1.0
	_mastery_lbl.anchor_right = 1.0
	_mastery_lbl.anchor_top = 0.50
	_mastery_lbl.anchor_bottom = 0.62
	_mastery_lbl.offset_left = -280.0
	_mastery_lbl.offset_right = -24.0
	_mastery_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mastery_lbl.text = "Combat Mastery 1\nScore: 0/100"
	_style_label(_mastery_lbl, 16, Color(1.0, 0.94, 0.72))
	add_child(_mastery_lbl)

	# 7. Top-Right Tactical Minimap (182x182) & Killfeed neatly below it
	_minimap = _TacticalMinimapControl.new()
	_minimap.name = "TacticalMinimap"
	_minimap.hud_owner = self
	_minimap.anchor_left = 1.0
	_minimap.anchor_right = 1.0
	_minimap.anchor_top = 0.0
	_minimap.anchor_bottom = 0.0
	_minimap.custom_minimum_size = Vector2(182.0, 182.0)
	_minimap.offset_left = -198.0
	_minimap.offset_right = -16.0
	_minimap.offset_top = 12.0
	_minimap.offset_bottom = 194.0
	_minimap.size = Vector2(182.0, 182.0)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_minimap)

	_mortar_banner_lbl = Label.new()
	_mortar_banner_lbl.anchor_left = 0.5
	_mortar_banner_lbl.anchor_right = 0.5
	_mortar_banner_lbl.anchor_top = 0.5
	_mortar_banner_lbl.anchor_bottom = 0.5
	_mortar_banner_lbl.offset_left = -240.0
	_mortar_banner_lbl.offset_right = 240.0
	_mortar_banner_lbl.offset_top = -242.0
	_mortar_banner_lbl.offset_bottom = -216.0
	_mortar_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mortar_banner_lbl.text = "MORTEIRO: Clique no mapa para bombardear (ESC / Direito cancela)"
	_mortar_banner_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mortar_banner_lbl.visible = false
	_style_label(_mortar_banner_lbl, 15, Color(1.0, 0.90, 0.30))
	add_child(_mortar_banner_lbl)

	_killfeed_lbl = Label.new()
	_killfeed_lbl.anchor_left = 1.0
	_killfeed_lbl.anchor_right = 1.0
	_killfeed_lbl.offset_left = -420.0
	_killfeed_lbl.offset_right = -16.0
	_killfeed_lbl.offset_top = 202.0
	_killfeed_lbl.offset_bottom = 350.0
	_killfeed_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_killfeed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_killfeed_lbl, 14, Color(0.98, 0.98, 0.98))
	add_child(_killfeed_lbl)

	# 8. Sniper Scope Overlay (1st-person Commando Optic)
	_scope_overlay = SniperScopeOverlay.new()
	_scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.visible = false
	add_child(_scope_overlay)

	var scope_hint := Label.new()
	scope_hint.anchor_left = 0.5
	scope_hint.anchor_right = 0.5
	scope_hint.anchor_top = 0.86
	scope_hint.offset_left = -140.0
	scope_hint.offset_right = 140.0
	scope_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope_hint.text = "4.0x LUNETA  |  [Botão Direito] Sair"
	_style_label(scope_hint, 13, Color(0.95, 0.88, 0.62, 0.85))
	_scope_overlay.add_child(scope_hint)

	# 9. Sixth Sense wall-reveal overlay & Floating Damage Numbers layers
	_sixth_sense_layer = Control.new()
	_sixth_sense_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sixth_sense_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sixth_sense_layer)

	_damage_numbers_layer = Control.new()
	_damage_numbers_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_numbers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_numbers_layer)

	# 10. Center Crosshair, Hitmarker, Parachute Prompt, Vehicle Interact & Defeat
	_crosshair = Control.new()
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_right = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.anchor_bottom = 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.visible = false
	add_child(_crosshair)

	_crosshair_dot = _make_crosshair_bar("CenterDot", Vector2(4, 4), Vector2(2, 2), Color.WHITE)
	_crosshair_dot.color = Color(0.03, 0.04, 0.06, 0.95)
	_crosshair_dot.position = Vector2(-2, -2)
	_crosshair.add_child(_crosshair_dot)

	_crosshair_top = _make_crosshair_bar("Top", Vector2(4, 11), Vector2(2, 9))
	_crosshair_top.visible = false
	_crosshair.add_child(_crosshair_top)
	_crosshair_bottom = _make_crosshair_bar("Bottom", Vector2(4, 11), Vector2(2, 9))
	_crosshair.add_child(_crosshair_bottom)
	_crosshair_left = _make_crosshair_bar("Left", Vector2(11, 4), Vector2(9, 2))
	_crosshair.add_child(_crosshair_left)
	_crosshair_right = _make_crosshair_bar("Right", Vector2(11, 4), Vector2(9, 2))
	_crosshair.add_child(_crosshair_right)
	_apply_crosshair_spread(_crosshair_spread_px)

	_hitmarker_container = Control.new()
	_hitmarker_container.name = "HitmarkerContainer"
	_hitmarker_container.position = Vector2.ZERO
	_hitmarker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker_container.visible = false
	_crosshair.add_child(_hitmarker_container)

	var hm_specs: Array[Dictionary] = [
		{"name": "HitDiagTL", "dir": Vector2(-1.0, -1.0).normalized(), "rot": -PI * 0.25},
		{"name": "HitDiagTR", "dir": Vector2(1.0, -1.0).normalized(), "rot": PI * 0.25},
		{"name": "HitDiagBL", "dir": Vector2(-1.0, 1.0).normalized(), "rot": PI * 0.25},
		{"name": "HitDiagBR", "dir": Vector2(1.0, 1.0).normalized(), "rot": -PI * 0.25},
	]
	var hm_radius_mid: float = 11.5
	for spec in hm_specs:
		var tick := ColorRect.new()
		tick.name = str(spec["name"])
		tick.size = Vector2(2.0, 9.0)
		tick.pivot_offset = Vector2(1.0, 4.5)
		tick.position = (spec["dir"] as Vector2) * hm_radius_mid - tick.pivot_offset
		tick.rotation = float(spec["rot"])
		tick.color = Color.WHITE
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hitmarker_container.add_child(tick)

	_hitmarker_lbl = Label.new()
	_hitmarker_lbl.text = ""
	_hitmarker_lbl.size = Vector2(28, 28)
	_hitmarker_lbl.position = Vector2(-14, -14)
	_hitmarker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hitmarker_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(_hitmarker_lbl, 22, Color.WHITE)
	_hitmarker_lbl.visible = false
	_crosshair.add_child(_hitmarker_lbl)

	_parachute_lbl = Label.new()
	_parachute_lbl.anchor_left = 0.5
	_parachute_lbl.anchor_right = 0.5
	_parachute_lbl.anchor_top = 0.72
	_parachute_lbl.offset_left = -180.0
	_parachute_lbl.offset_right = 180.0
	_parachute_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_parachute_lbl.text = "[ESPAÇO] Abrir Paraquedas"
	_style_label(_parachute_lbl, 20, Color(1.0, 0.94, 0.35))
	_parachute_lbl.visible = false
	add_child(_parachute_lbl)

	_interact_lbl = Label.new()
	_interact_lbl.anchor_left = 0.5
	_interact_lbl.anchor_right = 0.5
	_interact_lbl.anchor_top = 0.64
	_interact_lbl.offset_left = -170.0
	_interact_lbl.offset_right = 170.0
	_interact_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_lbl.text = ""
	_style_label(_interact_lbl, 18, Color(0.95, 0.98, 1.0))
	add_child(_interact_lbl)

	_defeat_lbl = Label.new()
	_defeat_lbl.anchor_left = 0.5
	_defeat_lbl.anchor_right = 0.5
	_defeat_lbl.anchor_top = 0.38
	_defeat_lbl.offset_left = -220.0
	_defeat_lbl.offset_right = 220.0
	_defeat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_defeat_lbl, 26, Color(1.0, 0.42, 0.35))
	_defeat_lbl.visible = false
	add_child(_defeat_lbl)

	# 11. Bottom-Center Vehicle Health Panel (just above hotbar, clear of [E] prompt)
	_veh_hp_panel = PanelContainer.new()
	_veh_hp_panel.anchor_left = 0.5
	_veh_hp_panel.anchor_right = 0.5
	_veh_hp_panel.anchor_top = 1.0
	_veh_hp_panel.anchor_bottom = 1.0
	_veh_hp_panel.offset_left = -160.0
	_veh_hp_panel.offset_right = 160.0
	_veh_hp_panel.offset_top = -138.0
	_veh_hp_panel.offset_bottom = -100.0
	_veh_hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var veh_sb := StyleBoxFlat.new()
	veh_sb.bg_color = Color(0.06, 0.08, 0.12, 0.78)
	veh_sb.border_color = Color(0.95, 0.85, 0.45, 0.65)
	veh_sb.border_width_left = 2
	veh_sb.border_width_right = 2
	veh_sb.border_width_top = 2
	veh_sb.border_width_bottom = 2
	veh_sb.corner_radius_top_left = 6
	veh_sb.corner_radius_top_right = 6
	veh_sb.corner_radius_bottom_left = 6
	veh_sb.corner_radius_bottom_right = 6
	veh_sb.content_margin_left = 10.0
	veh_sb.content_margin_right = 10.0
	veh_sb.content_margin_top = 4.0
	veh_sb.content_margin_bottom = 4.0
	_veh_hp_panel.add_theme_stylebox_override("panel", veh_sb)
	_veh_hp_panel.visible = false
	add_child(_veh_hp_panel)

	var veh_vbox := VBoxContainer.new()
	veh_vbox.add_theme_constant_override("separation", 3)
	veh_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veh_hp_panel.add_child(veh_vbox)

	var veh_top_row := HBoxContainer.new()
	veh_top_row.add_theme_constant_override("separation", 8)
	veh_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veh_vbox.add_child(veh_top_row)

	_veh_name_lbl = Label.new()
	_veh_name_lbl.text = "TANQUE"
	_style_label(_veh_name_lbl, 13, Color(1.0, 0.94, 0.72))
	veh_top_row.add_child(_veh_name_lbl)

	_veh_seat_lbl = Label.new()
	_veh_seat_lbl.text = ""
	_veh_seat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_label(_veh_seat_lbl, 12, Color(0.76, 0.90, 1.0))
	veh_top_row.add_child(_veh_seat_lbl)

	_veh_hp_lbl = Label.new()
	_veh_hp_lbl.text = "HP: 520 / 520"
	_veh_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(_veh_hp_lbl, 13, Color.WHITE)
	veh_top_row.add_child(_veh_hp_lbl)

	_veh_hp_bar_bg = ColorRect.new()
	_veh_hp_bar_bg.custom_minimum_size = Vector2(296.0, 10.0)
	_veh_hp_bar_bg.color = Color(0.12, 0.14, 0.18, 0.92)
	_veh_hp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veh_vbox.add_child(_veh_hp_bar_bg)

	_veh_hp_bar_fill = ColorRect.new()
	_veh_hp_bar_fill.anchor_left = 0.0
	_veh_hp_bar_fill.anchor_top = 0.0
	_veh_hp_bar_fill.anchor_right = 1.0
	_veh_hp_bar_fill.anchor_bottom = 1.0
	_veh_hp_bar_fill.offset_left = 0.0
	_veh_hp_bar_fill.offset_top = 0.0
	_veh_hp_bar_fill.offset_right = 0.0
	_veh_hp_bar_fill.offset_bottom = 0.0
	_veh_hp_bar_fill.color = Color(0.24, 0.84, 0.34)
	_veh_hp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veh_hp_bar_bg.add_child(_veh_hp_bar_fill)

	# 12. Vehicle Seat Occupancy Schematic Panel (just above Vehicle HP bar)
	_seat_diagram_panel = PanelContainer.new()
	_seat_diagram_panel.anchor_left = 0.5
	_seat_diagram_panel.anchor_right = 0.5
	_seat_diagram_panel.anchor_top = 1.0
	_seat_diagram_panel.anchor_bottom = 1.0
	_seat_diagram_panel.offset_left = -215.0
	_seat_diagram_panel.offset_right = 215.0
	_seat_diagram_panel.offset_top = -188.0
	_seat_diagram_panel.offset_bottom = -144.0
	var seat_sb := StyleBoxFlat.new()
	seat_sb.bg_color = Color(0.06, 0.08, 0.12, 0.82)
	seat_sb.border_color = Color(0.45, 0.72, 0.96, 0.72)
	seat_sb.set_border_width_all(2)
	seat_sb.set_corner_radius_all(6)
	seat_sb.content_margin_left = 8.0
	seat_sb.content_margin_right = 8.0
	seat_sb.content_margin_top = 4.0
	seat_sb.content_margin_bottom = 4.0
	_seat_diagram_panel.add_theme_stylebox_override("panel", seat_sb)
	_seat_diagram_panel.visible = false
	add_child(_seat_diagram_panel)

	var seat_hbox := HBoxContainer.new()
	seat_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	seat_hbox.add_theme_constant_override("separation", 6)
	_seat_diagram_panel.add_child(seat_hbox)

	_init_seat_styles()
	_reset_seat_diagram_cache()
	_seat_slot_buttons.clear()
	_seat_slot_labels.clear()
	for s_i in range(4):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96.0, 32.0)
		btn.text = "F%d" % (s_i + 1)
		btn.add_theme_font_size_override("font_size", 11)
		var cap_seat: int = s_i
		btn.pressed.connect(func() -> void:
			NetworkManager.request_seat_switch(cap_seat)
		)
		seat_hbox.add_child(btn)
		_seat_slot_buttons.append(btn)

		var sl := Label.new()
		sl.visible = false
		sl.text = ""
		btn.add_child(sl)
		_seat_slot_labels.append(sl)


static func _format_skill_hotkey_label(slot_idx: int) -> String:
	var lbl: String = InputCmd.key_short_label(InputCmd.get_skill_key(slot_idx))
	if slot_idx == 0 and InputCmd.get_skill_key(0) == KEY_5:
		return "5/F"
	if slot_idx == 1 and InputCmd.get_skill_key(1) == KEY_6:
		return "6/G"
	return lbl


static func _format_widget_hotkey_label(slot_idx: int) -> String:
	return InputCmd.key_short_label(InputCmd.get_widget_key(slot_idx))


func _update_hotkey_label_texts() -> void:
	for i in range(mini(_skill_slot_keys.size(), 6)):
		_skill_slot_keys[i].text = _format_skill_hotkey_label(i)
	for j in range(mini(_widget_slot_keys.size(), 4)):
		_widget_slot_keys[j].text = _format_widget_hotkey_label(j)


func refresh_hotkey_labels() -> void:
	_update_hotkey_label_texts()
	_refresh_widget_hotbar_icons()
	_last_highlighted_slot = -1
	_last_ammo_key = ""
	if _local_hero != null and is_instance_valid(_local_hero):
		_refresh_hotbar_icons()
		_refresh_slot_cooldowns_immediate()
		_refresh_drag_slot_highlights()


func _hide_local_hud_overlays() -> void:
	_cancel_hotbar_drag()
	if _mortar_targeting_active:
		set_mortar_targeting_mode(false)
	if _poison_tint_rect != null:
		_poison_tint_rect.visible = false
	if _crosshair != null:
		_crosshair.visible = false
	if _scope_overlay != null:
		_scope_overlay.visible = false
	if _veh_hp_panel != null:
		_veh_hp_panel.visible = false
	if _seat_diagram_panel != null:
		_seat_diagram_panel.visible = false
	_reset_seat_diagram_cache()
	_hide_all_sixth_sense_markers()


func _make_drag_slot_style(is_target: bool) -> StyleBoxFlat:
	if is_target and _slot_style_drag_target != null:
		return _slot_style_drag_target
	if not is_target and _slot_style_drag_source != null:
		return _slot_style_drag_source
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.72, 1.0, 0.36) if is_target else Color(1.0, 0.84, 0.24, 0.36)
	sb.border_color = Color(0.45, 0.92, 1.0, 0.98) if is_target else Color(1.0, 0.90, 0.32, 0.98)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	if is_target:
		_slot_style_drag_target = sb
	else:
		_slot_style_drag_source = sb
	return sb


func _get_slot_bgs_for_category(category: String) -> Array[PanelContainer]:
	match category:
		"weapon":
			return _weapon_slot_bgs
		"skill":
			return _skill_slot_bgs
		"widget":
			return _widget_slot_bgs
		_:
			return []


func _get_slot_icons_for_category(category: String) -> Array[TextureRect]:
	match category:
		"weapon":
			return _weapon_slot_icons
		"skill":
			return _skill_slot_icons
		"widget":
			return _widget_slot_icons
		_:
			return []


func _find_slot_at_point(category: String, global_pt: Vector2) -> int:
	var bgs: Array[PanelContainer] = _get_slot_bgs_for_category(category)
	for i in range(bgs.size()):
		var bg: PanelContainer = bgs[i]
		if bg != null and bg.is_visible_in_tree() and bg.get_global_rect().has_point(global_pt):
			return i
	return -1


func _refresh_drag_slot_highlights() -> void:
	var active_vis_weapon: int = -1
	if _local_hero != null and is_instance_valid(_local_hero) and not _local_hero.weapons.is_empty():
		var w_order: Array[int] = InputCmd.get_active_weapon_order(_local_hero.weapons.size())
		active_vis_weapon = w_order.find(clampi(_local_hero.selected_weapon_slot, 0, _local_hero.weapons.size() - 1))

	for i in range(_weapon_slot_bgs.size()):
		if _drag_active and _drag_category == "weapon":
			if i == _drag_source_vis:
				_weapon_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(false))
			elif i == _drag_hover_vis:
				_weapon_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(true))
			else:
				_weapon_slot_bgs[i].add_theme_stylebox_override("panel", _make_slot_style(i == active_vis_weapon))
		else:
			_weapon_slot_bgs[i].add_theme_stylebox_override("panel", _make_slot_style(i == active_vis_weapon))

	for i in range(_skill_slot_bgs.size()):
		if _drag_active and _drag_category == "skill" and i == _drag_source_vis:
			_skill_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(false))
		elif _drag_active and _drag_category == "skill" and i == _drag_hover_vis:
			_skill_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(true))
		else:
			_skill_slot_bgs[i].add_theme_stylebox_override("panel", _make_slot_style(false))

	for i in range(_widget_slot_bgs.size()):
		if _drag_active and _drag_category == "widget" and i == _drag_source_vis:
			_widget_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(false))
		elif _drag_active and _drag_category == "widget" and i == _drag_hover_vis:
			_widget_slot_bgs[i].add_theme_stylebox_override("panel", _make_drag_slot_style(true))
		else:
			_widget_slot_bgs[i].add_theme_stylebox_override("panel", _make_slot_style(false))


func _begin_hotbar_drag(category: String, vis_idx: int) -> void:
	var icons: Array[TextureRect] = _get_slot_icons_for_category(category)
	if vis_idx < 0 or vis_idx >= icons.size():
		return
	_drag_active = true
	_drag_category = category
	_drag_source_vis = vis_idx
	_drag_hover_vis = vis_idx
	if _drag_preview != null:
		_drag_preview.texture = icons[vis_idx].texture
		_drag_preview.position = get_viewport().get_mouse_position() - Vector2(17.0, 17.0)
		_drag_preview.visible = true
	_refresh_drag_slot_highlights()


func _cancel_hotbar_drag() -> void:
	if not _drag_active:
		return
	_drag_active = false
	_drag_category = ""
	_drag_source_vis = -1
	_drag_hover_vis = -1
	if _drag_preview != null:
		_drag_preview.visible = false
	_last_highlighted_slot = -1
	_refresh_drag_slot_highlights()


func _on_slot_gui_input(event: InputEvent, category: String, vis_idx: int) -> void:
	if not (_alt_cursor_mode or Input.is_key_pressed(KEY_ALT)):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_begin_hotbar_drag(category, vis_idx)


func _input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _drag_preview != null:
			_drag_preview.position = mm.global_position - Vector2(17.0, 17.0)
		var next_hover: int = _find_slot_at_point(_drag_category, mm.global_position)
		if next_hover != _drag_hover_vis:
			_drag_hover_vis = next_hover
			_refresh_drag_slot_highlights()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			var target_vis: int = _find_slot_at_point(_drag_category, mb.global_position)
			if target_vis < 0:
				target_vis = _drag_hover_vis
			if target_vis >= 0 and target_vis != _drag_source_vis:
				swap_hotbar_slots(_drag_category, _drag_source_vis, target_vis)
			_cancel_hotbar_drag()


func swap_hotbar_slots(category: String, vis_a: int, vis_b: int) -> bool:
	if vis_a == vis_b or vis_a < 0 or vis_b < 0:
		return false
	var active_order: Array[int] = []
	match category:
		"weapon":
			var w_cnt: int = _local_hero.weapons.size() if (_local_hero != null and is_instance_valid(_local_hero) and not _local_hero.weapons.is_empty()) else 4
			active_order = InputCmd.get_active_weapon_order(w_cnt)
		"skill":
			var s_cnt: int = 6
			if _local_hero != null and is_instance_valid(_local_hero):
				s_cnt = _local_hero.skill_manager.skill_ranks.size() if _local_hero.skill_manager != null else (6 if _local_hero.class_id == NetworkManager.CLASS_COMMANDO else 5)
			active_order = InputCmd.get_active_skill_order(s_cnt)
		"widget":
			active_order = InputCmd.get_active_widget_order(4)
		_:
			return false

	if vis_a >= active_order.size() or vis_b >= active_order.size():
		return false
	if not InputCmd.swap_logical_slots_in_order(category, active_order[vis_a], active_order[vis_b]):
		return false

	InputCmd.save_hotkeys_to_config(hotkeys_config_path)
	_last_highlighted_slot = -1
	_last_ammo_key = ""
	_refresh_hotbar_icons()
	_refresh_slot_cooldowns_immediate()
	_refresh_drag_slot_highlights()
	return true


func is_mortar_targeting_active() -> bool:
	return _mortar_targeting_active


func set_mortar_targeting_mode(active: bool, callback: Callable = Callable(), notify_cancel: bool = true) -> void:
	var was_active: bool = _mortar_targeting_active
	_mortar_targeting_active = active
	_mortar_target_callback = callback if active else Callable()
	if was_active and not active and notify_cancel:
		NetworkManager.send_mortar_cancel()
	if active:
		_cancel_hotbar_drag()
	if _mortar_banner_lbl != null:
		_mortar_banner_lbl.visible = active
	if _minimap != null:
		_minimap.mortar_active = active
		_minimap.hover_local_pos = Vector2(-1.0, -1.0)
		if active:
			_minimap.anchor_left = 0.5
			_minimap.anchor_right = 0.5
			_minimap.anchor_top = 0.5
			_minimap.anchor_bottom = 0.5
			_minimap.custom_minimum_size = Vector2(420.0, 420.0)
			_minimap.offset_left = -210.0
			_minimap.offset_right = 210.0
			_minimap.offset_top = -210.0
			_minimap.offset_bottom = 210.0
			_minimap.size = Vector2(420.0, 420.0)
			_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			_minimap.anchor_left = 1.0
			_minimap.anchor_right = 1.0
			_minimap.anchor_top = 0.0
			_minimap.anchor_bottom = 0.0
			_minimap.custom_minimum_size = Vector2(182.0, 182.0)
			_minimap.offset_left = -198.0
			_minimap.offset_right = -16.0
			_minimap.offset_top = 12.0
			_minimap.offset_bottom = 194.0
			_minimap.size = Vector2(182.0, 182.0)
			_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_minimap.queue_redraw()
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif not _alt_cursor_mode and not Input.is_key_pressed(KEY_ALT) and not DisplayServer.get_name().contains("headless"):
		var menu_open: bool = false
		if is_inside_tree():
			for m in get_tree().get_nodes_in_group("class_select_menus"):
				if m is CanvasLayer and (m as CanvasLayer).visible:
					menu_open = true
					break
		if not menu_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_minimap_mortar_clicked(local_pos: Vector2) -> void:
	if not _mortar_targeting_active or _minimap == null:
		return
	var world_pos: Vector3 = _minimap.minimap_to_world(local_pos)
	var cb: Callable = _mortar_target_callback
	set_mortar_targeting_mode(false, Callable(), false)
	if cb.is_valid():
		cb.call(world_pos)


func _refresh_widget_hotbar_icons() -> void:
	if _widget_slot_icons.is_empty():
		return
	var widget_order: Array[int] = InputCmd.get_active_widget_order(4)
	for vis_w in range(mini(widget_order.size(), _widget_slot_icons.size())):
		var logical_w: int = widget_order[vis_w]
		var w_key: String = "icon_widget_%d" % logical_w
		_widget_slot_icons[vis_w].texture = CartoonAssets.get_texture(w_key)
		if vis_w < _widget_slot_bgs.size():
			var w_entry: Dictionary = SkillCatalog.get_entry_by_key(w_key)
			if not w_entry.is_empty():
				_widget_slot_bgs[vis_w].tooltip_text = "%s (%s) — %s\nRecarga: %s | Duração: %s | Área: %s\n%s" % [
					str(w_entry.get("name", "")),
					str(w_entry.get("category", "")),
					str(w_entry.get("effect_stats", "")),
					str(w_entry.get("cooldown", "")),
					str(w_entry.get("duration", "")),
					str(w_entry.get("area", "")),
					str(w_entry.get("description", "")),
				]
			else:
				_widget_slot_bgs[vis_w].tooltip_text = ""


func _refresh_slot_cooldowns_immediate() -> void:
	if _local_hero == null or not is_instance_valid(_local_hero):
		return
	if _local_hero.skill_manager == null or not (_local_hero.skill_manager is SkillManager):
		return
	var sm := _local_hero.skill_manager as SkillManager
	var num_skills: int = sm.skill_ranks.size()
	var skill_order: Array[int] = InputCmd.get_active_skill_order(num_skills)
	for vis_s in range(_skill_slot_boxes.size()):
		var has_slot: bool = vis_s < skill_order.size()
		if _skill_slot_boxes[vis_s].visible != has_slot:
			_skill_slot_boxes[vis_s].visible = has_slot
		if not has_slot:
			continue
		var logical_s: int = skill_order[vis_s]
		var rank: int = sm.skill_ranks[logical_s]
		var cd: float = sm.skill_cooldowns[logical_s]
		var target_cd_txt: String
		var target_col: Color
		if rank <= 0:
			target_col = Color(0.45, 0.45, 0.45, 0.55)
			target_cd_txt = ""
		elif cd > 0.0:
			target_col = Color(0.55, 0.55, 0.55, 0.72)
			target_cd_txt = "%.0fs" % ceilf(cd)
		else:
			target_col = Color.WHITE
			target_cd_txt = "R%d" % rank
		if _skill_slot_icons[vis_s].modulate != target_col:
			_skill_slot_icons[vis_s].modulate = target_col
		if _skill_slot_cd_lbls[vis_s].text != target_cd_txt:
			_skill_slot_cd_lbls[vis_s].text = target_cd_txt

	var widget_order: Array[int] = InputCmd.get_active_widget_order(4)
	for vis_w in range(mini(widget_order.size(), _widget_slot_icons.size())):
		var logical_w: int = widget_order[vis_w]
		var wcd: float = sm.widget_cooldowns[logical_w]
		var w_txt: String = "%.0fs" % ceilf(wcd) if wcd > 0.0 else ""
		var w_col: Color = Color(0.55, 0.55, 0.55, 0.72) if wcd > 0.0 else Color.WHITE
		if _widget_slot_icons[vis_w].modulate != w_col:
			_widget_slot_icons[vis_w].modulate = w_col
		if _widget_slot_cd_lbls[vis_w].text != w_txt:
			_widget_slot_cd_lbls[vis_w].text = w_txt


func _refresh_hotbar_icons() -> void:
	_update_hotkey_label_texts()
	_refresh_widget_hotbar_icons()
	if _local_hero == null or not is_instance_valid(_local_hero):
		_local_hero = null
		_last_hotbar_class_id = -1
		_hide_local_hud_overlays()
		return
	if _skill_slot_icons.is_empty() or _weapon_slot_boxes.is_empty():
		return
	_last_hotbar_class_id = _local_hero.class_id
	var weapon_order: Array[int] = InputCmd.get_active_weapon_order(_local_hero.weapons.size())
	for vis_w in range(4):
		if vis_w < weapon_order.size():
			var logical_w: int = weapon_order[vis_w]
			_weapon_slot_boxes[vis_w].visible = true
			var w: WeaponBase = _local_hero.weapons[logical_w] as WeaponBase
			if w != null:
				var w_arch: int = clampi(w.archetype, 0, 2)
				_weapon_slot_icons[vis_w].texture = CartoonAssets.get_texture("icon_weapon_%d_%d" % [w.weapon_kind, w_arch])
				if not w.fired.is_connected(_on_local_weapon_fired):
					w.fired.connect(_on_local_weapon_fired)
				if not _bound_weapon_signals.has(w):
					_bound_weapon_signals.append(w)
		else:
			_weapon_slot_boxes[vis_w].visible = false

	var num_skills: int = (
		_local_hero.skill_manager.skill_ranks.size()
		if _local_hero.skill_manager != null
		else (6 if _local_hero.class_id == NetworkManager.CLASS_COMMANDO else 5)
	)
	var skill_order: Array[int] = InputCmd.get_active_skill_order(num_skills)
	for vis_s in range(_skill_slot_icons.size()):
		if vis_s < skill_order.size():
			var logical_s: int = skill_order[vis_s]
			var icon_key: String = "icon_skill_%d_%d" % [_local_hero.class_id, logical_s]
			_skill_slot_icons[vis_s].texture = CartoonAssets.get_texture(icon_key)
			if vis_s < _skill_slot_bgs.size():
				var entry: Dictionary = SkillCatalog.get_entry_by_key(icon_key)
				if not entry.is_empty():
					_skill_slot_bgs[vis_s].tooltip_text = "%s (%s) — %s\nRecarga: %s | Duração: %s | Área: %s\n%s" % [
						str(entry.get("name", "")),
						str(entry.get("category", "")),
						str(entry.get("effect_stats", "")),
						str(entry.get("cooldown", "")),
						str(entry.get("duration", "")),
						str(entry.get("area", "")),
						str(entry.get("description", "")),
					]
				else:
					_skill_slot_bgs[vis_s].tooltip_text = ""
		elif vis_s < _skill_slot_bgs.size():
			_skill_slot_bgs[vis_s].tooltip_text = ""


func _process(delta: float) -> void:
	var alt_key_now: bool = Input.is_key_pressed(KEY_ALT)
	if alt_key_now != _prev_alt_key_held:
		_prev_alt_key_held = alt_key_now
		_alt_cursor_mode = alt_key_now
		if not _alt_cursor_mode:
			_cancel_hotbar_drag()
	if _alt_hint_lbl != null:
		_alt_hint_lbl.visible = _alt_cursor_mode and not _mortar_targeting_active
	if _hotbar_alt_hint_lbl != null:
		_hotbar_alt_hint_lbl.visible = not _alt_cursor_mode and not _mortar_targeting_active and (_local_hero == null or _local_hero.current_vehicle_id < 0)

	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= delta
		if _hitmarker_timer <= 0.0:
			_hitmarker_timer = 0.0
	var hm_active: bool = (_hitmarker_timer > 0.0)
	if _hitmarker_lbl != null and _hitmarker_lbl.visible != hm_active:
		_hitmarker_lbl.visible = hm_active
	if _hitmarker_container != null and _hitmarker_container.visible != hm_active:
		_hitmarker_container.visible = hm_active

	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
		if _damage_arc != null:
			_damage_arc.flash_alpha = clampf(_damage_flash_timer / 0.45, 0.0, 1.0) * 0.92
			_damage_arc.queue_redraw()
	elif _damage_arc != null and _damage_arc.flash_alpha > 0.0:
		_damage_arc.flash_alpha = 0.0
		_damage_arc.queue_redraw()

	var ping_ms: int = int(NetworkManager.ema_rtt_ms)
	var sim_ms: int = int(roundf(NetworkManager.sim_latency_ms * 2.0))
	if ping_ms != _last_ping_ms or sim_ms != _last_sim_lat_ms:
		_last_ping_ms = ping_ms
		_last_sim_lat_ms = sim_ms
		_ping_lbl.text = "Ping: %dms (Sim %dms) | F8: Lag | M: Música | ESC: Menu" % [ping_ms, sim_ms]

	if _conquest != null:
		if _conquest.royal_tickets != _last_royal_tickets:
			_last_royal_tickets = _conquest.royal_tickets
			_royal_ticket_lbl.text = "%d" % _conquest.royal_tickets
		if _conquest.national_tickets != _last_national_tickets:
			_last_national_tickets = _conquest.national_tickets
			_national_ticket_lbl.text = "%d" % _conquest.national_tickets
		var r_mult: int = _conquest.get_team_kill_multiplier(NetworkManager.TEAM_ROYAL)
		if r_mult != _last_royal_mult:
			_last_royal_mult = r_mult
			_royal_mult_lbl.text = "%dx" % r_mult if r_mult > 0 else "0x"
		var n_mult: int = _conquest.get_team_kill_multiplier(NetworkManager.TEAM_NATIONAL)
		if n_mult != _last_national_mult:
			_last_national_mult = n_mult
			_national_mult_lbl.text = "%dx" % n_mult if n_mult > 0 else "0x"

		for i in range(_flag_pips.size()):
			if i < _conquest.capture_points.size():
				if not _flag_pips[i].visible:
					_flag_pips[i].visible = true
				var owner_t: int = _conquest.capture_points[i].owner_team
				if i >= _last_flag_owners.size() or _last_flag_owners[i] != owner_t:
					if i < _last_flag_owners.size():
						_last_flag_owners[i] = owner_t
					if owner_t == NetworkManager.TEAM_ROYAL:
						_flag_pips[i].color = Color(0.22, 0.55, 1.0)
					elif owner_t == NetworkManager.TEAM_NATIONAL:
						_flag_pips[i].color = Color(0.92, 0.22, 0.22)
					else:
						_flag_pips[i].color = Color(0.85, 0.85, 0.85)
			else:
				if _flag_pips[i].visible:
					_flag_pips[i].visible = false
				if i < _last_flag_owners.size():
					_last_flag_owners[i] = -99

	if _local_hero == null or not is_instance_valid(_local_hero):
		_local_hero = null
		_hide_local_hud_overlays()
		if _minimap != null:
			_minimap.queue_redraw()
		return

	if _mortar_targeting_active and (_local_hero.is_defeated or _local_hero.current_vehicle_id >= 0):
		set_mortar_targeting_mode(false)

	if _poison_tint_rect != null:
		var is_poisoned: bool = (_local_hero.active_flags & NetSerializer.SNAP_POISONED) != 0 and not _local_hero.is_defeated
		_poison_tint_rect.visible = is_poisoned
		if is_poisoned:
			_poison_pulse_time += delta
			var alpha: float = 0.22 + 0.10 * (0.5 + 0.5 * sin(_poison_pulse_time * 5.0))
			_poison_tint_rect.color = Color(0.16, 0.72, 0.22, alpha)

	if _prev_hp_observed > _local_hero.hp:
		trigger_damage_flash()
	_prev_hp_observed = _local_hero.hp

	# Update Portrait sprite
	var t_prefix: String = "royal" if _local_hero.team == NetworkManager.TEAM_ROYAL else "national"
	var p_key: String = "portrait_%s_%d" % [t_prefix, clampi(_local_hero.class_id, 0, 4)]
	if p_key != _last_portrait_key:
		_last_portrait_key = p_key
		_portrait_tex.texture = CartoonAssets.get_texture(p_key)
		_refresh_hotbar_icons()
	elif _local_hero.class_id != _last_hotbar_class_id:
		_refresh_hotbar_icons()

	if _local_hero.hp != _last_hp_val:
		_last_hp_val = _local_hero.hp
		_hp_value_lbl.text = "%d" % _local_hero.hp
	if _local_hero.shield != _last_shield_val:
		_last_shield_val = _local_hero.shield
		_shield_value_lbl.text = ("+%d ESCUDO" % _local_hero.shield) if _local_hero.shield > 0 else ""

	var is_scoped: bool = _local_hero.is_scoping or (_local_hero.hero_camera != null and _local_hero.hero_camera.is_scoped)
	if _scope_overlay != null:
		_scope_overlay.visible = is_scoped
		if _scope_overlay.visible:
			_scope_overlay.queue_redraw()
	if _crosshair != null:
		_crosshair.visible = not is_scoped and not _mortar_targeting_active
		_crosshair_bloom = maxf(0.0, _crosshair_bloom - 26.0 * delta)
		var speed_horiz: float = Vector2(_local_hero.velocity.x, _local_hero.velocity.z).length()
		var move_bloom: float = clampf(speed_horiz / 8.0, 0.0, 1.5) * 6.0
		var air_bloom: float = 6.0 if (not _local_hero.is_on_floor() and _local_hero.current_vehicle_id < 0) else 0.0
		var crouch_bonus: float = -2.0 if _local_hero.is_crouching else 0.0
		var weapon_spread_bonus: float = 0.0
		if not _local_hero.weapons.is_empty():
			var w_slot: int = clampi(_local_hero.selected_weapon_slot, 0, _local_hero.weapons.size() - 1)
			var active_w: WeaponBase = _local_hero.weapons[w_slot] as WeaponBase
			if active_w != null:
				var has_frenzy: bool = _local_hero.status_effects != null and _local_hero.status_effects.has_method("has_frenzy_fire") and _local_hero.status_effects.has_frenzy_fire()
				weapon_spread_bonus = clampf(active_w.spread_rad * active_w.get_current_spread_mult(is_scoped, has_frenzy, _local_hero.is_crouching) * 140.0, 0.0, 9.0)
		var recoil_bloom: float = _crosshair_bloom + _local_hero._weapon_recoil_anim * 5.0
		var target_spread: float = clampf(6.0 + weapon_spread_bonus + move_bloom + air_bloom + crouch_bonus + recoil_bloom, 4.0, 28.0)
		_crosshair_spread_px = lerpf(_crosshair_spread_px, target_spread, minf(1.0, 18.0 * delta))
		_apply_crosshair_spread(_crosshair_spread_px)

	_update_floating_damage_numbers(delta)

	if _defeat_lbl != null:
		_defeat_lbl.visible = _local_hero.is_defeated
		if _local_hero.is_defeated:
			_defeat_lbl.text = "DERROTADO! Renascendo em %.1fs..." % maxf(0.0, _local_hero.defeat_timer)

	if _parachute_lbl != null:
		var show_para: bool = _local_hero.can_open_parachute()
		_parachute_lbl.visible = show_para
		if show_para:
			_parachute_lbl.text = "[ESPAÇO] Fechar Paraquedas" if _local_hero.is_parachuting else "[ESPAÇO] Abrir Paraquedas"

	# Update Active Weapon slot highlight & Ammo counter (via weapon_slot_order)
	if not _local_hero.weapons.is_empty():
		var slot: int = clampi(_local_hero.selected_weapon_slot, 0, _local_hero.weapons.size() - 1)
		if slot != _last_highlighted_slot and not (_drag_active and _drag_category == "weapon"):
			_last_highlighted_slot = slot
			var w_order: Array[int] = InputCmd.get_active_weapon_order(_local_hero.weapons.size())
			var active_vis_w: int = w_order.find(slot)
			for vis_i in range(mini(w_order.size(), _weapon_slot_bgs.size())):
				_weapon_slot_bgs[vis_i].add_theme_stylebox_override("panel", _make_slot_style(vis_i == active_vis_w))
		var w: WeaponBase = _local_hero.weapons[slot] as WeaponBase
		if w != null:
			var ammo_key: String = "%d|%s|%s|%s|%d" % [slot, w.weapon_name, str(w.is_melee), str(w.is_reloading), w.ammo_in_mag]
			if ammo_key != _last_ammo_key:
				_last_ammo_key = ammo_key
				if w.is_melee:
					_ammo_value_lbl.text = "∞"
					var melee_tag: String = "Faca"
					if w.weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE:
						melee_tag = "Corpo a Corpo" if w.caber_spent else "Explosivo"
					_weapon_name_lbl.text = "%s (%s)" % [w.weapon_name, melee_tag]
				elif w.is_reloading:
					_ammo_value_lbl.text = "..."
					_weapon_name_lbl.text = "%s | RECARREGANDO" % w.weapon_name
				else:
					_ammo_value_lbl.text = "%d" % w.ammo_in_mag
					_weapon_name_lbl.text = "%s | ∞" % w.weapon_name

	# Update RPG Portrait ring, Skills & Widgets (via skill_slot_order & widget_slot_order)
	if _local_hero.skill_manager != null and _local_hero.skill_manager is SkillManager:
		var sm := _local_hero.skill_manager as SkillManager
		var xp_next: int = maxi(1, sm.get_xp_for_next_level())
		if sm.xp != _last_gauge_xp or sm.level != _last_gauge_level or _local_hero.team != _last_gauge_team:
			_last_gauge_xp = sm.xp
			_last_gauge_level = sm.level
			_last_gauge_team = _local_hero.team
			_level_lbl.text = "%d" % sm.level
			_hero_pts_lbl.text = ""
			_hero_pts_lbl.visible = false
			_portrait_gauge.team_id = _local_hero.team
			_portrait_gauge.xp_ratio = float(sm.xp) / float(xp_next)
			_portrait_gauge.queue_redraw()
			_mastery_lbl.text = "Combat Mastery %d\nScore: %d/%d" % [sm.level, sm.xp, xp_next]

		_refresh_slot_cooldowns_immediate()

	_update_interact_prompt()
	_update_vehicle_hp_panel(delta)
	_update_sixth_sense_markers()
	if _minimap != null:
		_minimap.queue_redraw()


func spawn_damage_number(world_pos: Vector3, amount: int, is_crit: bool = false, style_tag: String = "") -> void:
	if _damage_numbers_layer == null or amount <= 0:
		return
	while _floating_dmgs.size() >= 24:
		var oldest: Dictionary = _floating_dmgs.pop_front()
		var old_lbl := oldest.get("label", null) as Label
		if is_instance_valid(old_lbl):
			old_lbl.queue_free()

	var col := Color(1.0, 0.94, 0.28)
	var font_sz: int = 23
	var text_str: String = "-%d" % amount
	if style_tag == "burn":
		col = Color(1.0, 0.56, 0.16)
		font_sz = 18
		text_str = "-%d FOGO" % amount
	elif style_tag == "poison":
		col = Color(0.42, 0.96, 0.36)
		font_sz = 18
		text_str = "-%d VENENO" % amount
	elif style_tag == "vehicle":
		col = Color(0.55, 0.88, 1.0) if not is_crit else Color(1.0, 0.42, 0.18)
		font_sz = 26 if is_crit else 22
		text_str = "-%d!" % amount if is_crit else "-%d" % amount
	elif is_crit:
		col = Color(1.0, 0.28, 0.14)
		font_sz = 30
		text_str = "-%d!" % amount

	var lbl := Label.new()
	lbl.text = text_str
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(lbl, font_sz, col)
	lbl.pivot_offset = Vector2(36.0, 16.0)
	lbl.scale = Vector2.ONE * (1.42 if is_crit else 1.24)
	_damage_numbers_layer.add_child(lbl)

	_floating_dmgs.append({
		"world_pos": world_pos + Vector3(randf_range(-0.22, 0.22), 0.18, randf_range(-0.22, 0.22)),
		"offset": Vector2(randf_range(-14.0, 14.0), -10.0),
		"vel": Vector2(randf_range(-24.0, 24.0), -82.0 if not is_crit else -105.0),
		"age": 0.0,
		"dur": 0.90,
		"label": lbl,
	})


func _update_floating_damage_numbers(delta: float) -> void:
	if _floating_dmgs.is_empty():
		return
	var cam: Camera3D = null
	if _local_hero != null and _local_hero.hero_camera != null:
		cam = _local_hero.hero_camera.camera
	var keep: Array[Dictionary] = []
	for entry in _floating_dmgs:
		var lbl := entry["label"] as Label
		if not is_instance_valid(lbl):
			continue
		var age: float = float(entry["age"]) + delta
		var dur: float = float(entry["dur"])
		if age >= dur or cam == null:
			lbl.queue_free()
			continue
		entry["age"] = age
		var vel: Vector2 = entry["vel"]
		vel.y += 115.0 * delta
		entry["vel"] = vel
		var offset: Vector2 = entry["offset"] + vel * delta
		entry["offset"] = offset
		var wp: Vector3 = entry["world_pos"]
		if cam.is_position_behind(wp):
			lbl.visible = false
		else:
			lbl.visible = true
			var sp: Vector2 = cam.unproject_position(wp)
			lbl.position = sp + offset - Vector2(32.0, 14.0)
		var t_norm: float = age / dur
		lbl.scale = lbl.scale.lerp(Vector2.ONE, minf(1.0, 12.0 * delta))
		lbl.modulate.a = clampf(1.0 - maxf(0.0, (t_norm - 0.55) / 0.45), 0.0, 1.0)
		keep.append(entry)
	_floating_dmgs = keep


func _update_interact_prompt() -> void:
	if _local_hero == null or _interact_lbl == null:
		return
	var next_text: String = ""
	if _local_hero.current_vehicle_id >= 0:
		next_text = "[E] Sair do Veículo"
	else:
		for v in _vehicles_ref:
			if v != null and not v.is_destroyed and v.global_position.distance_to(_local_hero.global_position) <= 5.5:
				next_text = "[E] Entrar no Veículo (HP %d)" % v.hp
				break
	if next_text != _last_interact_text:
		_last_interact_text = next_text
		_interact_lbl.text = next_text


func _update_vehicle_hp_panel(delta: float) -> void:
	if _veh_hp_panel == null:
		return
	if _local_hero == null or _local_hero.is_defeated:
		_veh_hp_panel.visible = false
		if _seat_diagram_panel != null:
			_seat_diagram_panel.visible = false
		_reset_seat_diagram_cache()
		_last_hud_vehicle_id = -1
		return

	var target_v: VehicleBase = null
	var seat_text: String = ""
	if _local_hero.current_vehicle_id >= 0:
		for v in _vehicles_ref:
			if v != null and not v.is_destroyed and v.id == _local_hero.current_vehicle_id:
				target_v = v
				var seat: VehicleBase.SeatSlot = v.get_seat(_local_hero.current_seat_index)
				if seat != null:
					seat_text = get_seat_display_name(seat.seat_type, v.vehicle_type)
				break
	elif _local_hero.is_inside_tree():
		var best_dist: float = 8.5
		for v in _vehicles_ref:
			if v != null and not v.is_destroyed and v.is_inside_tree():
				var d: float = v.global_position.distance_to(_local_hero.global_position)
				if d <= best_dist:
					best_dist = d
					target_v = v

	if target_v == null:
		_veh_hp_panel.visible = false
		if _seat_diagram_panel != null:
			_seat_diagram_panel.visible = false
		_reset_seat_diagram_cache()
		_last_hud_vehicle_id = -1
		return

	_veh_hp_panel.visible = true
	if target_v.vehicle_type != _last_veh_name_type:
		_last_veh_name_type = target_v.vehicle_type
		_veh_name_lbl.text = get_vehicle_display_name(target_v.vehicle_type)
	if seat_text != _last_veh_seat_txt:
		_last_veh_seat_txt = seat_text
		_veh_seat_lbl.text = seat_text
	if target_v.hp != _last_veh_hp or target_v.max_hp != _last_veh_max_hp:
		_last_veh_hp = target_v.hp
		_last_veh_max_hp = target_v.max_hp
		_veh_hp_lbl.text = "HP: %d / %d" % [target_v.hp, target_v.max_hp]
	_update_vehicle_seat_diagram(target_v)

	var ratio: float = clampf(float(target_v.hp) / float(maxi(1, target_v.max_hp)), 0.0, 1.0)
	if _last_hud_vehicle_id != target_v.id:
		_last_hud_vehicle_id = target_v.id
		_veh_hp_bar_fill.anchor_right = ratio
	else:
		_veh_hp_bar_fill.anchor_right = lerpf(_veh_hp_bar_fill.anchor_right, ratio, minf(1.0, 14.0 * delta))

	if ratio > 0.55:
		_veh_hp_bar_fill.color = Color(0.24, 0.84, 0.34)
	elif ratio >= 0.25:
		_veh_hp_bar_fill.color = Color(0.96, 0.72, 0.16)
	else:
		_veh_pulse_time += delta
		var pulse: float = 0.5 + 0.5 * sin(_veh_pulse_time * 12.0)
		_veh_hp_bar_fill.color = Color(0.95, 0.14 + 0.22 * pulse, 0.12 + 0.12 * pulse)


func _update_vehicle_seat_diagram(target_v: VehicleBase) -> void:
	if _seat_diagram_panel == null or _local_hero == null:
		return
	var inside_this: bool = (_local_hero.current_vehicle_id == target_v.id)
	_seat_diagram_panel.visible = inside_this
	if not inside_this:
		_reset_seat_diagram_cache()
		return
	if _seat_style_mine == null:
		_init_seat_styles()
	if _last_seat_states.size() != _seat_slot_buttons.size():
		_last_seat_states.resize(_seat_slot_buttons.size())

	var seat_count: int = target_v.seats.size()
	for i in range(_seat_slot_buttons.size()):
		var btn: Button = _seat_slot_buttons[i]
		if i >= seat_count:
			if btn.visible:
				btn.visible = false
			_last_seat_states[i] = "hidden"
			continue
		if not btn.visible:
			btn.visible = true
		var s: VehicleBase.SeatSlot = target_v.seats[i]
		var role_txt: String = get_seat_display_name(s.seat_type, target_v.vehicle_type)
		var is_mine: bool = (s.occupant_id == _local_hero.entity_id)
		var is_occupied: bool = (s.occupant_id >= 0)
		var state_txt: String = "VOCÊ" if is_mine else ("OCUPADO" if is_occupied else "LIVRE")
		var btn_text: String = "[F%d] %s (%s)" % [i + 1, role_txt.left(5), state_txt]
		var style_tag: String = "M" if is_mine else ("R" if (is_occupied and target_v.team == NetworkManager.TEAM_ROYAL) else ("N" if is_occupied else "F"))
		var cache_key: String = "%d|%s|%s" % [target_v.id, style_tag, btn_text]
		if _last_seat_states[i] == cache_key:
			continue
		_last_seat_states[i] = cache_key

		btn.text = btn_text
		_seat_slot_labels[i].text = btn_text
		var sb: StyleBoxFlat
		var font_col: Color
		if is_mine:
			sb = _seat_style_mine
			font_col = Color(0.06, 0.05, 0.02)
		elif is_occupied:
			sb = _seat_style_occupied_royal if target_v.team == NetworkManager.TEAM_ROYAL else _seat_style_occupied_national
			font_col = Color.WHITE
		else:
			sb = _seat_style_free
			font_col = Color(0.86, 0.90, 0.96)
		btn.add_theme_color_override("font_color", font_col)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)


func _place_sixth_sense_marker(used_count: int, screen_p: Vector2, sym: String, col: Color) -> void:
	var marker: Label
	if used_count < _marker_pool.size():
		marker = _marker_pool[used_count]
	else:
		marker = Label.new()
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sixth_sense_layer.add_child(marker)
		_marker_pool.append(marker)
	if marker.text != sym:
		marker.text = sym
	marker.modulate = col
	marker.position = screen_p - Vector2(6.0, 10.0)
	if not marker.visible:
		marker.visible = true


func _update_sixth_sense_markers() -> void:
	if _sixth_sense_layer == null:
		return
	if _local_hero == null or _local_hero.hero_camera == null or _local_hero.hero_camera.camera == null:
		_hide_all_sixth_sense_markers()
		return
	var pulse_alpha: float = 0.52 + 0.48 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008))
	var cam: Camera3D = _local_hero.hero_camera.camera
	var used_count: int = 0

	for id_key in _heroes_ref.keys():
		var enemy: HeroCharacter = _heroes_ref[id_key]
		if enemy == null or enemy.is_defeated or enemy.team == _local_hero.team:
			continue
		var enemy_marked: bool = (enemy.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0
		var enemy_sensed: bool = StatusEffectContainer.is_enemy_sensed_by_team(enemy, _local_hero.team, _heroes_ref, _local_hero)
		if not enemy_sensed and not enemy_marked:
			continue
		var world_p: Vector3 = enemy.global_position + Vector3(0.0, 2.2, 0.0)
		if cam.is_position_behind(world_p):
			continue
		var screen_p: Vector2 = cam.unproject_position(world_p)
		var sym: String = "◎" if enemy_marked else "◆"
		var col := Color(1.0, 0.22, 0.22, 1.0 if enemy_marked else pulse_alpha)
		_place_sixth_sense_marker(used_count, screen_p, sym, col)
		used_count += 1

	for veh in _vehicles_ref:
		if veh == null or veh.is_destroyed:
			continue
		if veh.team == _local_hero.team:
			continue
		var veh_marked: bool = veh.is_marked
		var veh_sensed: bool = veh.team >= 0 and StatusEffectContainer.is_pos_sensed_by_team(veh.global_position, _local_hero.team, _heroes_ref, _local_hero)
		if not veh_marked and not veh_sensed:
			continue
		var v_world_p: Vector3 = veh.global_position + Vector3(0.0, 2.6, 0.0)
		if cam.is_position_behind(v_world_p):
			continue
		var v_screen_p: Vector2 = cam.unproject_position(v_world_p)
		var v_sym: String = "◎" if veh_marked else "◆"
		var v_col := Color(1.0, 0.22, 0.22, 1.0 if veh_marked else pulse_alpha)
		_place_sixth_sense_marker(used_count, v_screen_p, v_sym, v_col)
		used_count += 1

	for k in range(used_count, _marker_pool.size()):
		if _marker_pool[k].visible:
			_marker_pool[k].visible = false
