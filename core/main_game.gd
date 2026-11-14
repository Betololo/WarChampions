class_name MainGame
extends Node3D

## Bootstrap game coordinator connecting NetworkManager, players, bots, map, and HUD.
var heroes_root: Node3D
var vehicles_root: Node3D
var projectiles_root: Node3D
var map_root: Node3D
var heroes_by_id: Dictionary = {}


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

	NetworkManager.client_input_received.connect(_on_client_input)
	NetworkManager.authoritative_state_received.connect(_on_auth_state)
	NetworkManager.world_snapshot_received.connect(_on_world_snapshot)
	NetworkManager.player_registered.connect(_on_player_registered)
	NetworkManager.player_unregistered.connect(_on_player_unregistered)

	if NetworkManager.is_dedicated_server:
		_build_fallback_arena()


func _build_fallback_arena() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "FallbackFloor"
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 2.0, 200.0)
	col.shape = box
	col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(col)
	map_root.add_child(floor_body)


func _physics_process(_delta: float) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		for id_key in heroes_by_id.keys():
			var hero: HeroCharacter = heroes_by_id[id_key]
			if not hero.is_bot and hero.entity_id < 1000:
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

		if NetworkManager.should_broadcast_snapshot():
			var hero_snaps: Array[Dictionary] = []
			for id_key in heroes_by_id.keys():
				var h: HeroCharacter = heroes_by_id[id_key]
				hero_snaps.append(h.build_snapshot_dict())
			var empty_vehicles: Array[Dictionary] = []
			var empty_flags: Array[Dictionary] = []
			var srv_time_ms: int = int(roundf(float(NetworkManager.server_tick) * NetworkManager.TICK_INTERVAL_MS))
			var snap_bytes: PackedByteArray = NetSerializer.pack_world_snapshot(
				NetworkManager.server_tick,
				srv_time_ms,
				50,
				50,
				hero_snaps,
				empty_vehicles,
				empty_flags
			)
			NetworkManager.broadcast_world_snapshot(snap_bytes)


func _on_player_registered(peer_id: int, info: Dictionary) -> void:
	spawn_hero(peer_id, info)


func _on_player_unregistered(peer_id: int) -> void:
	if heroes_by_id.has(peer_id):
		var hero: HeroCharacter = heroes_by_id[peer_id]
		heroes_by_id.erase(peer_id)
		hero.queue_free()


func spawn_hero(entity_id: int, info: Dictionary) -> HeroCharacter:
	if heroes_by_id.has(entity_id):
		return heroes_by_id[entity_id]
	var hero := HeroCharacter.new()
	var is_local: bool = (entity_id == NetworkManager.local_peer_id) and not bool(info.get("is_bot", false)) and not NetworkManager.is_dedicated_server
	hero.setup_identity(
		entity_id,
		str(info.get("name", "Hero")),
		int(info.get("team", 0)),
		int(info.get("class_id", 0)),
		int(info.get("archetype", 0)),
		is_local,
		bool(info.get("is_bot", false))
	)
	var team_offset: float = -40.0 if hero.team == 0 else 40.0
	hero.position = Vector3(team_offset, 2.0, float((entity_id % 12) - 6) * 3.0)
	heroes_root.add_child(hero)
	heroes_by_id[entity_id] = hero
	return hero


func _on_client_input(peer_id: int, cmd: InputCmd) -> void:
	if heroes_by_id.has(peer_id):
		var hero: HeroCharacter = heroes_by_id[peer_id]
		hero.latest_server_input = cmd


func _on_auth_state(state: Dictionary) -> void:
	var local_hero: HeroCharacter = heroes_by_id.get(NetworkManager.local_peer_id, null)
	if local_hero != null:
		local_hero.reconcile_with_server(state)


func _on_world_snapshot(snapshot: Dictionary) -> void:
	var srv_tick: int = int(snapshot.get("server_tick", 0))
	var srv_time_ms: float = float(snapshot.get("server_time_ms", 0))
	var heroes_arr: Array = snapshot.get("heroes", [])
	for h_dict in heroes_arr:
		var hid: int = int(h_dict.get("id", 0))
		if hid == NetworkManager.local_peer_id:
			continue
		if not heroes_by_id.has(hid):
			spawn_hero(hid, {
				"name": "Hero_%d" % hid,
				"team": int(h_dict.get("team", 0)),
				"class_id": int(h_dict.get("class_id", 0)),
				"is_bot": hid >= 1000,
			})
		var remote_hero: HeroCharacter = heroes_by_id[hid]
		remote_hero.push_remote_snapshot(srv_tick, srv_time_ms, h_dict)
