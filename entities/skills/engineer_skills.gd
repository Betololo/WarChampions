class_name EngineerSkills
extends SkillManager

## Field Engineer Class Skills (Slots 0..4, Ranks 1..5):
## 0: Trincheira (3.0s build, 850 HP cover trench 5.0m x 3.0m w/ interior platform & stairs, max 1, 18s CD on destroy)
## 1: Metralhadora Montada c/ Escudo (2.0s build, 320 HP shielded 360° turret, max 1, 18s CD on destroy)
## 2: Blindar Veiculo (2.0s channel on occupied or nearest <= 7m allied/empty vehicle -> 2x max HP + armor plates, 20s CD)
## 3: Morteiro via Minimapa (HUD minimap click or bot target -> 1.5s warning strike -> 7.0m radius 80 max AoE dmg, 18s CD)
## 4: Armadura Invulneravel (1.5s full damage immunity aura, 18s CD)

const VehicleShieldedMGScript := preload("res://entities/vehicles/vehicle_shielded_mg.gd")

const MORTAR_RADIUS: float = 7.0
const MORTAR_DELAY: float = 1.5
const MORTAR_MAX_DAMAGE: int = 80
const ARMOR_RANGE: float = 7.0


class TrenchEntity:
	extends StaticBody3D

	const MAX_HP: int = 850
	const TRENCH_WIDTH: float = 5.0
	const PARAPET_HEIGHT: float = 2.75
	const PILLAR_HEIGHT: float = 3.0

	static var _shared_meshes: Dictionary = {}
	static var _shared_mats: Dictionary = {}

	var trench_id: int = -1
	var owner_id: int = -1
	var team: int = 0
	var hp: int = MAX_HP
	var max_hp: int = MAX_HP
	var is_destroyed: bool = false
	var on_destroyed: Callable = Callable()
	var _is_visual_only: bool = false

	static func _get_shared_box(key: String, size: Vector3) -> BoxMesh:
		if _shared_meshes.has(key):
			return _shared_meshes[key] as BoxMesh
		var bm := BoxMesh.new()
		bm.size = size
		_shared_meshes[key] = bm
		return bm

	static func _get_shared_mat(key: String, albedo: Color, rough: float = 0.78, metallic: float = 0.05) -> StandardMaterial3D:
		if _shared_mats.has(key):
			return _shared_mats[key] as StandardMaterial3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = albedo
		mat.roughness = rough
		mat.metallic = metallic
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared_mats[key] = mat
		return mat

	func _ready() -> void:
		if _is_visual_only:
			collision_layer = 0
			collision_mask = 0
		else:
			collision_layer = 1 | 64
			collision_mask = 0
			add_to_group("destructible")
			add_to_group("trenches")
		_build_geometry()

	func _add_part(mesh: Mesh, mat: Material, pos: Vector3, rot_x: float = 0.0, add_box_col: Vector3 = Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation.x = rot_x
		add_child(mi)
		if not _is_visual_only and add_box_col != Vector3.ZERO:
			var col := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = add_box_col
			col.shape = box
			col.position = pos
			col.rotation.x = rot_x
			add_child(col)

	func _build_geometry() -> void:
		var sand_mat: StandardMaterial3D = _get_shared_mat("sandbag", Color(0.56, 0.50, 0.36), 0.88, 0.0)
		var wood_mat: StandardMaterial3D = _get_shared_mat("timber", Color(0.36, 0.25, 0.16), 0.82, 0.02)
		var steel_mat: StandardMaterial3D = _get_shared_mat("steel", Color(0.24, 0.27, 0.31), 0.42, 0.65)
		var team_col: Color = Color(0.18, 0.45, 0.90) if team == 0 else Color(0.86, 0.24, 0.20)
		var team_mat: StandardMaterial3D = _get_shared_mat("team_%d" % team, team_col, 0.55, 0.15)

		# Front reinforced parapet wall (5.0m wide x 2.75m tall so hero on 1.55m deck shoots over)
		_add_part(
			_get_shared_box("parapet_wall", Vector3(5.0, PARAPET_HEIGHT, 0.42)),
			sand_mat,
			Vector3(0.0, PARAPET_HEIGHT * 0.5, -0.95),
			0.0,
			Vector3(5.0, PARAPET_HEIGHT, 0.42)
		)
		# Top armored steel coping along parapet crest
		_add_part(
			_get_shared_box("parapet_cap", Vector3(5.04, 0.12, 0.48)),
			steel_mat,
			Vector3(0.0, PARAPET_HEIGHT + 0.04, -0.95)
		)
		# Team stripe badge on front wall
		_add_part(
			_get_shared_box("team_badge", Vector3(2.2, 0.24, 0.06)),
			team_mat,
			Vector3(0.0, 1.85, -1.18)
		)

		# Full-height 3.0m armored side corner pillars (gives full 5.0m x 3.0m silhouette + flank cover)
		var pillar_mesh: BoxMesh = _get_shared_box("pillar", Vector3(0.54, PILLAR_HEIGHT, 0.68))
		for sx in [-1.0, 1.0]:
			_add_part(
				pillar_mesh,
				steel_mat,
				Vector3(sx * 2.23, PILLAR_HEIGHT * 0.5, -0.88),
				0.0,
				Vector3(0.54, PILLAR_HEIGHT, 0.68)
			)

		# Side flank walls enclosing the firing deck
		var cheek_mesh: BoxMesh = _get_shared_box("cheek_wall", Vector3(0.32, 1.75, 1.48))
		for sx in [-1.0, 1.0]:
			_add_part(
				cheek_mesh,
				sand_mat,
				Vector3(sx * 2.24, 0.875, 0.10),
				0.0,
				Vector3(0.32, 1.75, 1.48)
			)

		# Interior raised wooden firing platform (y = 1.55m -> hero muzzle clears 2.75m parapet)
		_add_part(
			_get_shared_box("firing_deck", Vector3(4.12, 1.55, 1.28)),
			wood_mat,
			Vector3(0.0, 0.775, -0.10),
			0.0,
			Vector3(4.12, 1.55, 1.28)
		)

		# Climbable rear stair steps (4 visual steps + smooth 40.7-deg sloped collider for glide-up)
		var step_mesh: BoxMesh = _get_shared_box("stair_step", Vector3(2.40, 0.39, 0.48))
		for step_i in range(4):
			var sy: float = 0.195 + float(step_i) * 0.385
			var sz: float = 2.10 - float(step_i) * 0.45
			_add_part(step_mesh, wood_mat, Vector3(0.0, sy, sz))

		if not _is_visual_only:
			# Smooth sloped collider spanning ground (z=2.34, y=0) up to firing deck (z=0.54, y=1.55)
			var ramp_col := CollisionShape3D.new()
			var ramp_box := BoxShape3D.new()
			ramp_box.size = Vector3(2.50, 0.22, 2.38)
			ramp_col.shape = ramp_box
			ramp_col.position = Vector3(0.0, 0.72, 1.44)
			ramp_col.rotation.x = atan2(1.55, 1.80)
			add_child(ramp_col)

	func apply_damage_server(
		amount: int,
		_attacker_id: int = -1,
		_dir: Vector3 = Vector3.ZERO,
		_hit_pos: Vector3 = Vector3.ZERO,
		_is_explosive: bool = false
	) -> int:
		if is_destroyed or amount <= 0:
			return 0
		var dealt: int = mini(hp, amount)
		hp = maxi(0, hp - amount)
		if hp <= 0:
			is_destroyed = true
			collision_layer = 0
			remove_from_group("destructible")
			remove_from_group("trenches")
			if on_destroyed.is_valid():
				on_destroyed.call(trench_id)
			NetworkManager.broadcast_game_event("trench_destroyed", {
				"trench_id": trench_id,
				"pos": global_position if is_inside_tree() else position,
			})
			queue_free()
		return dealt


var _active_trench: TrenchEntity = null
var _active_turret: VehicleShieldedMG = null
var _active_build_slot: int = -1
var _build_timer: float = 0.0
var _build_total: float = 0.0
var _build_target_veh: VehicleBase = null
var _mortar_pending_hero_aim: bool = false
var _pending_mortars: Array[Dictionary] = []
var _last_context: Dictionary = {}
var _mortar_stepped_frame: int = -1
var _next_deploy_id: int = 1


func _init() -> void:
	skill_names = [
		"Trincheira",
		"Metralhadora Montada",
		"Blindar Veículo",
		"Morteiro",
		"Invulnerável",
	]
	skill_max_cooldowns = [18.0, 18.0, 20.0, 18.0, 18.0]


func _defers_cooldown_until_exit(slot_idx: int) -> bool:
	return slot_idx in [0, 1, 2, 3]


func blocks_weapon_fire() -> bool:
	return _active_build_slot >= 0


func is_building() -> bool:
	return _active_build_slot >= 0


func get_build_progress_fraction() -> float:
	if _active_build_slot < 0 or _build_total <= 0.0:
		return 0.0
	return clampf(1.0 - (_build_timer / _build_total), 0.0, 1.0)


func step_server(delta: float, cmd: InputCmd, context: Dictionary, allow_class_skills: bool = true) -> void:
	_last_context = context
	_mortar_stepped_frame = Engine.get_physics_frames()
	_step_pending_mortars(delta, context)
	_step_active_build(delta, context)

	# Keep skill_max_cooldowns responsive while trench or turret is deployed
	if _active_trench != null and not is_instance_valid(_active_trench):
		_active_trench = null
	if _active_turret != null and not is_instance_valid(_active_turret):
		_active_turret = null

	super.step_server(delta, cmd, context, allow_class_skills and _active_build_slot < 0)


func _physics_process(delta: float) -> void:
	if Engine.get_physics_frames() != _mortar_stepped_frame and not _pending_mortars.is_empty():
		_step_pending_mortars(delta, _last_context)


func _step_active_build(delta: float, context: Dictionary) -> void:
	if _active_build_slot < 0:
		return
	if owner_hero == null or owner_hero.is_defeated:
		_active_build_slot = -1
		_build_timer = 0.0
		_build_target_veh = null
		return
	_build_timer -= delta
	if _build_timer > 0.0:
		return

	var finished_slot: int = _active_build_slot
	var target_veh: VehicleBase = _build_target_veh
	_active_build_slot = -1
	_build_timer = 0.0
	_build_target_veh = null

	match finished_slot:
		0:
			_complete_trench_spawn(context)
		1:
			_complete_turret_spawn(context)
		2:
			_complete_vehicle_armor(target_veh)


func _execute_class_skill(slot_idx: int, _rank: int, _cmd: InputCmd, context: Dictionary) -> bool:
	if owner_hero == null or _active_build_slot >= 0:
		return false

	match slot_idx:
		0: # Trincheira (3.0s build, max 1 active, 18s CD starts ONLY after destroyed)
			if owner_hero.current_vehicle_id >= 0:
				return false
			if _active_trench != null and is_instance_valid(_active_trench) and not _active_trench.is_destroyed:
				return false
			_active_build_slot = 0
			_build_total = 3.0
			_build_timer = 3.0
			return true

		1: # Metralhadora Montada c/ Escudo (2.0s build, max 1 active, 18s CD starts ONLY after destroyed)
			if owner_hero.current_vehicle_id >= 0:
				return false
			if _active_turret != null and is_instance_valid(_active_turret) and not _active_turret.is_destroyed:
				return false
			_active_build_slot = 1
			_build_total = 2.0
			_build_timer = 2.0
			return true

		2: # Blindar Veiculo (2.0s channel on occupied or nearest <= 7.0m allied/empty vehicle)
			var veh: VehicleBase = _find_armor_target_vehicle(context)
			if veh == null or veh.is_armored:
				return false
			_active_build_slot = 2
			_build_total = 2.0
			_build_timer = 2.0
			_build_target_veh = veh
			return true

		3: # Morteiro via Minimapa
			var is_bot: bool = bool(NetworkManager.players_info.get(owner_hero.entity_id, {}).get("is_bot", false))
			if is_bot:
				var bot_target: Vector3 = _pick_bot_mortar_target(context)
				if bot_target == Vector3.INF:
					return false
				return fire_mortar_at(bot_target, context)
			if _mortar_pending_hero_aim:
				return false
			_mortar_pending_hero_aim = true
			NetworkManager.broadcast_game_event("mortar_mode", {
				"hero_id": owner_hero.entity_id,
				"active": true,
			})
			return true

		4: # Armadura Invulneravel (1.5s full damage immunity)
			if owner_hero.status_effects != null:
				owner_hero.status_effects.activate_invulnerability(1.5)
			return true

	return false


func cancel_mortar_mode() -> void:
	_mortar_pending_hero_aim = false


func fire_mortar_at(target_xz: Vector3, context: Dictionary) -> bool:
	if owner_hero == null or owner_hero.is_defeated:
		_mortar_pending_hero_aim = false
		return false
	if skill_cooldowns.size() > 3 and skill_cooldowns[3] > 0.0:
		_mortar_pending_hero_aim = false
		return false
	_mortar_pending_hero_aim = false

	var strike_pos := Vector3(target_xz.x, target_xz.y, target_xz.z)
	if owner_hero.is_inside_tree() and owner_hero.get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = owner_hero.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(target_xz.x, 85.0, target_xz.z),
			Vector3(target_xz.x, -40.0, target_xz.z),
			1
		)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			strike_pos.y = (hit["position"] as Vector3).y

	skill_cooldowns[3] = skill_max_cooldowns[3]
	skill_activated.emit(3, skill_cooldowns[3])

	_pending_mortars.append({
		"pos": strike_pos,
		"timer": MORTAR_DELAY,
		"heroes": context.get("heroes", {}),
		"vehicles": context.get("vehicles", []),
		"root": context.get("projectiles_root", owner_hero.get_parent()),
	})

	NetworkManager.broadcast_game_event("mortar_strike", {
		"hero_id": owner_hero.entity_id,
		"team": owner_hero.team,
		"pos": strike_pos,
		"radius": MORTAR_RADIUS,
		"delay": MORTAR_DELAY,
	})
	return true


