class_name StatusEffectsVFX
extends Node3D

## Cartoon VFX spawner (NO blood!): shared cached primitive meshes & materials,
## dirty-state cached hero/vehicle status shaders, foot speed trails, and thematic
## multi-part 3D VFX for all 16 heroic skills and 4 widgets.

const HERO_SHADER: Shader = preload("res://vfx_shaders/hero_cel_shader.gdshader")
const HERO_CLOAK_SHADER: Shader = preload("res://vfx_shaders/hero_cloak_shader.gdshader")
const XRAY_SHADER: Shader = preload("res://vfx_shaders/xray_silhouette.gdshader")

const MAX_OVERHEAD_BUFF_SLOTS: int = 6
const BUFF_ICON_TABLE: Array[Array] = [
	[NetSerializer.BUFF_HERO_SHIELD, "icon_skill_1_0"],
	[NetSerializer.BUFF_LEG_IT, "icon_skill_1_1"],
	[NetSerializer.BUFF_ELIXIR, "icon_skill_2_4"],
	[NetSerializer.BUFF_BURNING_BULLETS, "icon_skill_0_1"],
	[NetSerializer.BUFF_POISONED_BLADE, "icon_skill_2_2"],
	[NetSerializer.BUFF_FRENZY_FIRE, "icon_skill_1_3"],
	[NetSerializer.BUFF_PIERCING_SHOT, "icon_skill_2_1"],
	[NetSerializer.BUFF_EAT_GRENADES, "icon_skill_1_4"],
	[NetSerializer.BUFF_SIXTH_SENSE, "icon_skill_0_4"],
	[NetSerializer.BUFF_COMBAT_MED_HOT, "icon_skill_0_0"],
	[NetSerializer.BUFF_BANDAGE, "icon_widget_0"],
	[NetSerializer.BUFF_FIREPROOF, "icon_widget_2"],
	[NetSerializer.BUFF_HASTE, "icon_skill_3_1"],
	[NetSerializer.BUFF_CARRIED_SHIELD, "icon_skill_3_0"],
	[NetSerializer.BUFF_VEHICLE_BUSTER, "icon_skill_3_4"],
	[NetSerializer.BUFF_TNT_ROPE, "icon_skill_3_2"],
	[NetSerializer.BUFF_ENGINEER_INVULN, "icon_skill_4_4"],
	[NetSerializer.BUFF_MARKSMAN_SPRINT, "icon_skill_5_0"],
	[NetSerializer.BUFF_MARKSMAN_UAV, "icon_skill_5_2"],
	[NetSerializer.BUFF_MARKSMAN_LAST_STAND, "icon_skill_5_4"],
]

static var _xray_mat: ShaderMaterial = null
static var _shared_meshes: Dictionary = {}
static var _shared_mats: Dictionary = {}
static var _shared_burst_mats: Dictionary = {}
static var _pool_managers: Dictionary = {}
static var _active_build_previews: Dictionary = {}
static var _active_flame_streams: Dictionary = {}


class VfxPoolEntry extends RefCounted:
	var kind: int = 0 # 0=burst, 1=tracer, 2=flame_jet, 3=flash, 4=mote
	var node: Node3D = null
	var mesh_node: MeshInstance3D = null
	var aux_mesh_node: MeshInstance3D = null
	var elapsed: float = 0.0
	var duration: float = 0.25
	var start_pos: Vector3 = Vector3.ZERO
	var end_pos: Vector3 = Vector3.ZERO
	var start_scale: Vector3 = Vector3.ONE
	var end_scale: Vector3 = Vector3.ONE
	var arc_points: PackedVector3Array = PackedVector3Array()
	var cum_dist: PackedFloat32Array = PackedFloat32Array()
	var start_d: float = 0.0
	var end_d: float = 0.0
	var active: bool = false


class VfxPoolManager extends Node:
	const MAX_BURSTS: int = 64
	const MAX_TRACERS: int = 64
	const MAX_FLASHES: int = 32
	const MAX_MOTES: int = 64

	var _burst_free: Array[VfxPoolEntry] = []
	var _tracer_free: Array[VfxPoolEntry] = []
	var _flash_free: Array[VfxPoolEntry] = []
	var _mote_free: Array[VfxPoolEntry] = []
	var _active: Array[VfxPoolEntry] = []
	var total_created: int = 0
	var total_reused: int = 0
	var parent_id: int = 0

	func _exit_tree() -> void:
		if parent_id != 0 and StatusEffectsVFX._pool_managers.get(parent_id, null) == self:
			StatusEffectsVFX._pool_managers.erase(parent_id)
		clear_all_entries()

	func clear_all_entries() -> void:
		for entry in _active:
			if entry.node != null and is_instance_valid(entry.node):
				entry.node.queue_free()
		for pool in [_burst_free, _tracer_free, _flash_free, _mote_free]:
			for entry in pool:
				if entry.node != null and is_instance_valid(entry.node):
					entry.node.queue_free()
			pool.clear()
		_active.clear()

	func _acquire_entry(pool: Array[VfxPoolEntry], cap: int, kind_id: int, create_fn: Callable) -> VfxPoolEntry:
		var entry: VfxPoolEntry = null
		while not pool.is_empty():
			var cand: VfxPoolEntry = pool.pop_back() as VfxPoolEntry
			if cand != null and cand.node != null and is_instance_valid(cand.node):
				entry = cand
				total_reused += 1
				break
		if entry == null:
			var active_of_kind: int = 0
			var oldest_idx: int = -1
			for idx in range(_active.size()):
				if _active[idx].kind == kind_id:
					active_of_kind += 1
					if oldest_idx < 0:
						oldest_idx = idx
			if active_of_kind >= cap and oldest_idx >= 0:
				entry = _active[oldest_idx]
				_active.remove_at(oldest_idx)
				total_reused += 1
			else:
				entry = create_fn.call() as VfxPoolEntry
				total_created += 1
				var p: Node = get_parent()
				if p != null and entry.node != null and entry.node.get_parent() == null:
					p.add_child(entry.node)
		entry.elapsed = 0.0
		entry.active = true
		if entry.node != null:
			entry.node.visible = true
		_active.append(entry)
		return entry

	func _recycle_entry(entry: VfxPoolEntry) -> void:
		entry.active = false
		if entry.node != null and is_instance_valid(entry.node):
			entry.node.visible = false
		match entry.kind:
			0:
				if _burst_free.size() < MAX_BURSTS:
					_burst_free.append(entry)
				elif entry.node != null and is_instance_valid(entry.node):
					entry.node.queue_free()
			1, 2:
				if _tracer_free.size() < MAX_TRACERS:
					_tracer_free.append(entry)
				elif entry.node != null and is_instance_valid(entry.node):
					entry.node.queue_free()
			3:
				if _flash_free.size() < MAX_FLASHES:
					_flash_free.append(entry)
				elif entry.node != null and is_instance_valid(entry.node):
					entry.node.queue_free()
			_:
				if _mote_free.size() < MAX_MOTES:
					_mote_free.append(entry)
				elif entry.node != null and is_instance_valid(entry.node):
					entry.node.queue_free()

	func _process(delta: float) -> void:
		if _active.is_empty():
			return
		var i: int = _active.size() - 1
		while i >= 0:
			var entry: VfxPoolEntry = _active[i]
			if entry == null or entry.node == null or not is_instance_valid(entry.node):
				_active.remove_at(i)
				i -= 1
				continue
			entry.elapsed += delta
			var dur: float = maxf(0.01, entry.duration)
			var t: float = clampf(entry.elapsed / dur, 0.0, 1.0)
			match entry.kind:
				0: # burst: expand quickly then shrink to zero cleanly (zero material allocation)
					entry.node.position = entry.start_pos.lerp(entry.end_pos, t)
					var env: float = (1.0 - maxf(0.0, (t - 0.55) / 0.45))
					entry.node.scale = entry.start_scale.lerp(entry.end_scale, minf(1.0, t * 1.35)) * maxf(0.02, env)
				1: # curved/straight tracer
					var d: float = lerpf(entry.start_d, entry.end_d, t)
					StatusEffectsVFX._apply_tracer_pose(entry.mesh_node, entry.arc_points, entry.cum_dist, d)
					var fade_s: float = maxf(0.05, 1.0 - maxf(0.0, (t - 0.65) / 0.35))
					entry.mesh_node.scale = Vector3(entry.start_scale.x * fade_s, entry.start_scale.y * fade_s, entry.start_scale.z)
				2: # flame jet
					entry.node.position = entry.start_pos.lerp(entry.end_pos, t)
					var f_fade: float = 1.0 - maxf(0.0, (t - 0.50) / 0.50)
					entry.node.scale = entry.start_scale.lerp(entry.end_scale, t) * maxf(0.05, f_fade)
				3: # muzzle flash
					entry.node.scale = entry.start_scale.lerp(entry.end_scale, t) * maxf(0.05, 1.0 - t * 0.85)
				4: # mote / puff
					entry.node.position = entry.start_pos.lerp(entry.end_pos, t)
					var m_fade: float = 1.0 - maxf(0.0, (t - 0.55) / 0.45)
					entry.node.scale = entry.start_scale.lerp(entry.end_scale, t) * maxf(0.04, m_fade)
			if entry.elapsed >= dur:
				_active.remove_at(i)
				_recycle_entry(entry)
			i -= 1


class BuildPreviewVFX extends Node3D:
	var hero_id: int = -1
	var slot: int = -1
	var duration: float = 2.0
	var elapsed: float = 0.0
	var scaffold: Node3D = null
	var _spark_timer: float = 0.0

	func _process(delta: float) -> void:
		elapsed = minf(duration, elapsed + delta)
		var frac: float = clampf(elapsed / maxf(0.05, duration), 0.0, 1.0)
		if scaffold != null and is_instance_valid(scaffold):
			scaffold.scale = Vector3(1.0, lerpf(0.05, 1.0, frac), 1.0)
		_spark_timer += delta
		if _spark_timer >= 0.22:
			_spark_timer = 0.0
			if not DisplayServer.get_name().contains("headless") and get_parent() != null:
				var spark_pos: Vector3 = global_position + global_transform.basis * Vector3(
					randf_range(-0.9, 0.9),
					lerpf(0.25, 1.6, frac),
					randf_range(-0.6, 0.6)
				)
				StatusEffectsVFX.spawn_cartoon_burst(get_parent(), spark_pos, "spark", 0.35)

	func _exit_tree() -> void:
		if StatusEffectsVFX._active_build_previews.get(hero_id, null) == self:
			StatusEffectsVFX._active_build_previews.erase(hero_id)


class MortarShellArcVFX extends Node3D:
	var origin: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3.ZERO
	var duration: float = 1.25
	var elapsed: float = 0.0
	var peak_lift: float = 22.0
	var _trail_timer: float = 0.0

	func _process(delta: float) -> void:
		var safe_dur: float = maxf(0.1, duration)
		elapsed = minf(safe_dur, elapsed + delta)
		var t: float = clampf(elapsed / safe_dur, 0.0, 1.0)
		var pos: Vector3 = origin.lerp(target, t)
		pos.y += peak_lift * 4.0 * t * (1.0 - t)
		position = pos

		var vel_t: Vector3 = (target - origin) / safe_dur + Vector3.UP * (peak_lift * 4.0 * (1.0 - 2.0 * t) / safe_dur)
		if vel_t.length_squared() > 0.001:
			var fwd: Vector3 = vel_t.normalized()
			var up_hint: Vector3 = Vector3.FORWARD if absf(fwd.y) > 0.96 else Vector3.UP
			var right_v: Vector3 = fwd.cross(up_hint).normalized()
			var up_v: Vector3 = right_v.cross(fwd).normalized()
			basis = Basis(right_v, up_v, -fwd)

		_trail_timer += delta
		if _trail_timer >= 0.045 and t < 0.98:
			_trail_timer = 0.0
			if not DisplayServer.get_name().contains("headless") and get_parent() != null:
				StatusEffectsVFX._spawn_mortar_trail_puff(get_parent(), pos)

		if elapsed >= safe_dur:
			queue_free()


