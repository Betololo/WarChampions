class_name ProjectileEntity
extends Node3D

## Server-authoritative ballistic/arcing projectile (Bazooka, TNT, Grenades, Explosive Keg, Tank Shell, AA Flak).
enum ProjectileKind {
	BAZOOKA_ROCKET,
	TNT_SATCHEL,
	FRAG_GRENADE,
	EXPLOSIVE_KEG,
	TANK_SHELL,
	AA_FLAK,
}

var kind: int = ProjectileKind.BAZOOKA_ROCKET
var owner_id: int = -1
var owner_team: int = 0
var velocity: Vector3 = Vector3.ZERO
var gravity_scale: float = 0.0
var splash_radius: float = 5.5
var base_damage: float = 65.0
var knockback_force: float = 11.0
var lifetime: float = 5.0
var bounce_restitution: float = 0.0
var explode_on_impact: bool = true
var apply_keg_slow: bool = false
var proximity_air_radius: float = 0.0 # > 0 for AA Flak
var hp: int = 20 # Shootable mid-air (e.g. Explosive Keg)

var _exploded: bool = false
var _mesh: MeshInstance3D
var _context: Dictionary = {}


func setup(p_kind: int, p_owner_id: int, p_team: int, p_pos: Vector3, p_vel: Vector3, p_context: Dictionary) -> void:
	kind = p_kind
	owner_id = p_owner_id
	owner_team = p_team
	position = p_pos
	velocity = p_vel
	_context = p_context

	match kind:
		ProjectileKind.BAZOOKA_ROCKET:
			gravity_scale = 0.15
			splash_radius = 5.5
			base_damage = 68.0
			knockback_force = 12.0
			lifetime = 5.0
			explode_on_impact = true
		ProjectileKind.TNT_SATCHEL:
			gravity_scale = 1.0
			splash_radius = 6.5
			base_damage = 90.0
			knockback_force = 15.0
			lifetime = 3.2
			bounce_restitution = 0.1
			explode_on_impact = false
		ProjectileKind.FRAG_GRENADE:
			gravity_scale = 1.0
			splash_radius = 5.0
			base_damage = 42.0
			knockback_force = 10.0
			lifetime = 2.0
			bounce_restitution = 0.45
			explode_on_impact = false
		ProjectileKind.EXPLOSIVE_KEG:
			gravity_scale = 1.0
			splash_radius = 7.0
			base_damage = 55.0
			knockback_force = 14.0
			lifetime = 3.8
			bounce_restitution = 0.55
			explode_on_impact = false
			apply_keg_slow = true
		ProjectileKind.TANK_SHELL:
			gravity_scale = 0.85
			splash_radius = 7.5
			base_damage = 95.0
			knockback_force = 16.0
			lifetime = 6.0
			explode_on_impact = true
		ProjectileKind.AA_FLAK:
			gravity_scale = 0.1
			splash_radius = 8.0
			base_damage = 32.0
			knockback_force = 6.0
			lifetime = 3.5
			explode_on_impact = true
			proximity_air_radius = 7.5


func _ready() -> void:
	add_to_group("destructible")
	_build_visual()


func _build_visual() -> void:
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	if kind == ProjectileKind.EXPLOSIVE_KEG:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.42
		cyl.bottom_radius = 0.42
		cyl.height = 0.95
		_mesh.mesh = cyl
		mat.albedo_color = Color(0.82, 0.18, 0.12)
	elif kind == ProjectileKind.TNT_SATCHEL:
		var box := BoxMesh.new()
		box.size = Vector3(0.4, 0.25, 0.3)
		_mesh.mesh = box
		mat.albedo_color = Color(0.75, 0.12, 0.12)
	else:
		var sph := SphereMesh.new()
		sph.radius = 0.22 if kind != ProjectileKind.FRAG_GRENADE else 0.16
		sph.height = sph.radius * 2.0
		_mesh.mesh = sph
		mat.albedo_color = Color(0.2, 0.25, 0.2) if kind == ProjectileKind.FRAG_GRENADE else Color(0.95, 0.55, 0.1)
	_mesh.material_override = mat
	add_child(_mesh)


