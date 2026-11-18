class_name ClassSelectMenu
extends CanvasLayer

## War Champions Multi-Screen Menu & In-Game Pause System:
## - HubScreen: War Champions 14v14 Cartoon Warfare crest, symmetrical faction banners, Offline Bots, Multiplayer Drawer.
## - ArmoryScreen: Symmetrical Royal vs National flags, 5 Class Cards, Live 3D Rotating Preview, Bottom Arsenal Strip.
## - SettingsScreen: Master/SFX/Music sliders, Mouse Sensitivity, Custom Skill/Widget Hotkeys, In-match Pause.
## - SkillsScreen: 6-tab Skills & Widgets Encyclopedia (Soldier, Gunner, Commando, Demolisher, Field Engineer, Widgets).

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

const HOTKEY_HINT_DEFAULT: String = "Clique em qualquer botão e pressione a tecla ou botão extra do mouse (ESC cancela):"
const HOTKEY_HINT_LISTENING: String = "Pressione a nova tecla ou botão extra do mouse... (ESC cancela)"
const HOTKEY_HINT_COLOR_DEFAULT: Color = Color(0.74, 0.84, 0.94)
const HOTKEY_HINT_COLOR_LISTENING: Color = Color(1.0, 0.86, 0.24)
const PREVIEW_ROTATE_SPEED: float = 0.85

@export var hotkeys_config_path: String = InputCmd.DEFAULT_HOTKEYS_PATH

static var current_mouse_sensitivity: float = 0.0024

var selected_team: int = NetworkManager.TEAM_ROYAL
var selected_class: int = NetworkManager.CLASS_SOLDIER
var current_screen: String = "hub"
var _in_match_mode: bool = false
var _pending_mode: String = "bots" # "bots", "host", "join"
var _settings_return_screen: String = "hub"
var _skills_return_screen: String = "hub"
var _skills_tab_class: int = 0
var _preview_weapon_slot: int = 0

## Screens
var _hub_screen: Control
var _armory_screen: Control
var _settings_screen: Control
var _skills_screen: Control

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
var _royal_flag_rect: TextureRect
var _national_flag_rect: TextureRect
var _royal_btn: Button
var _nat_btn: Button
var _royal_faction_card: PanelContainer
var _national_faction_card: PanelContainer
var _class_buttons: Array[Button] = []
var _class_cards: Array[PanelContainer] = []
var _class_card_portraits: Array[TextureRect] = []
var _lag_btn: Button
var _deploy_btn: Button
var _mp_card: PanelContainer
var _mp_drawer: VBoxContainer
var _hub_settings_btn: Button
var _hub_skills_btn: Button
var _armory_settings_btn: Button
var _armory_skills_btn: Button
var _weapon_variant_row: HBoxContainer
var _weapon_variant_selectors: Array[OptionButton] = []
var _arsenal_cards: Array[PanelContainer] = []
var _arsenal_preview_buttons: Array[Button] = []

## Live 3D Character Preview Elements
var _preview_viewport_container: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_world_root: Node3D
var _preview_camera: Camera3D
var _preview_key_light: DirectionalLight3D
var _preview_rim_light: DirectionalLight3D
var _preview_world_env: WorldEnvironment
var _preview_hero: HeroCharacter
var _preview_class_lbl: Label
var _preview_weapon_lbl: Label
var _last_preview_sig: String = ""

## Settings UI Elements
var _master_vol_slider: HSlider
var _sfx_vol_slider: HSlider
var _music_vol_slider: HSlider
var _sens_slider: HSlider
var _resume_btn: Button
var _leave_btn: Button
var _settings_back_btn: Button
var _settings_title: Label
var _hotkey_hint_lbl: Label
var _skill_hotkey_buttons: Array[Button] = []
var _widget_hotkey_buttons: Array[Button] = []
var _reset_hotkeys_btn: Button
var _listening_hotkey_kind: String = "" # "skill" | "widget" | ""
var _listening_hotkey_slot: int = -1

## Skills Guide UI Elements
var _skills_back_btn: Button
var _skills_tab_buttons: Array[Button] = []
var _skills_grid: GridContainer


func _ready() -> void:
	layer = 20
	add_to_group("class_select_menus")
	set_process(true)
	set_process_input(true)
	InputCmd.load_hotkeys_from_config(hotkeys_config_path)
	_build_ui()
	_refresh_summary()
	show_screen("hub")


func _exit_tree() -> void:
	_teardown_preview_viewport()


func _process(delta: float) -> void:
	if visible and current_screen == "armory" and _preview_hero != null and is_instance_valid(_preview_hero):
		_preview_hero.rotation.y = wrapf(_preview_hero.rotation.y + delta * PREVIEW_ROTATE_SPEED, 0.0, TAU)
		if _preview_hero.visual_root != null:
			_preview_hero.visual_root.rotation.y = _preview_hero.aim_yaw
		_preview_hero._animate_character(delta)


func _input(event: InputEvent) -> void:
	if _listening_hotkey_kind.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_cancel_hotkey_listen()
			get_viewport().set_input_as_handled()
			return
		if k.keycode in [KEY_CTRL, KEY_ALT, KEY_META]:
			return
		assign_hotkey_from_ui(_listening_hotkey_kind, _listening_hotkey_slot, k.keycode)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index >= MOUSE_BUTTON_XBUTTON1:
			assign_hotkey_from_ui(_listening_hotkey_kind, _listening_hotkey_slot, InputCmd.encode_mouse_button(mb.button_index))
			get_viewport().set_input_as_handled()


static func get_class_weapon_slots(p_class_id: int) -> Array[int]:
	match p_class_id:
		NetworkManager.CLASS_SOLDIER:
			return [WeaponBase.WeaponKind.SMG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.PISTOL, WeaponBase.WeaponKind.TNT]
		NetworkManager.CLASS_GUNNER:
			return [WeaponBase.WeaponKind.MG, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.BAZOOKA]
		NetworkManager.CLASS_DEMOLISHER:
			return [WeaponBase.WeaponKind.FLAMETHROWER, WeaponBase.WeaponKind.GRENADE_LAUNCHER, WeaponBase.WeaponKind.STICK_GRENADE]
		NetworkManager.CLASS_ENGINEER:
			return [WeaponBase.WeaponKind.DUAL_REVOLVERS, WeaponBase.WeaponKind.SHOTGUN, WeaponBase.WeaponKind.WELDING_TORCH]
		_:
			return [WeaponBase.WeaponKind.SNIPER, WeaponBase.WeaponKind.KNIFE, WeaponBase.WeaponKind.PISTOL, WeaponBase.WeaponKind.TNT]


static func _resolve_slot_weapon_kind(p_class_id: int, slot_idx: int, arch: int) -> int:
	var kinds: Array[int] = get_class_weapon_slots(p_class_id)
	if slot_idx < 0 or slot_idx >= kinds.size():
		return WeaponBase.WeaponKind.SMG
	if p_class_id == NetworkManager.CLASS_ENGINEER and slot_idx == 0:
		return WeaponBase.WeaponKind.DUAL_PISTOLS if arch >= 1 else WeaponBase.WeaponKind.DUAL_REVOLVERS
	return kinds[slot_idx]


