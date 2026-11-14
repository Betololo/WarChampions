class_name HUDController
extends CanvasLayer

## Clean Battlefield Heroes HUD layout:
## - Top Center: 50-Ticket scoreboard + 4 Capture Points + Flag Multiplier badge
## - Bottom Left: Robust HP + Blue Shield + RPG Level/XP + Weapon Ammo/Infinity
## - Bottom Center: 5 Skills (1-5) + 3 Widgets (6/7/8) with cooldowns & '+' Hero Point upgrades
## - Center: Crosshair, Hitmarker, Sniper Scope Overlay, Vehicle Interact prompt, Killfeed & Respawn notice.

signal upgrade_skill_requested(slot_idx: int)
signal toggle_menu_requested()

var _top_bar: PanelContainer
var _royal_ticket_lbl: Label
var _national_ticket_lbl: Label
var _multiplier_lbl: Label
var _flag_badges: Array[ColorRect] = []

var _hp_bar: ProgressBar
var _shield_bar: ProgressBar
var _hp_text_lbl: Label
var _level_lbl: Label
var _xp_bar: ProgressBar
var _weapon_lbl: Label
var _ping_lbl: Label

var _skill_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []
var _widget_buttons: Array[Button] = []

var _crosshair: Control
var _scope_overlay: ColorRect
var _hitmarker_lbl: Label
var _interact_lbl: Label
var _defeat_lbl: Label
var _killfeed_lbl: Label
var _sixth_sense_layer: Control

var _hitmarker_timer: float = 0.0
var _killfeed_lines: Array[String] = []

var _local_hero: HeroCharacter = null
var _conquest: ConquestManager = null
var _vehicles_ref: Array[VehicleBase] = []
var _heroes_ref: Dictionary = {}


func _ready() -> void:
	layer = 10
	_build_hud()


func bind_context(p_conquest: ConquestManager, p_vehicles: Array[VehicleBase], p_heroes: Dictionary) -> void:
	_conquest = p_conquest
	_vehicles_ref = p_vehicles
	_heroes_ref = p_heroes


func set_local_hero(hero: HeroCharacter) -> void:
	_local_hero = hero


func show_hitmarker(is_headshot: bool) -> void:
	_hitmarker_timer = 0.16
	if _hitmarker_lbl != null:
		_hitmarker_lbl.visible = true
		_hitmarker_lbl.modulate = Color(1.0, 0.2, 0.1) if is_headshot else Color.WHITE


func add_killfeed(text: String) -> void:
	_killfeed_lines.append(text)
	while _killfeed_lines.size() > 5:
		_killfeed_lines.pop_front()
	if _killfeed_lbl != null:
		_killfeed_lbl.text = "\n".join(_killfeed_lines)