class FlameStreamVFX extends Node3D:
	const TONGUE_COUNT: int = 12
	var hero_id: int = -1
	var duration: float = 0.24
	var elapsed: float = 0.0
	var stream_len: float = 18.0
	var is_fire_starter: bool = false
	var _phase: float = 0.0
	var _tongues: Array[MeshInstance3D] = []
	var _base_angles: PackedFloat32Array = PackedFloat32Array()

	func build_stream(p_len: float, p_fire_starter: bool) -> void:
		stream_len = clampf(p_len, 0.5, 22.0)
		is_fire_starter = p_fire_starter
		if _tongues.is_empty():
			StatusEffectsVFX.warm_shared_meshes()
			var jet_mesh: CylinderMesh = StatusEffectsVFX._get_shared_flame_jet()
			var col_core := Color(0.55, 0.88, 1.0, 0.72) if is_fire_starter else Color(1.0, 0.96, 0.68, 0.72)
			var col_mid := Color(1.0, 0.64, 0.14, 0.62)
			var col_tip := Color(0.96, 0.26, 0.05, 0.46)
			for i in range(TONGUE_COUNT):
				var t: float = float(i) / float(TONGUE_COUNT - 1)
				var col: Color = col_core.lerp(col_mid, t * 2.0) if t < 0.45 else col_mid.lerp(col_tip, (t - 0.45) / 0.55)
				var mi := MeshInstance3D.new()
				mi.mesh = jet_mesh
				mi.material_override = StatusEffectsVFX._get_shared_mat(col, true)
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(mi)
				_tongues.append(mi)
				_base_angles.append(float(i) * 2.39996)
		_refresh_tongues()

	func refresh_stream(p_len: float, p_fire_starter: bool) -> void:
		elapsed = 0.0
		duration = 0.24
		stream_len = clampf(p_len, 0.5, 22.0)
		if p_fire_starter != is_fire_starter and not _tongues.is_empty():
			is_fire_starter = p_fire_starter
			var col_core := Color(0.55, 0.88, 1.0, 0.72) if is_fire_starter else Color(1.0, 0.96, 0.68, 0.72)
			_tongues[0].material_override = StatusEffectsVFX._get_shared_mat(col_core, true)
		_refresh_tongues()

	func _refresh_tongues() -> void:
		var count: int = _tongues.size()
		if count <= 0:
			return
		var seg_h: float = clampf((stream_len / float(count)) * 2.8, 0.95, 3.6)
		var fade: float = clampf((duration - elapsed) / 0.06, 0.0, 1.0)
		for i in range(count):
			var mi: MeshInstance3D = _tongues[i]
			if mi == null or not is_instance_valid(mi):
				continue
			var raw_t: float = fposmod(float(i) / float(count) + _phase * 0.28, 1.0)
			var z_dist: float = raw_t * maxf(0.4, stream_len - seg_h * 0.25) + seg_h * 0.35
			var swirl_ang: float = _base_angles[i] + _phase * 1.4
			var swirl_r: float = lerpf(0.05, 0.52, raw_t) * minf(1.0, stream_len / 6.0)
			var lift_y: float = 0.36 * raw_t * raw_t
			mi.position = Vector3(cos(swirl_ang) * swirl_r, sin(swirl_ang) * swirl_r + lift_y, -z_dist)
			mi.rotation = Vector3(-PI * 0.5, 0.0, swirl_ang)
			var rad: float = lerpf(0.20, 1.18, raw_t) * fade
			mi.scale = Vector3(maxf(0.04, rad), maxf(0.2, seg_h * fade), maxf(0.04, rad))

	func _process(delta: float) -> void:
		elapsed += delta
		_phase += delta * 14.0
		if elapsed >= duration:
			queue_free()
			return
		_refresh_tongues()

	func _exit_tree() -> void:
		if StatusEffectsVFX._active_flame_streams.get(hero_id, null) == self:
			StatusEffectsVFX._active_flame_streams.erase(hero_id)


static func _get_xray_material() -> ShaderMaterial:
	if _xray_mat == null:
		_xray_mat = ShaderMaterial.new()
		_xray_mat.shader = XRAY_SHADER
	return _xray_mat


static func warm_shared_meshes() -> void:
	_get_shared_box()
	_get_shared_sphere()
	_get_shared_cylinder()
	_get_shared_cone()
	_get_shared_flame_jet()
	_get_shared_torus()


static func _get_shared_box() -> BoxMesh:
	if _shared_meshes.has("box"):
		return _shared_meshes["box"] as BoxMesh
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	_shared_meshes["box"] = m
	return m


static func _get_shared_sphere() -> SphereMesh:
	if _shared_meshes.has("sphere"):
		return _shared_meshes["sphere"] as SphereMesh
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	m.rings = 6
	_shared_meshes["sphere"] = m
	return m


static func _get_shared_cylinder() -> CylinderMesh:
	if _shared_meshes.has("cylinder"):
		return _shared_meshes["cylinder"] as CylinderMesh
	var m := CylinderMesh.new()
	m.top_radius = 0.5
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	_shared_meshes["cylinder"] = m
	return m


static func _get_shared_cone() -> CylinderMesh:
	if _shared_meshes.has("cone"):
		return _shared_meshes["cone"] as CylinderMesh
	var m := CylinderMesh.new()
	m.top_radius = 0.01
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 12
	_shared_meshes["cone"] = m
	return m


static func _get_shared_flame_jet() -> CylinderMesh:
	if _shared_meshes.has("flame_jet"):
		return _shared_meshes["flame_jet"] as CylinderMesh
	var m := CylinderMesh.new()
	m.top_radius = 0.46
	m.bottom_radius = 0.14
	m.height = 1.0
	m.radial_segments = 10
	_shared_meshes["flame_jet"] = m
	return m


static func _get_shared_torus() -> TorusMesh:
	if _shared_meshes.has("torus"):
		return _shared_meshes["torus"] as TorusMesh
	var m := TorusMesh.new()
	m.inner_radius = 0.38
	m.outer_radius = 0.50
	m.rings = 16
	m.ring_segments = 8
	_shared_meshes["torus"] = m
	return m


static func _get_shared_mat(col: Color, additive: bool = false) -> StandardMaterial3D:
	var key: String = "%08x_%d" % [col.to_rgba32(), 1 if additive else 0]
	if _shared_mats.has(key):
		return _shared_mats[key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = col
	_shared_mats[key] = mat
	return mat


static func _get_shared_burst_mat(kind: String) -> StandardMaterial3D:
	if _shared_burst_mats.has(kind):
		return _shared_burst_mats[kind] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	match kind:
		"spark":
			mat.albedo_color = Color(1.0, 0.86, 0.2, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.72, 0.1)
		"explosion":
			mat.albedo_color = Color(1.0, 0.45, 0.1, 0.85)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.35, 0.05)
		"heal":
			mat.albedo_color = Color(0.25, 0.95, 0.45, 0.85)
		"smoke":
			mat.albedo_color = Color(0.28, 0.28, 0.30, 0.72)
		"fire":
			mat.albedo_color = Color(1.0, 0.42, 0.08, 0.88)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.32, 0.04)
		"muzzle":
			mat.albedo_color = Color(1.0, 0.72, 0.16, 0.90)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.60, 0.10)
		_:
			mat.albedo_color = Color(0.88, 0.86, 0.8, 0.75)
	_shared_burst_mats[kind] = mat
	return mat


static func get_prewarm_materials() -> Array[Material]:
	warm_shared_meshes()
	var mats: Array[Material] = []
	for k in ["spark", "explosion", "heal", "smoke", "fire", "muzzle", "dust"]:
		mats.append(_get_shared_burst_mat(k))
	mats.append(_get_shared_mat(Color(1.0, 0.86, 0.35, 0.80), true))
	mats.append(_get_shared_mat(Color(1.0, 0.90, 0.32, 0.95), true))
	return mats


static func _get_pool_manager(parent: Node) -> VfxPoolManager:
	if parent == null or not is_instance_valid(parent):
		return null
	var pid: int = parent.get_instance_id()
	var existing: Variant = _pool_managers.get(pid, null)
	if existing is VfxPoolManager and is_instance_valid(existing) and (existing as VfxPoolManager).get_parent() == parent:
		return existing as VfxPoolManager
	var mgr := VfxPoolManager.new()
	mgr.name = "StatusEffectsVFXPool"
	mgr.parent_id = pid
	parent.add_child(mgr)
	_pool_managers[pid] = mgr
	return mgr


static func clear_pools(parent: Node = null) -> void:
	if parent != null:
		var pid: int = parent.get_instance_id()
		var mgr: Variant = _pool_managers.get(pid, null)
		_pool_managers.erase(pid)
		if mgr is VfxPoolManager and is_instance_valid(mgr):
			(mgr as VfxPoolManager).clear_all_entries()
			(mgr as VfxPoolManager).queue_free()
		return
	for pid_key in _pool_managers.keys():
		var m: Variant = _pool_managers[pid_key]
		if m is VfxPoolManager and is_instance_valid(m):
			(m as VfxPoolManager).clear_all_entries()
			(m as VfxPoolManager).queue_free()
	_pool_managers.clear()
	clear_all_flame_streams()


static func _is_beyond_vfx_distance(parent: Node, world_pos: Vector3, max_dist: float = 110.0) -> bool:
	if parent == null or not parent.is_inside_tree() or parent.get_viewport() == null:
		return false
	var cam: Camera3D = parent.get_viewport().get_camera_3d()
	if cam == null:
		return false
	return cam.global_position.distance_squared_to(world_pos) > (max_dist * max_dist)


static func _apply_tracer_pose(tracer: MeshInstance3D, arc_points: PackedVector3Array, cum_dist: PackedFloat32Array, d: float) -> void:
	if tracer == null or not is_instance_valid(tracer) or arc_points.size() < 2 or cum_dist.size() < 2:
		return
	var seg_idx: int = 0
	for i in range(arc_points.size() - 1):
		if d <= cum_dist[i + 1] or i == arc_points.size() - 2:
			seg_idx = i
			break
	var seg_span: float = maxf(0.001, cum_dist[seg_idx + 1] - cum_dist[seg_idx])
	var local_t: float = clampf((d - cum_dist[seg_idx]) / seg_span, 0.0, 1.0)
	var pos: Vector3 = arc_points[seg_idx].lerp(arc_points[seg_idx + 1], local_t)
	var seg_dir: Vector3 = arc_points[seg_idx + 1] - arc_points[seg_idx]
	tracer.position = pos
	if seg_dir.length_squared() > 0.0001:
		var dir_n: Vector3 = seg_dir.normalized()
		if absf(dir_n.dot(Vector3.UP)) < 0.98 and tracer.is_inside_tree():
			tracer.look_at(pos + dir_n, Vector3.UP)


