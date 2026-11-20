class_name MainGame
extends Node3D

## Master game coordinator for War Champions:
## Connects NetworkManager, MapSeasideFrontline (14v14 Land/Air/Water),
## ConquestManager (50 Tickets + 6 Flags), Vehicles, Bots, HUD & Class Menu.

const MAP_SCENE: PackedScene = preload("res://maps/seaside_frontline.tscn")
const EngineerSkillsScript := preload("res://entities/skills/engineer_skills.gd")
const VehicleShieldedMGScript := preload("res://entities/vehicles/vehicle_shielded_mg.gd")

var heroes_root: Node3D
var vehicles_root: Node3D
var projectiles_root: Node3D
var map_root: Node3D
var bots_root: Node3D
var lag_compensator: LagCompensator
var conquest_manager: ConquestManager
var hud: HUDController
var class_menu: ClassSelectMenu
var map_instance: MapSeasideFrontline

var heroes_by_id: Dictionary = {}
var vehicles_by_id: Dictionary = {}
var bot_brains: Dictionary = {}
var _prev_interact_state: Dictionary = {}
var _client_button_latch: Dictionary = {}
var _last_flame_sfx_msec: Dictionary = {}

const TRANSIENT_BTN_MASK: int = (
	InputCmd.BTN_INTERACT
	| InputCmd.BTN_RELOAD
	| InputCmd.BTN_EMOTE
	| InputCmd.BTN_SKILL_1
	| InputCmd.BTN_SKILL_2
	| InputCmd.BTN_SKILL_3
	| InputCmd.BTN_SKILL_4
	| InputCmd.BTN_SKILL_5
	| InputCmd.BTN_SKILL_6
	| InputCmd.BTN_WIDGET_1
	| InputCmd.BTN_WIDGET_2
	| InputCmd.BTN_WIDGET_3
	| InputCmd.BTN_WIDGET_4
)
var _prev_local_parachuting: bool = false
var _last_local_level: int = 5
var _royal_spawn_idx: int = 0
var _national_spawn_idx: int = 0
var _switching_mode: bool = false
var _loading_in_progress: bool = false
var _skip_loading_screen: bool = false
var _cached_combat_ctx: Dictionary = {}
var _live_vehicles_cache: Array[VehicleBase] = []
var _live_vehicles_dirty: bool = true
var _vfx_frame_counter: int = 0

var _loading_layer: CanvasLayer
var _loading_stage_lbl: Label
var _loading_bar: ProgressBar


func _ready() -> void:
	if get_viewport() != null:
		get_viewport().scaling_3d_scale = 1.0
		get_viewport().msaa_3d = Viewport.MSAA_2X
	RenderingServer.directional_shadow_atlas_set_size(2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	if OS.has_feature("web"):
		Engine.max_physics_steps_per_frame = 2
	heroes_root = Node3D.new()
	heroes_root.name = "Heroes"
	add_child(heroes_root)

	vehicles_root = Node3D.new()
	vehicles_root.name = "Vehicles"
	add_child(vehicles_root)

	projectiles_root = Node3D.new()
	projectiles_root.name = "Projectiles"
	add_child(projectiles_root)

	map_root = Node3D.new()
	map_root.name = "MapRoot"
	add_child(map_root)

	bots_root = Node3D.new()
	bots_root.name = "Bots"
	add_child(bots_root)

	lag_compensator = LagCompensator.new()
	lag_compensator.name = "LagCompensator"
	add_child(lag_compensator)

	conquest_manager = ConquestManager.new()
	conquest_manager.name = "ConquestManager"
	add_child(conquest_manager)
	conquest_manager.match_ended.connect(_on_match_ended)

	NetworkManager.client_input_received.connect(_on_client_input)
	NetworkManager.authoritative_state_received.connect(_on_auth_state)
	NetworkManager.world_snapshot_received.connect(_on_world_snapshot)
	NetworkManager.player_registered.connect(_on_player_registered)
	NetworkManager.player_unregistered.connect(_on_player_unregistered)
	NetworkManager.game_event_received.connect(_on_game_event)
	NetworkManager.connection_state_changed.connect(_on_connection_state_changed)
	NetworkManager.seat_switch_requested.connect(_on_seat_switch_requested)
	NetworkManager.mortar_target_received.connect(_on_mortar_target_received)
	NetworkManager.mortar_cancel_received.connect(_on_mortar_cancel_received)

	_load_map()
	_setup_ui()

	if NetworkManager.is_dedicated_server:
		class_menu.visible = false
	else:
		_check_cli_autostart()


func _check_cli_autostart() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var port: int = NetworkManager.DEFAULT_PORT
	for arg in args:
		if arg.begins_with("--port="):
			var parsed_port: int = int(arg.trim_prefix("--port="))
			if parsed_port > 0:
				port = parsed_port
	for arg in args:
		if arg == "--host":
			class_menu.hide_menu()
			_on_host_online(NetworkManager.TEAM_ROYAL, NetworkManager.CLASS_SOLDIER, port)
			return
		elif arg.begins_with("--join="):
			var ip: String = arg.trim_prefix("--join=")
			class_menu.hide_menu()
			_on_join_online(NetworkManager.TEAM_NATIONAL, NetworkManager.CLASS_SOLDIER, ip, port)
			return


func _exit_tree() -> void:
	SoundSynthesizer.stop_whistle_theme()
	StatusEffectContainer.clear_sixth_sense_cache()
	StatusEffectContainer.clear_team_uav()
	StatusEffectsVFX.clear_pools(projectiles_root)


func _on_connection_state_changed(connected: bool, is_srv: bool) -> void:
	_sync_vehicle_authority_freeze()
	if hud == null:
		return
	if connected and is_srv:
		if NetworkManager.is_solo_bot_mode:
			hud.add_killfeed("Modo Solo 14v14 com Bots pronto!")
		elif NetworkManager.is_relay_mode:
			var bots_lbl: String = "14v14 com Bots" if NetworkManager.online_fill_bots else "0 Bots"
			hud.add_killfeed("Sala Online '%s' pronta (%s)!" % [NetworkManager.active_room_code, bots_lbl])
		else:
			hud.add_killfeed("Sala Online pronta (porta %d)" % NetworkManager.DEFAULT_PORT)
	elif connected:
		hud.add_killfeed("Conectado ao servidor!")
	elif not _switching_mode:
		hud.add_killfeed("Desconectado da partida.")


func _sync_vehicle_authority_freeze() -> void:
	var auth: bool = NetworkManager.is_server_authority()
	for v_val in vehicles_by_id.values():
		var v := v_val as VehicleBase
		if v == null or not is_instance_valid(v):
			continue
		var should_freeze: bool = (v.vehicle_type == VehicleBase.VehicleType.AA_GUN or v.vehicle_type == VehicleBase.VehicleType.MOUNTED_MG) or not auth
		v.freeze = should_freeze
		if should_freeze:
			v.linear_velocity = Vector3.ZERO
			v.angular_velocity = Vector3.ZERO


func _load_map() -> void:
	GameCache.warm_textures()
	GameCache.warm_meshes()
	for c in map_root.get_children():
		c.queue_free()
	for v in vehicles_root.get_children():
		v.queue_free()
	vehicles_by_id.clear()

	_refresh_combat_context()
	map_instance = MAP_SCENE.instantiate() as MapSeasideFrontline
	map_root.add_child(map_instance)
	map_instance.build_map(conquest_manager, vehicles_root, _cached_combat_ctx)
	for v in map_instance.spawned_vehicles:
		vehicles_by_id[v.id] = v
	_live_vehicles_dirty = true
	_refresh_combat_context()
	_sync_vehicle_authority_freeze()


func _setup_ui() -> void:
	hud = HUDController.new()
	hud.name = "HUDController"
	add_child(hud)
	var v_arr: Array[VehicleBase] = map_instance.spawned_vehicles if map_instance != null else []
	hud.bind_context(conquest_manager, v_arr, heroes_by_id)
	hud.upgrade_skill_requested.connect(_on_upgrade_skill_requested)

	class_menu = ClassSelectMenu.new()
	class_menu.name = "ClassSelectMenu"
	add_child(class_menu)
	class_menu.host_online_pressed.connect(_on_host_online)
	class_menu.join_online_pressed.connect(_on_join_online)
	class_menu.play_offline_bots_pressed.connect(_on_play_offline_bots)
	class_menu.resume_match_requested.connect(_on_resume_match)
	class_menu.leave_match_requested.connect(_on_leave_match)

	if DisplayServer.get_name().contains("headless"):
		hud.visible = false
		class_menu.visible = false
	_build_loading_overlay()


func _build_loading_overlay() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "LoadingOverlay"
	_loading_layer.layer = 25
	_loading_layer.visible = false
	add_child(_loading_layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.09, 0.14, 0.96)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(540.0, 220.0)
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.11, 0.15, 0.22, 0.98)
	card_sb.border_color = Color(0.95, 0.78, 0.24, 0.92)
	card_sb.set_border_width_all(2)
	card_sb.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 28)
	pad.add_child(vb)
	card.add_child(pad)

	var title_lbl := Label.new()
	title_lbl.text = "WAR CHAMPIONS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.26))
	vb.add_child(title_lbl)

	var map_lbl := Label.new()
	map_lbl.text = "SEASIDE FRONTLINE  •  14 vs 14"
	map_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_lbl.add_theme_font_size_override("font_size", 15)
	map_lbl.add_theme_color_override("font_color", Color(0.76, 0.84, 0.94))
	vb.add_child(map_lbl)

	_loading_bar = ProgressBar.new()
	_loading_bar.custom_minimum_size = Vector2(460.0, 26.0)
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = 100.0
	_loading_bar.value = 0.0
	_loading_bar.show_percentage = true
	vb.add_child(_loading_bar)

	_loading_stage_lbl = Label.new()
	_loading_stage_lbl.text = "Inicializando cache da partida..."
	_loading_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_stage_lbl.add_theme_font_size_override("font_size", 14)
	_loading_stage_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96))
	vb.add_child(_loading_stage_lbl)


