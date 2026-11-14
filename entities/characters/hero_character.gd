class_name HeroCharacter
extends CharacterBody3D

## Server-authoritative hero character with 60Hz deterministic movement,
## Client-Side Prediction + Server Reconciliation (non-server clients),
## articulated cartoon rig & procedural animations, held 3D weapons,
## fall damage, infinite reusable parachute, swimming, and comic defeat.

signal stats_changed()
signal defeated(killer_id: int, explosive: bool)
signal respawned()
signal emote_triggered(emote_idx: int)

const GRAVITY: float = 22.0
const JUMP_VELOCITY: float = 8.8
const PARACHUTE_MAX_FALL: float = -3.8
const PARACHUTE_GLIDE_SPEED_MULT: float = 1.25
const PARACHUTE_MIN_FALL_TIME: float = 1.0
const CROUCH_SPEED_MULT: float = 0.58
const WATER_LEVEL: float = 0.0
const RECONCILE_THRESHOLD_METERS: float = 0.05
const STAND_HEIGHT: float = 1.85
const CROUCH_HEIGHT: float = 1.15
const FALL_DAMAGE_THRESHOLD_SPEED: float = 13.5

var entity_id: int = 1
var hero_name: String = "Hero"
var team: int = 0 # 0 = Royal, 1 = National
var class_id: int = 0 # 0 = Soldier, 1 = Gunner, 2 = Commando
var archetype: int = 0
var is_local_player: bool = false
var is_bot: bool = false

## Core Combat Stats
var max_hp: int = 110
var hp: int = 110
var shield: int = 0
var base_move_speed: float = 7.8
var speed_multiplier: float = 1.0
var capsule_radius: float = 0.42

## Movement & Action State
var is_parachuting: bool = false
var is_crouching: bool = false
var is_defeated: bool = false
var is_stealthed: bool = false
var is_scoping: bool = false
var is_in_water: bool = false
var is_emoting: bool = false
var emote_timer: float = 0.0
var defeat_timer: float = 0.0
var prev_jump_held: bool = false
var aim_yaw: float = 0.0
var aim_pitch: float = 0.0
var selected_weapon_slot: int = 0
var current_vehicle_id: int = -1
var current_seat_index: int = -1
var current_seat_enclosed: bool = false
var current_seat_pose: String = ""
var current_seat_can_shoot: bool = false
var _last_vehicle_id_for_cam: int = -1
var knockback_seq: int = 0
var active_flags: int = 0
var last_killer_id: int = -1
var defeat_explosive: bool = false
var _max_air_fall_speed: float = 0.0
var _was_airborne: bool = false
@export var _airborne_fall_time: float = 0.0
@export var _knockback_stun_timer: float = 0.0
@export var _defeat_elapsed: float = 0.0

## Networking & Prediction
var local_tick: int = 0
var input_buffer: InputRingBuffer = InputRingBuffer.new()
var snapshot_interpolator: SnapshotInterpolator = SnapshotInterpolator.new()
var latest_server_input: InputCmd = InputCmd.new()
var _last_processed_srv_tick: int = -1

## Decoupled Visual Smoothing & Articulated Rig
var visual_root: Node3D
@export var _pred_error_offset: Vector3 = Vector3.ZERO
var visual_error_offset: Vector3 = Vector3.ZERO
var _prev_phys_pos: Vector3 = Vector3.ZERO
var _curr_phys_pos: Vector3 = Vector3.ZERO

var _hips_pivot: Node3D
var _torso_pivot: Node3D
var _head_pivot: Node3D
var _arm_l_pivot: Node3D
var _arm_r_pivot: Node3D
var _forearm_l_pivot: Node3D
var _forearm_r_pivot: Node3D
var _leg_l_pivot: Node3D
var _leg_r_pivot: Node3D
var _held_weapon_root: Node3D
var _parachute_rig: Node3D
var _defeat_prop: Node3D
var _mesh_parts: Array[MeshInstance3D] = []
var _body_collision: CollisionShape3D
var _capsule_shape: CapsuleShape3D
var hero_camera: HeroCamera

var _walk_phase: float = 0.0
var _weapon_recoil_anim: float = 0.0
var _fire_pose_timer: float = 0.0
var _shown_weapon_kind: int = -1
var _prev_q_held: bool = false
var _upper_arm_len: float = 0.30
var _forearm_len: float = 0.28
var _weapon_grip_local: Vector3 = Vector3(0.0, -0.04, 0.0)
var _weapon_foregrip_local: Vector3 = Vector3(0.0, -0.015, -0.24)
var _weapon_muzzle_local: Vector3 = Vector3(0.0, 0.035, -0.58)
var _weapon_two_handed: bool = true

## Subsystems attached in Configure
var status_effects: Node = null
var skill_manager: Node = null
var weapons: Array[Node] = []


func _ready() -> void:
	collision_layer = 2 # PlayerBody
	collision_mask = 1 | 8 | 64 # World + Vehicle + Destructible (NO hero-on-hero capsule stacking)
	_build_collision()
	_build_cartoon_visuals()
	configure_class_loadout()
	StatusEffectsVFX.attach_hero_vfx_and_shader(self)
	_prev_phys_pos = global_position
	_curr_phys_pos = global_position

	if is_local_player:
		hero_camera = HeroCamera.new()
		hero_camera.name = "HeroCamera"
		add_child(hero_camera)
		hero_camera.global_position = visual_root.global_position if visual_root != null else global_position
		hero_camera.yaw = aim_yaw
		hero_camera.set_active_camera(true)
		hero_camera.scope_toggled.connect(_on_scope_toggled)
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not DisplayServer.get_name().contains("headless"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func setup_identity(p_entity_id: int, p_name: String, p_team: int, p_class_id: int, p_archetype: int, p_local: bool, p_bot: bool) -> void:
	entity_id = p_entity_id
	hero_name = p_name
	team = p_team
	class_id = p_class_id
	archetype = p_archetype
	is_local_player = p_local
	is_bot = p_bot
	aim_yaw = -PI * 0.5 if team == NetworkManager.TEAM_ROYAL else PI * 0.5
	if hero_camera != null:
		hero_camera.yaw = aim_yaw
		hero_camera.global_position = visual_root.global_position if visual_root != null else global_position
	name = "Hero_%d" % entity_id
	if is_inside_tree():
		configure_class_loadout()
		_rebuild_cartoon_visuals()
		StatusEffectsVFX.attach_hero_vfx_and_shader(self)
	else:
		_apply_class_defaults()


func configure_class_loadout() -> void:
	if status_effects != null:
		status_effects.queue_free()
		status_effects = null
	if skill_manager != null:
		skill_manager.queue_free()
		skill_manager = null
	for w in weapons:
		if is_instance_valid(w):
			w.queue_free()
	weapons.clear()

	match class_id:
		NetworkManager.CLASS_SOLDIER:
			ClassSoldier.configure_hero(self)
		NetworkManager.CLASS_GUNNER:
			ClassGunner.configure_hero(self)
		NetworkManager.CLASS_COMMANDO:
			ClassCommando.configure_hero(self)

	for w in weapons:
		if w is WeaponBase:
			(w as WeaponBase).fired.connect(_on_weapon_fired_anim)

	if _capsule_shape != null:
		_capsule_shape.radius = capsule_radius
	_shown_weapon_kind = -1
	_rebuild_held_weapon_mesh()


func _apply_class_defaults() -> void:
	match class_id:
		NetworkManager.CLASS_SOLDIER:
			max_hp = 110
			base_move_speed = 7.8
			capsule_radius = 0.42
		NetworkManager.CLASS_GUNNER:
			max_hp = 150
			base_move_speed = 6.4
			capsule_radius = 0.54
		NetworkManager.CLASS_COMMANDO:
			max_hp = 80
			base_move_speed = 9.0
			capsule_radius = 0.36
	hp = max_hp
	if _capsule_shape != null:
		_capsule_shape.radius = capsule_radius


func _build_collision() -> void:
	_body_collision = CollisionShape3D.new()
	_body_collision.name = "BodyCollision"
	_capsule_shape = CapsuleShape3D.new()
	_capsule_shape.radius = capsule_radius
	_capsule_shape.height = STAND_HEIGHT
	_body_collision.shape = _capsule_shape
	_body_collision.position = Vector3(0.0, STAND_HEIGHT * 0.5, 0.0)
	add_child(_body_collision)


func _build_cartoon_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)
	_rebuild_cartoon_visuals()