static func _get_weapon_role_tag(w_kind: int) -> String:
	match w_kind:
		WeaponBase.WeaponKind.SMG:
			return "Submetralhadora"
		WeaponBase.WeaponKind.MG:
			return "Metralhadora"
		WeaponBase.WeaponKind.SHOTGUN:
			return "Escopeta"
		WeaponBase.WeaponKind.PISTOL:
			return "Pistola"
		WeaponBase.WeaponKind.SNIPER:
			return "Sniper"
		WeaponBase.WeaponKind.KNIFE:
			return "Corpo a Corpo"
		WeaponBase.WeaponKind.BAZOOKA:
			return "Antitanque"
		WeaponBase.WeaponKind.TNT:
			return "Explosivo"
		WeaponBase.WeaponKind.FLAMETHROWER:
			return "Lança-Chamas"
		WeaponBase.WeaponKind.GRENADE_LAUNCHER:
			return "Granadeiro"
		WeaponBase.WeaponKind.STICK_GRENADE:
			return "Explosivo / Melee"
		WeaponBase.WeaponKind.DUAL_REVOLVERS:
			return "Dupla Ação"
		WeaponBase.WeaponKind.DUAL_PISTOLS:
			return "Dupla Automática"
		WeaponBase.WeaponKind.WELDING_TORCH:
			return "Solda / Reparo"
		_:
			return "Arma"


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
	bg.color = Color(0.03, 0.06, 0.12, 0.94)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main_panel := PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(1040, 660)
	main_panel.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.12, 0.19, 0.98), Color(0.96, 0.78, 0.22), 3))
	center.add_child(main_panel)

	var main_margin := MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	main_margin.add_theme_constant_override("margin_top", 14)
	main_margin.add_theme_constant_override("margin_bottom", 14)
	main_panel.add_child(main_margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	main_margin.add_child(stack)

	_build_hub_screen(stack)
	_build_armory_screen(stack)
	_build_settings_screen(stack)
	_build_skills_screen(stack)


func _make_faction_banner_card(flag_key: String, title_text: String, sub_text: String, border_col: Color, title_col: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(218, 220)
	card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.10, 0.17, 0.95), border_col, 2))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 14)
	m.add_theme_constant_override("margin_bottom", 14)
	card.add_child(m)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	m.add_child(vb)

	var flag_rect := TextureRect.new()
	flag_rect.custom_minimum_size = Vector2(112, 74)
	flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	flag_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	flag_rect.texture = CartoonAssets.get_texture(flag_key)
	vb.add_child(flag_rect)

	var t_lbl := Label.new()
	t_lbl.text = title_text
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 17)
	t_lbl.add_theme_color_override("font_color", title_col)
	vb.add_child(t_lbl)

	var s_lbl := Label.new()
	s_lbl.text = sub_text
	s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s_lbl.add_theme_font_size_override("font_size", 12)
	s_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
	vb.add_child(s_lbl)

	return card