func set_loading_state(is_visible: bool, progress_pct: float = 0.0, stage_text: String = "") -> void:
	if _loading_layer != null:
		_loading_layer.visible = is_visible
	if _loading_bar != null:
		_loading_bar.value = clampf(progress_pct, 0.0, 100.0)
	if _loading_stage_lbl != null and not stage_text.is_empty():
		_loading_stage_lbl.text = stage_text


func is_loading_visible() -> bool:
	return _loading_layer != null and _loading_layer.visible


func _should_use_loading_screen() -> bool:
	if _skip_loading_screen:
		return false
	if DisplayServer.get_name().contains("headless"):
		return false
	if not OS.get_cmdline_user_args().is_empty():
		return false
	if get_tree() == null or get_tree().current_scene != self:
		return false
	return is_inside_tree() and _loading_layer != null


func _run_with_loading_screen(deploy_text: String, on_ready_call: Callable) -> void:
	if _loading_in_progress:
		return
	_loading_in_progress = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_loading_state(true, 15.0, "Carregando mapa e cache de texturas...")
	await get_tree().process_frame

	GameCache.warm_textures()
	set_loading_state(true, 45.0, "Pré-carregando malhas 3D, armas e veículos...")
	await get_tree().process_frame

	GameCache.warm_meshes()
	set_loading_state(true, 72.0, deploy_text)
	on_ready_call.call()
	await get_tree().process_frame

	set_loading_state(true, 88.0, "Compilando shaders e cachê da GPU...")
	var prewarm_node: Node3D = GameCache.prewarm_gpu_pipelines(self)
	await get_tree().process_frame
	if prewarm_node != null:
		await get_tree().process_frame
		GameCache.cleanup_prewarm(prewarm_node)

	set_loading_state(true, 100.0, "Partida pronta!")
	set_loading_state(false, 100.0, "")
	_loading_in_progress = false
	if class_menu != null and not class_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not _loading_in_progress and class_menu != null and not class_menu.visible and heroes_by_id.has(NetworkManager.local_peer_id):
			var alt_held: bool = Input.is_key_pressed(KEY_ALT)
			var mortar_active: bool = hud != null and hud.is_mortar_targeting_active()
			if not alt_held and not mortar_active:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DisplayServer.get_name().contains("headless"):
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if (k.keycode == KEY_ESCAPE or k.keycode == KEY_P) and class_menu != null:
			if hud != null and hud.is_mortar_targeting_active():
				hud.set_mortar_targeting_mode(false)
				get_viewport().set_input_as_handled()
				return
			if class_menu.is_listening_hotkey():
				return
			var in_active_match: bool = heroes_by_id.has(NetworkManager.local_peer_id)
			if class_menu.visible:
				if in_active_match:
					class_menu.hide_menu()
				elif class_menu.current_screen != "hub":
					class_menu.show_screen("hub")
			else:
				class_menu.set_in_match_mode(in_active_match)
				if in_active_match:
					class_menu.show_screen("settings")
				class_menu.show_menu()
		elif k.keycode == KEY_F8:
			if NetworkManager.sim_latency_ms <= 0.0:
				NetworkManager.sim_latency_ms = 80.0
				NetworkManager.sim_jitter_ms = 12.0
				NetworkManager.sim_packet_loss = 0.02
			else:
				NetworkManager.sim_latency_ms = 0.0
				NetworkManager.sim_jitter_ms = 0.0
				NetworkManager.sim_packet_loss = 0.0
		elif k.keycode == KEY_M:
			var music_on: bool = SoundSynthesizer.toggle_music()
			if hud != null:
				hud.add_killfeed("Música: ATIVADA" if music_on else "Música: DESATIVADA (M)")


func _on_resume_match() -> void:
	if class_menu != null:
		class_menu.hide_menu()


func _on_leave_match() -> void:
	_switching_mode = true
	NetworkManager.shutdown_network()
	_clear_match_entities()
	conquest_manager.reset_match()
	SoundSynthesizer.stop_whistle_theme()
	_switching_mode = false
	if class_menu != null:
		class_menu.set_in_match_mode(false)
		class_menu.show_screen("hub")
		class_menu.show_menu()


func _on_host_online(team: int, class_id: int, port: int) -> void:
	if _should_use_loading_screen():
		_run_with_loading_screen("Abrindo sala online e preparando spawn...", func() -> void:
			_start_host_sync(team, class_id, port)
		)
		return
	_start_host_sync(team, class_id, port)


func _start_host_sync(team: int, class_id: int, port: int) -> void:
	_switching_mode = true
	_clear_match_entities()
	conquest_manager.reset_match()
	var slot_archs: Dictionary = NetworkManager.build_class_slot_archetypes(class_id)
	NetworkManager.set_local_loadout("HostHero", team, class_id, NetworkManager.ARCHETYPE_BALANCED, slot_archs)
	NetworkManager.start_host(port, false)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
	if NetworkManager.online_fill_bots:
		_spawn_14v14_bots(team)
	SoundSynthesizer.start_whistle_theme()


func _on_join_online(team: int, class_id: int, ip: String, port: int) -> void:
	if _should_use_loading_screen():
		_run_with_loading_screen("Conectando à sala online %s:%d..." % [ip, port], func() -> void:
			_start_join_sync(team, class_id, ip, port)
		)
		return
	_start_join_sync(team, class_id, ip, port)


func _start_join_sync(team: int, class_id: int, ip: String, port: int) -> void:
	_switching_mode = true
	_clear_match_entities()
	conquest_manager.reset_match()
	var slot_archs: Dictionary = NetworkManager.build_class_slot_archetypes(class_id)
	NetworkManager.set_local_loadout("ClientHero", team, class_id, NetworkManager.ARCHETYPE_BALANCED, slot_archs)
	NetworkManager.join_server(ip, port)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
	SoundSynthesizer.start_whistle_theme()


func _on_play_offline_bots(team: int, class_id: int) -> void:
	if _should_use_loading_screen():
		_run_with_loading_screen("Posicionando pelotões 14 vs 14 e iniciando partida...", func() -> void:
			_start_bots_sync(team, class_id)
		)
		return
	_start_bots_sync(team, class_id)


func _start_bots_sync(team: int, class_id: int) -> void:
	_switching_mode = true
	_clear_match_entities()
	conquest_manager.reset_match()
	var slot_archs: Dictionary = NetworkManager.build_class_slot_archetypes(class_id)
	NetworkManager.set_local_loadout("Hero", team, class_id, NetworkManager.ARCHETYPE_BALANCED, slot_archs)
	NetworkManager.start_host(NetworkManager.DEFAULT_PORT, true)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
	_spawn_14v14_bots(team)
	SoundSynthesizer.start_whistle_theme()


