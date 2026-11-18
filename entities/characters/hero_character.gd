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

const ClassEngineerScript := preload("res://entities/characters/classes/class_engineer.gd")

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
const FALL_DAMAGE_THRESHOLD_SPEED: float = 16.5
const MAX_STEP_HEIGHT: float = 0.50

var entity_id: int = 1
var hero_name: String = "Hero"
var team: int = 0 # 0 = Royal, 1 = National
var class_id: int = 0 # 0 = Soldier, 1 = Gunner, 2 = Commando
var archetype: int = 0
var weapon_slot_archetypes: Dictionary = {}
var is_local_player: bool = false
var is_bot: bool = false

## Core Combat Stats
var max_hp: int = 110
var hp: int = 110
var shield: int = 0
var base_move_speed: float = 6.3
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
var _last_weapon_slot: int = 1
var _alt_cursor_mode: bool = false
var _prev_alt_key_held: bool = false
var forced_weapon_seq: int = 0
var _last_forced_weapon_seq: int = 0
var _pending_forced_slot: int = -1
var _pending_forced_from_slot: int = -1
var _pending_forced_cmd_tick: int = -1
var _prev_seat_keys: int = 0
var current_vehicle_id: int = -1
var current_seat_index: int = -1
var current_seat_enclosed: bool = false
var current_seat_pose: String = ""
var current_seat_can_shoot: bool = false
var _last_vehicle_id_for_cam: int = -1
var knockback_seq: int = 0
var active_flags: int = 0
var active_buffs: int = 0
var last_killer_id: int = -1
var defeat_explosive: bool = false
var _max_air_fall_speed: float = 0.0
var _was_airborne: bool = false
var _airborne_start_y: float = 0.0
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
var _calf_l_pivot: Node3D
var _calf_r_pivot: Node3D
var _held_weapon_root: Node3D
var _held_weapon_root_l: Node3D
var _parachute_rig: Node3D
var _defeat_prop: Node3D
var _mesh_parts: Array[MeshInstance3D] = []
var _last_vfx_key: String = ""
var _overhead_buff_row: Node3D = null
var _overhead_buff_slots: Array[Sprite3D] = []
var _speed_trail_timer: float = 0.0
var _active_buff_vfx_timer: float = 0.0
var _sixth_sense_pulse_timer: float = 0.0
var _body_collision: CollisionShape3D
var _capsule_shape: CapsuleShape3D
var hero_camera: HeroCamera

var _walk_phase: float = 0.0
var _weapon_recoil_anim: float = 0.0
var _weapon_recoil_anim_l: float = 0.0
var _dual_shot_parity: int = 0
var _last_fired_hand: int = 0
var _weapon_grip_local_l: Vector3 = Vector3(0.0, -0.04, 0.0)
var _weapon_muzzle_local_l: Vector3 = Vector3(0.0, 0.035, -0.25)
var _fire_pose_timer: float = 0.0
var _cycle_anim_timer: float = 0.0
var _cycle_anim_duration: float = 0.0
var _weapon_cycle_progress: float = 0.0
var _weapon_reload_progress: float = 0.0
var _weapon_parts_by_name: Dictionary = {}
var _caber_head_spent: bool = false
var _tnt_rope_bundle: Node3D = null
var _tnt_spin_angle: float = 0.0
var _held_riot_shield: Node3D = null
var _held_riot_shield_base_pos: Vector3 = Vector3(-0.08, 0.26, -0.56)
var _skill_anim_timer: float = 0.0
var _skill_anim_duration: float = 0.55
var _skill_anim_style: String = ""
var last_skill_anim_name: String = ""
var _shown_weapon_kind: int = -1
var _shown_weapon_arch: int = -1
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
	_airborne_start_y = global_position.y

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


func setup_identity(p_entity_id: int, p_name: String, p_team: int, p_class_id: int, p_archetype: int, p_local: bool, p_bot: bool, p_slot_archetypes: Dictionary = {}) -> void:
	entity_id = p_entity_id
	hero_name = p_name
	team = p_team
	class_id = p_class_id
	archetype = p_archetype
	weapon_slot_archetypes = p_slot_archetypes.duplicate()
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
		NetworkManager.CLASS_DEMOLISHER:
			ClassDemolisher.configure_hero(self)
		NetworkManager.CLASS_ENGINEER:
			ClassEngineerScript.configure_hero(self)

	for w in weapons:
		if w is WeaponBase:
			(w as WeaponBase).fired.connect(_on_weapon_fired_anim)

	if _capsule_shape != null:
		_capsule_shape.radius = capsule_radius
	_shown_weapon_kind = -1
	_shown_weapon_arch = -1
	_rebuild_held_weapon_mesh()


func _apply_class_defaults() -> void:
	match class_id:
		NetworkManager.CLASS_SOLDIER:
			max_hp = 110
			base_move_speed = 6.3
			capsule_radius = 0.42
		NetworkManager.CLASS_GUNNER:
			max_hp = 150
			base_move_speed = 5.4
			capsule_radius = 0.54
		NetworkManager.CLASS_COMMANDO:
			max_hp = 80
			base_move_speed = 7.2
			capsule_radius = 0.36
		NetworkManager.CLASS_DEMOLISHER:
			max_hp = 110
			base_move_speed = 5.4
			capsule_radius = 0.46
		NetworkManager.CLASS_ENGINEER:
			max_hp = 125
			base_move_speed = 6.3
			capsule_radius = 0.43
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
	elif class_id == NetworkManager.CLASS_DEMOLISHER:
		style["hip_x"] = 0.165
		style["thigh_r"] = 0.106
		style["sh_x"] = 0.285
		style["arm_r_scale"] = 1.12
		style["arm_len_scale"] = 1.05
		style["beard_style"] = 1
		style["use_shades"] = true
		style["shade_col"] = Color(1.0, 0.66, 0.26)
		style["headgear"] = "visor_helmet"
		style["pauldron"] = true
	elif class_id == NetworkManager.CLASS_ENGINEER:
		style["hip_x"] = 0.148
		style["thigh_r"] = 0.094
		style["sh_x"] = 0.258
		style["arm_r_scale"] = 1.02
		style["beard_style"] = 0
		style["use_shades"] = false
		style["headgear"] = "engineer_cap"
		style["pauldron"] = false
	return style


func _create_leg_rig(
	side_sign: float,
	hip_x: float,
	thigh_mesh: Mesh,
	calf_mesh: Mesh,
	boot_mesh: Mesh,
	pants_mat: Material,
	boot_mat: Material
) -> Array[Node3D]:
	var leg_pivot := Node3D.new()
	leg_pivot.position = Vector3(side_sign * hip_x, 0.0, 0.0)
	_hips_pivot.add_child(leg_pivot)
	HeroMeshBuilder.add_part(leg_pivot, thigh_mesh, Vector3.ZERO, Vector3.ZERO, pants_mat, _mesh_parts)

	var calf_pivot := Node3D.new()
	calf_pivot.position = Vector3(0.0, -0.34, 0.0)
	leg_pivot.add_child(calf_pivot)
	HeroMeshBuilder.add_part(calf_pivot, calf_mesh, Vector3.ZERO, Vector3.ZERO, pants_mat, _mesh_parts)
	HeroMeshBuilder.add_part(calf_pivot, boot_mesh, Vector3(0.0, -0.22, 0.0), Vector3.ZERO, boot_mat, _mesh_parts)
	return [leg_pivot, calf_pivot]


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
		var cuff_mi := HeroMeshBuilder.add_part(forearm_pivot, cuff_mesh, Vector3(0.0, -_forearm_len * 0.88, 0.0), Vector3.ZERO, cuff_mat, _mesh_parts)
		cuff_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cuff_mi.visibility_range_end = 220.0
	var hand_rot := Vector3(0.0, PI if side_sign < 0.0 else 0.0, 0.0)
	HeroMeshBuilder.add_part(forearm_pivot, hand_mesh, Vector3(0.0, -_forearm_len, 0.0), hand_rot, hand_mat, _mesh_parts)
	return [arm_pivot, forearm_pivot]


func _mark_tiny_detail(mi: MeshInstance3D) -> MeshInstance3D:
	if mi != null:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 220.0
	return mi


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
	_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_collar_lapels_mesh(class_id), Vector3.ZERO, Vector3.ZERO, cloth_mat, _mesh_parts))
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_waist_belt_mesh(class_id), Vector3.ZERO, Vector3.ZERO, leather_mat, _mesh_parts)
	_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_buckle_mesh(), Vector3(0.0, 0.075, -(waist_rz + 0.022)), Vector3.ZERO, buckle_mat, _mesh_parts))
	_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_bandolier_mesh(class_id), Vector3.ZERO, Vector3.ZERO, leather_mat, _mesh_parts))

	var pack_mat: Material = leather_mat if class_id == NetworkManager.CLASS_COMMANDO else ruck_mat
	HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_backpack_mesh(class_id), Vector3.ZERO, Vector3.ZERO, pack_mat, _mesh_parts)
	if class_id == NetworkManager.CLASS_COMMANDO:
		_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_coat_tail_flap_mesh(), Vector3.ZERO, Vector3.ZERO, cloth_mat, _mesh_parts))

	var pouch_mesh := HeroMeshBuilder.build_belt_pouch_mesh()
	for side_sign in [-1.0, 1.0]:
		_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, pouch_mesh, Vector3(side_sign * (waist_rx + 0.025), 0.08, 0.02), Vector3(0.0, side_sign * -PI * 0.5, 0.0), ruck_mat, _mesh_parts))

	if not bool(style["rolled_vest_cap"]):
		var is_pauldron: bool = bool(style["pauldron"])
		var ep_mesh := HeroMeshBuilder.build_epaulet_mesh(is_pauldron)
		var ep_x: float = 0.255 if is_pauldron else 0.210
		var ep_y: float = 0.565 if is_pauldron else 0.578
		for side_sign in [-1.0, 1.0]:
			_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, ep_mesh, Vector3(side_sign * ep_x, ep_y, 0.0), Vector3(0.0, 0.0, side_sign * -0.20), cloth_mat, _mesh_parts))

	var scarf_col: Color = style["scarf_col"]
	if scarf_col.a > 0.01:
		var scarf_mat := HeroMeshBuilder.make_sculpted_mat(scarf_col, "", 0.78)
		_mark_tiny_detail(HeroMeshBuilder.add_part(_torso_pivot, HeroMeshBuilder.build_scarf_mesh(), Vector3.ZERO, Vector3.ZERO, scarf_mat, _mesh_parts))


