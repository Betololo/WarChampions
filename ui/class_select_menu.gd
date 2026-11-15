class_name ClassSelectMenu
extends CanvasLayer

## War Champions Multi-Screen Menu & In-Game Pause System:
## - HubScreen: War Champions 20v20 Cartoon Warfare, Quick Offline Bots, Multiplayer Drawer.
## - ArmoryScreen: Royal (Azure) vs National (Crimson) Factions, Exclusive Class loadouts, Weapon Variants & 5-6 skills.
## - SettingsScreen: Master/SFX/Music sliders, Mouse Sensitivity, Custom Skill/Widget Hotkeys, In-match Pause.

signal host_online_pressed(team: int, class_id: int, port: int)
signal join_online_pressed(team: int, class_id: int, ip: String, port: int)
signal play_offline_bots_pressed(team: int, class_id: int)

signal host_online_requested(team: int, class_id: int, port: int)
signal join_online_requested(team: int, class_id: int, ip: String, port: int)
signal play_offline_bots_requested(team: int, class_id: int)
signal deploy_requested(team: int, class_id: int)
signal team_selected(team: int)
signal class_selected(class_id: int)
signal resume_match_requested()
signal leave_match_requested()

static var current_mouse_sensitivity: float = 0.0024

var selected_team: int = NetworkManager.TEAM_ROYAL
var selected_class: int = NetworkManager.CLASS_SOLDIER
var current_screen: String = "hub"
var _in_match_mode: bool = false
var _pending_mode: String = "bots" # "bots", "host", "join"

## Screens
var _hub_screen: Control
var _armory_screen: Control
var _settings_screen: Control

## Common UI Elements
var _ip_input: LineEdit
var _port_input: LineEdit
var _status_lbl: Label
var status_label: Label:
	get:
		return _status_lbl

var _summary_lbl: Label
var _preview_portrait: TextureRect
var _preview_flag: TextureRect
var _royal_btn: Button
var _nat_btn: Button
var _class_buttons: Array[Button] = []
var _class_cards: Array[PanelContainer] = []
var _lag_btn: Button
var _deploy_btn: Button
var _mp_drawer: VBoxContainer
var _weapon_variant_row: HBoxContainer
var _weapon_variant_selectors: Array[OptionButton] = []

## Settings UI Elements
var _master_vol_slider: HSlider
var _sfx_vol_slider: HSlider
var _music_vol_slider: HSlider
var _sens_slider: HSlider
var _resume_btn: Button
var _leave_btn: Button
var _settings_back_btn: Button
var _settings_title: Label
var _skill_hotkey_buttons: Array[Button] = []
var _widget_hotkey_buttons: Array[Button] = []
var _reset_hotkeys_btn: Button
var _listening_hotkey_kind: String = "" # "skill" | "widget" | ""
var _listening_hotkey_slot: int = -1


func _ready() -> void:
	layer = 20
	set_process_input(true)
	_build_ui()
	_refresh_summary()
	show_screen("hub")


func _input(event: InputEvent) -> void:
	if _listening_hotkey_kind.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_cancel_hotkey_listen()
			get_viewport().set_input_as_handled()
			return
		if k.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return
		assign_hotkey_from_ui(_listening_hotkey_kind, _listening_hotkey_slot, k.keycode)
		get_viewport().set_input_as_handled()


static func get_class_weapon_slots(p_class_id: int) -> Array[int]:
	match p_class_id:
		NetworkManager.CLASS_SOLDIER:
			return [WeaponBase.WeaponKind.SMG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.PISTOL, WeaponBase.WeaponKind.TNT]
		NetworkManager.CLASS_GUNNER:
			return [WeaponBase.WeaponKind.MG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.BAZOOKA]
		_:
			return [WeaponBase.WeaponKind.SNIPER, WeaponBase.WeaponKind.KNIFE, WeaponBase.WeaponKind.PISTOL, WeaponBase.WeaponKind.TNT]