func _clear_match_entities() -> void:
	_royal_spawn_idx = 0
	_national_spawn_idx = 0
	_prev_interact_state.clear()
	_client_button_latch.clear()
	_last_flame_sfx_msec.clear()
	StatusEffectContainer.clear_sixth_sense_cache()
	StatusEffectContainer.clear_team_uav()
	StatusEffectsVFX.clear_pools(projectiles_root)
	StatusEffectsVFX.clear_all_build_previews()
	StatusEffectsVFX.clear_all_flame_streams()
	if hud != null:
		hud.set_local_hero(null)
		hud.clear_killfeed()
	if projectiles_root != null:
		for p in projectiles_root.get_children():
			p.queue_free()
	for b in bots_root.get_children():
		b.queue_free()
	bot_brains.clear()
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if is_instance_valid(h):
			h.queue_free()
	if heroes_root != null:
		for ch in heroes_root.get_children():
			if is_instance_valid(ch):
				ch.queue_free()
	heroes_by_id.clear()
	var reset_vehs: Array[VehicleBase] = []
	var remove_vids: Array[int] = []
	for vid_key in vehicles_by_id.keys():
		var vb := vehicles_by_id[vid_key] as VehicleBase
		if vb == null or not is_instance_valid(vb):
			remove_vids.append(int(vid_key))
			continue
		if vb.is_deployable or vb.vehicle_type == VehicleBase.VehicleType.MOUNTED_MG:
			remove_vids.append(int(vid_key))
			if vb.has_method("disable_shield_collision"):
				vb.disable_shield_collision()
			if map_instance != null and map_instance.spawned_vehicles.has(vb):
				map_instance.spawned_vehicles.erase(vb)
			vb.queue_free()
			continue
		if not reset_vehs.has(vb):
			reset_vehs.append(vb)
	for rvid in remove_vids:
		vehicles_by_id.erase(rvid)
	if is_inside_tree():
		for grp in ["trenches", "client_trenches", "mortar_rings", "deployed_turrets", "build_previews"]:
			for g_node in get_tree().get_nodes_in_group(grp):
				if is_instance_valid(g_node):
					if g_node is VehicleBase:
						var g_vb := g_node as VehicleBase
						vehicles_by_id.erase(g_vb.id)
						if map_instance != null and map_instance.spawned_vehicles.has(g_vb):
							map_instance.spawned_vehicles.erase(g_vb)
						if g_vb.has_method("disable_shield_collision"):
							g_vb.disable_shield_collision()
					elif g_node.has_method("disable_collision"):
						g_node.disable_collision()
					g_node.queue_free()
	if map_instance != null:
		for mv in map_instance.spawned_vehicles:
			if mv != null and is_instance_valid(mv) and not mv.is_deployable and not mv.is_queued_for_deletion() and not reset_vehs.has(mv):
				reset_vehs.append(mv)
		for ch in map_instance.get_children():
			if ch is DestructibleProp:
				(ch as DestructibleProp).reset_prop()
	for vb in reset_vehs:
		vb._respawn_vehicle()
	_live_vehicles_dirty = true
	_sync_vehicle_authority_freeze()
	_refresh_combat_context()
	_sync_hud_vehicles()


func _spawn_14v14_bots(human_team: int) -> void:
	# 14 Royal + 14 National = 28 combatants total (human + 27 bots)
	var bot_id: int = 1000
	var ally_count: int = 13
	var enemy_count: int = 14
	var enemy_team: int = NetworkManager.TEAM_NATIONAL if human_team == NetworkManager.TEAM_ROYAL else NetworkManager.TEAM_ROYAL

	for i in range(ally_count):
		var cls: int = i % 6
		NetworkManager.register_bot(bot_id, "AllyBot_%d" % (i + 1), human_team, cls, i % 3)
		bot_id += 1
	for j in range(enemy_count):
		var cls_e: int = (j + 2) % 6
		NetworkManager.register_bot(bot_id, "EnemyBot_%d" % (j + 1), enemy_team, cls_e, j % 3)
		bot_id += 1


func _refresh_combat_context() -> void:
	var v_list: Array = vehicles_by_id.values()
	if _cached_combat_ctx.is_empty():
		_cached_combat_ctx = {
			"lag_compensator": lag_compensator,
			"heroes_by_id": heroes_by_id,
			"projectiles_root": projectiles_root,
			"vehicles": v_list,
			"vehicles_by_id": vehicles_by_id,
			"on_damage_dealt": _on_damage_dealt_xp,
		}
	else:
		_cached_combat_ctx["lag_compensator"] = lag_compensator
		_cached_combat_ctx["heroes_by_id"] = heroes_by_id
		_cached_combat_ctx["projectiles_root"] = projectiles_root
		_cached_combat_ctx["vehicles"] = v_list
		_cached_combat_ctx["vehicles_by_id"] = vehicles_by_id
		_cached_combat_ctx["on_damage_dealt"] = _on_damage_dealt_xp


func _build_combat_context() -> Dictionary:
	_refresh_combat_context()
	return _cached_combat_ctx


func _on_damage_dealt_xp(attacker: HeroCharacter, _victim: HeroCharacter, dealt: int) -> void:
	if attacker != null and dealt > 0 and attacker.skill_manager != null and attacker.skill_manager.has_method("award_xp"):
		attacker.skill_manager.award_xp(maxi(5, dealt / 4))


func _physics_process(delta: float) -> void:
	if NetworkManager.is_active_host_authority():
		if _cached_combat_ctx.is_empty():
			_refresh_combat_context()
		var combat_ctx: Dictionary = _cached_combat_ctx
		StatusEffectContainer.refresh_sixth_sense_cache(heroes_by_id)

		# 1. Step AI Bots (staggered 3-way at 20 Hz when > 6 bots to cut CPU/raycast load by 67%)
		var cps: Array[CapturePoint] = map_instance.capture_points if map_instance != null else []
		var veh_arr: Array[VehicleBase] = _get_live_vehicles_array()
		var stagger_bots: bool = bot_brains.size() > 6
		var ai_slice: int = NetworkManager.server_tick % 3
		for bid in bot_brains.keys():
			var brain: BotController = bot_brains[bid]
			var bhero: HeroCharacter = heroes_by_id.get(bid, null)
			if bhero != null:
				if not stagger_bots or bhero.latest_server_input == null or bhero.latest_server_input.tick <= 0 or (int(bid) % 3) == ai_slice:
					var ai_dt: float = delta * 3.0 if (stagger_bots and bhero.latest_server_input != null and bhero.latest_server_input.tick > 0) else delta
					bhero.latest_server_input = brain.step_ai(ai_dt, cps, heroes_by_id, veh_arr)
				else:
					bhero.latest_server_input.tick = NetworkManager.server_tick

		var latch_restores: Array = []
		for pid_key in _client_button_latch.keys():
			var latch_bits: int = int(_client_button_latch[pid_key])
			if latch_bits != 0:
				var lh := heroes_by_id.get(pid_key, null) as HeroCharacter
				if lh != null and is_instance_valid(lh) and lh.latest_server_input != null:
					latch_restores.append([lh, lh.latest_server_input.buttons])
					lh.latest_server_input.buttons |= latch_bits
			_client_button_latch[pid_key] = 0

		# 2. Step Heroes, Vehicle Interact, Skills, Weapons, Respawns
		for id_key in heroes_by_id.keys():
			var hero: HeroCharacter = heroes_by_id[id_key]
			if hero.is_defeated:
				if hero.defeat_timer <= 0.0:
					var sp: Vector3 = _get_next_spawn_pos(hero.team)
					hero.respawn_at(sp, -PI * 0.5 if hero.team == NetworkManager.TEAM_ROYAL else PI * 0.5)
				if not hero.is_bot and hero.entity_id != 1:
					_send_hero_auth_state(hero)
				continue

			_handle_vehicle_interact(hero)

			if hero.is_local_player and not hero.is_bot and hero.hero_camera != null:
				hero.latest_server_input.aim_yaw = hero.hero_camera.yaw
				hero.latest_server_input.aim_pitch = hero.hero_camera.pitch
				hero.latest_server_input.view_interp_tick_delta = 0

			if hero.current_vehicle_id < 0 and hero.skill_manager != null and hero.skill_manager.has_method("step_server"):
				hero.skill_manager.step_server(delta, hero.latest_server_input, combat_ctx)

			if hero.current_vehicle_id < 0 and not hero.weapons.is_empty():
				var incoming_slot: int = clampi(hero.latest_server_input.selected_weapon_slot, 0, hero.weapons.size() - 1)
				if hero.should_apply_client_weapon_slot(incoming_slot, hero.latest_server_input.tick):
					hero.selected_weapon_slot = incoming_slot
				var w: WeaponBase = hero.weapons[hero.selected_weapon_slot] as WeaponBase
				if w != null:
					var was_reloading: bool = w.is_reloading
					w.step_timers(delta, hero.latest_server_input)
					if not was_reloading and w.is_reloading and hero.entity_id == NetworkManager.local_peer_id and not hero.is_bot:
						SoundSynthesizer.play_sfx("reload", 0.0, true)
					if w is ProjectileWeapon and not hero.is_defeated:
						(w as ProjectileWeapon).try_detonate_stickies(hero.latest_server_input)
					if w.try_consume_fire(hero.latest_server_input):
						w.fire_server(hero.latest_server_input, combat_ctx)

			if not hero.is_bot and hero.entity_id != 1:
				_send_hero_auth_state(hero)

		# 3. Step Vehicles & Conquest Flags
		for v in veh_arr:
			v.step_vehicle_server(delta, heroes_by_id, combat_ctx)

		for restore_item in latch_restores:
			var rh := restore_item[0] as HeroCharacter
			if rh != null and is_instance_valid(rh) and rh.latest_server_input != null:
				rh.latest_server_input.buttons = int(restore_item[1])

		conquest_manager.step_server(delta, heroes_by_id)
		lag_compensator.record_frame(NetworkManager.server_tick, heroes_by_id)

		# 4. Broadcast WorldSnapshot @ 30 Hz (only when remote clients are connected)
		if NetworkManager.should_broadcast_snapshot():
			if NetworkManager.has_connected_clients():
				var hero_snaps: Array[Dictionary] = []
				for id_key in heroes_by_id.keys():
					hero_snaps.append((heroes_by_id[id_key] as HeroCharacter).build_snapshot_dict())
				var veh_snaps: Array[Dictionary] = []
				for v in veh_arr:
					veh_snaps.append(v.build_snapshot_dict())
				var flag_snaps: Array[Dictionary] = conquest_manager.build_flags_snapshot()
				var srv_time_ms: int = int(roundf(float(NetworkManager.server_tick) * NetworkManager.TICK_INTERVAL_MS))
				var snap_bytes: PackedByteArray = NetSerializer.pack_world_snapshot(
					NetworkManager.server_tick,
					srv_time_ms,
					conquest_manager.royal_tickets,
					conquest_manager.national_tickets,
					hero_snaps,
					veh_snaps,
					flag_snaps
				)
				NetworkManager.broadcast_world_snapshot(snap_bytes)
	else:
		StatusEffectContainer.step_team_uav(delta)


