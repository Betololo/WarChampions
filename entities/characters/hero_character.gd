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

## Networking & Prediction
var local_tick: int = 0
var input_buffer: InputRingBuffer = InputRingBuffer.new()
var snapshot_interpolator: SnapshotInterpolator = SnapshotInterpolator.new()
var latest_server_input: InputCmd = InputCmd.new()
var _last_processed_srv_tick: int = -1

## Decoupled Visual Smoothing & Articulated Rig
var visual_root: Node3D
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


func _rebuild_cartoon_visuals() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		child.queue_free()
	_mesh_parts.clear()

	var is_royal: bool = (team == NetworkManager.TEAM_ROYAL)
	var trim_col: Color = Color(0.86, 0.72, 0.24) if is_royal else Color(0.76, 0.16, 0.16)
	var jacket_tex: String = "hero_jacket_royal" if is_royal else "hero_jacket_national"
	var pants_tex: String = "hero_pants_royal" if is_royal else "hero_pants_national"
	var hat_col: Color = Color(0.36, 0.23, 0.14) if is_royal else Color(0.24, 0.25, 0.28)
	var skin_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, "hero_skin", 0.72)
	var hair_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.22, 0.14, 0.09) if is_royal else Color(0.14, 0.13, 0.14), "", 0.80)
	var pants_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, pants_tex, 0.82)
	var boot_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.14, 0.12, 0.10), "", 0.55)
	var trim_mat := HeroMeshBuilder.make_sculpted_mat(trim_col, "", 0.50)

	var torso_tex: String = jacket_tex
	var arm_tex: String = jacket_tex
	if class_id == NetworkManager.CLASS_GUNNER:
		torso_tex = "hero_gunner_vest" if is_royal else "hero_jacket_national"
		arm_tex = "hero_skin" if is_royal else "hero_jacket_national"
	elif class_id == NetworkManager.CLASS_COMMANDO:
		torso_tex = "hero_coat_commando"
		arm_tex = "hero_coat_commando"

	var torso_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, torso_tex, 0.78)
	var arm_mat := HeroMeshBuilder.make_sculpted_mat(Color.WHITE, arm_tex, 0.76)

	_hips_pivot = Node3D.new()
	_hips_pivot.position = Vector3(0.0, 0.76, 0.0)
	visual_root.add_child(_hips_pivot)

	# Articulated Sculpted Legs & Boots
	var hip_x: float = 0.14 if class_id != NetworkManager.CLASS_GUNNER else 0.18
	var thigh_r: float = 0.115 if class_id == NetworkManager.CLASS_GUNNER else 0.095
	var leg_mesh: ArrayMesh = HeroMeshBuilder.build_leg_mesh(thigh_r)
	var boot_mesh: ArrayMesh = HeroMeshBuilder.build_boot_mesh()

	_leg_l_pivot = Node3D.new()
	_leg_l_pivot.position = Vector3(-hip_x, 0.0, 0.0)
	_hips_pivot.add_child(_leg_l_pivot)
	HeroMeshBuilder.add_part(_leg_l_pivot, leg_mesh, Vector3.ZERO, Vector3.ZERO, pants_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_leg_l_pivot, boot_mesh, Vector3(0.0, -0.56, 0.0), Vector3.ZERO, boot_mat, _mesh_parts)

	_leg_r_pivot = Node3D.new()
	_leg_r_pivot.position = Vector3(hip_x, 0.0, 0.0)
	_hips_pivot.add_child(_leg_r_pivot)
	HeroMeshBuilder.add_part(_leg_r_pivot, leg_mesh, Vector3.ZERO, Vector3.ZERO, pants_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_leg_r_pivot, boot_mesh, Vector3(0.0, -0.56, 0.0), Vector3.ZERO, boot_mat, _mesh_parts)

	# Upper Torso (Sculpted V-Tapered Jacket/Coat/Muscle Chest!)
	_torso_pivot = Node3D.new()
	_torso_pivot.position = Vector3(0.0, 0.04, 0.0)
	_hips_pivot.add_child(_torso_pivot)

	var torso_mesh: ArrayMesh = HeroMeshBuilder.build_torso_mesh(class_id)
	HeroMeshBuilder.add_part(_torso_pivot, torso_mesh, Vector3.ZERO, Vector3.ZERO, torso_mat, _mesh_parts)

	# Subtle sculpted class details (Epaulets / Canteen pouch / Collar / Bandolier) — NO ugly bricks!
	var leather_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.24, 0.18, 0.12), "", 0.65)
	if class_id == NetworkManager.CLASS_GUNNER:
		var band := CylinderMesh.new()
		band.top_radius = 0.055
		band.bottom_radius = 0.055
		band.height = 0.68
		HeroMeshBuilder.add_part(_torso_pivot, band, Vector3(0.0, 0.34, 0.02), Vector3(0.1, 0.0, 0.68), leather_mat, _mesh_parts)
		var pouch := HeroMeshBuilder.make_loft([
			{"y": -0.10, "rx": 0.12, "rz": 0.07, "p": 2.4},
			{"y": 0.10, "rx": 0.11, "rz": 0.06, "p": 2.4},
		], 12)
		HeroMeshBuilder.add_part(_torso_pivot, pouch, Vector3(0.0, 0.22, 0.18), Vector3.ZERO, leather_mat, _mesh_parts)
	else:
		# Rear hip canteen/satchel tucked smoothly at waist
		var pouch := HeroMeshBuilder.make_loft([
			{"y": -0.07, "rx": 0.08, "rz": 0.05, "p": 2.3},
			{"y": 0.07, "rx": 0.075, "rz": 0.045, "p": 2.3},
		], 10)
		HeroMeshBuilder.add_part(_torso_pivot, pouch, Vector3(-0.14, 0.12, 0.15), Vector3(0.0, 0.0, 0.08), leather_mat, _mesh_parts)

	# Head Pivot (Smooth Sculpted Pixar/BFH Square-Jaw Head, Hair Cap, Ears, Nose & Headgear!)
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 0.63, 0.0)
	_torso_pivot.add_child(_head_pivot)

	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_head_mesh(), Vector3.ZERO, Vector3.ZERO, skin_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_hair_cap_mesh(), Vector3.ZERO, Vector3.ZERO, hair_mat, _mesh_parts)

	var ear_sph := SphereMesh.new()
	ear_sph.radius = 0.036
	ear_sph.height = 0.072
	HeroMeshBuilder.add_part(_head_pivot, ear_sph, Vector3(-0.125, 0.22, 0.01), Vector3(0.0, 0.0, 0.2), skin_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_head_pivot, ear_sph, Vector3(0.125, 0.22, 0.01), Vector3(0.0, 0.0, -0.2), skin_mat, _mesh_parts)

	var nose_sph := SphereMesh.new()
	nose_sph.radius = 0.028
	nose_sph.height = 0.075
	HeroMeshBuilder.add_part(_head_pivot, nose_sph, Vector3(0.0, 0.21, -0.125), Vector3(-0.25, 0.0, 0.0), HeroMeshBuilder.make_sculpted_mat(Color(0.92, 0.72, 0.58), "", 0.72), _mesh_parts)

	var shade_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.08, 0.09, 0.11), "", 0.25)
	if class_id == NetworkManager.CLASS_SOLDIER:
		var beret_mat := HeroMeshBuilder.make_sculpted_mat(hat_col, "", 0.85)
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beret_mesh(), Vector3(-0.01, 0.34, 0.0), Vector3(0.08, 0.0, 0.16), beret_mat, _mesh_parts)
		var stache := HeroMeshBuilder.make_loft([
			{"y": -0.02, "rx": 0.065, "rz": 0.02, "p": 2.2},
			{"y": 0.015, "rx": 0.04, "rz": 0.018, "p": 2.0},
		], 10)
		HeroMeshBuilder.add_part(_head_pivot, stache, Vector3(0.0, 0.155, -0.125), Vector3.ZERO, hair_mat, _mesh_parts)
	elif class_id == NetworkManager.CLASS_GUNNER:
		var red_beret_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.76, 0.14, 0.14) if is_royal else Color(0.24, 0.28, 0.22), "", 0.85)
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_beret_mesh(), Vector3(-0.015, 0.34, 0.0), Vector3(0.06, 0.0, 0.20), red_beret_mat, _mesh_parts)
		HeroMeshBuilder.add_part(_head_pivot, trim_mat_badge_mesh(), Vector3(0.05, 0.38, -0.105), Vector3.ZERO, trim_mat, _mesh_parts)
		var goggle := HeroMeshBuilder.make_loft([
			{"y": -0.025, "rx": 0.095, "rz": 0.025, "p": 2.6},
			{"y": 0.025, "rx": 0.100, "rz": 0.025, "p": 2.6},
		], 12)
		HeroMeshBuilder.add_part(_head_pivot, goggle, Vector3(0.0, 0.25, -0.115), Vector3.ZERO, shade_mat, _mesh_parts)
	else:
		var fedora_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.11, 0.11, 0.13), "", 0.78)
		HeroMeshBuilder.add_part(_head_pivot, HeroMeshBuilder.build_fedora_mesh(), Vector3(0.0, 0.34, -0.005), Vector3(0.10, 0.0, -0.06), fedora_mat, _mesh_parts)
		var goggle_c := HeroMeshBuilder.make_loft([
			{"y": -0.022, "rx": 0.092, "rz": 0.022, "p": 2.6},
			{"y": 0.022, "rx": 0.095, "rz": 0.022, "p": 2.6},
		], 12)
		HeroMeshBuilder.add_part(_head_pivot, goggle_c, Vector3(0.0, 0.245, -0.115), Vector3.ZERO, shade_mat, _mesh_parts)

	# Two-Joint Articulated Sculpted Arms sized cleanly for 2-bone IK onto rifle grip/foregrip
	var sh_x: float = 0.285 if class_id != NetworkManager.CLASS_GUNNER else 0.345
	var arm_r_scale: float = 1.22 if class_id == NetworkManager.CLASS_GUNNER else 1.0
	var arm_len_scale: float = 1.12 if class_id == NetworkManager.CLASS_GUNNER else 1.0
	_upper_arm_len = 0.30 * arm_len_scale
	_forearm_len = 0.28 * arm_len_scale

	var sh_sph := SphereMesh.new()
	sh_sph.radius = 0.092 * arm_r_scale
	sh_sph.height = sh_sph.radius * 2.0
	var el_sph := SphereMesh.new()
	el_sph.radius = 0.072 * arm_r_scale
	el_sph.height = el_sph.radius * 2.0
	var hand_sph := SphereMesh.new()
	hand_sph.radius = 0.068 * arm_r_scale
	hand_sph.height = 0.145
	var hand_mat := HeroMeshBuilder.make_sculpted_mat(Color(0.22, 0.20, 0.18) if class_id == NetworkManager.CLASS_COMMANDO else Color.WHITE, "" if class_id == NetworkManager.CLASS_COMMANDO else "hero_skin", 0.72)

	var upper_arm_mesh: ArrayMesh = HeroMeshBuilder.build_arm_segment_mesh(0.088 * arm_r_scale, 0.072 * arm_r_scale, _upper_arm_len)
	var forearm_mesh: ArrayMesh = HeroMeshBuilder.build_arm_segment_mesh(0.070 * arm_r_scale, 0.064 * arm_r_scale, _forearm_len * 0.92)

	_arm_l_pivot = Node3D.new()
	_arm_l_pivot.position = Vector3(-sh_x, 0.53, 0.0)
	_torso_pivot.add_child(_arm_l_pivot)
	HeroMeshBuilder.add_part(_arm_l_pivot, sh_sph, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_arm_l_pivot, upper_arm_mesh, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)

	_forearm_l_pivot = Node3D.new()
	_forearm_l_pivot.position = Vector3(0.0, -_upper_arm_len, 0.0)
	_arm_l_pivot.add_child(_forearm_l_pivot)
	HeroMeshBuilder.add_part(_forearm_l_pivot, el_sph, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_forearm_l_pivot, forearm_mesh, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_forearm_l_pivot, hand_sph, Vector3(0.0, -_forearm_len, 0.0), Vector3.ZERO, hand_mat, _mesh_parts)

	_arm_r_pivot = Node3D.new()
	_arm_r_pivot.position = Vector3(sh_x, 0.53, 0.0)
	_torso_pivot.add_child(_arm_r_pivot)
	HeroMeshBuilder.add_part(_arm_r_pivot, sh_sph, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_arm_r_pivot, upper_arm_mesh, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)

	_forearm_r_pivot = Node3D.new()
	_forearm_r_pivot.position = Vector3(0.0, -_upper_arm_len, 0.0)
	_arm_r_pivot.add_child(_forearm_r_pivot)
	HeroMeshBuilder.add_part(_forearm_r_pivot, el_sph, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_forearm_r_pivot, forearm_mesh, Vector3.ZERO, Vector3.ZERO, arm_mat, _mesh_parts)
	HeroMeshBuilder.add_part(_forearm_r_pivot, hand_sph, Vector3(0.0, -_forearm_len, 0.0), Vector3.ZERO, hand_mat, _mesh_parts)

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
	var sph := SphereMesh.new()
	sph.radius = 0.022
	sph.height = 0.044
	return sph


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
		var old_mat := mi.material_override as StandardMaterial3D
		var base_col: Color = old_mat.albedo_color if old_mat != null else Color.WHITE
		var tex_key: String = str(old_mat.get_meta("tex_key", "")) if old_mat != null else ""
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("albedo_color", base_col)
		if not tex_key.is_empty():
			smat.set_shader_parameter("use_tex", true)
			smat.set_shader_parameter("albedo_tex", CartoonAssets.get_texture(tex_key))
		else:
			smat.set_shader_parameter("use_tex", false)
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
		visual_error_offset = visual_error_offset.lerp(Vector3.ZERO, minf(1.0, 20.0 * delta))
		if visual_root != null:
			if current_vehicle_id >= 0:
				visual_root.global_position = global_position
			else:
				var frac: float = Engine.get_physics_interpolation_fraction()
				var interp_world: Vector3 = _prev_phys_pos.lerp(_curr_phys_pos, frac)
				visual_root.global_position = interp_world + visual_error_offset
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
		if is_defeated:
			_defeat_prop.rotation.y += 4.0 * delta

	_weapon_recoil_anim = maxf(0.0, _weapon_recoil_anim - 7.5 * delta)
	_fire_pose_timer = maxf(0.0, _fire_pose_timer - delta)

	if is_defeated:
		_hips_pivot.position.y = 0.35
		_hips_pivot.rotation.x = -0.55 if not defeat_explosive else _hips_pivot.rotation.x + 8.0 * delta
		_leg_l_pivot.rotation.x = 1.2
		_leg_r_pivot.rotation.x = 1.2
		_arm_l_pivot.rotation = Vector3(0.5, 0.0, 0.15)
		_arm_r_pivot.rotation = Vector3(0.5, 0.0, -0.15)
		_forearm_l_pivot.rotation = Vector3(0.3, 0.0, 0.0)
		_forearm_r_pivot.rotation = Vector3(0.3, 0.0, 0.0)
		return

	_hips_pivot.rotation.x = 0.0

	var slot: int = clampi(selected_weapon_slot, 0, maxi(0, weapons.size() - 1))
	var cur_w: WeaponBase = weapons[slot] as WeaponBase if slot < weapons.size() else null
	var reloading: bool = cur_w != null and cur_w.is_reloading
	var fire_blend: float = clampf(_fire_pose_timer * 3.2, 0.0, 1.0)
	var kick: float = _weapon_recoil_anim

	if current_vehicle_id >= 0:
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

	if _held_weapon_root != null:
		_held_weapon_root.visible = true

	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed > 0.4 and is_on_floor():
		_walk_phase += horiz_speed * delta * 2.1
	else:
		_walk_phase = lerpf(_walk_phase, 0.0, 8.0 * delta)

	var stride: float = sin(_walk_phase) * clampf(horiz_speed / 7.0, 0.0, 1.0)
	var bob: float = absf(sin(_walk_phase)) * 0.06 * clampf(horiz_speed / 7.0, 0.0, 1.0)

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
		_torso_pivot.rotation.x = aim_pitch * 0.25 + (-0.14 if is_crouching else 0.0) - kick * 0.05
		_torso_pivot.rotation.y = lerpf(0.0, 0.18 if _shown_weapon_kind != WeaponBase.WeaponKind.KNIFE else kick * 0.45, 0.5 + fire_blend * 0.5)
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
				_held_weapon_root.position = Vector3(0.21, 0.32 + stride * 0.012, -0.14 + kick * 0.06)
				_held_weapon_root.rotation = Vector3(aim_pitch * 0.55 + 0.16 + kick * 0.12 - r_tilt * 0.3, lerpf(base_yaw, 0.20, fire_blend), -0.08 + r_tilt)

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
		if multiplayer.multiplayer_peer == null or (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) or not multiplayer.is_server():
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
	elif multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.is_server():
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
	return velocity.y < -0.5 or _distance_to_ground() > 2.0