func _make_card_style(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.border_width_top = border_w
	sb.border_width_bottom = border_w
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	return sb


func _get_lan_ip_hint() -> String:
	var ips: PackedStringArray = []
	for addr in IP.get_local_addresses():
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			if not ips.has(addr):
				ips.append(addr)
	if ips.is_empty():
		return "127.0.0.1 (localhost)"
	return ", ".join(ips)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.08, 0.14, 0.92)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_panel := PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(980, 620)
	main_panel.add_theme_stylebox_override("panel", _make_card_style(Color(0.09, 0.13, 0.20, 0.97), Color(0.96, 0.78, 0.22), 3))
	center.add_child(main_panel)

	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 24)
	main_margin.add_theme_constant_override("margin_right", 24)
	main_margin.add_theme_constant_override("margin_top", 18)
	main_margin.add_theme_constant_override("margin_bottom", 18)
	main_panel.add_child(main_margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	main_margin.add_child(stack)

	_build_hub_screen(stack)
	_build_armory_screen(stack)
	_build_settings_screen(stack)


func _build_hub_screen(parent: Control) -> void:
	_hub_screen = VBoxContainer.new()
	_hub_screen.add_theme_constant_override("separation", 12)
	parent.add_child(_hub_screen)

	# 1. Header Banner
	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 2)
	_hub_screen.add_child(title_box)

	var title := Label.new()
	title.text = "WAR CHAMPIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "20v20 Cartoon Warfare — Seaside Frontline"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	title_box.add_child(subtitle)

	# 2. Main Mode Action Buttons
	var mode_box := VBoxContainer.new()
	mode_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_box.add_theme_constant_override("separation", 10)
	_hub_screen.add_child(mode_box)

	var solo_btn := Button.new()
	solo_btn.text = "Treino Offline 20v20 Bots"
	solo_btn.custom_minimum_size = Vector2(480, 46)
	solo_btn.pressed.connect(func() -> void:
		_pending_mode = "bots"
		show_screen("armory")
	)
	mode_box.add_child(solo_btn)

	var mp_toggle_btn := Button.new()
	mp_toggle_btn.text = "Multiplayer Online"
	mp_toggle_btn.custom_minimum_size = Vector2(480, 46)
	mp_toggle_btn.pressed.connect(func() -> void:
		_mp_drawer.visible = not _mp_drawer.visible
	)
	mode_box.add_child(mp_toggle_btn)

	# 3. Multiplayer Drawer Panel
	var mp_card := PanelContainer.new()
	mp_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.16, 0.26, 0.92), Color(0.30, 0.72, 1.0), 2))
	mode_box.add_child(mp_card)

	var mp_m := MarginContainer.new()
	mp_m.add_theme_constant_override("margin_left", 14)
	mp_m.add_theme_constant_override("margin_right", 14)
	mp_m.add_theme_constant_override("margin_top", 10)
	mp_m.add_theme_constant_override("margin_bottom", 10)
	mp_card.add_child(mp_m)

	_mp_drawer = VBoxContainer.new()
	_mp_drawer.add_theme_constant_override("separation", 8)
	mp_m.add_child(_mp_drawer)

	var mp_hdr := Label.new()
	mp_hdr.text = "CONEXÃO MULTIPLAYER ONLINE (12v12 Servidor Dedicado)"
	mp_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_hdr.add_theme_font_size_override("font_size", 15)
	mp_hdr.add_theme_color_override("font_color", Color(0.50, 0.90, 1.0))
	_mp_drawer.add_child(mp_hdr)

	var ip_row := HBoxContainer.new()
	ip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ip_row.add_theme_constant_override("separation", 8)
	_mp_drawer.add_child(ip_row)

	var ip_lbl := Label.new()
	ip_lbl.text = "IP / Domínio:"
	ip_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(170, 34)
	ip_row.add_child(_ip_input)

	var port_lbl := Label.new()
	port_lbl.text = "Porta UDP:"
	ip_row.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = "7777"
	_port_input.custom_minimum_size = Vector2(75, 34)
	ip_row.add_child(_port_input)

	# Presets
	var preset_local := Button.new()
	preset_local.text = "Localhost 127.0.0.1"
	preset_local.pressed.connect(func() -> void:
		_ip_input.text = "127.0.0.1"
		_port_input.text = "7777"
	)
	ip_row.add_child(preset_local)

	var preset_vps := Button.new()
	preset_vps.text = "Servidor VPS"
	preset_vps.pressed.connect(func() -> void:
		_ip_input.text = "game.warchampions.io"
		_port_input.text = "7777"
	)
	ip_row.add_child(preset_vps)

	var mp_act_row := HBoxContainer.new()
	mp_act_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mp_act_row.add_theme_constant_override("separation", 10)
	_mp_drawer.add_child(mp_act_row)

	var host_btn := Button.new()
	host_btn.text = "Criar Sala (Host)"
	host_btn.custom_minimum_size = Vector2(230, 38)
	host_btn.pressed.connect(func() -> void:
		_pending_mode = "host"
		show_screen("armory")
	)
	mp_act_row.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Entrar no Servidor"
	join_btn.custom_minimum_size = Vector2(230, 38)
	join_btn.pressed.connect(func() -> void:
		_pending_mode = "join"
		show_screen("armory")
	)
	mp_act_row.add_child(join_btn)

	# 4. Secondary Navigation Buttons
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_row.add_theme_constant_override("separation", 12)
	_hub_screen.add_child(nav_row)

	var armory_btn := Button.new()
	armory_btn.text = "Arsenal & Classes"
	armory_btn.custom_minimum_size = Vector2(235, 40)
	armory_btn.pressed.connect(func() -> void:
		show_screen("armory")
	)
	nav_row.add_child(armory_btn)

	var settings_btn := Button.new()
	settings_btn.text = "Configurações / Controles"
	settings_btn.custom_minimum_size = Vector2(235, 40)
	settings_btn.pressed.connect(func() -> void:
		show_screen("settings")
	)
	nav_row.add_child(settings_btn)

	_lag_btn = Button.new()
	_lag_btn.text = "Simulador de Lag: OFF (0ms)"
	_lag_btn.custom_minimum_size = Vector2(240, 40)
	_lag_btn.pressed.connect(_toggle_lag_sim)
	nav_row.add_child(_lag_btn)

	# 5. Status Label
	_status_lbl = Label.new()
	_status_lbl.text = "IP Local: %s | Servidor padrão UDP 7777" % _get_lan_ip_hint()
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 12)
	_status_lbl.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	_hub_screen.add_child(_status_lbl)