func _pick_bot_mortar_target(context: Dictionary) -> Vector3:
	if owner_hero == null:
		return Vector3.INF
	var heroes: Dictionary = context.get("heroes", {})
	var best_pos: Vector3 = Vector3.INF
	var best_dist: float = 95.0
	var my_pos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	for hid in heroes.keys():
		var h: HeroCharacter = heroes[hid] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated or h.team == owner_hero.team:
			continue
		var hpos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var d: float = my_pos.distance_to(hpos)
		if d >= 8.0 and d < best_dist:
			best_dist = d
			best_pos = hpos
	return best_pos


func _step_pending_mortars(delta: float, context: Dictionary) -> void:
	if _pending_mortars.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for strike in _pending_mortars:
		var t: float = float(strike.get("timer", 0.0)) - delta
		strike["timer"] = t
		if t <= 0.0:
			_detonate_mortar(strike, context)
		else:
			remaining.append(strike)
	_pending_mortars = remaining


func _detonate_mortar(strike: Dictionary, context: Dictionary) -> void:
	var strike_pos: Vector3 = strike.get("pos", Vector3.ZERO) as Vector3
	var attacker_id: int = owner_hero.entity_id if owner_hero != null else -1
	var attacker_team: int = owner_hero.team if owner_hero != null else 0

	var heroes_dict: Dictionary = context.get("heroes", strike.get("heroes", {}))
	for hid in heroes_dict.keys():
		var h: HeroCharacter = heroes_dict[hid] as HeroCharacter
		if h == null or not is_instance_valid(h) or h.is_defeated:
			continue
		if h.team == attacker_team and h.entity_id != attacker_id:
			continue
		var hpos: Vector3 = h.global_position if h.is_inside_tree() else h.position
		var dist: float = hpos.distance_to(strike_pos)
		if dist <= MORTAR_RADIUS:
			var falloff: float = clampf(1.0 - (dist / MORTAR_RADIUS) * 0.6, 0.4, 1.0)
			var dmg: int = maxi(1, int(roundf(float(MORTAR_MAX_DAMAGE) * falloff)))
			h.apply_damage_server(dmg, attacker_id, true)
			var push_dir: Vector3 = (hpos - strike_pos)
			push_dir.y = 0.0
			if push_dir.length_squared() < 0.01:
				push_dir = Vector3.FORWARD
			h.apply_knockback((push_dir.normalized() + Vector3.UP * 0.55).normalized() * (11.0 * falloff))

	var vehicles_arr: Array = context.get("vehicles", strike.get("vehicles", []))
	for v_node in vehicles_arr:
		if not (v_node is VehicleBase) or not is_instance_valid(v_node):
			continue
		var v: VehicleBase = v_node as VehicleBase
		if v.is_destroyed:
			continue
		var vpos: Vector3 = v.global_position if v.is_inside_tree() else v.position
		var dist_v: float = vpos.distance_to(strike_pos)
		if dist_v <= MORTAR_RADIUS + 2.0:
			var v_falloff: float = clampf(1.0 - (dist_v / (MORTAR_RADIUS + 2.0)) * 0.6, 0.4, 1.0)
			var vdmg: int = maxi(1, int(roundf(float(MORTAR_MAX_DAMAGE) * 1.25 * v_falloff)))
			var hit_dir: Vector3 = (vpos - strike_pos).normalized()
			v.apply_damage_server(vdmg, attacker_id, hit_dir, strike_pos, true)

	if owner_hero != null and owner_hero.is_inside_tree():
		for d in owner_hero.get_tree().get_nodes_in_group("destructible"):
			if d is Node3D and is_instance_valid(d) and d.has_method("apply_damage_server"):
				var dpos: Vector3 = (d as Node3D).global_position
				if dpos.distance_to(strike_pos) <= MORTAR_RADIUS:
					d.apply_damage_server(MORTAR_MAX_DAMAGE, attacker_id, Vector3.UP, strike_pos, true)

	NetworkManager.broadcast_game_event("mortar_explode", {
		"hero_id": attacker_id,
		"pos": strike_pos,
		"radius": MORTAR_RADIUS,
	})