func apply_damage_server(amount: int, _attacker_id: int, _dir: Vector3, _hit_pos: Vector3, _is_explosive: bool) -> void:
	if _exploded or not multiplayer.is_server():
		return
	hp -= amount
	if hp <= 0:
		_detonate()


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	lifetime -= delta
	if lifetime <= 0.0:
		if multiplayer.is_server() or multiplayer.multiplayer_peer == null:
			_detonate()
		else:
			queue_free()
		return

	velocity.y -= 18.0 * gravity_scale * delta
	var next_pos: Vector3 = global_position + velocity * delta

	if (multiplayer.is_server() or multiplayer.multiplayer_peer == null) and is_inside_tree():
		# Proximity fuse for AA Flak against planes/airborne targets
		if proximity_air_radius > 0.0:
			var vehicles: Array[Node] = get_tree().get_nodes_in_group("vehicles")
			for v in vehicles:
				if v is Node3D and (v as Node3D).global_position.distance_to(next_pos) <= proximity_air_radius:
					if v.has_method("is_aircraft") and v.is_aircraft() and v.get("team") != owner_team:
						global_position = next_pos
						_detonate()
						return

		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, 1 | 2 | 8 | 64)
			var res: Dictionary = space.intersect_ray(query)
			if not res.is_empty():
				var hit_pos: Vector3 = res["position"]
				var hit_normal: Vector3 = res.get("normal", Vector3.UP)
				var collider: Object = res.get("collider", null)
				var hit_enemy_hero: bool = (collider is HeroCharacter and (collider as HeroCharacter).team != owner_team)
				var hit_vehicle: bool = (collider is Node and (collider as Node).is_in_group("vehicles"))
				if explode_on_impact or hit_enemy_hero or hit_vehicle:
					global_position = hit_pos
					_detonate()
					return
				else:
					# Bounce / roll (Grenades, Keg, TNT)
					global_position = hit_pos + hit_normal * 0.15
					velocity = velocity.bounce(hit_normal) * bounce_restitution
					if kind == ProjectileKind.TNT_SATCHEL:
						velocity = Vector3.ZERO
						gravity_scale = 0.0
					return

	global_position = next_pos
	if kind == ProjectileKind.EXPLOSIVE_KEG and _mesh != null:
		_mesh.rotation.x += 8.0 * delta


func _detonate() -> void:
	if _exploded:
		return
	_exploded = true

	var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
	var eaten_by_gunner: bool = false

	# Check Gunner's "I Eat Grenades" absorption BEFORE dealing splash damage
	for id_key in heroes_by_id.keys():
		var h: HeroCharacter = heroes_by_id[id_key]
		if h == null or h.is_defeated:
			continue
		if h.global_position.distance_to(global_position) <= splash_radius + 1.5:
			if h.status_effects != null and h.status_effects.has_method("can_eat_grenades") and h.status_effects.can_eat_grenades():
				var heal_amt: int = int(roundf(base_damage * 0.55))
				h.heal_server(heal_amt)
				eaten_by_gunner = true
				NetworkManager.broadcast_game_event("eat_grenades", {
					"hero_id": h.entity_id,
					"pos": global_position,
					"heal": heal_amt,
				})
				break

	if not eaten_by_gunner:
		for id_key in heroes_by_id.keys():
			var h: HeroCharacter = heroes_by_id[id_key]
			if h == null or h.is_defeated:
				continue
			# Friendly fire off except minor self-knockback
			if h.team == owner_team and h.entity_id != owner_id:
				continue
			var dist: float = h.global_position.distance_to(global_position)
			if dist <= splash_radius:
				var falloff: float = clampf(1.0 - (dist / splash_radius) * 0.75, 0.25, 1.0)
				var dmg: int = maxi(1, int(roundf(base_damage * falloff)))
				if h.entity_id == owner_id:
					dmg = int(roundf(float(dmg) * 0.35))
				var dealt: int = h.apply_damage_server(dmg, owner_id, true)
				var kb_dir: Vector3 = (h.global_position - global_position + Vector3(0.0, 0.75, 0.0)).normalized()
				h.apply_knockback(kb_dir * knockback_force * falloff)

				if apply_keg_slow and h.team != owner_team and h.status_effects != null and h.status_effects.has_method("apply_concussion_slow"):
					h.status_effects.apply_concussion_slow(0.55, 3.5)

				var xp_cb: Callable = _context.get("on_damage_dealt", Callable())
				if xp_cb.is_valid() and h.team != owner_team:
					var attacker: HeroCharacter = heroes_by_id.get(owner_id, null)
					if attacker != null:
						xp_cb.call(attacker, h, dealt)

		# Splash damage against vehicles & destructible props
		if is_inside_tree():
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v is Node3D and v.has_method("apply_damage_server"):
					var vdist: float = (v as Node3D).global_position.distance_to(global_position)
					if vdist <= splash_radius + 3.0:
						var hit_dir: Vector3 = ((v as Node3D).global_position - global_position).normalized()
						if velocity.length_squared() > 1.0:
							hit_dir = velocity.normalized()
						var vdmg: int = maxi(5, int(roundf(base_damage * 1.15 * clampf(1.0 - vdist / (splash_radius + 3.5), 0.25, 1.0))))
						v.apply_damage_server(vdmg, owner_id, hit_dir, global_position, true)

			for d in get_tree().get_nodes_in_group("destructible"):
				if d == self or not (d is Node3D):
					continue
				if d.has_method("apply_damage_server") and (d as Node3D).global_position.distance_to(global_position) <= splash_radius:
					d.apply_damage_server(int(base_damage), owner_id, Vector3.UP, global_position, true)

	NetworkManager.broadcast_game_event("explosion_vfx", {
		"pos": global_position,
		"radius": splash_radius,
		"kind": kind,
	})
	queue_free()