func _get_visual_style(is_royal: bool) -> Dictionary:
	var jacket_tex: String = "hero_jacket_royal" if is_royal else "hero_jacket_national"
	var cloth_tex: String = "hero_cloth_royal" if is_royal else "hero_cloth_national"
	var pants_tex: String = "hero_pants_royal" if is_royal else "hero_pants_national"
	var style := {
		"is_royal": is_royal,
		"trim_col": Color(0.88, 0.72, 0.24) if is_royal else Color(0.78, 0.16, 0.18),
		"buckle_col": Color(0.90, 0.74, 0.26) if is_royal else Color(0.56, 0.59, 0.64),
		"badge_col": Color(0.92, 0.76, 0.26) if is_royal else Color(0.58, 0.61, 0.66),
		"torso_tex": jacket_tex,
		"torso_tint": Color.WHITE,
		"cloth_tex": cloth_tex,
		"cloth_tint": Color.WHITE,
		"arm_tex": cloth_tex,
		"arm_tint": Color.WHITE,
		"forearm_tex": cloth_tex,
		"forearm_tint": Color.WHITE,
		"pants_tex": pants_tex,
		"hand_tex": "hero_skin",
		"hand_tint": Color.WHITE,
		"hair_col": Color(0.36, 0.22, 0.11) if is_royal else Color(0.14, 0.13, 0.14),
		"hip_x": 0.14,
		"thigh_r": 0.095,
		"sh_x": 0.245,
		"arm_r_scale": 1.0,
		"arm_len_scale": 1.0,
		"beard_style": 0 if is_royal else 1,
		"use_shades": false,
		"shade_col": Color.WHITE,
		"headgear": "helmet" if is_royal else "officer_cap",
		"beret_col": Color.WHITE,
		"fedora_col": Color(0.32, 0.34, 0.22),
		"fedora_band": Color(0.82, 0.66, 0.24),
		"scarf_col": Color.TRANSPARENT,
		"rolled_vest_cap": false,
		"pauldron": false,
	}
	if class_id == NetworkManager.CLASS_GUNNER:
		style["torso_tex"] = "hero_gunner_vest" if is_royal else "hero_jacket_national"
		style["cloth_tex"] = "hero_cloth_gunner_royal" if is_royal else "hero_cloth_national"
		style["arm_tex"] = "hero_arm_tattoo" if is_royal else "hero_cloth_national"
		style["forearm_tex"] = "hero_arm_forearm_wrap" if is_royal else "hero_cloth_national"
		style["hair_col"] = Color(0.24, 0.15, 0.09) if is_royal else Color(0.14, 0.13, 0.14)
		style["hip_x"] = 0.18
		style["thigh_r"] = 0.115
		style["sh_x"] = 0.305
		style["arm_r_scale"] = 1.22
		style["arm_len_scale"] = 1.12
		style["beard_style"] = 2
		style["use_shades"] = true
		style["headgear"] = "beret"
		style["beret_col"] = Color(0.76, 0.14, 0.14) if is_royal else Color(0.23, 0.26, 0.22)
		style["rolled_vest_cap"] = is_royal
		style["pauldron"] = not is_royal
	elif class_id == NetworkManager.CLASS_COMMANDO:
		var coat_tint := Color.WHITE if is_royal else Color(0.94, 0.94, 0.98)
		var commando_cloth: String = "hero_cloth_commando_royal" if is_royal else "hero_cloth_commando_national"
		style["torso_tex"] = "hero_coat_commando_royal" if is_royal else "hero_coat_commando"
		style["torso_tint"] = coat_tint
		style["cloth_tex"] = commando_cloth
		style["cloth_tint"] = coat_tint
		style["arm_tex"] = commando_cloth
		style["arm_tint"] = coat_tint
		style["forearm_tex"] = commando_cloth
		style["forearm_tint"] = coat_tint
		style["hand_tex"] = "hero_leather"
		style["hand_tint"] = Color(0.56, 0.52, 0.48)
		style["hip_x"] = 0.135
		style["thigh_r"] = 0.090
		style["arm_r_scale"] = 0.96
		style["beard_style"] = -1
		style["use_shades"] = true
		style["shade_col"] = Color(1.0, 0.90, 0.64) if is_royal else Color(0.92, 0.78, 0.82)
		style["headgear"] = "fedora"
		style["fedora_col"] = Color(0.32, 0.34, 0.22) if is_royal else Color(0.12, 0.12, 0.14)
		style["fedora_band"] = Color(0.82, 0.66, 0.24) if is_royal else Color(0.84, 0.16, 0.18)
		style["scarf_col"] = Color(0.46, 0.40, 0.22) if is_royal else Color(0.68, 0.14, 0.16)
	return style


func _create_leg_rig(side_sign: float, hip_x: float, leg_mesh: Mesh, boot_mesh: Mesh, pants_mat: Material, boot_mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side_sign * hip_x, 0.0, 0.0)
	_hips_pivot.add_child(pivot)
	HeroMeshBuilder.add_part(pivot, leg_mesh, Vector3.ZERO, Vector3.ZERO, pants_mat, _mesh_parts)
	HeroMeshBuilder.add_part(pivot, boot_mesh, Vector3(0.0, -0.56, 0.0), Vector3.ZERO, boot_mat, _mesh_parts)
	return pivot


func _create_arm_rig(
	side_sign: float,
	sh_x: float,
	upper_mesh: Mesh,
	forearm_mesh: Mesh,
	hand_mesh: Mesh,
	cuff_mesh: Mesh,
	sleeve_cap_mesh: Mesh,
	upper_arm_mat: Material,
	forearm_mat: Material,
	cuff_mat: Material,
	hand_mat: Material,
	cap_mat: Material
) -> Array[Node3D]:
	var arm_pivot := Node3D.new()
	arm_pivot.position = Vector3(side_sign * sh_x, 0.505, 0.0)
	_torso_pivot.add_child(arm_pivot)
	HeroMeshBuilder.add_part(arm_pivot, upper_mesh, Vector3.ZERO, Vector3.ZERO, upper_arm_mat, _mesh_parts)
	if sleeve_cap_mesh != null:
		HeroMeshBuilder.add_part(arm_pivot, sleeve_cap_mesh, Vector3.ZERO, Vector3.ZERO, cap_mat, _mesh_parts)

	var forearm_pivot := Node3D.new()
	forearm_pivot.position = Vector3(0.0, -_upper_arm_len, 0.0)
	arm_pivot.add_child(forearm_pivot)
	HeroMeshBuilder.add_part(forearm_pivot, forearm_mesh, Vector3.ZERO, Vector3.ZERO, forearm_mat, _mesh_parts)
	if cuff_mesh != null:
		HeroMeshBuilder.add_part(forearm_pivot, cuff_mesh, Vector3(0.0, -_forearm_len * 0.88, 0.0), Vector3.ZERO, cuff_mat, _mesh_parts)
	var hand_rot := Vector3(0.0, PI if side_sign < 0.0 else 0.0, 0.0)
	HeroMeshBuilder.add_part(forearm_pivot, hand_mesh, Vector3(0.0, -_forearm_len, 0.0), hand_rot, hand_mat, _mesh_parts)
	return [arm_pivot, forearm_pivot]


func _attach_torso_gear(style: Dictionary, mats: Dictionary) -> void:
	var torso_mat: Material = mats["torso"]
	var cloth_mat: Material = mats["cloth"]
	var leather_mat: Material = mats["leather"]
	var ruck_mat: Material = mats["ruck"]
	var buckle_mat: Material = mats["buckle"]
	var prof: Dictionary = HeroMeshBuilder.get_torso_profile(class_id)
	var waist_rx: float = float(prof["waist_rx"])
	var waist_rz: float = float(prof["waist_rz"])

	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_torso_mesh(class_id), Vector3.ZERO, Vector3.ZERO, torso_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_collar_lapels_mesh(class_id), Vector3.ZERO, Vector3.ZERO, cloth_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_waist_belt_mesh(class_id), Vector3.ZERO, Vector3.ZERO, leather_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_buckle_mesh(), Vector3(0.0, 0.075, -(waist_rz + 0.022)), Vector3.ZERO, buckle_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_bandolier_mesh(class_id), Vector3.ZERO, Vector3.ZERO, leather_mat, _mesh_parts)

	var pack_mat: Material = leather_mat if class_id == NetworkManager.CLASS_COMMANDO else ruck_mat
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_backpack_mesh(class_id), Vector3.ZERO, Vector3.ZERO, pack_mat, _mesh_parts)
	if class_id == NetworkManager.CLASS_COMMANDO:
		HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_coat_tail_flap_mesh(), Vector3.ZERO, Vector3.ZERO, cloth_mat, _mesh_parts)

	var pouch_mesh := HeroMeshBuilder.build_belt_pouch_mesh()
	for side_sign in [-1.0, 1.0]:
		HeroMeshBuilder.add_part(_torso_pivot, pouch_mesh, Vector3(side_sign * (waist_rx + 0.025), 0.08, 0.02), Vector3(0.0, side_sign * -PI * 0.5, 0.0), ruck_mat, _mesh_parts)

	if not bool(style["rolled_vest_cap"]):
		var is_pauldron: bool = bool(style["pauldron"])
		var ep_mesh := HeroMeshBuilder.build_epaulet_mesh(is_pauldron)
		var ep_x: float = 0.255 if is_pauldron else 0.210
		var ep_y: float = 0.565 if is_pauldron else 0.578
		for side_sign in [-1.0, 1.0]:
			HeroMeshBuilder.add_part(_torso_pivot, ep_mesh, Vector3(side_sign * ep_x, ep_y, 0.0), Vector3(0.0, 0.0, side_sign * -0.20), cloth_mat, _mesh_parts)

	var scarf_col: Color = style["scarf_col"]
	if scarf_col.a > 0.01:
		var scarf_mat := HeroMeshBuilder.make_sculpted_mat(scarf_col, "", 0.78)
		HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_scarf_mesh(), Vector3.ZERO, Vector3.ZERO, scarf_mat, _mesh_parts)


