class_name MainGame
extends Node3D

## Master game coordinator for War Champions:
## Connects NetworkManager, MapSeasideFrontline (12v12 Land/Air/Water),
## ConquestManager (50 Tickets + 4 Flags), Vehicles, Bots, HUD & Class Menu.

const MAP_SCENE: PackedScene = preload("res://maps/seaside_frontline.tscn")

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
var _prev_local_parachuting: bool = false
var _last_local_level: int = 1
var _royal_spawn_idx: int = 0
var _national_spawn_idx: int = 0
var _switching_mode: bool = false
var _loading_in_progress: bool = false
var _skip_loading_screen: bool = false

var _loading_layer: CanvasLayer
var _loading_stage_lbl: Label
var _loading_bar: ProgressBar


func _ready() -> void:
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


func _on_connection_state_changed(connected: bool, is_srv: bool) -> void:
	_sync_vehicle_authority_freeze()
	if hud == null:
		return
	if connected and is_srv:
		if NetworkManager.is_solo_bot_mode:
			hud.add_killfeed("Modo Solo 12v12 com Bots pronto!")
		else:
			hud.add_killfeed("Sala Online pronta (0 Bots, porta %d)" % NetworkManager.DEFAULT_PORT)
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
		var should_freeze: bool = (v.vehicle_type == VehicleBase.VehicleType.AA_GUN) or not auth
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

	map_instance = MAP_SCENE.instantiate() as MapSeasideFrontline
	map_root.add_child(map_instance)
	map_instance.build_map(conquest_manager, vehicles_root, _build_combat_context())
	for v in map_instance.spawned_vehicles:
		vehicles_by_id[v.id] = v
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
	map_lbl.text = "SEASIDE FRONTLINE  •  12 vs 12"
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
	set_loading_state(true, 75.0, "Compilando shaders e cachê da GPU...")
	var prewarm_node: Node3D = GameCache.prewarm_gpu_pipelines(self)
	await get_tree().process_frame
	if prewarm_node != null:
		await get_tree().process_frame
		GameCache.cleanup_prewarm(prewarm_node)

	set_loading_state(true, 92.0, deploy_text)
	on_ready_call.call()
	await get_tree().process_frame

	set_loading_state(true, 100.0, "Partida pronta!")
	set_loading_state(false, 100.0, "")
	_loading_in_progress = false
	if class_menu != null and not class_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and class_menu != null:
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
	NetworkManager.set_local_loadout("HostHero", team, class_id, NetworkManager.ARCHETYPE_BALANCED)
	NetworkManager.start_host(port, false)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
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
	NetworkManager.set_local_loadout("ClientHero", team, class_id, NetworkManager.ARCHETYPE_BALANCED)
	NetworkManager.join_server(ip, port)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
	SoundSynthesizer.start_whistle_theme()


func _on_play_offline_bots(team: int, class_id: int) -> void:
	if _should_use_loading_screen():
		_run_with_loading_screen("Posicionando pelotões 12 vs 12 e iniciando partida...", func() -> void:
			_start_bots_sync(team, class_id)
		)
		return
	_start_bots_sync(team, class_id)


func _start_bots_sync(team: int, class_id: int) -> void:
	_switching_mode = true
	_clear_match_entities()
	conquest_manager.reset_match()
	NetworkManager.set_local_loadout("Hero", team, class_id, NetworkManager.ARCHETYPE_BALANCED)
	NetworkManager.start_host(NetworkManager.DEFAULT_PORT, true)
	_sync_vehicle_authority_freeze()
	_switching_mode = false
	_spawn_12v12_bots(team)
	SoundSynthesizer.start_whistle_theme()


func _clear_match_entities() -> void:
	_royal_spawn_idx = 0
	_national_spawn_idx = 0
	if hud != null:
		hud.set_local_hero(null)
		hud.clear_killfeed()
	for b in bots_root.get_children():
		b.queue_free()
	bot_brains.clear()
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if is_instance_valid(h):
			h.queue_free()
	heroes_by_id.clear()


