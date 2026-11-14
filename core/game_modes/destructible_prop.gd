class_name DestructibleProp
extends StaticBody3D

## Stylized destructible props (White wooden fences, wooden crates, red explosive barrels).
enum PropKind {
	WHITE_FENCE,
	CRATE,
	RED_BARREL,
}

var kind: int = PropKind.CRATE
var max_hp: int = 45
var hp: int = 45
var is_broken: bool = false
var _respawn_timer: float = 0.0
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _context: Dictionary = {}


func setup(p_kind: int, p_pos: Vector3, p_rot_y: float = 0.0, p_ctx: Dictionary = {}) -> void:
	kind = p_kind
	position = p_pos
	rotation.y = p_rot_y
	_context = p_ctx


func _ready() -> void:
	collision_layer = 64 # Layer 7 Destructible
	collision_mask = 1 | 2 | 8
	add_to_group("destructible")
	_build_prop()


func _build_prop() -> void:
	_mesh = MeshInstance3D.new()
	_col = CollisionShape3D.new()
	var mat := StandardMaterial3D.new()
	if kind == PropKind.WHITE_FENCE:
		max_hp = 30
		var box := BoxMesh.new()
		box.size = Vector3(3.6, 1.25, 0.25)
		_mesh.mesh = box
		_mesh.position = Vector3(0.0, 0.62, 0.0)
		var shape := BoxShape3D.new()
		shape.size = box.size
		_col.shape = shape
		_col.position = _mesh.position
		mat.albedo_color = Color(0.95, 0.94, 0.90)
	elif kind == PropKind.RED_BARREL:
		max_hp = 25
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = 1.25
		_mesh.mesh = cyl
		_mesh.position = Vector3(0.0, 0.62, 0.0)
		var cshape := CylinderShape3D.new()
		cshape.radius = 0.45
		cshape.height = 1.25
		_col.shape = cshape
		_col.position = _mesh.position
		mat.albedo_color = Color(0.86, 0.14, 0.12)
	else:
		max_hp = 45
		var cbox := BoxMesh.new()
		cbox.size = Vector3(1.3, 1.3, 1.3)
		_mesh.mesh = cbox
		_mesh.position = Vector3(0.0, 0.65, 0.0)
		var cbox_shape := BoxShape3D.new()
		cbox_shape.size = cbox.size
		_col.shape = cbox_shape
		_col.position = _mesh.position
		mat.albedo_color = Color(0.68, 0.48, 0.24)
	hp = max_hp
	_mesh.material_override = mat
	add_child(_mesh)
	add_child(_col)


func apply_damage_server(amount: int, attacker_id: int, _dir: Vector3, _hit_pos: Vector3, _is_explosive: bool) -> void:
	if is_broken or amount <= 0:
		return
	hp -= amount
	if hp <= 0:
		_break_prop(attacker_id)


func _break_prop(attacker_id: int) -> void:
	is_broken = true
	_respawn_timer = 35.0
	visible = false
	_col.disabled = true
	if kind == PropKind.RED_BARREL:
		var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h != null and not h.is_defeated:
				var d: float = h.global_position.distance_to(global_position)
				if d <= 6.5:
					var dmg: int = int(roundf(75.0 * clampf(1.0 - d / 7.0, 0.25, 1.0)))
					h.apply_damage_server(dmg, attacker_id, true)
					h.apply_knockback((h.global_position - global_position + Vector3(0.0, 0.7, 0.0)).normalized() * 12.0)
		NetworkManager.broadcast_game_event("explosion_vfx", {"pos": global_position, "radius": 6.5, "kind": 77})
	else:
		NetworkManager.broadcast_game_event("hit_vfx", {"pos": global_position + Vector3(0.0, 0.6, 0.0), "kind": "dust"})


func _physics_process(delta: float) -> void:
	if is_broken and (multiplayer.is_server() or multiplayer.multiplayer_peer == null):
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			is_broken = false
			hp = max_hp
			visible = true
			_col.disabled = false