func _attach_head_and_gear(style: Dictionary, mats: Dictionary) -> void:
	var skin_mat: Material = mats["skin"]
	var hair_mat: Material = mats["hair"]
	var badge_mat: Material = mats["badge"]

	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_head_mesh(), Vector3.ZERO, Vector3.ZERO, skin_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_hair_cap_mesh(), Vector3.ZERO, Vector3.ZERO, hair_mat, _mesh_parts)

	var ear_mesh := HeroMeshBuilder.build_ear_mesh()
	for side_sign in [-1.0, 1.0]:
		HeroMeshBuilder.add_part(_head_pivot, ear_mesh, Vector3(side_sign * 0.128, 0.215, 0.01), Vector3(0.0, 0.0, side_sign * -0.18), skin_mat, _mesh_parts)

	var nose_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.92, 0.72, 0.58), "", 0.72)
	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_nose_mesh(), Vector3(0.0, 0.205, -0.132), Vector3(-0.22, 0.0, 0.0), nose_mat, _mesh_parts)

	if bool(style["use_shades"]):
		var shade_mat := HeroMeshBuilder.make_sculpted_mat(style["shade_col"], "", 0.18)
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_sunglasses_mesh(), Vector3(0.0, 0.248, -0.142), Vector3.ZERO, shade_mat, _mesh_parts)
	else:
		var eyes_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.35)
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_eyes_mesh(), Vector3(0.0, 0.248, -0.138), Vector3.ZERO, eyes_mat, _mesh_parts)

	var beard_style: int = int(style["beard_style"])
	if beard_style >= 0:
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beard_mesh(beard_style), Vector3(0.0, 0.152, -0.128), Vector3.ZERO, hair_mat, _mesh_parts)

	match str(style["headgear"]):
		"helmet":
			var helmet_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.36)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_helmet_mesh(bool(style["is_royal"])), Vector3(0.0, 0.288, 0.0), Vector3(0.04, 0.0, 0.0), helmet_mat, _mesh_parts)
		"officer_cap":
			var cap_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.42)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_officer_cap_mesh(), Vector3(0.0, 0.290, 0.0), Vector3(-0.04, 0.0, 0.0), cap_mat, _mesh_parts)
		"beret":
			var beret_mat := HeroMeshBuilder.make_sculpted_mat(style["beret_col"], "", 0.80)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beret_mesh(), Vector3(-0.012, 0.302, 0.0), Vector3(0.04, 0.0, 0.18), beret_mat, _mesh_parts)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_badge_mesh(), Vector3(0.046, 0.343, -0.118), Vector3(-0.10, 0.0, 0.12), badge_mat, _mesh_parts)
		"fedora":
			var fedora_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.76)
			var fedora_mesh := HeroMeshBuilder.build_fedora_mesh(style["fedora_band"], style["fedora_col"])
			HeroMeshBuilder.add_part(_head_pivot, fedora_mesh, Vector3(0.0, 0.302, -0.004), Vector3(-0.12, 0.0, -0.06), fedora_mat, _mesh_parts)


func _rebuild_cartoon_visuals() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		child.queue_free()
	_mesh_parts.clear()

	var is_royal: bool = (team == NetworkManager.TEAM_ROYAL)
	var style: Dictionary = _get_visual_style(is_royal)
	var trim_col: Color = style["trim_col"]

	var mats := {
		"skin": HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "hero_skin", 0.72),
		"hair": HeroMeshBuilder.make_sculpted_mat(style["hair_col"], "", 0.78),
		"pants": HeroMeshBuilder.make_sculpted_mat(Color.WHITE, style["pants_tex"], 0.80),
		"boot": HeroMeshBuilder.make_sculpted_mat(Color(0.56, 0.52, 0.48), "hero_leather", 0.45),
		"leather": HeroMeshBuilder.make_sculpted_mat(Color(0.84, 0.82, 0.80), "hero_leather", 0.48),
		"ruck": HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "hero_rucksack", 0.78),
		"buckle": HeroMeshBuilder.make_sculpted_mat(style["buckle_col"], "", 0.28),
		"badge": HeroMeshBuilder.make_sculpted_mat(style["badge_col"], "", 0.28),
		"torso": HeroMeshBuilder.make_sculpted_mat(style["torso_tint"], style["torso_tex"], 0.76),
		"cloth": HeroMeshBuilder.make_sculpted_mat(style["cloth_tint"], style["cloth_tex"], 0.76),
		"arm": HeroMeshBuilder.make_sculpted_mat(style["arm_tint"], style["arm_tex"], 0.72 if str(style["arm_tex"]).begins_with("hero_arm_") else 0.76),
		"forearm": HeroMeshBuilder.make_sculpted_mat(style["forearm_tint"], style["forearm_tex"], 0.72 if str(style["forearm_tex"]).begins_with("hero_arm_") else 0.76),
		"hand": HeroMeshBuilder.make_sculpted_mat(style["hand_tint"], style["hand_tex"], 0.60 if style["hand_tex"] == "hero_leather" else 0.72),
	}

	_hips_pivot = Node3D.new()
	_hips_pivot.position = Vector3(0.0, 0.76, 0.0)
	visual_root.add_child(_hips_pivot)

	# Articulated Sculpted Legs & Chunky Combat Boots
	var hip_x: float = float(style["hip_x"])
	var leg_mesh: ArrayMesh = HeroMeshBuilder.build_leg_mesh(float(style["thigh_r"]))
	var boot_mesh: ArrayMesh = HeroMeshBuilder.build_boot_mesh()
	_leg_l_pivot = _create_leg_rig(-1.0, hip_x, leg_mesh, boot_mesh, mats["pants"], mats["boot"])
	_leg_r_pivot = _create_leg_rig(1.0, hip_x, leg_mesh, boot_mesh, mats["pants"], mats["boot"])

	# Upper Torso + Collar Lapels + Belt/Buckle/Pouches + Back Gear + Bandolier/Suspenders
	_torso_pivot = Node3D.new()
	_torso_pivot.position = Vector3(0.0, 0.04, 0.0)
	_hips_pivot.add_child(_torso_pivot)
	_attach_torso_gear(style, mats)

	# Head Pivot (Chiseled Jaw, Ears, Nose, Eyes/Shades, Beard/Mustache & Faction Headgear)
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 0.63, 0.0)
	_torso_pivot.add_child(_head_pivot)
	_attach_head_and_gear(style, mats)

	# Seamless Two-Bone IK Arms (Deltoid cap tucked inside shoulder armhole; zero ball-joint spheres!)
	var sh_x: float = float(style["sh_x"])
	var arm_r_scale: float = float(style["arm_r_scale"])
	var arm_len_scale: float = float(style["arm_len_scale"])
	_upper_arm_len = 0.30 * arm_len_scale
	_forearm_len = 0.28 * arm_len_scale

	var upper_arm_mesh: ArrayMesh = HeroMeshBuilder.build_arm_segment_mesh(0.088 * arm_r_scale, 0.072 * arm_r_scale, _upper_arm_len, true)
	var forearm_mesh: ArrayMesh = HeroMeshBuilder.build_arm_segment_mesh(0.068 * arm_r_scale, 0.056 * arm_r_scale, _forearm_len, false)
	var hand_mesh: ArrayMesh = HeroMeshBuilder.build_hand_mesh(arm_r_scale)
	var rolled_cap_mesh: Mesh = HeroMeshBuilder.build_rolled_sleeve_cap_mesh(0.088 * arm_r_scale) if bool(style["rolled_vest_cap"]) else null
	var cuff_mesh: Mesh = null if bool(style["rolled_vest_cap"]) else HeroMeshBuilder.build_cuff_mesh(0.062 * arm_r_scale)

	var left_arm: Array[Node3D] = _create_arm_rig(-1.0, sh_x, upper_arm_mesh, forearm_mesh, hand_mesh, cuff_mesh, rolled_cap_mesh, mats["arm"], mats["forearm"], mats["cloth"], mats["hand"], mats["cloth"])
	_arm_l_pivot = left_arm[0]
	_forearm_l_pivot = left_arm[1]
	var right_arm: Array[Node3D] = _create_arm_rig(1.0, sh_x, upper_arm_mesh, forearm_mesh, hand_mesh, cuff_mesh, rolled_cap_mesh, mats["arm"], mats["forearm"], mats["cloth"], mats["hand"], mats["cloth"])
	_arm_r_pivot = right_arm[0]
	_forearm_r_pivot = right_arm[1]

	# Held Weapon Root mounted on Torso (grip + foregrip sockets solved directly by IK!)
	_held_weapon_root = Node3D.new()
	_held_weapon_root.name = "HeldWeaponRoot"
	_held_weapon_root.position = Vector3(0.20, 0.30, -0.14)
	_torso_pivot.add_child(_held_weapon_root)
	_shown_weapon_kind = -1
	_rebuild_held_weapon_mesh()

	# Parachute Rig (Canopy + 4 cords)
	_parachute_rig = Node3D.new()
	_parachute_rig.name = "ParachuteRig"
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 2.0
	sph.height = 1.6
	canopy.mesh = sph
	canopy.scale = Vector3(1.15, 0.5, 1.15)
	canopy.position = Vector3(0.0, 3.25, 0.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = trim_col
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = cmat
	_parachute_rig.add_child(canopy)
	for cx in [-1.1, 1.1]:
		for cz in [-0.7, 0.7]:
			var cord := MeshInstance3D.new()
			var cbox := BoxMesh.new()
			cbox.size = Vector3(0.03, 1.9, 0.03)
			cord.mesh = cbox
			cord.position = Vector3(cx * 0.5, 2.35, cz * 0.5)
			cord.rotation.z = -cx * 0.25
			cord.rotation.x = cz * 0.25
			_parachute_rig.add_child(cord)
	_parachute_rig.visible = false
	visual_root.add_child(_parachute_rig)

	# Comic defeat prop (white surrender flag)
	_defeat_prop = Node3D.new()
	_defeat_prop.name = "DefeatProp"
	var pole := MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(0.04, 1.1, 0.04)
	pole.mesh = pbox
	pole.position = Vector3(0.45, 0.9, 0.0)
	var flag := MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(0.55, 0.35, 0.03)
	flag.mesh = fbox
	flag.position = Vector3(0.74, 1.25, 0.0)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color.WHITE
	flag.material_override = flag_mat
	_defeat_prop.add_child(pole)
	_defeat_prop.add_child(flag)
	_defeat_prop.visible = false
	visual_root.add_child(_defeat_prop)


func trim_mat_badge_mesh() -> Mesh:
	return HeroMeshBuilder.build_badge_mesh()


func _rebuild_held_weapon_mesh() -> void:
	if _held_weapon_root == null or weapons.is_empty():
		return
	var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
	var w: WeaponBase = weapons[slot] as WeaponBase
	if w == null or w.weapon_kind == _shown_weapon_kind:
		return
	_shown_weapon_kind = w.weapon_kind
	var w_info: Dictionary = HeroMeshBuilder.populate_weapon_root(_held_weapon_root, w.weapon_kind)
	_weapon_grip_local = w_info.get("grip", Vector3(0.0, -0.04, 0.0))
	_weapon_foregrip_local = w_info.get("foregrip", Vector3(0.0, -0.015, -0.24))
	_weapon_muzzle_local = w_info.get("muzzle", Vector3(0.0, 0.035, -0.58))
	_weapon_two_handed = bool(w_info.get("two_handed", true))


func apply_character_shader(shader: Shader) -> void:
	if shader == null:
		return
	for mi in _mesh_parts:
		if mi.material_override is ShaderMaterial:
			var existing := mi.material_override as ShaderMaterial
			existing.shader = shader
			continue
		var old_mat := mi.material_override as StandardMaterial3D
		var base_col: Color = old_mat.albedo_color if old_mat != null else Color.WHITE
		var tex_key: String = str(old_mat.get_meta("tex_key", "")) if old_mat != null else ""
		var rough: float = old_mat.roughness if old_mat != null else 0.68
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("albedo_color", base_col)
		if not tex_key.is_empty():
			smat.set_meta("tex_key", tex_key)
			smat.set_shader_parameter("use_tex", true)
			smat.set_shader_parameter("albedo_tex", CartoonAssets.get_texture(tex_key))
		else:
			smat.set_shader_parameter("use_tex", false)
		smat.set_shader_parameter("specular_roughness", rough)
		smat.set_shader_parameter("rim_color", Color(1.0, 0.96, 0.85))
		smat.set_shader_parameter("rim_strength", 0.45)
		smat.set_shader_parameter("cloak_amount", 0.0)
		mi.material_override = smat


func _on_weapon_fired_anim(w_kind: int, _muzzle: Vector3, _hit: Vector3) -> void:
	trigger_weapon_fire_visual(w_kind, false)


func trigger_weapon_fire_visual(w_kind: int, apply_camera_kick: bool = false) -> void:
	_weapon_recoil_anim = 1.0
	_fire_pose_timer = 0.45 if (w_kind == WeaponBase.WeaponKind.SMG or w_kind == WeaponBase.WeaponKind.MG) else 0.55
	if apply_camera_kick and hero_camera != null:
		var kick_rad: float = 0.022
		if not weapons.is_empty():
			var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
			var w: WeaponBase = weapons[slot] as WeaponBase
			if w != null:
				kick_rad = w.recoil_rad
		hero_camera.add_recoil(kick_rad)


func get_muzzle_world_position() -> Vector3:
	if is_scoping or _held_weapon_root == null or not is_inside_tree():
		var fwd: Vector3 = -(Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)).z).normalized()
		return global_position + Vector3(0.0, 1.48 if not is_crouching else 1.0, 0.0) + fwd * 0.65
	return _held_weapon_root.to_global(_weapon_muzzle_local)


