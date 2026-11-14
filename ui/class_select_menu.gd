class_name ClassSelectMenu
extends CanvasLayer

## War Champions Main & Class Selection Menu:
## Royal Army vs National Army, Soldier/Gunner/Commando, 3 Weapon Archetypes,
## Solo 12v12 Bots Match, Host Server, Join Server, and Artificial Lag Test Toggle.

signal play_solo_12v12_pressed(team: int, class_id: int, archetype: int)
signal host_match_pressed(team: int, class_id: int, archetype: int, port: int)
signal join_match_pressed(team: int, class_id: int, archetype: int, ip: String, port: int)

var selected_team: int = NetworkManager.TEAM_ROYAL
var selected_class: int = NetworkManager.CLASS_SOLDIER
var selected_archetype: int = NetworkManager.ARCHETYPE_BALANCED

var _ip_input: LineEdit
var _port_input: LineEdit
var _summary_lbl: Label
var _lag_btn: Button


func _ready() -> void:
	layer = 20
	_build_ui()
	_refresh_summary()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.12, 0.18, 0.86)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 520)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "WAR CHAMPIONS — 12v12 Seaside Frontline"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# 1. Faction Picker
	var fac_box := HBoxContainer.new()
	fac_box.alignment = BoxContainer.ALIGNMENT_CENTER
	fac_box.add_theme_constant_override("separation", 16)
	vbox.add_child(fac_box)

	var royal_btn := Button.new()
	royal_btn.text = "ROYAL ARMY (Allied Blue/Khaki)"
	royal_btn.custom_minimum_size = Vector2(260, 44)
	royal_btn.pressed.connect(func() -> void:
		selected_team = NetworkManager.TEAM_ROYAL
		_refresh_summary()
	)
	fac_box.add_child(royal_btn)

	var nat_btn := Button.new()
	nat_btn.text = "NATIONAL ARMY (Dark Grey/Red)"
	nat_btn.custom_minimum_size = Vector2(260, 44)
	nat_btn.pressed.connect(func() -> void:
		selected_team = NetworkManager.TEAM_NATIONAL
		_refresh_summary()
	)
	fac_box.add_child(nat_btn)

	# 2. Class Picker
	var cls_box := HBoxContainer.new()
	cls_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cls_box.add_theme_constant_override("separation", 12)
	vbox.add_child(cls_box)

	var cls_names: Array[String] = [
		"SOLDIER (110 HP)\nSMG / Shotgun / TNT",
		"GUNNER (150 HP)\nMG / Shotgun / Bazooka",
		"COMMANDO (80 HP)\nSniper / Knife / Stealth",
	]
	for i in range(3):
		var cbtn := Button.new()
		cbtn.text = cls_names[i]
		cbtn.custom_minimum_size = Vector2(205, 62)
		var cid: int = i
		cbtn.pressed.connect(func() -> void:
			selected_class = cid
			_refresh_summary()
		)
		cls_box.add_child(cbtn)

	# 3. Weapon Archetype Picker
	var arch_box := HBoxContainer.new()
	arch_box.alignment = BoxContainer.ALIGNMENT_CENTER
	arch_box.add_theme_constant_override("separation", 12)
	vbox.add_child(arch_box)

	var arch_names: Array[String] = ["Balanced (Default)", "Fast / Short-Range", "Slow / Long-Range"]
	for i in range(3):
		var abtn := Button.new()
		abtn.text = arch_names[i]
		abtn.custom_minimum_size = Vector2(205, 38)
		var aid: int = i
		abtn.pressed.connect(func() -> void:
			selected_archetype = aid
			_refresh_summary()
		)
		arch_box.add_child(abtn)

	_summary_lbl = Label.new()
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_summary_lbl)

	# 4. Launch Modes
	var solo_btn := Button.new()
	solo_btn.text = "PLAY 12v12 NOW (Solo + 23 AI Bots | Land, Air & Sea)"
	solo_btn.custom_minimum_size = Vector2(560, 50)
	solo_btn.pressed.connect(func() -> void:
		hide_menu()
		play_solo_12v12_pressed.emit(selected_team, selected_class, selected_archetype)
	)
	vbox.add_child(solo_btn)

	var net_box := HBoxContainer.new()
	net_box.alignment = BoxContainer.ALIGNMENT_CENTER
	net_box.add_theme_constant_override("separation", 10)
	vbox.add_child(net_box)

	_ip_input = LineEdit.new()
	_ip_input.text = "127.0.0.1"
	_ip_input.custom_minimum_size = Vector2(150, 38)
	net_box.add_child(_ip_input)

	_port_input = LineEdit.new()
	_port_input.text = "7777"
	_port_input.custom_minimum_size = Vector2(80, 38)
	net_box.add_child(_port_input)

	var host_btn := Button.new()
	host_btn.text = "Host 12v12 Server"
	host_btn.custom_minimum_size = Vector2(160, 38)
	host_btn.pressed.connect(func() -> void:
		hide_menu()
		host_match_pressed.emit(selected_team, selected_class, selected_archetype, int(_port_input.text))
	)
	net_box.add_child(host_btn)

	var join_btn := Button.new()
	join_btn.text = "Join Match"
	join_btn.custom_minimum_size = Vector2(130, 38)
	join_btn.pressed.connect(func() -> void:
		hide_menu()
		join_match_pressed.emit(selected_team, selected_class, selected_archetype, _ip_input.text, int(_port_input.text))
	)
	net_box.add_child(join_btn)

	_lag_btn = Button.new()
	_lag_btn.text = "Artificial Lag Sim: OFF (0ms)"
	_lag_btn.pressed.connect(_toggle_lag_sim)
	vbox.add_child(_lag_btn)


func _toggle_lag_sim() -> void:
	if NetworkManager.sim_latency_ms <= 0.0:
		NetworkManager.sim_latency_ms = 80.0
		NetworkManager.sim_jitter_ms = 12.0
		NetworkManager.sim_packet_loss = 0.02
		_lag_btn.text = "Artificial Lag Sim: ON (160ms RTT + 2% Loss)"
	else:
		NetworkManager.sim_latency_ms = 0.0
		NetworkManager.sim_jitter_ms = 0.0
		NetworkManager.sim_packet_loss = 0.0
		_lag_btn.text = "Artificial Lag Sim: OFF (0ms)"


func _refresh_summary() -> void:
	var t_name: String = "Royal Army" if selected_team == 0 else "National Army"
	var c_names: Array[String] = ["Soldier", "Gunner", "Commando"]
	var a_names: Array[String] = ["Balanced", "Fast / Short-Range", "Slow / Long-Range"]
	if _summary_lbl != null:
		_summary_lbl.text = "Selected: %s | %s | %s Weapons" % [t_name, c_names[selected_class], a_names[selected_archetype]]


func show_menu() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	visible = false
	if not DisplayServer.get_name().contains("headless"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