func _get_deploy_origin_and_yaw(forward_dist: float) -> Dictionary:
	var hpos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var fwd: Vector3 = -Basis(Vector3.UP, owner_hero.aim_yaw).z
	fwd.y = 0.0
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var spawn_pos: Vector3 = hpos + fwd * forward_dist
	if owner_hero.is_inside_tree() and owner_hero.get_world_3d() != null:
		var space: PhysicsDirectSpaceState3D = owner_hero.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			spawn_pos + Vector3(0.0, 3.0, 0.0),
			spawn_pos + Vector3(0.0, -5.0, 0.0),
			1
		)
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty():
			spawn_pos.y = (hit["position"] as Vector3).y
	return {"pos": spawn_pos, "yaw": owner_hero.aim_yaw}


func _complete_trench_spawn(context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return
	var root: Node = context.get("projectiles_root", owner_hero.get_parent())
	if root == null:
		return
	var deploy: Dictionary = _get_deploy_origin_and_yaw(3.4)
	var spawn_pos: Vector3 = deploy["pos"] as Vector3
	var yaw: float = float(deploy["yaw"])

	var trench := TrenchEntity.new()
	_next_deploy_id += 1
	trench.trench_id = owner_hero.entity_id * 1000 + _next_deploy_id
	trench.owner_id = owner_hero.entity_id
	trench.team = owner_hero.team
	trench.position = spawn_pos
	trench.rotation.y = yaw
	trench.on_destroyed = func(_tid: int) -> void:
		if is_instance_valid(self):
			_active_trench = null
			if skill_cooldowns.size() > 0:
				skill_cooldowns[0] = skill_max_cooldowns[0]
				skill_activated.emit(0, skill_cooldowns[0])

	root.add_child(trench)
	_active_trench = trench

	NetworkManager.broadcast_game_event("trench_spawn", {
		"trench_id": trench.trench_id,
		"owner_id": owner_hero.entity_id,
		"team": owner_hero.team,
		"pos": spawn_pos,
		"yaw": yaw,
	})


func _complete_turret_spawn(context: Dictionary) -> void:
	if owner_hero == null or owner_hero.is_defeated:
		return
	var root: Node = context.get("vehicles_root", context.get("projectiles_root", owner_hero.get_parent()))
	if root == null:
		return
	var deploy: Dictionary = _get_deploy_origin_and_yaw(2.6)
	var spawn_pos: Vector3 = deploy["pos"] as Vector3
	var yaw: float = float(deploy["yaw"])

	var vehicles_arr: Array = context.get("vehicles", [])
	var max_vid: int = 40
	for existing in vehicles_arr:
		if existing is VehicleBase and is_instance_valid(existing):
			max_vid = maxi(max_vid, (existing as VehicleBase).id)
	var turret_vid: int = clampi(max_vid + 1, 1, 250)

	var turret := VehicleShieldedMGScript.new() as VehicleShieldedMG
	turret.id = turret_vid
	turret.name = "MountedMG_%d" % turret_vid
	turret.team = owner_hero.team
	turret.owner_id = owner_hero.entity_id
	turret.owner_team = owner_hero.team
	turret.position = spawn_pos
	turret.rotation.y = yaw
	turret.turret_yaw = yaw
	turret.spawn_transform = Transform3D(Basis(Vector3.UP, yaw), spawn_pos)
	turret.on_turret_destroyed = func() -> void:
		if is_instance_valid(self):
			_active_turret = null
			if skill_cooldowns.size() > 1:
				skill_cooldowns[1] = skill_max_cooldowns[1]
				skill_activated.emit(1, skill_cooldowns[1])

	root.add_child(turret)
	_active_turret = turret
	if not vehicles_arr.has(turret):
		vehicles_arr.append(turret)

	NetworkManager.broadcast_game_event("eng_turret_spawn", {
		"vehicle_id": turret.id,
		"owner_id": owner_hero.entity_id,
		"team": turret.team,
		"pos": spawn_pos,
		"yaw": yaw,
	})


func _find_armor_target_vehicle(context: Dictionary) -> VehicleBase:
	if owner_hero == null:
		return null
	var vehicles: Array = context.get("vehicles", [])
	if owner_hero.current_vehicle_id >= 0:
		for v_node in vehicles:
			if v_node is VehicleBase and is_instance_valid(v_node):
				var v: VehicleBase = v_node as VehicleBase
				if v.id == owner_hero.current_vehicle_id and not v.is_destroyed:
					return v

	var hpos: Vector3 = owner_hero.global_position if owner_hero.is_inside_tree() else owner_hero.position
	var best_v: VehicleBase = null
	var best_dist: float = ARMOR_RANGE
	for v_node in vehicles:
		if not (v_node is VehicleBase) or not is_instance_valid(v_node):
			continue
		var v: VehicleBase = v_node as VehicleBase
		if v.is_destroyed or v.is_armored:
			continue
		# Must be empty or currently occupied only by allied team
		var has_occupant: bool = false
		var has_enemy: bool = false
		for seat in v.seats:
			if seat.occupant_id >= 0:
				has_occupant = true
				if v.team != owner_hero.team:
					has_enemy = true
		if has_enemy or (has_occupant and v.team != owner_hero.team):
			continue
		var vpos: Vector3 = v.global_position if v.is_inside_tree() else v.position
		var dist: float = hpos.distance_to(vpos)
		if dist <= best_dist:
			best_dist = dist
			best_v = v
	return best_v


func _complete_vehicle_armor(target_veh: VehicleBase) -> void:
	if target_veh == null or not is_instance_valid(target_veh) or target_veh.is_destroyed:
		return
	if target_veh.apply_engineer_armor():
		if skill_cooldowns.size() > 2:
			skill_cooldowns[2] = skill_max_cooldowns[2]
			skill_activated.emit(2, skill_cooldowns[2])
		NetworkManager.broadcast_game_event("veh_armored", {
			"vehicle_id": target_veh.id,
			"hero_id": owner_hero.entity_id if owner_hero != null else -1,
			"max_hp": target_veh.max_hp,
			"hp": target_veh.hp,
		})