func _input(event: InputEvent) -> void:
	if not is_local_player or is_bot:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if hero_camera != null:
			hero_camera.apply_look_delta((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_weapon_slot = posmod(selected_weapon_slot - 1, maxi(1, weapons.size()))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_weapon_slot = posmod(selected_weapon_slot + 1, maxi(1, weapons.size()))


func _process(delta: float) -> void:
	if is_local_player and not is_bot and hero_camera != null:
		var sniper_scoped: bool = false
		if not is_defeated and current_vehicle_id < 0 and not weapons.is_empty():
			var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
			var w: WeaponBase = weapons[slot] as WeaponBase
			if w != null and w.is_sniper and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				sniper_scoped = true
		hero_camera.set_scoped(sniper_scoped)

	if is_local_player or is_bot or NetworkManager.is_server_authority():
		_pred_error_offset = _pred_error_offset.lerp(Vector3.ZERO, minf(1.0, 14.0 * delta))
		visual_error_offset = _pred_error_offset
		if visual_root != null:
			if current_vehicle_id >= 0:
				visual_root.global_position = global_position
			else:
				var frac: float = Engine.get_physics_interpolation_fraction()
				var interp_world: Vector3 = _prev_phys_pos.lerp(_curr_phys_pos, frac)
				visual_root.global_position = interp_world + _pred_error_offset
			visual_root.rotation.y = aim_yaw
	else:
		var sample: SnapshotInterpolator.SnapshotSample = snapshot_interpolator.sample(NetworkManager.get_server_clock_ms())
		if sample != null:
			global_position = sample.position
			velocity = sample.velocity
			aim_yaw = sample.aim_yaw
			aim_pitch = sample.aim_pitch
			active_flags = sample.flags
			is_parachuting = (active_flags & NetSerializer.SNAP_PARACHUTING) != 0
			is_crouching = (active_flags & NetSerializer.SNAP_CROUCHING) != 0
			is_defeated = (active_flags & NetSerializer.SNAP_DEFEATED) != 0
			is_stealthed = (active_flags & NetSerializer.SNAP_STEALTHED) != 0
			is_emoting = (active_flags & NetSerializer.SNAP_EMOTING) != 0
			if visual_root != null:
				visual_root.global_position = global_position
				visual_root.rotation.y = aim_yaw

	_rebuild_held_weapon_mesh()
	_animate_character(delta)


func _animate_character(delta: float) -> void:
	if _hips_pivot == null:
		return
	if _parachute_rig != null:
		_parachute_rig.visible = is_parachuting and not is_defeated
	if _defeat_prop != null:
		_defeat_prop.visible = is_defeated

	_weapon_recoil_anim = maxf(0.0, _weapon_recoil_anim - 7.5 * delta)
	_fire_pose_timer = maxf(0.0, _fire_pose_timer - delta)

	if not is_defeated:
		_defeat_elapsed = 0.0
	else:
		_defeat_elapsed += delta
		var slump_t: float = clampf((_defeat_elapsed - 0.45) / 0.40, 0.0, 1.0)
		var kneel_t: float = clampf(_defeat_elapsed / 0.45, 0.0, 1.0)

		# Multi-stage collapse defeat: drop to knees (0..0.45s) then slump flat onto ground (0.45s+)
		_hips_pivot.position.y = lerpf(0.35, 0.12, slump_t)
		var base_rot_x: float = lerpf(lerpf(0.0, -0.45, kneel_t), -1.15, slump_t)
		_hips_pivot.rotation.x = base_rot_x if not defeat_explosive or _defeat_elapsed > 0.45 else _hips_pivot.rotation.x + 8.0 * delta
		_torso_pivot.rotation.x = lerpf(0.0, -0.22, slump_t)
		_head_pivot.rotation.x = lerpf(0.0, -0.42, slump_t)

		_leg_l_pivot.rotation.x = lerpf(1.2, 1.45, slump_t)
		_leg_r_pivot.rotation.x = lerpf(1.2, 1.45, slump_t)

		# Left arm braces on ground
		_arm_l_pivot.rotation = Vector3(lerpf(0.5, -0.35, slump_t), 0.0, lerpf(0.2, 0.65, slump_t))
		_forearm_l_pivot.rotation = Vector3(lerpf(0.3, 0.85, slump_t), 0.0, 0.0)

		# Right arm keeps waving white surrender flag clearly above ground
		var wave: float = sin(Time.get_ticks_msec() * 0.008) * 0.35
		_arm_r_pivot.rotation = Vector3(lerpf(0.5, 1.35, slump_t), wave, -0.25)
		_forearm_r_pivot.rotation = Vector3(0.4, 0.0, 0.0)

		if _defeat_prop != null:
			_defeat_prop.visible = true
			_defeat_prop.position = _hips_pivot.position + Vector3(0.35, 0.22, -0.12)
			_defeat_prop.rotation = Vector3(0.0, wave * 0.3, -0.25)
		return

	var slot: int = clampi(selected_weapon_slot, 0, maxi(0, weapons.size() - 1))
	var cur_w: WeaponBase = weapons[slot] as WeaponBase if slot < weapons.size() else null
	var reloading: bool = cur_w != null and cur_w.is_reloading
	var fire_blend: float = clampf(_fire_pose_timer * 3.2, 0.0, 1.0)
	var kick: float = _weapon_recoil_anim

	if current_vehicle_id >= 0:
		_hips_pivot.rotation.x = 0.0
		if current_seat_pose == "hidden":
			return
		var can_shoot_seat: bool = current_seat_can_shoot or current_seat_index > 0
		if _held_weapon_root != null:
			_held_weapon_root.visible = can_shoot_seat
		if current_seat_pose == "sit":
			_hips_pivot.position.y = 0.28
			# +X rotation swings downward -Y legs forward toward -Z into the cockpit/footwell
			_leg_l_pivot.rotation.x = 1.45
			_leg_r_pivot.rotation.x = 1.45
			_torso_pivot.rotation.x = -0.04
			_torso_pivot.rotation.y = 0.0
			_head_pivot.rotation.x = clampf(aim_pitch * 0.25, -0.35, 0.35)
		else:
			_hips_pivot.position.y = 0.76
			_leg_l_pivot.rotation.x = 0.0
			_leg_r_pivot.rotation.x = 0.0
			_torso_pivot.rotation.x = aim_pitch * 0.25 - kick * 0.05
			_torso_pivot.rotation.y = 0.0
			_head_pivot.rotation.x = aim_pitch * 0.35

		if can_shoot_seat:
			_pose_held_weapon_and_arms(0.0, fire_blend, kick, reloading)
		else:
			_pose_arm_ik(_arm_r_pivot, _forearm_r_pivot, Vector3(0.20, 0.34, -0.36), Vector3(0.75, -0.45, 0.55))
			_pose_arm_ik(_arm_l_pivot, _forearm_l_pivot, Vector3(-0.20, 0.34, -0.36), Vector3(-0.80, -0.45, 0.45))
		return

	# Remote client fall time tracking in animation loop (local player and server track deterministically in simulate_movement)
	if not is_local_player and not is_bot and not NetworkManager.is_server_authority():
		if not is_on_floor() and (active_flags & NetSerializer.SNAP_GROUNDED) == 0 and not is_in_water and not is_parachuting:
			if velocity.y < -0.5:
				_airborne_fall_time += delta
			else:
				_airborne_fall_time = 0.0
		elif is_on_floor() or (active_flags & NetSerializer.SNAP_GROUNDED) != 0 or is_in_water or is_parachuting:
			_airborne_fall_time = 0.0

	var is_falling_air: bool = (not is_on_floor() and (active_flags & NetSerializer.SNAP_GROUNDED) == 0 and not is_in_water and not is_parachuting and (velocity.y < -4.5 or _airborne_fall_time > 0.35))

	if is_falling_air:
		if _held_weapon_root != null:
			_held_weapon_root.visible = false
		var ready_for_chute: bool = (_airborne_fall_time >= 1.0 or velocity.y < -10.5)
		var flutter_freq: float = 24.0 if ready_for_chute else 12.0
		var flutter_amp: float = 0.08 if ready_for_chute else 0.03
		var flutter: float = sin(Time.get_ticks_msec() * 0.001 * flutter_freq) * flutter_amp

		# Arched belly-to-earth skydiving freefall pose
		_hips_pivot.position.y = lerpf(_hips_pivot.position.y, 0.68, 12.0 * delta)
		_hips_pivot.rotation.x = lerpf(_hips_pivot.rotation.x, -0.62, 10.0 * delta)
		_torso_pivot.rotation.x = lerpf(_torso_pivot.rotation.x, -0.25 + flutter, 10.0 * delta)
		_torso_pivot.rotation.y = lerpf(_torso_pivot.rotation.y, 0.0, 10.0 * delta)
		_head_pivot.rotation.x = lerpf(_head_pivot.rotation.x, 0.55, 10.0 * delta)

		# Wings: arms spread out wide to the sides
		_arm_l_pivot.rotation = _arm_l_pivot.rotation.lerp(Vector3(0.20, 0.0, 1.35 + flutter), 12.0 * delta)
		_arm_r_pivot.rotation = _arm_r_pivot.rotation.lerp(Vector3(0.20, 0.0, -1.35 - flutter), 12.0 * delta)
		_forearm_l_pivot.rotation = _forearm_l_pivot.rotation.lerp(Vector3(0.35, 0.0, 0.25), 12.0 * delta)
		_forearm_r_pivot.rotation = _forearm_r_pivot.rotation.lerp(Vector3(0.35, 0.0, -0.25), 12.0 * delta)

		# Legs bent backward
		_leg_l_pivot.rotation.x = lerpf(_leg_l_pivot.rotation.x, -0.55 + flutter * 0.5, 10.0 * delta)
		_leg_r_pivot.rotation.x = lerpf(_leg_r_pivot.rotation.x, -0.55 - flutter * 0.5, 10.0 * delta)
		return

	_hips_pivot.rotation.x = 0.0
	if _held_weapon_root != null:
		_held_weapon_root.visible = true

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.4 and (is_on_floor() or (active_flags & NetSerializer.SNAP_GROUNDED) != 0):
		_walk_phase += horiz_speed * delta * 2.1
	else:
		_walk_phase = lerpf(_walk_phase, 0.0, 8.0 * delta)

	var stride: float = sin(_walk_phase) * clampf(horiz_speed / 7.0, 0.0, 1.0)
	var bob: float = absf(sin(_walk_phase * 2.0)) * 0.012 * clampf(horiz_speed / 7.0, 0.0, 1.0)

	var target_hips_y: float = 0.50 if is_crouching else (0.76 + bob)
	_hips_pivot.position.y = lerpf(_hips_pivot.position.y, target_hips_y, 14.0 * delta)

	if is_parachuting:
		_leg_l_pivot.rotation.x = lerpf(_leg_l_pivot.rotation.x, 0.35, 10.0 * delta)
		_leg_r_pivot.rotation.x = lerpf(_leg_r_pivot.rotation.x, -0.25, 10.0 * delta)
		_arm_l_pivot.rotation = _arm_l_pivot.rotation.lerp(Vector3(2.65, 0.0, 0.25), 10.0 * delta)
		_arm_r_pivot.rotation = _arm_r_pivot.rotation.lerp(Vector3(2.65, 0.0, -0.25), 10.0 * delta)
		_forearm_l_pivot.rotation = _forearm_l_pivot.rotation.lerp(Vector3(0.25, 0.0, 0.0), 10.0 * delta)
		_forearm_r_pivot.rotation = _forearm_r_pivot.rotation.lerp(Vector3(0.25, 0.0, 0.0), 10.0 * delta)
		_torso_pivot.rotation.x = 0.12
		_torso_pivot.rotation.y = 0.0
	elif is_emoting:
		emote_timer += delta
		_leg_l_pivot.rotation.x = 0.0
		_leg_r_pivot.rotation.x = 0.0
		_arm_l_pivot.rotation = Vector3(2.2 + sin(emote_timer * 12.0) * 0.55, 0.0, 0.4)
		_arm_r_pivot.rotation = Vector3(0.5, 0.0, -0.2)
		_forearm_l_pivot.rotation = Vector3(0.4, 0.0, 0.0)
		_forearm_r_pivot.rotation = Vector3(0.8, 0.0, 0.0)
		_hips_pivot.position.y = 0.76 + absf(sin(emote_timer * 8.0)) * 0.16
	else:
		_leg_l_pivot.rotation.x = stride * 0.72 + (-0.55 if is_crouching else 0.0)
		_leg_r_pivot.rotation.x = -stride * 0.72 + (-0.55 if is_crouching else 0.0)
		var counter_twist: float = -stride * 0.08 * (1.0 - fire_blend)
		_torso_pivot.rotation.x = aim_pitch * 0.25 + (-0.14 if is_crouching else 0.0) - kick * 0.05
		_torso_pivot.rotation.y = lerpf(counter_twist, 0.18 if _shown_weapon_kind != WeaponBase.WeaponKind.KNIFE else kick * 0.45, 0.5 + fire_blend * 0.5)
		_head_pivot.rotation.x = aim_pitch * 0.35
		_pose_held_weapon_and_arms(stride, fire_blend, kick, reloading)


func _pose_held_weapon_and_arms(stride: float, fire_blend: float, kick: float, reloading: bool) -> void:
	var left_target: Vector3 = Vector3(-0.18, 0.34, -0.24)
	var right_pole: Vector3 = Vector3(0.75, -0.45, 0.55)
	var left_pole: Vector3 = Vector3(-0.80, -0.45, 0.45)

	if _held_weapon_root != null:
		match _shown_weapon_kind:
			WeaponBase.WeaponKind.BAZOOKA:
				_held_weapon_root.position = Vector3(0.24, 0.58, -0.02 + kick * 0.09)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.65 + kick * 0.15, 0.06, 0.0)
			WeaponBase.WeaponKind.MG:
				var reload_tilt: float = 0.45 if reloading else 0.0
				_held_weapon_root.position = Vector3(0.24, 0.23, -0.14 + kick * 0.05)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.45 + 0.04 + kick * 0.07 - reload_tilt * 0.4, lerpf(0.42, 0.14, fire_blend), reload_tilt)
			WeaponBase.WeaponKind.PISTOL:
				_held_weapon_root.position = Vector3(0.20, 0.44, -0.34 + kick * 0.05)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.75 + kick * 0.28, lerpf(0.16, 0.04, fire_blend), 0.42 if reloading else 0.0)
			WeaponBase.WeaponKind.KNIFE:
				var swing_phase: float = sin(clampf(1.0 - kick, 0.0, 1.0) * PI) if kick > 0.01 else 0.0
				_held_weapon_root.position = Vector3(0.25 - swing_phase * 0.42, 0.34 + swing_phase * 0.10, -0.22 - swing_phase * 0.24)
				_held_weapon_root.rotation = Vector3(-0.22 + aim_pitch * 0.45 - swing_phase * 0.55, 0.40 + swing_phase * 1.15, -0.35 - swing_phase * 0.65)
			WeaponBase.WeaponKind.TNT:
				var throw_phase: float = sin(clampf(1.0 - kick, 0.0, 1.0) * PI) if kick > 0.01 else 0.0
				_held_weapon_root.position = Vector3(0.25, 0.34 + throw_phase * 0.24, -0.20 - throw_phase * 0.26)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.5 - throw_phase * 0.9, 0.20, 0.0)
			_: # SMG, Shotgun, Sniper (BFH iconic across-chest 2-handed rifle carry, tightening on fire!)
				var r_tilt: float = 0.52 if reloading else 0.0
				var base_yaw: float = 0.66 if _shown_weapon_kind == WeaponBase.WeaponKind.SNIPER else 0.58
				var sway_x: float = -stride * 0.015 * (1.0 - fire_blend)
				var sway_yaw: float = -stride * 0.035 * (1.0 - fire_blend)
				_held_weapon_root.position = Vector3(0.21 + sway_x, 0.32 + stride * 0.012, -0.14 + kick * 0.06)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.55 + 0.16 + kick * 0.12 - r_tilt * 0.3, lerpf(base_yaw + sway_yaw, 0.20, fire_blend), -0.08 + r_tilt)

		var right_target: Vector3 = _held_weapon_root.transform * _weapon_grip_local
		_pose_arm_ik(_arm_r_pivot, _forearm_r_pivot, right_target, right_pole)

		if reloading:
			var dip: float = absf(sin(Time.get_ticks_msec() * 0.008))
			left_target = Vector3(-0.04, 0.16 + dip * 0.16, -0.26)
		elif _weapon_two_handed:
			left_target = _held_weapon_root.transform * _weapon_foregrip_local
		else:
			left_target = Vector3(-0.20, 0.36, -0.26)
		_pose_arm_ik(_arm_l_pivot, _forearm_l_pivot, left_target, left_pole)