func _handle_vehicle_interact(hero: HeroCharacter) -> void:
	if hero == null or hero.is_defeated:
		return
	var held: bool = hero.latest_server_input.has_button(InputCmd.BTN_INTERACT)
	var was_held: bool = bool(_prev_interact_state.get(hero.entity_id, false))
	_prev_interact_state[hero.entity_id] = held
	if not (held and not was_held):
		return

	if hero.current_vehicle_id >= 0:
		var cur_v: VehicleBase = vehicles_by_id.get(hero.current_vehicle_id, null)
		if cur_v != null:
			cur_v.exit_hero(hero)
		return

	if hero.hp <= 0 or hero.is_last_stand_active():
		return

	var best_v: VehicleBase = null
	var best_d: float = 5.5
	for v_key in vehicles_by_id.keys():
		var v: VehicleBase = vehicles_by_id[v_key]
		if v == null or v.is_destroyed:
			continue
		var d: float = v.global_position.distance_to(hero.global_position)
		if d <= best_d:
			best_d = d
			best_v = v
	if best_v != null:
		best_v.try_enter_hero(hero)


func _on_seat_switch_requested(peer_id: int, seat_idx: int) -> void:
	if not NetworkManager.is_active_host_authority():
		return
	var hero: HeroCharacter = heroes_by_id.get(peer_id, null)
	if hero == null or hero.is_defeated or hero.current_vehicle_id < 0:
		return
	var veh: VehicleBase = vehicles_by_id.get(hero.current_vehicle_id, null)
	if veh != null and veh.has_method("try_switch_seat"):
		veh.try_switch_seat(hero, seat_idx)


func _on_player_registered(peer_id: int, info: Dictionary) -> void:
	var was_new: bool = not heroes_by_id.has(peer_id)
	spawn_hero(peer_id, info)
	if was_new and peer_id > 1 and not bool(info.get("is_bot", false)) and NetworkManager.is_server_authority():
		_sync_active_deployables_on_join()


func _sync_active_deployables_on_join() -> void:
	if is_inside_tree():
		for t_node in get_tree().get_nodes_in_group("trenches"):
			if t_node is EngineerSkillsScript.TrenchEntity:
				var t := t_node as EngineerSkillsScript.TrenchEntity
				if not t.is_destroyed and not t._is_visual_only:
					NetworkManager.broadcast_game_event("trench_spawn", {
						"trench_id": t.trench_id,
						"owner_id": t.owner_id,
						"team": t.team,
						"pos": t.position,
						"yaw": t.rotation.y,
					})
	for v_val in vehicles_by_id.values():
		var vb := v_val as VehicleBase
		if vb == null or not is_instance_valid(vb) or vb.is_destroyed:
			continue
		if vb.is_deployable and vb.vehicle_type == VehicleBase.VehicleType.MOUNTED_MG:
			var owner_peer: int = (vb as VehicleShieldedMG).owner_id if vb is VehicleShieldedMGScript else -1
			NetworkManager.broadcast_game_event("eng_turret_spawn", {
				"vehicle_id": vb.id,
				"owner_id": owner_peer,
				"team": vb.team,
				"pos": vb.position,
				"yaw": vb.rotation.y,
			})
		if vb.is_armored:
			NetworkManager.broadcast_game_event("veh_armored", {
				"vehicle_id": vb.id,
				"max_hp": vb.max_hp,
				"hp": vb.hp,
				"hero_id": -1,
			})
	if projectiles_root != null:
		for ch in projectiles_root.get_children():
			if ch is DemolisherSkills.ArmorKitEntity and not ch.is_queued_for_deletion():
				var kit := ch as DemolisherSkills.ArmorKitEntity
				if kit.charges > 0:
					NetworkManager.broadcast_game_event("armor_kit_spawn", {
						"owner_id": kit.owner_id,
						"team": kit.owner_team,
						"kit_uid": kit.kit_uid,
						"charges": kit.charges,
						"pos": kit.position,
					})


func _send_hero_auth_state(hero: HeroCharacter) -> void:
	var packed: PackedByteArray = NetSerializer.pack_authoritative_state(
		hero.latest_server_input.tick,
		hero.global_position,
		hero.velocity,
		hero.active_flags,
		hero.hp,
		hero.shield,
		hero.current_vehicle_id,
		hero.current_seat_index,
		hero.knockback_seq,
		hero.active_buffs,
		hero.selected_weapon_slot,
		hero.forced_weapon_seq,
		hero.get_sprint_energy_byte()
	)
	NetworkManager.send_authoritative_state(hero.entity_id, packed)


func _on_player_unregistered(peer_id: int) -> void:
	if bot_brains.has(peer_id):
		(bot_brains[peer_id] as BotController).queue_free()
		bot_brains.erase(peer_id)
	if heroes_by_id.has(peer_id):
		var hero: HeroCharacter = heroes_by_id[peer_id]
		heroes_by_id.erase(peer_id)
		hero.queue_free()


func _get_next_spawn_pos(p_team: int) -> Vector3:
	if map_instance == null:
		return Vector3(0.0, 4.0, 0.0)
	var idx: int = 0
	if p_team == NetworkManager.TEAM_ROYAL:
		idx = _royal_spawn_idx
		_royal_spawn_idx += 1
	else:
		idx = _national_spawn_idx
		_national_spawn_idx += 1
	return map_instance.get_spawn_position(p_team, idx)


func _bind_local_hero_ui_hooks(hero: HeroCharacter) -> void:
	if hero.hero_camera != null:
		hero.hero_camera.mouse_sensitivity = ClassSelectMenu.current_mouse_sensitivity
		hero.hero_camera.sensitivity = ClassSelectMenu.current_mouse_sensitivity
	_last_local_level = hero.skill_manager.level if hero.skill_manager != null else 5
	_prev_local_parachuting = hero.is_parachuting
	if hero.skill_manager != null and hero.skill_manager.has_signal("progression_changed"):
		hero.skill_manager.progression_changed.connect(func(lvl: int, _xp: int, _xp_next: int, _pts: int) -> void:
			if lvl > _last_local_level:
				_last_local_level = lvl
				SoundSynthesizer.play_sfx("level_up", 0.0, true)
		)
	if hud != null:
		hud.set_local_hero(hero)