func _spawn_12v12_bots(human_team: int) -> void:
	# 12 Royal + 12 National = 24 combatants total (human + 23 bots)
	var bot_id: int = 1000
	var ally_count: int = 11
	var enemy_count: int = 12
	var enemy_team: int = NetworkManager.TEAM_NATIONAL if human_team == NetworkManager.TEAM_ROYAL else NetworkManager.TEAM_ROYAL

	for i in range(ally_count):
		var cls: int = i % 3
		NetworkManager.register_bot(bot_id, "AllyBot_%d" % (i + 1), human_team, cls, i % 3)
		bot_id += 1
	for j in range(enemy_count):
		var cls_e: int = j % 3
		NetworkManager.register_bot(bot_id, "EnemyBot_%d" % (j + 1), enemy_team, cls_e, j % 3)
		bot_id += 1


func _build_combat_context() -> Dictionary:
	return {
		"lag_compensator": lag_compensator,
		"heroes_by_id": heroes_by_id,
		"projectiles_root": projectiles_root,
		"vehicles": vehicles_by_id.values(),
		"vehicles_by_id": vehicles_by_id,
		"on_damage_dealt": _on_damage_dealt_xp,
	}


func _on_damage_dealt_xp(attacker: HeroCharacter, _victim: HeroCharacter, dealt: int) -> void:
	if attacker != null and dealt > 0 and attacker.skill_manager != null and attacker.skill_manager.has_method("award_xp"):
		attacker.skill_manager.award_xp(maxi(5, dealt / 4))


func _physics_process(delta: float) -> void:
	if NetworkManager.is_active_host_authority():
		var combat_ctx: Dictionary = _build_combat_context()

		# 1. Step AI Bots
		var cps: Array[CapturePoint] = map_instance.capture_points if map_instance != null else []
		var veh_arr: Array[VehicleBase] = map_instance.spawned_vehicles if map_instance != null else []
		for bid in bot_brains.keys():
			var brain: BotController = bot_brains[bid]
			var bhero: HeroCharacter = heroes_by_id.get(bid, null)
			if bhero != null:
				bhero.latest_server_input = brain.step_ai(delta, cps, heroes_by_id, veh_arr)

		# 2. Step Heroes, Vehicle Interact, Skills, Weapons, Respawns
		for id_key in heroes_by_id.keys():
			var hero: HeroCharacter = heroes_by_id[id_key]
			if hero.is_defeated:
				if hero.defeat_timer <= 0.0:
					var sp: Vector3 = _get_next_spawn_pos(hero.team)
					hero.respawn_at(sp, -PI * 0.5 if hero.team == NetworkManager.TEAM_ROYAL else PI * 0.5)
				continue

			_handle_vehicle_interact(hero)

			if hero.skill_manager != null and hero.skill_manager.has_method("step_server"):
				hero.skill_manager.step_server(delta, hero.latest_server_input, combat_ctx)

			if hero.current_vehicle_id < 0 and not hero.weapons.is_empty():
				var slot: int = clampi(hero.latest_server_input.selected_weapon_slot, 0, hero.weapons.size() - 1)
				hero.selected_weapon_slot = slot
				var w: WeaponBase = hero.weapons[slot] as WeaponBase
				if w != null:
					var was_reloading: bool = w.is_reloading
					w.step_timers(delta, hero.latest_server_input)
					if not was_reloading and w.is_reloading and hero.entity_id == NetworkManager.local_peer_id and not hero.is_bot:
						SoundSynthesizer.play_sfx("reload", 0.0, true)
					if w.try_consume_fire(hero.latest_server_input):
						w.fire_server(hero.latest_server_input, combat_ctx)

			if not hero.is_bot and hero.entity_id != 1:
				var packed: PackedByteArray = NetSerializer.pack_authoritative_state(
					hero.latest_server_input.tick,
					hero.global_position,
					hero.velocity,
					hero.active_flags,
					hero.hp,
					hero.shield,
					hero.current_vehicle_id,
					hero.current_seat_index,
					hero.knockback_seq
				)
				NetworkManager.send_authoritative_state(hero.entity_id, packed)

		# 3. Step Vehicles & Conquest Flags
		for v in veh_arr:
			v.step_vehicle_server(delta, heroes_by_id, combat_ctx)

		conquest_manager.step_server(delta, heroes_by_id)
		lag_compensator.record_frame(NetworkManager.server_tick, heroes_by_id)

		# 4. Broadcast WorldSnapshot @ 30 Hz
		if NetworkManager.should_broadcast_snapshot():
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