func _aim_segment_basis(dir_u: Vector3, pole_hint: Vector3) -> Basis:
	var y_axis: Vector3 = -dir_u.normalized()
	var x_axis: Vector3 = y_axis.cross(pole_hint)
	if x_axis.length_squared() < 0.0001:
		x_axis = y_axis.cross(Vector3.RIGHT)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _pose_arm_ik(arm_pivot: Node3D, forearm_pivot: Node3D, target_torso: Vector3, pole_hint: Vector3) -> void:
	if arm_pivot == null or forearm_pivot == null:
		return
	var s_pos: Vector3 = arm_pivot.position
	var diff: Vector3 = target_torso - s_pos
	var max_reach: float = _upper_arm_len + _forearm_len - 0.006
	var dist: float = clampf(diff.length(), 0.06, max_reach)
	var dir_n: Vector3 = diff.normalized() if diff.length_squared() > 0.00001 else Vector3.DOWN

	var perp: Vector3 = pole_hint - dir_n * pole_hint.dot(dir_n)
	if perp.length_squared() < 0.0001:
		perp = Vector3.DOWN - dir_n * Vector3.DOWN.dot(dir_n)
	perp = perp.normalized()

	var l1: float = _upper_arm_len
	var l2: float = _forearm_len
	var cos_a: float = clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -0.998, 0.998)
	var sin_a: float = sqrt(maxf(0.0, 1.0 - cos_a * cos_a))
	var elbow_pos: Vector3 = s_pos + dir_n * (l1 * cos_a) + perp * (l1 * sin_a)
	var hand_clamped: Vector3 = s_pos + dir_n * dist

	var upper_dir: Vector3 = (elbow_pos - s_pos).normalized()
	var lower_dir: Vector3 = (hand_clamped - elbow_pos).normalized()
	var upper_b: Basis = _aim_segment_basis(upper_dir, pole_hint)
	var lower_b: Basis = _aim_segment_basis(lower_dir, pole_hint)
	arm_pivot.basis = upper_b
	forearm_pivot.basis = upper_b.inverse() * lower_b


