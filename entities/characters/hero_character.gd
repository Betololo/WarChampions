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
var _shown_weapon_kind: int = -1
var _prev_q_held: bool = false

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
	var uniform_col: Color = Color(0.32, 0.38, 0.24) if is_royal else Color(0.24, 0.25, 0.28)
	var trim_col: Color = Color(0.86, 0.72, 0.24) if is_royal else Color(0.76, 0.16, 0.16)
	var pants_col: Color = Color(0.34, 0.30, 0.22) if is_royal else Color(0.22, 0.22, 0.24)
	var skin_col := Color(0.95, 0.76, 0.62)

	_hips_pivot = Node3D.new()
	_hips_pivot.position = Vector3(0.0, 0.76, 0.0)
	visual_root.add_child(_hips_pivot)

	# Articulated Legs & Boots
	var hip_x: float = 0.18 if class_id != NetworkManager.CLASS_GUNNER else 0.24
	_leg_l_pivot = Node3D.new()
	_leg_l_pivot.position = Vector3(-hip_x, 0.0, 0.0)
	_hips_pivot.add_child(_leg_l_pivot)
	_add_cyl(_leg_l_pivot, 0.11, 0.09, 0.56, Vector3(0.0, -0.28, 0.0), pants_col)
	_add_box(_leg_l_pivot, Vector3(0.18, 0.16, 0.28), Vector3(0.0, -0.64, -0.04), Color(0.14, 0.12, 0.10))

	_leg_r_pivot = Node3D.new()
	_leg_r_pivot.position = Vector3(hip_x, 0.0, 0.0)
	_hips_pivot.add_child(_leg_r_pivot)
	_add_cyl(_leg_r_pivot, 0.11, 0.09, 0.56, Vector3(0.0, -0.28, 0.0), pants_col)
	_add_box(_leg_r_pivot, Vector3(0.18, 0.16, 0.28), Vector3(0.0, -0.64, -0.04), Color(0.14, 0.12, 0.10))

	# Upper Torso (Sculpted V-Tapered Heroic Chest!)
	_torso_pivot = Node3D.new()
	_torso_pivot.position = Vector3(0.0, 0.06, 0.0)
	_hips_pivot.add_child(_torso_pivot)

	var chest_top_r: float = 0.30
	var chest_bot_r: float = 0.19
	var torso_col: Color = uniform_col
	if class_id == NetworkManager.CLASS_GUNNER:
		chest_top_r = 0.42
		chest_bot_r = 0.25
		torso_col = Color(0.92, 0.90, 0.85) if is_royal else Color(0.24, 0.25, 0.28) # Tank top / heavy vest
	elif class_id == NetworkManager.CLASS_COMMANDO:
		chest_top_r = 0.26
		chest_bot_r = 0.17
		torso_col = Color(0.14, 0.14, 0.16) # Dark trenchcoat

	# Belt + Buckle
	_add_cyl(_torso_pivot, chest_bot_r * 1.05, chest_bot_r * 1.05, 0.12, Vector3(0.0, 0.06, 0.0), Color(0.16, 0.14, 0.12))
	_add_box(_torso_pivot, Vector3(0.12, 0.10, 0.06), Vector3(0.0, 0.06, -chest_bot_r), trim_col)
	# V-Chest
	_add_cyl(_torso_pivot, chest_top_r, chest_bot_r, 0.62, Vector3(0.0, 0.40, 0.0), torso_col)

	if class_id == NetworkManager.CLASS_COMMANDO:
		# Trenchcoat tail & bandolier
		_add_cyl(_torso_pivot, 0.21, 0.28, 0.36, Vector3(0.0, -0.14, 0.02), torso_col)
		_add_box(_torso_pivot, Vector3(0.08, 0.45, 0.40), Vector3(0.10, 0.42, 0.0), Color(0.32, 0.22, 0.12))
	elif class_id == NetworkManager.CLASS_GUNNER:
		# Ammo belt & heavy pack
		_add_box(_torso_pivot, Vector3(0.46, 0.46, 0.24), Vector3(0.0, 0.42, 0.26), Color(0.25, 0.28, 0.22))
	else:
		# Officer scarf / tie & lapel badge
		_add_box(_torso_pivot, Vector3(0.10, 0.20, 0.06), Vector3(0.0, 0.56, -chest_top_r * 0.72), trim_col)

	# Head Pivot (Square-Jaw Cartoon Hero + Class Hat/Mustache/Shades)
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 0.74, 0.0)
	_torso_pivot.add_child(_head_pivot)
	_add_cyl(_head_pivot, 0.10, 0.12, 0.12, Vector3(0.0, 0.04, 0.0), skin_col)
	_add_box(_head_pivot, Vector3(0.26, 0.30, 0.28), Vector3(0.0, 0.22, 0.0), skin_col)
	# Nose & Brow
	_add_box(_head_pivot, Vector3(0.06, 0.09, 0.08), Vector3(0.0, 0.22, -0.16), skin_col.darkened(0.08))
	if class_id == NetworkManager.CLASS_SOLDIER:
		# Beret + Mustache
		_add_cyl(_head_pivot, 0.19, 0.16, 0.12, Vector3(-0.02, 0.39, 0.0), Color(0.38, 0.24, 0.14) if is_royal else Color(0.26, 0.26, 0.28))
		_add_box(_head_pivot, Vector3(0.14, 0.04, 0.05), Vector3(0.0, 0.15, -0.15), Color(0.25, 0.16, 0.10))
	elif class_id == NetworkManager.CLASS_GUNNER:
		# Red Beret + Aviator Sunglasses
		_add_cyl(_head_pivot, 0.20, 0.17, 0.12, Vector3(-0.03, 0.39, 0.0), Color(0.76, 0.14, 0.14) if is_royal else Color(0.25, 0.28, 0.24))
		_add_box(_head_pivot, Vector3(0.22, 0.07, 0.05), Vector3(0.0, 0.25, -0.15), Color(0.08, 0.08, 0.10))
	else:
		# Commando Wide-Brim Hat + Sunglasses
		_add_cyl(_head_pivot, 0.36, 0.36, 0.04, Vector3(0.0, 0.35, 0.0), Color(0.12, 0.12, 0.14))
		_add_cyl(_head_pivot, 0.15, 0.17, 0.14, Vector3(0.0, 0.42, 0.0), Color(0.12, 0.12, 0.14))
		_add_box(_head_pivot, Vector3(0.22, 0.07, 0.05), Vector3(0.0, 0.25, -0.15), Color(0.08, 0.08, 0.10))

	# Articulated Arms & Large Hands
	var arm_col: Color = skin_col if (class_id == NetworkManager.CLASS_GUNNER and is_royal) else torso_col
	var arm_x: float = chest_top_r + 0.10
	_arm_l_pivot = Node3D.new()
	_arm_l_pivot.position = Vector3(-arm_x, 0.62, 0.0)
	_torso_pivot.add_child(_arm_l_pivot)
	_add_cyl(_arm_l_pivot, 0.09, 0.08, 0.50, Vector3(0.0, -0.25, 0.0), arm_col)
	_add_box(_arm_l_pivot, Vector3(0.15, 0.16, 0.15), Vector3(0.0, -0.54, 0.0), skin_col)

	_arm_r_pivot = Node3D.new()
	_arm_r_pivot.position = Vector3(arm_x, 0.62, 0.0)
	_torso_pivot.add_child(_arm_r_pivot)
	_add_cyl(_arm_r_pivot, 0.09, 0.08, 0.50, Vector3(0.0, -0.25, 0.0), arm_col)
	_add_box(_arm_r_pivot, Vector3(0.15, 0.16, 0.15), Vector3(0.0, -0.54, 0.0), skin_col)

	_held_weapon_root = Node3D.new()
	_held_weapon_root.name = "HeldWeaponRoot"
	_held_weapon_root.position = Vector3(0.0, -0.48, -0.15)
	_arm_r_pivot.add_child(_held_weapon_root)
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


