@tool
@icon("icons/node_spring.svg")
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
# Local position.
var _position := Vector3.ZERO
# Global mass position.
var _mass_position := Vector3.ZERO
# Global velocity.
var _velocity := Vector3.ZERO
var _should_reset := true


func _enter_tree() -> void:
	_setup()


func _exit_tree() -> void:
	_bone_idx = -1


func _set(property: StringName, _value: Variant) -> bool:
	match property:
		&"active":
			reset()
			_setup()

	return false


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
	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var global_bone_pose := bone_pose
	var global_parent_pose := Transform3D()

	# Bone has parent.
	if parent_bone_idx >= 0:
		global_parent_pose = skeleton.get_bone_global_pose(parent_bone_idx)
		global_bone_pose = global_parent_pose * global_bone_pose

	var global_global_bone_pose := skeleton.global_transform * global_bone_pose
	var global_to_pose := global_global_bone_pose.affine_inverse()

	if _should_reset:
		_velocity = Vector3.ZERO

	var pose_mass := global_to_pose * _mass_position
	pose_mass = pose_mass.limit_length(properties.max_distance)
	_mass_position = global_global_bone_pose * pose_mass

	var mass_global := global_global_bone_pose.origin
	var mass_velocity := (mass_global - _mass_position) / delta

	if _should_reset:
		mass_velocity = Vector3.ZERO

	# Global forces.
	var force := force_global + properties.get_gravity()
	# Add force relative to current pose.
	force += global_global_bone_pose.basis * force_local
	# Add reverse global velocity.
	force -= mass_velocity

	# Add force.
	# TODO: Set mass.
	var mass := 1.0
	var inv_inertia := 1.0 / mass \
		if mass > 0.0 \
		else 1.0
	var acceleration := force * inv_inertia
	_velocity += acceleration * delta

	var frequency := properties.frequency * TAU

	# Apply spring velocity without damping. [1]
	if not is_zero_approx(frequency):
		var target := global_global_bone_pose.origin

		var alpha := frequency
		var x0 := _mass_position - target
		var cos_ := cos(delta * alpha)
		var sin_ := sin(delta * alpha)
		var c2 := _velocity / alpha

		_mass_position = target + (x0 * cos_ + c2 * sin_)
		_velocity = (c2 * cos_ - x0 * sin_) * alpha

	# Time-independent velocity damping.
	# Factor is arbitary but gives useful results. [2]
	var velocity_decay := properties.damping * _VELOCITY_DECAY_FACTOR
	_velocity *= exp(-velocity_decay * delta)

	var position_relative := global_to_pose * _mass_position
	# Set bone position.
	var bone_position := bone_pose * position_relative
	skeleton.set_bone_pose_position(_bone_idx, bone_position)

	# Apply bone transform to Node3D.
	bone_pose.origin = bone_position
	global_transform = skeleton.global_transform * global_parent_pose * bone_pose

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

	reset()
	update_configuration_warnings()
	update_gizmos()


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

	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var bone_pose := skeleton.get_bone_pose(_bone_idx)

	# Bone has parent.
	if parent_bone_idx >= 0:
		bone_pose = skeleton.get_bone_global_pose(parent_bone_idx) * bone_pose

	_mass_position = bone_pose.origin
	_should_reset = true


func _on_properties_changed() -> void:
	update_gizmos()