static func _vfx_part(
	parent: Node3D,
	mesh: Mesh,
	mat: Material,
	pos: Vector3,
	scale_v: Vector3,
	rot: Vector3 = Vector3.ZERO,
	fade_list: Array[MeshInstance3D] = []
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	fade_list.append(mi)
	return mi


static func _vfx_plus_cross(
	parent: Node3D,
	mat: Material,
	pos: Vector3,
	size: float,
	thickness: float,
	fade_list: Array[MeshInstance3D] = []
) -> Node3D:
	var cross := Node3D.new()
	cross.position = pos
	parent.add_child(cross)
	var box: BoxMesh = _get_shared_box()
	_vfx_part(cross, box, mat, Vector3.ZERO, Vector3(thickness, size, thickness), Vector3.ZERO, fade_list)
	_vfx_part(cross, box, mat, Vector3.ZERO, Vector3(size, thickness, thickness), Vector3.ZERO, fade_list)
	return cross


static func _collect_active_buff_icon_keys(hero: HeroCharacter, stealthed: bool, is_enemy: bool) -> Array[String]:
	var keys: Array[String] = []
	for entry in BUFF_ICON_TABLE:
		var bit: int = int(entry[0])
		if (hero.active_buffs & bit) != 0:
			keys.append(str(entry[1]))
			if keys.size() >= MAX_OVERHEAD_BUFF_SLOTS:
				return keys
	if stealthed and not is_enemy and keys.size() < MAX_OVERHEAD_BUFF_SLOTS:
		keys.append("icon_skill_2_0")
	return keys


static func _update_overhead_buff_icons(hero: HeroCharacter, _stealthed: bool, _is_enemy: bool, _vis: bool) -> void:
	if hero == null:
		return
	var row: Node3D = hero._overhead_buff_row
	if row != null and is_instance_valid(row) and not row.is_queued_for_deletion():
		row.visible = false
	for sp in hero._overhead_buff_slots:
		if is_instance_valid(sp):
			sp.visible = false
			sp.texture = null


static func attach_hero_vfx_and_shader(hero: HeroCharacter) -> void:
	if hero == null:
		return
	hero.apply_character_shader(HERO_SHADER)


static func _is_stealthed_hero_near_enemy(hero: HeroCharacter, local_hero: HeroCharacter, heroes_by_id: Dictionary, detect_r: float) -> bool:
	if hero == null:
		return false
	var h_pos: Vector3 = hero.global_position if hero.is_inside_tree() else hero.position
	var r_sq: float = detect_r * detect_r
	if local_hero != null and is_instance_valid(local_hero) and not local_hero.is_defeated and local_hero.team != hero.team:
		var l_pos: Vector3 = local_hero.global_position if local_hero.is_inside_tree() else local_hero.position
		if h_pos.distance_squared_to(l_pos) <= r_sq:
			return true
	for id_key in heroes_by_id.keys():
		var cand: HeroCharacter = heroes_by_id[id_key] as HeroCharacter
		if cand == null or not is_instance_valid(cand) or cand.is_defeated or cand.team == hero.team:
			continue
		var c_pos: Vector3 = cand.global_position if cand.is_inside_tree() else cand.position
		if h_pos.distance_squared_to(c_pos) <= r_sq:
			return true
	return false


static func update_hero_client_visuals(hero: HeroCharacter, local_hero: HeroCharacter, delta: float, vehicles_by_id: Dictionary = {}, heroes_by_id: Dictionary = {}) -> void:
	if hero == null or hero.visual_root == null:
		return

	var active_fs: Variant = _active_flame_streams.get(hero.entity_id, null)
	if active_fs is FlameStreamVFX and is_instance_valid(active_fs):
		var fs_node := active_fs as FlameStreamVFX
		var cur_w: WeaponBase = hero.weapons[hero.selected_weapon_slot] as WeaponBase if (hero.selected_weapon_slot >= 0 and hero.selected_weapon_slot < hero.weapons.size()) else null
		var holding_continuous_flame: bool = (
			not hero.is_defeated
			and hero.current_vehicle_id < 0
			and cur_w != null
			and cur_w.weapon_kind == WeaponBase.WeaponKind.FLAMETHROWER
			and cur_w.archetype != 2
		)
		if not holding_continuous_flame:
			stop_continuous_flame_stream(hero.entity_id)
		else:
			fs_node.position = hero.get_muzzle_world_position()

	if hero.current_vehicle_id >= 0 and vehicles_by_id.has(hero.current_vehicle_id):
		var v: VehicleBase = vehicles_by_id[hero.current_vehicle_id] as VehicleBase
		if v != null:
			var seat: VehicleBase.SeatSlot = v.get_seat(hero.current_seat_index)
			if seat != null:
				hero.current_seat_enclosed = seat.is_enclosed
				hero.current_seat_pose = seat.seat_pose
				hero.current_seat_can_shoot = seat.can_shoot
	elif hero.current_vehicle_id < 0:
		hero.current_seat_enclosed = false
		hero.current_seat_pose = ""
		hero.current_seat_can_shoot = false

	var hidden_in_vehicle: bool = (hero.current_vehicle_id >= 0 and hero.current_seat_pose == "hidden" and not hero.is_defeated)
	var is_enemy: bool = local_hero != null and hero.team != local_hero.team
	var stealthed: bool = (hero.active_flags & NetSerializer.SNAP_STEALTHED) != 0 or hero.is_stealthed
	var marked_enemy: bool = is_enemy and ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0)
	var sensed_enemy: bool = is_enemy and local_hero != null and StatusEffectContainer.is_enemy_sensed_by_team(hero, local_hero.team, heroes_by_id, local_hero)
	var show_xray: bool = (marked_enemy or sensed_enemy) and not hero.is_defeated
	var cloak_val: float = 0.0
	var vis: bool = true

	if hidden_in_vehicle:
		vis = false
	elif stealthed:
		var detect_r: float = hero.status_effects.stealth_detection_radius if hero.status_effects != null else 10.0
		if is_enemy and local_hero != null:
			var dist_sq: float = hero.global_position.distance_squared_to(local_hero.global_position)
			if marked_enemy or sensed_enemy or dist_sq <= detect_r * detect_r or _is_stealthed_hero_near_enemy(hero, local_hero, heroes_by_id, detect_r):
				vis = not hero.is_scoping
				cloak_val = 0.12
			else:
				vis = false
		else:
			vis = not (hero.is_local_player and hero.is_scoping)
			var revealed_to_enemies: bool = (
				_is_stealthed_hero_near_enemy(hero, local_hero, heroes_by_id, detect_r)
				or ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0)
				or StatusEffectContainer.is_enemy_sensed_by_team(hero, 1 - hero.team, heroes_by_id)
			)
			cloak_val = 0.0 if revealed_to_enemies else 0.55
	else:
		vis = not (hero.is_local_player and hero.is_scoping)
		cloak_val = 0.0

	var is_headless: bool = DisplayServer.get_name().contains("headless")
	var parent_node: Node = hero.get_parent()

	# Rate-limited foot dust/wind puffs when speed-boosted (Leg It / Elixir) and sprinting
	if vis and not hero.is_defeated and hero.current_vehicle_id < 0:
		var is_boosted: bool = (
			((hero.active_flags & NetSerializer.SNAP_SPEED_BOOST) != 0)
			or ((hero.active_buffs & (NetSerializer.BUFF_MARKSMAN_SPRINT | NetSerializer.BUFF_MARKSMAN_LAST_STAND)) != 0)
			or (hero.speed_multiplier > 1.15)
		)
		if is_boosted:
			var horiz_sq: float = hero.velocity.x * hero.velocity.x + hero.velocity.z * hero.velocity.z
			if horiz_sq > 6.25:
				hero._speed_trail_timer -= delta
				if hero._speed_trail_timer <= 0.0:
					hero._speed_trail_timer = 0.18
					if parent_node != null and not is_headless:
						_spawn_foot_speed_puff(parent_node, hero.global_position, hero.aim_yaw)

		# Rate-limited thematic continuous particles matching active buffs (zero extra VFX on Stealth)
		if _has_continuous_particle_buff(hero):
			hero._active_buff_vfx_timer -= delta
			if hero._active_buff_vfx_timer <= 0.0:
				hero._active_buff_vfx_timer = 0.42
				if parent_node != null and not is_headless:
					_spawn_active_buff_tick_vfx(parent_node, hero)

	# Expanding ground radar pulse around Sixth Sense caster (visible on ground around caster)
	if not hero.is_defeated and ((hero.active_flags & NetSerializer.SNAP_SIXTH_SENSE) != 0):
		hero._sixth_sense_pulse_timer -= delta
		if hero._sixth_sense_pulse_timer <= 0.0:
			hero._sixth_sense_pulse_timer = 1.15
			if parent_node != null and not is_headless:
				_spawn_sixth_sense_radar_pulse(parent_node, hero.global_position, StatusEffectContainer.SIXTH_SENSE_RADIUS)

	var burning: bool = (hero.active_flags & NetSerializer.SNAP_BURNING) != 0
	var poisoned: bool = (hero.active_flags & NetSerializer.SNAP_POISONED) != 0
	var shielded: bool = (hero.active_flags & NetSerializer.SNAP_SHIELDED) != 0
	var speed_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_SPEED_BOOST) != 0) else 0
	var eat_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_EAT_GRENADES) != 0) else 0
	var frenzy_flag: int = 1 if ((hero.active_buffs & NetSerializer.BUFF_FRENZY_FIRE) != 0 or (hero.status_effects != null and hero.status_effects.frenzy_timer > 0.0)) else 0
	var pierce_flag: int = 1 if ((hero.active_buffs & NetSerializer.BUFF_PIERCING_SHOT) != 0 or (hero.status_effects != null and hero.status_effects.piercing_timer > 0.0)) else 0
	var stealth_ally_flag: int = 1 if (stealthed and not is_enemy) else 0
	var mark_flag: int = 1 if ((hero.active_flags & NetSerializer.SNAP_MARKED_TARGET) != 0) else 0
	var cloak_q: int = int(roundf(clampf(cloak_val, 0.0, 1.0) * 100.0))

	var state_hash: int = (
		(1 if hero.current_vehicle_id >= 0 else 0)
		| ((0 if vis else 1) << 1)
		| ((1 if hero.is_defeated else 0) << 2)
		| ((1 if show_xray else 0) << 3)
		| ((1 if burning else 0) << 4)
		| ((1 if poisoned else 0) << 5)
		| ((1 if shielded else 0) << 6)
		| ((1 if marked_enemy else 0) << 7)
		| (speed_flag << 8)
		| (eat_flag << 9)
		| (frenzy_flag << 10)
		| (pierce_flag << 11)
		| (stealth_ally_flag << 12)
		| (mark_flag << 13)
		| ((cloak_q & 0x7F) << 14)
		| (hero.active_buffs << 21)
	)

	if state_hash == hero._last_vfx_hash:
		return
	hero._last_vfx_hash = state_hash
	hero._last_vfx_key = String.num_int64(state_hash)
	hero.visual_root.visible = vis
	_update_overhead_buff_icons(hero, stealthed, is_enemy, vis)
	if not vis:
		return

	var target_shader: Shader = HERO_CLOAK_SHADER if cloak_val > 0.01 else HERO_SHADER
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null
	var rim_col := Color(1.0, 0.95, 0.82)
	var rim_str: float = 0.42
	if burning:
		rim_col = Color(1.0, 0.35, 0.05)
		rim_str = 1.8
	elif poisoned:
		rim_col = Color(0.25, 0.95, 0.25)
		rim_str = 1.8
	elif marked_enemy:
		rim_col = Color(1.0, 0.16, 0.12)
		rim_str = 2.0
	elif shielded:
		rim_col = Color(0.25, 0.72, 1.0)
		rim_str = 1.65
	elif eat_flag == 1:
		rim_col = Color(0.32, 1.0, 0.45)
		rim_str = 1.55
	elif frenzy_flag == 1:
		rim_col = Color(1.0, 0.78, 0.18)
		rim_str = 1.45
	elif pierce_flag == 1:
		rim_col = Color(1.0, 0.28, 0.22)
		rim_str = 1.45
	elif (hero.active_buffs & NetSerializer.BUFF_CARRIED_SHIELD) != 0:
		rim_col = Color(0.32, 0.84, 1.0)
		rim_str = 1.45
	elif (hero.active_buffs & NetSerializer.BUFF_ENGINEER_INVULN) != 0:
		rim_col = Color(1.0, 0.88, 0.28)
		rim_str = 1.85
	elif (hero.active_buffs & NetSerializer.BUFF_VEHICLE_BUSTER) != 0:
		rim_col = Color(1.0, 0.42, 0.16)
		rim_str = 1.50
	elif (hero.active_buffs & NetSerializer.BUFF_HASTE) != 0:
		rim_col = Color(1.0, 0.80, 0.20)
		rim_str = 1.45
	elif (hero.active_buffs & NetSerializer.BUFF_TNT_ROPE) != 0:
		rim_col = Color(1.0, 0.38, 0.14)
		rim_str = 1.40
	elif (hero.active_buffs & NetSerializer.BUFF_MARKSMAN_LAST_STAND) != 0:
		rim_col = Color(1.0, 0.25, 0.12)
		rim_str = 1.95
	elif (hero.active_buffs & NetSerializer.BUFF_MARKSMAN_SPRINT) != 0 or speed_flag == 1:
		rim_col = Color(0.72, 1.0, 0.32)
		rim_str = 1.35

	var shader_changed: bool = (hero._last_vfx_shader != target_shader)
	var xray_changed: bool = (hero._last_vfx_xray != xray_ov)
	var cloak_changed: bool = not is_equal_approx(hero._last_vfx_cloak, cloak_val)
	var rim_col_changed: bool = (hero._last_vfx_rim_col != rim_col)
	var rim_str_changed: bool = not is_equal_approx(hero._last_vfx_rim_str, rim_str)

	for part in hero._mesh_parts:
		if not is_instance_valid(part):
			continue
		part.visible = true
		if xray_changed:
			part.material_overlay = xray_ov
		if part.material_override is ShaderMaterial:
			var smat := part.material_override as ShaderMaterial
			if smat.shader != target_shader:
				smat.shader = target_shader
			if shader_changed or cloak_changed:
				smat.set_shader_parameter("cloak_amount", cloak_val)
			if shader_changed or rim_col_changed:
				smat.set_shader_parameter("rim_color", rim_col)
			if shader_changed or rim_str_changed:
				smat.set_shader_parameter("rim_strength", rim_str)

	hero._last_vfx_shader = target_shader
	hero._last_vfx_xray = xray_ov
	hero._last_vfx_cloak = cloak_val
	hero._last_vfx_rim_col = rim_col
	hero._last_vfx_rim_str = rim_str


static func update_vehicle_client_visuals(veh: VehicleBase, local_hero: HeroCharacter, heroes_by_id: Dictionary = {}) -> void:
	if veh == null or veh.is_destroyed or veh._visual_root == null:
		return
	var is_non_ally: bool = local_hero != null and veh.team != local_hero.team
	var is_enemy: bool = local_hero != null and veh.team >= 0 and veh.team != local_hero.team
	var local_senses: bool = is_enemy and StatusEffectContainer.is_pos_sensed_by_team(veh.global_position, local_hero.team, heroes_by_id, local_hero)
	var show_xray: bool = (is_non_ally and veh.is_marked) or local_senses
	var next_xray: int = 1 if show_xray else 0
	var meshes: Array[MeshInstance3D] = veh.get_cached_visual_meshes()
	if next_xray == veh._last_xray_state:
		return
	veh._last_xray_state = next_xray
	var xray_ov: ShaderMaterial = _get_xray_material() if show_xray else null
	for mi in meshes:
		if is_instance_valid(mi):
			mi.material_overlay = xray_ov