func _build_armory_screen(parent: Control) -> void:
	_armory_screen = VBoxContainer.new()
	_armory_screen.visible = false
	_armory_screen.add_theme_constant_override("separation", 10)
	parent.add_child(_armory_screen)

	# Header with Back button
	var arm_top := HBoxContainer.new()
	_armory_screen.add_child(arm_top)

	var back_btn := Button.new()
	back_btn.text = "<- Voltar ao Hub"
	back_btn.custom_minimum_size = Vector2(160, 36)
	back_btn.pressed.connect(func() -> void:
		show_screen("hub")
	)
	arm_top.add_child(back_btn)

	var arm_title := Label.new()
	arm_title.text = "ARSENAL DE COMBATE — FAÇÃO & CLASSE"
	arm_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arm_title.add_theme_font_size_override("font_size", 22)
	arm_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	arm_top.add_child(arm_title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(160, 36)
	arm_top.add_child(spacer)

	# Faction Picker Row
	var fac_box := HBoxContainer.new()
	fac_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fac_box.add_theme_constant_override("separation", 18)
	_armory_screen.add_child(fac_box)

	_preview_flag = TextureRect.new()
	_preview_flag.custom_minimum_size = Vector2(64, 46)
	_preview_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fac_box.add_child(_preview_flag)

	_royal_btn = Button.new()
	_royal_btn.text = "ROYAL ARMY\n(Aliados Azul / Ouro)"
	_royal_btn.custom_minimum_size = Vector2(260, 50)
	_royal_btn.pressed.connect(func() -> void:
		select_team(NetworkManager.TEAM_ROYAL)
	)
	fac_box.add_child(_royal_btn)

	_nat_btn = Button.new()
	_nat_btn.text = "NATIONAL ARMY\n(Cinza Chumbo / Carmesim)"
	_nat_btn.custom_minimum_size = Vector2(260, 50)
	_nat_btn.pressed.connect(func() -> void:
		select_team(NetworkManager.TEAM_NATIONAL)
	)
	fac_box.add_child(_nat_btn)

	_preview_portrait = TextureRect.new()
	_preview_portrait.custom_minimum_size = Vector2(54, 54)
	_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fac_box.add_child(_preview_portrait)

	# 3 Class Cards Row
	var cls_row := HBoxContainer.new()
	cls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cls_row.add_theme_constant_override("separation", 12)
	_armory_screen.add_child(cls_row)

	var class_info := [
		{
			"id": NetworkManager.CLASS_SOLDIER,
			"name": "SOLDIER",
			"stats": "HP: 110 | Velocidade: 6.3 m/s",
			"weapons": "SMG, Shotgun, Pistola, TNT",
			"skills": "Combat Med • Blasting • Grenade\nSixth Sense • Burning Bullets",
			"col": Color(0.20, 0.45, 0.75),
		},
		{
			"id": NetworkManager.CLASS_GUNNER,
			"name": "GUNNER",
			"stats": "HP: 150 | Velocidade: 5.4 m/s",
			"weapons": "Metralhadora MG, Shotgun, Bazooka",
			"skills": "Hero Shield • Eat Grenades • Frenzy\nExplosive Keg • Leg Shot",
			"col": Color(0.65, 0.40, 0.15),
		},
		{
			"id": NetworkManager.CLASS_COMMANDO,
			"name": "COMMANDO",
			"stats": "HP: 80 | Velocidade: 7.2 m/s",
			"weapons": "Sniper, Faca, Pistola, TNT",
			"skills": "Stealth • Poisoned Blade • Troop Trap\nElixir • Piercing • Mark Target",
			"col": Color(0.45, 0.20, 0.60),
		},
	]

	_class_buttons.clear()
	_class_cards.clear()

	for info in class_info:
		var c_card := PanelContainer.new()
		c_card.custom_minimum_size = Vector2(290, 200)
		c_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.12, 0.18, 0.95), info["col"], 2))
		cls_row.add_child(c_card)
		_class_cards.append(c_card)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 12)
		cm.add_theme_constant_override("margin_right", 12)
		cm.add_theme_constant_override("margin_top", 10)
		cm.add_theme_constant_override("margin_bottom", 10)
		c_card.add_child(cm)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		cm.add_child(cv)

		var c_btn := Button.new()
		c_btn.text = "ESCOLHER %s" % info["name"]
		c_btn.custom_minimum_size = Vector2(250, 34)
		var cid: int = int(info["id"])
		c_btn.pressed.connect(func() -> void:
			select_class(cid)
		)
		cv.add_child(c_btn)
		_class_buttons.append(c_btn)

		var stat_lbl := Label.new()
		stat_lbl.text = info["stats"]
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
		cv.add_child(stat_lbl)

		var wep_hdr := Label.new()
		wep_hdr.text = "Armas Exclusivas:"
		wep_hdr.add_theme_font_size_override("font_size", 12)
		cv.add_child(wep_hdr)

		var wep_lbl := Label.new()
		wep_lbl.text = info["weapons"]
		wep_lbl.add_theme_font_size_override("font_size", 11)
		wep_lbl.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
		wep_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(wep_lbl)

		var skl_hdr := Label.new()
		skl_hdr.text = "Habilidades Únicas:"
		skl_hdr.add_theme_font_size_override("font_size", 12)
		cv.add_child(skl_hdr)

		var skl_lbl := Label.new()
		skl_lbl.text = info["skills"]
		skl_lbl.add_theme_font_size_override("font_size", 11)
		skl_lbl.add_theme_color_override("font_color", Color(0.70, 0.88, 0.70))
		skl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(skl_lbl)

	# Equippable Weapon Variants per Slot for Selected Class
	var var_card := PanelContainer.new()
	var_card.custom_minimum_size = Vector2(900, 74)
	var_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.10, 0.16, 0.95), Color(0.35, 0.50, 0.70), 2))
	_armory_screen.add_child(var_card)

	var vm := MarginContainer.new()
	vm.add_theme_constant_override("margin_left", 12)
	vm.add_theme_constant_override("margin_right", 12)
	vm.add_theme_constant_override("margin_top", 6)
	vm.add_theme_constant_override("margin_bottom", 6)
	var_card.add_child(vm)

	var v_outer := VBoxContainer.new()
	v_outer.add_theme_constant_override("separation", 4)
	vm.add_child(v_outer)

	var var_hdr := Label.new()
	var_hdr.text = "EQUIPAMENTO — VARIANTES POR SLOT DA CLASSE SELECIONADA:"
	var_hdr.add_theme_font_size_override("font_size", 11)
	var_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	v_outer.add_child(var_hdr)

	_weapon_variant_row = HBoxContainer.new()
	_weapon_variant_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_weapon_variant_row.add_theme_constant_override("separation", 10)
	v_outer.add_child(_weapon_variant_row)

	_summary_lbl = Label.new()
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 14)
	_summary_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	_armory_screen.add_child(_summary_lbl)

	# Deploy Button
	_deploy_btn = Button.new()
	_deploy_btn.text = "ENTRAR NA BATALHA"
	_deploy_btn.custom_minimum_size = Vector2(460, 44)
	_deploy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_deploy_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.40))
	_deploy_btn.pressed.connect(_on_deploy_clicked)
	_armory_screen.add_child(_deploy_btn)