func _physics_process(delta: float) -> void:
	_prev_phys_pos = _curr_phys_pos
	if is_defeated:
		defeat_timer -= delta
		_airborne_fall_time = 0.0
		_knockback_stun_timer = 0.0
		if is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.x = lerpf(velocity.x, 0.0, minf(1.0, 24.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, minf(1.0, 24.0 * delta))
		velocity.y -= GRAVITY * delta
		move_and_slide()
		_curr_phys_pos = global_position
		return

	if current_vehicle_id >= 0:
		_curr_phys_pos = global_position
		if is_local_player and not is_bot:
			var cmd: InputCmd = _sample_local_input()
			local_tick += 1
			cmd.tick = local_tick
			aim_yaw = cmd.aim_yaw
			aim_pitch = cmd.aim_pitch
			selected_weapon_slot = cmd.selected_weapon_slot
			NetworkManager.send_input_to_server(cmd)
		return

	if is_local_player and not is_bot:
		var cmd: InputCmd = _sample_local_input()
		local_tick += 1
		cmd.tick = local_tick
		var pre_jump_held: bool = prev_jump_held
		simulate_movement(cmd, delta)
		if not NetworkManager.is_active_host_authority():
			input_buffer.push(
				local_tick,
				cmd,
				global_position,
				velocity,
				is_parachuting,
				is_crouching,
				is_on_floor(),
				pre_jump_held
			)
			if not weapons.is_empty():
				var w_slot: int = clampi(cmd.selected_weapon_slot, 0, weapons.size() - 1)
				var cw: WeaponBase = weapons[w_slot] as WeaponBase
				if cw != null:
					var was_reloading: bool = cw.is_reloading
					cw.step_timers(delta, cmd)
					if not was_reloading and cw.is_reloading:
						SoundSynthesizer.play_sfx("reload")
					if cw.try_consume_fire(cmd):
						trigger_weapon_fire_visual(cw.weapon_kind, true)
						SoundSynthesizer.play_weapon_fire(cw.weapon_kind, 0.0)
						var aim_dir: Vector3 = -(Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)).z).normalized()
						StatusEffectsVFX.spawn_muzzle_flash(get_parent(), get_muzzle_world_position(), aim_dir, cw.weapon_kind)
		NetworkManager.send_input_to_server(cmd)
	elif NetworkManager.is_active_host_authority():
		simulate_movement(latest_server_input, delta)

	_curr_phys_pos = global_position