static func _spawn_foot_speed_puff(parent: Node, world_pos: Vector3, aim_yaw: float) -> void:
	if _is_beyond_vfx_distance(parent, world_pos, 110.0):
		return
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return
	var entry: VfxPoolEntry = mgr._acquire_entry(mgr._mote_free, mgr.MAX_MOTES, 4, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 4
		var mi := MeshInstance3D.new()
		mi.mesh = _get_shared_sphere()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.node = mi
		e.mesh_node = mi
		return e
	)
	var puff := entry.mesh_node
	puff.mesh = _get_shared_sphere()
	puff.material_override = _get_shared_mat(Color(0.86, 0.88, 0.72, 0.48), false)
	var back_dir := Vector3(sin(aim_yaw), 0.0, cos(aim_yaw))
	var start_p: Vector3 = world_pos + Vector3(0.0, 0.14, 0.0) + back_dir * 0.28
	puff.position = start_p
	puff.scale = Vector3(0.24, 0.16, 0.24)
	entry.start_pos = start_p
	entry.end_pos = start_p + back_dir * 0.45 + Vector3(0.0, 0.18, 0.0)
	entry.start_scale = Vector3(0.24, 0.16, 0.24)
	entry.end_scale = Vector3(0.55, 0.30, 0.55)
	entry.duration = 0.26


static func _has_continuous_particle_buff(hero: HeroCharacter) -> bool:
	const PARTICLE_BUFF_MASK: int = (
		NetSerializer.BUFF_HERO_SHIELD
		| NetSerializer.BUFF_BURNING_BULLETS
		| NetSerializer.BUFF_POISONED_BLADE
		| NetSerializer.BUFF_FRENZY_FIRE
		| NetSerializer.BUFF_PIERCING_SHOT
		| NetSerializer.BUFF_EAT_GRENADES
		| NetSerializer.BUFF_COMBAT_MED_HOT
		| NetSerializer.BUFF_BANDAGE
		| NetSerializer.BUFF_FIREPROOF
		| NetSerializer.BUFF_HASTE
		| NetSerializer.BUFF_CARRIED_SHIELD
		| NetSerializer.BUFF_VEHICLE_BUSTER
		| NetSerializer.BUFF_TNT_ROPE
		| NetSerializer.BUFF_ENGINEER_INVULN
		| NetSerializer.BUFF_MARKSMAN_LAST_STAND
	)
	if (hero.active_buffs & PARTICLE_BUFF_MASK) != 0:
		return true
	const PARTICLE_FLAG_MASK: int = (
		NetSerializer.SNAP_BURNING
		| NetSerializer.SNAP_POISONED
		| NetSerializer.SNAP_SHIELDED
		| NetSerializer.SNAP_EAT_GRENADES
	)
	return (hero.active_flags & PARTICLE_FLAG_MASK) != 0


static func _spawn_rising_mote(
	parent: Node,
	start_pos: Vector3,
	col: Color,
	mote_scale: float,
	rise_y: float = 0.65,
	is_cross: bool = false
) -> void:
	if _is_beyond_vfx_distance(parent, start_pos, 110.0):
		return
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return
	var mat: StandardMaterial3D = _get_shared_mat(col, true)
	var entry: VfxPoolEntry = mgr._acquire_entry(mgr._mote_free, mgr.MAX_MOTES, 4, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 4
		var mi := MeshInstance3D.new()
		mi.mesh = _get_shared_sphere()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var aux := MeshInstance3D.new()
		aux.mesh = _get_shared_box()
		aux.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		aux.visible = false
		mi.add_child(aux)
		e.node = mi
		e.mesh_node = mi
		e.aux_mesh_node = aux
		return e
	)
	var mi := entry.mesh_node
	var aux := entry.aux_mesh_node
	mi.position = start_pos
	mi.material_override = mat
	if is_cross:
		mi.mesh = _get_shared_box()
		mi.scale = Vector3(mote_scale * 0.55, mote_scale * 2.2, mote_scale * 0.55)
		if aux != null:
			aux.visible = true
			aux.material_override = mat
			aux.scale = Vector3(4.0, 0.25, 1.0)
	else:
		mi.mesh = _get_shared_sphere()
		mi.scale = Vector3.ONE * mote_scale
		if aux != null:
			aux.visible = false
	entry.start_pos = start_pos
	entry.end_pos = start_pos + Vector3(randf_range(-0.18, 0.18), rise_y, randf_range(-0.18, 0.18))
	entry.start_scale = mi.scale
	entry.end_scale = mi.scale * 1.45
	entry.duration = 0.45


static func _spawn_active_buff_tick_vfx(parent: Node, hero: HeroCharacter) -> void:
	warm_shared_meshes()
	var base: Vector3 = hero.global_position
	var side_a := Vector3(randf_range(-0.42, 0.42), randf_range(0.75, 1.35), randf_range(-0.42, 0.42))
	var b: int = hero.active_buffs
	var f: int = hero.active_flags

	if (b & (NetSerializer.BUFF_COMBAT_MED_HOT | NetSerializer.BUFF_BANDAGE)) != 0 and parent is Node3D:
		var cross_col := Color(0.28, 0.78, 1.0, 0.90) if (b & NetSerializer.BUFF_BANDAGE) != 0 else Color(0.24, 0.96, 0.52, 0.90)
		_spawn_rising_mote(parent, base + side_a, cross_col, 0.11, 0.75, true)
	elif (b & NetSerializer.BUFF_HERO_SHIELD) != 0 or (f & NetSerializer.SNAP_SHIELDED) != 0:
		_spawn_rising_mote(parent, base + side_a, Color(0.32, 0.76, 1.0, 0.85), 0.12, 0.60, false)

	if (b & NetSerializer.BUFF_BURNING_BULLETS) != 0 or (f & NetSerializer.SNAP_BURNING) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.35, 0.35), 1.05, randf_range(-0.35, 0.35)), Color(1.0, 0.42, 0.08, 0.92), 0.11, 0.65, false)
	elif (b & NetSerializer.BUFF_POISONED_BLADE) != 0 or (f & NetSerializer.SNAP_POISONED) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.35, 0.35), 1.00, randf_range(-0.35, 0.35)), Color(0.28, 0.96, 0.24, 0.88), 0.10, 0.55, false)
	elif (b & NetSerializer.BUFF_EAT_GRENADES) != 0 or (f & NetSerializer.SNAP_EAT_GRENADES) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.4, 0.4), 0.95, randf_range(-0.4, 0.4)), Color(0.32, 1.0, 0.52, 0.86), 0.11, 0.55, false)
	elif (b & NetSerializer.BUFF_FRENZY_FIRE) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.32, 0.32), 1.15, randf_range(-0.32, 0.32)), Color(1.0, 0.82, 0.18, 0.90), 0.10, 0.60, false)
	elif (b & NetSerializer.BUFF_PIERCING_SHOT) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.30, 0.30), 1.15, randf_range(-0.30, 0.30)), Color(1.0, 0.26, 0.22, 0.90), 0.10, 0.60, false)
	elif (b & NetSerializer.BUFF_FIREPROOF) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.38, 0.38), 0.95, randf_range(-0.38, 0.38)), Color(0.95, 0.68, 0.22, 0.82), 0.10, 0.55, false)

	if (b & NetSerializer.BUFF_HASTE) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.36, 0.36), 0.95, randf_range(-0.36, 0.36)), Color(1.0, 0.78, 0.16, 0.92), 0.11, 0.65, false)
	if (b & NetSerializer.BUFF_CARRIED_SHIELD) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.36, 0.36), 1.05, randf_range(-0.36, 0.36)), Color(0.32, 0.86, 1.0, 0.86), 0.10, 0.55, false)
	if (b & NetSerializer.BUFF_VEHICLE_BUSTER) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.34, 0.34), 1.15, randf_range(-0.34, 0.34)), Color(1.0, 0.34, 0.14, 0.92), 0.12, 0.65, false)
	if (b & NetSerializer.BUFF_TNT_ROPE) != 0:
		_spawn_rising_mote(parent, base + Vector3(0.24, 1.18, -0.22), Color(1.0, 0.58, 0.14, 0.92), 0.10, 0.50, false)
	if (b & NetSerializer.BUFF_ENGINEER_INVULN) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.42, 0.42), 1.05, randf_range(-0.42, 0.42)), Color(1.0, 0.86, 0.28, 0.94), 0.12, 0.55, false)
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.36, 0.36), 1.25, randf_range(-0.36, 0.36)), Color(0.32, 0.94, 1.0, 0.92), 0.10, 0.50, false)
	if (b & NetSerializer.BUFF_MARKSMAN_LAST_STAND) != 0:
		_spawn_rising_mote(parent, base + Vector3(randf_range(-0.38, 0.38), 1.05, randf_range(-0.38, 0.38)), Color(1.0, 0.28, 0.14, 0.94), 0.12, 0.65, false)


static func _spawn_sixth_sense_radar_pulse(parent: Node, origin: Vector3, radius: float) -> void:
	warm_shared_meshes()
	var pulse := MeshInstance3D.new()
	pulse.mesh = _get_shared_torus()
	pulse.material_override = _get_shared_mat(Color(1.0, 0.78, 0.18, 0.55), true)
	pulse.position = origin + Vector3(0.0, 0.18, 0.0)
	pulse.scale = Vector3(1.2, 0.35, 1.2)
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pulse)
	if pulse.is_inside_tree():
		var target_scale: float = clampf(radius * 2.0, 12.0, 110.0)
		var tw: Tween = pulse.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pulse, "scale", Vector3(target_scale, 0.35, target_scale), 0.95)
		tw.tween_property(pulse, "transparency", 1.0, 0.95)
		tw.chain().tween_callback(pulse.queue_free)


static func spawn_cartoon_burst(parent: Node, world_pos: Vector3, kind: String, radius: float = 1.0, force_in_headless: bool = false) -> void:
	if parent == null or (not force_in_headless and DisplayServer.get_name().contains("headless")):
		return
	var cull_dist: float = 220.0 if kind == "explosion" else 110.0
	if _is_beyond_vfx_distance(parent, world_pos, cull_dist):
		return
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return
	var base_r: float = 0.28 if kind != "explosion" else clampf(radius * 0.45, 0.8, 3.5)
	if kind == "smoke":
		base_r = clampf(0.35 * radius, 0.25, 1.2)
	elif kind == "fire":
		base_r = clampf(0.28 * radius, 0.2, 0.9)

	var entry: VfxPoolEntry = mgr._acquire_entry(mgr._burst_free, mgr.MAX_BURSTS, 0, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 0
		var mi := MeshInstance3D.new()
		mi.mesh = _get_shared_sphere()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.node = mi
		e.mesh_node = mi
		return e
	)
	var burst := entry.mesh_node
	burst.material_override = _get_shared_burst_mat(kind)
	var diam: float = base_r * 2.0
	var is_plume: bool = (kind == "smoke" or kind == "fire")
	burst.scale = Vector3.ONE * diam
	burst.position = world_pos
	entry.start_pos = world_pos
	entry.end_pos = (world_pos + Vector3(randf_range(-0.3, 0.3), 2.4, randf_range(-0.3, 0.3))) if is_plume else world_pos
	entry.start_scale = Vector3.ONE * diam
	entry.end_scale = Vector3.ONE * (diam * (2.2 if is_plume else 1.8))
	entry.duration = 0.55 if is_plume else 0.26


static func spawn_muzzle_flash(parent: Node, world_pos: Vector3, aim_dir: Vector3, weapon_kind: int, force_in_headless: bool = false) -> void:
	if parent == null or (not force_in_headless and DisplayServer.get_name().contains("headless")):
		return
	if weapon_kind == 5 or weapon_kind == 7 or weapon_kind == 10:
		return
	if _is_beyond_vfx_distance(parent, world_pos, 110.0):
		return
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return

	var base_r: float = 0.16 if weapon_kind == 6 or weapon_kind == 2 else (0.14 if (weapon_kind == 4 or weapon_kind == 13) else 0.10)
	var flash_col := Color(0.34, 0.94, 1.0, 0.95) if weapon_kind == 13 else Color(1.0, 0.90, 0.32, 0.95)
	var mat: StandardMaterial3D = _get_shared_mat(flash_col, true)

	var entry: VfxPoolEntry = mgr._acquire_entry(mgr._flash_free, mgr.MAX_FLASHES, 3, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 3
		var root := Node3D.new()
		var core := MeshInstance3D.new()
		core.name = "Core"
		core.mesh = _get_shared_sphere()
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(core)
		var streak := MeshInstance3D.new()
		streak.name = "Streak"
		streak.mesh = _get_shared_cone()
		streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		streak.rotation.x = -PI * 0.5
		root.add_child(streak)
		e.node = root
		e.mesh_node = core
		e.aux_mesh_node = streak
		return e
	)
	var flash_root := entry.node
	flash_root.position = world_pos
	flash_root.scale = Vector3.ONE
	var core := entry.mesh_node
	core.scale = Vector3.ONE * (base_r * 2.0)
	core.material_override = mat
	var streak := entry.aux_mesh_node
	streak.scale = Vector3(base_r * 1.7, base_r * 3.4, base_r * 1.7)
	streak.material_override = mat
	streak.position.z = -base_r * 1.5
	var dir_n: Vector3 = aim_dir.normalized() if aim_dir.length_squared() > 0.001 else Vector3.FORWARD
	if absf(dir_n.dot(Vector3.UP)) < 0.98 and flash_root.is_inside_tree():
		flash_root.look_at(world_pos + dir_n, Vector3.UP)
	entry.start_scale = Vector3.ONE
	entry.end_scale = Vector3.ONE * 1.55
	entry.duration = 0.07