func _build_settings_screen(parent: Control) -> void:
	_settings_screen = VBoxContainer.new()
	_settings_screen.visible = false
	_settings_screen.add_theme_constant_override("separation", 10)
	parent.add_child(_settings_screen)

	# Settings Header
	var st_top := HBoxContainer.new()
	_settings_screen.add_child(st_top)

	_settings_back_btn = Button.new()
	_settings_back_btn.text = "<- Voltar ao Hub"
	_settings_back_btn.custom_minimum_size = Vector2(160, 36)
	_settings_back_btn.pressed.connect(func() -> void:
		show_screen("hub")
	)
	st_top.add_child(_settings_back_btn)

	_settings_title = Label.new()
	_settings_title.text = "CONFIGURAÇÕES & CONTROLES"
	_settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title.add_theme_font_size_override("font_size", 22)
	_settings_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	st_top.add_child(_settings_title)

	var st_spacer := Control.new()
	st_spacer.custom_minimum_size = Vector2(160, 36)
	st_top.add_child(st_spacer)

	# Sliders & Controls layout
	var sets_box := HBoxContainer.new()
	sets_box.add_theme_constant_override("separation", 18)
	_settings_screen.add_child(sets_box)

	# Left Column: Audio & Sensitivity Sliders
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(400, 390)
	left_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.11, 0.17, 0.95), Color(0.35, 0.50, 0.70), 2))
	sets_box.add_child(left_card)

	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_left", 16)
	lm.add_theme_constant_override("margin_right", 16)
	lm.add_theme_constant_override("margin_top", 12)
	lm.add_theme_constant_override("margin_bottom", 12)
	left_card.add_child(lm)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	lm.add_child(lv)

	var aud_hdr := Label.new()
	aud_hdr.text = "Áudio & Sensibilidade do Mouse"
	aud_hdr.add_theme_font_size_override("font_size", 16)
	aud_hdr.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	lv.add_child(aud_hdr)

	# Master Volume
	var m_lbl := Label.new()
	m_lbl.text = "Volume Geral (Master): 100%"
	lv.add_child(m_lbl)
	_master_vol_slider = HSlider.new()
	_master_vol_slider.min_value = 0.0
	_master_vol_slider.max_value = 100.0
	_master_vol_slider.value = SoundSynthesizer.master_volume * 100.0
	_master_vol_slider.value_changed.connect(func(v: float) -> void:
		m_lbl.text = "Volume Geral (Master): %d%%" % int(v)
		SoundSynthesizer.set_master_volume(v / 100.0)
	)
	lv.add_child(_master_vol_slider)

	# SFX Volume
	var s_lbl := Label.new()
	s_lbl.text = "Volume dos Efeitos (SFX): 100%"
	lv.add_child(s_lbl)
	_sfx_vol_slider = HSlider.new()
	_sfx_vol_slider.min_value = 0.0
	_sfx_vol_slider.max_value = 100.0
	_sfx_vol_slider.value = SoundSynthesizer.sfx_volume * 100.0
	_sfx_vol_slider.value_changed.connect(func(v: float) -> void:
		s_lbl.text = "Volume dos Efeitos (SFX): %d%%" % int(v)
		SoundSynthesizer.set_sfx_volume(v / 100.0)
	)
	lv.add_child(_sfx_vol_slider)

	# Music Volume
	var mus_lbl := Label.new()
	mus_lbl.text = "Volume da Música: 100%"
	lv.add_child(mus_lbl)
	_music_vol_slider = HSlider.new()
	_music_vol_slider.min_value = 0.0
	_music_vol_slider.max_value = 100.0
	_music_vol_slider.value = SoundSynthesizer.music_volume * 100.0
	_music_vol_slider.value_changed.connect(func(v: float) -> void:
		mus_lbl.text = "Volume da Música: %d%%" % int(v)
		SoundSynthesizer.set_music_volume(v / 100.0)
	)
	lv.add_child(_music_vol_slider)

	var mute_btn := Button.new()
	mute_btn.text = "Alternar Mudo / Música (M)"
	mute_btn.pressed.connect(func() -> void:
		var on: bool = SoundSynthesizer.toggle_music()
		mute_btn.text = "Música: ATIVADA" if on else "Música: DESATIVADA (M)"
	)
	lv.add_child(mute_btn)

	# Mouse Sensitivity
	var sens_lbl := Label.new()
	sens_lbl.text = "Sensibilidade do Mouse: %.4f rad/px" % current_mouse_sensitivity
	lv.add_child(sens_lbl)
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.0010
	_sens_slider.max_value = 0.0060
	_sens_slider.step = 0.0001
	_sens_slider.value = current_mouse_sensitivity
	_sens_slider.value_changed.connect(func(v: float) -> void:
		sens_lbl.text = "Sensibilidade do Mouse: %.4f rad/px" % v
		set_mouse_sensitivity(v)
	)
	lv.add_child(_sens_slider)

	# Right Column: Custom Skill/Widget Hotkeys & Controls Summary
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(490, 390)
	right_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.11, 0.17, 0.95), Color(0.35, 0.50, 0.70), 2))
	sets_box.add_child(right_card)

	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_left", 14)
	rm.add_theme_constant_override("margin_right", 14)
	rm.add_theme_constant_override("margin_top", 10)
	rm.add_theme_constant_override("margin_bottom", 10)
	right_card.add_child(rm)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	rm.add_child(rv)

	var bind_hdr_row := HBoxContainer.new()
	rv.add_child(bind_hdr_row)

	var bind_hdr := Label.new()
	bind_hdr.text = "Atalhos Personalizáveis (Skills & Itens)"
	bind_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bind_hdr.add_theme_font_size_override("font_size", 15)
	bind_hdr.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	bind_hdr_row.add_child(bind_hdr)

	_reset_hotkeys_btn = Button.new()
	_reset_hotkeys_btn.text = "Restaurar Padrões"
	_reset_hotkeys_btn.custom_minimum_size = Vector2(138, 26)
	_reset_hotkeys_btn.pressed.connect(func() -> void:
		InputCmd.reset_default_hotkeys()
		_cancel_hotkey_listen()
		_refresh_hotkey_buttons()
		_notify_hud_hotkeys_changed()
	)
	bind_hdr_row.add_child(_reset_hotkeys_btn)

	var sk_grid := GridContainer.new()
	sk_grid.columns = 3
	sk_grid.add_theme_constant_override("h_separation", 8)
	sk_grid.add_theme_constant_override("v_separation", 6)
	rv.add_child(sk_grid)

	_skill_hotkey_buttons.clear()
	for s_i in range(6):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(146, 30)
		var captured_s: int = s_i
		btn.pressed.connect(func() -> void:
			_begin_hotkey_listen("skill", captured_s)
		)
		sk_grid.add_child(btn)
		_skill_hotkey_buttons.append(btn)

	var wd_grid := GridContainer.new()
	wd_grid.columns = 2
	wd_grid.add_theme_constant_override("h_separation", 8)
	wd_grid.add_theme_constant_override("v_separation", 6)
	rv.add_child(wd_grid)

	_widget_hotkey_buttons.clear()
	for w_i in range(4):
		var wbtn := Button.new()
		wbtn.custom_minimum_size = Vector2(224, 30)
		var captured_w: int = w_i
		wbtn.pressed.connect(func() -> void:
			_begin_hotkey_listen("widget", captured_w)
		)
		wd_grid.add_child(wbtn)
		_widget_hotkey_buttons.append(wbtn)

	_refresh_hotkey_buttons()

	var ctrl_hdr := Label.new()
	ctrl_hdr.text = "Resumo de Controles"
	ctrl_hdr.add_theme_font_size_override("font_size", 14)
	ctrl_hdr.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	rv.add_child(ctrl_hdr)

	var controls_text: String = (
		"• WASD: Mover | Espaço: Pular / Paraquedas | Ctrl/C: Agachar\n" +
		"• 1..4: Armas | Q: Última Arma usada | R: Recarregar | Botão Direito: Mirar\n" +
		"• E: Entrar/Sair Veículo | F1..F4: Trocar Assento do Veículo\n" +
		"• F8: Simulador de Lag | M: Música | T: Emote | ESC: Pausa"
	)
	var ctrl_body := Label.new()
	ctrl_body.text = controls_text
	ctrl_body.add_theme_font_size_override("font_size", 11)
	ctrl_body.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	ctrl_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(ctrl_body)

	# In-match Pause Action Row (Retomar / Sair)
	var pause_row := HBoxContainer.new()
	pause_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_row.add_theme_constant_override("separation", 16)
	_settings_screen.add_child(pause_row)

	_resume_btn = Button.new()
	_resume_btn.text = "Retomar Partida"
	_resume_btn.custom_minimum_size = Vector2(230, 42)
	_resume_btn.visible = false
	_resume_btn.pressed.connect(func() -> void:
		hide_menu()
		resume_match_requested.emit()
	)
	pause_row.add_child(_resume_btn)

	_leave_btn = Button.new()
	_leave_btn.text = "Desconectar / Voltar ao Menu"
	_leave_btn.custom_minimum_size = Vector2(230, 42)
	_leave_btn.visible = false
	_leave_btn.pressed.connect(func() -> void:
		set_in_match_mode(false)
		show_screen("hub")
		leave_match_requested.emit()
	)
	pause_row.add_child(_leave_btn)