func _build_hub_screen(parent: Control) -> void:
	_hub_screen = VBoxContainer.new()
	_hub_screen.add_theme_constant_override("separation", 14)
	parent.add_child(_hub_screen)

	# 1. Crest / Header Banner Card
	var crest_card := PanelContainer.new()
	crest_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.05, 0.10, 0.18, 0.95), Color(0.96, 0.78, 0.22), 2))
	_hub_screen.add_child(crest_card)

	var crest_m := MarginContainer.new()
	crest_m.add_theme_constant_override("margin_left", 16)
	crest_m.add_theme_constant_override("margin_right", 16)
	crest_m.add_theme_constant_override("margin_top", 10)
	crest_m.add_theme_constant_override("margin_bottom", 10)
	crest_card.add_child(crest_m)

	var title_box := VBoxContainer.new()
	title_box.add_theme_constant_override("separation", 3)
	crest_m.add_child(title_box)

	var title := Label.new()
	title.text = "WAR CHAMPIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "14v14 Cartoon Warfare — Seaside Frontline"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.48, 0.88, 1.0))
	title_box.add_child(subtitle)

	var badge_lbl := Label.new()
	badge_lbl.text = "5 Classes Únicas • Veículos Terrestres, Aéreos & Navais • Conquista 6 Bandeiras"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
	title_box.add_child(badge_lbl)

	# 2. Symmetrical Royal vs National Banners framing the Mode Cards
	var arena_row := HBoxContainer.new()
	arena_row.alignment = BoxContainer.ALIGNMENT_CENTER
	arena_row.add_theme_constant_override("separation", 16)
	_hub_screen.add_child(arena_row)

	var royal_crest := _make_faction_banner_card(
		"flag_royal",
		"ROYAL ARMY",
		"Azul & Ouro\nDisciplina Tática & Aviação",
		Color(0.24, 0.56, 0.95),
		Color(0.48, 0.82, 1.0)
	)
	arena_row.add_child(royal_crest)

	var mode_box := VBoxContainer.new()
	mode_box.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_box.add_theme_constant_override("separation", 10)
	arena_row.add_child(mode_box)

	var solo_card := PanelContainer.new()
	solo_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.15, 0.24, 0.96), Color(0.95, 0.78, 0.24), 2))
	mode_box.add_child(solo_card)
	var solo_m := MarginContainer.new()
	solo_m.add_theme_constant_override("margin_left", 12)
	solo_m.add_theme_constant_override("margin_right", 12)
	solo_m.add_theme_constant_override("margin_top", 10)
	solo_m.add_theme_constant_override("margin_bottom", 10)
	solo_card.add_child(solo_m)
	var solo_v := VBoxContainer.new()
	solo_v.add_theme_constant_override("separation", 4)
	solo_m.add_child(solo_v)

	var solo_btn := Button.new()
	solo_btn.text = "Treino Offline 14v14 Bots"
	solo_btn.custom_minimum_size = Vector2(460, 46)
	solo_btn.add_theme_font_size_override("font_size", 16)
	solo_btn.pressed.connect(func() -> void:
		_pending_mode = "bots"
		show_screen("armory")
	)
	solo_v.add_child(solo_btn)

	var solo_sub := Label.new()
	solo_sub.text = "Partida instantânea 14v14 com todas as 5 classes e bots inteligentes"
	solo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	solo_sub.add_theme_font_size_override("font_size", 11)
	solo_sub.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96))
	solo_v.add_child(solo_sub)

	var mp_toggle_card := PanelContainer.new()
	mp_toggle_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.13, 0.22, 0.96), Color(0.32, 0.68, 0.95), 2))
	mode_box.add_child(mp_toggle_card)
	var mp_tm := MarginContainer.new()
	mp_tm.add_theme_constant_override("margin_left", 12)
	mp_tm.add_theme_constant_override("margin_right", 12)
	mp_tm.add_theme_constant_override("margin_top", 10)
	mp_tm.add_theme_constant_override("margin_bottom", 10)
	mp_toggle_card.add_child(mp_tm)
	var mp_tv := VBoxContainer.new()
	mp_tv.add_theme_constant_override("separation", 4)
	mp_tm.add_child(mp_tv)

	var mp_toggle_btn := Button.new()
	mp_toggle_btn.text = "Multiplayer Online"
	mp_toggle_btn.custom_minimum_size = Vector2(460, 44)
	mp_toggle_btn.add_theme_font_size_override("font_size", 16)
	mp_toggle_btn.pressed.connect(func() -> void:
		_mp_card.visible = not _mp_card.visible
	)
	mp_tv.add_child(mp_toggle_btn)

	var mp_sub := Label.new()
	mp_sub.text = "Hospede ou conecte-se a uma sala 14v14 via IP / UDP"
	mp_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_sub.add_theme_font_size_override("font_size", 11)
	mp_sub.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96))
	mp_tv.add_child(mp_sub)

	var nat_crest := _make_faction_banner_card(
		"flag_national",
		"NATIONAL ARMY",
		"Chumbo & Carmesim\nBlindagem & Poder de Fogo",
		Color(0.88, 0.24, 0.22),
		Color(1.0, 0.46, 0.44)
	)
	arena_row.add_child(nat_crest)

	# 3. Multiplayer Drawer Panel (starts collapsed)
	_mp_card = PanelContainer.new()
	_mp_card.visible = false
	_mp_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.16, 0.26, 0.95), Color(0.30, 0.72, 1.0), 2))
	_hub_screen.add_child(_mp_card)

	var mp_m := MarginContainer.new()
	mp_m.add_theme_constant_override("margin_left", 14)
	mp_m.add_theme_constant_override("margin_right", 14)
	mp_m.add_theme_constant_override("margin_top", 8)
	mp_m.add_theme_constant_override("margin_bottom", 8)
	_mp_card.add_child(mp_m)

	_mp_drawer = VBoxContainer.new()
	_mp_drawer.add_theme_constant_override("separation", 6)
	mp_m.add_child(_mp_drawer)

	var mp_hdr := Label.new()
	mp_hdr.text = "CONEXÃO MULTIPLAYER ONLINE (14v14 Servidor Dedicado)"
	mp_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_hdr.add_theme_font_size_override("font_size", 14)
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
	_ip_input.custom_minimum_size = Vector2(170, 32)
	ip_row.add_child(_ip_input)

	var port_lbl := Label.new()
	port_lbl.text = "Porta UDP:"
	ip_row.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = "7777"
	_port_input.custom_minimum_size = Vector2(75, 32)
	ip_row.add_child(_port_input)

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
	host_btn.custom_minimum_size = Vector2(220, 34)
	host_btn.pressed.connect(func() -> void:
		_pending_mode = "host"
		show_screen("armory")
	)
	mp_act_row.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Entrar no Servidor"
	join_btn.custom_minimum_size = Vector2(220, 34)
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
	armory_btn.custom_minimum_size = Vector2(195, 40)
	armory_btn.pressed.connect(func() -> void:
		show_screen("armory")
	)
	nav_row.add_child(armory_btn)

	_hub_skills_btn = Button.new()
	_hub_skills_btn.text = "Habilidades"
	_hub_skills_btn.custom_minimum_size = Vector2(180, 40)
	_hub_skills_btn.pressed.connect(func() -> void:
		_skills_return_screen = "hub"
		_skills_tab_class = selected_class
		show_screen("skills")
	)
	nav_row.add_child(_hub_skills_btn)

	_hub_settings_btn = Button.new()
	_hub_settings_btn.text = "Atalhos (Hotkeys) & Config"
	_hub_settings_btn.custom_minimum_size = Vector2(225, 40)
	_hub_settings_btn.pressed.connect(func() -> void:
		_settings_return_screen = "hub"
		show_screen("settings")
	)
	nav_row.add_child(_hub_settings_btn)

	_lag_btn = Button.new()
	_lag_btn.text = "Simulador de Lag: OFF (0ms)"
	_lag_btn.custom_minimum_size = Vector2(245, 40)
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
	_armory_screen.add_theme_constant_override("separation", 6)
	parent.add_child(_armory_screen)

	# 1. Header with Back button
	var arm_top := HBoxContainer.new()
	_armory_screen.add_child(arm_top)

	var back_btn := Button.new()
	back_btn.text = "<- Voltar ao Hub"
	back_btn.custom_minimum_size = Vector2(150, 34)
	back_btn.pressed.connect(func() -> void:
		show_screen("hub")
	)
	arm_top.add_child(back_btn)

	var arm_title := Label.new()
	arm_title.text = "ARSENAL DE COMBATE — FAÇÃO & CLASSE"
	arm_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arm_title.add_theme_font_size_override("font_size", 20)
	arm_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	arm_top.add_child(arm_title)

	_armory_skills_btn = Button.new()
	_armory_skills_btn.text = "Ver Habilidades"
	_armory_skills_btn.custom_minimum_size = Vector2(150, 34)
	_armory_skills_btn.pressed.connect(func() -> void:
		_skills_return_screen = "armory"
		_skills_tab_class = selected_class
		show_screen("skills")
	)
	arm_top.add_child(_armory_skills_btn)

	_armory_settings_btn = Button.new()
	_armory_settings_btn.text = "Atalhos (Hotkeys)"
	_armory_settings_btn.custom_minimum_size = Vector2(160, 34)
	_armory_settings_btn.pressed.connect(func() -> void:
		_settings_return_screen = "armory"
		show_screen("settings")
	)
	arm_top.add_child(_armory_settings_btn)

	# 2. Symmetrical Top Faction Selector (Royal Flag + Button | National Button + Flag)
	var fac_box := HBoxContainer.new()
	fac_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fac_box.add_theme_constant_override("separation", 18)
	_armory_screen.add_child(fac_box)

	_royal_faction_card = PanelContainer.new()
	_royal_faction_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.13, 0.24, 0.95), Color(0.28, 0.62, 1.0), 2))
	fac_box.add_child(_royal_faction_card)
	var r_row := HBoxContainer.new()
	r_row.add_theme_constant_override("separation", 10)
	_royal_faction_card.add_child(r_row)

	_royal_flag_rect = TextureRect.new()
	_royal_flag_rect.custom_minimum_size = Vector2(64, 42)
	_royal_flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_royal_flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_royal_flag_rect.texture = CartoonAssets.get_texture("flag_royal")
	r_row.add_child(_royal_flag_rect)

	_royal_btn = Button.new()
	_royal_btn.text = "ROYAL ARMY\n(Aliados Azul / Ouro)"
	_royal_btn.custom_minimum_size = Vector2(236, 44)
	_royal_btn.pressed.connect(func() -> void:
		select_team(NetworkManager.TEAM_ROYAL)
	)
	r_row.add_child(_royal_btn)

	_national_faction_card = PanelContainer.new()
	_national_faction_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.18, 0.08, 0.11, 0.95), Color(0.88, 0.24, 0.24), 2))
	fac_box.add_child(_national_faction_card)
	var n_row := HBoxContainer.new()
	n_row.add_theme_constant_override("separation", 10)
	_national_faction_card.add_child(n_row)

	_nat_btn = Button.new()
	_nat_btn.text = "NATIONAL ARMY\n(Cinza Chumbo / Carmesim)"
	_nat_btn.custom_minimum_size = Vector2(236, 44)
	_nat_btn.pressed.connect(func() -> void:
		select_team(NetworkManager.TEAM_NATIONAL)
	)
	n_row.add_child(_nat_btn)

	_national_flag_rect = TextureRect.new()
	_national_flag_rect.custom_minimum_size = Vector2(64, 42)
	_national_flag_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_national_flag_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_national_flag_rect.texture = CartoonAssets.get_texture("flag_national")
	n_row.add_child(_national_flag_rect)

	# 3. Main Center Split: Left 5 Class Cards | Right Live 3D Rotating Character Preview
	var center_split := HBoxContainer.new()
	center_split.add_theme_constant_override("separation", 12)
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_armory_screen.add_child(center_split)

	var classes_col := VBoxContainer.new()
	classes_col.custom_minimum_size = Vector2(656, 306)
	classes_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	classes_col.add_theme_constant_override("separation", 5)
	center_split.add_child(classes_col)

	var class_info: Array[Dictionary] = [
		{
			"id": NetworkManager.CLASS_SOLDIER,
			"name": "SOLDIER",
			"stats": "HP: 110  |  Vel: 6.3 m/s",
			"role": "Assalto • SMG, Shotgun, Pistola, TNT",
			"col": Color(0.24, 0.56, 0.88),
		},
		{
			"id": NetworkManager.CLASS_GUNNER,
			"name": "GUNNER",
			"stats": "HP: 150  |  Vel: 5.4 m/s",
			"role": "Tanque • Metralhadora MG, Shotgun, Bazooka",
			"col": Color(0.76, 0.46, 0.16),
		},
		{
			"id": NetworkManager.CLASS_COMMANDO,
			"name": "COMMANDO",
			"stats": "HP: 80   |  Vel: 7.2 m/s",
			"role": "Furtivo • Sniper, Faca, Pistola, TNT",
			"col": Color(0.54, 0.24, 0.72),
		},
		{
			"id": NetworkManager.CLASS_DEMOLISHER,
			"name": "DEMOLISHER",
			"stats": "HP: 110  |  Vel: 5.4 m/s",
			"role": "Demolição • Lança-Chamas, Granadeiro, Escudo",
			"col": Color(0.86, 0.38, 0.14),
		},
		{
			"id": NetworkManager.CLASS_ENGINEER,
			"name": "FIELD ENGINEER",
			"stats": "HP: 125  |  Vel: 6.3 m/s",
			"role": "Suporte • 2 Revólveres/Pistolas, Shotgun, Maçarico",
			"col": Color(0.86, 0.68, 0.18),
		},
	]

	_class_buttons.clear()
	_class_cards.clear()
	_class_card_portraits.clear()

	for info in class_info:
		var cid: int = int(info["id"])
		var c_card := PanelContainer.new()
		c_card.custom_minimum_size = Vector2(640, 56)
		c_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.11, 0.18, 0.95), info["col"], 2))
		classes_col.add_child(c_card)
		_class_cards.append(c_card)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 8)
		cm.add_theme_constant_override("margin_right", 8)
		cm.add_theme_constant_override("margin_top", 5)
		cm.add_theme_constant_override("margin_bottom", 5)
		c_card.add_child(cm)

		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 10)
		cm.add_child(ch)

		var c_portrait := TextureRect.new()
		c_portrait.custom_minimum_size = Vector2(42, 42)
		c_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c_portrait.texture = CartoonAssets.get_texture("portrait_royal_%d" % cid)
		ch.add_child(c_portrait)
		_class_card_portraits.append(c_portrait)

		var text_v := VBoxContainer.new()
		text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_v.add_theme_constant_override("separation", 1)
		ch.add_child(text_v)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 10)
		text_v.add_child(top_line)

		var name_lbl := Label.new()
		name_lbl.text = str(info["name"])
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.38))
		top_line.add_child(name_lbl)

		var stat_lbl := Label.new()
		stat_lbl.text = str(info["stats"])
		stat_lbl.add_theme_font_size_override("font_size", 12)
		stat_lbl.add_theme_color_override("font_color", Color(0.58, 0.92, 1.0))
		top_line.add_child(stat_lbl)

		var role_lbl := Label.new()
		role_lbl.text = str(info["role"])
		role_lbl.add_theme_font_size_override("font_size", 11)
		role_lbl.add_theme_color_override("font_color", Color(0.84, 0.90, 0.96))
		text_v.add_child(role_lbl)

		var c_btn := Button.new()
		c_btn.text = "SELECIONAR"
		c_btn.custom_minimum_size = Vector2(126, 36)
		c_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		c_btn.add_theme_font_size_override("font_size", 12)
		c_btn.pressed.connect(func() -> void:
			select_class(cid)
		)
		ch.add_child(c_btn)
		_class_buttons.append(c_btn)

	# Right Showcase Column: Hero Preview Info Header + Live 3D Rotating SubViewport
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(328, 306)
	preview_panel.add_theme_stylebox_override("panel", _make_card_style(Color(0.05, 0.09, 0.15, 0.98), Color(0.36, 0.62, 0.88), 2))
	center_split.add_child(preview_panel)

	var pm := MarginContainer.new()
	pm.add_theme_constant_override("margin_left", 8)
	pm.add_theme_constant_override("margin_right", 8)
	pm.add_theme_constant_override("margin_top", 8)
	pm.add_theme_constant_override("margin_bottom", 8)
	preview_panel.add_child(pm)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	pm.add_child(pv)

	var p_hdr := HBoxContainer.new()
	p_hdr.add_theme_constant_override("separation", 8)
	pv.add_child(p_hdr)

	_preview_portrait = TextureRect.new()
	_preview_portrait.custom_minimum_size = Vector2(44, 44)
	_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p_hdr.add_child(_preview_portrait)

	var p_hdr_text := VBoxContainer.new()
	p_hdr_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_hdr_text.add_theme_constant_override("separation", 1)
	p_hdr.add_child(p_hdr_text)

	_preview_class_lbl = Label.new()
	_preview_class_lbl.text = "SOLDIER"
	_preview_class_lbl.add_theme_font_size_override("font_size", 14)
	_preview_class_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	p_hdr_text.add_child(_preview_class_lbl)

	_preview_weapon_lbl = Label.new()
	_preview_weapon_lbl.text = "Empunhando: SMG"
	_preview_weapon_lbl.add_theme_font_size_override("font_size", 11)
	_preview_weapon_lbl.add_theme_color_override("font_color", Color(0.62, 0.90, 1.0))
	p_hdr_text.add_child(_preview_weapon_lbl)

	_preview_flag = TextureRect.new()
	_preview_flag.custom_minimum_size = Vector2(40, 28)
	_preview_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p_hdr.add_child(_preview_flag)

	_build_preview_viewport(pv)

	# 4. Bottom Arsenal Strip Underneath (96x64 Weapon Icons, Names, Role Badges & Variant Selectors)
	var var_card := PanelContainer.new()
	var_card.custom_minimum_size = Vector2(980, 134)
	var_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.06, 0.10, 0.16, 0.96), Color(0.35, 0.50, 0.70), 2))
	_armory_screen.add_child(var_card)

	var vm := MarginContainer.new()
	vm.add_theme_constant_override("margin_left", 10)
	vm.add_theme_constant_override("margin_right", 10)
	vm.add_theme_constant_override("margin_top", 6)
	vm.add_theme_constant_override("margin_bottom", 6)
	var_card.add_child(vm)

	var v_outer := VBoxContainer.new()
	v_outer.add_theme_constant_override("separation", 5)
	vm.add_child(v_outer)

	var var_hdr := Label.new()
	var_hdr.text = "ARSENAL DA CLASSE — CLIQUE EM UMA ARMA PARA VISUALIZAR EM 3D OU ESCOLHA A VARIANTE:"
	var_hdr.add_theme_font_size_override("font_size", 11)
	var_hdr.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	v_outer.add_child(var_hdr)

	_weapon_variant_row = HBoxContainer.new()
	_weapon_variant_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_weapon_variant_row.add_theme_constant_override("separation", 8)
	v_outer.add_child(_weapon_variant_row)

	# 5. Summary + Deploy Footer Row
	var footer_row := HBoxContainer.new()
	footer_row.add_theme_constant_override("separation", 12)
	_armory_screen.add_child(footer_row)

	_summary_lbl = Label.new()
	_summary_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.add_theme_font_size_override("font_size", 13)
	_summary_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	footer_row.add_child(_summary_lbl)

	_deploy_btn = Button.new()
	_deploy_btn.text = "ENTRAR NA BATALHA"
	_deploy_btn.custom_minimum_size = Vector2(280, 42)
	_deploy_btn.add_theme_font_size_override("font_size", 15)
	_deploy_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.40))
	_deploy_btn.pressed.connect(_on_deploy_clicked)
	footer_row.add_child(_deploy_btn)