## Deterministic 60Hz character physics simulation shared by Client Prediction & Server Authority.
func simulate_movement(cmd: InputCmd, delta: float) -> void:
	aim_yaw = cmd.aim_yaw
	aim_pitch = cmd.aim_pitch
	selected_weapon_slot = cmd.selected_weapon_slot

	var jump_held: bool = cmd.has_button(InputCmd.BTN_JUMP)
	var jump_just_pressed: bool = jump_held and not prev_jump_held
	prev_jump_held = jump_held

	is_crouching = cmd.has_button(InputCmd.BTN_CROUCH) and not is_parachuting
	_update_capsule_height(is_crouching)

	is_in_water = global_position.y < WATER_LEVEL - 0.55
	var grounded: bool = is_on_floor()

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

	# Jump & Infinite Reusable Parachute
	if jump_just_pressed:
		if grounded:
			velocity.y = JUMP_VELOCITY
			is_parachuting = false
		elif is_in_water:
			velocity.y = JUMP_VELOCITY * 0.8
			is_parachuting = false
		else:
			if is_parachuting:
				is_parachuting = false
			elif velocity.y < -0.2 or _distance_to_ground() > 1.6:
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

	var accel: float = 16.0 if grounded else (5.5 if is_parachuting else 8.0)
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
	visual_error_offset = Vector3.ZERO


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
	if _body_collision != null:
		_body_collision.disabled = false
	if hero_camera != null:
		hero_camera.set_vehicle_mode(false)
	if visual_root != null and not is_scoping:
		visual_root.visible = true

func reconcile_with_server(state: Dictionary) -> void:
	var is_active_host: bool = multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer) and multiplayer.is_server()
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

	var pre_reconcile_pos: Vector3 = global_position
	global_position = auth_pos
	velocity = auth_vel
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

	visual_error_offset += pre_reconcile_pos - global_position
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
		last_killer_id = attacker_id
		defeat_explosive = is_explosive
		if is_explosive:
			velocity += Vector3(randf_range(-4.0, 4.0), 10.5, randf_range(-4.0, 4.0))
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
	is_parachuting = false
	is_crouching = false
	_max_air_fall_speed = 0.0
	_was_airborne = false
	clear_vehicle_state()
	_prev_phys_pos = spawn_pos
	_curr_phys_pos = spawn_pos
	visual_error_offset = Vector3.ZERO
	respawned.emit()
	stats_changed.emit()


func _on_scope_toggled(scoped: bool) -> void:
	is_scoping = scoped
	if visual_root != null and is_local_player:
		visual_root.visible = not scoped
	if is_local_player and not is_bot:
		SoundSynthesizer.play_sfx("scope_in", 1.0 if scoped else 0.78)