static func spawn_curved_tracer(parent: Node, arc_points: PackedVector3Array, weapon_kind: int, force_in_headless: bool = false) -> void:
	if parent == null or (not force_in_headless and DisplayServer.get_name().contains("headless")):
		return
	if weapon_kind == 5 or weapon_kind == 6 or weapon_kind == 7 or weapon_kind == 9 or weapon_kind == 10:
		return
	if arc_points.size() < 2:
		return
	var start_p: Vector3 = arc_points[0]
	var end_p: Vector3 = arc_points[arc_points.size() - 1]
	if _is_beyond_vfx_distance(parent, start_p, 110.0) and _is_beyond_vfx_distance(parent, end_p, 110.0):
		return
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return
	if weapon_kind == 8:
		return

	var cum_dist := PackedFloat32Array()
	cum_dist.resize(arc_points.size())
	cum_dist[0] = 0.0
	var total_len: float = 0.0
	for i in range(1, arc_points.size()):
		total_len += arc_points[i - 1].distance_to(arc_points[i])
		cum_dist[i] = total_len
	if total_len < 0.6:
		return

	var seg_len: float = clampf(total_len * 0.25, 1.2, 9.0 if weapon_kind == 4 else 5.5)
	var thick: float = 0.044 if weapon_kind == 13 else (0.036 if weapon_kind == 4 else 0.024)
	var col := Color(0.34, 0.94, 1.0, 0.94) if weapon_kind == 13 else (Color(1.0, 0.94, 0.58, 0.88) if weapon_kind == 4 else Color(1.0, 0.86, 0.35, 0.80))

	var t_entry: VfxPoolEntry = mgr._acquire_entry(mgr._tracer_free, mgr.MAX_TRACERS, 1, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 1
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.node = mi
		e.mesh_node = mi
		return e
	)
	t_entry.kind = 1
	var tracer := t_entry.mesh_node
	tracer.mesh = _get_shared_box()
	tracer.basis = Basis.IDENTITY
	tracer.scale = Vector3(thick, thick, seg_len)
	tracer.material_override = _get_shared_mat(col, true)
	t_entry.start_scale = Vector3(thick, thick, seg_len)
	t_entry.arc_points = arc_points
	t_entry.cum_dist = cum_dist
	t_entry.start_d = minf(total_len * 0.5, seg_len * 0.5 + 0.15)
	t_entry.end_d = maxf(t_entry.start_d, total_len - minf(total_len * 0.12, seg_len * 0.35))
	t_entry.duration = clampf(total_len / 300.0, 0.055, 0.36)
	_apply_tracer_pose(tracer, arc_points, cum_dist, t_entry.start_d)


static func spawn_bullet_tracer(parent: Node, start_pos: Vector3, end_pos: Vector3, weapon_kind: int) -> void:
	spawn_curved_tracer(parent, PackedVector3Array([start_pos, end_pos]), weapon_kind)