func _build_preview_viewport(parent: Control) -> void:
	_preview_viewport_container = SubViewportContainer.new()
	_preview_viewport_container.custom_minimum_size = Vector2(312, 236)
	_preview_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_viewport_container.stretch = true
	parent.add_child(_preview_viewport_container)

	_preview_viewport = SubViewport.new()
	_preview_viewport.own_world_3d = true
	_preview_viewport.transparent_bg = false
	_preview_viewport.msaa_3d = Viewport.MSAA_2X
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview_viewport_container.add_child(_preview_viewport)

	_preview_world_root = Node3D.new()
	_preview_world_root.name = "PreviewWorld"
	_preview_viewport.add_child(_preview_world_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.10, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.75
	_preview_world_env = WorldEnvironment.new()
	_preview_world_env.environment = env
	_preview_world_root.add_child(_preview_world_env)

	_preview_key_light = DirectionalLight3D.new()
	_preview_key_light.light_color = Color(1.0, 0.96, 0.90)
	_preview_key_light.light_energy = 1.45
	_preview_key_light.rotation_degrees = Vector3(-32.0, 28.0, 0.0)
	_preview_world_root.add_child(_preview_key_light)

	_preview_rim_light = DirectionalLight3D.new()
	_preview_rim_light.light_color = Color(0.52, 0.78, 1.0)
	_preview_rim_light.light_energy = 0.80
	_preview_rim_light.rotation_degrees = Vector3(-18.0, -145.0, 0.0)
	_preview_world_root.add_child(_preview_rim_light)

	_preview_camera = Camera3D.new()
	_preview_camera.fov = 38.0
	_preview_camera.position = Vector3(0.0, 1.06, 3.15)
	_preview_camera.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	_preview_camera.current = true
	_preview_world_root.add_child(_preview_camera)

	var pedestal := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.72
	cyl.bottom_radius = 0.80
	cyl.height = 0.10
	pedestal.mesh = cyl
	pedestal.position = Vector3(0.0, -0.05, 0.0)
	var ped_mat := StandardMaterial3D.new()
	ped_mat.albedo_color = Color(0.14, 0.20, 0.30)
	ped_mat.metallic = 0.35
	ped_mat.roughness = 0.45
	pedestal.material_override = ped_mat
	_preview_world_root.add_child(pedestal)

	_preview_hero = HeroCharacter.new()
	_preview_hero.is_local_player = false
	_preview_hero.is_bot = false
	_preview_world_root.add_child(_preview_hero)
	_preview_hero.set_process(false)
	_preview_hero.set_physics_process(false)
	_preview_hero.collision_layer = 0
	_preview_hero.collision_mask = 0
	_preview_hero.aim_yaw = PI
	if _preview_hero.visual_root != null:
		_preview_hero.visual_root.rotation.y = _preview_hero.aim_yaw


func _teardown_preview_viewport() -> void:
	if _preview_hero != null and is_instance_valid(_preview_hero):
		var hp: Node = _preview_hero.get_parent()
		if hp != null:
			hp.remove_child(_preview_hero)
		_preview_hero.queue_free()
		_preview_hero = null
	if _preview_world_root != null and is_instance_valid(_preview_world_root):
		for child in _preview_world_root.get_children():
			_preview_world_root.remove_child(child)
			child.queue_free()
		var wp: Node = _preview_world_root.get_parent()
		if wp != null:
			wp.remove_child(_preview_world_root)
		_preview_world_root.queue_free()
		_preview_world_root = null
	if _preview_viewport != null and is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _sync_preview_hero() -> void:
	if _preview_hero == null or not is_instance_valid(_preview_hero):
		return
	var cid: int = clampi(selected_class, 0, 4)
	var slot_archs: Dictionary = NetworkManager.build_class_slot_archetypes(cid)
	var sig_parts: PackedStringArray = [str(selected_team), str(cid)]
	var kinds: Array[int] = get_class_weapon_slots(cid)
	for s_i in range(kinds.size()):
		sig_parts.append(str(slot_archs.get(s_i, 0)))
	var sig: String = "|".join(sig_parts)

	if sig != _last_preview_sig:
		_last_preview_sig = sig
		_preview_hero.setup_identity(0, "PreviewHero", selected_team, cid, 0, false, false, slot_archs)
		_preview_hero.set_process(false)
		_preview_hero.set_physics_process(false)
		_preview_hero.collision_layer = 0
		_preview_hero.collision_mask = 0
		_preview_hero.aim_yaw = PI
		if _preview_hero.visual_root != null:
			_preview_hero.visual_root.rotation.y = _preview_hero.aim_yaw

	var safe_slot: int = clampi(_preview_weapon_slot, 0, maxi(0, _preview_hero.weapons.size() - 1))
	_preview_weapon_slot = safe_slot
	_preview_hero.selected_weapon_slot = safe_slot
	_preview_hero._shown_weapon_kind = -1
	_preview_hero._rebuild_held_weapon_mesh()
	_preview_hero._animate_character(0.016)

	if _preview_weapon_lbl != null and safe_slot < _preview_hero.weapons.size():
		var w_node := _preview_hero.weapons[safe_slot] as WeaponBase
		if w_node != null:
			_preview_weapon_lbl.text = "Empunhando: %s" % w_node.weapon_name


func select_preview_weapon_slot(slot_idx: int) -> void:
	var cid: int = clampi(selected_class, 0, 4)
	var kinds: Array[int] = get_class_weapon_slots(cid)
	_preview_weapon_slot = clampi(slot_idx, 0, maxi(0, kinds.size() - 1))
	_sync_preview_hero()
	_refresh_arsenal_highlights()


func _refresh_arsenal_highlights() -> void:
	for i in range(_arsenal_cards.size()):
		var is_sel: bool = (i == _preview_weapon_slot)
		var sb: StyleBoxFlat = _arsenal_cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = Color(1.0, 0.86, 0.24) if is_sel else Color(0.28, 0.44, 0.64)
			sb.bg_color = Color(0.10, 0.17, 0.28, 0.98) if is_sel else Color(0.07, 0.11, 0.18, 0.95)
	for i in range(_arsenal_preview_buttons.size()):
		var is_sel_btn: bool = (i == _preview_weapon_slot)
		_arsenal_preview_buttons[i].text = "3D ATIVO" if is_sel_btn else "Ver 3D"
		_arsenal_preview_buttons[i].modulate = Color(1.0, 0.94, 0.50) if is_sel_btn else Color(0.82, 0.88, 0.96)


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
	_settings_back_btn.custom_minimum_size = Vector2(180, 36)
	_settings_back_btn.pressed.connect(func() -> void:
		show_screen(_settings_return_screen if _settings_return_screen == "armory" else "hub")
	)
	st_top.add_child(_settings_back_btn)

	_settings_title = Label.new()
	_settings_title.text = "CONFIGURAÇÕES & ATALHOS (HOTKEYS)"
	_settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_title.add_theme_font_size_override("font_size", 22)
	_settings_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	st_top.add_child(_settings_title)

	var st_spacer := Control.new()
	st_spacer.custom_minimum_size = Vector2(180, 36)
	st_top.add_child(st_spacer)

	# Sliders & Controls layout
	var sets_box := HBoxContainer.new()
	sets_box.add_theme_constant_override("separation", 18)
	_settings_screen.add_child(sets_box)

	# Left Column: Audio & Sensitivity Sliders
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(430, 410)
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
	right_card.custom_minimum_size = Vector2(540, 410)
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_reset_hotkeys_btn.custom_minimum_size = Vector2(142, 26)
	_reset_hotkeys_btn.pressed.connect(func() -> void:
		InputCmd.reset_default_hotkeys()
		InputCmd.save_hotkeys_to_config(hotkeys_config_path)
		_cancel_hotkey_listen()
		_refresh_hotkey_buttons()
		_notify_hud_hotkeys_changed()
	)
	bind_hdr_row.add_child(_reset_hotkeys_btn)

	_hotkey_hint_lbl = Label.new()
	_hotkey_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hotkey_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_set_hotkey_hint(false)
	rv.add_child(_hotkey_hint_lbl)

	var sk_grid := GridContainer.new()
	sk_grid.columns = 3
	sk_grid.add_theme_constant_override("h_separation", 8)
	sk_grid.add_theme_constant_override("v_separation", 5)
	rv.add_child(sk_grid)

	_skill_hotkey_buttons.clear()
	for s_i in range(6):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(158, 28)
		var captured_s: int = s_i
		btn.pressed.connect(func() -> void:
			_begin_hotkey_listen("skill", captured_s)
		)
		sk_grid.add_child(btn)
		_skill_hotkey_buttons.append(btn)

	var wd_grid := GridContainer.new()
	wd_grid.columns = 2
	wd_grid.add_theme_constant_override("h_separation", 8)
	wd_grid.add_theme_constant_override("v_separation", 5)
	rv.add_child(wd_grid)

	_widget_hotkey_buttons.clear()
	for w_i in range(4):
		var wbtn := Button.new()
		wbtn.custom_minimum_size = Vector2(240, 28)
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
		"• 1..4: Armas | Q: Última Arma | R: Recarregar | ALT: Cursor / Reorganizar Barra\n" +
		"• E: Entrar/Sair Veículo | F1..F4: Trocar Assento | Botão Direito: Mirar\n" +
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


func _build_skills_screen(parent: Control) -> void:
	_skills_screen = VBoxContainer.new()
	_skills_screen.visible = false
	_skills_screen.add_theme_constant_override("separation", 10)
	parent.add_child(_skills_screen)

	var sk_top := HBoxContainer.new()
	_skills_screen.add_child(sk_top)

	_skills_back_btn = Button.new()
	_skills_back_btn.text = "<- Voltar ao Hub"
	_skills_back_btn.custom_minimum_size = Vector2(180, 36)
	_skills_back_btn.pressed.connect(func() -> void:
		show_screen(_skills_return_screen if _skills_return_screen == "armory" else "hub")
	)
	sk_top.add_child(_skills_back_btn)

	var sk_title := Label.new()
	sk_title.text = "ENCICLOPÉDIA DE HABILIDADES (NÍVEL MÁXIMO R5)"
	sk_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sk_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sk_title.add_theme_font_size_override("font_size", 20)
	sk_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	sk_top.add_child(sk_title)

	var sk_spacer := Control.new()
	sk_spacer.custom_minimum_size = Vector2(180, 36)
	sk_top.add_child(sk_spacer)

	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 8)
	_skills_screen.add_child(tab_row)

	var tab_labels: Array[String] = [
		"Soldier (5)",
		"Gunner (5)",
		"Commando (6)",
		"Demolisher (5)",
		"Field Engineer (5)",
		"Itens / Widgets (4)",
	]
	_skills_tab_buttons.clear()
	for tab_i in range(tab_labels.size()):
		var t_btn := Button.new()
		t_btn.text = tab_labels[tab_i]
		t_btn.custom_minimum_size = Vector2(152, 34)
		var cap_tab: int = tab_i
		t_btn.pressed.connect(func() -> void:
			select_skills_tab(cap_tab)
		)
		tab_row.add_child(t_btn)
		_skills_tab_buttons.append(t_btn)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(960, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_skills_screen.add_child(scroll)

	_skills_grid = GridContainer.new()
	_skills_grid.columns = 2
	_skills_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_grid.add_theme_constant_override("h_separation", 12)
	_skills_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_skills_grid)