func _attach_head_and_gear(style: Dictionary, mats: Dictionary) -> void:
	var skin_mat: Material = mats["skin"]
	var hair_mat: Material = mats["hair"]
	var badge_mat: Material = mats["badge"]

	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_head_mesh(), Vector3.ZERO, Vector3.ZERO, skin_mat, _mesh_parts)
	_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_hair_cap_mesh(), Vector3.ZERO, Vector3.ZERO, hair_mat, _mesh_parts))

	var ear_mesh := HeroMeshBuilder.build_ear_mesh()
	for side_sign in [-1.0, 1.0]:
		_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, ear_mesh, Vector3(side_sign * 0.128, 0.215, 0.01), Vector3(0.0, 0.0, side_sign * -0.18), skin_mat, _mesh_parts))

	var nose_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.92, 0.72, 0.58), "", 0.72)
	_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_nose_mesh(), Vector3(0.0, 0.205, -0.132), Vector3(-0.22, 0.0, 0.0), nose_mat, _mesh_parts))

	if bool(style["use_shades"]):
		var shade_mat := HeroMeshBuilder.make_sculpted_mat(style["shade_col"], "", 0.18)
		_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_sunglasses_mesh(), Vector3(0.0, 0.248, -0.142), Vector3.ZERO, shade_mat, _mesh_parts))
	else:
		var eyes_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.35)
		_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_eyes_mesh(), Vector3(0.0, 0.248, -0.138), Vector3.ZERO, eyes_mat, _mesh_parts))

	var beard_style: int = int(style["beard_style"])
	if beard_style >= 0:
		_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beard_mesh(beard_style), Vector3(0.0, 0.152, -0.128), Vector3.ZERO, hair_mat, _mesh_parts))

	match str(style["headgear"]):
		"helmet":
			var helmet_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.36)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_helmet_mesh(bool(style["is_royal"])), Vector3(0.0, 0.288, 0.0), Vector3(0.04, 0.0, 0.0), helmet_mat, _mesh_parts)
		"visor_helmet":
			var v_helmet_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.34)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_visor_helmet_mesh(bool(style["is_royal"])), Vector3(0.0, 0.286, 0.0), Vector3(0.02, 0.0, 0.0), v_helmet_mat, _mesh_parts)
		"officer_cap":
			var cap_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.42)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_officer_cap_mesh(), Vector3(0.0, 0.290, 0.0), Vector3(-0.04, 0.0, 0.0), cap_mat, _mesh_parts)
		"beret":
			var beret_mat := HeroMeshBuilder.make_sculpted_mat(style["beret_col"], "", 0.80)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beret_mesh(), Vector3(-0.012, 0.302, 0.0), Vector3(0.04, 0.0, 0.18), beret_mat, _mesh_parts)
			_mark_tiny_detail(HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_badge_mesh(), Vector3(0.046, 0.343, -0.118), Vector3(-0.10, 0.0, 0.12), badge_mat, _mesh_parts))
		"fedora":
			var fedora_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.76)
			var fedora_mesh := HeroMeshBuilder.build_fedora_mesh(style["fedora_band"], style["fedora_col"])
			HeroMeshBuilder.add_part(_head_pivot, fedora_mesh, Vector3(0.0, 0.302, -0.004), Vector3(-0.12, 0.0, -0.06), fedora_mat, _mesh_parts)
		"engineer_cap":
			var ecap_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "", 0.44)
			HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_engineer_cap_mesh(bool(style["is_royal"])), Vector3(0.0, 0.290, 0.0), Vector3(-0.04, 0.0, 0.0), ecap_mat, _mesh_parts)


func _rebuild_cartoon_visuals() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
	_mesh_parts.clear()
	_last_vfx_key = ""
	_overhead_buff_row = null
	_overhead_buff_slots.clear()
	_held_riot_shield = null

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

	# Articulated Sculpted Legs (Thigh + Knee/Calf) & Chunky Combat Boots
	var hip_x: float = float(style["hip_x"])
	var thigh_r: float = float(style["thigh_r"])
	var thigh_mesh: ArrayMesh = HeroMeshBuilder.build_thigh_mesh(thigh_r)
	var calf_mesh: ArrayMesh = HeroMeshBuilder.build_calf_mesh(thigh_r)
	var boot_mesh: ArrayMesh = HeroMeshBuilder.build_boot_mesh()
	var left_leg: Array[Node3D] = _create_leg_rig(-1.0, hip_x, thigh_mesh, calf_mesh, boot_mesh, mats["pants"], mats["boot"])
	_leg_l_pivot = left_leg[0]
	_calf_l_pivot = left_leg[1]
	var right_leg: Array[Node3D] = _create_leg_rig(1.0, hip_x, thigh_mesh, calf_mesh, boot_mesh, mats["pants"], mats["boot"])
	_leg_r_pivot = right_leg[0]
	_calf_r_pivot = right_leg[1]

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
	_held_weapon_root_l = Node3D.new()
	_held_weapon_root_l.name = "HeldWeaponRootL"
	_held_weapon_root_l.position = Vector3(-0.22, 0.42, -0.34)
	_held_weapon_root_l.visible = false
	_torso_pivot.add_child(_held_weapon_root_l)
	_shown_weapon_kind = -1
	_rebuild_held_weapon_mesh()

	if class_id == NetworkManager.CLASS_DEMOLISHER:
		_held_riot_shield = HeroMeshBuilder.build_carried_riot_shield(is_royal)
		_held_riot_shield.position = _held_riot_shield_base_pos
		_held_riot_shield.visible = false
		_torso_pivot.add_child(_held_riot_shield)

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


func is_carried_shield_active() -> bool:
	if is_defeated:
		return false
	if (active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) != 0:
		return true
	if status_effects != null and status_effects.get("carried_shield_active") == true:
		return true
	return false


func _is_tnt_rope_held() -> bool:
	if (active_buffs & NetSerializer.BUFF_TNT_ROPE) != 0:
		return true
	if status_effects != null and status_effects.has_method("is_tnt_rope_active"):
		return bool(status_effects.is_tnt_rope_active())
	return false


func _rebuild_held_weapon_mesh() -> void:
	if _held_weapon_root == null:
		return
	if _is_tnt_rope_held():
		if _shown_weapon_kind == -99 and _tnt_rope_bundle != null and is_instance_valid(_tnt_rope_bundle):
			return
		_shown_weapon_kind = -99
		_shown_weapon_arch = 0
		_cycle_anim_timer = 0.0
		_cycle_anim_duration = 0.0
		_weapon_cycle_progress = 0.0
		_weapon_reload_progress = 0.0
		_weapon_parts_by_name.clear()
		var t_info: Dictionary = HeroMeshBuilder.populate_tnt_rope_root(_held_weapon_root)
		_tnt_rope_bundle = t_info.get("bundle", null) as Node3D
		_weapon_grip_local = t_info.get("grip", Vector3(0.0, -0.02, 0.02))
		_weapon_foregrip_local = t_info.get("foregrip", Vector3.ZERO)
		_weapon_muzzle_local = t_info.get("muzzle", Vector3(0.0, 0.0, -0.18))
		_weapon_two_handed = false
		if _held_weapon_root_l != null:
			_held_weapon_root_l.visible = false
		return

	_tnt_rope_bundle = null
	if weapons.is_empty():
		return
	var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
	var w: WeaponBase = weapons[slot] as WeaponBase
	if w == null:
		return
	var w_arch: int = clampi(w.archetype, 0, 2)
	if w.weapon_kind == _shown_weapon_kind and w_arch == _shown_weapon_arch:
		return
	_shown_weapon_kind = w.weapon_kind
	_shown_weapon_arch = w_arch
	_cycle_anim_timer = 0.0
	_cycle_anim_duration = 0.0
	_weapon_cycle_progress = 0.0
	_weapon_reload_progress = 0.0
	_weapon_parts_by_name.clear()
	var w_info: Dictionary = HeroMeshBuilder.populate_weapon_root(_held_weapon_root, w.weapon_kind, w_arch)
	_weapon_grip_local = w_info.get("grip", Vector3(0.0, -0.04, 0.0))
	_weapon_foregrip_local = w_info.get("foregrip", Vector3(0.0, -0.015, -0.24))
	_weapon_muzzle_local = w_info.get("muzzle", Vector3(0.0, 0.035, -0.58))
	_weapon_two_handed = bool(w_info.get("two_handed", true))
	var is_dual: bool = (w.weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS or w.weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS)
	if _held_weapon_root_l != null:
		if is_dual:
			var wl_info: Dictionary = HeroMeshBuilder.populate_weapon_root(_held_weapon_root_l, w.weapon_kind, w_arch)
			_weapon_grip_local_l = wl_info.get("grip", Vector3(0.0, -0.04, 0.0))
			_weapon_muzzle_local_l = wl_info.get("muzzle", Vector3(0.0, 0.035, -0.25))
			_held_weapon_root_l.visible = true
		else:
			_held_weapon_root_l.visible = false
	var named_parts: Dictionary = w_info.get("parts_by_name", {})
	for part_name in named_parts.keys():
		var mi := named_parts[part_name] as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			_weapon_parts_by_name[str(part_name)] = {
				"node": mi,
				"base_pos": mi.position,
				"base_rot": mi.rotation,
			}
	_apply_caber_head_visibility()


func set_caber_spent_visual(spent: bool) -> void:
	_caber_head_spent = spent
	for w_node in weapons:
		if w_node is WeaponBase and (w_node as WeaponBase).weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE:
			(w_node as WeaponBase).caber_spent = spent
	_apply_caber_head_visibility()


func _is_caber_head_spent() -> bool:
	if _caber_head_spent:
		return true
	for w_node in weapons:
		if w_node is WeaponBase and (w_node as WeaponBase).weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE:
			if (w_node as WeaponBase).caber_spent:
				return true
	return false


func _apply_caber_head_visibility() -> void:
	if _shown_weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE and _weapon_parts_by_name.has("CaberHead"):
		var entry: Dictionary = _weapon_parts_by_name["CaberHead"]
		var node := entry.get("node", null) as MeshInstance3D
		if node != null and is_instance_valid(node):
			node.visible = not _is_caber_head_spent()


func apply_character_shader(shader: Shader) -> void:
	if shader == null:
		return
	_last_vfx_key = ""
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


