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

		# Bullet-drop holdover mil-dot elevation hash ticks below center reticle
		var holdover_drops: Array[float] = [24.0, 52.0, 88.0]
		var holdover_widths: Array[float] = [9.0, 13.0, 17.0]
		var hold_col := Color(0.95, 0.42, 0.20, 0.70)
		for idx in range(holdover_drops.size()):
			var dy: float = holdover_drops[idx]
			var hw: float = holdover_widths[idx]
			if dy < radius * 0.85:
				draw_line(Vector2(center.x - hw, center.y + dy), Vector2(center.x + hw, center.y + dy), wire_col, 1.8)
				draw_circle(Vector2(center.x, center.y + dy), 2.0, hold_col)

		# Razor pinpoint glowing center reticle dot
		draw_circle(center, 3.2, Color(1.0, 0.30, 0.14, 0.98))
		draw_circle(center, 1.4, Color(1.0, 0.92, 0.55, 1.0))


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

var _skill_slot_bgs: Array[PanelContainer] = []
var _skill_slot_icons: Array[TextureRect] = []
var _skill_slot_cd_lbls: Array[Label] = []
var _upgrade_buttons: Array[Button] = []

var _widget_slot_icons: Array[TextureRect] = []
var _widget_slot_cd_lbls: Array[Label] = []

var _mastery_lbl: Label
var _crosshair: Control
var _scope_overlay: Control
var _hitmarker_lbl: Label
var _parachute_lbl: Label
var _interact_lbl: Label
var _defeat_lbl: Label
var _killfeed_lbl: Label
var _sixth_sense_layer: Control
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

var _hitmarker_timer: float = 0.0
var _damage_flash_timer: float = 0.0
var _prev_hp_observed: int = -1
var _killfeed_lines: Array[String] = []
var _last_portrait_key: String = ""

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
		_:
			return "VEÍCULO"


static func get_seat_display_name(seat_type: int) -> String:
	match seat_type:
		VehicleBase.SeatType.DRIVER:
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
	_build_hud()


func bind_context(p_conquest: ConquestManager, p_vehicles: Array[VehicleBase], p_heroes: Dictionary) -> void:
	_conquest = p_conquest
	_vehicles_ref = p_vehicles
	_heroes_ref = p_heroes


func set_local_hero(hero: HeroCharacter) -> void:
	_local_hero = hero
	_prev_hp_observed = hero.hp if hero != null else -1
	_last_portrait_key = ""
	_refresh_hotbar_icons()


func show_hitmarker(is_headshot: bool) -> void:
	_hitmarker_timer = 0.16
	if _hitmarker_lbl != null:
		_hitmarker_lbl.visible = true
		_hitmarker_lbl.modulate = Color(1.0, 0.2, 0.1) if is_headshot else Color.WHITE


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


func _make_slot_style(highlighted: bool) -> StyleBoxFlat:
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
	return sb