func select_skills_tab(tab_idx: int) -> void:
	_skills_tab_class = clampi(tab_idx, 0, 5)
	_rebuild_skills_grid()


func _rebuild_skills_grid() -> void:
	var tab_colors: Array[Color] = [
		Color(0.24, 0.56, 0.88),
		Color(0.86, 0.52, 0.18),
		Color(0.58, 0.30, 0.82),
		Color(0.90, 0.38, 0.16),
		Color(0.86, 0.68, 0.18),
		Color(0.24, 0.74, 0.44),
	]
	for i in range(_skills_tab_buttons.size()):
		var is_active: bool = (i == _skills_tab_class)
		_skills_tab_buttons[i].modulate = Color(1.0, 0.96, 0.75) if is_active else Color(0.65, 0.70, 0.78)
		_skills_tab_buttons[i].add_theme_color_override(
			"font_color",
			Color(1.0, 0.88, 0.32) if is_active else Color(0.86, 0.90, 0.96)
		)

	if _skills_grid == null:
		return
	for child in _skills_grid.get_children():
		_skills_grid.remove_child(child)
		child.queue_free()

	var entries: Array[Dictionary] = (
		SkillCatalog.get_widgets()
		if _skills_tab_class == 5
		else SkillCatalog.get_class_skills(_skills_tab_class)
	)
	var accent_col: Color = tab_colors[clampi(_skills_tab_class, 0, tab_colors.size() - 1)]

	for entry in entries:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(464, 122)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.11, 0.18, 0.96), accent_col, 2))
		_skills_grid.add_child(card)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 10)
		cm.add_theme_constant_override("margin_right", 10)
		cm.add_theme_constant_override("margin_top", 8)
		cm.add_theme_constant_override("margin_bottom", 8)
		card.add_child(cm)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		cm.add_child(row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.texture = CartoonAssets.get_texture(str(entry.get("icon", "")))
		row.add_child(icon_rect)

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.add_theme_constant_override("separation", 3)
		row.add_child(info_v)

		var hdr_row := HBoxContainer.new()
		hdr_row.add_theme_constant_override("separation", 8)
		info_v.add_child(hdr_row)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", ""))
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36))
		hdr_row.add_child(name_lbl)

		var cat_lbl := Label.new()
		cat_lbl.text = "[%s]" % str(entry.get("category", ""))
		cat_lbl.add_theme_font_size_override("font_size", 11)
		cat_lbl.add_theme_color_override("font_color", Color(0.48, 0.90, 1.0))
		cat_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr_row.add_child(cat_lbl)

		var stats_lbl := Label.new()
		stats_lbl.text = "Recarga: %s | Duração: %s | Área: %s\nEfeito: %s" % [
			str(entry.get("cooldown", "")),
			str(entry.get("duration", "")),
			str(entry.get("area", "")),
			str(entry.get("effect_stats", "")),
		]
		stats_lbl.add_theme_font_size_override("font_size", 11)
		stats_lbl.add_theme_color_override("font_color", Color(0.82, 0.94, 0.74))
		stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_v.add_child(stats_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = str(entry.get("description", ""))
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_v.add_child(desc_lbl)


func show_screen(screen_name: String) -> void:
	current_screen = screen_name
	if screen_name != "settings" and is_listening_hotkey():
		_cancel_hotkey_listen()
	if _hub_screen != null:
		_hub_screen.visible = (screen_name == "hub")
	if _armory_screen != null:
		_armory_screen.visible = (screen_name == "armory")
	if _settings_screen != null:
		_settings_screen.visible = (screen_name == "settings")
	if _skills_screen != null:
		_skills_screen.visible = (screen_name == "skills")
	if _preview_viewport != null and is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if (visible and screen_name == "armory") else SubViewport.UPDATE_DISABLED
		)
	if screen_name == "armory":
		_refresh_summary()
	elif screen_name == "settings":
		_refresh_hotkey_buttons()
		if _settings_back_btn != null:
			_settings_back_btn.text = "<- Voltar ao Arsenal" if _settings_return_screen == "armory" else "<- Voltar ao Hub"
	elif screen_name == "skills":
		if _skills_back_btn != null:
			_skills_back_btn.text = "<- Voltar ao Arsenal" if _skills_return_screen == "armory" else "<- Voltar ao Hub"
		_rebuild_skills_grid()


