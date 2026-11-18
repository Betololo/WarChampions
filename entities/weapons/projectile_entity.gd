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
var _is_stuck: bool = false
var _stuck_target: Node3D = null
var _stuck_local_pos: Vector3 = Vector3.ZERO
var _mesh: Node3D
var _context: Dictionary = {}
var _trail_timer: float = 0.0


static func spawn_server_projectile(
	p_kind: int,
	p_owner_id: int,
	p_team: int,
	p_pos: Vector3,
	p_vel: Vector3,
	p_context: Dictionary,
	damage_override: float = -1.0,
	fallback_parent: Node = null
) -> ProjectileEntity:
	var proj := ProjectileEntity.new()
	proj.setup(p_kind, p_owner_id, p_team, p_pos, p_vel, p_context)
	if damage_override >= 0.0:
		proj.base_damage = damage_override
	var parent_node: Node = p_context.get("projectiles_root", null) as Node
	if parent_node == null:
		var heroes: Dictionary = p_context.get("heroes_by_id", {})
		var owner_node: Node = heroes.get(p_owner_id, null) as Node
		if owner_node != null:
			parent_node = owner_node.get_parent()
	if parent_node == null:
		parent_node = fallback_parent
	if parent_node != null:
		parent_node.add_child(proj)
	NetworkManager.broadcast_game_event("proj_vfx", {
		"kind": p_kind,
		"pos": p_pos,
		"vel": p_vel,
		"gravity_scale": proj.gravity_scale,
		"lifetime": proj.lifetime,
		"damage_override": damage_override,
	})
	return proj


func setup(p_kind: int, p_owner_id: int, p_team: int, p_pos: Vector3, p_vel: Vector3, p_context: Dictionary) -> void:
	kind = p_kind
	owner_id = p_owner_id
	owner_team = p_team
	position = p_pos
	velocity = p_vel
	_context = p_context

	match kind:
		ProjectileKind.BAZOOKA_ROCKET:
			gravity_scale = 0.0
			splash_radius = 8.0
			base_damage = 85.0
			knockback_force = 19.0
			lifetime = 5.0
			explode_on_impact = true
		ProjectileKind.TNT_SATCHEL:
			gravity_scale = 1.05
			splash_radius = 9.0
			base_damage = 110.0
			knockback_force = 22.0
			lifetime = 3.2
			bounce_restitution = 0.1
			explode_on_impact = false
		ProjectileKind.FRAG_GRENADE:
			gravity_scale = 1.05
			splash_radius = 7.5
			base_damage = 58.0
			knockback_force = 17.0
			lifetime = 2.0
			bounce_restitution = 0.45
			explode_on_impact = false
		ProjectileKind.EXPLOSIVE_KEG:
			gravity_scale = 1.05
			splash_radius = 9.5
			base_damage = 78.0
			knockback_force = 21.0
			lifetime = 3.8
			bounce_restitution = 0.55
			explode_on_impact = false
			apply_keg_slow = true
		ProjectileKind.TANK_SHELL:
			gravity_scale = 0.0
			splash_radius = 9.5
			base_damage = 110.0
			knockback_force = 23.0
			lifetime = 6.0
			explode_on_impact = true
		ProjectileKind.AA_FLAK:
			gravity_scale = 0.38
			splash_radius = 8.0
			base_damage = 32.0
			knockback_force = 6.0
			lifetime = 3.5
			explode_on_impact = true
			proximity_air_radius = 7.5


func _ready() -> void:
	if not bool(get_meta("visual_only", false)):
		add_to_group("destructible")
	_build_visual()
	_align_mesh_to_velocity()