func _sample_local_input() -> InputCmd:
	var cmd := InputCmd.new()
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		move.y += 1.0
	if move.length() > 1.0:
		move = move.normalized()
	cmd.move_dir = move

	if hero_camera != null:
		cmd.aim_yaw = hero_camera.yaw
		cmd.aim_pitch = hero_camera.pitch

	# Weapon slots 1, 2, 3 (+ Q cycle) matching BFH hotbar
	if Input.is_key_pressed(KEY_1):
		selected_weapon_slot = 0
	elif Input.is_key_pressed(KEY_2) and weapons.size() > 1:
		selected_weapon_slot = 1
	elif Input.is_key_pressed(KEY_3) and weapons.size() > 2:
		selected_weapon_slot = 2
	elif Input.is_key_pressed(KEY_4) and weapons.size() > 3:
		selected_weapon_slot = 3
	var q_held: bool = Input.is_key_pressed(KEY_Q)
	if q_held and not _prev_q_held:
		selected_weapon_slot = (selected_weapon_slot + 1) % maxi(1, weapons.size())
	_prev_q_held = q_held

	cmd.set_button(InputCmd.BTN_JUMP, Input.is_key_pressed(KEY_SPACE))
	cmd.set_button(InputCmd.BTN_CROUCH, Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C))
	cmd.set_button(InputCmd.BTN_FIRE, Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	cmd.set_button(InputCmd.BTN_AIM, Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	cmd.set_button(InputCmd.BTN_RELOAD, Input.is_key_pressed(KEY_R))
	cmd.set_button(InputCmd.BTN_INTERACT, Input.is_key_pressed(KEY_E))
	cmd.set_button(InputCmd.BTN_SKILL_1, Input.is_key_pressed(KEY_5) or Input.is_key_pressed(KEY_F))
	cmd.set_button(InputCmd.BTN_SKILL_2, Input.is_key_pressed(KEY_6) or Input.is_key_pressed(KEY_G))
	cmd.set_button(InputCmd.BTN_SKILL_3, Input.is_key_pressed(KEY_7))
	cmd.set_button(InputCmd.BTN_SKILL_4, Input.is_key_pressed(KEY_8))
	cmd.set_button(InputCmd.BTN_SKILL_5, Input.is_key_pressed(KEY_9))
	cmd.set_button(InputCmd.BTN_WIDGET_1, Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_0))
	cmd.set_button(InputCmd.BTN_WIDGET_2, Input.is_key_pressed(KEY_X))
	cmd.set_button(InputCmd.BTN_WIDGET_3, Input.is_key_pressed(KEY_V))
	cmd.set_button(InputCmd.BTN_EMOTE, Input.is_key_pressed(KEY_T))

	cmd.selected_weapon_slot = selected_weapon_slot
	cmd.view_interp_tick_delta = NetworkManager.get_view_interp_tick_delta()
	return cmd


func can_open_parachute() -> bool:
	if is_defeated or current_vehicle_id >= 0 or is_on_floor() or is_in_water:
		return false
	return _airborne_fall_time >= PARACHUTE_MIN_FALL_TIME and _distance_to_ground() > 1.8


## Deterministic 60Hz character physics simulation shared by Client Prediction & Server Authority.
func simulate_movement(cmd: InputCmd, delta: float) -> void:
	if is_defeated:
		_airborne_fall_time = 0.0
		_knockback_stun_timer = 0.0
		if is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			velocity.x = lerpf(velocity.x, 0.0, minf(1.0, 24.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, minf(1.0, 24.0 * delta))
		velocity.y -= GRAVITY * delta
		move_and_slide()
		active_flags = NetSerializer.SNAP_DEFEATED
		if is_on_floor():
			active_flags |= NetSerializer.SNAP_GROUNDED
		return

	aim_yaw = cmd.aim_yaw
	aim_pitch = cmd.aim_pitch
	selected_weapon_slot = cmd.selected_weapon_slot

	_knockback_stun_timer = maxf(0.0, _knockback_stun_timer - delta)
	if _knockback_stun_timer > 0.0 or velocity.y > 0.5:
		floor_snap_length = 0.0
	else:
		floor_snap_length = 0.3

	var jump_held: bool = cmd.has_button(InputCmd.BTN_JUMP)
	var jump_just_pressed: bool = jump_held and not prev_jump_held
	prev_jump_held = jump_held

	is_crouching = cmd.has_button(InputCmd.BTN_CROUCH) and not is_parachuting
	_update_capsule_height(is_crouching)

	is_in_water = global_position.y < WATER_LEVEL - 0.55
	var grounded: bool = is_on_floor()

	# Airborne fall time tracking: resets on ground, water, vehicle; only increments when falling past apex
	if grounded or is_in_water or current_vehicle_id >= 0:
		_airborne_fall_time = 0.0
	elif velocity.y < -0.5:
		_airborne_fall_time += delta
	else:
		_airborne_fall_time = 0.0

	# Fall Damage Check when hitting ground after airborne drop without parachute
	if (grounded or is_in_water) and _was_airborne:
		if not is_parachuting and not is_in_water and _max_air_fall_speed > FALL_DAMAGE_THRESHOLD_SPEED:
			if NetworkManager.is_server_authority():
				var fall_dmg: int = maxi(5, int(roundf((_max_air_fall_speed - FALL_DAMAGE_THRESHOLD_SPEED) * 6.5)))
				apply_damage_server(fall_dmg, -1, false)
		_max_air_fall_speed = 0.0
		_was_airborne = false
		is_parachuting = false
	elif not grounded and not is_in_water:
		_was_airborne = true
		if is_parachuting:
			_max_air_fall_speed = 0.0
		elif velocity.y < 0.0:
			_max_air_fall_speed = maxf(_max_air_fall_speed, -velocity.y)

	# Jump & Infinite Reusable Parachute (requires >= 1.0s fall delay)
	if jump_just_pressed:
		if grounded:
			velocity.y = JUMP_VELOCITY
			is_parachuting = false
			_airborne_fall_time = 0.0
		elif is_in_water:
			velocity.y = JUMP_VELOCITY * 0.8
			is_parachuting = false
			_airborne_fall_time = 0.0
		else:
			if is_parachuting:
				is_parachuting = false
			elif can_open_parachute():
				is_parachuting = true
				_max_air_fall_speed = 0.0

	# Gravity / Buoyancy / Parachute fall clamp
	if is_in_water:
		var depth: float = WATER_LEVEL - 0.55 - global_position.y
		velocity.y += (depth * 18.0 - velocity.y * 4.5) * delta
	elif not grounded:
		velocity.y -= GRAVITY * delta
		if is_parachuting and velocity.y < PARACHUTE_MAX_FALL:
			velocity.y = lerpf(velocity.y, PARACHUTE_MAX_FALL, minf(1.0, 14.0 * delta))

	# Horizontal movement aligned to aim_yaw
	var basis_yaw := Basis(Vector3.UP, aim_yaw)
	var wish_dir: Vector3 = (basis_yaw * Vector3(cmd.move_dir.x, 0.0, cmd.move_dir.y))
	wish_dir.y = 0.0
	if wish_dir.length_squared() > 0.0001:
		wish_dir = wish_dir.normalized()

	var move_speed: float = base_move_speed * speed_multiplier
	if is_crouching:
		move_speed *= CROUCH_SPEED_MULT
	elif is_parachuting:
		move_speed *= PARACHUTE_GLIDE_SPEED_MULT
	elif is_in_water:
		move_speed *= 0.72

	var accel: float
	if _knockback_stun_timer > 0.0:
		accel = 2.4 if grounded else 2.8
	elif grounded:
		accel = 16.0
	elif is_parachuting:
		accel = 5.5
	else:
		accel = 8.0

	velocity.x = lerpf(velocity.x, wish_dir.x * move_speed, minf(1.0, accel * delta))
	velocity.z = lerpf(velocity.z, wish_dir.z * move_speed, minf(1.0, accel * delta))

	move_and_slide()

	# Emote state
	if cmd.has_button(InputCmd.BTN_EMOTE) and grounded and not is_emoting:
		is_emoting = true
		emote_timer = 0.0
		emote_triggered.emit(0)
	elif cmd.move_dir.length_squared() > 0.05 or not grounded:
		is_emoting = false

	# Update flags bitmask
	active_flags = 0
	if is_on_floor():
		active_flags |= NetSerializer.SNAP_GROUNDED
	if is_parachuting:
		active_flags |= NetSerializer.SNAP_PARACHUTING
	if is_crouching:
		active_flags |= NetSerializer.SNAP_CROUCHING
	if is_defeated:
		active_flags |= NetSerializer.SNAP_DEFEATED
	if is_stealthed:
		active_flags |= NetSerializer.SNAP_STEALTHED
	if shield > 0:
		active_flags |= NetSerializer.SNAP_SHIELDED
	if is_scoping:
		active_flags |= NetSerializer.SNAP_SCOPING
	if is_emoting:
		active_flags |= NetSerializer.SNAP_EMOTING


func _update_capsule_height(crouched: bool) -> void:
	if _capsule_shape == null or _body_collision == null:
		return
	var target_h: float = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	if absf(_capsule_shape.height - target_h) > 0.01:
		_capsule_shape.height = target_h
		_body_collision.position.y = target_h * 0.5


func _distance_to_ground() -> float:
	if not is_inside_tree():
		return 10.0
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0.0, 0.2, 0.0),
		global_position - Vector3(0.0, 25.0, 0.0),
		1
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return 25.0
	return global_position.distance_to(hit["position"])


func _snap_authoritative_pos(auth_pos: Vector3, auth_vel: Vector3) -> void:
	if is_inside_tree():
		global_position = auth_pos
	else:
		position = auth_pos
	velocity = auth_vel
	_curr_phys_pos = auth_pos
	_prev_phys_pos = auth_pos
	_pred_error_offset = Vector3.ZERO
	visual_error_offset = Vector3.ZERO
	if hero_camera != null:
		hero_camera.global_position = auth_pos


## Clears seat-specific metadata when no longer riding in a vehicle.
func _reset_seat_metadata() -> void:
	current_seat_enclosed = false
	current_seat_pose = ""
	current_seat_can_shoot = false

## Resets all hero-side vehicle occupancy, collision, camera, and visibility state.
func clear_vehicle_state() -> void:
	current_vehicle_id = -1
	current_seat_index = -1
	_reset_seat_metadata()
	_last_vehicle_id_for_cam = -1
	_pred_error_offset = Vector3.ZERO
	visual_error_offset = Vector3.ZERO
	if _body_collision != null:
		_body_collision.disabled = false
	if hero_camera != null:
		hero_camera.set_vehicle_mode(false)
		if visual_root != null:
			hero_camera.global_position = visual_root.global_position
	if visual_root != null and not is_scoping:
		visual_root.visible = true

func reconcile_with_server(state: Dictionary) -> void:
	var is_active_host: bool = NetworkManager.is_active_host_authority()
	if not is_local_player or is_bot or is_active_host:
		return
	var ack_tick: int = int(state.get("ack_tick", -1))
	var auth_pos: Vector3 = state.get("pos", global_position)
	var auth_vel: Vector3 = state.get("vel", velocity)
	var auth_flags: int = int(state.get("flags", 0))
	hp = int(state.get("hp", hp))
	shield = int(state.get("shield", shield))
	var prev_vid: int = current_vehicle_id
	current_vehicle_id = int(state.get("vehicle_id", -1))
	current_seat_index = int(state.get("seat_idx", -1))
	if current_vehicle_id < 0:
		_reset_seat_metadata()
	if current_vehicle_id != _last_vehicle_id_for_cam:
		_last_vehicle_id_for_cam = current_vehicle_id
		if _body_collision != null:
			_body_collision.disabled = (current_vehicle_id >= 0)
		if hero_camera != null:
			hero_camera.set_vehicle_mode(current_vehicle_id >= 0)
		if current_vehicle_id < 0 and visual_root != null and not is_scoping:
			visual_root.visible = true
	is_defeated = (auth_flags & NetSerializer.SNAP_DEFEATED) != 0
	stats_changed.emit()

	if current_vehicle_id >= 0 or prev_vid >= 0:
		_pred_error_offset = Vector3.ZERO
		visual_error_offset = Vector3.ZERO
		_snap_authoritative_pos(auth_pos, auth_vel)
		if ack_tick > _last_processed_srv_tick:
			_last_processed_srv_tick = ack_tick
		return

	if ack_tick <= _last_processed_srv_tick:
		return
	_last_processed_srv_tick = ack_tick

	var saved: InputRingBuffer.RingEntry = input_buffer.get_entry(ack_tick)
	if saved == null:
		return

	var err_dist: float = auth_pos.distance_to(saved.position)
	if err_dist <= RECONCILE_THRESHOLD_METERS:
		return

	var old_visual_pos: Vector3 = global_position + _pred_error_offset
	global_position = auth_pos
	velocity = auth_vel

	var horiz_vel: float = Vector2(auth_vel.x, auth_vel.z).length()
	var run_spd: float = base_move_speed * speed_multiplier
	if horiz_vel > run_spd * 1.15 or auth_vel.length() > 12.0:
		_knockback_stun_timer = maxf(_knockback_stun_timer, 0.35)

	is_parachuting = (auth_flags & NetSerializer.SNAP_PARACHUTING) != 0
	is_crouching = (auth_flags & NetSerializer.SNAP_CROUCHING) != 0
	prev_jump_held = saved.prev_jump_held

	var fixed_dt: float = 1.0 / float(NetworkManager.TICK_RATE)
	var replay_entries: Array[InputRingBuffer.RingEntry] = input_buffer.get_entries_range(ack_tick + 1, local_tick)
	for entry in replay_entries:
		simulate_movement(entry.cmd, fixed_dt)
		input_buffer.push(
			entry.tick,
			entry.cmd,
			global_position,
			velocity,
			is_parachuting,
			is_crouching,
			is_on_floor(),
			entry.prev_jump_held
		)

	if err_dist <= 4.0:
		var new_delta: Vector3 = old_visual_pos - global_position
		if new_delta.length() > 2.0:
			new_delta = new_delta.normalized() * 2.0
		_pred_error_offset = new_delta
	else:
		_pred_error_offset = Vector3.ZERO
		if hero_camera != null:
			hero_camera.global_position = global_position

	visual_error_offset = _pred_error_offset
	_prev_phys_pos = global_position
	_curr_phys_pos = global_position


func push_remote_snapshot(server_tick: int, server_time_ms: float, snap_dict: Dictionary) -> void:
	var pos: Vector3 = snap_dict.get("pos", Vector3.ZERO)
	var yaw: float = float(snap_dict.get("yaw", 0.0))
	var pitch: float = float(snap_dict.get("pitch", 0.0))
	var vel: Vector3 = snap_dict.get("vel", Vector3.ZERO)
	var flags: int = int(snap_dict.get("flags", 0))
	hp = int(snap_dict.get("hp", hp))
	shield = int(snap_dict.get("shield", shield))
	selected_weapon_slot = int(snap_dict.get("weapon_slot", selected_weapon_slot))
	current_vehicle_id = int(snap_dict.get("vehicle_id", -1))
	current_seat_index = int(snap_dict.get("seat_idx", -1))
	if current_vehicle_id < 0:
		_reset_seat_metadata()
	if _body_collision != null:
		_body_collision.disabled = (current_vehicle_id >= 0)
	var rot := Quaternion(Vector3.UP, yaw)
	snapshot_interpolator.push_snapshot(server_tick, server_time_ms, pos, rot, vel, yaw, pitch, 0.0, flags)


func build_snapshot_dict() -> Dictionary:
	return {
		"id": entity_id,
		"team": team,
		"class_id": class_id,
		"weapon_slot": selected_weapon_slot,
		"flags": active_flags,
		"pos": global_position,
		"vel": velocity,
		"yaw": aim_yaw,
		"pitch": aim_pitch,
		"hp": hp,
		"shield": shield,
		"vehicle_id": current_vehicle_id,
		"seat_idx": current_seat_index,
	}


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse
	if impulse.y > 0.2 or impulse.length() > 5.0:
		velocity.y = maxf(velocity.y, maxf(4.8, impulse.y))
	_knockback_stun_timer = maxf(_knockback_stun_timer, 0.38)
	knockback_seq = (knockback_seq + 1) & 0xFF


func apply_damage_server(amount: int, attacker_id: int, is_explosive: bool = false, bypass_enclosure: bool = false) -> int:
	if is_defeated or amount <= 0:
		return 0
	if current_vehicle_id >= 0 and current_seat_enclosed and not bypass_enclosure:
		return 0
	var remaining: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	var hp_dealt: int = mini(hp, remaining)
	hp -= hp_dealt
	if hp <= 0:
		hp = 0
		is_defeated = true
		defeat_timer = 5.0
		_defeat_elapsed = 0.0
		_airborne_fall_time = 0.0
		_knockback_stun_timer = 0.0
		last_killer_id = attacker_id
		defeat_explosive = is_explosive
		if is_explosive:
			velocity += Vector3(randf_range(-4.0, 4.0), 10.5, randf_range(-4.0, 4.0))
		elif is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
		defeated.emit(attacker_id, is_explosive)
	stats_changed.emit()
	return hp_dealt


func heal_server(amount: int) -> int:
	if is_defeated or amount <= 0:
		return 0
	var prev: int = hp
	hp = mini(max_hp, hp + amount)
	stats_changed.emit()
	return hp - prev


func respawn_at(spawn_pos: Vector3, spawn_yaw: float) -> void:
	global_position = spawn_pos
	velocity = Vector3.ZERO
	aim_yaw = spawn_yaw
	if hero_camera != null:
		hero_camera.yaw = spawn_yaw
	hp = max_hp
	shield = 0
	is_defeated = false
	_defeat_elapsed = 0.0
	_airborne_fall_time = 0.0
	_knockback_stun_timer = 0.0
	is_parachuting = false
	is_crouching = false
	_max_air_fall_speed = 0.0
	_was_airborne = false
	clear_vehicle_state()
	_prev_phys_pos = spawn_pos
	_curr_phys_pos = spawn_pos
	_pred_error_offset = Vector3.ZERO
	visual_error_offset = Vector3.ZERO
	if visual_root != null:
		visual_root.global_position = spawn_pos
	if hero_camera != null:
		hero_camera.global_position = spawn_pos
	respawned.emit()
	stats_changed.emit()


func _on_scope_toggled(scoped: bool) -> void:
	is_scoping = scoped
	if visual_root != null and is_local_player:
		visual_root.visible = not scoped
	if is_local_player and not is_bot:
		SoundSynthesizer.play_sfx("scope_in", 0.0, true, Vector3.ZERO, 1.0 if scoped else 0.78)