func set_in_match_mode(in_match: bool) -> void:
	_in_match_mode = in_match
	if _resume_btn != null:
		_resume_btn.visible = in_match
	if _leave_btn != null:
		_leave_btn.visible = in_match
	if _settings_back_btn != null:
		_settings_back_btn.visible = not in_match
	if _settings_title != null:
		_settings_title.text = "PAUSA — CONFIGURAÇÕES" if in_match else "CONFIGURAÇÕES & ATALHOS (HOTKEYS)"


func select_team(p_team: int) -> void:
	selected_team = clampi(p_team, 0, 1)
	_refresh_summary()
	team_selected.emit(selected_team)


func select_class(p_class_id: int) -> void:
	var clamped: int = clampi(p_class_id, 0, 4)
	if clamped != selected_class:
		_preview_weapon_slot = 0
	selected_class = clamped
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
		_preview_weapon_slot = slot_idx
		_refresh_summary()


func _rebuild_weapon_variant_selectors() -> void:
	if _weapon_variant_row == null:
		return
	for child in _weapon_variant_row.get_children():
		_weapon_variant_row.remove_child(child)
		child.queue_free()
	_weapon_variant_selectors.clear()
	_arsenal_cards.clear()
	_arsenal_preview_buttons.clear()

	var kinds: Array[int] = get_class_weapon_slots(selected_class)
	var arch_tags: Array[String] = ["Equilibrada", "Cadência+", "Precisão+"]
	var card_min_w: float = 228.0 if kinds.size() >= 4 else 306.0

	for slot_idx in range(kinds.size()):
		var w_kind: int = kinds[slot_idx]
		var cur_arch: int = NetworkManager.get_slot_archetype(selected_class, slot_idx, NetworkManager.ARCHETYPE_BALANCED)
		var eff_kind: int = _resolve_slot_weapon_kind(selected_class, slot_idx, cur_arch)
		var eff_arch: int = 0 if (selected_class == NetworkManager.CLASS_ENGINEER and slot_idx == 0) else clampi(cur_arch, 0, 2)
		var w_display: String = WeaponBase.get_variant_display_name(eff_kind, eff_arch)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(card_min_w, 102)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _make_card_style(Color(0.07, 0.11, 0.18, 0.95), Color(0.28, 0.44, 0.64), 2))
		var cap_card_slot: int = slot_idx
		card.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton:
				var mb := ev as InputEventMouseButton
				if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
					select_preview_weapon_slot(cap_card_slot)
		)
		_weapon_variant_row.add_child(card)
		_arsenal_cards.append(card)

		var cm := MarginContainer.new()
		cm.add_theme_constant_override("margin_left", 7)
		cm.add_theme_constant_override("margin_right", 7)
		cm.add_theme_constant_override("margin_top", 5)
		cm.add_theme_constant_override("margin_bottom", 5)
		cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cm)

		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 4)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cm.add_child(cv)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(top_row)

		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(96, 64)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = CartoonAssets.get_texture("icon_weapon_%d_%d" % [eff_kind, eff_arch])
		top_row.add_child(icon_rect)

		var meta_v := VBoxContainer.new()
		meta_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		meta_v.add_theme_constant_override("separation", 2)
		meta_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_child(meta_v)

		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 4)
		badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_v.add_child(badge_row)

		var role_lbl := Label.new()
		role_lbl.text = "[%d] %s" % [slot_idx + 1, _get_weapon_role_tag(eff_kind)]
		role_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		role_lbl.add_theme_font_size_override("font_size", 10)
		role_lbl.add_theme_color_override("font_color", Color(0.54, 0.88, 1.0))
		role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_row.add_child(role_lbl)

		var prev_btn := Button.new()
		prev_btn.text = "Ver 3D"
		prev_btn.custom_minimum_size = Vector2(56, 20)
		prev_btn.add_theme_font_size_override("font_size", 10)
		prev_btn.pressed.connect(func() -> void:
			select_preview_weapon_slot(cap_card_slot)
		)
		badge_row.add_child(prev_btn)
		_arsenal_preview_buttons.append(prev_btn)

		var w_name_lbl := Label.new()
		w_name_lbl.text = w_display
		w_name_lbl.add_theme_font_size_override("font_size", 12)
		w_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.36))
		w_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta_v.add_child(w_name_lbl)

		var opt := OptionButton.new()
		opt.custom_minimum_size = Vector2(180, 26)
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if selected_class == NetworkManager.CLASS_ENGINEER and slot_idx == 0:
			opt.add_item("2 Revólveres", 0)
			opt.add_item("2 Pistolas", 1)
			opt.selected = 0 if cur_arch == 0 else 1
		elif w_kind == WeaponBase.WeaponKind.STICK_GRENADE or w_kind == WeaponBase.WeaponKind.WELDING_TORCH:
			opt.add_item(WeaponBase.get_variant_display_name(w_kind, 0), 0)
			opt.selected = 0
			opt.disabled = true
		elif w_kind == WeaponBase.WeaponKind.FLAMETHROWER or w_kind == WeaponBase.WeaponKind.GRENADE_LAUNCHER:
			for a_idx in range(3):
				opt.add_item(WeaponBase.get_variant_display_name(w_kind, a_idx), a_idx)
			opt.selected = clampi(cur_arch, 0, 2)
		else:
			for a_idx in range(3):
				var vname: String = WeaponBase.get_variant_display_name(w_kind, a_idx)
				opt.add_item("%s (%s)" % [vname, arch_tags[a_idx]], a_idx)
			opt.selected = clampi(cur_arch, 0, 2)

		var cap_opt: OptionButton = opt
		opt.item_selected.connect(func(sel_idx: int) -> void:
			var item_id: int = cap_opt.get_item_id(sel_idx)
			select_weapon_variant(selected_class, cap_card_slot, item_id)
		)
		cv.add_child(opt)
		_weapon_variant_selectors.append(opt)

	_refresh_arsenal_highlights()