func _add_visual_part(mesh: Mesh, pos: Vector3, rot: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emissive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	_mesh.add_child(mi)
	return mi


func _build_visual() -> void:
	_mesh = Node3D.new()
	add_child(_mesh)
	match kind:
		ProjectileKind.EXPLOSIVE_KEG:
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.42
			cyl.bottom_radius = 0.42
			cyl.height = 0.95
			_add_visual_part(cyl, Vector3.ZERO, Vector3.ZERO, Color(0.82, 0.18, 0.12))
			var band := CylinderMesh.new()
			band.top_radius = 0.435
			band.bottom_radius = 0.435
			band.height = 0.09
			_add_visual_part(band, Vector3(0.0, 0.28, 0.0), Vector3.ZERO, Color(0.18, 0.18, 0.2))
			_add_visual_part(band, Vector3(0.0, -0.28, 0.0), Vector3.ZERO, Color(0.18, 0.18, 0.2))
		ProjectileKind.TNT_SATCHEL:
			var box := BoxMesh.new()
			box.size = Vector3(0.4, 0.25, 0.3)
			_add_visual_part(box, Vector3.ZERO, Vector3.ZERO, Color(0.75, 0.12, 0.12))
			var cap := BoxMesh.new()
			cap.size = Vector3(0.12, 0.08, 0.12)
			_add_visual_part(cap, Vector3(0.0, 0.15, 0.0), Vector3.ZERO, Color(0.22, 0.22, 0.24))
		ProjectileKind.FRAG_GRENADE:
			var sph := SphereMesh.new()
			sph.radius = 0.16
			sph.height = 0.32
			_add_visual_part(sph, Vector3.ZERO, Vector3.ZERO, Color(0.22, 0.28, 0.20))
			var pin := BoxMesh.new()
			pin.size = Vector3(0.07, 0.09, 0.07)
			_add_visual_part(pin, Vector3(0.0, 0.17, 0.0), Vector3.ZERO, Color(0.78, 0.65, 0.24))
		ProjectileKind.BAZOOKA_ROCKET:
			var body := CylinderMesh.new()
			body.top_radius = 0.085
			body.bottom_radius = 0.095
			body.height = 0.56
			_add_visual_part(body, Vector3.ZERO, Vector3(-PI * 0.5, 0.0, 0.0), Color(0.24, 0.32, 0.20))
			var cone := CylinderMesh.new()
			cone.top_radius = 0.012
			cone.bottom_radius = 0.095
			cone.height = 0.24
			_add_visual_part(cone, Vector3(0.0, 0.0, -0.39), Vector3(-PI * 0.5, 0.0, 0.0), Color(0.78, 0.22, 0.14))
			var fin_h := BoxMesh.new()
			fin_h.size = Vector3(0.32, 0.02, 0.18)
			_add_visual_part(fin_h, Vector3(0.0, 0.0, 0.23), Vector3.ZERO, Color(0.35, 0.36, 0.38))
			var fin_v := BoxMesh.new()
			fin_v.size = Vector3(0.02, 0.32, 0.18)
			_add_visual_part(fin_v, Vector3(0.0, 0.0, 0.23), Vector3.ZERO, Color(0.35, 0.36, 0.38))
			var flame := CylinderMesh.new()
			flame.top_radius = 0.075
			flame.bottom_radius = 0.01
			flame.height = 0.34
			_add_visual_part(flame, Vector3(0.0, 0.0, 0.44), Vector3(-PI * 0.5, 0.0, 0.0), Color(1.0, 0.55, 0.08), true)
		ProjectileKind.TANK_SHELL:
			var shell_body := CylinderMesh.new()
			shell_body.top_radius = 0.11
			shell_body.bottom_radius = 0.11
			shell_body.height = 0.36
			_add_visual_part(shell_body, Vector3(0.0, 0.0, 0.05), Vector3(-PI * 0.5, 0.0, 0.0), Color(0.88, 0.68, 0.24))
			var shell_tip := CylinderMesh.new()
			shell_tip.top_radius = 0.015
			shell_tip.bottom_radius = 0.11
			shell_tip.height = 0.28
			_add_visual_part(shell_tip, Vector3(0.0, 0.0, -0.26), Vector3(-PI * 0.5, 0.0, 0.0), Color(1.0, 0.72, 0.22), true)
			var tracer_tail := SphereMesh.new()
			tracer_tail.radius = 0.11
			tracer_tail.height = 0.22
			_add_visual_part(tracer_tail, Vector3(0.0, 0.0, 0.26), Vector3.ZERO, Color(1.0, 0.45, 0.08), true)
		ProjectileKind.AA_FLAK:
			var flak_orb := SphereMesh.new()
			flak_orb.radius = 0.20
			flak_orb.height = 0.40
			_add_visual_part(flak_orb, Vector3.ZERO, Vector3.ZERO, Color(1.0, 0.85, 0.18), true)


func _align_mesh_to_velocity() -> void:
	if _mesh == null or not is_inside_tree():
		return
	if kind != ProjectileKind.BAZOOKA_ROCKET and kind != ProjectileKind.TANK_SHELL:
		return
	if velocity.length_squared() <= 0.25:
		return
	var vel_dir: Vector3 = velocity.normalized()
	if absf(vel_dir.dot(Vector3.UP)) < 0.99:
		_mesh.look_at(global_position + vel_dir, Vector3.UP)


func apply_damage_server(amount: int, _attacker_id: int, _dir: Vector3, _hit_pos: Vector3, _is_explosive: bool) -> void:
	if _exploded or bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority():
		return
	hp -= amount
	if hp <= 0:
		_detonate()


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	var is_visual_only: bool = bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority()

	lifetime -= delta
	if lifetime <= 0.0:
		if not is_visual_only:
			_detonate()
		else:
			queue_free()
		return

	if _is_stuck:
		if _stuck_target != null and is_instance_valid(_stuck_target) and _stuck_target.is_inside_tree():
			global_position = _stuck_target.to_global(_stuck_local_pos)
		return

	velocity.y -= 18.0 * gravity_scale * delta
	var next_pos: Vector3 = global_position + velocity * delta

	if is_inside_tree():
		# Proximity fuse for AA Flak against planes/airborne targets
		if not is_visual_only and proximity_air_radius > 0.0:
			var vehicles: Array[Node] = get_tree().get_nodes_in_group("vehicles")
			for v in vehicles:
				if v is Node3D and (v as Node3D).global_position.distance_to(next_pos) <= proximity_air_radius:
					if v.has_method("is_aircraft") and v.is_aircraft() and v.get("team") != owner_team:
						global_position = next_pos
						_detonate()
						return

		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		if space != null:
			var mask: int = (1 | 8 | 64) if is_visual_only else (1 | 2 | 8 | 64)
			var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, mask)
			var res: Dictionary = space.intersect_ray(query)
			if not res.is_empty():
				var hit_pos: Vector3 = res["position"]
				var hit_normal: Vector3 = res.get("normal", Vector3.UP)
				var collider: Object = res.get("collider", null)
				var hit_enemy_hero: bool = (not is_visual_only) and (collider is HeroCharacter and (collider as HeroCharacter).team != owner_team)
				var hit_vehicle: bool = (collider is Node and (collider as Node).is_in_group("vehicles"))
				if kind == ProjectileKind.TNT_SATCHEL and not hit_enemy_hero:
					_stick_to_surface(hit_pos, hit_normal, collider)
					return
				if explode_on_impact or hit_enemy_hero or hit_vehicle:
					if is_visual_only:
						queue_free()
					else:
						global_position = hit_pos
						_detonate()
					return
				else:
					# Bounce / roll (Grenades, Keg)
					global_position = hit_pos + hit_normal * 0.15
					velocity = velocity.bounce(hit_normal) * bounce_restitution
					return

	global_position = next_pos
	if kind == ProjectileKind.EXPLOSIVE_KEG and _mesh != null:
		_mesh.rotation.x += 8.0 * delta
	else:
		_align_mesh_to_velocity()

	if (kind == ProjectileKind.BAZOOKA_ROCKET or kind == ProjectileKind.TANK_SHELL) and not DisplayServer.get_name().contains("headless"):
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.055
			StatusEffectsVFX.spawn_cartoon_burst(get_parent(), global_position, "smoke", 0.32)