func _build_hud() -> void:
	# 1. Top Center Scoreboard (Tickets + 4 Flags + Multiplier)
	_top_bar = PanelContainer.new()
	_top_bar.anchor_left = 0.5
	_top_bar.anchor_right = 0.5
	_top_bar.offset_left = -260.0
	_top_bar.offset_right = 260.0
	_top_bar.offset_top = 12.0
	_top_bar.offset_bottom = 68.0
	add_child(_top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 14)
	_top_bar.add_child(top_hbox)

	_royal_ticket_lbl = Label.new()
	_royal_ticket_lbl.text = "ROYAL 50"
	_royal_ticket_lbl.add_theme_font_size_override("font_size", 22)
	_royal_ticket_lbl.modulate = Color(0.32, 0.65, 1.0)
	top_hbox.add_child(_royal_ticket_lbl)

	var flags_hbox := HBoxContainer.new()
	flags_hbox.add_theme_constant_override("separation", 6)
	top_hbox.add_child(flags_hbox)
	for i in range(4):
		var fb := ColorRect.new()
		fb.custom_minimum_size = Vector2(22, 22)
		fb.color = Color(0.85, 0.85, 0.85)
		flags_hbox.add_child(fb)
		_flag_badges.append(fb)

	_multiplier_lbl = Label.new()
	_multiplier_lbl.text = "1x"
	_multiplier_lbl.add_theme_font_size_override("font_size", 18)
	_multiplier_lbl.modulate = Color(1.0, 0.88, 0.25)
	top_hbox.add_child(_multiplier_lbl)

	_national_ticket_lbl = Label.new()
	_national_ticket_lbl.text = "50 NATIONAL"
	_national_ticket_lbl.add_theme_font_size_override("font_size", 22)
	_national_ticket_lbl.modulate = Color(0.95, 0.28, 0.28)
	top_hbox.add_child(_national_ticket_lbl)

	# 2. Bottom Left Robust Health, Shield, Level/XP & Weapon Ammo
	var bl_panel := PanelContainer.new()
	bl_panel.anchor_left = 0.0
	bl_panel.anchor_top = 1.0
	bl_panel.anchor_bottom = 1.0
	bl_panel.offset_left = 18.0
	bl_panel.offset_right = 310.0
	bl_panel.offset_top = -148.0
	bl_panel.offset_bottom = -16.0
	add_child(bl_panel)

	var bl_vbox := VBoxContainer.new()
	bl_vbox.add_theme_constant_override("separation", 4)
	bl_panel.add_child(bl_vbox)

	_hp_text_lbl = Label.new()
	_hp_text_lbl.text = "HP: 110 / 110"
	_hp_text_lbl.add_theme_font_size_override("font_size", 18)
	bl_vbox.add_child(_hp_text_lbl)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(260, 22)
	_hp_bar.show_percentage = false
	_hp_bar.modulate = Color(0.25, 0.92, 0.35)
	bl_vbox.add_child(_hp_bar)

	_shield_bar = ProgressBar.new()
	_shield_bar.custom_minimum_size = Vector2(260, 10)
	_shield_bar.show_percentage = false
	_shield_bar.max_value = 160
	_shield_bar.modulate = Color(0.25, 0.72, 1.0)
	bl_vbox.add_child(_shield_bar)

	_level_lbl = Label.new()
	_level_lbl.text = "LVL 1 | Hero Pts: 2"
	bl_vbox.add_child(_level_lbl)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(260, 8)
	_xp_bar.show_percentage = false
	_xp_bar.modulate = Color(1.0, 0.85, 0.25)
	bl_vbox.add_child(_xp_bar)

	_weapon_lbl = Label.new()
	_weapon_lbl.text = "SMG | 32 / ∞"
	_weapon_lbl.add_theme_font_size_override("font_size", 16)
	bl_vbox.add_child(_weapon_lbl)

	# 3. Bottom Center Skills (1-5) & Widgets (6-8)
	var bc_panel := PanelContainer.new()
	bc_panel.anchor_left = 0.5
	bc_panel.anchor_right = 0.5
	bc_panel.anchor_top = 1.0
	bc_panel.anchor_bottom = 1.0
	bc_panel.offset_left = -350.0
	bc_panel.offset_right = 350.0
	bc_panel.offset_top = -94.0
	bc_panel.offset_bottom = -14.0
	add_child(bc_panel)

	var bc_hbox := HBoxContainer.new()
	bc_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bc_hbox.add_theme_constant_override("separation", 8)
	bc_panel.add_child(bc_hbox)

	for i in range(5):
		var slot_box := VBoxContainer.new()
		var up_btn := Button.new()
		up_btn.text = "+ (%d)" % (i + 1)
		up_btn.custom_minimum_size = Vector2(68, 22)
		var slot_idx: int = i
		up_btn.pressed.connect(func() -> void: upgrade_skill_requested.emit(slot_idx))
		slot_box.add_child(up_btn)
		_upgrade_buttons.append(up_btn)

		var sk_btn := Button.new()
		sk_btn.text = "[%d]" % (i + 1)
		sk_btn.custom_minimum_size = Vector2(76, 46)
		slot_box.add_child(sk_btn)
		_skill_buttons.append(sk_btn)
		bc_hbox.add_child(slot_box)

	var sep := VSeparator.new()
	bc_hbox.add_child(sep)

	var w_keys: Array[String] = ["[6] Band", "[7] Wrch", "[8] Anti"]
	for j in range(3):
		var wb := Button.new()
		wb.text = w_keys[j]
		wb.custom_minimum_size = Vector2(68, 52)
		bc_hbox.add_child(wb)
		_widget_buttons.append(wb)

	# 4. Sniper Scope Overlay (1st-person Commando Scope)
	_scope_overlay = ColorRect.new()
	_scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.color = Color(0.0, 0.0, 0.0, 0.25)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.visible = false
	add_child(_scope_overlay)

	var scope_ring := Label.new()
	scope_ring.anchor_left = 0.5
	scope_ring.anchor_top = 0.5
	scope_ring.offset_left = -120.0
	scope_ring.offset_top = -30.0
	scope_ring.text = "--------- ( + ) ---------"
	scope_ring.add_theme_font_size_override("font_size", 24)
	_scope_overlay.add_child(scope_ring)

	# 5. Sixth Sense wall-reveal overlay layer
	_sixth_sense_layer = Control.new()
	_sixth_sense_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sixth_sense_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sixth_sense_layer)

	# 6. Center Crosshair, Hitmarker, Interact & Defeat
	_crosshair = Control.new()
	_crosshair.anchor_left = 0.5
	_crosshair.anchor_top = 0.5
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	var dot := ColorRect.new()
	dot.color = Color(1.0, 1.0, 1.0, 0.9)
	dot.position = Vector2(-2, -2)
	dot.size = Vector2(4, 4)
	_crosshair.add_child(dot)

	_hitmarker_lbl = Label.new()
	_hitmarker_lbl.text = "X"
	_hitmarker_lbl.position = Vector2(-7, -14)
	_hitmarker_lbl.add_theme_font_size_override("font_size", 20)
	_hitmarker_lbl.visible = false
	_crosshair.add_child(_hitmarker_lbl)

	_interact_lbl = Label.new()
	_interact_lbl.anchor_left = 0.5
	_interact_lbl.anchor_top = 0.65
	_interact_lbl.offset_left = -140.0
	_interact_lbl.offset_right = 140.0
	_interact_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_lbl.text = ""
	_interact_lbl.add_theme_font_size_override("font_size", 18)
	add_child(_interact_lbl)

	_defeat_lbl = Label.new()
	_defeat_lbl.anchor_left = 0.5
	_defeat_lbl.anchor_top = 0.4
	_defeat_lbl.offset_left = -190.0
	_defeat_lbl.offset_right = 190.0
	_defeat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_defeat_lbl.add_theme_font_size_override("font_size", 26)
	_defeat_lbl.visible = false
	add_child(_defeat_lbl)

	# 7. Top-Right Killfeed & Ping / Lag Sim indicator
	_killfeed_lbl = Label.new()
	_killfeed_lbl.anchor_left = 1.0
	_killfeed_lbl.anchor_right = 1.0
	_killfeed_lbl.offset_left = -360.0
	_killfeed_lbl.offset_right = -16.0
	_killfeed_lbl.offset_top = 14.0
	_killfeed_lbl.offset_bottom = 160.0
	_killfeed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_killfeed_lbl)

	_ping_lbl = Label.new()
	_ping_lbl.offset_left = 16.0
	_ping_lbl.offset_top = 14.0
	_ping_lbl.text = "Ping: 0ms | F8: LagSim | ESC: Menu"
	add_child(_ping_lbl)