func _rebuild_held_weapon_mesh() -> void:
	if _held_weapon_root == null or weapons.is_empty():
		return
	var slot: int = clampi(selected_weapon_slot, 0, weapons.size() - 1)
	var w: WeaponBase = weapons[slot] as WeaponBase
	if w == null or w.weapon_kind == _shown_weapon_kind:
		return
	_shown_weapon_kind = w.weapon_kind
	for c in _held_weapon_root.get_children():
		c.queue_free()

	var metal := Color(0.22, 0.24, 0.28)
	var wood := Color(0.48, 0.28, 0.14)
	match w.weapon_kind:
		WeaponBase.WeaponKind.SNIPER:
			_add_raw_box(_held_weapon_root, Vector3(0.08, 0.10, 1.15), Vector3(0.0, 0.0, -0.45), wood)
			_add_raw_box(_held_weapon_root, Vector3(0.05, 0.05, 0.65), Vector3(0.0, 0.03, -0.95), metal)
			_add_raw_box(_held_weapon_root, Vector3(0.06, 0.06, 0.32), Vector3(0.0, 0.09, -0.35), metal)
		WeaponBase.WeaponKind.BAZOOKA:
			_add_raw_box(_held_weapon_root, Vector3(0.18, 0.18, 1.25), Vector3(0.0, 0.10, -0.25), Color(0.26, 0.38, 0.22))
		WeaponBase.WeaponKind.MG:
			_add_raw_box(_held_weapon_root, Vector3(0.14, 0.16, 0.95), Vector3(0.0, 0.0, -0.35), metal)
			_add_raw_box(_held_weapon_root, Vector3(0.18, 0.18, 0.18), Vector3(-0.10, -0.06, -0.25), Color(0.32, 0.38, 0.22))
		WeaponBase.WeaponKind.KNIFE:
			_add_raw_box(_held_weapon_root, Vector3(0.03, 0.05, 0.34), Vector3(0.0, 0.0, -0.18), Color(0.84, 0.88, 0.92))
		WeaponBase.WeaponKind.TNT:
			_add_raw_box(_held_weapon_root, Vector3(0.24, 0.16, 0.18), Vector3(0.0, 0.0, -0.15), Color(0.82, 0.16, 0.14))
		_:
			# SMG / Shotgun / Pistol
			var length: float = 0.80 if w.weapon_kind == WeaponBase.WeaponKind.SHOTGUN else (0.62 if w.weapon_kind == WeaponBase.WeaponKind.SMG else 0.32)
			_add_raw_box(_held_weapon_root, Vector3(0.08, 0.10, length), Vector3(0.0, 0.0, -length * 0.4), wood if w.weapon_kind == WeaponBase.WeaponKind.SHOTGUN else metal)


