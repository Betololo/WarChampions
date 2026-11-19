class_name CapturePoint
extends Node3D

## 3D Conquest Capture Point with visual flagpole & synchronized capture state.
signal flag_captured(point_index: int, new_owner: int, capturers: Array[HeroCharacter])

const CAPTURE_RADIUS: float = 12.0
const CAPTURE_RATE_PER_HERO: float = 0.18 # ~5.5 seconds for 1 hero

var point_index: int = 0
var point_name: String = "Flag A"
var initial_owner_team: int = -1
var owner_team: int = -1 # -1 Neutral, 0 Royal, 1 National
var capturing_team: int = -1
var progress: float = 0.0 # 0.0 neutral .. 1.0 fully captured

var _flag_mesh: MeshInstance3D
var _ring_mesh: MeshInstance3D
var _flag_label_3d: Label3D
var _last_vis_owner: int = -99
var _last_vis_cap_team: int = -99
var _last_vis_progress_q: int = -1


func setup(p_index: int, p_name: String, p_pos: Vector3, initial_owner: int = -1) -> void:
	point_index = p_index
	point_name = p_name
	position = p_pos
	initial_owner_team = initial_owner
	owner_team = initial_owner
	capturing_team = -1
	progress = 1.0 if initial_owner >= 0 else 0.0
	name = "CapturePoint_%d" % p_index
	if _flag_label_3d != null:
		_flag_label_3d.text = "[%s] %s" % [String.chr(65 + point_index), point_name]


func reset_point() -> void:
	owner_team = initial_owner_team
	capturing_team = -1
	progress = 1.0 if initial_owner_team >= 0 else 0.0
	_update_visuals()


func _ready() -> void:
	_build_flagpole_visual()
	_update_visuals()


func _build_flagpole_visual() -> void:
	var plinth := MeshInstance3D.new()
	var pl_cyl := CylinderMesh.new()
	pl_cyl.top_radius = 0.85
	pl_cyl.bottom_radius = 1.05
	pl_cyl.height = 0.36
	plinth.mesh = pl_cyl
	plinth.position = Vector3(0.0, 0.18, 0.0)
	var pl_mat := StandardMaterial3D.new()
	pl_mat.albedo_color = Color(0.55, 0.56, 0.60)
	plinth.material_override = pl_mat
	plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plinth)

	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.18
	cyl.height = 13.5
	pole.mesh = cyl
	pole.position = Vector3(0.0, 6.75, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.88, 0.88, 0.9)
	pole.material_override = pmat
	add_child(pole)

	var finial := MeshInstance3D.new()
	var fin_sph := SphereMesh.new()
	fin_sph.radius = 0.32
	fin_sph.height = 0.64
	finial.mesh = fin_sph
	finial.position = Vector3(0.0, 13.65, 0.0)
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.95, 0.78, 0.22)
	finial.material_override = fin_mat
	add_child(finial)

	_flag_mesh = MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(3.2, 1.85, 0.14)
	_flag_mesh.mesh = fbox
	_flag_mesh.position = Vector3(1.7, 12.0, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color.WHITE
	_flag_mesh.material_override = fmat
	add_child(_flag_mesh)

	_ring_mesh = MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = CAPTURE_RADIUS
	torus.bottom_radius = CAPTURE_RADIUS
	torus.height = 0.12
	_ring_mesh.mesh = torus
	_ring_mesh.position = Vector3(0.0, 0.08, 0.0)
	var rmat := StandardMaterial3D.new()
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1.0, 1.0, 1.0, 0.16)
	_ring_mesh.material_override = rmat
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring_mesh)

	_flag_label_3d = Label3D.new()
	_flag_label_3d.name = "FlagLabel3D"
	_flag_label_3d.position = Vector3(0.0, 14.8, 0.0)
	_flag_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_flag_label_3d.no_depth_test = true
	_flag_label_3d.fixed_size = false
	_flag_label_3d.pixel_size = 0.014
	_flag_label_3d.font_size = 42
	_flag_label_3d.outline_size = 10
	_flag_label_3d.text = "[%s] %s" % [String.chr(65 + point_index), point_name]
	add_child(_flag_label_3d)


func step_server(delta: float, heroes_by_id: Dictionary) -> void:
	var royal_heroes: Array[HeroCharacter] = []
	var national_heroes: Array[HeroCharacter] = []

	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h == null or h.is_defeated:
			continue
		if h.global_position.distance_to(global_position) <= CAPTURE_RADIUS:
			if h.team == NetworkManager.TEAM_ROYAL:
				royal_heroes.append(h)
			else:
				national_heroes.append(h)

	var diff: int = royal_heroes.size() - national_heroes.size()
	if diff == 0:
		capturing_team = -1
		_update_visuals()
		return

	var dominant_team: int = NetworkManager.TEAM_ROYAL if diff > 0 else NetworkManager.TEAM_NATIONAL
	var dominant_heroes: Array[HeroCharacter] = royal_heroes if diff > 0 else national_heroes
	var rate: float = float(absi(diff)) * CAPTURE_RATE_PER_HERO * delta

	if owner_team == dominant_team:
		progress = minf(1.0, progress + rate)
		capturing_team = -1
	elif owner_team == -1:
		capturing_team = dominant_team
		progress = minf(1.0, progress + rate)
		if progress >= 1.0:
			owner_team = dominant_team
			capturing_team = -1
			flag_captured.emit(point_index, owner_team, dominant_heroes)
	else:
		# Neutralize enemy flag first
		capturing_team = dominant_team
		progress = maxf(0.0, progress - rate)
		if progress <= 0.0:
			owner_team = -1

	_update_visuals()


func apply_snapshot_state(p_owner: int, p_cap_team: int, p_progress: float) -> void:
	owner_team = p_owner
	capturing_team = p_cap_team
	progress = p_progress
	_update_visuals()


func _update_visuals() -> void:
	if _flag_mesh == null:
		return
	var prog_q: int = int(roundf(clampf(progress, 0.0, 1.0) * 100.0))
	if owner_team == _last_vis_owner and capturing_team == _last_vis_cap_team and prog_q == _last_vis_progress_q:
		return
	_last_vis_owner = owner_team
	_last_vis_cap_team = capturing_team
	_last_vis_progress_q = prog_q

	var col: Color = Color(0.92, 0.92, 0.92)
	var lbl_col: Color = Color(1.0, 0.95, 0.72)
	if owner_team == NetworkManager.TEAM_ROYAL:
		col = Color(0.18, 0.45, 0.95)
		lbl_col = Color(0.40, 0.72, 1.0)
	elif owner_team == NetworkManager.TEAM_NATIONAL:
		col = Color(0.86, 0.16, 0.16)
		lbl_col = Color(1.0, 0.38, 0.38)
	elif capturing_team == NetworkManager.TEAM_ROYAL:
		col = Color(0.55, 0.72, 1.0)
	elif capturing_team == NetworkManager.TEAM_NATIONAL:
		col = Color(1.0, 0.55, 0.55)

	if _flag_mesh.material_override is StandardMaterial3D:
		(_flag_mesh.material_override as StandardMaterial3D).albedo_color = col
	_flag_mesh.position.y = lerpf(5.5, 12.0, clampf(progress, 0.0, 1.0))

	if _ring_mesh != null and _ring_mesh.material_override is StandardMaterial3D:
		(_ring_mesh.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.18)

	if _flag_label_3d != null:
		_flag_label_3d.modulate = lbl_col


func build_snapshot_dict() -> Dictionary:
	return {
		"owner": owner_team,
		"capturing_team": capturing_team,
		"progress": progress,
	}
