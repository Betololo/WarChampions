class_name HeroCamera
extends Node3D

## Tight BFH Over-the-Right-Shoulder TPS camera + 1st-person Sniper Scope transition.
signal scope_toggled(is_scoped: bool)

const TPS_SHOULDER_OFFSET: Vector3 = Vector3(0.24, 2.06, 0.0)
const TPS_SPRING_LENGTH: float = 1.58
const TPS_FOV: float = 66.0

const FPS_EYE_OFFSET: Vector3 = Vector3(0.0, 1.62, 0.0)
const FPS_SCOPE_FOV: float = 22.0

const VEHICLE_SPRING_LENGTH: float = 6.5
const VEHICLE_OFFSET: Vector3 = Vector3(0.0, 2.35, 0.0)

var mouse_sensitivity: float = 0.0024
var scope_sensitivity_mult: float = 0.36
var yaw: float = 0.0
var pitch: float = -0.02
var is_scoped: bool = false
var in_vehicle: bool = false
var recoil_pitch_offset: float = 0.0
var aim_punch_decay: float = 12.0

var pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D


func _ready() -> void:
	pivot = Node3D.new()
	pivot.name = "CameraPivot"
	add_child(pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "SpringArm3D"
	spring_arm.spring_length = TPS_SPRING_LENGTH
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.22
	pivot.add_child(spring_arm)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = TPS_FOV
	camera.far = 1600.0
	spring_arm.add_child(camera)
	pivot.position = TPS_SHOULDER_OFFSET


func set_active_camera(active: bool) -> void:
	if camera != null:
		camera.current = active


func apply_look_delta(relative: Vector2) -> void:
	var sens: float = mouse_sensitivity * (scope_sensitivity_mult if is_scoped else 1.0)
	yaw = wrapf(yaw - relative.x * sens, -PI, PI)
	pitch = clampf(pitch - relative.y * sens, -1.35, 1.35)


func add_recoil(amount_rad: float) -> void:
	recoil_pitch_offset = clampf(recoil_pitch_offset + amount_rad, 0.0, 0.22)


func set_scoped(scoped: bool) -> void:
	if is_scoped == scoped:
		return
	is_scoped = scoped
	scope_toggled.emit(is_scoped)


func set_vehicle_mode(active: bool) -> void:
	in_vehicle = active
	if active and is_scoped:
		set_scoped(false)


func _process(delta: float) -> void:
	recoil_pitch_offset = lerpf(recoil_pitch_offset, 0.0, aim_punch_decay * delta)
	var target_offset: Vector3 = TPS_SHOULDER_OFFSET
	var target_length: float = TPS_SPRING_LENGTH
	var target_fov: float = TPS_FOV

	if is_scoped:
		target_offset = FPS_EYE_OFFSET
		target_length = 0.05
		target_fov = FPS_SCOPE_FOV
	elif in_vehicle:
		target_offset = VEHICLE_OFFSET
		target_length = VEHICLE_SPRING_LENGTH
		target_fov = 74.0

	pivot.position = pivot.position.lerp(target_offset, 18.0 * delta)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, 18.0 * delta)
	camera.fov = lerpf(camera.fov, target_fov, 18.0 * delta)

	rotation.y = yaw
	pivot.rotation.x = clampf(pitch + recoil_pitch_offset, -1.40, 1.40)


func get_aim_ray_origin() -> Vector3:
	if camera != null:
		return camera.global_position
	return global_position + Vector3(0.0, 1.55, 0.0)


func get_aim_ray_direction() -> Vector3:
	if camera != null:
		return -camera.global_transform.basis.z.normalized()
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	return -basis.z.normalized()
