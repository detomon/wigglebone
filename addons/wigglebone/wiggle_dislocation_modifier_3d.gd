@tool
@icon("icons/wiggle_dislocation_modifier_3d.svg")
class_name WiggleDislocationModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone.
##
## It reacts to animated or global motion as if it's connected with a rubber band to its initial
## position.

# References:
#
# [1]
# Springs: From Hooke's law to a time based equation
# https://www.youtube.com/watch?v=FZekwtIO0I4
#
# [2]
# Lerp smoothing is broken
# https://www.youtube.com/watch?v=LSNQuFEDOyQ

# Factor is arbitary but gives useful results.
const _VELOCITY_DECAY_FACTOR := 25.0

const Functions := preload("functions.gd")

## The bone name to animate.
@export var bone_name := "": set = set_bone_name
## The properties used to move the bone.
@export var properties: WiggleDislocationProperties3D: set = set_properties

@export_group("Force", "force")
## A constant global force.
@export var force_global := Vector3.ZERO
## A constant local force relative to the bone's rest pose.
@export var force_local := Vector3.ZERO

var _bone_idx := -1
var _parent_bone_idx := -1
# Position in pose space.
var _local_position := Vector3.ZERO
# Global pose position.
var _global_position := Vector3.ZERO
# Global velocity.
var _global_velocity := Vector3.ZERO
var _should_reset := true


func _enter_tree() -> void:
	_setup()


func _exit_tree() -> void:
	_bone_idx = -1
	_parent_bone_idx = -1


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"bone_name":
			var skeleton := get_skeleton()
			var bone_names = Functions.get_sorted_skeleton_bones(skeleton)
			property.hint |= PROPERTY_HINT_ENUM
			property.hint_string = ",".join(bone_names)

		&"force_global", &"force_local":
			property.hint_string = &"suffix:m/s²"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append(tr(&"WiggleDislocationProperties3D resource is required.", &"DMWB"))

	return warnings


func _process_modification() -> void:
	if not properties or _bone_idx < 0:
		return

	# FIXME: Remove.
	var time := Time.get_ticks_usec()

	var skeleton := get_skeleton()
	var delta := 0.016667 # Default to 60 FPS.

	# FIXME: Better method to get the current delta?
	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	# Limit delta to prevent errors.
	delta = clampf(delta, 0.001, 0.1)

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var skeleton_bone_pose := bone_pose
	var skeleton_parent_pose := Transform3D()

	# Bone has parent.
	if _parent_bone_idx >= 0:
		skeleton_parent_pose = skeleton.get_bone_global_pose(_parent_bone_idx)
		skeleton_bone_pose = skeleton_parent_pose * skeleton_bone_pose

	var pose_to_global := skeleton.global_transform * skeleton_bone_pose
	var global_to_pose := pose_to_global.affine_inverse()

	if _should_reset:
		_local_position = Vector3.ZERO
		_global_position = pose_to_global.origin
		_global_velocity = Vector3.ZERO

	var position_global := pose_to_global * _local_position
	var parent_velocity := (position_global - _global_position) / delta

	if _should_reset:
		parent_velocity = Vector3.ZERO

	var force := force_global + properties.get_gravity() # Global forces.
	force += pose_to_global.basis * force_local # Add force relative to current pose.
	force -= parent_velocity # Add reverse global velocity.

	# Add force.
	var inv_inertia := 1.0 / properties.mass \
		if properties.mass > 0.0 \
		else 0.0
	var acceleration := force * inv_inertia
	_global_velocity += acceleration * delta

	# Apply spring velocity without damping. [1]
	var frequency := properties.frequency * TAU
	if not is_zero_approx(frequency):
		var pose_target := pose_to_global.origin

		var alpha := frequency
		var x0 := _global_position - pose_target
		var cos_ := cos(delta * alpha)
		var sin_ := sin(delta * alpha)
		var c2 := _global_velocity / alpha

		_global_position = pose_target + (x0 * cos_ + c2 * sin_)
		_global_velocity = (c2 * cos_ - x0 * sin_) * alpha

	# No spring tension. Just move the mass in global space.
	else:
		_global_position += _global_velocity * delta

	# Set local position to calculate parent speed in next iteration.
	_local_position = global_to_pose * _global_position

	# Time-independent velocity damping. [2]
	var velocity_decay := properties.damping * _VELOCITY_DECAY_FACTOR
	_global_velocity *= exp(-velocity_decay * delta)

	# Limit distance and velocity.
	var length_squared := _local_position.length_squared()
	var max_distance := properties.max_distance
	if length_squared > max_distance * max_distance:
		var global_pose_to_mass := pose_to_global.origin.direction_to(_global_position)
		# Limit position to max_distance.
		_local_position = _local_position * max_distance / sqrt(length_squared)
		# Recalculate global position.
		_global_position = pose_to_global * _local_position

		# Limit velocity when velocity points outwards.
		if global_pose_to_mass.dot(_global_velocity) > 0.0:
			# Project velocity to sphere tangent.
			_global_velocity = Plane(global_pose_to_mass, 0.0).project(_global_velocity)

	# Set bone position.
	var bone_position := bone_pose * _local_position
	skeleton.set_bone_pose_position(_bone_idx, bone_position)

	# Apply bone transform to Node3D.
	bone_pose.origin = bone_position
	global_transform = skeleton.global_transform * skeleton_parent_pose * bone_pose

	_should_reset = false

	# FIXME: Remove.
	#var time2 := Time.get_ticks_usec()
	#if get_tree().get_frame() % 60 == 0:
		#print(float(time2 - time) / 1_000_000.0)


func set_properties(value: WiggleDislocationProperties3D) -> void:
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


func reset() -> void:
	_should_reset = true


func _setup() -> void:
	if not properties:
		return

	var skeleton := get_skeleton()
	if not skeleton:
		return

	_bone_idx = skeleton.find_bone(bone_name)
	if _bone_idx < 0:
		return

	var skeleton_bone_pose := skeleton.get_bone_pose(_bone_idx)
	_parent_bone_idx = skeleton.get_bone_parent(_bone_idx)

	# Bone has parent.
	if _parent_bone_idx >= 0:
		skeleton_bone_pose = skeleton.get_bone_global_pose(_parent_bone_idx) * skeleton_bone_pose

	_global_position = skeleton.global_transform * skeleton_bone_pose.origin
	_should_reset = true


func _on_properties_changed() -> void:
	update_gizmos()
