@tool
@icon("icon.svg")
class_name WiggleBoneModifier
extends SkeletonModifier3D

## Adds jiggle physics to the bone.
##
## It reacts to animated or global motion as if it's connected with a rubber band to its initial
## position.

const SOFT_LIMIT_FACTOR := 0.5

## The bone name to animate.
@export var bone_name := "": set = set_bone_name
## The properties used to move the bone.
@export var properties: WiggleProperties: set = set_properties

@export_group("Const Force", "const_force")
## A constant global force.
@export var const_force_global := Vector3.ZERO
## A constant local force relative to the bone's rest pose.
@export var const_force_local := Vector3.ZERO

var _bone_idx := -1
var _point_mass := Vector3.ZERO
var _point_mass_velocity := Vector3.ZERO
var _point_mass_acceleration := Vector3.ZERO
var _global_to_pose := Basis()
var _prev_mass_center := Vector3.ZERO
var _should_reset := true
var _bone_rest_rotation := Quaternion()
var _bone_rest_position := Vector3.ZERO


func _enter_tree() -> void:
	_fetch_bone()
	reset()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"bone_name":
			var bone_names = _get_sorted_skeleton_bone()
			property.hint |= PROPERTY_HINT_ENUM
			property.hint_string = ",".join(bone_names)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append("WiggleProperties resource is required")

	return warnings


func _process_modification() -> void:
	if not properties or _bone_idx < 0:
		return

	var skeleton := get_skeleton()
	var delta := 0.0

	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var parent_pose := Transform3D()

	if parent_bone_idx >= 0:
		parent_pose = skeleton.get_bone_global_pose(parent_bone_idx)
		bone_pose = parent_pose * bone_pose

	var global_bone_pose := skeleton.global_transform * bone_pose
	_global_to_pose = global_bone_pose.basis.inverse()

	var mass_center := Vector3.ZERO

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			mass_center = Vector3.UP * properties.length

	mass_center = global_bone_pose * mass_center
	var delta_mass_center := _prev_mass_center - mass_center
	_prev_mass_center = mass_center

	if _should_reset:
		delta_mass_center = Vector3.ZERO
		_prev_mass_center = Vector3.ZERO
		_should_reset = false

	var delta_limited := clampf(delta, 0.001, 0.033333)
	var global_velocity := delta_mass_center / delta_limited

	var global_force := properties.gravity + const_force_global + global_velocity
	var local_force := _global_to_pose * global_force + const_force_local

	var mass_distance := properties.length

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			local_force = _project_to_vector_plane(Vector3.ZERO, mass_distance, local_force)

	var damping := properties.damping
	var stiffness := properties.stiffness

	_point_mass_acceleration += local_force
	_point_mass_velocity = _point_mass_velocity * (1.0 - damping) + _point_mass_acceleration * delta
	_point_mass += _point_mass_velocity
	_point_mass_velocity -= _point_mass * stiffness
	_point_mass_acceleration = Vector3.ZERO

	var pose := Transform3D()
	var point_mass = _point_mass

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var angular_offset := Vector2.RIGHT.rotated(deg_to_rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit := angular_offset * mass_distance
			var k := angular_limit * SOFT_LIMIT_FACTOR
			var mass_constrained := _clamp_length_soft(point_mass, 0.0, angular_limit, k)

			var mass_local := (Vector3.UP * properties.length) + mass_constrained
			var relative_rotation := Quaternion(Vector3.UP, mass_local.normalized())

			var bone_rotation := _bone_rest_rotation * relative_rotation
			skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

			pose.basis = Basis(relative_rotation)

		WiggleProperties.Mode.DISLOCATION:
			var k := properties.max_distance * SOFT_LIMIT_FACTOR
			var mass_constrained := _clamp_length_soft(point_mass, 0.0, properties.max_distance, k)

			var bone_position := _bone_rest_position + _bone_rest_rotation * mass_constrained
			skeleton.set_bone_pose_position(_bone_idx, bone_position)

			pose.origin = bone_position

	pose = bone_pose * pose
	global_transform = skeleton.global_transform * pose


func set_properties(value: WiggleProperties) -> void:
	var is_editor := Engine.is_editor_hint()

	if properties:
		if is_editor:
			properties.changed.disconnect(_on_properties_changed)
		properties.behaviour_changed.disconnect(_on_behaviour_changed)

	properties = value

	if properties and is_editor:
		if is_editor:
			properties.changed.connect(_on_properties_changed)
		properties.behaviour_changed.connect(_on_behaviour_changed)

	reset()
	update_configuration_warnings()
	update_gizmos()


func set_bone_name(value: String) -> void:
	bone_name = value
	_fetch_bone()
	reset()
	update_gizmos()


func apply_impulse(impulse: Vector3, global := false) -> void:
	if global:
		impulse = _global_to_pose * impulse

	_point_mass_acceleration += impulse


func reset() -> void:
	_point_mass = Vector3.ZERO
	_point_mass_velocity = Vector3.ZERO
	_point_mass_acceleration = Vector3.ZERO
	_should_reset = true


func _fetch_bone() -> void:
	var skeleton := get_skeleton()

	_bone_idx = skeleton.find_bone(bone_name) \
		if skeleton \
		else -1

	if _bone_idx >= 0:
		var bone_rest := skeleton.get_bone_rest(_bone_idx)
		_bone_rest_rotation = bone_rest.basis.get_rotation_quaternion()
		_bone_rest_position = bone_rest.origin


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


func _get_sorted_skeleton_bone() -> PackedStringArray:
	var skeleton := get_skeleton()
	if not skeleton:
		return []

	var bone_names = PackedStringArray()
	var bone_count := skeleton.get_bone_count()

	bone_names.resize(bone_count)
	for i in bone_count:
		bone_names[i] = skeleton.get_bone_name(i)
	bone_names.sort()

	return bone_names
