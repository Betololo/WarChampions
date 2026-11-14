class_name ClassSelectMenu
extends CanvasLayer

## War Champions Main & Class Selection Menu:
## - Exclusive per-class Battlefield Heroes weapons (no fake 3-archetype selector).
## - Online Multiplayer First: Host Online Room (0 Bots) & Join by IP:Port.
## - Optional Offline Practice Mode with 12v12 Bots in a separate testing button.

signal host_online_pressed(team: int, class_id: int, port: int)
signal join_online_pressed(team: int, class_id: int, ip: String, port: int)
signal play_offline_bots_pressed(team: int, class_id: int)

var selected_team: int = NetworkManager.TEAM_ROYAL
var selected_class: int = NetworkManager.CLASS_SOLDIER

var _ip_input: LineEdit
var _port_input: LineEdit
var _summary_lbl: Label
var _preview_portrait: TextureRect
var _preview_flag: TextureRect
var _royal_btn: Button
var _nat_btn: Button
var _class_buttons: Array[Button] = []
var _lag_btn: Button
var _status_lbl: Label


func _ready() -> void:
	layer = 20
	_build_ui()
	_refresh_summary()


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
	bg.color = Color(0.06, 0.11, 0.19, 0.88)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 560)
	panel.add_theme_stylebox_override("panel", _make_card_style(Color(0.10, 0.14, 0.21, 0.96), Color(0.95, 0.78, 0.22), 3))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "WAR CHAMPIONS — 12v12 Seaside Frontline"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.26))
	vbox.add_child(title)

	# 1. Faction Picker + Portrait Preview Row
	var top_pick := HBoxContainer.new()
	top_pick.alignment = BoxContainer.ALIGNMENT_CENTER
	top_pick.add_theme_constant_override("separation", 18)
	vbox.add_child(top_pick)

	_preview_flag = TextureRect.new()
	_preview_flag.custom_minimum_size = Vector2(68, 48)
	_preview_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_pick.add_child(_preview_flag)

	_royal_btn = Button.new()
	_royal_btn.text = "ROYAL ARMY\n(Aliados Azul / Cáqui)"
	_royal_btn.custom_minimum_size = Vector2(225, 52)
	_royal_btn.pressed.connect(func() -> void:
		selected_team = NetworkManager.TEAM_ROYAL
		_refresh_summary()
	)
	top_pick.add_child(_royal_btn)

	_nat_btn = Button.new()
	_nat_btn.text = "NATIONAL ARMY\n(Cinza Chumbo / Vermelho)"
	_nat_btn.custom_minimum_size = Vector2(225, 52)
	_nat_btn.pressed.connect(func() -> void:
		selected_team = NetworkManager.TEAM_NATIONAL
		_refresh_summary()
	)
	top_pick.add_child(_nat_btn)

	_preview_portrait = TextureRect.new()
	_preview_portrait.custom_minimum_size = Vector2(64, 64)
	_preview_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_pick.add_child(_preview_portrait)

	# 2. Class Picker (Exclusive Weapons per Class)
	var cls_box := HBoxContainer.new()
	cls_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cls_box.add_theme_constant_override("separation", 12)
	vbox.add_child(cls_box)

	var cls_names: Array[String] = [
		"SOLDIER (110 HP)\nSMG / Shotgun / Pistola / TNT",
		"GUNNER (150 HP)\nMetralhadora MG / Shotgun / Bazooka",
		"COMMANDO (80 HP)\nSniper / Faca / Pistola / TNT",
	]
	for i in range(3):
		var cbtn := Button.new()
		cbtn.text = cls_names[i]
		cbtn.custom_minimum_size = Vector2(230, 68)
		var cid: int = i
		cbtn.pressed.connect(func() -> void:
			selected_class = cid
			_refresh_summary()
		)
		cls_box.add_child(cbtn)
		_class_buttons.append(cbtn)

	_summary_lbl = Label.new()
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 15)
	_summary_lbl.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0))
	vbox.add_child(_summary_lbl)

	# 3. PRIMARY SECTION: Online Multiplayer (0 forced bots)
	var online_card := PanelContainer.new()
	online_card.add_theme_stylebox_override("panel", _make_card_style(Color(0.08, 0.18, 0.28, 0.9), Color(0.28, 0.72, 1.0), 2))
	vbox.add_child(online_card)

	var on_margin := MarginContainer.new()
	on_margin.add_theme_constant_override("margin_left", 14)
	on_margin.add_theme_constant_override("margin_right", 14)
	on_margin.add_theme_constant_override("margin_top", 10)
	on_margin.add_theme_constant_override("margin_bottom", 10)
	online_card.add_child(on_margin)

	var on_v := VBoxContainer.new()
	on_v.add_theme_constant_override("separation", 8)
	on_margin.add_child(on_v)

	var on_hdr := Label.new()
	on_hdr.text = "MULTIPLAYER ONLINE (12v12 Jogadores Reais — Sem Bots)"
	on_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	on_hdr.add_theme_font_size_override("font_size", 17)
	on_hdr.add_theme_color_override("font_color", Color(0.42, 0.90, 1.0))
	on_v.add_child(on_hdr)

	var ip_hint := Label.new()
	ip_hint.text = "Seu IP Local (LAN/VPN): %s" % _get_lan_ip_hint()
	ip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_hint.add_theme_font_size_override("font_size", 13)
	on_v.add_child(ip_hint)

	var host_online_btn := Button.new()
	host_online_btn.text = "CRIAR SALA ONLINE (Host Multiplayer — 0 Bots)"
	host_online_btn.custom_minimum_size = Vector2(560, 44)
	host_online_btn.pressed.connect(func() -> void:
		hide_menu()
		host_online_pressed.emit(selected_team, selected_class, maxi(1024, int(_port_input.text)))
	)
	on_v.add_child(host_online_btn)

	var join_row := HBoxContainer.new()
	join_row.alignment = BoxContainer.ALIGNMENT_CENTER
	join_row.add_theme_constant_override("separation", 10)
	on_v.add_child(join_row)

	var ip_lbl := Label.new()
	ip_lbl.text = "IP:"
	join_row.add_child(ip_lbl)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(180, 38)
	join_row.add_child(_ip_input)

	var port_lbl := Label.new()
	port_lbl.text = "Porta:"
	join_row.add_child(port_lbl)

	_port_input = LineEdit.new()
	_port_input.text = "7777"
	_port_input.custom_minimum_size = Vector2(85, 38)
	join_row.add_child(_port_input)

	var join_btn := Button.new()
	join_btn.text = "ENTRAR NA PARTIDA ONLINE"
	join_btn.custom_minimum_size = Vector2(230, 38)
	join_btn.pressed.connect(func() -> void:
		hide_menu()
		join_online_pressed.emit(selected_team, selected_class, _ip_input.text.strip_edges(), maxi(1024, int(_port_input.text)))
	)
	join_row.add_child(join_btn)

	# 4. OPTIONAL OFFLINE BOTS + LAG SIM TESTING ROW
	var test_row := HBoxContainer.new()
	test_row.alignment = BoxContainer.ALIGNMENT_CENTER
	test_row.add_theme_constant_override("separation", 12)
	vbox.add_child(test_row)

	var solo_btn := Button.new()
	solo_btn.text = "Treino Offline com Bots (12v12)"
	solo_btn.custom_minimum_size = Vector2(310, 40)
	solo_btn.pressed.connect(func() -> void:
		hide_menu()
		play_offline_bots_pressed.emit(selected_team, selected_class)
	)
	test_row.add_child(solo_btn)

	_lag_btn = Button.new()
	_lag_btn.text = "Simulador de Lag: OFF (0ms)"
	_lag_btn.custom_minimum_size = Vector2(290, 40)
	_lag_btn.pressed.connect(_toggle_lag_sim)
	test_row.add_child(_lag_btn)

	_status_lbl = Label.new()
	_status_lbl.text = "Controles: WASD Mover | Espaço Pular/Paraquedas | Ctrl/C Agachar | 1-4/Q Armas | 5-9/F/G Skills | Z/X/V Itens | E Veículo | T Emote"
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.add_theme_font_size_override("font_size", 11)
	_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	vbox.add_child(_status_lbl)