func is_listening_hotkey() -> bool:
	return not _listening_hotkey_kind.is_empty()


func _set_hotkey_hint(listening: bool) -> void:
	if _hotkey_hint_lbl == null:
		return
	_hotkey_hint_lbl.text = HOTKEY_HINT_LISTENING if listening else HOTKEY_HINT_DEFAULT
	_hotkey_hint_lbl.add_theme_color_override("font_color", HOTKEY_HINT_COLOR_LISTENING if listening else HOTKEY_HINT_COLOR_DEFAULT)


func _begin_hotkey_listen(kind: String, slot_idx: int) -> void:
	_listening_hotkey_kind = kind
	_listening_hotkey_slot = slot_idx
	_set_hotkey_hint(true)
	_refresh_hotkey_buttons()
	if kind == "skill" and slot_idx >= 0 and slot_idx < _skill_hotkey_buttons.size():
		_skill_hotkey_buttons[slot_idx].text = "Sk%d: [Tecla...]" % (slot_idx + 1)
	elif kind == "widget" and slot_idx >= 0 and slot_idx < _widget_hotkey_buttons.size():
		_widget_hotkey_buttons[slot_idx].text = "[Pressione Tecla...]"


func _cancel_hotkey_listen() -> void:
	_listening_hotkey_kind = ""
	_listening_hotkey_slot = -1
	_set_hotkey_hint(false)
	_refresh_hotkey_buttons()


