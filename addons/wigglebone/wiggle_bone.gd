@tool
class_name WiggleBone
extends BoneAttachment3D

## Adds jiggle physics to the bone.
##
## It reacts to animated or global motion as if it's connected with a rubber
## band to its initial position. As it reacts to acceleration instead of velocity,
## bones of constantly moving objects will not "lag behind" and have a more realistic behaviour.

const ACCELERATION_WEIGHT := 0.5
const SOFT_LIMIT_FACTOR := 0.5

## Enable WiggleBone.
@export var enabled := true: set = set_enabled
## The properties used to move the bone.
@export var properties: WiggleProperties: set = set_properties

@export_group("Const Force", "const_force")
## A constant global force.
@export var const_force_global := Vector3.ZERO # global force
## A constant local force relative to the bone's rest pose.
@export var const_force_local := Vector3.ZERO # local force relative to bone pose

var _skeleton: Skeleton3D
var _bone_idx := -1
var _parent_bone_idx := -1
var _point_mass := PointMass.new()
var _global_to_pose := Basis()
var _should_reset := true
var _acceleration := Vector3.ZERO # local bone acceleration at mass center
var _prev_mass_center := Vector3.ZERO
var _prev_velocity := Vector3.ZERO


func _ready() -> void:
	set_enabled(enabled)


func _enter_tree() -> void:
	if get_use_external_skeleton():
		var skeleton_node := get_external_skeleton()
		if skeleton_node:
			_skeleton = get_node(skeleton_node)

	else:
		_skeleton = get_parent()

	_fetch_bone()
	reset()


func _exit_tree() -> void:
	_skeleton = null
	_fetch_bone()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"bone_name":
		reset()
		set_bone_name(value)
		_fetch_bone()
		reset()
		update_configuration_warnings()

	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append("WiggleProperties resource is required")

	return warnings


func _process(delta: float) -> void:
	# may be 0.0 in editor on first frame
	if delta == 0.0:
		delta = 1.0 / float(60.0)

	var bone_pose := _skeleton.get_bone_pose(_bone_idx)
	if _parent_bone_idx >= 0:
		bone_pose = _skeleton.get_bone_global_pose(_parent_bone_idx) * bone_pose

	var global_bone_pose = _skeleton.global_transform * bone_pose
	_global_to_pose = global_bone_pose.basis.inverse()

	var new_acceleration := _update_acceleration(global_bone_pose, delta)
	_acceleration = _acceleration.lerp(new_acceleration, ACCELERATION_WEIGHT)

	# adjust for varying framerates
	# this is only an approximation
	var delta_factor := log(delta * 60.0) / log(2.0) + 1.0
	_acceleration /= clampf(delta_factor, 1.0, 3.0) # TODO: adjust for rates higher than 60 fps

	var pose := bone_pose * _pose()

	if not override_pose:
		_skeleton.set_bone_global_pose_override(_bone_idx, pose, 1.0, true)

	else:
		# TODO: fix when using external skeleton
		global_transform = _skeleton.global_transform * pose


func _physics_process(delta: float) -> void:
	_solve(_global_to_pose, _acceleration, delta)


func set_enabled(value: bool) -> void:
	enabled = value
	reset()
	_update_enabled()


func set_properties(value: WiggleProperties) -> void:
	if properties:
		properties.changed.disconnect(_on_properties_changed)
		properties.behaviour_changed.disconnect(_on_behaviour_changed)

	properties = value

	if properties:
		properties.changed.connect(_on_properties_changed)
		properties.behaviour_changed.connect(_on_behaviour_changed)

	reset()
	_update_enabled()
	update_configuration_warnings()
	update_gizmos()


func apply_impulse(impulse: Vector3, global := false) -> void:
	if global:
		impulse = _global_to_pose * impulse

	_point_mass.apply_force(impulse)


func reset() -> void:
	if _skeleton:
		_skeleton.set_bone_global_pose_override(_bone_idx, Transform3D(), 0.0)

	_point_mass.reset()
	_should_reset = true


