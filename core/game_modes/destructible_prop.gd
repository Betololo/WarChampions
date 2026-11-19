class_name DestructibleProp
extends StaticBody3D

## Stylized destructible props (White wooden fences, wooden crates, red explosive barrels).
enum PropKind {
	WHITE_FENCE,
	CRATE,
	RED_BARREL,
}

static var _shared_meshes: Dictionary = {}
static var _shared_shapes: Dictionary = {}
static var _shared_mats: Dictionary = {}

var kind: int = PropKind.CRATE
var max_hp: int = 45
var hp: int = 45
var is_broken: bool = false
var _respawn_timer: float = 0.0
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _context: Dictionary = {}


static func clear_shared_caches() -> void:
	_shared_meshes.clear()
	_shared_shapes.clear()
	_shared_mats.clear()


static func _get_shared_prop_assets(prop_kind: int) -> Dictionary:
	if not _shared_meshes.has(prop_kind):
		var mat := StandardMaterial3D.new()
		if prop_kind == PropKind.WHITE_FENCE:
			var box := BoxMesh.new()
			box.size = Vector3(3.6, 1.25, 0.25)
			var shape := BoxShape3D.new()
			shape.size = box.size
			mat.albedo_color = Color(0.95, 0.94, 0.90)
			_shared_meshes[prop_kind] = box
			_shared_shapes[prop_kind] = shape
		elif prop_kind == PropKind.RED_BARREL:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.45
			cyl.bottom_radius = 0.45
			cyl.height = 1.25
			var cshape := CylinderShape3D.new()
			cshape.radius = 0.45
			cshape.height = 1.25
			mat.albedo_color = Color(0.86, 0.14, 0.12)
			_shared_meshes[prop_kind] = cyl
			_shared_shapes[prop_kind] = cshape
		else:
			var cbox := BoxMesh.new()
			cbox.size = Vector3(1.3, 1.3, 1.3)
			var cbox_shape := BoxShape3D.new()
			cbox_shape.size = cbox.size
			mat.albedo_color = Color(0.68, 0.48, 0.24)
			_shared_meshes[prop_kind] = cbox
			_shared_shapes[prop_kind] = cbox_shape
		_shared_mats[prop_kind] = mat
	return {
		"mesh": _shared_meshes[prop_kind],
		"shape": _shared_shapes[prop_kind],
		"mat": _shared_mats[prop_kind],
	}


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


func reset_prop() -> void:
	is_broken = false
	_respawn_timer = 0.0
	hp = max_hp
	visible = true
	if _col != null:
		_col.disabled = false


func _build_prop() -> void:
	_mesh = MeshInstance3D.new()
	_col = CollisionShape3D.new()
	var assets: Dictionary = _get_shared_prop_assets(kind)
	_mesh.mesh = assets["mesh"] as Mesh
	_mesh.material_override = assets["mat"] as Material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_col.shape = assets["shape"] as Shape3D
	if kind == PropKind.WHITE_FENCE:
		max_hp = 30
		_mesh.position = Vector3(0.0, 0.62, 0.0)
	elif kind == PropKind.RED_BARREL:
		max_hp = 25
		_mesh.position = Vector3(0.0, 0.62, 0.0)
	else:
		max_hp = 45
		_mesh.position = Vector3(0.0, 0.65, 0.0)
	_col.position = _mesh.position
	hp = max_hp
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
		var attacker_hero: HeroCharacter = heroes_by_id.get(attacker_id, null) as HeroCharacter
		var attacker_team: int = attacker_hero.team if attacker_hero != null else -1

		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h == null or h.is_defeated:
				continue
			var d: float = h.global_position.distance_to(global_position)
			if d <= 6.5:
				var falloff: float = clampf(1.0 - d / 7.0, 0.25, 1.0)
				# Teammates take 0 damage and 0 knockback
				if attacker_team >= 0 and h.team == attacker_team and h.entity_id != attacker_id:
					continue

				var diff_with_lift: Vector3 = h.global_position - global_position + Vector3(0.0, 0.9, 0.0)
				if diff_with_lift.length_squared() < 0.001:
					diff_with_lift = Vector3.UP
				var kb_dir: Vector3 = diff_with_lift.normalized()
				var kb_impulse: Vector3 = kb_dir * 16.0 * falloff

				if h.entity_id == attacker_id:
					# ZERO self-damage, full radial self-knockback with upward lift
					h.apply_knockback(kb_impulse)
				else:
					# Enemy / unowned
					var dmg: int = int(roundf(75.0 * falloff))
					h.apply_damage_server(dmg, attacker_id, true)
					h.apply_knockback(kb_impulse)
		NetworkManager.broadcast_game_event("explosion_vfx", {"pos": global_position, "radius": 6.5, "kind": 77})
	else:
		NetworkManager.broadcast_game_event("hit_vfx", {"pos": global_position + Vector3(0.0, 0.6, 0.0), "kind": "dust"})


func _physics_process(delta: float) -> void:
	if is_broken and NetworkManager.is_server_authority():
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			is_broken = false
			hp = max_hp
			visible = true
			_col.disabled = false
