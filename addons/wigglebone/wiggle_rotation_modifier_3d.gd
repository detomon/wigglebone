@tool
@icon("icons/wiggle_rotation_modifier_3d.svg")
class_name DMWBWiggleRotationModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone influencing the pose rotation.

const _SWING_LIMIT_EPSILON := 1e-4
const _DEGREES_TO_RAD := PI / 180.0

const Functions := preload("functions.gd")

## Name of the bone to modify.
@export var bone_name := "":
	set = set_bone_name

## Properties used to move the bone.
@export var properties: DMWBWiggleRotationProperties3D:
	set = set_properties

@export_group("Force", "force")

## Applies a constant global force.
@export var force_global := Vector3.ZERO

## Applies a constant force relative to the bone's pose.
@export var force_local := Vector3.ZERO

@export_group("Editor")

## Sets the distance of the editor handle on the bone's Y axis.
@export_range(0.01, 1.0, 0.01, "or_greater", "suffix:m") var handle_distance := 0.1:
	set = set_handle_distance

var _bone_idx := -1
var _bone_parent_idx := -1
var _global_position := Vector3.ZERO # Global mass position.
var _global_direction := Vector3.UP # Global bone direction.
var _angular_velocity := Vector3.ZERO # Global angular velocity.
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
		warnings.append(tr(&"DMWBWiggleRotationProperties3D resource is required.", &"DMWB"))

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
	delta = clampf(delta, 0.0001, 0.1)

	var skeleton_bone_parent_global_pose := skeleton.global_transform
	if _bone_parent_idx >= 0:
		skeleton_bone_parent_global_pose *= skeleton.get_bone_global_pose(_bone_parent_idx)

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var pose_to_global := skeleton_bone_parent_global_pose * bone_pose
	var pose_to_global_rotation := pose_to_global.basis.get_rotation_quaternion()
	var global_to_pose_rotation := pose_to_global_rotation.inverse()
	var pose_global_direction := pose_to_global_rotation * Vector3.UP

	var global_position_new := pose_to_global.origin
	var global_velocity := (global_position_new - _global_position) / delta
	_global_position = global_position_new

	if _reset:
		_angular_velocity = Vector3.ZERO
		global_velocity = Vector3.ZERO

	# Global forces.
	var force := (force_global + properties.get_gravity()) * properties.force_scale
	# Add force relative to current pose.
	force += pose_to_global_rotation * force_local * properties.force_scale
	# Linear velocity.
	force -= global_velocity * properties.linear_scale

	# Add torque.
	var angular_acceleration := _global_direction.cross(force) * _DEGREES_TO_RAD
	_angular_velocity += angular_acceleration * delta

	var rotation_axis := pose_global_direction.cross(_global_direction)
	var rotation_angle := pose_global_direction.angle_to(_global_direction)
	# Use fallback axis when exactly 0° or 180°.
	if rotation_axis.is_zero_approx():
		rotation_axis = pose_to_global_rotation * Vector3.RIGHT
	rotation_axis = rotation_axis.normalized()

	# Apply rotation spring velocity without damping (see README.md).
	var frequency := properties.spring_freq * TAU
	if not is_zero_approx(frequency):
		# Rotation axis where the length is the rotation difference to the pose in radians.
		var spring_rotation := rotation_axis * rotation_angle

		var x0 := spring_rotation
		var a := delta * frequency
		var cos_ := cos(a)
		var sin_ := sin(a)
		var c2 := _angular_velocity / frequency

		spring_rotation = x0 * cos_ + c2 * sin_
		_angular_velocity = (c2 * cos_ - x0 * sin_) * frequency

		# FIXME: Handle wrapping around pole when rotation_angle > PI.
		rotation_angle = spring_rotation.length()
		if not is_zero_approx(rotation_angle):
			rotation_axis = spring_rotation / rotation_angle # Normalize axis.
			_global_direction = pose_global_direction.rotated(rotation_axis, rotation_angle)

	# No spring tension; linear rotation.
	else:
		var velocity := _angular_velocity.length()
		if not is_zero_approx(velocity):
			var velocity_axis := _angular_velocity / velocity
			var velocity_delta := velocity * delta
			_global_direction = _global_direction.rotated(velocity_axis, velocity_delta)

			# FIXME: Optimize.
			rotation_axis = pose_global_direction.cross(_global_direction)
			rotation_angle = pose_global_direction.angle_to(_global_direction)
			# Use fallback axis when exactly 0° or 180°.
			if rotation_axis.is_zero_approx():
				rotation_axis = pose_to_global_rotation * Vector3.RIGHT
			rotation_axis = rotation_axis.normalized()

	# Limit rotation and angular velocity. _SWING_LIMIT_EPSILON prevents sticking to limit.
	if rotation_angle > properties.swing_span + _SWING_LIMIT_EPSILON:
		# Limit rotation.
		_global_direction = pose_global_direction.rotated(rotation_axis, properties.swing_span)

		# Limit velocity when rotating towards limit
		if _angular_velocity.dot(rotation_axis) > 0.0:
			# Global velocity at bone tail.
			var torque_force := _angular_velocity.cross(_global_direction)
			# Limit force to tangent on swing span circle.
			torque_force = torque_force.project(rotation_axis)
			_angular_velocity = _global_direction.cross(torque_force)

	_global_direction = _global_direction.normalized()
	# Remove rotation around bone forward axis.
	_angular_velocity = Plane(_global_direction, 0.0).project(_angular_velocity)

	# Time-independent velocity damping (see README.md).
	var velocity_decay := properties.angular_damp
	_angular_velocity *= exp(-velocity_decay * delta)

	# Get rotation relative to current pose.
	var local_direction := global_to_pose_rotation * _global_direction
	var rotation_relative := Quaternion(Vector3.UP, local_direction) \
		if not is_equal_approx(local_direction.dot(Vector3.UP), -1.0) \
		else Quaternion(1.0, 0.0, 0.0, 0.0) # Rotate around X axis as fallback when rotation is exactly 180°.

	# Set bone pose rotation.
	var bone_pose_rotation := skeleton.get_bone_pose_rotation(_bone_idx)
	var bone_rotation := bone_pose_rotation * rotation_relative
	skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

	# Apply bone transform to node.
	bone_pose.basis = Basis(bone_rotation)
	global_transform = skeleton_bone_parent_global_pose * bone_pose

	_reset = false


func set_properties(value: DMWBWiggleRotationProperties3D) -> void:
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


func set_handle_distance(value: float) -> void:
	handle_distance = maxf(0.0, value)
	update_gizmos()


## Reset rotation and angular velocity.
func reset() -> void:
	_reset = true


## Add a global torque impulse.
func add_torque_impulse(torque: Vector3) -> void:
	_angular_velocity += torque


## Add a global force impulse.
func add_force_impulse(force: Vector3) -> void:
	if not properties:
		return

	force *= properties.force_scale
	var angular_acceleration := _global_direction.cross(force)
	add_torque_impulse(angular_acceleration)


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

	var global_bone_pose := skeleton.global_transform * skeleton_bone_pose
	_global_direction = (global_bone_pose.basis * Vector3.UP).normalized()
	_global_position = global_bone_pose * Vector3.UP
	_angular_velocity = Vector3.ZERO

	reset()


func _on_properties_changed() -> void:
	update_gizmos()