func trigger_weapon_fire_visual(w_kind: int, apply_camera_kick: bool = false, hand_override: int = -1) -> void:
	if w_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS or w_kind == WeaponBase.WeaponKind.DUAL_PISTOLS:
		var hand: int = hand_override if hand_override >= 0 else (_dual_shot_parity & 1)
		if hand_override < 0:
			_dual_shot_parity = (_dual_shot_parity + 1) & 1
		_last_fired_hand = hand
		if hand == 1:
			_weapon_recoil_anim_l = 1.0
		else:
			_weapon_recoil_anim = 1.0
	else:
		_last_fired_hand = 0
		_weapon_recoil_anim = 1.0
	_fire_pose_timer = 0.45 if (w_kind == WeaponBase.WeaponKind.SMG or w_kind == WeaponBase.WeaponKind.MG) else 0.55
	var active_interval: float = 0.0
	match w_kind:
		WeaponBase.WeaponKind.SHOTGUN:
			active_interval = 0.65
		WeaponBase.WeaponKind.BAZOOKA:
			active_interval = 1.05
		WeaponBase.WeaponKind.SNIPER:
			active_interval = 0.90
		WeaponBase.WeaponKind.GRENADE_LAUNCHER:
			active_interval = 0.50
		WeaponBase.WeaponKind.STICK_GRENADE:
			active_interval = 0.48
	_cycle_anim_duration = active_interval
	_cycle_anim_timer = active_interval
	if apply_camera_kick and hero_camera != null:
		hero_camera.add_recoil(0.0)


func get_muzzle_world_position(hand_override: int = -1) -> Vector3:
	var is_dual: bool = (_shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS or _shown_weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS)
	var use_left: bool = is_dual and _held_weapon_root_l != null and ((hand_override == 1) or (hand_override < 0 and _last_fired_hand == 1))
	if use_left and not is_scoping and is_inside_tree():
		return _held_weapon_root_l.to_global(_weapon_muzzle_local_l)
	if is_scoping or _held_weapon_root == null or not is_inside_tree():
		var fwd: Vector3 = -(Basis.from_euler(Vector3(aim_pitch, aim_yaw, 0.0)).z).normalized()
		return global_position + Vector3(0.0, 1.48 if not is_crouching else 1.0, 0.0) + fwd * 0.65
	return _held_weapon_root.to_global(_weapon_muzzle_local)


func _is_ui_cursor_locked_open() -> bool:
	if not is_inside_tree():
		return false
	for m in get_tree().get_nodes_in_group("class_select_menus"):
		if m is CanvasLayer and (m as CanvasLayer).visible:
			return true
	for h in get_tree().get_nodes_in_group("hud_controllers"):
		if h != null and h.has_method("is_mortar_targeting_active") and h.is_mortar_targeting_active():
			return true
	return false


func is_cursor_free_mode() -> bool:
	if _alt_cursor_mode or Input.is_key_pressed(KEY_ALT):
		return true
	if _is_ui_cursor_locked_open():
		return true
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return true
	return false


func _sync_alt_cursor_mode() -> void:
	if not is_local_player or is_bot:
		return
	var alt_key_now: bool = Input.is_key_pressed(KEY_ALT)
	if alt_key_now != _prev_alt_key_held:
		_prev_alt_key_held = alt_key_now
		_alt_cursor_mode = alt_key_now
		if alt_key_now:
			if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			if not _is_ui_cursor_locked_open() and not DisplayServer.get_name().contains("headless"):
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif _alt_cursor_mode and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _cycle_weapon_slot_visual(step: int) -> void:
	if weapons.is_empty():
		return
	var order: Array[int] = InputCmd.get_active_weapon_order(weapons.size())
	if order.is_empty():
		return
	var cur_vis: int = order.find(selected_weapon_slot)
	if cur_vis < 0:
		cur_vis = 0
	var next_vis: int = posmod(cur_vis + step, order.size())
	switch_weapon_slot(order[next_vis])