func show_screen(screen_name: String) -> void:
	current_screen = screen_name
	if _hub_screen != null:
		_hub_screen.visible = (screen_name == "hub")
	if _armory_screen != null:
		_armory_screen.visible = (screen_name == "armory")
	if _settings_screen != null:
		_settings_screen.visible = (screen_name == "settings")
	if screen_name == "armory":
		_refresh_summary()


func set_in_match_mode(in_match: bool) -> void:
	_in_match_mode = in_match
	if _resume_btn != null:
		_resume_btn.visible = in_match
	if _leave_btn != null:
		_leave_btn.visible = in_match
	if _settings_back_btn != null:
		_settings_back_btn.visible = not in_match
	if _settings_title != null:
		_settings_title.text = "PAUSA — CONFIGURAÇÕES" if in_match else "CONFIGURAÇÕES & CONTROLES"


func select_team(p_team: int) -> void:
	selected_team = clampi(p_team, 0, 1)
	_refresh_summary()
	team_selected.emit(selected_team)


func select_class(p_class_id: int) -> void:
	selected_class = clampi(p_class_id, 0, 2)
	_refresh_summary()
	class_selected.emit(selected_class)


func set_mouse_sensitivity(val: float) -> void:
	current_mouse_sensitivity = clampf(val, 0.0010, 0.0060)
	HeroCamera.default_sensitivity = current_mouse_sensitivity
	if is_inside_tree():
		for node in get_tree().get_nodes_in_group("hero_cameras"):
			if node is HeroCamera:
				node.mouse_sensitivity = current_mouse_sensitivity
				node.sensitivity = current_mouse_sensitivity
		var cam: HeroCamera = get_tree().root.find_child("HeroCamera", true, false) as HeroCamera
		if cam != null:
			cam.mouse_sensitivity = current_mouse_sensitivity
			cam.sensitivity = current_mouse_sensitivity


