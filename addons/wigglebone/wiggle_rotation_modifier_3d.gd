@tool
@icon("icons/wiggle_rotation_modifier_3d.svg")
class_name WiggleRotationModifier3D
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

## The bone name to modify.
@export var bone_name := "": set = set_bone_name
## The properties used to rotate the bone.
@export var properties: WiggleRotationProperties3D: set = set_properties

@export_group("Force", "force")
## A constant global force.
@export var force_global := Vector3.ZERO
## A constant force relative to the bone pose.
@export var force_local := Vector3.ZERO

var _bone_idx := -1
# Global mass position.
var _mass_position := Vector3.ZERO
# Global bone direction.
var _direction := Vector3.UP
# Global angular velocity.
var _angular_velocity := Vector3.ZERO
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
		warnings.append(tr(&"WiggleRotationProperties3D resource is required.", &"DMWB"))

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
	var global_global_bone_rotation := global_global_bone_pose.basis.get_rotation_quaternion()
	var bone_pose_rotation := bone_pose.basis.get_rotation_quaternion()
	var bone_pose_forward := bone_pose_rotation * Vector3.UP

	var mass_global := global_global_bone_pose * (bone_pose_forward * properties.length)
	var mass_velocity := (mass_global - _mass_position) / delta
	_mass_position = mass_global

	if _should_reset:
		_angular_velocity = Vector3.ZERO
		mass_velocity = Vector3.ZERO

	# Global forces.
	var force := force_global + properties.get_gravity()
	# Add force relative to current pose.
	force += global_global_bone_rotation * force_local
	# Add reverse global velocity.
	force -= mass_velocity

	# Add torque.
	# Inverse inertia is simplified to inverse of bone length.
	var inv_inertia := 1.0 / properties.length \
		if properties.length > 0.0 \
		else 1.0
	var angular_acceleration := _direction.cross(force) * inv_inertia
	_angular_velocity += angular_acceleration * delta

	# Apply angular velocity.
	var velocity := _angular_velocity.length()
	if not is_zero_approx(velocity):
		var rotation_axis := _angular_velocity / velocity
		_direction = Quaternion(rotation_axis, velocity * delta) * _direction

	# Apply spring velocity without damping. [1]
	var frequency := properties.frequency * TAU
	if not is_zero_approx(frequency):
		var bone_target := global_global_bone_rotation * Vector3.UP
		# Rotation axis where the length is the rotation in radians.
		var rotation_axis := bone_target.cross(_direction).normalized()
		rotation_axis *= bone_target.angle_to(_direction)

		var alpha := frequency
		var x0 := rotation_axis
		var cos_ := cos(delta * alpha)
		var sin_ := sin(delta * alpha)
		var c2 := _angular_velocity / alpha

		_angular_velocity = (c2 * cos_ - x0 * sin_) * alpha
		# FIXME: Ignoring changed position results in spring loosing energy even when damping is 0.0.
		# var position := target + (x0 * cos_ + c2 * sin_)

	_direction = _direction.normalized()

	# Remove rotation around bone forward axis.
	# TODO: Limit _angular_velocity?
	_angular_velocity = Plane(_direction, 0.0).project(_angular_velocity)

	# Time-independent velocity damping.
	# Factor is arbitary but gives useful results. [2]
	var velocity_decay := properties.damping * _VELOCITY_DECAY_FACTOR
	_angular_velocity *= exp(-velocity_decay * delta)

	var direction_local := global_global_bone_rotation.inverse() * _direction
	var rotation_relative := Quaternion(Vector3.UP, direction_local) \
		if not is_equal_approx(direction_local.dot(Vector3.UP), -1.0) \
		# Rotate around X axis when rotation is exactly 180°.
		else Quaternion(1.0, 0.0, 0.0, 0.0)

	# Set bone rotation.
	var bone_rotation := bone_pose_rotation * rotation_relative
	skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

	# Apply bone transform to Node3D.
	bone_pose.basis = Basis(bone_rotation)
	global_transform = skeleton.global_transform * global_parent_pose * bone_pose

	_should_reset = false

	# FIXME: Remove.
	#var time2 := Time.get_ticks_usec()
	#if get_tree().get_frame() % 60 == 0:
		#print(float(time2 - time) / 1_000_000.0)


func set_properties(value: WiggleRotationProperties3D) -> void:
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

	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var bone_pose := skeleton.get_bone_pose(_bone_idx)

	# Bone has parent.
	if parent_bone_idx >= 0:
		bone_pose = skeleton.get_bone_global_pose(parent_bone_idx) * bone_pose

	_direction = bone_pose.basis * Vector3.UP
	_mass_position = bone_pose * (Vector3.UP * properties.length)
	_should_reset = true


func _on_properties_changed() -> void:
	update_gizmos()