func _process(delta: float) -> void:
	if _hitmarker_timer > 0.0:
		_hitmarker_timer -= delta
		if _hitmarker_timer <= 0.0 and _hitmarker_lbl != null:
			_hitmarker_lbl.visible = false

	_ping_lbl.text = "Ping: %dms (Sim %.0fms) | F8: LagSim | ESC: Menu" % [int(NetworkManager.ema_rtt_ms), NetworkManager.sim_latency_ms * 2.0]

	if _conquest != null:
		_royal_ticket_lbl.text = "ROYAL %d" % _conquest.royal_tickets
		_national_ticket_lbl.text = "%d NATIONAL" % _conquest.national_tickets
		for i in range(mini(_conquest.capture_points.size(), _flag_badges.size())):
			var cp: CapturePoint = _conquest.capture_points[i]
			if cp.owner_team == NetworkManager.TEAM_ROYAL:
				_flag_badges[i].color = Color(0.22, 0.55, 1.0)
			elif cp.owner_team == NetworkManager.TEAM_NATIONAL:
				_flag_badges[i].color = Color(0.92, 0.22, 0.22)
			else:
				_flag_badges[i].color = Color(0.85, 0.85, 0.85)
		if _local_hero != null:
			var mult: int = _conquest.get_team_kill_multiplier(_local_hero.team)
			_multiplier_lbl.text = "%dx" % mult if mult > 0 else "0x"

	if _local_hero == null:
		return

	_hp_bar.max_value = _local_hero.max_hp
	_hp_bar.value = _local_hero.hp
	_shield_bar.value = _local_hero.shield
	_hp_text_lbl.text = "HP: %d / %d" % [_local_hero.hp, _local_hero.max_hp] + (" (+%d Shield)" % _local_hero.shield if _local_hero.shield > 0 else "")

	if _scope_overlay != null:
		_scope_overlay.visible = _local_hero.is_scoping

	if _defeat_lbl != null:
		_defeat_lbl.visible = _local_hero.is_defeated
		if _local_hero.is_defeated:
			_defeat_lbl.text = "DEFEATED! Respawning in %.1fs..." % maxf(0.0, _local_hero.defeat_timer)

	if not _local_hero.weapons.is_empty():
		var slot: int = clampi(_local_hero.selected_weapon_slot, 0, _local_hero.weapons.size() - 1)
		var w: WeaponBase = _local_hero.weapons[slot] as WeaponBase
		if w != null:
			if w.is_melee:
				_weapon_lbl.text = "%s (Melee)" % w.weapon_name
			elif w.is_reloading:
				_weapon_lbl.text = "%s | RELOADING..." % w.weapon_name
			else:
				_weapon_lbl.text = "%s | %d / ∞ [Q: Swap]" % [w.weapon_name, w.ammo_in_mag]

	if _local_hero.skill_manager != null and _local_hero.skill_manager is SkillManager:
		var sm := _local_hero.skill_manager as SkillManager
		_level_lbl.text = "LVL %d | Hero Pts: %d" % [sm.level, sm.hero_points]
		_xp_bar.max_value = sm.get_xp_for_next_level()
		_xp_bar.value = sm.xp

		for i in range(5):
			var rank: int = sm.skill_ranks[i]
			var cd: float = sm.skill_cooldowns[i]
			var short_name: String = sm.skill_names[i].substr(0, 8)
			if rank <= 0:
				_skill_buttons[i].text = "[%d] %s\nLOCK" % [i + 1, short_name]
			elif cd > 0.0:
				_skill_buttons[i].text = "[%d] %s\n%.1fs" % [i + 1, short_name, cd]
			else:
				_skill_buttons[i].text = "[%d] %s\nR%d" % [i + 1, short_name, rank]
			_upgrade_buttons[i].visible = sm.hero_points > 0 and rank < SkillManager.MAX_SKILL_RANK

		var w_labels: Array[String] = ["Band", "Wrch", "Anti"]
		for j in range(3):
			var wcd: float = sm.widget_cooldowns[j]
			_widget_buttons[j].text = "[%d] %s\n%s" % [6 + j, w_labels[j], ("%.1fs" % wcd) if wcd > 0.0 else "RDY"]

	_update_interact_prompt()
	_update_sixth_sense_markers()


func _update_interact_prompt() -> void:
	if _local_hero == null or _interact_lbl == null:
		return
	if _local_hero.current_vehicle_id >= 0:
		_interact_lbl.text = "[E] Exit Vehicle"
		return
	for v in _vehicles_ref:
		if v != null and not v.is_destroyed and v.global_position.distance_to(_local_hero.global_position) <= 5.5:
			_interact_lbl.text = "[E] Enter Vehicle (HP %d)" % v.hp
			return
	_interact_lbl.text = ""


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
