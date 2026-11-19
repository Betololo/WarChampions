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
	FIREBALL,
	BOUNCE_GRENADE,
	CANNON_BALL,
	TRAPPER_STICKY,
	TNT_ROPE_CLUSTER,
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
var age_sec: float = 0.0
var hit_radius: float = 0.65

var _exploded: bool = false
var _is_stuck: bool = false
var _stuck: bool = false
var _bounce_fuse_started: bool = false
var _stuck_target: Node3D = null
var _stuck_local_pos: Vector3 = Vector3.ZERO
var _mesh: Node3D
var _context: Dictionary = {}
var _trail_timer: float = 0.0

static var _next_proj_uid: int = 1
var proj_uid: int = 0


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
	proj.proj_uid = _next_proj_uid
	_next_proj_uid += 1
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
		"uid": proj.proj_uid,
		"kind": p_kind,
		"team": p_team,
		"pos": p_pos,
		"vel": p_vel,
		"gravity_scale": proj.gravity_scale,
		"lifetime": proj.lifetime,
		"damage_override": damage_override,
	})
	return proj


func setup_visual(payload: Dictionary) -> void:
	set_meta("visual_only", true)
	proj_uid = int(payload.get("uid", 0))
	setup(
		int(payload.get("kind", 0)),
		-1,
		int(payload.get("team", -1)),
		payload.get("pos", Vector3.ZERO),
		payload.get("vel", Vector3.ZERO),
		{}
	)
	if payload.has("gravity_scale"):
		gravity_scale = float(payload["gravity_scale"])
	if payload.has("lifetime"):
		lifetime = float(payload["lifetime"])
	add_to_group("client_proj_vfx")


func setup(p_kind: int, p_owner_id: int, p_team: int, p_pos: Vector3, p_vel: Vector3, p_context: Dictionary) -> void:
	kind = p_kind
	owner_id = p_owner_id
	owner_team = p_team
	position = p_pos
	velocity = p_vel
	_context = p_context
	age_sec = 0.0
	_is_stuck = false
	_stuck = false
	_bounce_fuse_started = false

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
		ProjectileKind.FIREBALL:
			gravity_scale = 0.0
			splash_radius = 2.6
			base_damage = 40.0
			knockback_force = 4.0
			lifetime = 0.68
			explode_on_impact = true
		ProjectileKind.BOUNCE_GRENADE:
			gravity_scale = 1.0
			splash_radius = 6.5
			base_damage = 60.0
			knockback_force = 15.0
			lifetime = 6.0
			bounce_restitution = 0.24
			explode_on_impact = false
		ProjectileKind.CANNON_BALL:
			gravity_scale = 0.42
			splash_radius = 7.5
			base_damage = 100.0
			knockback_force = 24.0
			lifetime = 5.0
			explode_on_impact = true
		ProjectileKind.TRAPPER_STICKY:
			gravity_scale = 1.0
			splash_radius = 6.0
			base_damage = 40.0
			knockback_force = 14.0
			lifetime = 45.0
			explode_on_impact = false
			hit_radius = 0.36
			if not bool(get_meta("visual_only", false)):
				add_to_group("destructible_stickies")
		ProjectileKind.TNT_ROPE_CLUSTER:
			gravity_scale = 1.0
			splash_radius = 8.5
			base_damage = 105.0
			knockback_force = 23.0
			lifetime = 1.8
			explode_on_impact = true


