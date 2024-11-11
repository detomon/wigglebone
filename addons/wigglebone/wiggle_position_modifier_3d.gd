@tool
@icon("icons/wiggle_position_modifier_3d.svg")
class_name DMWBWigglePositionModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone influencing the pose position.

const Functions := preload("functions.gd")

## Bone names to modify.
@export var bones := PackedStringArray(): set = set_bones
## Properties which define the spring behaviour.
@export var properties: DMWBWigglePositionProperties3D: set = set_properties

@export_group("Force", "force")
## Applies a constant global force.
@export var force_global := Vector3.ZERO
## Applies a constant local force relative to the bone's pose.
@export var force_local := Vector3.ZERO

var _bone_indices := PackedInt32Array()
var _bone_parent_indices := PackedInt32Array()
var _global_positions := PackedVector3Array() # Global pose positions.
var _global_velocities := PackedVector3Array() # Global velocities.
var _local_positions := PackedVector3Array() # Positions in pose space.
var _reset := true


func _enter_tree() -> void:
	_setup()


func _exit_tree() -> void:
	_resize_lists(0)


func _set(property: StringName, value: Variant) -> bool:
	# Migrate old single bone name.
	if property == &"bone_name":
		set_bones([value])
		return true

	return false


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"bones":
			var skeleton := get_skeleton()
			var names := Functions.get_sorted_skeleton_bones(skeleton)

			property.hint = PROPERTY_HINT_TYPE_STRING
			property.hint_string = "%d/%d:%s" % [TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(names)]

		&"force_global", &"force_local":
			property.hint_string = &"suffix:m/s²"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not bones:
		warnings.append(tr(&"No bones defined.", &"DMWB"))
	if len(_bone_indices) < len(bones):
		warnings.append(tr(&"Some bone names are invalid.", &"DMWB"))
	if not properties:
		warnings.append(tr(&"DMWBWigglePositionProperties3D resource is required.", &"DMWB"))

	return warnings


func _process_modification() -> void:
	if not _bone_indices:
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
	var frequency := properties.spring_freq * TAU
	var has_spring := not is_zero_approx(frequency)
	var velocity_decay := properties.linear_damp
	var velocity_decay_delta := exp(-velocity_decay * delta)
	var global_force := (force_global + properties.get_gravity()) * properties.force_scale
	var a := frequency * delta
	var cos_ := cos(a)
	var sin_ := sin(a)

	for i in len(_bone_indices):
		var bone_idx := _bone_indices[i]
		var bone_parent_global_pose := skeleton_bone_parent_global_pose

		var parent_idx := _bone_parent_indices[i]
		if parent_idx >= 0:
			bone_parent_global_pose *= skeleton.get_bone_global_pose(parent_idx)

		var bone_pose := skeleton.get_bone_pose(bone_idx)
		var pose_to_global := bone_parent_global_pose * bone_pose
		var global_to_pose := pose_to_global.affine_inverse()

		if _reset:
			_local_positions[i] = Vector3.ZERO
			_global_positions[i] = pose_to_global.origin
			_global_velocities[i] = Vector3.ZERO

		var global_position_new := pose_to_global * _local_positions[i]
		_global_positions[i] = global_position_new.lerp(_global_positions[i], properties.linear_scale)
		var global_velocity := (global_position_new - _global_positions[i]) / delta

		if _reset:
			global_velocity = Vector3.ZERO

		# Global forces.
		var force := global_force \
			# Add force relative to current pose.
			+ pose_to_global.basis * force_local * properties.force_scale \
			# Add reverse global velocity.
			- global_velocity

		# Add force.
		var acceleration := force
		_global_velocities[i] += acceleration * delta

		# Apply linear velocity to spring without damping (see README.md).
		if has_spring:
			var pose_global := pose_to_global.origin
			var spring_position := _global_positions[i] - pose_global

			var x0 := spring_position
			var c2 := _global_velocities[i] / frequency

			_global_positions[i] = pose_global + (x0 * cos_ + c2 * sin_)
			_global_velocities[i] = (c2 * cos_ - x0 * sin_) * frequency

		# No spring tension; linear movement.
		else:
			_global_positions[i] += _global_velocities[i] * delta

		# Set local position to calculate parent speed in next iteration.
		_local_positions[i] = global_to_pose * _global_positions[i]

		# Time-independent velocity damping (see README.md).
		_global_velocities[i] *= velocity_decay_delta

		# Limit position and velocity.
		var length_squared := _local_positions[i].length_squared()
		var max_distance := properties.max_distance
		if length_squared > max_distance * max_distance:
			# Limit position to max_distance.
			_local_positions[i] = _local_positions[i] * max_distance / sqrt(length_squared)
			# Recalculate global position.
			_global_positions[i] = pose_to_global * _local_positions[i]

			var position_relative := _global_positions[i] - pose_to_global.origin
			# Limit velocity when moving towards limit.
			if position_relative.dot(_global_velocities[i]) > 0.0:
				# Project velocity to sphere tangent.
				_global_velocities[i] = Plane(position_relative.normalized(), 0.0).project(_global_velocities[i])

		# Set bone pose position.
		var bone_position := bone_pose * _local_positions[i]
		skeleton.set_bone_pose_position(bone_idx, bone_position)

		# Use first bone for modifier position.
		if i == 0:
			# Apply bone transform to node.
			bone_pose.origin = bone_position
			global_transform = bone_parent_global_pose * bone_pose

	_reset = false


func set_properties(value: DMWBWigglePositionProperties3D) -> void:
	if Engine.is_editor_hint():
		if properties:
			properties.changed.disconnect(_on_properties_changed)
		if value:
			value.changed.connect(_on_properties_changed)

	properties = value
	_setup()
	update_gizmos()


func set_bones(value: PackedStringArray) -> void:
	bones = value
	_setup()
	update_gizmos()


## Resets position and velocity.
func reset() -> void:
	_reset = true


## Adds a global force impulse.
func add_force_impulse(force: Vector3) -> void:
	for i in len(_global_velocities):
		_global_velocities[i] += force


func _setup() -> void:
	_resize_lists(0)

	if not properties:
		return

	var skeleton := get_skeleton()
	if not skeleton:
		return

	var count := len(bones)
	var valid_count := 0
	var skeleton_global_xform := skeleton.global_transform

	_resize_lists(count)

	for i in count:
		var bone_idx := skeleton.find_bone(bones[i])
		if bone_idx < 0:
			continue

		_bone_indices[valid_count] = bone_idx

		var skeleton_bone_pose := skeleton.get_bone_pose(bone_idx)
		var parent_idx := skeleton.get_bone_parent(bone_idx)
		_bone_parent_indices[valid_count] = parent_idx
		if parent_idx >= 0:
			skeleton_bone_pose = skeleton.get_bone_global_pose(parent_idx) * skeleton_bone_pose

		_global_positions[i] = skeleton_global_xform * skeleton_bone_pose.origin
		_global_velocities[i] = Vector3.ZERO
		_local_positions[i] = Vector3.ZERO

		valid_count += 1

	if valid_count < count:
		_resize_lists(valid_count)

	reset()
	update_configuration_warnings()


func _resize_lists(count: int) -> void:
	_bone_indices.resize(count)
	_bone_parent_indices.resize(count)
	_global_positions.resize(count)
	_global_velocities.resize(count)
	_local_positions.resize(count)


func _on_properties_changed() -> void:
	update_gizmos()