func assign_hotkey_from_ui(kind: String, slot_idx: int, keycode: int) -> void:
	InputCmd.assign_unique_key(kind, slot_idx, keycode)
	InputCmd.save_hotkeys_to_config(hotkeys_config_path)
	_listening_hotkey_kind = ""
	_listening_hotkey_slot = -1
	_set_hotkey_hint(false)
	_refresh_hotkey_buttons()
	_notify_hud_hotkeys_changed()


func _refresh_hotkey_buttons() -> void:
	var skill_order: Array[int] = InputCmd.get_active_skill_order(6)
	for s_i in range(_skill_hotkey_buttons.size()):
		var logical_s: int = skill_order[s_i] if s_i < skill_order.size() else s_i
		var lbl: String = InputCmd.key_short_label(InputCmd.get_skill_key(s_i))
		_skill_hotkey_buttons[s_i].text = "Skill %d: %s" % [logical_s + 1, lbl]
	var w_names: Array[String] = ["Bandagem", "Chave", "Água", "Antídoto"]
	var widget_order: Array[int] = InputCmd.get_active_widget_order(4)
	for w_i in range(_widget_hotkey_buttons.size()):
		var logical_w: int = widget_order[w_i] if w_i < widget_order.size() else w_i
		var wlbl: String = InputCmd.key_short_label(InputCmd.get_widget_key(w_i))
		_widget_hotkey_buttons[w_i].text = "%s: %s" % [w_names[logical_w], wlbl]


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
	var cid: int = clampi(selected_class, 0, 4)
	var t_name: String = "Royal Army" if selected_team == 0 else "National Army"
	var t_prefix: String = "royal" if selected_team == 0 else "national"
	var c_names: Array[String] = ["Soldier", "Gunner", "Commando", "Demolisher", "Field Engineer"]
	var c_stats: Array[String] = [
		"HP 110 • 6.3 m/s",
		"HP 150 • 5.4 m/s",
		"HP 80 • 7.2 m/s",
		"HP 110 • 5.4 m/s",
		"HP 125 • 6.3 m/s",
	]
	var w_desc: Array[String] = [
		"SMG, Shotgun, Pistola, TNT",
		"Metralhadora MG, Shotgun, Bazooka",
		"Rifle Sniper, Faca, Pistola, TNT",
		"Lança-Chamas, Lança-Granadas, Granada de Cabo",
		"2 Revólveres/Pistolas, Shotgun, Maçarico de Solda",
	]
	var equipped_names: PackedStringArray = []
	var kinds: Array[int] = get_class_weapon_slots(cid)
	for s_i in range(kinds.size()):
		var a: int = NetworkManager.get_slot_archetype(cid, s_i, NetworkManager.ARCHETYPE_BALANCED)
		var eff_kind: int = _resolve_slot_weapon_kind(cid, s_i, a)
		var eff_arch: int = 0 if (cid == NetworkManager.CLASS_ENGINEER and s_i == 0) else a
		equipped_names.append(WeaponBase.get_variant_display_name(eff_kind, eff_arch))

	_rebuild_weapon_variant_selectors()

	if _summary_lbl != null:
		_summary_lbl.text = "%s | %s (%s) — Variantes: %s" % [t_name, c_names[cid], w_desc[cid], ", ".join(equipped_names)]
	if _preview_class_lbl != null:
		_preview_class_lbl.text = "%s  (%s)" % [c_names[cid].to_upper(), c_stats[cid]]
	if _preview_flag != null:
		_preview_flag.texture = CartoonAssets.get_texture("flag_%s" % t_prefix)
	if _preview_portrait != null:
		_preview_portrait.texture = CartoonAssets.get_texture("portrait_%s_%d" % [t_prefix, cid])
	for ci in range(_class_card_portraits.size()):
		_class_card_portraits[ci].texture = CartoonAssets.get_texture("portrait_%s_%d" % [t_prefix, ci])
	if _royal_btn != null:
		_royal_btn.modulate = Color(1.0, 1.0, 1.0) if selected_team == 0 else Color(0.65, 0.68, 0.72)
	if _nat_btn != null:
		_nat_btn.modulate = Color(1.0, 1.0, 1.0) if selected_team == 1 else Color(0.65, 0.68, 0.72)
	if _royal_faction_card != null:
		var rsb: StyleBoxFlat = _royal_faction_card.get_theme_stylebox("panel") as StyleBoxFlat
		if rsb != null:
			rsb.border_color = Color(1.0, 0.86, 0.24) if selected_team == 0 else Color(0.24, 0.44, 0.70)
	if _national_faction_card != null:
		var nsb: StyleBoxFlat = _national_faction_card.get_theme_stylebox("panel") as StyleBoxFlat
		if nsb != null:
			nsb.border_color = Color(1.0, 0.86, 0.24) if selected_team == 1 else Color(0.62, 0.22, 0.24)
	for i in range(_class_buttons.size()):
		var is_c: bool = (i == cid)
		_class_buttons[i].text = "SELECIONADO" if is_c else "SELECIONAR"
		_class_buttons[i].modulate = Color(1.0, 0.96, 0.75) if is_c else Color(0.72, 0.78, 0.86)
	for i in range(_class_cards.size()):
		var border_col: Color = Color(1.0, 0.86, 0.24) if i == cid else Color(0.30, 0.42, 0.56)
		var sb: StyleBoxFlat = _class_cards[i].get_theme_stylebox("panel") as StyleBoxFlat
		if sb != null:
			sb.border_color = border_col

	_sync_preview_hero()


func show_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _preview_viewport != null and is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if current_screen == "armory" else SubViewport.UPDATE_DISABLED
		)


func _is_mortar_targeting_active() -> bool:
	if not is_inside_tree():
		return false
	for h in get_tree().get_nodes_in_group("hud_controllers"):
		if h != null and h.has_method("is_mortar_targeting_active") and h.is_mortar_targeting_active():
			return true
	return false


func hide_menu() -> void:
	visible = false
	if _preview_viewport != null and is_instance_valid(_preview_viewport):
		_preview_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not DisplayServer.get_name().contains("headless") and not Input.is_key_pressed(KEY_ALT) and not _is_mortar_targeting_active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