## Spawns unmistakable thematic multi-part 3D VFX for every one of the 16 heroic skills and 4 widgets.
static func spawn_skill_vfx(parent: Node, class_id: int, slot_idx: int, world_pos: Vector3, aim_yaw: float = 0.0) -> void:
	if parent == null:
		return
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "SkillVFX_%d_%d" % [class_id, slot_idx]
	root.position = world_pos
	root.rotation.y = aim_yaw
	parent.add_child(root)

	var box: BoxMesh = _get_shared_box()
	var sph: SphereMesh = _get_shared_sphere()
	var cyl: CylinderMesh = _get_shared_cylinder()
	var cone: CylinderMesh = _get_shared_cone()
	var torus: TorusMesh = _get_shared_torus()
	var fade_meshes: Array[MeshInstance3D] = []
	var dur: float = 0.55

	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	if slot_idx >= 100:
		match slot_idx - 100:
			0: # Bandages: 4 glowing cyan/light-blue + crosses floating upward
				dur = 0.65
				var mat_band := _get_shared_mat(Color(0.32, 0.90, 1.0, 0.92), true)
				var offsets: Array[Vector3] = [
					Vector3(-0.48, 0.85, -0.25), Vector3(0.46, 0.95, 0.22),
					Vector3(0.05, 1.10, -0.45), Vector3(-0.22, 0.78, 0.42),
				]
				for idx in range(offsets.size()):
					var c: Node3D = _vfx_plus_cross(root, mat_band, offsets[idx], 0.34, 0.10, fade_meshes)
					if tw != null:
						tw.tween_property(c, "position", offsets[idx] + Vector3(0.0, 0.95 + float(idx) * 0.14, 0.0), dur)
						tw.tween_property(c, "rotation:y", PI * 0.75, dur)
			1: # Wrench: metallic spark burst + floating yellow-gold + repair cross
				dur = 0.50
				var mat_gold := _get_shared_mat(Color(1.0, 0.84, 0.20, 0.95), true)
				var mat_silv := _get_shared_mat(Color(0.86, 0.92, 1.0, 0.92), true)
				var repair_c: Node3D = _vfx_plus_cross(root, mat_gold, Vector3(0.0, 1.15, -0.40), 0.42, 0.12, fade_meshes)
				if tw != null:
					tw.tween_property(repair_c, "position", Vector3(0.0, 1.85, -0.45), dur)
					tw.tween_property(repair_c, "rotation:y", PI, dur)
				for s_i in range(4):
					var ang: float = float(s_i) * (TAU / 4.0) + 0.4
					var sp := _vfx_part(root, box, mat_silv, Vector3(0.0, 1.15, -0.40), Vector3(0.07, 0.32, 0.07), Vector3(0.4, ang, 0.7), fade_meshes)
					if tw != null:
						tw.tween_property(sp, "position", Vector3(cos(ang) * 0.65, 1.45, -0.45 + sin(ang) * 0.65), dur)
			2: # Fireproof Underwear: cooling ice-blue protective plates + mist ring
				dur = 0.60
				var mat_ice := _get_shared_mat(Color(0.32, 0.80, 1.0, 0.78), false)
				var mat_mist := _get_shared_mat(Color(0.55, 0.92, 1.0, 0.72), true)
				var ring := _vfx_part(root, torus, mat_mist, Vector3(0.0, 1.05, 0.0), Vector3(1.4, 0.9, 1.4), Vector3.ZERO, fade_meshes)
				if tw != null:
					tw.tween_property(ring, "scale", Vector3(2.4, 1.2, 2.4), dur)
					tw.tween_property(ring, "position:y", 1.55, dur)
				for p_i in range(4):
					var a: float = float(p_i) * (TAU * 0.25)
					var plate := _vfx_part(root, box, mat_ice, Vector3(cos(a) * 0.62, 1.08, sin(a) * 0.62), Vector3(0.42, 0.56, 0.08), Vector3(0.0, -a + PI * 0.5, 0.0), fade_meshes)
					if tw != null:
						tw.tween_property(plate, "position", Vector3(cos(a) * 0.92, 1.42, sin(a) * 0.92), dur)
			_: # Antidote: emerald-green cleansing + crosses & detox droplets
				dur = 0.62
				var mat_ant := _get_shared_mat(Color(0.22, 1.0, 0.56, 0.92), true)
				var mat_drop := _get_shared_mat(Color(0.45, 1.0, 0.68, 0.85), false)
				for i in range(3):
					var ang: float = float(i) * (TAU / 3.0)
					var pos0 := Vector3(cos(ang) * 0.45, 0.75 + float(i) * 0.12, sin(ang) * 0.45)
					var ac: Node3D = _vfx_plus_cross(root, mat_ant, pos0, 0.32, 0.09, fade_meshes)
					var dr := _vfx_part(root, sph, mat_drop, pos0 * 0.75 + Vector3(0.0, 0.2, 0.0), Vector3(0.14, 0.20, 0.14), Vector3.ZERO, fade_meshes)
					if tw != null:
						tw.tween_property(ac, "position", pos0 + Vector3(0.0, 1.15, 0.0), dur)
						tw.tween_property(dr, "position", pos0 + Vector3(0.0, 1.40, 0.0), dur)
	else:
		match class_id:
			NetworkManager.CLASS_SOLDIER:
				match slot_idx:
					0: # Combat Medicine: expanding emerald-cyan ground aura ring + 5 rising + crosses
						dur = 0.72
						var mat_heal := _get_shared_mat(Color(0.22, 0.98, 0.62, 0.92), true)
						var mat_aura := _get_shared_mat(Color(0.20, 0.94, 0.78, 0.78), true)
						var aura := _vfx_part(root, torus, mat_aura, Vector3(0.0, 0.08, 0.0), Vector3(1.2, 0.7, 1.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(aura, "scale", Vector3(6.8, 0.7, 6.8), dur)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var r_off: float = 0.85 if (i % 2 == 0) else 1.35
							var p0 := Vector3(cos(a) * r_off, 0.45 + float(i) * 0.1, sin(a) * r_off)
							var hc: Node3D = _vfx_plus_cross(root, mat_heal, p0, 0.36, 0.10, fade_meshes)
							if tw != null:
								tw.tween_property(hc, "position", p0 + Vector3(0.0, 1.55, 0.0), dur)
								tw.tween_property(hc, "rotation:y", PI, dur)
					1: # Burning Bullets: swirling fiery orange/yellow flame embers & hot muzzle sparks
						dur = 0.52
						var mat_flame := _get_shared_mat(Color(1.0, 0.44, 0.06, 0.95), true)
						var mat_spark := _get_shared_mat(Color(1.0, 0.88, 0.22, 0.96), true)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.42, 0.95 + float(i) * 0.12, -0.18 + sin(a) * 0.42)
							var em := _vfx_part(root, sph if (i % 2 == 0) else box, mat_flame if (i % 2 == 0) else mat_spark, p0, Vector3(0.16, 0.26, 0.16), Vector3(0.3, a, 0.4), fade_meshes)
							if tw != null:
								tw.tween_property(em, "position", Vector3(cos(a + 1.8) * 0.62, 2.05, -0.30 + sin(a + 1.8) * 0.62), dur)
					2: # Grenade Spam: arcing fiery-orange fuse sparks & 3 forward lobbing streaks
						dur = 0.50
						var mat_fuse := _get_shared_mat(Color(1.0, 0.58, 0.10, 0.94), true)
						var mat_strk := _get_shared_mat(Color(1.0, 0.34, 0.06, 0.88), true)
						for i in range(3):
							var spread_x: float = (float(i) - 1.0) * 0.38
							var p0 := Vector3(spread_x * 0.4, 1.35, -0.35)
							var stk := _vfx_part(root, box, mat_strk, p0, Vector3(0.08, 0.08, 0.75), Vector3(-0.35, -spread_x * 0.5, 0.0), fade_meshes)
							var fsp := _vfx_part(root, sph, mat_fuse, p0 + Vector3(0.0, 0.08, -0.25), Vector3(0.18, 0.18, 0.18), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position", Vector3(spread_x * 1.4, 1.65, -2.4), dur)
								tw.tween_property(fsp, "position", Vector3(spread_x * 1.6, 1.85, -2.8), dur)
					3: # Blasting Strike: wide forward golden-orange sonic shock-cone + ground dust blast rings
						dur = 0.52
						var mat_cone := _get_shared_mat(Color(1.0, 0.62, 0.14, 0.78), true)
						var mat_ring := _get_shared_mat(Color(0.95, 0.78, 0.46, 0.68), false)
						var shock_cone := _vfx_part(root, cone, mat_cone, Vector3(0.0, 1.15, -1.2), Vector3(1.2, 1.8, 1.2), Vector3(-PI * 0.5, 0.0, 0.0), fade_meshes)
						var ring1 := _vfx_part(root, torus, mat_ring, Vector3(0.0, 0.10, -0.6), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, fade_meshes)
						var ring2 := _vfx_part(root, torus, mat_cone, Vector3(0.0, 0.16, -1.0), Vector3(0.9, 0.9, 0.9), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(shock_cone, "scale", Vector3(4.2, 4.6, 3.2), dur)
							tw.tween_property(shock_cone, "position:z", -3.2, dur)
							tw.tween_property(ring1, "scale", Vector3(6.4, 0.9, 6.4), dur)
							tw.tween_property(ring2, "scale", Vector3(5.2, 1.1, 5.2), dur)
					_: # Sixth Sense: golden overhead radar sweep arc + 2 expanding sonar pulse rings
						dur = 0.62
						var mat_rad := _get_shared_mat(Color(1.0, 0.88, 0.20, 0.92), true)
						var sweep_pivot := Node3D.new()
						sweep_pivot.position = Vector3(0.0, 2.05, 0.0)
						root.add_child(sweep_pivot)
						_vfx_part(sweep_pivot, box, mat_rad, Vector3(0.32, 0.0, -0.55), Vector3(0.08, 0.05, 1.25), Vector3(0.0, -0.45, 0.0), fade_meshes)
						_vfx_part(sweep_pivot, box, mat_rad, Vector3(-0.32, 0.0, -0.55), Vector3(0.08, 0.05, 1.25), Vector3(0.0, 0.45, 0.0), fade_meshes)
						var r_in := _vfx_part(root, torus, mat_rad, Vector3(0.0, 2.02, 0.0), Vector3(0.6, 0.7, 0.6), Vector3.ZERO, fade_meshes)
						var r_out := _vfx_part(root, torus, mat_rad, Vector3(0.0, 2.02, 0.0), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(sweep_pivot, "rotation:y", TAU, dur)
							tw.tween_property(r_in, "scale", Vector3(4.2, 0.7, 4.2), dur)
							tw.tween_property(r_out, "scale", Vector3(6.5, 0.7, 6.5), dur)

			NetworkManager.CLASS_GUNNER:
				match slot_idx:
					0: # Hero Shield: translucent cyan energy shield dome + 4 vertical ribs + belt ring
						dur = 0.60
						var mat_dome := _get_shared_mat(Color(0.22, 0.74, 1.0, 0.36), false)
						var mat_rib := _get_shared_mat(Color(0.35, 0.92, 1.0, 0.88), true)
						var dome := _vfx_part(root, sph, mat_dome, Vector3(0.0, 1.05, 0.0), Vector3(1.2, 1.4, 1.2), Vector3.ZERO, fade_meshes)
						var belt := _vfx_part(root, torus, mat_rib, Vector3(0.0, 1.05, 0.0), Vector3(1.4, 0.8, 1.4), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(dome, "scale", Vector3(2.3, 2.4, 2.3), dur)
							tw.tween_property(belt, "scale", Vector3(2.6, 0.8, 2.6), dur)
						for r_i in range(4):
							var a: float = float(r_i) * (TAU * 0.25)
							var rib := _vfx_part(root, box, mat_rib, Vector3(cos(a) * 0.68, 1.05, sin(a) * 0.68), Vector3(0.08, 1.2, 0.08), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(rib, "position", Vector3(cos(a) * 1.22, 1.05, sin(a) * 1.22), dur)
					1: # Leg It: backward-kicking movement wind streaks & light-tan dust puffs at feet
						dur = 0.54
						var mat_wind := _get_shared_mat(Color(0.45, 0.95, 1.0, 0.86), true)
						var mat_dust := _get_shared_mat(Color(0.84, 0.78, 0.64, 0.72), false)
						for i in range(4):
							var side_x: float = (float(i) - 1.5) * 0.36
							var stk := _vfx_part(root, box, mat_wind, Vector3(side_x, 0.18 + (i % 2) * 0.14, 0.25), Vector3(0.06, 0.06, 0.75), Vector3.ZERO, fade_meshes)
							var puff := _vfx_part(root, sph, mat_dust, Vector3(side_x * 0.85, 0.14, 0.15), Vector3(0.28, 0.18, 0.28), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.65, dur)
								tw.tween_property(puff, "position", Vector3(side_x * 1.1, 0.34, 1.15), dur)
								tw.tween_property(puff, "scale", Vector3(0.55, 0.35, 0.55), dur)
					2: # Explosive Keg: overhead warning orange/red stripe burst + launch dust flash
						dur = 0.52
						var mat_warn := _get_shared_mat(Color(1.0, 0.28, 0.10, 0.92), true)
						var mat_flash := _get_shared_mat(Color(0.95, 0.74, 0.38, 0.82), false)
						_vfx_part(root, box, mat_warn, Vector3(0.0, 1.88, -0.15), Vector3(0.65, 0.10, 0.10), Vector3(0.0, 0.0, 0.78), fade_meshes)
						_vfx_part(root, box, mat_warn, Vector3(0.0, 1.88, -0.15), Vector3(0.65, 0.10, 0.10), Vector3(0.0, 0.0, -0.78), fade_meshes)
						var fl1 := _vfx_part(root, sph, mat_flash, Vector3(-0.35, 1.35, -0.55), Vector3(0.32, 0.32, 0.32), Vector3.ZERO, fade_meshes)
						var fl2 := _vfx_part(root, sph, mat_flash, Vector3(0.35, 1.35, -0.55), Vector3(0.32, 0.32, 0.32), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(fl1, "position", Vector3(-0.75, 1.75, -1.65), dur)
							tw.tween_property(fl2, "position", Vector3(0.75, 1.75, -1.65), dur)
					3: # Frenzy Fire: rising golden-amber rapid-fire chevrons / hot brass flash bars
						dur = 0.50
						var mat_frz := _get_shared_mat(Color(1.0, 0.80, 0.18, 0.94), true)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.45, 0.85 + float(i) * 0.08, -0.25 + sin(a) * 0.45)
							var bar := _vfx_part(root, box, mat_frz, p0, Vector3(0.10, 0.36, 0.10), Vector3(0.25, a, 0.35), fade_meshes)
							if tw != null:
								tw.tween_property(bar, "position", p0 + Vector3(0.0, 1.25, -0.25), dur)
					_: # I Eat Grenades: inward-pulling green absorption chevrons & shrinking chomp pulse ring
						dur = 0.55
						var mat_eat := _get_shared_mat(Color(0.32, 1.0, 0.42, 0.92), true)
						var chomp_ring := _vfx_part(root, torus, mat_eat, Vector3(0.0, 1.15, 0.0), Vector3(2.2, 0.9, 2.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(chomp_ring, "scale", Vector3(0.25, 0.7, 0.25), dur)
						for i in range(4):
							var a: float = float(i) * (TAU * 0.25)
							var p_out := Vector3(cos(a) * 1.45, 1.15, sin(a) * 1.45)
							var chev := _vfx_part(root, box, mat_eat, p_out, Vector3(0.28, 0.10, 0.10), Vector3(0.0, -a, 0.45), fade_meshes)
							if tw != null:
								tw.tween_property(chev, "position", Vector3(cos(a) * 0.18, 1.15, sin(a) * 0.18), dur)

			_: # Commando
				match slot_idx:
					0: # Stealth: swirling smoky blue-grey shadow wisps + expanding veil ring
						dur = 0.58
						var mat_smk := _get_shared_mat(Color(0.62, 0.74, 0.88, 0.58), false)
						var veil_ring := _vfx_part(root, torus, mat_smk, Vector3(0.0, 0.12, 0.0), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						var swirl := Node3D.new()
						root.add_child(swirl)
						for i in range(5):
							var a: float = float(i) * (TAU / 5.0)
							var p0 := Vector3(cos(a) * 0.52, 0.45 + float(i) * 0.20, sin(a) * 0.52)
							var wisp := _vfx_part(swirl, sph, mat_smk, p0, Vector3(0.34, 0.24, 0.34), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(wisp, "position:y", p0.y + 0.95, dur)
								tw.tween_property(wisp, "scale", Vector3(0.58, 0.40, 0.58), dur)
						if tw != null:
							tw.tween_property(veil_ring, "scale", Vector3(2.4, 0.7, 2.4), dur)
							tw.tween_property(swirl, "rotation:y", PI * 1.5, dur)
					1: # Piercing Shot: crimson-gold 6m rail beam along -Z + muzzle shock ring
						dur = 0.44
						var mat_rail := _get_shared_mat(Color(1.0, 0.22, 0.18, 0.92), true)
						var mat_core := _get_shared_mat(Color(1.0, 0.88, 0.35, 0.96), true)
						var beam := _vfx_part(root, cyl, mat_rail, Vector3(0.0, 1.35, -3.35), Vector3(0.14, 6.0, 0.14), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var core := _vfx_part(root, cyl, mat_core, Vector3(0.0, 1.35, -3.35), Vector3(0.06, 6.0, 0.06), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var m_ring := _vfx_part(root, torus, mat_core, Vector3(0.0, 1.35, -0.55), Vector3(0.45, 0.6, 0.45), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						if tw != null:
							tw.tween_property(beam, "scale", Vector3(0.04, 6.4, 0.04), dur)
							tw.tween_property(core, "scale", Vector3(0.02, 6.4, 0.02), dur)
							tw.tween_property(m_ring, "scale", Vector3(1.65, 0.6, 1.65), dur)
					2: # Poisoned Blade: toxic neon-green venom droplets & dagger slash arc
						dur = 0.52
						var mat_ven := _get_shared_mat(Color(0.24, 1.0, 0.26, 0.92), true)
						var slash := _vfx_part(root, box, mat_ven, Vector3(0.0, 1.12, -0.55), Vector3(0.85, 0.08, 0.14), Vector3(0.0, 0.2, 0.35), fade_meshes)
						if tw != null:
							tw.tween_property(slash, "rotation:z", -0.65, dur)
							tw.tween_property(slash, "position:z", -0.85, dur)
						for i in range(4):
							var a: float = float(i) * (TAU * 0.25) + 0.3
							var drop := _vfx_part(root, sph, mat_ven, Vector3(cos(a) * 0.38, 1.10, -0.45 + sin(a) * 0.38), Vector3(0.14, 0.18, 0.14), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(drop, "position", Vector3(cos(a) * 0.65, 0.72, -0.55 + sin(a) * 0.65), dur)
					3: # Troop Trap: ground hazard X-prongs + amber arming beam snapping into floor
						dur = 0.56
						var mat_trap := _get_shared_mat(Color(0.95, 0.68, 0.18, 0.92), true)
						var mat_floor := _get_shared_mat(Color(0.92, 0.45, 0.12, 0.82), false)
						_vfx_part(root, box, mat_floor, Vector3(0.0, 0.08, -0.2), Vector3(0.95, 0.06, 0.12), Vector3(0.0, 0.78, 0.0), fade_meshes)
						_vfx_part(root, box, mat_floor, Vector3(0.0, 0.08, -0.2), Vector3(0.95, 0.06, 0.12), Vector3(0.0, -0.78, 0.0), fade_meshes)
						var arm_beam := _vfx_part(root, cyl, mat_trap, Vector3(0.0, 0.85, -0.2), Vector3(0.12, 1.2, 0.12), Vector3.ZERO, fade_meshes)
						var ring_t := _vfx_part(root, torus, mat_trap, Vector3(0.0, 0.06, -0.2), Vector3(1.1, 0.7, 1.1), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(arm_beam, "position:y", 0.15, dur * 0.65)
							tw.tween_property(arm_beam, "scale:y", 0.15, dur * 0.65)
							tw.tween_property(ring_t, "scale", Vector3(2.2, 0.7, 2.2), dur)
					4: # Elixir: bright lime-gold speed wind streaks & foot dust puffs + adrenaline trail
						dur = 0.54
						var mat_elx := _get_shared_mat(Color(0.74, 1.0, 0.24, 0.94), true)
						var mat_edust := _get_shared_mat(Color(0.86, 0.82, 0.64, 0.72), false)
						for i in range(4):
							var sx: float = (float(i) - 1.5) * 0.34
							var stk := _vfx_part(root, box, mat_elx, Vector3(sx, 0.18 + (i % 2) * 0.14, 0.25), Vector3(0.06, 0.06, 0.75), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.70, dur)
						for j in range(3):
							var dx: float = (float(j) - 1.0) * 0.38
							var dp := _vfx_part(root, sph, mat_edust, Vector3(dx, 0.14, 0.18), Vector3(0.26, 0.18, 0.26), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(dp, "position", Vector3(dx * 1.2, 0.35, 1.15), dur)
						var adr := _vfx_part(root, box, mat_elx, Vector3(0.0, 0.75, 0.0), Vector3(0.10, 0.65, 0.10), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(adr, "position:y", 1.95, dur)
					_: # Mark Target: tactical red laser designator beam + overhead crimson target diamond
						dur = 0.65
						var mat_red := _get_shared_mat(Color(1.0, 0.16, 0.16, 0.94), true)
						var beam := _vfx_part(root, cyl, mat_red, Vector3(0.0, 1.48, -4.35), Vector3(0.07, 8.0, 0.07), Vector3(PI * 0.5, 0.0, 0.0), fade_meshes)
						var diam_pivot := Node3D.new()
						diam_pivot.position = Vector3(0.0, 2.30, 0.0)
						root.add_child(diam_pivot)
						_vfx_part(diam_pivot, cone, mat_red, Vector3(0.0, -0.18, 0.0), Vector3(0.42, 0.42, 0.42), Vector3(PI, 0.0, 0.0), fade_meshes)
						_vfx_part(diam_pivot, cone, mat_red, Vector3(0.0, 0.18, 0.0), Vector3(0.42, 0.26, 0.42), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(beam, "scale", Vector3(0.02, 9.5, 0.02), dur)
							tw.tween_property(diam_pivot, "rotation:y", TAU, dur)
							tw.tween_property(diam_pivot, "position:y", 2.55, dur)

			NetworkManager.CLASS_DEMOLISHER:
				match slot_idx:
					0: # Escudo Balístico (Em Mãos): forward steel/cyan equip flash in front of Demolisher
						dur = 0.44
						var mat_sh := _get_shared_mat(Color(0.32, 0.82, 1.0, 0.86), true)
						var plate := _vfx_part(root, box, mat_sh, Vector3(-0.08, 1.05, -0.65), Vector3(1.15, 1.35, 0.10), Vector3.ZERO, fade_meshes)
						var s_ring := _vfx_part(root, torus, mat_sh, Vector3(0.0, 0.12, -0.55), Vector3(1.0, 0.7, 1.0), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(plate, "scale", Vector3(1.28, 1.48, 0.14), dur)
							tw.tween_property(s_ring, "scale", Vector3(2.2, 0.7, 2.2), dur)
					1: # Haste: amber speed streaks & fiery adrenaline aura
						dur = 0.54
						var mat_hst := _get_shared_mat(Color(1.0, 0.78, 0.18, 0.94), true)
						for i in range(4):
							var sx: float = (float(i) - 1.5) * 0.34
							var stk := _vfx_part(root, box, mat_hst, Vector3(sx, 0.24 + (i % 2) * 0.18, 0.20), Vector3(0.07, 0.07, 0.80), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.75, dur)
					2: # Corda de TNTs: crimson-orange fuse spark cluster around hand
						dur = 0.48
						var mat_tnt := _get_shared_mat(Color(1.0, 0.42, 0.12, 0.92), true)
						for i in range(3):
							var a: float = float(i) * (TAU / 3.0)
							var sp := _vfx_part(root, sph, mat_tnt, Vector3(0.24 + cos(a) * 0.20, 1.15 + sin(a) * 0.15, -0.22), Vector3(0.16, 0.16, 0.16), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(sp, "position:y", 1.55, dur)
					3: # Kit de 5 Coletes: ground armor kit deploy halo + rising cyan armor cross
						dur = 0.56
						var mat_drn := _get_shared_mat(Color(0.28, 0.88, 1.0, 0.88), true)
						var kit_ring := _vfx_part(root, torus, mat_drn, Vector3(0.0, 0.12, 0.0), Vector3(0.8, 0.7, 0.8), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(kit_ring, "scale", Vector3(3.8, 0.7, 3.8), dur)
						_vfx_plus_cross(root, mat_drn, Vector3(0.0, 0.85, 0.0), 0.42, 0.11, fade_meshes)
					_: # Quebra-Tanques: fiery orange-gold armor-buster shock ring & upward lance
						dur = 0.54
						var mat_vb := _get_shared_mat(Color(1.0, 0.36, 0.12, 0.94), true)
						var lance := _vfx_part(root, cone, mat_vb, Vector3(0.0, 1.25, -0.45), Vector3(0.48, 1.4, 0.48), Vector3(-PI * 0.5, 0.0, 0.0), fade_meshes)
						var vring := _vfx_part(root, torus, mat_vb, Vector3(0.0, 0.12, 0.0), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(lance, "position:z", -1.65, dur)
							tw.tween_property(vring, "scale", Vector3(3.2, 0.8, 3.2), dur)
			NetworkManager.CLASS_ENGINEER:
				match slot_idx:
					0, 1: # Construct Trench / Turret: golden-cyan blueprint shockwave ring
						dur = 0.62
						var mat_eng := _get_shared_mat(Color(0.32, 0.88, 1.0, 0.88), true)
						var bring := _vfx_part(root, torus, mat_eng, Vector3(0.0, 0.14, 0.0), Vector3(0.8, 0.7, 0.8), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(bring, "scale", Vector3(3.6, 0.7, 3.6), dur)
					2: # Armor Vehicle: gleaming gold armor cross & aura ring
						dur = 0.58
						var mat_arm := _get_shared_mat(Color(1.0, 0.82, 0.24, 0.92), true)
						_vfx_plus_cross(root, mat_arm, Vector3(0.0, 1.10, 0.0), 0.48, 0.12, fade_meshes)
						var aring := _vfx_part(root, torus, mat_arm, Vector3(0.0, 0.25, 0.0), Vector3(1.2, 0.8, 1.2), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(aring, "scale", Vector3(3.4, 0.8, 3.4), dur)
					3: # Mortar Call: crimson telemetry flare rising skyward
						dur = 0.65
						var mat_mr := _get_shared_mat(Color(1.0, 0.30, 0.20, 0.92), true)
						var flare := _vfx_part(root, cone, mat_mr, Vector3(0.0, 1.10, 0.0), Vector3(0.36, 1.4, 0.36), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(flare, "position:y", 3.6, dur)
					_: # Invulnerable Armor: bright golden-cyan dome pulse
						dur = 0.65
						var mat_inv := _get_shared_mat(Color(1.0, 0.88, 0.30, 0.92), true)
						var dome := _vfx_part(root, sph, mat_inv, Vector3(0.0, 1.05, 0.0), Vector3(1.4, 2.0, 1.4), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(dome, "scale", Vector3(2.4, 2.6, 2.4), dur)
			NetworkManager.CLASS_MARKSMAN:
				match slot_idx:
					0: # Sprint: lime wind streaks
						dur = 0.48
						var mat_spr := _get_shared_mat(Color(0.68, 1.0, 0.28, 0.90), true)
						for i in range(4):
							var sx: float = (float(i) - 1.5) * 0.32
							var stk := _vfx_part(root, box, mat_spr, Vector3(sx, 0.24 + (i % 2) * 0.16, 0.22), Vector3(0.06, 0.06, 0.75), Vector3.ZERO, fade_meshes)
							if tw != null:
								tw.tween_property(stk, "position:z", 1.65, dur)
					1, 3: # Flashbang / Thrown Stick Grenade: amber throw arc spark
						dur = 0.42
						var mat_th := _get_shared_mat(Color(0.96, 0.94, 0.72, 0.90), true)
						var sp := _vfx_part(root, sph, mat_th, Vector3(0.22, 1.42, -0.35), Vector3(0.24, 0.24, 0.24), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(sp, "position", Vector3(0.18, 1.72, -1.05), dur)
					2: # UAV: expanding tactical radar ring overhead
						dur = 0.75
						var mat_uav := _get_shared_mat(Color(0.28, 0.92, 1.0, 0.88), true)
						var uring := _vfx_part(root, torus, mat_uav, Vector3(0.0, 2.2, 0.0), Vector3(0.8, 0.6, 0.8), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(uring, "scale", Vector3(4.2, 0.6, 4.2), dur)
					_: # Last Stand: crimson-orange battlecry ring
						dur = 0.60
						var mat_ls := _get_shared_mat(Color(1.0, 0.28, 0.14, 0.92), true)
						var lring := _vfx_part(root, torus, mat_ls, Vector3(0.0, 0.15, 0.0), Vector3(1.1, 0.8, 1.1), Vector3.ZERO, fade_meshes)
						if tw != null:
							tw.tween_property(lring, "scale", Vector3(3.4, 0.8, 3.4), dur)

	if tw != null:
		for mi in fade_meshes:
			tw.tween_property(mi, "transparency", 1.0, dur)
		tw.chain().tween_callback(root.queue_free)


static func _get_aoe_theme_color(class_id: int, slot_idx: int) -> Color:
	if class_id == NetworkManager.CLASS_SOLDIER:
		match slot_idx:
			0:
				return Color(0.20, 0.95, 0.56)
			3:
				return Color(1.0, 0.56, 0.14)
			4:
				return Color(1.0, 0.86, 0.22)
	elif class_id == NetworkManager.CLASS_GUNNER and slot_idx == 1:
		return Color(0.32, 0.94, 1.0)
	return Color(1.0, 0.44, 0.12)


static func _spawn_aoe_rings_into(
	root: Node3D,
	radius: float,
	theme_col: Color,
	dur: float,
	disc_alpha: float,
	tw: Tween,
	fade_meshes: Array[MeshInstance3D]
) -> void:
	var cyl: CylinderMesh = _get_shared_cylinder()
	var torus: TorusMesh = _get_shared_torus()
	var diam: float = radius * 2.0

	var mat_disc: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, disc_alpha), false)
	var disc: MeshInstance3D = _vfx_part(
		root, cyl, mat_disc,
		Vector3(0.0, 0.08, 0.0),
		Vector3(diam, 0.03, diam),
		Vector3.ZERO, fade_meshes
	)
	disc.name = "AoEGroundDisc"

	var mat_perim: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, 0.90), true)
	var perim: MeshInstance3D = _vfx_part(
		root, torus, mat_perim,
		Vector3(0.0, 0.12, 0.0),
		Vector3(diam, 0.35, diam),
		Vector3.ZERO, fade_meshes
	)
	perim.name = "AoEPerimeterRing"

	var wave_col: Color = theme_col.lerp(Color.WHITE, 0.40)
	var mat_wave: StandardMaterial3D = _get_shared_mat(Color(wave_col.r, wave_col.g, wave_col.b, 0.92), true)
	var wave := MeshInstance3D.new()
	wave.name = "AoEWaveRing"
	wave.mesh = torus
	wave.material_override = mat_wave
	wave.position = Vector3(0.0, 0.14, 0.0)
	wave.scale = Vector3(radius * 0.4, 0.45, radius * 0.4)
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(wave)

	if tw != null:
		tw.tween_property(wave, "scale", Vector3(diam, 0.45, diam), 0.45)
		tw.tween_property(wave, "transparency", 1.0, 0.45)
		tw.tween_property(disc, "transparency", 1.0, dur)
		tw.tween_property(perim, "transparency", 1.0, dur)


static func spawn_aoe_area_vfx(
	parent: Node,
	class_id: int,
	slot_idx: int,
	origin: Vector3,
	radius: float,
	affected_positions: Array[Vector3] = []
) -> Node3D:
	if parent == null or radius <= 0.0:
		return null
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "AoEAreaVFX_%d_%d" % [class_id, slot_idx]
	root.position = origin
	parent.add_child(root)

	var theme_col: Color = _get_aoe_theme_color(class_id, slot_idx)
	var dur: float = 1.1
	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	var ring_meshes: Array[MeshInstance3D] = []
	_spawn_aoe_rings_into(root, radius, theme_col, dur, 0.22, tw, ring_meshes)

	var cyl: CylinderMesh = _get_shared_cylinder()
	var torus: TorusMesh = _get_shared_torus()
	var marker_col: Color = theme_col.lerp(Color.WHITE, 0.30)
	var mat_marker: StandardMaterial3D = _get_shared_mat(Color(marker_col.r, marker_col.g, marker_col.b, 0.94), true)
	var mat_col: StandardMaterial3D = _get_shared_mat(Color(theme_col.r, theme_col.g, theme_col.b, 0.42), true)
	var marker_meshes: Array[MeshInstance3D] = []
	var is_offensive: bool = (class_id == NetworkManager.CLASS_SOLDIER and slot_idx == 3)

	for idx in range(affected_positions.size()):
		var tpos: Vector3 = affected_positions[idx]
		var marker := Node3D.new()
		marker.name = "AffectedMarker_%d" % idx
		marker.position = tpos - origin
		root.add_child(marker)

		var halo: MeshInstance3D = _vfx_part(
			marker, torus, mat_marker,
			Vector3(0.0, 0.12, 0.0),
			Vector3(1.5, 0.55, 1.5),
			Vector3.ZERO, marker_meshes
		)
		var beam: MeshInstance3D = _vfx_part(
			marker, cyl, mat_col,
			Vector3(0.0, 1.15, 0.0),
			Vector3(0.42, 2.2, 0.42),
			Vector3.ZERO, marker_meshes
		)
		var emblem: Node3D = _vfx_plus_cross(
			marker, mat_marker,
			Vector3(0.0, 2.35, 0.0),
			0.42, 0.11, marker_meshes
		)
		if is_offensive:
			emblem.rotation.z = PI * 0.25

		if tw != null:
			tw.tween_property(halo, "scale", Vector3(2.1, 0.55, 2.1), 0.8)
			tw.tween_property(beam, "position:y", 1.95, 0.8)
			tw.tween_property(emblem, "position:y", 2.90, 0.8)
			tw.tween_property(emblem, "rotation:y", PI, 0.8)

	if tw != null:
		for mi in marker_meshes:
			tw.tween_property(mi, "transparency", 1.0, 0.8)
		tw.chain().tween_callback(root.queue_free)

	return root


static func spawn_explosion_area_ring(parent: Node, origin: Vector3, radius: float) -> Node3D:
	if parent == null or radius <= 0.0 or DisplayServer.get_name().contains("headless"):
		return null
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "ExplosionAreaVFX"
	root.position = origin
	parent.add_child(root)

	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		tw.set_parallel(true)

	var ring_meshes: Array[MeshInstance3D] = []
	_spawn_aoe_rings_into(root, radius, Color(1.0, 0.44, 0.12), 0.65, 0.16, tw, ring_meshes)
	if tw != null:
		tw.chain().tween_callback(root.queue_free)

	return root


static func spawn_mortar_warning_ring(parent: Node, origin: Vector3, radius: float = 13.0, delay: float = 1.25) -> Node3D:
	if parent == null or radius <= 0.0 or DisplayServer.get_name().contains("headless"):
		return null
	warm_shared_meshes()

	var root := Node3D.new()
	root.name = "MortarWarningVFX"
	root.position = origin + Vector3(0.0, 0.08, 0.0)
	root.add_to_group("mortar_rings")
	parent.add_child(root)

	var outer_ring := MeshInstance3D.new()
	outer_ring.mesh = _get_shared_torus()
	outer_ring.material_override = _get_shared_mat(Color(1.0, 0.18, 0.14, 0.90), true)
	outer_ring.scale = Vector3(radius * 2.0, 0.45, radius * 2.0)
	outer_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(outer_ring)

	var fill_disc := MeshInstance3D.new()
	fill_disc.mesh = _get_shared_cylinder()
	fill_disc.material_override = _get_shared_mat(Color(1.0, 0.22, 0.16, 0.28), true)
	fill_disc.scale = Vector3(radius * 0.25, 0.03, radius * 0.25)
	fill_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fill_disc)

	var tw: Tween = root.create_tween() if root.is_inside_tree() else null
	if tw != null:
		var safe_delay: float = maxf(0.1, delay)
		tw.set_parallel(true)
		tw.tween_property(fill_disc, "scale", Vector3(radius * 1.95, 0.03, radius * 1.95), safe_delay)
		tw.tween_property(outer_ring, "scale", Vector3(radius * 2.15, 0.70, radius * 2.15), safe_delay)
		tw.chain().tween_callback(root.queue_free)

	return root


static func _spawn_mortar_trail_puff(parent: Node, pos: Vector3) -> void:
	if parent == null or DisplayServer.get_name().contains("headless"):
		return
	if _is_beyond_vfx_distance(parent, pos, 110.0):
		return
	warm_shared_meshes()
	var mgr: VfxPoolManager = _get_pool_manager(parent)
	if mgr == null:
		return
	var entry: VfxPoolEntry = mgr._acquire_entry(mgr._mote_free, mgr.MAX_MOTES, 4, func() -> VfxPoolEntry:
		var e := VfxPoolEntry.new()
		e.kind = 4
		var mi := MeshInstance3D.new()
		mi.mesh = _get_shared_sphere()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.node = mi
		e.mesh_node = mi
		return e
	)
	var puff := entry.mesh_node
	puff.mesh = _get_shared_sphere()
	if entry.aux_mesh_node != null:
		entry.aux_mesh_node.visible = false
	puff.material_override = _get_shared_mat(Color(0.86, 0.84, 0.80, 0.55), false)
	puff.position = pos
	puff.scale = Vector3(0.32, 0.32, 0.32)
	entry.start_pos = pos
	entry.end_pos = pos + Vector3(0.0, 0.45, 0.0)
	entry.start_scale = Vector3(0.32, 0.32, 0.32)
	entry.end_scale = Vector3(0.95, 0.95, 0.95)
	entry.duration = 0.38


static func spawn_mortar_shell_arc(parent: Node, origin: Vector3, target: Vector3, duration: float = 1.25) -> Node3D:
	if parent == null:
		return null
	warm_shared_meshes()

	var shell := MortarShellArcVFX.new()
	shell.name = "MortarShellArcVFX"
	shell.origin = origin
	shell.target = target
	shell.duration = maxf(0.1, duration)
	var horiz_dist: float = Vector2(target.x - origin.x, target.z - origin.z).length()
	shell.peak_lift = clampf(16.0 + horiz_dist * 0.28, 18.0, 42.0)
	shell.position = origin
	shell.add_to_group("mortar_rings")

	var cyl: CylinderMesh = _get_shared_cylinder()
	var cone: CylinderMesh = _get_shared_cone()
	var sph: SphereMesh = _get_shared_sphere()
	var olive_mat: StandardMaterial3D = _get_shared_mat(Color(0.32, 0.38, 0.24, 1.0), false)
	var brass_mat: StandardMaterial3D = _get_shared_mat(Color(0.92, 0.72, 0.24, 1.0), false)
	var flame_mat: StandardMaterial3D = _get_shared_mat(Color(1.0, 0.52, 0.14, 0.94), true)
	var dummy: Array[MeshInstance3D] = []

	# Shell aligned along -Z forward (cylinder/cone local +Y rotated -PI*0.5 around X -> -Z)
	_vfx_part(shell, cyl, olive_mat, Vector3.ZERO, Vector3(0.22, 0.56, 0.22), Vector3(-PI * 0.5, 0.0, 0.0), dummy)
	_vfx_part(shell, cone, brass_mat, Vector3(0.0, 0.0, -0.38), Vector3(0.20, 0.26, 0.20), Vector3(-PI * 0.5, 0.0, 0.0), dummy)
	_vfx_part(shell, sph, flame_mat, Vector3(0.0, 0.0, 0.34), Vector3(0.28, 0.28, 0.46), Vector3.ZERO, dummy)

	parent.add_child(shell)
	shell._process(0.0)
	return shell


static func _add_wireframe_box_outline(
	parent_n: Node3D,
	center: Vector3,
	sz: Vector3,
	frame_mat: Material,
	fill_mat: Material,
	thickness: float = 0.05
) -> void:
	var box: BoxMesh = _get_shared_box()
	var dummy: Array[MeshInstance3D] = []
	if fill_mat != null:
		_vfx_part(parent_n, box, fill_mat, center, sz, Vector3.ZERO, dummy)

	var hx: float = sz.x * 0.5
	var hy: float = sz.y * 0.5
	var hz: float = sz.z * 0.5
	for sx in [-1.0, 1.0]:
		for sz_s in [-1.0, 1.0]:
			_vfx_part(parent_n, box, frame_mat, center + Vector3(sx * hx, 0.0, sz_s * hz), Vector3(thickness, sz.y, thickness), Vector3.ZERO, dummy)
	for sy in [-1.0, 1.0]:
		for sz_s in [-1.0, 1.0]:
			_vfx_part(parent_n, box, frame_mat, center + Vector3(0.0, sy * hy, sz_s * hz), Vector3(sz.x, thickness, thickness), Vector3.ZERO, dummy)
		for sx in [-1.0, 1.0]:
			_vfx_part(parent_n, box, frame_mat, center + Vector3(sx * hx, sy * hy, 0.0), Vector3(thickness, thickness, sz.z), Vector3.ZERO, dummy)


static func spawn_build_preview(
	parent: Node,
	hero_id: int,
	slot: int,
	pos: Vector3,
	yaw: float,
	duration: float
) -> Node3D:
	if parent == null:
		return null
	stop_build_preview(hero_id)
	warm_shared_meshes()

	var root := BuildPreviewVFX.new()
	root.name = "BuildPreview_%d_%d" % [hero_id, slot]
	root.hero_id = hero_id
	root.slot = slot
	root.duration = maxf(0.1, duration)
	root.position = pos
	root.rotation.y = yaw
	root.add_to_group("build_previews")

	var scaffold := Node3D.new()
	scaffold.name = "Scaffold"
	scaffold.scale = Vector3(1.0, 0.05, 1.0)
	root.add_child(scaffold)
	root.scaffold = scaffold

	var fill_mat: StandardMaterial3D = _get_shared_mat(Color(0.22, 0.88, 1.0, 0.24), true)
	var cyan_wire: StandardMaterial3D = _get_shared_mat(Color(0.32, 0.96, 1.0, 0.92), true)
	var gold_wire: StandardMaterial3D = _get_shared_mat(Color(1.0, 0.86, 0.24, 0.90), true)
	var box: BoxMesh = _get_shared_box()
	var torus: TorusMesh = _get_shared_torus()
	var dummy: Array[MeshInstance3D] = []

	match slot:
		0: # Trincheira blueprint scaffold
			_add_wireframe_box_outline(scaffold, Vector3(0.0, 1.375, -0.95), Vector3(5.0, 2.75, 0.42), cyan_wire, fill_mat, 0.055)
			for sx in [-1.0, 1.0]:
				_add_wireframe_box_outline(scaffold, Vector3(sx * 2.23, 1.50, -0.88), Vector3(0.54, 3.00, 0.68), gold_wire, fill_mat, 0.055)
				_add_wireframe_box_outline(scaffold, Vector3(sx * 2.24, 0.875, 0.10), Vector3(0.32, 1.75, 1.48), cyan_wire, fill_mat, 0.05)
			_add_wireframe_box_outline(scaffold, Vector3(0.0, 0.775, -0.10), Vector3(4.12, 1.55, 1.28), gold_wire, fill_mat, 0.05)
			_vfx_part(root, box, gold_wire, Vector3(0.0, 0.04, 0.0), Vector3(5.15, 0.04, 0.05), Vector3.ZERO, dummy)
		1: # Torreta MG blueprint scaffold (tripod + pedestal + shield + barrel)
			for leg_i in range(3):
				var ang: float = float(leg_i) * (TAU / 3.0) + PI * 0.5
				var lx: float = cos(ang) * 0.45
				var lz: float = sin(ang) * 0.45
				_vfx_part(scaffold, box, gold_wire, Vector3(lx, 0.48, lz), Vector3(0.07, 1.05, 0.07), Vector3(lz * 0.65, 0.0, -lx * 0.65), dummy)
			_vfx_part(scaffold, box, cyan_wire, Vector3(0.0, 0.62, 0.0), Vector3(0.16, 1.24, 0.16), Vector3.ZERO, dummy)
			_add_wireframe_box_outline(scaffold, Vector3(0.0, 1.36, -0.24), Vector3(1.10, 0.72, 0.10), cyan_wire, fill_mat, 0.045)
			_add_wireframe_box_outline(scaffold, Vector3(0.0, 1.38, -0.62), Vector3(0.12, 0.12, 0.90), gold_wire, fill_mat, 0.035)
			_vfx_part(root, torus, cyan_wire, Vector3(0.0, 0.06, 0.0), Vector3(1.9, 0.45, 1.9), Vector3.ZERO, dummy)
		_: # Blindar Veículo blueprint plates + ring
			_vfx_part(root, torus, gold_wire, Vector3(0.0, 0.10, 0.0), Vector3(4.2, 0.55, 4.2), Vector3.ZERO, dummy)
			for sx in [-1.0, 1.0]:
				_add_wireframe_box_outline(scaffold, Vector3(sx * 1.45, 0.90, 0.0), Vector3(0.10, 0.85, 2.60), gold_wire, fill_mat, 0.045)
			_add_wireframe_box_outline(scaffold, Vector3(0.0, 0.90, -1.65), Vector3(2.20, 0.75, 0.10), cyan_wire, fill_mat, 0.045)

	parent.add_child(root)
	_active_build_previews[hero_id] = root
	return root


static func stop_build_preview(hero_id: int) -> void:
	var prev: Variant = _active_build_previews.get(hero_id, null)
	_active_build_previews.erase(hero_id)
	if prev is Node and is_instance_valid(prev):
		(prev as Node).queue_free()


static func clear_all_build_previews() -> void:
	for k in _active_build_previews.keys():
		var prev: Variant = _active_build_previews[k]
		if prev is Node and is_instance_valid(prev):
			(prev as Node).queue_free()
	_active_build_previews.clear()


static func update_continuous_flame_stream(
	parent: Node,
	hero_id: int,
	muzzle_world: Vector3,
	dir: Vector3,
	max_len: float,
	is_fire_starter: bool = false
) -> FlameStreamVFX:
	if parent == null:
		return null
	if _is_beyond_vfx_distance(parent, muzzle_world, 110.0):
		return null

	var stream: FlameStreamVFX = _active_flame_streams.get(hero_id, null) as FlameStreamVFX
	if stream == null or not is_instance_valid(stream) or stream.is_queued_for_deletion():
		stream = FlameStreamVFX.new()
		stream.name = "FlameStream_%d" % hero_id
		stream.hero_id = hero_id
		parent.add_child(stream)
		_active_flame_streams[hero_id] = stream
		stream.build_stream(max_len, is_fire_starter)
	elif stream.get_parent() != parent:
		if stream.get_parent() != null:
			stream.get_parent().remove_child(stream)
		parent.add_child(stream)
		stream.refresh_stream(max_len, is_fire_starter)
	else:
		stream.refresh_stream(max_len, is_fire_starter)

	stream.position = muzzle_world
	var d_norm: Vector3 = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var up_hint: Vector3 = Vector3.RIGHT if absf(d_norm.dot(Vector3.UP)) > 0.96 else Vector3.UP
	var right_v: Vector3 = d_norm.cross(up_hint).normalized()
	var up_v: Vector3 = right_v.cross(d_norm).normalized()
	stream.basis = Basis(right_v, up_v, -d_norm)
	return stream


static func stop_continuous_flame_stream(hero_id: int) -> void:
	var prev: Variant = _active_flame_streams.get(hero_id, null)
	_active_flame_streams.erase(hero_id)
	if prev is Node and is_instance_valid(prev):
		(prev as Node).queue_free()


static func clear_all_flame_streams() -> void:
	for k in _active_flame_streams.keys():
		var prev: Variant = _active_flame_streams[k]
		if prev is Node and is_instance_valid(prev):
			(prev as Node).queue_free()
	_active_flame_streams.clear()