func set_status_text(text: String) -> void:
	if _status_lbl != null:
		_status_lbl.text = text


func _on_deploy_clicked() -> void:
	hide_menu()
	deploy_requested.emit(selected_team, selected_class)
	match _pending_mode:
		"host":
			var port: int = maxi(1024, int(_port_input.text)) if _port_input != null else NetworkManager.DEFAULT_PORT
			host_online_pressed.emit(selected_team, selected_class, port)
			host_online_requested.emit(selected_team, selected_class, port)
		"join":
			var ip: String = _ip_input.text.strip_edges() if _ip_input != null else "127.0.0.1"
			var port: int = maxi(1024, int(_port_input.text)) if _port_input != null else NetworkManager.DEFAULT_PORT
			join_online_pressed.emit(selected_team, selected_class, ip, port)
			join_online_requested.emit(selected_team, selected_class, ip, port)
		_:
			play_offline_bots_pressed.emit(selected_team, selected_class)
			play_offline_bots_requested.emit(selected_team, selected_class)


func _toggle_lag_sim() -> void:
	if NetworkManager.sim_latency_ms <= 0.0:
		NetworkManager.sim_latency_ms = 80.0
		NetworkManager.sim_jitter_ms = 12.0
		NetworkManager.sim_packet_loss = 0.02
		if _lag_btn != null:
			_lag_btn.text = "Simulador de Lag: ON (160ms + 2% Perda)"
	else:
		NetworkManager.sim_latency_ms = 0.0
		NetworkManager.sim_jitter_ms = 0.0
		NetworkManager.sim_packet_loss = 0.0
		if _lag_btn != null:
			_lag_btn.text = "Simulador de Lag: OFF (0ms)"