func spawn_hero(entity_id: int, info: Dictionary) -> HeroCharacter:
	var is_bot: bool = bool(info.get("is_bot", false))
	var is_local: bool = (entity_id == NetworkManager.local_peer_id) and not is_bot and not NetworkManager.is_dedicated_server
	var raw_slots: Variant = info.get("slot_archetypes", {})
	var slot_map: Dictionary = raw_slots if raw_slots is Dictionary else {}
	var p_name: String = str(info.get("name", "Hero"))
	var p_team: int = int(info.get("team", 0))
	var p_cls: int = int(info.get("class_id", 0))
	var p_arch: int = int(info.get("archetype", 0))
	if heroes_by_id.has(entity_id):
		var existing := heroes_by_id[entity_id] as HeroCharacter
		if existing != null and is_instance_valid(existing):
			existing.hero_name = p_name
			var needs_rebuild: bool = (
				existing.team != p_team
				or existing.class_id != p_cls
				or existing.archetype != p_arch
				or existing.weapon_slot_archetypes != slot_map
			)
			if needs_rebuild:
				var prev_team: int = existing.team
				existing.setup_identity(entity_id, p_name, p_team, p_cls, p_arch, is_local, is_bot, slot_map)
				if existing.team != prev_team and NetworkManager.is_server_authority():
					existing.position = _get_next_spawn_pos(existing.team)
				if is_local:
					_bind_local_hero_ui_hooks(existing)
			return existing
	var hero := HeroCharacter.new()
	hero.setup_identity(
		entity_id,
		p_name,
		p_team,
		p_cls,
		p_arch,
		is_local,
		is_bot,
		slot_map
	)
	var sp: Vector3 = _get_next_spawn_pos(hero.team)
	hero.position = sp
	heroes_root.add_child(hero)
	heroes_by_id[entity_id] = hero
	print("[MainGame] Spawned %s (id=%d, team=%d, bot=%s, total=%d)" % [hero.hero_name, entity_id, hero.team, str(is_bot), heroes_by_id.size()])

	hero.defeated.connect(_on_hero_defeated.bind(hero))
	hero.emote_triggered.connect(func(_idx: int) -> void:
		var is_loc_emote: bool = (hero.entity_id == NetworkManager.local_peer_id and not hero.is_bot)
		SoundSynthesizer.play_faction_emote(hero.team, is_loc_emote, hero.global_position)
	)

	if is_local:
		_bind_local_hero_ui_hooks(hero)

	if is_bot and NetworkManager.is_server_authority():
		var brain := BotController.new()
		brain.setup(hero)
		bots_root.add_child(brain)
		bot_brains[entity_id] = brain

	return hero


func _on_hero_defeated(killer_id: int, _explosive: bool, victim: HeroCharacter) -> void:
	if not NetworkManager.is_server_authority():
		return
	if victim.current_vehicle_id >= 0:
		var cur_v: VehicleBase = vehicles_by_id.get(victim.current_vehicle_id, null)
		if cur_v != null:
			cur_v.exit_hero(victim)

	var killer: HeroCharacter = heroes_by_id.get(killer_id, null)
	var killer_team: int = killer.team if killer != null else -1
	var lost: int = conquest_manager.on_player_killed(victim.team, killer_team, killer)
	var k_name: String = killer.hero_name if killer != null else "Environment"
	NetworkManager.broadcast_game_event("kill_event", {
		"killer": k_name,
		"killer_id": killer_id,
		"victim": victim.hero_name,
		"tickets_lost": lost,
	})


func _on_match_ended(winning_team: int) -> void:
	var winner_name: String = "ROYAL ARMY" if winning_team == NetworkManager.TEAM_ROYAL else "NATIONAL ARMY"
	NetworkManager.broadcast_game_event("match_over", {"winner": winner_name})


func _on_upgrade_skill_requested(slot_idx: int) -> void:
	NetworkManager.broadcast_game_event("upgrade_skill", {
		"hero_id": NetworkManager.local_peer_id,
		"slot": slot_idx,
	})


func _on_client_input(peer_id: int, cmd: InputCmd) -> void:
	if heroes_by_id.has(peer_id):
		(heroes_by_id[peer_id] as HeroCharacter).latest_server_input = cmd
	_client_button_latch[peer_id] = int(_client_button_latch.get(peer_id, 0)) | (cmd.buttons & TRANSIENT_BTN_MASK)


func _on_auth_state(state: Dictionary) -> void:
	var local_hero: HeroCharacter = heroes_by_id.get(NetworkManager.local_peer_id, null)
	if local_hero != null:
		local_hero.reconcile_with_server(state)


func _on_world_snapshot(snapshot: Dictionary) -> void:
	var srv_tick: int = int(snapshot.get("server_tick", 0))
	var srv_time_ms: float = float(snapshot.get("server_time_ms", 0))
	conquest_manager.royal_tickets = int(snapshot.get("royal_tickets", 50))
	conquest_manager.national_tickets = int(snapshot.get("national_tickets", 50))
	conquest_manager.apply_flags_snapshot(snapshot.get("flags", []))

	for h_dict in snapshot.get("heroes", []):
		var hid: int = int(h_dict.get("id", 0))
		if hid == NetworkManager.local_peer_id:
			var lh: HeroCharacter = heroes_by_id.get(hid, null)
			if lh != null and is_instance_valid(lh):
				lh.active_buffs = int(h_dict.get("buffs", lh.active_buffs))
			continue
		if not heroes_by_id.has(hid):
			var p_info: Dictionary = NetworkManager.players_info.get(hid, {})
			spawn_hero(hid, {
				"name": str(p_info.get("name", "Hero_%d" % hid)),
				"team": int(h_dict.get("team", 0)),
				"class_id": int(h_dict.get("class_id", 0)),
				"is_bot": bool(p_info.get("is_bot", hid >= 1000 and hid <= 1099)),
			})
		(heroes_by_id[hid] as HeroCharacter).push_remote_snapshot(srv_tick, srv_time_ms, h_dict)

	for v_dict in snapshot.get("vehicles", []):
		var vid: int = int(v_dict.get("id", 0))
		var v: VehicleBase = vehicles_by_id.get(vid, null)
		if v != null:
			v.push_remote_snapshot(srv_tick, srv_time_ms, v_dict)
	_sync_client_vehicle_seats()


func _sync_client_vehicle_seats() -> void:
	for v_val in vehicles_by_id.values():
		var vb := v_val as VehicleBase
		if vb != null and is_instance_valid(vb):
			for s in vb.seats:
				s.occupant_id = -1
	for h_val in heroes_by_id.values():
		var h := h_val as HeroCharacter
		if h == null or not is_instance_valid(h) or h.current_vehicle_id < 0:
			continue
		var vb := vehicles_by_id.get(h.current_vehicle_id, null) as VehicleBase
		if vb == null or not is_instance_valid(vb):
			continue
		var seat := vb.get_seat(h.current_seat_index)
		if seat != null:
			seat.occupant_id = h.entity_id
			h.current_seat_enclosed = seat.is_enclosed
			h.current_seat_pose = seat.seat_pose
			h.current_seat_can_shoot = seat.can_shoot


func _process(delta: float) -> void:
	var local_hero: HeroCharacter = heroes_by_id.get(NetworkManager.local_peer_id, null)
	if local_hero != null and is_instance_valid(local_hero):
		SoundSynthesizer.set_listener_position(local_hero.global_position + Vector3(0.0, 1.5, 0.0))
		if local_hero.is_parachuting and not _prev_local_parachuting:
			SoundSynthesizer.play_sfx("parachute", 0.0, true)
		_prev_local_parachuting = local_hero.is_parachuting
	else:
		var cam := get_viewport().get_camera_3d() if get_viewport() != null else null
		if cam != null:
			SoundSynthesizer.set_listener_position(cam.global_position)
	StatusEffectContainer.refresh_sixth_sense_cache(heroes_by_id)
	_vfx_frame_counter += 1
	var local_pos: Vector3 = local_hero.global_position if (local_hero != null and is_instance_valid(local_hero)) else Vector3.ZERO
	var has_local: bool = (local_hero != null and is_instance_valid(local_hero))
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h != local_hero and has_local and h._last_vfx_hash != -1:
			if not h.is_stealthed and (h.active_flags & (NetSerializer.SNAP_STEALTHED | NetSerializer.SNAP_SPEED_BOOST | NetSerializer.SNAP_SIXTH_SENSE)) == 0 and h.active_buffs == 0:
				if h.global_position.distance_squared_to(local_pos) > 900.0 and ((h.entity_id + _vfx_frame_counter) % 3) != 0:
					continue
		StatusEffectsVFX.update_hero_client_visuals(h, local_hero, delta, vehicles_by_id, heroes_by_id)
	for v_key in vehicles_by_id.keys():
		StatusEffectsVFX.update_vehicle_client_visuals(vehicles_by_id[v_key] as VehicleBase, local_hero, heroes_by_id)