func _toggle_lag_sim() -> void:
	if NetworkManager.sim_latency_ms <= 0.0:
		NetworkManager.sim_latency_ms = 80.0
		NetworkManager.sim_jitter_ms = 12.0
		NetworkManager.sim_packet_loss = 0.02
		_lag_btn.text = "Simulador de Lag: ON (160ms + 2% Perda)"
	else:
		NetworkManager.sim_latency_ms = 0.0
		NetworkManager.sim_jitter_ms = 0.0
		NetworkManager.sim_packet_loss = 0.0
		_lag_btn.text = "Simulador de Lag: OFF (0ms)"


func _refresh_summary() -> void:
	var t_name: String = "Royal Army" if selected_team == 0 else "National Army"
	var t_prefix: String = "royal" if selected_team == 0 else "national"
	var c_names: Array[String] = ["Soldier", "Gunner", "Commando"]
	var w_desc: Array[String] = [
		"SMG, Shotgun, Pistola e TNT",
		"Metralhadora MG, Shotgun e Bazooka",
		"Rifle Sniper, Faca, Pistola e TNT",
	]
	if _summary_lbl != null:
		_summary_lbl.text = "Selecionado: %s | %s — Armas Exclusivas: %s" % [t_name, c_names[selected_class], w_desc[selected_class]]
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


func show_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false
	if not DisplayServer.get_name().contains("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