func _input(event: InputEvent) -> void:
	if not is_local_player or is_bot:
		return
	if event is InputEventKey:
		var kev := event as InputEventKey
		if kev.keycode == KEY_ALT:
			_sync_alt_cursor_mode()
	if is_cursor_free_mode():
		return
	if event is InputEventMouseMotion:
		if hero_camera != null:
			hero_camera.apply_look_delta((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon_slot_visual(-1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon_slot_visual(1)


func _process(delta: float) -> void:
	if is_local_player and not is_bot:
		_sync_alt_cursor_mode()
	if is_local_player and not is_bot and hero_camera != null:
		var sniper_scoped: bool = false
		if not is_defeated and current_vehicle_id < 0 and not weapons.is_empty() and not is_cursor_free_mode():
			var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
			var w: WeaponBase = weapons[slot] as WeaponBase
			if w != null and w.is_sniper and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				sniper_scoped = true
		hero_camera.set_scoped(sniper_scoped)

	if is_local_player or is_bot or NetworkManager.is_server_authority():
		_pred_error_offset = _pred_error_offset.lerp(Vector3.ZERO, minf(1.0, 14.0 * delta))
		visual_error_offset = _pred_error_offset
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
			collision_layer = 0 if is_defeated else 2
			is_stealthed = (active_flags & NetSerializer.SNAP_STEALTHED) != 0
			is_emoting = (active_flags & NetSerializer.SNAP_EMOTING) != 0

	if current_vehicle_id >= 0:
		_sync_seated_visual_transform()
	elif visual_root != null:
		visual_root.rotation.x = 0.0
		visual_root.rotation.z = 0.0
		if is_local_player or is_bot or NetworkManager.is_server_authority():
			var frac: float = Engine.get_physics_interpolation_fraction()
			var interp_world: Vector3 = _prev_phys_pos.lerp(_curr_phys_pos, frac)
			visual_root.global_position = interp_world + _pred_error_offset
			visual_root.rotation.y = aim_yaw
		else:
			visual_root.global_position = global_position
			visual_root.rotation.y = aim_yaw

	_rebuild_held_weapon_mesh()
	_animate_character(delta)


func _animate_character(delta: float) -> void:
	if _hips_pivot == null:
		return
	_rebuild_held_weapon_mesh()
	if _is_tnt_rope_held():
		_tnt_spin_angle = wrapf(_tnt_spin_angle + delta * 5.5, 0.0, TAU)
	else:
		_tnt_spin_angle = 0.0
	if _parachute_rig != null:
		_parachute_rig.visible = is_parachuting and not is_defeated
	if _defeat_prop != null:
		_defeat_prop.visible = is_defeated

	_weapon_recoil_anim = maxf(0.0, _weapon_recoil_anim - 7.5 * delta)
	_weapon_recoil_anim_l = maxf(0.0, _weapon_recoil_anim_l - 7.5 * delta)
	_fire_pose_timer = maxf(0.0, _fire_pose_timer - delta)
	_cycle_anim_timer = maxf(0.0, _cycle_anim_timer - delta)
	_skill_anim_timer = maxf(0.0, _skill_anim_timer - delta)

	if not is_defeated:
		_defeat_elapsed = 0.0
	else:
		if _held_riot_shield != null and is_instance_valid(_held_riot_shield):
			_held_riot_shield.visible = false
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
		if _calf_l_pivot != null:
			_calf_l_pivot.rotation.x = 0.0
		if _calf_r_pivot != null:
			_calf_r_pivot.rotation.x = 0.0

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
	_weapon_reload_progress = clampf(1.0 - (cur_w.reload_timer / maxf(0.01, cur_w.reload_duration)), 0.0, 1.0) if (reloading and cur_w != null) else 0.0
	if _cycle_anim_timer > 0.0 and _cycle_anim_duration > 0.001:
		_weapon_cycle_progress = clampf(1.0 - (_cycle_anim_timer / _cycle_anim_duration), 0.0, 1.0)
	elif cur_w != null and cur_w.cooldown_timer > 0.0 and cur_w.fire_interval > 0.01 and _cycle_anim_duration <= 0.0:
		_weapon_cycle_progress = clampf(1.0 - (cur_w.cooldown_timer / cur_w.fire_interval), 0.0, 1.0)
	else:
		_weapon_cycle_progress = 0.0
	var fire_blend: float = clampf(_fire_pose_timer * 3.2, 0.0, 1.0)
	var kick: float = _weapon_recoil_anim

	if current_vehicle_id >= 0:
		_hips_pivot.rotation.x = 0.0
		if current_seat_pose == "hidden":
			return
		var veh: VehicleBase = _resolve_current_vehicle()
		var cur_seat: VehicleBase.SeatSlot = veh.get_seat(current_seat_index) if veh != null else null
		var can_shoot_seat: bool = cur_seat.can_shoot if cur_seat != null else (current_seat_can_shoot or current_seat_index > 0)
		if cur_seat != null and cur_seat.follow_turret:
			can_shoot_seat = false
		if _held_weapon_root != null:
			_held_weapon_root.visible = can_shoot_seat
		if _held_weapon_root_l != null:
			var is_dual_in_veh: bool = (_shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS or _shown_weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS)
			_held_weapon_root_l.visible = can_shoot_seat and is_dual_in_veh
		if _held_riot_shield != null and is_instance_valid(_held_riot_shield):
			_held_riot_shield.visible = false
		if current_seat_pose == "sit":
			_hips_pivot.position.y = 0.28
			# +X rotation swings downward -Y legs forward toward -Z into the cockpit/footwell
			_leg_l_pivot.rotation.x = 1.45
			_leg_r_pivot.rotation.x = 1.45
			if _calf_l_pivot != null:
				_calf_l_pivot.rotation.x = 0.0
			if _calf_r_pivot != null:
				_calf_r_pivot.rotation.x = 0.0
			_torso_pivot.rotation.x = -0.04
			_torso_pivot.rotation.y = 0.0
			_head_pivot.rotation.x = clampf(aim_pitch * 0.25, -0.35, 0.35)
		else:
			_hips_pivot.position.y = 0.76
			_leg_l_pivot.rotation.x = 0.0
			_leg_r_pivot.rotation.x = 0.0
			if _calf_l_pivot != null:
				_calf_l_pivot.rotation.x = 0.0
			if _calf_r_pivot != null:
				_calf_r_pivot.rotation.x = 0.0
			_torso_pivot.rotation.x = aim_pitch * 0.25 - kick * 0.05
			_torso_pivot.rotation.y = 0.0
			_head_pivot.rotation.x = aim_pitch * 0.35

		if can_shoot_seat:
			_head_pivot.rotation.y = 0.0
			_pose_held_weapon_and_arms(0.0, fire_blend, kick, reloading)
		else:
			if veh != null:
				var veh_fwd: Vector3 = -veh.global_transform.basis.z
				var veh_yaw: float = atan2(-veh_fwd.x, -veh_fwd.z)
				var glance: float = clampf(angle_difference(veh_yaw, aim_yaw), -0.5, 0.5)
				_head_pivot.rotation.y = glance
			else:
				_head_pivot.rotation.y = 0.0
			_pose_arm_ik(_arm_r_pivot, _forearm_r_pivot, Vector3(0.20, 0.34, -0.36), Vector3(0.75, -0.45, 0.55))
			_pose_arm_ik(_arm_l_pivot, _forearm_l_pivot, Vector3(-0.20, 0.34, -0.36), Vector3(-0.80, -0.45, 0.45))
		return

	_head_pivot.rotation.y = 0.0

	# Remote client fall time tracking in animation loop (local player and server track deterministically in simulate_movement)
	if not is_local_player and not is_bot and not NetworkManager.is_server_authority():
		if not is_on_floor() and (active_flags & NetSerializer.SNAP_GROUNDED) == 0 and not is_in_water and not is_parachuting:
			if velocity.y < -0.5:
				_airborne_fall_time += delta
			else:
				_airborne_fall_time = 0.0
		elif is_on_floor() or (active_flags & NetSerializer.SNAP_GROUNDED) != 0 or is_in_water or is_parachuting:
			_airborne_fall_time = 0.0

	var is_falling_air: bool = (not is_on_floor() and (active_flags & NetSerializer.SNAP_GROUNDED) == 0 and not is_in_water and not is_parachuting and _airborne_fall_time >= 1.0)

	if is_falling_air:
		if _held_weapon_root != null:
			_held_weapon_root.visible = false
		if _held_weapon_root_l != null:
			_held_weapon_root_l.visible = false
		if _held_riot_shield != null and is_instance_valid(_held_riot_shield):
			_held_riot_shield.visible = false
		var flutter_freq: float = 24.0
		var flutter_amp: float = 0.08
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
		if _calf_l_pivot != null:
			_calf_l_pivot.rotation.x = lerpf(_calf_l_pivot.rotation.x, -0.70, 10.0 * delta)
		if _calf_r_pivot != null:
			_calf_r_pivot.rotation.x = lerpf(_calf_r_pivot.rotation.x, -0.70, 10.0 * delta)
		return

	_hips_pivot.rotation.x = 0.0
	if _held_weapon_root != null:
		_held_weapon_root.visible = true
	if _held_weapon_root_l != null:
		_held_weapon_root_l.visible = (_shown_weapon_kind == WeaponBase.WeaponKind.DUAL_REVOLVERS or _shown_weapon_kind == WeaponBase.WeaponKind.DUAL_PISTOLS)

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.4 and (is_on_floor() or (active_flags & NetSerializer.SNAP_GROUNDED) != 0):
		_walk_phase += horiz_speed * delta * 2.1
	else:
		_walk_phase = lerpf(_walk_phase, 0.0, 8.0 * delta)

	var stride: float = sin(_walk_phase) * clampf(horiz_speed / 7.0, 0.0, 1.0)
	var bob: float = absf(sin(_walk_phase * 2.0)) * 0.012 * clampf(horiz_speed / 7.0, 0.0, 1.0)

	var target_hips_y: float = 0.52 if is_crouching else (0.76 + bob)
	_hips_pivot.position.y = lerpf(_hips_pivot.position.y, target_hips_y, 14.0 * delta)

	if is_parachuting:
		_leg_l_pivot.rotation.x = lerpf(_leg_l_pivot.rotation.x, 0.35, 10.0 * delta)
		_leg_r_pivot.rotation.x = lerpf(_leg_r_pivot.rotation.x, -0.25, 10.0 * delta)
		if _calf_l_pivot != null:
			_calf_l_pivot.rotation.x = 0.0
		if _calf_r_pivot != null:
			_calf_r_pivot.rotation.x = 0.0
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
		if _calf_l_pivot != null:
			_calf_l_pivot.rotation.x = 0.0
		if _calf_r_pivot != null:
			_calf_r_pivot.rotation.x = 0.0
		_arm_l_pivot.rotation = Vector3(2.2 + sin(emote_timer * 12.0) * 0.55, 0.0, 0.4)
		_arm_r_pivot.rotation = Vector3(0.5, 0.0, -0.2)
		_forearm_l_pivot.rotation = Vector3(0.4, 0.0, 0.0)
		_forearm_r_pivot.rotation = Vector3(0.8, 0.0, 0.0)
		_hips_pivot.position.y = 0.76 + absf(sin(emote_timer * 8.0)) * 0.16
	else:
		var is_grounded_anim: bool = is_on_floor() or (active_flags & NetSerializer.SNAP_GROUNDED) != 0
		if is_crouching:
			_leg_l_pivot.rotation.x = 1.10 + stride * 0.42
			_leg_r_pivot.rotation.x = 1.10 - stride * 0.42
			if _calf_l_pivot != null:
				_calf_l_pivot.rotation.x = -1.45 + stride * 0.18
			if _calf_r_pivot != null:
				_calf_r_pivot.rotation.x = -1.45 - stride * 0.18
		elif not is_grounded_anim and not is_in_water and _airborne_fall_time < 1.0:
			_leg_l_pivot.rotation.x = 0.28
			_leg_r_pivot.rotation.x = -0.18
			if _calf_l_pivot != null:
				_calf_l_pivot.rotation.x = -0.55
			if _calf_r_pivot != null:
				_calf_r_pivot.rotation.x = -0.25
		else:
			_leg_l_pivot.rotation.x = stride * 0.72
			_leg_r_pivot.rotation.x = -stride * 0.72
			if _calf_l_pivot != null:
				_calf_l_pivot.rotation.x = -maxf(0.0, -stride) * 0.45
			if _calf_r_pivot != null:
				_calf_r_pivot.rotation.x = -maxf(0.0, stride) * 0.45
		_leg_l_pivot.rotation.z = 0.0
		_leg_r_pivot.rotation.z = 0.0
		var counter_twist: float = -stride * 0.08 * (1.0 - fire_blend)
		_torso_pivot.rotation.x = aim_pitch * 0.25 + (0.14 if is_crouching else 0.0) - kick * 0.05
		_torso_pivot.rotation.y = lerpf(counter_twist, 0.18 if _shown_weapon_kind != WeaponBase.WeaponKind.KNIFE else kick * 0.45, 0.5 + fire_blend * 0.5)
		_head_pivot.rotation.x = aim_pitch * 0.35
		_pose_held_weapon_and_arms(stride, fire_blend, kick, reloading)
		if _skill_anim_timer > 0.0:
			var s_t: float = 1.0 - clampf(_skill_anim_timer / maxf(0.05, _skill_anim_duration), 0.0, 1.0)
			_pose_skill_animation(s_t)


func trigger_skill_visual(p_class_id: int, slot_idx: int) -> void:
	var style: String = "charge_pump"
	var dur: float = 0.55
	if slot_idx >= 100:
		match slot_idx - 100:
			0: style = "raise_med"; dur = 0.70
			1: style = "throw_overhead"; dur = 0.50
			2: style = "flex_shield"; dur = 0.50
			3: style = "raise_med"; dur = 0.50
	else:
		match p_class_id:
			NetworkManager.CLASS_SOLDIER:
				match slot_idx:
					0: style = "raise_med"; dur = 0.65
					1: style = "weapon_charge"; dur = 0.50
					2: style = "throw_overhead"; dur = 0.55
					3: style = "clap_strike"; dur = 0.60
					4: style = "radar_temple"; dur = 0.65
			NetworkManager.CLASS_GUNNER:
				match slot_idx:
					0: style = "flex_shield"; dur = 0.60
					1: style = "sprint_boost"; dur = 0.55
					2: style = "keg_throw"; dur = 0.68
					3: style = "weapon_charge"; dur = 0.50
					4: style = "chomp_absorb"; dur = 0.60
			NetworkManager.CLASS_COMMANDO:
				match slot_idx:
					0: style = "cloak_sweep"; dur = 0.55
					1: style = "weapon_charge"; dur = 0.50
					2: style = "blade_coat"; dur = 0.58
					3: style = "plant_kneel"; dur = 0.65
					4: style = "sprint_boost"; dur = 0.55
					5: style = "mark_point"; dur = 0.70
			NetworkManager.CLASS_DEMOLISHER:
				match slot_idx:
					0: style = "flex_shield"; dur = 0.48
					1: style = "sprint_boost"; dur = 0.55
					2: style = "throw_overhead"; dur = 0.55
					3: style = "plant_kneel"; dur = 0.55
					4: style = "weapon_charge"; dur = 0.50
			NetworkManager.CLASS_ENGINEER:
				match slot_idx:
					0: style = "plant_kneel"; dur = 0.60
					1: style = "plant_kneel"; dur = 0.60
					2: style = "weapon_charge"; dur = 0.55
					3: style = "mark_point"; dur = 0.65
					4: style = "flex_shield"; dur = 0.55
	_skill_anim_style = style
	last_skill_anim_name = style
	_skill_anim_duration = dur
	_skill_anim_timer = dur


func _pose_skill_animation(t: float) -> void:
	var pulse: float = sin(t * PI)
	match _skill_anim_style:
		"clap_strike": # Blasting Strike: dramatic two-palm shockwave clap forward
			_torso_pivot.rotation.x = -0.18 * pulse
			_arm_l_pivot.rotation = Vector3(1.55 * pulse, -0.45 * pulse, lerpf(1.2, 0.08, t))
			_arm_r_pivot.rotation = Vector3(1.55 * pulse, 0.45 * pulse, lerpf(-1.2, -0.08, t))
			_forearm_l_pivot.rotation = Vector3(0.25, 0.0, 0.0)
			_forearm_r_pivot.rotation = Vector3(0.25, 0.0, 0.0)
		"keg_throw": # Explosive Keg: two-hand overhead barrel heave forward
			var arc: float = lerpf(2.85, 0.95, t)
			_torso_pivot.rotation.x = lerpf(0.22, -0.26, t) * pulse
			_arm_l_pivot.rotation = Vector3(arc, 0.0, 0.22)
			_arm_r_pivot.rotation = Vector3(arc, 0.0, -0.22)
			_forearm_l_pivot.rotation = Vector3(0.35, 0.0, 0.0)
			_forearm_r_pivot.rotation = Vector3(0.35, 0.0, 0.0)
		"throw_overhead": # Grenade Spam / Wrench swing
			var swing: float = lerpf(2.6, 0.55, t)
			_torso_pivot.rotation.y = -0.35 * cos(t * PI)
			_arm_l_pivot.rotation = Vector3(swing, 0.0, 0.25)
			_forearm_l_pivot.rotation = Vector3(0.4, 0.0, 0.0)
		"raise_med": # Combat Medicine / Bandages raise
			_arm_l_pivot.rotation = Vector3(2.45 * pulse, 0.0, 0.35 * pulse)
			_forearm_l_pivot.rotation = Vector3(0.45 * pulse, 0.0, 0.0)
			_torso_pivot.rotation.x = 0.08 * pulse
		"radar_temple": # Sixth Sense hand-to-temple scanner salute
			_arm_l_pivot.rotation = Vector3(1.85 * pulse, 0.0, 0.55 * pulse)
			_forearm_l_pivot.rotation = Vector3(1.75 * pulse, 0.0, -0.45 * pulse)
			_head_pivot.rotation.y = sin(t * TAU) * 0.28
		"mark_point": # Mark Target laser spotter point forward
			_arm_l_pivot.rotation = Vector3(1.55 * pulse, 0.0, 0.12)
			_forearm_l_pivot.rotation = Vector3(0.15, 0.0, 0.0)
			_torso_pivot.rotation.y = 0.20 * pulse
		"plant_kneel": # Troop Trap crouch & ground plant
			_hips_pivot.position.y = lerpf(_hips_pivot.position.y, 0.44, pulse)
			_leg_l_pivot.rotation.x = -0.75 * pulse
			_leg_r_pivot.rotation.x = -0.75 * pulse
			_torso_pivot.rotation.x = -0.38 * pulse
			_arm_l_pivot.rotation = Vector3(1.1 * pulse, 0.0, 0.15)
		"cloak_sweep": # Stealth arm sweep across cloak
			_arm_l_pivot.rotation = Vector3(1.25 * pulse, -0.75 * pulse, 0.3)
			_forearm_l_pivot.rotation = Vector3(1.1 * pulse, 0.0, 0.0)
		"blade_coat": # Poisoned Blade vial coat across weapon
			_arm_l_pivot.rotation = Vector3(1.15 * pulse, -0.45 * pulse, 0.1)
			_forearm_l_pivot.rotation = Vector3(0.85 * pulse, 0.0, 0.0)
			_arm_r_pivot.rotation = Vector3(1.05 * pulse, 0.35 * pulse, -0.1)
		"flex_shield": # Hero Shield / Eat Grenades chest slam
			_torso_pivot.rotation.x = 0.18 * pulse
			_arm_l_pivot.rotation = Vector3(1.35 * pulse, -0.35 * pulse, 0.45 * pulse)
			_arm_r_pivot.rotation = Vector3(1.35 * pulse, 0.35 * pulse, -0.45 * pulse)
		"weapon_charge": # Burning Bullets / Piercing Shot / Frenzy Fire weapon chamber slam
			_arm_l_pivot.rotation.x += 0.55 * pulse
			_torso_pivot.rotation.x = -0.10 * pulse
		"sprint_boost": # Leg It / Elixir: dynamic forward sprint lean & pumping elbows
			var pump: float = sin(t * TAU * 1.5)
			_torso_pivot.rotation.x = -0.28 * pulse
			_arm_l_pivot.rotation = Vector3(1.15 * pulse + pump * 0.55, 0.0, 0.18)
			_arm_r_pivot.rotation = Vector3(1.15 * pulse - pump * 0.55, 0.0, -0.18)
			_forearm_l_pivot.rotation = Vector3(1.35 * pulse, 0.0, 0.0)
			_forearm_r_pivot.rotation = Vector3(1.35 * pulse, 0.0, 0.0)
		"chomp_absorb": # I Eat Grenades: bracing wide stance, arms scooping inward to chest
			_hips_pivot.position.y = lerpf(_hips_pivot.position.y, 0.62, pulse)
			_leg_l_pivot.rotation.z = -0.22 * pulse
			_leg_r_pivot.rotation.z = 0.22 * pulse
			_torso_pivot.rotation.x = 0.16 * pulse
			var scoop: float = lerpf(0.95, 0.12, t)
			_arm_l_pivot.rotation = Vector3(1.25 * pulse, -0.65 * pulse, scoop)
			_arm_r_pivot.rotation = Vector3(1.25 * pulse, 0.65 * pulse, -scoop)
			_forearm_l_pivot.rotation = Vector3(1.1 * pulse, 0.0, 0.0)
			_forearm_r_pivot.rotation = Vector3(1.1 * pulse, 0.0, 0.0)
		_: # "charge_pump": fallback raised fist pump
			_arm_l_pivot.rotation = Vector3(2.55 * pulse, 0.0, 0.3 * pulse)
			_forearm_l_pivot.rotation = Vector3(0.25, 0.0, 0.0)


func _pose_held_weapon_and_arms(stride: float, fire_blend: float, kick: float, reloading: bool) -> void:
	var left_target: Vector3 = Vector3(-0.18, 0.34, -0.24)
	var right_pole: Vector3 = Vector3(0.75, -0.45, 0.55)
	var left_pole: Vector3 = Vector3(-0.80, -0.45, 0.45)

	for part_name in _weapon_parts_by_name.keys():
		var entry: Dictionary = _weapon_parts_by_name[part_name]
		var p_node := entry.get("node", null) as MeshInstance3D
		if p_node != null and is_instance_valid(p_node):
			p_node.position = entry.get("base_pos", Vector3.ZERO)
			p_node.rotation = entry.get("base_rot", Vector3.ZERO)
			p_node.visible = true
	_apply_caber_head_visibility()

	var cycle_p: float = _weapon_cycle_progress
	var reload_p: float = _weapon_reload_progress
	var shield_up: bool = is_carried_shield_active()

	if _held_weapon_root != null:
		var custom_right_target: bool = false
		var custom_left_target: bool = false
		var right_target: Vector3 = Vector3.ZERO

		match _shown_weapon_kind:
			WeaponBase.WeaponKind.BAZOOKA:
				var is_feeding: bool = (cycle_p > 0.0) or reloading
				var feed_p: float = reload_p if reloading else cycle_p
				var feed_env: float = sin(clampf(feed_p, 0.0, 1.0) * PI) if is_feeding else 0.0
				var tilt_amt: float = maxf(feed_env, 0.35 if reloading else 0.0)
				_held_weapon_root.position = Vector3(0.24, 0.58 - tilt_amt * 0.14, -0.02 + kick * 0.09 - tilt_amt * 0.04)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.65 + kick * 0.15 - tilt_amt * 0.38, 0.06 + tilt_amt * 0.18, tilt_amt * 0.26)
				if is_feeding:
					var warhead_mi: MeshInstance3D = null
					if _weapon_parts_by_name.has("Warhead"):
						var w_entry: Dictionary = _weapon_parts_by_name["Warhead"]
						warhead_mi = w_entry.get("node", null) as MeshInstance3D
						if warhead_mi != null and is_instance_valid(warhead_mi):
							var w_base: Vector3 = w_entry.get("base_pos", Vector3.ZERO)
							if feed_p < 0.20:
								warhead_mi.visible = false
								warhead_mi.position = w_base + Vector3(-0.14, -0.06, 1.20)
							elif feed_p <= 0.85:
								var slide_t: float = clampf((feed_p - 0.20) / 0.65, 0.0, 1.0)
								warhead_mi.visible = true
								warhead_mi.position = w_base + Vector3(-0.14 * (1.0 - slide_t), -0.06 * (1.0 - slide_t), 1.20 * (1.0 - slide_t))
							else:
								warhead_mi.visible = true
								warhead_mi.position = w_base
					if _weapon_parts_by_name.has("Bolt"):
						var b_entry: Dictionary = _weapon_parts_by_name["Bolt"]
						var b_mi := b_entry.get("node", null) as MeshInstance3D
						if b_mi != null and is_instance_valid(b_mi):
							var b_base: Vector3 = b_entry.get("base_pos", Vector3.ZERO)
							b_mi.position = b_base + Vector3(0.06 * feed_env, 0.0, 0.06 * feed_env)
					if feed_p >= 0.12 and feed_p <= 0.90:
						var feed_blend: float = sin(clampf((feed_p - 0.12) / 0.78, 0.0, 1.0) * PI)
						var rocket_feed_local: Vector3 = (warhead_mi.position + Vector3(0.0, 0.0, 0.14)) if (warhead_mi != null and is_instance_valid(warhead_mi)) else Vector3(-0.08, -0.04, 0.42)
						left_target = (_held_weapon_root.transform * _weapon_foregrip_local).lerp(_held_weapon_root.transform * rocket_feed_local, feed_blend)
						right_target = (_held_weapon_root.transform * _weapon_grip_local).lerp(_held_weapon_root.transform * (_weapon_grip_local + Vector3(0.04, 0.06, 0.28)), feed_blend * 0.7)
						custom_left_target = true
						custom_right_target = true
			WeaponBase.WeaponKind.MG:
				var reload_tilt: float = 0.45 if reloading else 0.0
				_held_weapon_root.position = Vector3(0.24, 0.23, -0.14 + kick * 0.05)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.45 + 0.04 + kick * 0.07 - reload_tilt * 0.4, lerpf(0.42, 0.14, fire_blend), reload_tilt)
			WeaponBase.WeaponKind.PISTOL:
				_held_weapon_root.position = Vector3(0.20, 0.44, -0.34 + kick * 0.05)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.75 + kick * 0.28, lerpf(0.16, 0.04, fire_blend), 0.42 if reloading else 0.0)
			WeaponBase.WeaponKind.DUAL_REVOLVERS, WeaponBase.WeaponKind.DUAL_PISTOLS:
				var kick_l: float = _weapon_recoil_anim_l
				var dual_roll: float = 0.40 if reloading else 0.0
				_held_weapon_root.position = Vector3(0.22, 0.42, -0.34 + kick * 0.06)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.78 + kick * 0.30, lerpf(0.10, 0.02, fire_blend), dual_roll)
				if _held_weapon_root_l != null:
					_held_weapon_root_l.visible = true
					_held_weapon_root_l.position = Vector3(-0.22, 0.42, -0.34 + kick_l * 0.06)
					_held_weapon_root_l.rotation = Vector3(aim_pitch * 0.78 + kick_l * 0.30, lerpf(-0.10, -0.02, fire_blend), -dual_roll)
					left_target = _held_weapon_root_l.transform * _weapon_grip_local_l
					custom_left_target = true
			WeaponBase.WeaponKind.WELDING_TORCH:
				_held_weapon_root.position = Vector3(0.22, 0.38, -0.26 + kick * 0.02)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.72 + 0.06, lerpf(0.18, 0.05, fire_blend), 0.0)
			WeaponBase.WeaponKind.KNIFE, WeaponBase.WeaponKind.STICK_GRENADE:
				var swing_phase: float = sin(clampf(1.0 - kick, 0.0, 1.0) * PI) if kick > 0.01 else 0.0
				if _shown_weapon_kind == WeaponBase.WeaponKind.STICK_GRENADE and _cycle_anim_timer > 0.0 and _cycle_anim_duration > 0.001:
					swing_phase = maxf(swing_phase, sin(clampf(cycle_p, 0.0, 1.0) * PI))
				var ready_x: float = 0.34 if shield_up else 0.25
				_held_weapon_root.position = Vector3(ready_x - swing_phase * 0.42, 0.34 + swing_phase * 0.10, -0.22 - swing_phase * 0.24)
				_held_weapon_root.rotation = Vector3(-0.22 + aim_pitch * 0.45 - swing_phase * 0.55, 0.40 + swing_phase * 1.15, -0.35 - swing_phase * 0.65)
				if shield_up and _held_riot_shield != null and is_instance_valid(_held_riot_shield):
					_held_riot_shield.visible = true
					if swing_phase > 0.05:
						_held_riot_shield.position = _held_riot_shield_base_pos + Vector3(-0.42 * swing_phase, 0.0, 0.06 * swing_phase)
						_held_riot_shield.rotation = Vector3(0.0, 1.05 * swing_phase, 0.0)
						left_target = Vector3(-0.08 - 0.42 * swing_phase, 0.36, -0.58 + 0.06 * swing_phase)
					else:
						_held_riot_shield.position = _held_riot_shield_base_pos
						_held_riot_shield.rotation = Vector3.ZERO
						left_target = Vector3(-0.08, 0.36, -0.58)
					custom_left_target = true
			WeaponBase.WeaponKind.FLAMETHROWER:
				var f_tilt: float = 0.45 if reloading else 0.0
				_held_weapon_root.position = Vector3(0.23, 0.26, -0.14 + kick * 0.03)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.55 + 0.04 - f_tilt * 0.35, lerpf(0.32, 0.10, fire_blend), f_tilt)
			WeaponBase.WeaponKind.GRENADE_LAUNCHER:
				var g_tilt: float = 0.48 if reloading else 0.0
				_held_weapon_root.position = Vector3(0.22, 0.30, -0.14 + kick * 0.07)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.60 + 0.10 + kick * 0.14 - g_tilt * 0.35, lerpf(0.38, 0.12, fire_blend), g_tilt)
				if cycle_p > 0.0 and _weapon_parts_by_name.has("Drum"):
					var d_entry: Dictionary = _weapon_parts_by_name["Drum"]
					var d_mi := d_entry.get("node", null) as MeshInstance3D
					if d_mi != null and is_instance_valid(d_mi):
						var d_rot: Vector3 = d_entry.get("base_rot", Vector3.ZERO)
						d_mi.rotation = d_rot + Vector3(0.0, 0.0, (TAU / 6.0) * cycle_p)
			WeaponBase.WeaponKind.TNT:
				var throw_phase: float = sin(clampf(1.0 - kick, 0.0, 1.0) * PI) if kick > 0.01 else 0.0
				_held_weapon_root.position = Vector3(0.25, 0.34 + throw_phase * 0.24, -0.20 - throw_phase * 0.26)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.5 - throw_phase * 0.9, 0.20, 0.0)
			-99: # Cowboy overhead lasso TNT Rope spinning beside right shoulder/head
				_held_weapon_root.position = Vector3(0.44, 0.72, -0.04)
				_held_weapon_root.rotation = Vector3(0.12 * cos(_tnt_spin_angle), 0.0, -0.22 + 0.12 * sin(_tnt_spin_angle))
				if _tnt_rope_bundle != null and is_instance_valid(_tnt_rope_bundle):
					_tnt_rope_bundle.rotation = Vector3(0.0, _tnt_spin_angle, 0.0)
				right_target = _held_weapon_root.transform * Vector3.ZERO
				custom_right_target = true
				right_pole = Vector3(0.85, 0.25, 0.35)
				left_target = Vector3(-0.26, 0.18, -0.14)
				custom_left_target = true
			_: # SMG, Shotgun, Sniper (BFH iconic across-chest 2-handed rifle carry, tightening on fire!)
				var r_tilt: float = 0.52 if reloading else 0.0
				var base_yaw: float = 0.66 if _shown_weapon_kind == WeaponBase.WeaponKind.SNIPER else 0.58
				var sway_x: float = -stride * 0.015 * (1.0 - fire_blend)
				var sway_yaw: float = -stride * 0.035 * (1.0 - fire_blend)
				var pump_travel: float = 0.0
				if _shown_weapon_kind == WeaponBase.WeaponKind.SHOTGUN:
					if cycle_p > 0.0:
						pump_travel = sin(clampf((cycle_p - 0.18) / 0.65, 0.0, 1.0) * PI)
					elif reloading:
						pump_travel = sin(clampf((reload_p - 0.65) / 0.30, 0.0, 1.0) * PI)
				var pump_shift: float = pump_travel * 0.11
				var pump_cant: float = pump_travel * 0.22

				var bolt_lift: float = 0.0
				var bolt_pull: float = 0.0
				if _shown_weapon_kind == WeaponBase.WeaponKind.SNIPER and cycle_p > 0.0:
					bolt_lift = sin(clampf((cycle_p - 0.15) / 0.70, 0.0, 1.0) * PI)
					bolt_pull = sin(clampf((cycle_p - 0.22) / 0.58, 0.0, 1.0) * PI)

				_held_weapon_root.position = Vector3(0.21 + sway_x, 0.32 + stride * 0.012, -0.14 + kick * 0.06)
				_held_weapon_root.rotation = Vector3(
					aim_pitch * 0.55 + 0.16 + kick * 0.12 - r_tilt * 0.3 - pump_cant * 0.35 - bolt_lift * 0.08,
					lerpf(base_yaw + sway_yaw, 0.20, fire_blend),
					-0.08 + r_tilt + pump_cant + bolt_lift * 0.12
				)

				if _shown_weapon_kind == WeaponBase.WeaponKind.SHOTGUN and _weapon_parts_by_name.has("Pump"):
					var p_entry: Dictionary = _weapon_parts_by_name["Pump"]
					var p_mi := p_entry.get("node", null) as MeshInstance3D
					if p_mi != null and is_instance_valid(p_mi):
						var p_base: Vector3 = p_entry.get("base_pos", Vector3.ZERO)
						p_mi.position = p_base + Vector3(0.0, 0.0, pump_shift)
				if _shown_weapon_kind == WeaponBase.WeaponKind.SHOTGUN and pump_travel > 0.01 and not reloading:
					left_target = _held_weapon_root.transform * (_weapon_foregrip_local + Vector3(0.0, 0.0, pump_shift))
					custom_left_target = true

				if _shown_weapon_kind == WeaponBase.WeaponKind.SNIPER and _weapon_parts_by_name.has("Bolt"):
					var sb_entry: Dictionary = _weapon_parts_by_name["Bolt"]
					var sb_mi := sb_entry.get("node", null) as MeshInstance3D
					if sb_mi != null and is_instance_valid(sb_mi):
						var sb_base: Vector3 = sb_entry.get("base_pos", Vector3.ZERO)
						var sb_rot: Vector3 = sb_entry.get("base_rot", Vector3.ZERO)
						sb_mi.position = sb_base + Vector3(0.0, 0.025 * bolt_lift, 0.06 * bolt_pull)
						sb_mi.rotation = sb_rot + Vector3(0.0, 0.0, 0.45 * bolt_lift)
					if bolt_lift > 0.05:
						right_target = _held_weapon_root.transform * (_weapon_grip_local + Vector3(0.028 * bolt_pull, 0.06 * bolt_lift, 0.04 * bolt_pull))
						custom_right_target = true

		if _held_riot_shield != null and is_instance_valid(_held_riot_shield):
			if not shield_up:
				_held_riot_shield.visible = false
				_held_riot_shield.position = _held_riot_shield_base_pos
				_held_riot_shield.rotation = Vector3.ZERO
			elif not custom_left_target:
				_held_riot_shield.visible = true
				_held_riot_shield.position = _held_riot_shield_base_pos
				_held_riot_shield.rotation = Vector3.ZERO
				left_target = Vector3(-0.08, 0.36, -0.58)
				custom_left_target = true

		if not custom_right_target:
			right_target = _held_weapon_root.transform * _weapon_grip_local
		_pose_arm_ik(_arm_r_pivot, _forearm_r_pivot, right_target, right_pole)

		if not custom_left_target:
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

	# Weapon slots 1..4 (mapped via weapon_slot_order) + Q last-weapon quick-switch (across ALL equipped slots)
	var weapon_order: Array[int] = InputCmd.get_active_weapon_order(weapons.size())
	var next_slot: int = selected_weapon_slot
	var weapon_keys: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for vis_w in range(mini(weapon_order.size(), weapon_keys.size())):
		if Input.is_key_pressed(weapon_keys[vis_w] as Key):
			next_slot = weapon_order[vis_w]
			break
	if next_slot != selected_weapon_slot:
		switch_weapon_slot(next_slot)

	var q_held: bool = Input.is_key_pressed(KEY_Q)
	if q_held and not _prev_q_held:
		quick_switch_last_weapon()
	_prev_q_held = q_held

	# F1..F4 seat switching when inside a vehicle
	if current_vehicle_id >= 0:
		var seat_keys: Array[int] = [KEY_F1, KEY_F2, KEY_F3, KEY_F4]
		var cur_seat_mask: int = 0
		for sk_i in range(4):
			if Input.is_key_pressed(seat_keys[sk_i]):
				cur_seat_mask |= (1 << sk_i)
				if (_prev_seat_keys & (1 << sk_i)) == 0:
					NetworkManager.request_seat_switch(sk_i)
		_prev_seat_keys = cur_seat_mask
	else:
		_prev_seat_keys = 0

	var cursor_free: bool = is_cursor_free_mode()
	cmd.set_button(InputCmd.BTN_JUMP, Input.is_key_pressed(KEY_SPACE))
	cmd.set_button(InputCmd.BTN_CROUCH, Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C))
	cmd.set_button(InputCmd.BTN_FIRE, (not cursor_free) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	cmd.set_button(InputCmd.BTN_AIM, (not cursor_free) and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	cmd.set_button(InputCmd.BTN_RELOAD, Input.is_key_pressed(KEY_R))
	cmd.set_button(InputCmd.BTN_INTERACT, Input.is_key_pressed(KEY_E))

	for s_flag in SkillManager.SKILL_BUTTON_FLAGS:
		cmd.set_button(s_flag, false)
	var n_skills: int = skill_manager.skill_ranks.size() if skill_manager != null else (6 if class_id == NetworkManager.CLASS_COMMANDO else 5)
	var skill_order: Array[int] = InputCmd.get_active_skill_order(n_skills)
	for vis_s in range(mini(skill_order.size(), SkillManager.SKILL_BUTTON_FLAGS.size())):
		var pressed_s: bool = InputCmd.is_bind_pressed(InputCmd.get_skill_key(vis_s))
		if vis_s == 0 and not InputCmd.is_key_assigned_anywhere(KEY_F) and Input.is_key_pressed(KEY_F):
			pressed_s = true
		elif vis_s == 1 and not InputCmd.is_key_assigned_anywhere(KEY_G) and Input.is_key_pressed(KEY_G):
			pressed_s = true
		var logical_s: int = skill_order[vis_s]
		if logical_s >= 0 and logical_s < SkillManager.SKILL_BUTTON_FLAGS.size():
			cmd.set_button(SkillManager.SKILL_BUTTON_FLAGS[logical_s], pressed_s)

	for w_flag in SkillManager.WIDGET_BUTTON_FLAGS:
		cmd.set_button(w_flag, false)
	var widget_order: Array[int] = InputCmd.get_active_widget_order(4)
	for vis_wd in range(mini(widget_order.size(), SkillManager.WIDGET_BUTTON_FLAGS.size())):
		var pressed_wd: bool = InputCmd.is_bind_pressed(InputCmd.get_widget_key(vis_wd))
		var logical_wd: int = widget_order[vis_wd]
		if logical_wd >= 0 and logical_wd < SkillManager.WIDGET_BUTTON_FLAGS.size():
			cmd.set_button(SkillManager.WIDGET_BUTTON_FLAGS[logical_wd], pressed_wd)

	cmd.set_button(InputCmd.BTN_EMOTE, Input.is_key_pressed(KEY_T))

	cmd.selected_weapon_slot = selected_weapon_slot
	cmd.view_interp_tick_delta = NetworkManager.get_view_interp_tick_delta()
	return cmd


func switch_weapon_slot(new_slot: int) -> void:
	var max_slot: int = maxi(0, weapons.size() - 1)
	var clamped: int = clampi(new_slot, 0, max_slot)
	if clamped == selected_weapon_slot:
		return
	_last_weapon_slot = selected_weapon_slot
	selected_weapon_slot = clamped


## Forces a server-authoritative weapon switch (e.g. Poisoned Blade) and holds it against stale in-flight client inputs.
func force_server_weapon_slot(target_slot: int, cmd_tick: int = -1) -> void:
	var max_slot: int = maxi(0, weapons.size() - 1)
	var clamped: int = clampi(target_slot, 0, max_slot)
	var prev_slot: int = selected_weapon_slot
	switch_weapon_slot(clamped)
	forced_weapon_seq = (forced_weapon_seq + 1) & 0xFF
	if forced_weapon_seq == 0:
		forced_weapon_seq = 1
	_pending_forced_slot = clamped
	_pending_forced_from_slot = prev_slot
	_pending_forced_cmd_tick = cmd_tick


## Returns true if the incoming client weapon slot should overwrite selected_weapon_slot.
func should_apply_client_weapon_slot(incoming_slot: int, cmd_tick: int) -> bool:
	if _pending_forced_slot < 0:
		return true
	if incoming_slot == _pending_forced_slot:
		_pending_forced_slot = -1
		return true
	if _pending_forced_cmd_tick >= 0 and cmd_tick > _pending_forced_cmd_tick + 45:
		_pending_forced_slot = -1
		return true
	if _pending_forced_cmd_tick >= 0 and cmd_tick > _pending_forced_cmd_tick and incoming_slot != _pending_forced_from_slot:
		_pending_forced_slot = -1
		return true
	return false


func quick_switch_last_weapon() -> void:
	var w_count: int = weapons.size()
	if w_count <= 1:
		return
	var target: int = clampi(_last_weapon_slot, 0, w_count - 1)
	if target == selected_weapon_slot:
		target = (selected_weapon_slot + 1) % w_count
	switch_weapon_slot(target)


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
	if should_apply_client_weapon_slot(cmd.selected_weapon_slot, cmd.tick):
		selected_weapon_slot = clampi(cmd.selected_weapon_slot, 0, weapons.size() - 1) if not weapons.is_empty() else cmd.selected_weapon_slot

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

	# Fall Damage Check BEFORE resetting _airborne_fall_time so landing frame preserves fall duration
	if (grounded or is_in_water) and _was_airborne:
		var drop_h: float = _airborne_start_y - global_position.y
		if not is_parachuting and not is_in_water and _max_air_fall_speed > FALL_DAMAGE_THRESHOLD_SPEED and drop_h >= 4.2 and _airborne_fall_time >= 0.72:
			if NetworkManager.is_server_authority():
				var fall_dmg: int = maxi(5, int(roundf((_max_air_fall_speed - FALL_DAMAGE_THRESHOLD_SPEED) * 6.5)))
				apply_damage_server(fall_dmg, -1, false)
		_max_air_fall_speed = 0.0
		_was_airborne = false
		is_parachuting = false
		_airborne_start_y = global_position.y
	elif grounded or is_in_water:
		_airborne_start_y = global_position.y
	elif not grounded and not is_in_water:
		if not _was_airborne:
			_airborne_start_y = global_position.y
		else:
			_airborne_start_y = maxf(_airborne_start_y, global_position.y)
		_was_airborne = true
		if is_parachuting:
			_max_air_fall_speed = 0.0
		elif velocity.y < 0.0:
			_max_air_fall_speed = maxf(_max_air_fall_speed, -velocity.y)

	# Airborne fall time tracking: resets on ground, water, vehicle; only increments when falling past apex
	if grounded or is_in_water or current_vehicle_id >= 0:
		_airborne_fall_time = 0.0
	elif velocity.y < -0.5:
		_airborne_fall_time += delta
	else:
		_airborne_fall_time = 0.0

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

	_move_and_slide_with_steps(delta, wish_dir, grounded)

	# Emote state
	if cmd.has_button(InputCmd.BTN_EMOTE) and grounded and not is_emoting:
		is_emoting = true
		emote_timer = 0.0
		emote_triggered.emit(0)
	elif cmd.move_dir.length_squared() > 0.05 or not grounded:
		is_emoting = false

	# Update flags bitmask while preserving server-synced status bits
	const PRESERVED_STATUS_FLAGS: int = (
		NetSerializer.SNAP_BURNING
		| NetSerializer.SNAP_POISONED
		| NetSerializer.SNAP_SPEED_BOOST
		| NetSerializer.SNAP_SIXTH_SENSE
		| NetSerializer.SNAP_EAT_GRENADES
		| NetSerializer.SNAP_MARKED_TARGET
		| NetSerializer.SNAP_KEG_CONCUSSED
	)
	active_flags &= PRESERVED_STATUS_FLAGS
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


## Deterministic step-climbing ("degraus") used in 60Hz movement simulation.
func _move_and_slide_with_steps(delta: float, wish_dir: Vector3, grounded: bool) -> void:
	var pre_pos: Vector3 = global_position
	var pre_vel: Vector3 = velocity
	move_and_slide()

	if _knockback_stun_timer > 0.0 or velocity.y > 1.0:
		return
	if wish_dir.length_squared() <= 0.001 or not (grounded or is_on_floor()):
		return

	var actual_disp: Vector3 = Vector3(global_position.x - pre_pos.x, 0.0, global_position.z - pre_pos.z)
	var actual_progress: float = actual_disp.dot(wish_dir)
	var horiz_vel_len: float = Vector2(pre_vel.x, pre_vel.z).length()
	var desired_dist: float = maxf(1.5, horiz_vel_len) * delta

	# Check if any slide collision hit a steep vertical step/wall (abs(normal.y) < 0.35)
	var hit_steep_wall: bool = false
	var col_count: int = get_slide_collision_count()
	for i in range(col_count):
		var col := get_slide_collision(i)
		if absf(col.get_normal().y) < 0.35:
			hit_steep_wall = true
			break

	if not hit_steep_wall or actual_progress >= desired_dist * 0.85:
		return

	var slide_pos: Vector3 = global_position
	var slide_vel: Vector3 = velocity

	# Test stepping up via move_and_collide starting from pre_pos
	global_position = pre_pos
	velocity = pre_vel

	# 1) Lift up +Vector3.UP * MAX_STEP_HEIGHT (halt early if hitting ceiling)
	var _up_col := move_and_collide(Vector3.UP * MAX_STEP_HEIGHT)

	# 2) Advance horizontally along wish_dir (minimum 0.12m probe so slow walk still mounts steps)
	var step_advance: float = maxf(0.12, desired_dist)
	var _fwd_col := move_and_collide(wish_dir * step_advance)

	# 3) Sweep back down -Vector3.UP * (MAX_STEP_HEIGHT + 0.08) checking for valid floor
	var down_col := move_and_collide(Vector3.DOWN * (MAX_STEP_HEIGHT + 0.08))

	# 4) Validate surface and progress
	var valid_floor: bool = down_col != null and down_col.get_normal().y >= 0.68
	var stepped_disp: Vector3 = Vector3(global_position.x - pre_pos.x, 0.0, global_position.z - pre_pos.z)
	var stepped_progress: float = stepped_disp.dot(wish_dir)

	if valid_floor and stepped_progress > actual_progress + 0.005:
		velocity.y = maxf(0.0, pre_vel.y)
		_airborne_fall_time = 0.0
		_max_air_fall_speed = 0.0
		_airborne_start_y = global_position.y
		return

	# Step failed or didn't improve progress; cleanly restore move_and_slide result
	global_position = slide_pos
	velocity = slide_vel


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
	_last_vfx_key = ""
	_speed_trail_timer = 0.0
	if _body_collision != null:
		_body_collision.disabled = false
	if hero_camera != null:
		hero_camera.set_vehicle_mode(false)
		if visual_root != null:
			hero_camera.global_position = visual_root.global_position
	if visual_root != null:
		visual_root.rotation.x = 0.0
		visual_root.rotation.z = 0.0
		if not is_scoping:
			visual_root.visible = true


## Locates the current occupied VehicleBase instance across Host, Dedicated Server, and Remote Clients.
func _resolve_current_vehicle() -> VehicleBase:
	if current_vehicle_id < 0 or not is_inside_tree():
		return null
	var tree := get_tree()
	if tree == null:
		return null
	var vehs := tree.get_nodes_in_group("vehicles")
	for v in vehs:
		if v is VehicleBase and (v as VehicleBase).id == current_vehicle_id:
			return v as VehicleBase
	return null


## Synchronizes seated character position and visual transform with the vehicle.
func _sync_seated_visual_transform(veh: VehicleBase = null) -> void:
	if visual_root == null or current_vehicle_id < 0:
		return
	if veh == null:
		veh = _resolve_current_vehicle()
	if veh != null:
		visual_root.global_position = veh.get_seat_world_pos_for_hero(self)
		_sync_seated_visual_orientation(veh)
	else:
		visual_root.global_position = global_position
		visual_root.rotation.y = aim_yaw
		visual_root.rotation.x = 0.0
		visual_root.rotation.z = 0.0


## Synchronizes seated character visual transform and facing with the vehicle chassis.
func _sync_seated_visual_orientation(veh: VehicleBase) -> void:
	if visual_root == null or veh == null:
		return
	if current_seat_pose == "hidden":
		visual_root.visible = false
		return
	elif not is_scoping:
		visual_root.visible = true

	var seat: VehicleBase.SeatSlot = veh.get_seat(current_seat_index)
	var follow_turret: bool = seat != null and seat.follow_turret

	if follow_turret:
		visual_root.global_transform.basis = Basis(Vector3.UP, veh.turret_yaw)
	elif not current_seat_can_shoot and current_seat_index == 0:
		# Non-shooting Driver/Pilot (Jeep Driver, Boat Driver, Plane Pilot)
		visual_root.global_transform.basis = veh.global_transform.basis * Basis(Vector3.UP, veh.get_seat_local_yaw(current_seat_index))
	else:
		# Open shooting Passengers / Wing-riders
		var is_shooting: bool = _fire_pose_timer > 0.0 or (is_local_player and not is_bot and not is_cursor_free_mode() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (latest_server_input != null and latest_server_input.has_button(InputCmd.BTN_FIRE))
		if is_shooting:
			var veh_basis: Basis = veh.global_transform.basis
			var veh_fwd: Vector3 = -veh_basis.z
			var veh_yaw: float = atan2(-veh_fwd.x, -veh_fwd.z)
			var local_yaw: float = wrapf(aim_yaw - veh_yaw, -PI, PI)
			visual_root.global_transform.basis = veh_basis * Basis(Vector3.UP, local_yaw)
		else:
			visual_root.global_transform.basis = veh.global_transform.basis * Basis(Vector3.UP, veh.get_seat_local_yaw(current_seat_index))


func reconcile_with_server(state: Dictionary) -> void:
	var is_active_host: bool = NetworkManager.is_active_host_authority()
	if not is_local_player or is_bot or is_active_host:
		return
	var ack_tick: int = int(state.get("ack_tick", -1))
	var auth_pos: Vector3 = state.get("pos", global_position)
	var auth_vel: Vector3 = state.get("vel", velocity)
	var auth_flags: int = int(state.get("flags", 0))
	active_buffs = int(state.get("buffs", active_buffs))
	const AUTH_STATUS_MASK: int = (
		NetSerializer.SNAP_STEALTHED
		| NetSerializer.SNAP_SHIELDED
		| NetSerializer.SNAP_BURNING
		| NetSerializer.SNAP_POISONED
		| NetSerializer.SNAP_SPEED_BOOST
		| NetSerializer.SNAP_SIXTH_SENSE
		| NetSerializer.SNAP_EAT_GRENADES
		| NetSerializer.SNAP_MARKED_TARGET
		| NetSerializer.SNAP_KEG_CONCUSSED
	)
	active_flags = (active_flags & ~AUTH_STATUS_MASK) | (auth_flags & AUTH_STATUS_MASK)
	is_stealthed = (auth_flags & NetSerializer.SNAP_STEALTHED) != 0
	var auth_weapon_slot: int = int(state.get("weapon_slot", -1))
	var auth_forced_seq: int = int(state.get("forced_weapon_seq", 0))
	var forced_weapon_applied: bool = false
	if auth_forced_seq != _last_forced_weapon_seq and auth_weapon_slot >= 0:
		_last_forced_weapon_seq = auth_forced_seq
		switch_weapon_slot(auth_weapon_slot)
		forced_weapon_applied = true
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
			if current_vehicle_id >= 0 and current_seat_index == 0 and is_inside_tree():
				for v_node in get_tree().get_nodes_in_group("vehicles"):
					if v_node is VehicleBase and v_node.id == current_vehicle_id and v_node.is_aircraft():
						hero_camera.yaw = v_node.global_rotation.y
						hero_camera.pitch = maxf(hero_camera.pitch, 0.06)
						break
		if current_vehicle_id < 0 and visual_root != null:
			visual_root.rotation.x = 0.0
			visual_root.rotation.z = 0.0
			if not is_scoping:
				visual_root.visible = true
	var was_defeated: bool = is_defeated
	is_defeated = (auth_flags & NetSerializer.SNAP_DEFEATED) != 0
	if is_defeated:
		collision_layer = 0
	elif was_defeated and not is_defeated:
		collision_layer = 2
		reset_weapons_full()
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
	if forced_weapon_applied and auth_weapon_slot >= 0:
		selected_weapon_slot = clampi(auth_weapon_slot, 0, maxi(0, weapons.size() - 1))

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
	active_buffs = int(snap_dict.get("buffs", 0))
	hp = int(snap_dict.get("hp", hp))
	shield = int(snap_dict.get("shield", shield))
	selected_weapon_slot = int(snap_dict.get("weapon_slot", selected_weapon_slot))
	current_vehicle_id = int(snap_dict.get("vehicle_id", -1))
	current_seat_index = int(snap_dict.get("seat_idx", -1))
	if current_vehicle_id < 0:
		_reset_seat_metadata()
	if _body_collision != null:
		_body_collision.disabled = (current_vehicle_id >= 0)
	var was_def: bool = is_defeated
	var def: bool = (flags & NetSerializer.SNAP_DEFEATED) != 0 or hp <= 0
	is_defeated = def
	if was_def and not def:
		set_caber_spent_visual(false)
	collision_layer = 0 if def else 2
	var rot := Quaternion(Vector3.UP, yaw)
	snapshot_interpolator.push_snapshot(server_tick, server_time_ms, pos, rot, vel, yaw, pitch, 0.0, flags)


func build_snapshot_dict() -> Dictionary:
	return {
		"id": entity_id,
		"team": team,
		"class_id": class_id,
		"weapon_slot": selected_weapon_slot,
		"flags": active_flags,
		"buffs": active_buffs,
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
		velocity.y = maxf(velocity.y, maxf(9.2, impulse.y))
	floor_snap_length = 0.0
	_knockback_stun_timer = maxf(_knockback_stun_timer, 0.60)
	knockback_seq = (knockback_seq + 1) & 0xFF


func apply_damage_server(amount: int, attacker_id: int, is_explosive: bool = false, bypass_enclosure: bool = false, is_dot_tick: bool = false) -> int:
	if is_defeated or amount <= 0:
		return 0
	if status_effects != null and status_effects.has_method("is_invulnerable") and status_effects.is_invulnerable():
		return 0
	if current_vehicle_id >= 0 and current_seat_enclosed and not bypass_enclosure:
		return 0
	if not is_dot_tick and status_effects != null:
		if status_effects.has_method("interrupt_bandage_channel"):
			status_effects.interrupt_bandage_channel()
		if amount > 15 and status_effects.has_method("break_stealth"):
			status_effects.break_stealth()
	var remaining: int = amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		if status_effects != null and status_effects.get("permanent_vest_shield") != null and int(status_effects.permanent_vest_shield) > 0:
			status_effects.permanent_vest_shield = mini(int(status_effects.permanent_vest_shield), shield)
		if shield <= 0 and status_effects != null and status_effects.has_method("_sync_flags"):
			status_effects._sync_flags()
	var hp_dealt: int = mini(hp, remaining)
	hp -= hp_dealt
	if hp <= 0:
		hp = 0
		is_defeated = true
		if status_effects != null and status_effects.has_method("deactivate_carried_shield") and status_effects.get("carried_shield_active") == true:
			status_effects.deactivate_carried_shield(true)
		active_buffs = 0
		collision_layer = 0
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


func reset_weapons_full() -> void:
	_caber_head_spent = false
	for w_node in weapons:
		var w: WeaponBase = w_node as WeaponBase
		if w != null:
			w.ammo_in_mag = w.mag_size
			w.is_reloading = false
			w.reload_timer = 0.0
			w.cooldown_timer = 0.0
			w._burst_bloom = 0.0
			w._was_first_shot = true
			w._prev_fire_held = false
			w.reset_caber_for_life()
			w.ammo_changed.emit(w.ammo_in_mag, w.mag_size, false)
	_apply_caber_head_visibility()
	if NetworkManager.is_server_authority() and class_id == NetworkManager.CLASS_DEMOLISHER:
		NetworkManager.broadcast_game_event("caber_spent", {
			"hero_id": entity_id,
			"spent": false,
		})


func respawn_at(spawn_pos: Vector3, spawn_yaw: float) -> void:
	global_position = spawn_pos
	velocity = Vector3.ZERO
	aim_yaw = spawn_yaw
	if hero_camera != null:
		hero_camera.yaw = spawn_yaw
	hp = max_hp
	shield = 0
	active_buffs = 0
	is_defeated = false
	if status_effects != null and status_effects.has_method("clear_all"):
		status_effects.clear_all()
	collision_layer = 2
	reset_weapons_full()
	_pending_forced_slot = -1
	_defeat_elapsed = 0.0
	_airborne_fall_time = 0.0
	_knockback_stun_timer = 0.0
	is_parachuting = false
	is_crouching = false
	_max_air_fall_speed = 0.0
	_was_airborne = false
	_airborne_start_y = spawn_pos.y
	clear_vehicle_state()
	_prev_phys_pos = spawn_pos
	_curr_phys_pos = spawn_pos
	_pred_error_offset = Vector3.ZERO
	visual_error_offset = Vector3.ZERO
	_last_vfx_key = ""
	_speed_trail_timer = 0.0
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