func _on_game_event(event_type: String, payload: Dictionary) -> void:
	match event_type:
		"shot_vfx":
			var shooter_id: int = int(payload.get("shooter_id", -1))
			var w_kind: int = int(payload.get("weapon_kind", 0))
			var w_arch: int = int(payload.get("archetype", 0))
			var is_continuous_flame: bool = (w_kind == WeaponBase.WeaponKind.FLAMETHROWER and w_arch != 2)
			var shooter: HeroCharacter = heroes_by_id.get(shooter_id, null)
			var origin_fallback: Vector3 = payload.get("origin", Vector3.ZERO)
			var is_vehicle_shot: bool = bool(payload.get("vehicle_shot", false))
			var hand: int = int(payload.get("hand", -1))
			var use_origin: bool = is_vehicle_shot or shooter == null or shooter.current_vehicle_id >= 0
			var muzzle_pos: Vector3 = origin_fallback if use_origin else shooter.get_muzzle_world_position(hand)
			var aim_dir: Vector3 = payload.get("dir", Vector3.FORWARD)
			var is_remote_client_own_shot: bool = (shooter_id == NetworkManager.local_peer_id and not NetworkManager.is_server_authority())

			if not is_remote_client_own_shot or is_vehicle_shot:
				var local_hero: HeroCharacter = heroes_by_id.get(NetworkManager.local_peer_id, null)
				if local_hero != null and is_instance_valid(local_hero):
					SoundSynthesizer.set_listener_position(local_hero.global_position + Vector3(0.0, 1.5, 0.0))
				var is_local_shooter: bool = (shooter_id == NetworkManager.local_peer_id and (shooter == null or not shooter.is_bot))
				var dist_m: float = 0.0
				if not is_local_shooter and local_hero != null:
					dist_m = local_hero.global_position.distance_to(muzzle_pos)
				var play_sfx_now: bool = true
				if is_continuous_flame:
					var now_ms: int = Time.get_ticks_msec()
					var prev_ms: int = int(_last_flame_sfx_msec.get(shooter_id, -10000))
					if now_ms - prev_ms < 200:
						play_sfx_now = false
					else:
						_last_flame_sfx_msec[shooter_id] = now_ms
				if play_sfx_now:
					SoundSynthesizer.play_weapon_fire(w_kind, dist_m, is_local_shooter, muzzle_pos, w_arch)
				if shooter != null and not is_vehicle_shot:
					shooter.trigger_weapon_fire_visual(w_kind, shooter_id == NetworkManager.local_peer_id and not shooter.is_bot, hand)
				if not is_continuous_flame:
					StatusEffectsVFX.spawn_muzzle_flash(projectiles_root, muzzle_pos, aim_dir, w_kind, false, w_arch)

			if is_continuous_flame and projectiles_root != null:
				var hit_arr: Array = payload.get("hits", [])
				var end_pt: Vector3 = hit_arr[0] as Vector3 if (not hit_arr.is_empty() and hit_arr[0] is Vector3) else (muzzle_pos + aim_dir * 21.0)
				var stream_len: float = clampf(muzzle_pos.distance_to(end_pt), 0.5, 22.0)
				StatusEffectsVFX.update_continuous_flame_stream(projectiles_root, shooter_id, muzzle_pos, aim_dir, stream_len, w_arch == 1)
			else:
				var arcs: Array = payload.get("arcs", [])
				if not arcs.is_empty():
					for arc_var in arcs:
						if arc_var is PackedVector3Array or arc_var is Array:
							var arc_pts: PackedVector3Array = arc_var if arc_var is PackedVector3Array else PackedVector3Array(arc_var)
							if arc_pts.size() >= 2 and muzzle_pos.distance_to(arc_pts[arc_pts.size() - 1]) > 1.5 and muzzle_pos.distance_to(arc_pts[0]) < 3.0:
								arc_pts = arc_pts.duplicate()
								arc_pts[0] = muzzle_pos
							StatusEffectsVFX.spawn_curved_tracer(projectiles_root, arc_pts, w_kind)
				else:
					for hp_var in payload.get("hits", []):
						if hp_var is Vector3:
							StatusEffectsVFX.spawn_bullet_tracer(projectiles_root, muzzle_pos, hp_var as Vector3, w_kind)
		"proj_vfx":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var vp := ProjectileEntity.new()
				vp.setup_visual(payload)
				projectiles_root.add_child(vp)
		"proj_destroy":
			if not NetworkManager.is_server_authority():
				var target_uid: int = int(payload.get("uid", 0))
				if target_uid > 0:
					if is_inside_tree():
						for node in get_tree().get_nodes_in_group("client_proj_vfx"):
							if node is ProjectileEntity and (node as ProjectileEntity).proj_uid == target_uid and not node.is_queued_for_deletion():
								node.queue_free()
					if projectiles_root != null:
						for ch in projectiles_root.get_children():
							if ch is ProjectileEntity and (ch as ProjectileEntity).proj_uid == target_uid and bool(ch.get_meta("visual_only", false)) and not ch.is_queued_for_deletion():
								ch.queue_free()
		"hit_vfx":
			var hit_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var hit_kind: String = str(payload.get("kind", "dust"))
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, hit_pos, hit_kind, 0.4)
			var dmg_amt: int = int(payload.get("damage", 0))
			if int(payload.get("attacker_id", -1)) == NetworkManager.local_peer_id and hit_kind != "dust" and dmg_amt > 0:
				var is_crit: bool = bool(payload.get("headshot", false))
				SoundSynthesizer.play_sfx("crit" if is_crit else "hit", 0.0, true)
				if hud != null:
					hud.show_hitmarker(is_crit)
					var s_tag: String = str(payload.get("dot", ""))
					if s_tag.is_empty() and bool(payload.get("is_vehicle", false)):
						s_tag = "vehicle"
					hud.spawn_damage_number(hit_pos, dmg_amt, is_crit, s_tag)
		"explosion_vfx":
			var exp_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var exp_radius: float = float(payload.get("radius", 5.0))
			var exp_kind: int = int(payload.get("kind", -1))
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, exp_pos, "explosion", exp_radius)
			StatusEffectsVFX.spawn_explosion_area_ring(projectiles_root, exp_pos, exp_radius)
			var exp_attacker_id: int = int(payload.get("attacker_id", -1))
			var exp_sfx: String = "flashbang" if exp_kind == ProjectileEntity.ProjectileKind.FLASHBANG else "explosion"
			SoundSynthesizer.play_sfx(exp_sfx, 0.0, exp_attacker_id == NetworkManager.local_peer_id, exp_pos)
		"vehicle_destroyed":
			var v_id_dead: int = int(payload.get("vehicle_id", -1))
			var v_type: int = int(payload.get("vehicle_type", 0))
			if v_type == VehicleBase.VehicleType.MOUNTED_MG and v_id_dead >= 0:
				var dead_v := vehicles_by_id.get(v_id_dead, null) as VehicleBase
				vehicles_by_id.erase(v_id_dead)
				if dead_v != null and is_instance_valid(dead_v) and not dead_v.is_queued_for_deletion():
					if dead_v.has_method("disable_shield_collision"):
						dead_v.disable_shield_collision()
					dead_v.queue_free()
				_live_vehicles_dirty = true
				_refresh_combat_context()
				_sync_hud_vehicles()
			var attacker_id: int = int(payload.get("attacker_id", -1))
			var attacker: HeroCharacter = heroes_by_id.get(attacker_id, null)
			if NetworkManager.is_server_authority() and attacker != null and attacker.skill_manager != null and attacker.skill_manager.has_method("award_xp"):
				attacker.skill_manager.award_xp(45)
			if hud != null:
				var a_name: String = attacker.hero_name if attacker != null else "Alguém"
				var v_label: String = HUDController.get_vehicle_display_name(v_type)
				hud.add_killfeed("%s destruiu %s!" % [a_name, v_label])
		"skill_vfx":
			var skill_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var skill_caster_id: int = int(payload.get("hero_id", payload.get("caster_id", -1)))
			var skill_slot: int = int(payload.get("slot", 0))
			var skill_cls: int = int(payload.get("class_id", 0))
			var caster_hero: HeroCharacter = heroes_by_id.get(skill_caster_id, null)
			var caster_yaw: float = caster_hero.aim_yaw if caster_hero != null else 0.0
			if caster_hero != null and caster_hero.has_method("trigger_skill_visual"):
				caster_hero.trigger_skill_visual(skill_cls, skill_slot)
			StatusEffectsVFX.spawn_skill_vfx(projectiles_root, skill_cls, skill_slot, skill_pos, caster_yaw)
			var aoe_radius: float = float(payload.get("aoe_radius", 0.0))
			if aoe_radius > 0.0:
				var aoe_origin: Vector3 = payload.get("aoe_origin", skill_pos)
				var affected_positions: Array[Vector3] = []
				for tid in payload.get("affected_ids", []):
					var th: HeroCharacter = heroes_by_id.get(int(tid), null)
					if th != null and is_instance_valid(th):
						affected_positions.append(th.global_position)
				StatusEffectsVFX.spawn_aoe_area_vfx(projectiles_root, skill_cls, skill_slot, aoe_origin, aoe_radius, affected_positions)
			SoundSynthesizer.play_sfx("heal", 0.0, skill_caster_id == NetworkManager.local_peer_id, skill_pos)
		"eat_grenades":
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, payload.get("pos", Vector3.ZERO), "heal", 1.8)
		"armor_kit_spawn":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var spawn_uid: int = int(payload.get("kit_uid", 0))
				var dup_kit: DemolisherSkills.ArmorKitEntity = null
				for ch in projectiles_root.get_children():
					if ch is DemolisherSkills.ArmorKitEntity and not ch.is_queued_for_deletion() and (ch as DemolisherSkills.ArmorKitEntity).kit_uid == spawn_uid:
						dup_kit = ch as DemolisherSkills.ArmorKitEntity
						break
				if dup_kit != null:
					dup_kit.set_charges_visual(int(payload.get("charges", dup_kit.charges)))
				else:
					var kit := DemolisherSkills.ArmorKitEntity.new()
					kit.set_meta("visual_only", true)
					kit.owner_id = int(payload.get("owner_id", -1))
					kit.owner_team = int(payload.get("team", 0))
					kit.kit_uid = spawn_uid
					kit.charges = int(payload.get("charges", 5))
					kit.position = payload.get("pos", Vector3.ZERO)
					projectiles_root.add_child(kit)
		"armor_kit_update":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var upd_uid: int = int(payload.get("kit_uid", 0))
				var upd_charges: int = int(payload.get("charges", 0))
				for ch in projectiles_root.get_children():
					if ch is DemolisherSkills.ArmorKitEntity and (ch as DemolisherSkills.ArmorKitEntity).kit_uid == upd_uid:
						(ch as DemolisherSkills.ArmorKitEntity).set_charges_visual(upd_charges)
		"armor_kit_empty", "armor_kit_removed":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var empty_uid: int = int(payload.get("kit_id", payload.get("kit_uid", 0)))
				for ch in projectiles_root.get_children():
					if ch is DemolisherSkills.ArmorKitEntity and (ch as DemolisherSkills.ArmorKitEntity).kit_uid == empty_uid:
						ch.remove_from_group("armor_kits")
						ch.queue_free()
		"armor_kit_vfx":
			var kit_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var kit_hero_id: int = int(payload.get("hero_id", -1))
			if projectiles_root != null:
				StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, kit_pos, "heal", 0.9)
			SoundSynthesizer.play_sfx("heal", 0.0, kit_hero_id == NetworkManager.local_peer_id, kit_pos)
		"fire_patch_spawn":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var spawn_pos: Vector3 = payload.get("pos", Vector3.ZERO)
				var spawn_owner: int = int(payload.get("owner_id", -1))
				var refreshed: bool = false
				for ch in projectiles_root.get_children():
					if ch is DemolisherSkills.FirePatchEntity and not ch.is_queued_for_deletion():
						var fp_old := ch as DemolisherSkills.FirePatchEntity
						if fp_old.owner_id == spawn_owner and fp_old.position.distance_to(spawn_pos) <= 0.5:
							fp_old._lifetime_elapsed = 0.0
							refreshed = true
							break
				if not refreshed:
					var fp := DemolisherSkills.FirePatchEntity.new()
					fp.set_meta("visual_only", true)
					fp.owner_id = spawn_owner
					fp.owner_team = int(payload.get("team", 0))
					fp.radius = float(payload.get("radius", 2.6))
					fp.max_lifetime = float(payload.get("lifetime", 6.0))
					fp.position = spawn_pos
					projectiles_root.add_child(fp)
		"fire_patch_extinguish":
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				DemolisherSkills.FirePatchEntity.extinguish_near(
					payload.get("pos", Vector3.ZERO),
					float(payload.get("radius", 6.0)),
					projectiles_root
				)
		"fire_patch_vfx":
			if projectiles_root != null:
				var fp_pos: Vector3 = payload.get("pos", Vector3.ZERO)
				StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, fp_pos, "fire", 1.1)
				var fp_owner: int = int(payload.get("owner_id", -1))
				for ch in projectiles_root.get_children():
					if ch is DemolisherSkills.FirePatchEntity and not ch.is_queued_for_deletion():
						var fp_node := ch as DemolisherSkills.FirePatchEntity
						if bool(fp_node.get_meta("visual_only", false)) and (fp_owner < 0 or fp_node.owner_id == fp_owner) and fp_node.position.distance_to(fp_pos) <= 2.0:
							fp_node._lifetime_elapsed = 0.0
		"caber_spent":
			var c_hero: HeroCharacter = heroes_by_id.get(int(payload.get("hero_id", -1)), null)
			if c_hero != null and is_instance_valid(c_hero) and c_hero.has_method("set_caber_spent_visual"):
				c_hero.set_caber_spent_visual(bool(payload.get("spent", true)))
		"kill_event":
			if int(payload.get("killer_id", -1)) == NetworkManager.local_peer_id and hud != null:
				hud.show_hitmarker(false, true)
			if hud != null:
				hud.add_killfeed("%s defeated %s (-%d Tickets)" % [str(payload.get("killer", "?")), str(payload.get("victim", "?")), int(payload.get("tickets_lost", 0))])
		"match_over":
			if hud != null:
				hud.add_killfeed("VICTORY: %s WINS!" % str(payload.get("winner", "")))
		"upgrade_skill":
			if NetworkManager.is_server_authority():
				var hid: int = int(payload.get("hero_id", -1))
				var h: HeroCharacter = heroes_by_id.get(hid, null)
				if h != null and h.skill_manager != null and h.skill_manager.has_method("upgrade_skill"):
					h.skill_manager.upgrade_skill(int(payload.get("slot", -1)))
		"mortar_mode":
			var m_hero_id: int = int(payload.get("hero_id", -1))
			var active_m: bool = bool(payload.get("active", false))
			var m_hero: HeroCharacter = heroes_by_id.get(m_hero_id, null)
			if m_hero != null and is_instance_valid(m_hero) and m_hero.has_method("trigger_mortar_visual"):
				m_hero.trigger_mortar_visual("deploy" if active_m else "stow")
			if m_hero_id == NetworkManager.local_peer_id and hud != null and hud.has_method("set_mortar_targeting_mode"):
				hud.set_mortar_targeting_mode(active_m, func(world_pos: Vector3) -> void:
					NetworkManager.send_mortar_target(world_pos.x, world_pos.z)
				)
		"mortar_cancel":
			var mc_hero_id: int = int(payload.get("hero_id", -1))
			var mc_hero: HeroCharacter = heroes_by_id.get(mc_hero_id, null)
			if mc_hero != null and is_instance_valid(mc_hero) and mc_hero.has_method("trigger_mortar_visual"):
				mc_hero.trigger_mortar_visual("stow")
		"mortar_strike":
			var ms_hero_id: int = int(payload.get("hero_id", -1))
			var ms_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var ms_rad: float = float(payload.get("radius", 13.0))
			var ms_delay: float = float(payload.get("delay", 1.25))
			var ms_hero: HeroCharacter = heroes_by_id.get(ms_hero_id, null)
			if ms_hero != null and is_instance_valid(ms_hero) and ms_hero.has_method("trigger_mortar_visual"):
				ms_hero.trigger_mortar_visual("fire")
			var ms_origin: Vector3 = payload.get("shooter_pos", Vector3.ZERO)
			if ms_hero != null and is_instance_valid(ms_hero) and ms_hero.has_method("get_mortar_muzzle_world_position"):
				ms_origin = ms_hero.get_mortar_muzzle_world_position()
			elif ms_origin == Vector3.ZERO:
				ms_origin = ms_pos + Vector3(0.0, 1.0, 0.0)
			if projectiles_root != null:
				StatusEffectsVFX.spawn_mortar_warning_ring(projectiles_root, ms_pos, ms_rad, ms_delay)
				StatusEffectsVFX.spawn_mortar_shell_arc(projectiles_root, ms_origin, ms_pos, ms_delay)
			SoundSynthesizer.play_sfx("mortar_whistle", 0.0, false, ms_pos)
		"mortar_explode":
			var me_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var me_rad: float = float(payload.get("radius", 13.0))
			var me_hero_id: int = int(payload.get("hero_id", -1))
			if projectiles_root != null:
				StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, me_pos, "explosion", me_rad)
				StatusEffectsVFX.spawn_explosion_area_ring(projectiles_root, me_pos, me_rad)
			SoundSynthesizer.play_sfx("explosion", 0.0, me_hero_id == NetworkManager.local_peer_id, me_pos)
		"trench_spawn":
			var ts_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var ts_owner: int = int(payload.get("owner_id", -1))
			var ts_tid: int = int(payload.get("trench_id", -1))
			SoundSynthesizer.play_sfx("build_construct", 0.0, ts_owner == NetworkManager.local_peer_id, ts_pos)
			if not NetworkManager.is_server_authority() and projectiles_root != null:
				var already_has_trench: bool = false
				for ch in projectiles_root.get_children():
					if ch is EngineerSkillsScript.TrenchEntity and not ch.is_queued_for_deletion() and (ch as EngineerSkillsScript.TrenchEntity).trench_id == ts_tid:
						already_has_trench = true
						break
				if not already_has_trench:
					var vis_t := EngineerSkillsScript.TrenchEntity.new()
					vis_t._is_visual_only = true
					vis_t.trench_id = ts_tid
					vis_t.owner_id = ts_owner
					vis_t.team = int(payload.get("team", 0))
					vis_t.position = ts_pos
					vis_t.rotation.y = float(payload.get("yaw", 0.0))
					projectiles_root.add_child(vis_t)
		"trench_destroyed":
			var td_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var td_id: int = int(payload.get("trench_id", -1))
			if projectiles_root != null:
				StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, td_pos, "explosion", 2.2)
				if not NetworkManager.is_server_authority():
					for ch in projectiles_root.get_children():
						if ch is EngineerSkillsScript.TrenchEntity and (ch as EngineerSkillsScript.TrenchEntity).trench_id == td_id:
							(ch as EngineerSkillsScript.TrenchEntity).disable_collision()
							ch.queue_free()
			SoundSynthesizer.play_sfx("explosion", 0.0, false, td_pos)
		"eng_turret_spawn":
			var et_vid: int = int(payload.get("vehicle_id", -1))
			var et_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var et_yaw: float = float(payload.get("yaw", 0.0))
			var et_owner: int = int(payload.get("owner_id", -1))
			var found_turret: VehicleBase = null
			if projectiles_root != null:
				for ch in projectiles_root.get_children():
					if ch is VehicleShieldedMG and (ch as VehicleBase).id == et_vid:
						found_turret = ch as VehicleBase
						break
			if found_turret == null and vehicles_root != null:
				for ch in vehicles_root.get_children():
					if ch is VehicleShieldedMG and (ch as VehicleBase).id == et_vid:
						found_turret = ch as VehicleBase
						break
			if found_turret == null and not NetworkManager.is_server_authority() and vehicles_root != null:
				var vis_turret := VehicleShieldedMGScript.new() as VehicleShieldedMG
				vis_turret.id = et_vid
				vis_turret.team = int(payload.get("team", 0))
				vis_turret.owner_id = et_owner
				vis_turret.position = et_pos
				vis_turret.rotation.y = et_yaw
				vis_turret.turret_yaw = et_yaw
				vehicles_root.add_child(vis_turret)
				found_turret = vis_turret
			if found_turret != null:
				vehicles_by_id[et_vid] = found_turret
				_live_vehicles_dirty = true
				_refresh_combat_context()
				_sync_vehicle_authority_freeze()
				_sync_hud_vehicles()
			SoundSynthesizer.play_sfx("build_construct", 0.0, et_owner == NetworkManager.local_peer_id, et_pos)
		"veh_armored":
			var av_id: int = int(payload.get("vehicle_id", -1))
			var av_node: VehicleBase = vehicles_by_id.get(av_id, null) as VehicleBase
			if av_node != null and is_instance_valid(av_node):
				av_node.is_armored = true
				av_node.max_hp = int(payload.get("max_hp", av_node.max_hp))
				av_node.hp = int(payload.get("hp", av_node.hp))
				av_node.attach_engineer_armor_visuals()
			SoundSynthesizer.play_sfx("build_construct", 0.0, int(payload.get("hero_id", -1)) == NetworkManager.local_peer_id, av_node.global_position if av_node != null else Vector3.ZERO)
		"eng_build_start":
			var eb_hero_id: int = int(payload.get("hero_id", -1))
			var eb_slot: int = int(payload.get("slot", -1))
			var eb_dur: float = float(payload.get("duration", 2.0))
			var eb_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			var eb_yaw: float = float(payload.get("yaw", 0.0))
			if projectiles_root != null:
				StatusEffectsVFX.spawn_build_preview(projectiles_root, eb_hero_id, eb_slot, eb_pos, eb_yaw, eb_dur)
			if eb_hero_id == NetworkManager.local_peer_id and hud != null and hud.has_method("start_build_progress"):
				hud.start_build_progress(eb_slot, eb_dur)
		"eng_build_stop":
			var ebs_hero_id: int = int(payload.get("hero_id", -1))
			StatusEffectsVFX.stop_build_preview(ebs_hero_id)
			if ebs_hero_id == NetworkManager.local_peer_id and hud != null and hud.has_method("stop_build_progress"):
				hud.stop_build_progress()
		"uav_pulse":
			var uav_team: int = int(payload.get("team", -1))
			var uav_dur: float = float(payload.get("duration", 1.0))
			if uav_team >= 0:
				StatusEffectContainer.trigger_team_uav(uav_team, uav_dur)
			var uav_hero_id: int = int(payload.get("hero_id", -1))
			var uav_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			SoundSynthesizer.play_sfx("radar", 0.0, uav_hero_id == NetworkManager.local_peer_id, uav_pos)
		"flashbang_blind":
			var fb_hero_id: int = int(payload.get("hero_id", -1))
			var fb_dur: float = float(payload.get("duration", 0.0))
			var fb_int: float = float(payload.get("intensity", 0.0))
			if fb_hero_id == NetworkManager.local_peer_id:
				SoundSynthesizer.play_sfx("flashbang", 0.0, true)
				if hud != null and hud.has_method("trigger_flashbang_blind"):
					hud.trigger_flashbang_blind(fb_dur, fb_int)
		"pickaxe_swing":
			var pk_hero_id: int = int(payload.get("hero_id", -1))
			var pk_hero: HeroCharacter = heroes_by_id.get(pk_hero_id, null)
			if pk_hero != null and is_instance_valid(pk_hero):
				pk_hero.trigger_weapon_fire_visual(WeaponBase.WeaponKind.PICKAXE, false)
			var pk_pos: Vector3 = payload.get("pos", Vector3.ZERO)
			SoundSynthesizer.play_sfx("pickaxe", 0.0, pk_hero_id == NetworkManager.local_peer_id, pk_pos)