func _ready() -> void:
	if bool(get_meta("visual_only", false)):
		add_to_group("client_proj_vfx")
	else:
		if kind == ProjectileKind.TRAPPER_STICKY:
			add_to_group("destructible_stickies")
		else:
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
		ProjectileKind.FIREBALL:
			var fb := SphereMesh.new()
			fb.radius = 0.24
			fb.height = 0.48
			_add_visual_part(fb, Vector3.ZERO, Vector3.ZERO, Color(1.0, 0.48, 0.08), true)
		ProjectileKind.BOUNCE_GRENADE:
			var bg := CapsuleMesh.new()
			bg.radius = 0.115
			bg.height = 0.36
			_add_visual_part(bg, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), Color(0.24, 0.30, 0.20))
			var brass_rim := CylinderMesh.new()
			brass_rim.top_radius = 0.12
			brass_rim.bottom_radius = 0.12
			brass_rim.height = 0.055
			brass_rim.radial_segments = 12
			_add_visual_part(brass_rim, Vector3(0.0, 0.0, 0.10), Vector3(PI * 0.5, 0.0, 0.0), Color(0.78, 0.62, 0.24))
			var fuse_tip := SphereMesh.new()
			fuse_tip.radius = 0.088
			fuse_tip.height = 0.15
			_add_visual_part(fuse_tip, Vector3(0.0, 0.0, -0.13), Vector3.ZERO, Color(0.92, 0.46, 0.10))
		ProjectileKind.CANNON_BALL:
			var cb := SphereMesh.new()
			cb.radius = 0.24
			cb.height = 0.48
			_add_visual_part(cb, Vector3.ZERO, Vector3.ZERO, Color(0.18, 0.19, 0.22))
		ProjectileKind.TRAPPER_STICKY:
			var st := SphereMesh.new()
			st.radius = 0.18
			st.height = 0.36
			var st_col: Color = Color(0.20, 0.45, 0.88) if owner_team == NetworkManager.TEAM_ROYAL else Color(0.86, 0.22, 0.18)
			_add_visual_part(st, Vector3.ZERO, Vector3.ZERO, st_col)
			var sp1 := BoxMesh.new()
			sp1.size = Vector3(0.42, 0.07, 0.07)
			_add_visual_part(sp1, Vector3.ZERO, Vector3.ZERO, Color(0.22, 0.22, 0.24))
			var sp2 := BoxMesh.new()
			sp2.size = Vector3(0.07, 0.42, 0.07)
			_add_visual_part(sp2, Vector3.ZERO, Vector3.ZERO, Color(0.22, 0.22, 0.24))
		ProjectileKind.TNT_ROPE_CLUSTER:
			var bundle := BoxMesh.new()
			bundle.size = Vector3(0.42, 0.24, 0.36)
			_add_visual_part(bundle, Vector3.ZERO, Vector3.ZERO, Color(0.82, 0.14, 0.12))
			var strap := BoxMesh.new()
			strap.size = Vector3(0.44, 0.07, 0.38)
			_add_visual_part(strap, Vector3.ZERO, Vector3.ZERO, Color(0.18, 0.18, 0.20))


func _align_mesh_to_velocity() -> void:
	if _mesh == null or not is_inside_tree():
		return
	if kind != ProjectileKind.BAZOOKA_ROCKET and kind != ProjectileKind.TANK_SHELL and kind != ProjectileKind.BOUNCE_GRENADE:
		return
	if velocity.length_squared() <= 0.25:
		return
	var vel_dir: Vector3 = velocity.normalized()
	if absf(vel_dir.dot(Vector3.UP)) < 0.99:
		_mesh.look_at(global_position + vel_dir, Vector3.UP)
	else:
		_mesh.look_at(global_position + vel_dir, Vector3.FORWARD)


func can_detonate() -> bool:
	return age_sec >= 0.5 and not _exploded and not is_queued_for_deletion()


func destroy_by_enemy(emit_vfx: bool = true) -> void:
	if _exploded:
		return
	_exploded = true
	remove_from_group("destructible_stickies")
	if not bool(get_meta("visual_only", false)) and NetworkManager.is_server_authority():
		if proj_uid > 0:
			NetworkManager.broadcast_game_event("proj_destroy", {"uid": proj_uid})
		if emit_vfx and is_inside_tree():
			NetworkManager.broadcast_game_event("hit_vfx", {
				"pos": global_position,
				"kind": "spark",
			})
	queue_free()


func apply_damage_server(amount: int, attacker_id: int, _dir: Vector3, _hit_pos: Vector3, _is_explosive: bool) -> void:
	if _exploded or bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority():
		return
	if kind == ProjectileKind.TRAPPER_STICKY:
		var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
		var attacker_h: HeroCharacter = heroes_by_id.get(attacker_id, null) as HeroCharacter
		if attacker_h != null and attacker_h.team == owner_team:
			return
		hp -= amount
		if hp <= 0:
			destroy_by_enemy()
		return
	hp -= amount
	if hp <= 0:
		_detonate()