func _build_hud() -> void:
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

	# 4 Flag ownership pips neatly beneath the scoreboard
	var pips_hbox := HBoxContainer.new()
	pips_hbox.position = Vector2(180.0, 74.0)
	pips_hbox.size = Vector2(160.0, 14.0)
	pips_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_hbox.add_theme_constant_override("separation", 10)
	pips_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_anchor.add_child(pips_hbox)

	for i in range(4):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 10)
		pip.color = Color(0.85, 0.85, 0.85)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	br_hbox.offset_left = -280.0
	br_hbox.offset_top = -82.0
	br_hbox.offset_right = -20.0
	br_hbox.offset_bottom = -14.0
	br_hbox.alignment = BoxContainer.ALIGNMENT_END
	br_hbox.add_theme_constant_override("separation", 10)
	br_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br_hbox)

	var ammo_vbox := VBoxContainer.new()
	ammo_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
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
	_ammo_icon_tex.custom_minimum_size = Vector2(36, 56)
	_ammo_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ammo_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ammo_icon_tex.texture = CartoonAssets.get_texture("icon_ammo")
	_ammo_icon_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	br_hbox.add_child(_ammo_icon_tex)

	# 5. Bottom-Center: Transparent Hotbar (Weapons 1..4, Skills 5..9, Widgets 0/X/V)
	_hotbar_hbox = HBoxContainer.new()
	_hotbar_hbox.anchor_left = 0.5
	_hotbar_hbox.anchor_right = 0.5
	_hotbar_hbox.anchor_top = 1.0
	_hotbar_hbox.anchor_bottom = 1.0
	_hotbar_hbox.offset_left = -360.0
	_hotbar_hbox.offset_right = 360.0
	_hotbar_hbox.offset_top = -84.0
	_hotbar_hbox.offset_bottom = -8.0
	_hotbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hotbar_hbox.add_theme_constant_override("separation", 6)
	_hotbar_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar_hbox)

	# 4 possible Weapon slots (visible dynamically per class)
	for w_idx in range(4):
		var slot_v := VBoxContainer.new()
		slot_v.alignment = BoxContainer.ALIGNMENT_END
		slot_v.add_theme_constant_override("separation", 2)
		slot_v.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(52, 46)
		bg.add_theme_stylebox_override("panel", _make_slot_style(w_idx == 0))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_v.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(46, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_weapon_%d" % w_idx)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var k_lbl := Label.new()
		k_lbl.text = "%d" % (w_idx + 1)
		k_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(k_lbl, 13, Color(0.95, 0.95, 0.95))
		slot_v.add_child(k_lbl)

		_hotbar_hbox.add_child(slot_v)
		_weapon_slot_boxes.append(slot_v)
		_weapon_slot_bgs.append(bg)
		_weapon_slot_icons.append(icon)
		_weapon_slot_keys.append(k_lbl)

	# 5 Skill slots (5/F, 6/G, 7, 8, 9) with upgrade '+' buttons above
	var sk_keys: Array[String] = ["5/F", "6/G", "7", "8", "9"]
	for s_idx in range(5):
		var sv := VBoxContainer.new()
		sv.alignment = BoxContainer.ALIGNMENT_END
		sv.add_theme_constant_override("separation", 1)
		sv.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var upg := Button.new()
		upg.text = "+"
		upg.custom_minimum_size = Vector2(24, 18)
		upg.visible = false
		var captured: int = s_idx
		upg.pressed.connect(func() -> void: upgrade_skill_requested.emit(captured))
		sv.add_child(upg)
		_upgrade_buttons.append(upg)

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(44, 44)
		bg.add_theme_stylebox_override("panel", _make_slot_style(false))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sv.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_skill_%d" % s_idx)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var cd_lbl := Label.new()
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.text = ""
		_style_label(cd_lbl, 13, Color(1.0, 0.90, 0.30))
		bg.add_child(cd_lbl)

		var kl := Label.new()
		kl.text = sk_keys[s_idx]
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(kl, 12, Color(0.95, 0.95, 0.95))
		sv.add_child(kl)

		_hotbar_hbox.add_child(sv)
		_skill_slot_bgs.append(bg)
		_skill_slot_icons.append(icon)
		_skill_slot_cd_lbls.append(cd_lbl)

	# 3 Widget slots (Z/0, X, V)
	var wd_keys: Array[String] = ["Z/0", "X", "V"]
	for wj in range(3):
		var wv := VBoxContainer.new()
		wv.alignment = BoxContainer.ALIGNMENT_END
		wv.add_theme_constant_override("separation", 2)
		wv.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var bg := PanelContainer.new()
		bg.custom_minimum_size = Vector2(42, 42)
		bg.add_theme_stylebox_override("panel", _make_slot_style(false))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wv.add_child(bg)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = CartoonAssets.get_texture("icon_widget_%d" % wj)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(icon)

		var cd_lbl := Label.new()
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.text = ""
		_style_label(cd_lbl, 12, Color(1.0, 0.85, 0.25))
		bg.add_child(cd_lbl)

		var kl := Label.new()
		kl.text = wd_keys[wj]
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_label(kl, 12, Color(0.95, 0.95, 0.95))
		wv.add_child(kl)

		_hotbar_hbox.add_child(wv)
		_widget_slot_icons.append(icon)
		_widget_slot_cd_lbls.append(cd_lbl)

	# 6. Mid-Right: Combat Mastery / Score XP (matching Screenshot 1)
	_mastery_lbl = Label.new()
	_mastery_lbl.anchor_left = 1.0
	_mastery_lbl.anchor_right = 1.0
	_mastery_lbl.anchor_top = 0.44
	_mastery_lbl.anchor_bottom = 0.56
	_mastery_lbl.offset_left = -280.0
	_mastery_lbl.offset_right = -24.0
	_mastery_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mastery_lbl.text = "Combat Mastery 1\nScore: 0/100"
	_style_label(_mastery_lbl, 16, Color(1.0, 0.94, 0.72))
	add_child(_mastery_lbl)

	# 7. Top-Right Killfeed
	_killfeed_lbl = Label.new()
	_killfeed_lbl.anchor_left = 1.0
	_killfeed_lbl.anchor_right = 1.0
	_killfeed_lbl.offset_left = -420.0
	_killfeed_lbl.offset_right = -18.0
	_killfeed_lbl.offset_top = 12.0
	_killfeed_lbl.offset_bottom = 180.0
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
	_crosshair.anchor_top = 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	var dot := ColorRect.new()
	dot.color = Color(1.0, 1.0, 1.0, 0.92)
	dot.position = Vector2(-2, -2)
	dot.size = Vector2(4, 4)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(dot)

	_hitmarker_lbl = Label.new()
	_hitmarker_lbl.text = "X"
	_hitmarker_lbl.position = Vector2(-8, -15)
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
	_veh_hp_panel.offset_top = -132.0
	_veh_hp_panel.offset_bottom = -94.0
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


func _refresh_hotbar_icons() -> void:
	if _local_hero == null:
		if _veh_hp_panel != null:
			_veh_hp_panel.visible = false
		return
	for i in range(4):
		if i < _local_hero.weapons.size():
			_weapon_slot_boxes[i].visible = true
			var w: WeaponBase = _local_hero.weapons[i] as WeaponBase
			if w != null:
				_weapon_slot_icons[i].texture = CartoonAssets.get_texture("icon_weapon_%d" % w.weapon_kind)
		else:
			_weapon_slot_boxes[i].visible = false


func _process(delta: float) -> void:
	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= delta
		if _hitmarker_timer <= 0.0 and _hitmarker_lbl != null:
			_hitmarker_lbl.visible = false

	if _damage_flash_timer > 0.0:
		_damage_flash_timer = maxf(0.0, _damage_flash_timer - delta)
		if _damage_arc != null:
			_damage_arc.flash_alpha = clampf(_damage_flash_timer / 0.45, 0.0, 1.0) * 0.92
			_damage_arc.queue_redraw()
	elif _damage_arc != null and _damage_arc.flash_alpha > 0.0:
		_damage_arc.flash_alpha = 0.0
		_damage_arc.queue_redraw()

	_ping_lbl.text = "Ping: %dms (Sim %.0fms) | F8: Lag | M: Música | ESC: Menu" % [int(NetworkManager.ema_rtt_ms), NetworkManager.sim_latency_ms * 2.0]

	if _conquest != null:
		_royal_ticket_lbl.text = "%d" % _conquest.royal_tickets
		_national_ticket_lbl.text = "%d" % _conquest.national_tickets
		var r_mult: int = _conquest.get_team_kill_multiplier(NetworkManager.TEAM_ROYAL)
		var n_mult: int = _conquest.get_team_kill_multiplier(NetworkManager.TEAM_NATIONAL)
		_royal_mult_lbl.text = "%dx" % r_mult if r_mult > 0 else "0x"
		_national_mult_lbl.text = "%dx" % n_mult if n_mult > 0 else "0x"

		for i in range(mini(_conquest.capture_points.size(), _flag_pips.size())):
			var cp: CapturePoint = _conquest.capture_points[i]
			if cp.owner_team == NetworkManager.TEAM_ROYAL:
				_flag_pips[i].color = Color(0.22, 0.55, 1.0)
			elif cp.owner_team == NetworkManager.TEAM_NATIONAL:
				_flag_pips[i].color = Color(0.92, 0.22, 0.22)
			else:
				_flag_pips[i].color = Color(0.85, 0.85, 0.85)

	if _local_hero == null:
		if _veh_hp_panel != null:
			_veh_hp_panel.visible = false
		return

	if _prev_hp_observed > _local_hero.hp:
		trigger_damage_flash()
	_prev_hp_observed = _local_hero.hp

	# Update Portrait sprite
	var t_prefix: String = "royal" if _local_hero.team == NetworkManager.TEAM_ROYAL else "national"
	var p_key: String = "portrait_%s_%d" % [t_prefix, clampi(_local_hero.class_id, 0, 2)]
	if p_key != _last_portrait_key:
		_last_portrait_key = p_key
		_portrait_tex.texture = CartoonAssets.get_texture(p_key)
		_refresh_hotbar_icons()

	_hp_value_lbl.text = "%d" % _local_hero.hp
	_shield_value_lbl.text = ("+%d ESCUDO" % _local_hero.shield) if _local_hero.shield > 0 else ""

	if _scope_overlay != null:
		_scope_overlay.visible = _local_hero.is_scoping
		if _scope_overlay.visible:
			_scope_overlay.queue_redraw()
	if _crosshair != null:
		_crosshair.visible = not _local_hero.is_scoping

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

	# Update Active Weapon slot highlight & Ammo counter
	if not _local_hero.weapons.is_empty():
		var slot: int = clampi(_local_hero.selected_weapon_slot, 0, _local_hero.weapons.size() - 1)
		for i in range(mini(_local_hero.weapons.size(), _weapon_slot_bgs.size())):
			_weapon_slot_bgs[i].add_theme_stylebox_override("panel", _make_slot_style(i == slot))
		var w: WeaponBase = _local_hero.weapons[slot] as WeaponBase
		if w != null:
			if w.is_melee:
				_ammo_value_lbl.text = "∞"
				_weapon_name_lbl.text = "%s (Faca)" % w.weapon_name
			elif w.is_reloading:
				_ammo_value_lbl.text = "..."
				_weapon_name_lbl.text = "%s | RECARREGANDO" % w.weapon_name
			else:
				_ammo_value_lbl.text = "%d" % w.ammo_in_mag
				_weapon_name_lbl.text = "%s | ∞" % w.weapon_name

	# Update RPG Portrait ring, Skills & Widgets
	if _local_hero.skill_manager != null and _local_hero.skill_manager is SkillManager:
		var sm := _local_hero.skill_manager as SkillManager
		var xp_next: int = maxi(1, sm.get_xp_for_next_level())
		_level_lbl.text = "%d" % sm.level
		_hero_pts_lbl.text = ("★ %d Hero Pts" % sm.hero_points) if sm.hero_points > 0 else ""
		_portrait_gauge.team_id = _local_hero.team
		_portrait_gauge.xp_ratio = float(sm.xp) / float(xp_next)
		_portrait_gauge.queue_redraw()
		_mastery_lbl.text = "Combat Mastery %d\nScore: %d/%d" % [sm.level, sm.xp, xp_next]

		for i in range(5):
			var rank: int = sm.skill_ranks[i]
			var cd: float = sm.skill_cooldowns[i]
			if rank <= 0:
				_skill_slot_icons[i].modulate = Color(0.45, 0.45, 0.45, 0.55)
				_skill_slot_cd_lbls[i].text = ""
			elif cd > 0.0:
				_skill_slot_icons[i].modulate = Color(0.55, 0.55, 0.55, 0.72)
				_skill_slot_cd_lbls[i].text = "%.0fs" % ceilf(cd)
			else:
				_skill_slot_icons[i].modulate = Color.WHITE
				_skill_slot_cd_lbls[i].text = "R%d" % rank
			_upgrade_buttons[i].visible = sm.hero_points > 0 and rank < SkillManager.MAX_SKILL_RANK

		for j in range(3):
			var wcd: float = sm.widget_cooldowns[j]
			if wcd > 0.0:
				_widget_slot_icons[j].modulate = Color(0.55, 0.55, 0.55, 0.72)
				_widget_slot_cd_lbls[j].text = "%.0fs" % ceilf(wcd)
			else:
				_widget_slot_icons[j].modulate = Color.WHITE
				_widget_slot_cd_lbls[j].text = ""

	_update_interact_prompt()
	_update_vehicle_hp_panel(delta)
	_update_sixth_sense_markers()


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
	if _local_hero.current_vehicle_id >= 0:
		_interact_lbl.text = "[E] Sair do Veículo"
		return
	for v in _vehicles_ref:
		if v != null and not v.is_destroyed and v.global_position.distance_to(_local_hero.global_position) <= 5.5:
			_interact_lbl.text = "[E] Entrar no Veículo (HP %d)" % v.hp
			return
	_interact_lbl.text = ""


func _update_vehicle_hp_panel(delta: float) -> void:
	if _veh_hp_panel == null:
		return
	if _local_hero == null or _local_hero.is_defeated:
		_veh_hp_panel.visible = false
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
					seat_text = get_seat_display_name(seat.seat_type)
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
		_last_hud_vehicle_id = -1
		return

	_veh_hp_panel.visible = true
	_veh_name_lbl.text = get_vehicle_display_name(target_v.vehicle_type)
	_veh_seat_lbl.text = seat_text
	_veh_hp_lbl.text = "HP: %d / %d" % [target_v.hp, target_v.max_hp]

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


func _update_sixth_sense_markers() -> void:
	if _sixth_sense_layer == null:
		return
	for c in _sixth_sense_layer.get_children():
		c.queue_free()
	if _local_hero == null or (_local_hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) == 0:
		return
	if _local_hero.hero_camera == null or _local_hero.hero_camera.camera == null:
		return
	var cam: Camera3D = _local_hero.hero_camera.camera
	for id_key in _heroes_ref.keys():
		var enemy: HeroCharacter = _heroes_ref[id_key]
		if enemy == null or enemy.is_defeated or enemy.team == _local_hero.team:
			continue
		var world_p: Vector3 = enemy.global_position + Vector3(0.0, 2.2, 0.0)
		if cam.is_position_behind(world_p):
			continue
		var screen_p: Vector2 = cam.unproject_position(world_p)
		var marker := Label.new()
		marker.text = "◆"
		marker.modulate = Color(1.0, 0.25, 0.25)
		marker.position = screen_p - Vector2(6, 10)
		_sixth_sense_layer.add_child(marker)