func select_weapon_variant(p_class_id: int, slot_idx: int, arch: int) -> void:
	NetworkManager.set_slot_archetype(p_class_id, slot_idx, arch)
	if p_class_id == selected_class:
		_refresh_summary()


func _rebuild_weapon_variant_selectors() -> void:
	if _weapon_variant_row == null:
		return
	for child in _weapon_variant_row.get_children():
		child.queue_free()
	_weapon_variant_selectors.clear()
	var kinds: Array[int] = get_class_weapon_slots(selected_class)
	var arch_tags: Array[String] = ["Equilibrada", "Cadência+", "Precisão+"]
	for slot_idx in range(kinds.size()):
		var w_kind: int = kinds[slot_idx]
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var slot_lbl := Label.new()
		slot_lbl.text = "%d:" % (slot_idx + 1)
		slot_lbl.add_theme_font_size_override("font_size", 11)
		slot_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.40))
		box.add_child(slot_lbl)

		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(196, 28)
		for a_idx in range(3):
			var vname: String = WeaponBase.get_variant_display_name(w_kind, a_idx)
			opt.add_item("%s (%s)" % [vname, arch_tags[a_idx]], a_idx)
		var cur_arch: int = NetworkManager.get_slot_archetype(selected_class, slot_idx, NetworkManager.ARCHETYPE_BALANCED)
		opt.selected = clampi(cur_arch, 0, 2)
		var cap_slot: int = slot_idx
		opt.item_selected.connect(func(sel_idx: int) -> void:
			select_weapon_variant(selected_class, cap_slot, sel_idx)
		)
		box.add_child(opt)
		_weapon_variant_row.add_child(box)
		_weapon_variant_selectors.append(opt)