func _stick_to_surface(hit_pos: Vector3, hit_normal: Vector3, collider: Object) -> void:
	_is_stuck = true
	velocity = Vector3.ZERO
	gravity_scale = 0.0
	var stuck_world_pos: Vector3 = hit_pos + hit_normal * 0.08
	global_position = stuck_world_pos
	if collider is Node3D:
		var c_node: Node3D = collider as Node3D
		if c_node.get_parent() is VehicleBase:
			c_node = c_node.get_parent() as Node3D
		_stuck_target = c_node
		_stuck_local_pos = c_node.to_local(stuck_world_pos)
	else:
		_stuck_target = null


func _detonate() -> void:
	if _exploded or bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority():
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
			# ZERO friendly fire: teammates take 0 damage and 0 knockback
			if h.team == owner_team and h.entity_id != owner_id:
				continue
			var dist: float = h.global_position.distance_to(global_position)
			var eff_dist: float = maxf(0.0, dist - h.capsule_radius)
			if eff_dist <= splash_radius:
				# Solid Layer-1 vertical wall occlusion blocks splash damage & knockback
				if is_inside_tree() and dist > 0.35:
					var occ_space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
					if occ_space != null:
						var ray_from: Vector3 = global_position + Vector3(0.0, 1.05, 0.0)
						var ray_to: Vector3 = h.global_position + Vector3(0.0, 1.25, 0.0)
						var occ_q := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
						var occ_hit: Dictionary = occ_space.intersect_ray(occ_q)
						if not occ_hit.is_empty():
							var occ_normal: Vector3 = occ_hit.get("normal", Vector3.UP)
							var is_curb_or_ground: bool = occ_normal.y >= 0.45 and absf(h.global_position.y - global_position.y) < 1.8
							if not is_curb_or_ground:
								continue
				var falloff: float = clampf(1.0 - (eff_dist / splash_radius) * 0.55, 0.45, 1.0)
				var horiz_vec := Vector3(h.global_position.x - global_position.x, 0.0, h.global_position.z - global_position.z)
				var horiz_dir: Vector3 = horiz_vec.normalized() if horiz_vec.length_squared() > 0.001 else Vector3.FORWARD
				var kb_dir: Vector3 = (horiz_dir * 0.78 + Vector3.UP * 0.62).normalized()

				if h.entity_id == owner_id:
					# ZERO self-damage, full radial self-knockback for rocket jumping
					h.apply_knockback(kb_dir * knockback_force * falloff)
				else:
					# Enemies: deal damage AND always apply strong radial knockback
					var dmg: int = maxi(1, int(roundf(base_damage * falloff)))
					var dealt: int = h.apply_damage_server(dmg, owner_id, true)
					var enemy_kb: float = maxf(21.0, knockback_force)
					h.apply_knockback(kb_dir * enemy_kb * falloff)

					if apply_keg_slow and h.status_effects != null and h.status_effects.has_method("apply_concussion_slow"):
						h.status_effects.apply_concussion_slow(0.60, 5.0)

					if dealt > 0:
						var xp_cb: Callable = _context.get("on_damage_dealt", Callable())
						if xp_cb.is_valid():
							var attacker: HeroCharacter = heroes_by_id.get(owner_id, null)
							if attacker != null:
								xp_cb.call(attacker, h, dealt)
						NetworkManager.broadcast_game_event("hit_vfx", {
							"pos": h.global_position + Vector3(0.0, 1.85, 0.0),
							"kind": "spark",
							"attacker_id": owner_id,
							"victim_id": h.entity_id,
							"damage": dmg,
							"headshot": true,
						})

		# Splash damage against vehicles & destructible props
		if is_inside_tree():
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v is Node3D and v.has_method("apply_damage_server"):
					var vdist: float = (v as Node3D).global_position.distance_to(global_position)
					if vdist <= splash_radius + 3.0:
						var hit_dir: Vector3 = ((v as Node3D).global_position - global_position).normalized()
						if velocity.length_squared() > 1.0:
							hit_dir = velocity.normalized()
						if kind == ProjectileKind.BAZOOKA_ROCKET and v.has_method("apply_bazooka_damage_server"):
							v.apply_bazooka_damage_server(owner_id, hit_dir, global_position)
						else:
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