func _is_target_vehicle_node(veh: VehicleBase, shooter_vehicle_id: int = -1) -> bool:
	if veh == null or veh.is_destroyed:
		return false
	if shooter_vehicle_id >= 0 and veh.id == shooter_vehicle_id:
		return false
	if veh.team < 0 or veh.team != owner_team:
		return true
	var heroes_map: Dictionary = _context.get("heroes_by_id", {})
	for s in veh.seats:
		if s.occupant_id >= 0:
			var occ: HeroCharacter = heroes_map.get(s.occupant_id, null) as HeroCharacter
			if occ != null and not occ.is_defeated and occ.team != owner_team:
				return true
	return false


func _is_target_vehicle(collider: Object, shooter_vehicle_id: int = -1) -> bool:
	if not (collider is Node):
		return false
	var n: Node = collider as Node
	var veh: VehicleBase = null
	if n is VehicleBase:
		veh = n as VehicleBase
	elif n.get_parent() is VehicleBase:
		veh = n.get_parent() as VehicleBase
	elif n.is_in_group("vehicles"):
		return true
	if veh != null:
		return _is_target_vehicle_node(veh, shooter_vehicle_id)
	return false


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	age_sec += delta
	var is_visual_only: bool = bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority()

	if kind != ProjectileKind.TRAPPER_STICKY:
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
		var heroes_map: Dictionary = _context.get("heroes_by_id", {})
		var shooter_excl: Array[RID] = []
		var shooter_vehicle_id: int = -1
		var shooter_var: Variant = heroes_map.get(owner_id, null)
		if shooter_var != null and is_instance_valid(shooter_var) and shooter_var is HeroCharacter:
			var shooter_h: HeroCharacter = shooter_var as HeroCharacter
			shooter_excl.append(shooter_h.get_rid())
			shooter_vehicle_id = shooter_h.current_vehicle_id
			if shooter_vehicle_id >= 0:
				for v_own in get_tree().get_nodes_in_group("vehicles"):
					if v_own is VehicleBase and (v_own as VehicleBase).id == shooter_vehicle_id:
						shooter_excl.append((v_own as CollisionObject3D).get_rid())

		# Direct hero & vehicle contact proximity sweep for FIREBALL, BOUNCE_GRENADE, and CANNON_BALL
		if not is_visual_only and (kind == ProjectileKind.FIREBALL or kind == ProjectileKind.BOUNCE_GRENADE or kind == ProjectileKind.CANNON_BALL):
			var hero_prox_r: float = 0.62 if kind == ProjectileKind.FIREBALL else 0.42
			var hull_aabb := AABB(Vector3(-1.8, -0.8, -3.0), Vector3(3.6, 3.6, 6.0))
			var best_dist_sq: float = INF
			var best_contact: Vector3 = Vector3.ZERO
			var best_veh_rid: RID = RID()
			var has_contact: bool = false

			for id_key in heroes_map.keys():
				var h_var: Variant = heroes_map[id_key]
				if not is_instance_valid(h_var) or not (h_var is HeroCharacter):
					continue
				var h: HeroCharacter = h_var as HeroCharacter
				if h.is_defeated or h.entity_id == owner_id or h.team == owner_team:
					continue
				if h.current_vehicle_id >= 0 and h.current_seat_enclosed:
					continue
				if kind == ProjectileKind.FIREBALL and (h.is_in_water or (h.status_effects != null and h.status_effects.fire_immunity_timer > 0.0)):
					continue
				var h_pos: Vector3 = h.global_position if h.is_inside_tree() else h.position
				var closest: PackedVector3Array = Geometry3D.get_closest_points_between_segments(
					global_position, next_pos,
					h_pos + Vector3(0.0, 0.3, 0.0), h_pos + Vector3(0.0, 1.7, 0.0)
				)
				var seg_pt: Vector3 = closest[0]
				var cap_pt: Vector3 = closest[1]
				if seg_pt.distance_to(cap_pt) <= hero_prox_r + h.capsule_radius * 0.4:
					var d_sq: float = global_position.distance_squared_to(seg_pt)
					if d_sq < best_dist_sq:
						best_dist_sq = d_sq
						best_contact = seg_pt
						best_veh_rid = RID()
						has_contact = true

			for v in get_tree().get_nodes_in_group("vehicles"):
				if not (v is Node3D):
					continue
				if v is VehicleBase:
					if not _is_target_vehicle_node(v as VehicleBase, shooter_vehicle_id):
						continue
					var vb: VehicleBase = v as VehicleBase
					var v_xform: Transform3D = vb.global_transform
					var v_inv: Transform3D = v_xform.affine_inverse()
					var local_start: Vector3 = v_inv * global_position
					var local_end: Vector3 = v_inv * next_pos
					var contact_pt: Vector3 = Vector3.ZERO
					var hit_v: bool = false
					if hull_aabb.has_point(local_start):
						contact_pt = global_position
						hit_v = true
					elif hull_aabb.has_point(local_end):
						contact_pt = next_pos
						hit_v = true
					else:
						var hit_local: Variant = hull_aabb.intersects_segment(local_start, local_end)
						if hit_local is Vector3:
							contact_pt = v_xform * (hit_local as Vector3)
							hit_v = true
					if hit_v:
						var d_sq_v: float = global_position.distance_squared_to(contact_pt)
						if d_sq_v < best_dist_sq:
							best_dist_sq = d_sq_v
							best_contact = contact_pt
							best_veh_rid = vb.get_rid()
							has_contact = true
				else:
					var v_pos: Vector3 = (v as Node3D).global_position + Vector3(0.0, 0.85, 0.0)
					var seg_v: Vector3 = Geometry3D.get_closest_point_to_segment(v_pos, global_position, next_pos)
					if seg_v.distance_to(v_pos) <= 1.3:
						var d_sq_v2: float = global_position.distance_squared_to(seg_v)
						if d_sq_v2 < best_dist_sq:
							best_dist_sq = d_sq_v2
							best_contact = seg_v
							best_veh_rid = (v as CollisionObject3D).get_rid() if v is CollisionObject3D else RID()
							has_contact = true

			if has_contact:
				var wall_blocked: bool = false
				if space != null and best_dist_sq > 0.01:
					var occ_excl: Array[RID] = shooter_excl.duplicate()
					if best_veh_rid.is_valid():
						occ_excl.append(best_veh_rid)
					var occ_q := PhysicsRayQueryParameters3D.create(global_position, best_contact, 1, occ_excl)
					occ_q.hit_from_inside = true
					if not space.intersect_ray(occ_q).is_empty():
						wall_blocked = true
				if not wall_blocked:
					global_position = best_contact
					_detonate()
					return

		if space != null:
			var mask: int = (1 | 8 | 64) if is_visual_only else (1 | 2 | 8 | 64)
			var query := PhysicsRayQueryParameters3D.create(global_position, next_pos, mask)
			query.hit_from_inside = true
			if not shooter_excl.is_empty():
				query.exclude = shooter_excl
			var res: Dictionary = space.intersect_ray(query)
			if not res.is_empty():
				var hit_pos: Vector3 = res["position"]
				var hit_normal: Vector3 = res.get("normal", Vector3.UP)
				var collider: Object = res.get("collider", null)
				var hit_enemy_hero: bool = (not is_visual_only) and (collider is HeroCharacter and (collider as HeroCharacter).team != owner_team)
				var hit_vehicle: bool = _is_target_vehicle(collider, shooter_vehicle_id)
				if kind == ProjectileKind.TNT_SATCHEL and not hit_enemy_hero:
					_stick_to_surface(hit_pos, hit_normal, collider)
					return
				if kind == ProjectileKind.TRAPPER_STICKY:
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
					if kind == ProjectileKind.BOUNCE_GRENADE:
						if not _bounce_fuse_started and not (collider is HeroCharacter):
							_bounce_fuse_started = true
							lifetime = minf(lifetime, 1.0)
						global_position = hit_pos + hit_normal * 0.06
						velocity = velocity.bounce(hit_normal) * bounce_restitution
						if hit_normal.y >= 0.45:
							velocity.y = minf(velocity.y, 4.0)
							velocity.x *= 0.72
							velocity.z *= 0.72
					else:
						global_position = hit_pos + hit_normal * 0.15
						velocity = velocity.bounce(hit_normal) * bounce_restitution
					_align_mesh_to_velocity()
					return

	global_position = next_pos
	if kind == ProjectileKind.EXPLOSIVE_KEG and _mesh != null:
		_mesh.rotation.x += 8.0 * delta
	else:
		_align_mesh_to_velocity()

	if (kind == ProjectileKind.BAZOOKA_ROCKET or kind == ProjectileKind.TANK_SHELL or kind == ProjectileKind.FIREBALL) and not DisplayServer.get_name().contains("headless"):
		_trail_timer -= delta
		if _trail_timer <= 0.0:
			_trail_timer = 0.055
			var trail_kind: String = "fire" if kind == ProjectileKind.FIREBALL else "smoke"
			StatusEffectsVFX.spawn_cartoon_burst(get_parent(), global_position, trail_kind, 0.32)