func _add_raw_box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	parent.add_child(mi)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mi.material_override = mat
	parent.add_child(mi)
	_mesh_parts.append(mi)
	return mi


func _add_cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = h
	cyl.radial_segments = 12
	mi.mesh = cyl
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mi.material_override = mat
	parent.add_child(mi)
	_mesh_parts.append(mi)
	return mi


func apply_character_shader(shader: Shader) -> void:
	if shader == null:
		return
	for mi in _mesh_parts:
		var old_mat := mi.material_override as StandardMaterial3D
		var base_col: Color = old_mat.albedo_color if old_mat != null else Color.WHITE
		var smat := ShaderMaterial.new()
		smat.shader = shader
		smat.set_shader_parameter("albedo_color", base_col)
		smat.set_shader_parameter("rim_color", Color(1.0, 0.96, 0.85))
		smat.set_shader_parameter("cloak_amount", 0.0)
		mi.material_override = smat


func _on_weapon_fired_anim(_kind: int, _muzzle: Vector3, _hit: Vector3) -> void:
	_weapon_recoil_anim = 1.0


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

	if is_defeated:
		_hips_pivot.position.y = 0.35
		_hips_pivot.rotation.x = -0.55 if not defeat_explosive else _hips_pivot.rotation.x + 8.0 * delta
		_leg_l_pivot.rotation.x = 1.2
		_leg_r_pivot.rotation.x = 1.2
		_arm_l_pivot.rotation.x = 0.5
		_arm_r_pivot.rotation.x = 0.5
		return

	_hips_pivot.rotation.x = 0.0
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
		_arm_l_pivot.rotation.x = lerpf(_arm_l_pivot.rotation.x, 2.7, 10.0 * delta)
		_arm_r_pivot.rotation.x = lerpf(_arm_r_pivot.rotation.x, 2.7, 10.0 * delta)
		_torso_pivot.rotation.x = 0.12
	elif is_emoting:
		emote_timer += delta
		_leg_l_pivot.rotation.x = 0.0
		_leg_r_pivot.rotation.x = 0.0
		_arm_l_pivot.rotation.x = 1.9 + sin(emote_timer * 12.0) * 0.6
		_arm_r_pivot.rotation.x = 1.2
		_hips_pivot.position.y = 0.76 + absf(sin(emote_timer * 8.0)) * 0.16
	else:
		_leg_l_pivot.rotation.x = stride * 0.75 + (-0.55 if is_crouching else 0.0)
		_leg_r_pivot.rotation.x = -stride * 0.75 + (-0.55 if is_crouching else 0.0)
		_torso_pivot.rotation.x = aim_pitch * 0.35 + (-0.18 if is_crouching else 0.0)
		# Right arm raises weapon forward to aim; left arm swings or braces
		_arm_r_pivot.rotation.x = 1.38 + aim_pitch * 0.7 + _weapon_recoil_anim * 0.28
		_arm_l_pivot.rotation.x = 1.18 + aim_pitch * 0.5 - stride * 0.25


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
	current_vehicle_id = int(state.get("vehicle_id", -1))
	current_seat_index = int(state.get("seat_idx", -1))
	is_defeated = (auth_flags & NetSerializer.SNAP_DEFEATED) != 0
	stats_changed.emit()

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


func apply_damage_server(amount: int, attacker_id: int, is_explosive: bool = false) -> int:
	if is_defeated or amount <= 0:
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
	hp = max_hp
	shield = 0
	is_defeated = false
	is_parachuting = false
	is_crouching = false
	_max_air_fall_speed = 0.0
	_was_airborne = false
	current_vehicle_id = -1
	current_seat_index = -1
	_prev_phys_pos = spawn_pos
	_curr_phys_pos = spawn_pos
	visual_error_offset = Vector3.ZERO
	respawned.emit()
	stats_changed.emit()


func _on_scope_toggled(scoped: bool) -> void:
	is_scoping = scoped
	if visual_root != null and is_local_player:
		visual_root.visible = not scoped