func _update_acceleration(global_bone_pose: Transform3D, delta: float) -> Vector3:
	var mass_center := Vector3.ZERO

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			mass_center = Vector3.UP * properties.length

	mass_center = global_bone_pose * mass_center
	var delta_mass_center := _prev_mass_center - mass_center
	_prev_mass_center = mass_center

	if _should_reset:
		delta_mass_center = Vector3.ZERO

	var global_velocity := delta_mass_center / delta
	_acceleration = global_velocity - _prev_velocity
	_prev_velocity = global_velocity

	if _should_reset:
		_acceleration = Vector3.ZERO
		_should_reset = false

	return _acceleration


func _solve(global_to_local: Basis, acceleration: Vector3, delta: float) -> void:
	var global_force := properties.gravity + const_force_global
	var local_force := global_to_local * global_force + const_force_local

	var mass_distance := properties.length
	var local_acc := global_to_local * acceleration

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			local_force = _project_to_vector_plane(Vector3.ZERO, mass_distance, local_force)
			local_acc = _project_to_vector_plane(Vector3.ZERO, mass_distance, local_acc)

	_point_mass.accelerate(local_acc, delta)
	_point_mass.apply_force(local_force)
	_point_mass.solve(properties.stiffness, properties.damping, delta)


func _pose() -> Transform3D:
	var pose := Transform3D()

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var mass_distance := properties.length
			var angular_offset := Vector2.RIGHT.rotated(deg_to_rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit := angular_offset * mass_distance
			var k := angular_limit * SOFT_LIMIT_FACTOR
			var mass_constrained := _clamp_length_soft(_point_mass.p, 0.0, angular_limit, k)

			var mass_local := (Vector3.UP * properties.length) + mass_constrained
			var relative_rotation := Quaternion(Vector3.UP, mass_local.normalized())

			pose.basis = Basis(relative_rotation)

		WiggleProperties.Mode.DISLOCATION:
			var k := properties.max_distance * SOFT_LIMIT_FACTOR
			var mass_constrained := _clamp_length_soft(_point_mass.p, 0.0, properties.max_distance, k)

			pose.origin = mass_constrained

	return pose


func _update_enabled() -> void:
	var valid := _skeleton != null and _bone_idx >= 0 and properties != null
	var active := enabled and valid

	set_physics_process(active)
	set_process(active)

	if valid and not enabled:
		_skeleton.set_bone_global_pose_override(_bone_idx, Transform3D(), 0.0)


func _fetch_bone() -> void:
	_bone_idx = _skeleton.find_bone(bone_name) if _skeleton else -1
	_parent_bone_idx = _skeleton.get_bone_parent(_bone_idx) if _bone_idx >= 0 else -1
	_update_enabled()


func _on_properties_changed() -> void:
	update_gizmos()


func _on_behaviour_changed() -> void:
	reset()


func _project_to_vector_plane(vector: Vector3, length: float, point: Vector3) -> Vector3:
	return Plane(vector.normalized(), length).project(point)


func _clamp_length_soft(v: Vector3, min_length: float, max_length: float, k: float) -> Vector3:
	return v.normalized() * _smin(maxf(min_length, v.length()), max_length, k)


# https://iquilezles.org/articles/smin/
func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(0.0, k - absf(a - b))
	return minf(a, b) - h * h / (4.0 * k)


class PointMass:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var a := Vector3.ZERO

	func solve(stiffness: float, damping: float, delta: float) -> void:
		# inertia
		v = v * (1.0 - damping) + a * delta
		p += v
		a = Vector3.ZERO

		# constraint
		v -= p * stiffness

	func accelerate(acc: Vector3, delta: float) -> void:
		v += acc * delta

	func apply_force(force: Vector3) -> void:
		a += force

	func reset() -> void:
		p = Vector3.ZERO
		v = Vector3.ZERO
		a = Vector3.ZERO