func _begin_hotkey_listen(kind: String, slot_idx: int) -> void:
	_listening_hotkey_kind = kind
	_listening_hotkey_slot = slot_idx
	_refresh_hotkey_buttons()
	if kind == "skill" and slot_idx >= 0 and slot_idx < _skill_hotkey_buttons.size():
		_skill_hotkey_buttons[slot_idx].text = "Sk%d: [Tecla...]" % (slot_idx + 1)
	elif kind == "widget" and slot_idx >= 0 and slot_idx < _widget_hotkey_buttons.size():
		_widget_hotkey_buttons[slot_idx].text = "[Pressione Tecla...]"


func _cancel_hotkey_listen() -> void:
	_listening_hotkey_kind = ""
	_listening_hotkey_slot = -1
	_refresh_hotkey_buttons()


func assign_hotkey_from_ui(kind: String, slot_idx: int, keycode: int) -> void:
	if kind == "skill":
		InputCmd.set_skill_key(slot_idx, keycode)
	elif kind == "widget":
		InputCmd.set_widget_key(slot_idx, keycode)
	_listening_hotkey_kind = ""
	_listening_hotkey_slot = -1
	_refresh_hotkey_buttons()
	_notify_hud_hotkeys_changed()


func _refresh_hotkey_buttons() -> void:
	for s_i in range(_skill_hotkey_buttons.size()):
		var lbl: String = InputCmd.key_short_label(InputCmd.get_skill_key(s_i))
		_skill_hotkey_buttons[s_i].text = "Skill %d: %s" % [s_i + 1, lbl]
	var w_names: Array[String] = ["Bandagem", "Chave", "Antifogo", "Antídoto"]
	for w_i in range(_widget_hotkey_buttons.size()):
		var wlbl: String = InputCmd.key_short_label(InputCmd.get_widget_key(w_i))
		_widget_hotkey_buttons[w_i].text = "%s: %s" % [w_names[w_i], wlbl]


func _notify_hud_hotkeys_changed() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("hud_controllers"):
		if node != null and node.has_method("refresh_hotkey_labels"):
			node.refresh_hotkey_labels()
	var hud_node: Node = get_tree().root.find_child("HUDController", true, false)
	if hud_node != null and hud_node.has_method("refresh_hotkey_labels"):
		hud_node.refresh_hotkey_labels()


func _refresh_summary() -> void:
	var t_name: String = "Royal Army" if selected_team == 0 else "National Army"
	var t_prefix: String = "royal" if selected_team == 0 else "national"
	var c_names: Array[String] = ["Soldier", "Gunner", "Commando"]
	var w_desc: Array[String] = [
		"SMG, Shotgun, Pistola, TNT",
		"Metralhadora MG, Shotgun, Bazooka",
		"Rifle Sniper, Faca, Pistola, TNT",
	]
	var equipped_names: PackedStringArray = []
	var kinds: Array[int] = get_class_weapon_slots(selected_class)
	for s_i in range(kinds.size()):
		var a: int = NetworkManager.get_slot_archetype(selected_class, s_i, NetworkManager.ARCHETYPE_BALANCED)
		equipped_names.append(WeaponBase.get_variant_display_name(kinds[s_i], a))
	_rebuild_weapon_variant_selectors()
	if _summary_lbl != null:
		_summary_lbl.text = "%s | %s (%s) — Variantes: %s" % [t_name, c_names[selected_class], w_desc[selected_class], ", ".join(equipped_names)]
	if _preview_flag != null:
		_preview_flag.texture = CartoonAssets.get_texture("flag_%s" % t_prefix)
	if _preview_portrait != null:
		_preview_portrait.texture = CartoonAssets.get_texture("portrait_%s_%d" % [t_prefix, selected_class])
	if _royal_btn != null:
		_royal_btn.modulate = Color(1.0, 1.0, 1.0) if selected_team == 0 else Color(0.65, 0.68, 0.72)
	if _nat_btn != null:
		_nat_btn.modulate = Color(1.0, 1.0, 1.0) if selected_team == 1 else Color(0.65, 0.68, 0.72)
	for i in range(_class_buttons.size()):
		_class_buttons[i].modulate = Color(1.0, 0.96, 0.75) if i == selected_class else Color(0.68, 0.72, 0.78)
	for i in range(_class_cards.size()):
		var border_col: Color = Color(1.0, 0.86, 0.24) if i == selected_class else Color(0.35, 0.45, 0.55)
		var sb: StyleBoxFlat = _class_cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = border_col


func show_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false
	if not DisplayServer.get_name().contains("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