func _get_live_vehicles_array() -> Array[VehicleBase]:
	if not _live_vehicles_dirty:
		for vb in _live_vehicles_cache:
			if vb == null or not is_instance_valid(vb) or vb.is_queued_for_deletion():
				_live_vehicles_dirty = true
				break
	if _live_vehicles_dirty:
		_live_vehicles_cache.clear()
		for v_val in vehicles_by_id.values():
			var vb := v_val as VehicleBase
			if vb != null and is_instance_valid(vb) and not vb.is_queued_for_deletion():
				_live_vehicles_cache.append(vb)
		_live_vehicles_dirty = false
	return _live_vehicles_cache


func _sync_hud_vehicles() -> void:
	if hud != null:
		hud.bind_context(conquest_manager, _get_live_vehicles_array(), heroes_by_id)


func _on_mortar_target_received(peer_id: int, wx: float, wz: float) -> void:
	if not NetworkManager.is_server_authority():
		return
	var hero: HeroCharacter = heroes_by_id.get(peer_id, null)
	if hero == null or not is_instance_valid(hero) or hero.is_defeated:
		return
	if hero.skill_manager != null and hero.skill_manager.has_method("fire_mortar_at"):
		if _cached_combat_ctx.is_empty():
			_refresh_combat_context()
		hero.skill_manager.fire_mortar_at(Vector3(wx, 0.0, wz), _cached_combat_ctx)


func _on_mortar_cancel_received(peer_id: int) -> void:
	if not NetworkManager.is_server_authority():
		return
	var hero: HeroCharacter = heroes_by_id.get(peer_id, null)
	if hero != null and is_instance_valid(hero) and hero.skill_manager != null and hero.skill_manager.has_method("cancel_mortar_mode"):
		hero.skill_manager.cancel_mortar_mode()