func _handle_vehicle_interact(hero: HeroCharacter) -> void:
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


func _on_player_registered(peer_id: int, info: Dictionary) -> void:
	spawn_hero(peer_id, info)


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


func spawn_hero(entity_id: int, info: Dictionary) -> HeroCharacter:
	if heroes_by_id.has(entity_id):
		return heroes_by_id[entity_id]
	var hero := HeroCharacter.new()
	var is_bot: bool = bool(info.get("is_bot", false))
	var is_local: bool = (entity_id == NetworkManager.local_peer_id) and not is_bot and not NetworkManager.is_dedicated_server
	hero.setup_identity(
		entity_id,
		str(info.get("name", "Hero")),
		int(info.get("team", 0)),
		int(info.get("class_id", 0)),
		int(info.get("archetype", 0)),
		is_local,
		is_bot
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
		if hero.hero_camera != null:
			hero.hero_camera.mouse_sensitivity = ClassSelectMenu.current_mouse_sensitivity
			hero.hero_camera.sensitivity = ClassSelectMenu.current_mouse_sensitivity
		_last_local_level = 1
		_prev_local_parachuting = hero.is_parachuting
		if hero.skill_manager != null and hero.skill_manager.has_signal("progression_changed"):
			hero.skill_manager.progression_changed.connect(func(lvl: int, _xp: int, _xp_next: int, _pts: int) -> void:
				if lvl > _last_local_level:
					_last_local_level = lvl
					SoundSynthesizer.play_sfx("level_up", 0.0, true)
			)
		if hud != null:
			hud.set_local_hero(hero)

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
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		StatusEffectsVFX.update_hero_client_visuals(h, local_hero, delta, vehicles_by_id)


func _on_game_event(event_type: String, payload: Dictionary) -> void:
	match event_type:
		"shot_vfx":
			var shooter_id: int = int(payload.get("shooter_id", -1))
			var w_kind: int = int(payload.get("weapon_kind", 0))
			var shooter: HeroCharacter = heroes_by_id.get(shooter_id, null)
			var origin_fallback: Vector3 = payload.get("origin", Vector3.ZERO)
			var is_vehicle_shot: bool = bool(payload.get("vehicle_shot", false))
			var use_origin: bool = is_vehicle_shot or shooter == null or shooter.current_vehicle_id >= 0
			var muzzle_pos: Vector3 = origin_fallback if use_origin else shooter.get_muzzle_world_position()
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
				SoundSynthesizer.play_weapon_fire(w_kind, dist_m, is_local_shooter, muzzle_pos)
				if shooter != null and not is_vehicle_shot:
					shooter.trigger_weapon_fire_visual(w_kind, shooter_id == NetworkManager.local_peer_id and not shooter.is_bot)
				StatusEffectsVFX.spawn_muzzle_flash(projectiles_root, muzzle_pos, aim_dir, w_kind)

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
				vp.set_meta("visual_only", true)
				vp.setup(
					int(payload.get("kind", 0)),
					-1,
					-1,
					payload.get("pos", Vector3.ZERO),
					payload.get("vel", Vector3.ZERO),
					{}
				)
				if payload.has("gravity_scale"):
					vp.gravity_scale = float(payload["gravity_scale"])
				if payload.has("lifetime"):
					vp.lifetime = float(payload["lifetime"])
				projectiles_root.add_child(vp)
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
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, exp_pos, "explosion", float(payload.get("radius", 5.0)))
			var exp_attacker_id: int = int(payload.get("attacker_id", -1))
			SoundSynthesizer.play_sfx("explosion", 0.0, exp_attacker_id == NetworkManager.local_peer_id, exp_pos)
		"vehicle_destroyed":
			var v_type: int = int(payload.get("vehicle_type", 0))
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
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, skill_pos, "heal", 1.2)
			var skill_caster_id: int = int(payload.get("hero_id", payload.get("caster_id", -1)))
			SoundSynthesizer.play_sfx("heal", 0.0, skill_caster_id == NetworkManager.local_peer_id, skill_pos)
		"eat_grenades":
			StatusEffectsVFX.spawn_cartoon_burst(projectiles_root, payload.get("pos", Vector3.ZERO), "heal", 1.8)
		"kill_event":
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
