@tool
@icon("icons/wiggle_position_modifier_3d.svg")
class_name DMWBWigglePositionModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone influencing the pose rotation.

const Functions := preload("functions.gd")

## Name of the bone to modify.
@export var bone_name := "":
	set = set_bone_name

## Properties used to move the bone.
@export var properties: DMWBWigglePositionProperties3D:
	set = set_properties

@export_group("Force", "force")

## Applies a constant global force.
@export var force_global := Vector3.ZERO

## Applies a constant local force relative to the bone's pose.
@export var force_local := Vector3.ZERO

var _bone_idx := -1
var _bone_parent_idx := -1
var _global_position := Vector3.ZERO # Global pose position.
var _global_velocity := Vector3.ZERO # Global velocity.
var _local_position := Vector3.ZERO # Position in pose space.
var _reset := true


func _enter_tree() -> void:
	_setup()


func _exit_tree() -> void:
	_bone_idx = -1
	_bone_parent_idx = -1


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"bone_name":
			var skeleton := get_skeleton()
			var bone_names := Functions.get_sorted_skeleton_bones(skeleton)

			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(bone_names)

		&"force_global", &"force_local":
			property.hint_string = &"suffix:m/s²"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append(tr(&"DMWBWigglePositionProperties3D resource is required.", &"DMWB"))

	return warnings


func _process_modification() -> void:
	if _bone_idx < 0:
		return

	var skeleton := get_skeleton()
	var delta := 0.0

	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	# Limit delta.
	delta = clampf(delta, 0.001, 0.1)

	var skeleton_bone_parent_global_pose := skeleton.global_transform
	if _bone_parent_idx >= 0:
		skeleton_bone_parent_global_pose *= skeleton.get_bone_global_pose(_bone_parent_idx)

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var pose_to_global := skeleton_bone_parent_global_pose * bone_pose
	var global_to_pose := pose_to_global.affine_inverse()

	if _reset:
		_local_position = Vector3.ZERO
		_global_position = pose_to_global.origin
		_global_velocity = Vector3.ZERO

	var global_position_new := pose_to_global * _local_position
	_global_position = global_position_new.lerp(_global_position, properties.linear_scale)
	var global_velocity := (global_position_new - _global_position) / delta

	if _reset:
		global_velocity = Vector3.ZERO

	# Global forces.
	var force := (force_global + properties.get_gravity()) * properties.force_scale
	# Add force relative to current pose.
	force += pose_to_global.basis * force_local * properties.force_scale
	# Add reverse global velocity.
	force -= global_velocity

	# Add force.
	var acceleration := force
	_global_velocity += acceleration * delta

	# Apply spring velocity without damping (see README.md).
	var frequency := properties.spring_freq * TAU
	if not is_zero_approx(frequency):
		var pose_global := pose_to_global.origin
		var spring_position := _global_position - pose_global

		var x0 := spring_position
		var a := delta * frequency
		var cos_ := cos(a)
		var sin_ := sin(a)
		var c2 := _global_velocity / frequency

		_global_position = pose_global + (x0 * cos_ + c2 * sin_)
		_global_velocity = (c2 * cos_ - x0 * sin_) * frequency

	# No spring tension; linear movement.
	else:
		_global_position += _global_velocity * delta

	# Set local position to calculate parent speed in next iteration.
	_local_position = global_to_pose * _global_position

	# Time-independent velocity damping (see README.md).
	var velocity_decay := properties.linear_damp
	_global_velocity *= exp(-velocity_decay * delta)

	# Limit position and velocity.
	var length_squared := _local_position.length_squared()
	var max_distance := properties.max_distance
	if length_squared > max_distance * max_distance:
		# Limit position to max_distance.
		_local_position = _local_position * max_distance / sqrt(length_squared)
		# Recalculate global position.
		_global_position = pose_to_global * _local_position

		var position_relative := _global_position - pose_to_global.origin
		# Limit velocity when moving towards limit.
		if position_relative.dot(_global_velocity) > 0.0:
			# Project velocity to sphere tangent.
			_global_velocity = Plane(position_relative.normalized(), 0.0).project(_global_velocity)

	# Set bone pose position.
	var bone_position := bone_pose * _local_position
	skeleton.set_bone_pose_position(_bone_idx, bone_position)

	# Apply bone transform to node.
	bone_pose.origin = bone_position
	global_transform = skeleton_bone_parent_global_pose * bone_pose

	_reset = false


func set_properties(value: DMWBWigglePositionProperties3D) -> void:
	var is_editor := Engine.is_editor_hint()

	if properties and is_editor:
		properties.changed.disconnect(_on_properties_changed)

	properties = value

	if properties and is_editor:
		properties.changed.connect(_on_properties_changed)

	_setup()
	update_gizmos()
	update_configuration_warnings()


func set_bone_name(value: String) -> void:
	bone_name = value
	_setup()
	update_gizmos()


## Reset position and velocity.
func reset() -> void:
	_reset = true


## Add a global force impulse.
func add_force_impulse(force: Vector3) -> void:
	_global_velocity += force


func _setup() -> void:
	_bone_idx = -1

	if not properties:
		return

	var skeleton := get_skeleton()
	if not skeleton:
		return

	_bone_idx = skeleton.find_bone(bone_name)
	if _bone_idx < 0:
		return

	var skeleton_bone_pose := skeleton.get_bone_pose(_bone_idx)
	_bone_parent_idx = skeleton.get_bone_parent(_bone_idx)

	if _bone_parent_idx >= 0:
		skeleton_bone_pose = skeleton.get_bone_global_pose(_bone_parent_idx) * skeleton_bone_pose

	_global_position = skeleton.global_transform * skeleton_bone_pose.origin
	_global_velocity = Vector3.ZERO
	_local_position = Vector3.ZERO
	_reset = true


func _on_properties_changed() -> void:
	update_gizmos()
