class_name CapturePoint
extends Node3D

## 3D Conquest Capture Point with visual flagpole & synchronized capture state.
signal flag_captured(point_index: int, new_owner: int, capturers: Array[HeroCharacter])

const CAPTURE_RADIUS: float = 12.0
const CAPTURE_RATE_PER_HERO: float = 0.18 # ~5.5 seconds for 1 hero

var point_index: int = 0
var point_name: String = "Flag A"
var owner_team: int = -1 # -1 Neutral, 0 Royal, 1 National
var capturing_team: int = -1
var progress: float = 0.0 # 0.0 neutral .. 1.0 fully captured

var _flag_mesh: MeshInstance3D
var _ring_mesh: MeshInstance3D


func setup(p_index: int, p_name: String, p_pos: Vector3, initial_owner: int = -1) -> void:
	point_index = p_index
	point_name = p_name
	position = p_pos
	owner_team = initial_owner
	progress = 1.0 if initial_owner >= 0 else 0.0
	name = "CapturePoint_%d" % p_index


func _ready() -> void:
	_build_flagpole_visual()
	_update_visuals()


func _build_flagpole_visual() -> void:
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14
	cyl.bottom_radius = 0.18
	cyl.height = 10.0
	pole.mesh = cyl
	pole.position = Vector3(0.0, 5.0, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.88, 0.88, 0.9)
	pole.material_override = pmat
	add_child(pole)

	_flag_mesh = MeshInstance3D.new()
	var fbox := BoxMesh.new()
	fbox.size = Vector3(2.8, 1.6, 0.12)
	_flag_mesh.mesh = fbox
	_flag_mesh.position = Vector3(1.5, 9.0, 0.0)
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
	add_child(_ring_mesh)


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
	var col: Color = Color(0.92, 0.92, 0.92)
	if owner_team == NetworkManager.TEAM_ROYAL:
		col = Color(0.18, 0.45, 0.95)
	elif owner_team == NetworkManager.TEAM_NATIONAL:
		col = Color(0.86, 0.16, 0.16)
	elif capturing_team == NetworkManager.TEAM_ROYAL:
		col = Color(0.55, 0.72, 1.0)
	elif capturing_team == NetworkManager.TEAM_NATIONAL:
		col = Color(1.0, 0.55, 0.55)

	if _flag_mesh.material_override is StandardMaterial3D:
		(_flag_mesh.material_override as StandardMaterial3D).albedo_color = col
	_flag_mesh.position.y = lerpf(3.0, 9.0, clampf(progress, 0.0, 1.0))

	if _ring_mesh != null and _ring_mesh.material_override is StandardMaterial3D:
		(_ring_mesh.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.18)


func build_snapshot_dict() -> Dictionary:
	return {
		"owner": owner_team,
		"capturing_team": capturing_team,
		"progress": progress,
	}