func _stick_to_surface(hit_pos: Vector3, hit_normal: Vector3, collider: Object) -> void:
	_is_stuck = true
	_stuck = true
	velocity = Vector3.ZERO
	gravity_scale = 0.0
	var stuck_world_pos: Vector3 = hit_pos + hit_normal * 0.04
	global_position = stuck_world_pos
	if collider is Node3D:
		var c_node: Node3D = collider as Node3D
		if c_node.get_parent() is VehicleBase:
			c_node = c_node.get_parent() as Node3D
		if c_node is HeroCharacter:
			_stuck_target = null
		else:
			_stuck_target = c_node
			_stuck_local_pos = c_node.to_local(stuck_world_pos)
	else:
		_stuck_target = null


func _detonate() -> void:
	if _exploded or bool(get_meta("visual_only", false)) or not NetworkManager.is_server_authority():
		return
	_exploded = true
	remove_from_group("destructible_stickies")
	if proj_uid > 0:
		NetworkManager.broadcast_game_event("proj_destroy", {"uid": proj_uid})

	var heroes_by_id: Dictionary = _context.get("heroes_by_id", {})
	var eaten_by_gunner: bool = false
	var is_demolisher_grenade: bool = (
		kind == ProjectileKind.BOUNCE_GRENADE
		or kind == ProjectileKind.CANNON_BALL
		or kind == ProjectileKind.TRAPPER_STICKY
		or kind == ProjectileKind.TNT_ROPE_CLUSTER
	)

	# Check Gunner's "I Eat Grenades" absorption BEFORE dealing splash damage (skip for Fireball)
	if kind != ProjectileKind.FIREBALL:
		for id_key in heroes_by_id.keys():
			var h_var: Variant = heroes_by_id[id_key]
			if not is_instance_valid(h_var) or not (h_var is HeroCharacter):
				continue
			var h: HeroCharacter = h_var as HeroCharacter
			if h.is_defeated:
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
		var attacker_var: Variant = heroes_by_id.get(owner_id, null)
		var attacker_h: HeroCharacter = attacker_var as HeroCharacter if is_instance_valid(attacker_var) else null
		for id_key in heroes_by_id.keys():
			var h_var: Variant = heroes_by_id[id_key]
			if not is_instance_valid(h_var) or not (h_var is HeroCharacter):
				continue
			var h: HeroCharacter = h_var as HeroCharacter
			if h.is_defeated:
				continue
			# ZERO friendly fire: teammates take 0 damage and 0 knockback
			if h.team == owner_team and h.entity_id != owner_id:
				continue
			var dist: float = h.global_position.distance_to(global_position)
			if is_demolisher_grenade or kind == ProjectileKind.FIREBALL:
				var chest_dist: float = (h.global_position + Vector3(0.0, 1.05, 0.0)).distance_to(global_position)
				dist = minf(dist, chest_dist)
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
				if is_demolisher_grenade:
					falloff = clampf(1.0 - (eff_dist / splash_radius) * 0.72, 0.25, 1.0)
				elif kind == ProjectileKind.FIREBALL:
					falloff = 1.0
				var horiz_vec := Vector3(h.global_position.x - global_position.x, 0.0, h.global_position.z - global_position.z)
				var horiz_dir: Vector3 = horiz_vec.normalized() if horiz_vec.length_squared() > 0.001 else Vector3.FORWARD
				var kb_dir: Vector3 = (horiz_dir * 0.78 + Vector3.UP * 0.62).normalized()

				if h.entity_id == owner_id:
					# ZERO self-damage, full radial self-knockback for rocket jumping (skip for Fireball)
					if kind != ProjectileKind.FIREBALL:
						h.apply_knockback(kb_dir * knockback_force * falloff)
				else:
					if kind == ProjectileKind.FIREBALL:
						var is_fire_immune: bool = h.is_in_water or (h.status_effects != null and h.status_effects.fire_immunity_timer > 0.0)
						if is_fire_immune:
							continue
					# Enemies: check frontal carried shield block, then deal damage AND apply radial knockback
					var dmg: int = maxi(1, int(roundf(base_damage * falloff)))
					var atk_from_target := Vector3(global_position.x - h.global_position.x, 0.0, global_position.z - h.global_position.z)
					if atk_from_target.length_squared() < 0.0001 and velocity.length_squared() > 0.0001:
						atk_from_target = Vector3(-velocity.x, 0.0, -velocity.z)
					if h.status_effects != null and h.status_effects.has_method("is_frontal_carried_shield_block_dir") and h.status_effects.is_frontal_carried_shield_block_dir(atk_from_target):
						h.status_effects.damage_carried_shield(dmg)
						NetworkManager.broadcast_game_event("hit_vfx", {
							"pos": h.global_position + Vector3(0.0, 1.3, 0.0),
							"kind": "spark",
							"attacker_id": owner_id,
							"victim_id": h.entity_id,
							"damage": 0,
							"headshot": false,
						})
						continue
					var dealt: int = h.apply_damage_server(dmg, owner_id, kind != ProjectileKind.FIREBALL)
					var enemy_kb: float = knockback_force if (is_demolisher_grenade or kind == ProjectileKind.FIREBALL) else maxf(21.0, knockback_force)
					if kind != ProjectileKind.FIREBALL:
						h.apply_knockback(kb_dir * enemy_kb * falloff)

					if kind == ProjectileKind.FIREBALL and h.status_effects != null and h.status_effects.has_method("apply_burn"):
						h.status_effects.apply_burn(owner_id, 10.0, 3.0)

					if apply_keg_slow and h.status_effects != null and h.status_effects.has_method("apply_concussion_slow"):
						h.status_effects.apply_concussion_slow(0.60, 5.0)

					if dealt > 0:
						var xp_cb: Callable = _context.get("on_damage_dealt", Callable())
						if xp_cb.is_valid() and attacker_h != null:
							xp_cb.call(attacker_h, h, dealt)
						NetworkManager.broadcast_game_event("hit_vfx", {
							"pos": h.global_position + Vector3(0.0, 1.85, 0.0),
							"kind": "fire" if kind == ProjectileKind.FIREBALL else "spark",
							"attacker_id": owner_id,
							"victim_id": h.entity_id,
							"damage": dmg,
							"headshot": kind != ProjectileKind.FIREBALL,
						})

		# Splash damage against vehicles, enemy stickies & destructible props
		if is_inside_tree():
			var veh_mult: float = 1.0
			if attacker_h != null and attacker_h.status_effects != null and attacker_h.status_effects.has_method("get_vehicle_damage_mult"):
				veh_mult = float(attacker_h.status_effects.get_vehicle_damage_mult())
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v is VehicleBase and not _is_target_vehicle_node(v as VehicleBase):
					continue
				if v is Node3D and v.has_method("apply_damage_server"):
					var vdist: float = (v as Node3D).global_position.distance_to(global_position)
					if vdist <= splash_radius + 3.0:
						var hit_dir: Vector3 = ((v as Node3D).global_position - global_position).normalized()
						if velocity.length_squared() > 1.0:
							hit_dir = velocity.normalized()
						if kind == ProjectileKind.BAZOOKA_ROCKET and v.has_method("apply_bazooka_damage_server") and is_equal_approx(veh_mult, 1.0):
							v.apply_bazooka_damage_server(owner_id, hit_dir, global_position)
						else:
							var base_v: float = float(v.compute_bazooka_directional_damage(hit_dir, global_position)) if (kind == ProjectileKind.BAZOOKA_ROCKET and v.has_method("compute_bazooka_directional_damage")) else (base_damage * 1.15 * clampf(1.0 - vdist / (splash_radius + 3.5), 0.25, 1.0))
							var vdmg: int = maxi(5, int(roundf(base_v * veh_mult)))
							v.apply_damage_server(vdmg, owner_id, hit_dir, global_position, true)

			for s in get_tree().get_nodes_in_group("destructible_stickies"):
				if s == self or not (s is ProjectileEntity):
					continue
				var sticky: ProjectileEntity = s as ProjectileEntity
				if sticky.owner_team != owner_team and sticky.global_position.distance_to(global_position) <= splash_radius:
					sticky.destroy_by_enemy()

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
