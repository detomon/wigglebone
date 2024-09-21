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

# Factor is arbitary but gives useful results.
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
var _parent_bone_idx := -1
# Global bone direction.
var _global_direction := Vector3.UP
# Global mass position.
var _global_position := Vector3.ZERO
# Global angular velocity.
var _angular_velocity := Vector3.ZERO
var _should_reset := true

# TODO: Remove.
const _DEBUG_AXIS := preload("res://_debug_axis.tscn")
var _rotation_axis_mesh: Node3D


func _enter_tree() -> void:
	_setup()

	_rotation_axis_mesh = _DEBUG_AXIS.instantiate()
	add_child(_rotation_axis_mesh)
	_rotation_axis_mesh.top_level = true


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
	var skeleton_bone_pose := bone_pose
	var skeleton_parent_pose := Transform3D()

	# Bone has parent.
	if _parent_bone_idx >= 0:
		skeleton_parent_pose = skeleton.get_bone_global_pose(_parent_bone_idx)
		skeleton_bone_pose = skeleton_parent_pose * skeleton_bone_pose

	var pose_to_global := skeleton.global_transform * skeleton_bone_pose
	var pose_to_global_rotation := pose_to_global.basis.get_rotation_quaternion()
	var bone_pose_rotation := bone_pose.basis.get_rotation_quaternion()
	var bone_tail := bone_pose_rotation * Vector3.UP

	var mass_global := pose_to_global * bone_tail
	var global_velocity := (mass_global - _global_position) / delta
	_global_position = mass_global

	if _should_reset:
		_angular_velocity = Vector3.ZERO
		global_velocity = Vector3.ZERO

	var force := force_global + properties.get_gravity() # Global forces.
	force += pose_to_global_rotation * force_local # Add force relative to current pose.
	force -= global_velocity # Add reverse global velocity.

	# Add torque. Inverse inertia is simplified to inverse of bone length.
	var inv_inertia := 1.0 * properties.torque_scale
	var angular_acceleration := _global_direction.cross(force) * inv_inertia
	_angular_velocity += angular_acceleration * delta

	# Apply angular velocity.
	var velocity := _angular_velocity.length()
	if not is_zero_approx(velocity):
		var rotation_axis := _angular_velocity / velocity
		_global_direction = Quaternion(rotation_axis, velocity * delta) * _global_direction

	# Global pose target.
	var pose_target := pose_to_global_rotation * Vector3.UP
	# Torque axis where the length is the rotation difference to the pose target in radians.
	# FIXME: Add falback when pose_target.dot(_global_direction) ≈ -1.0
	var torque_axis := pose_target.cross(_global_direction).normalized()
	var torque_angle := pose_target.angle_to(_global_direction)
	var torque := torque_axis * torque_angle

	# Apply rotation spring velocity without damping. [1]
	var frequency := properties.spring_freq * TAU
	if not is_zero_approx(frequency):
		var alpha := frequency
		var x0 := torque
		var cos_ := cos(delta * alpha)
		var sin_ := sin(delta * alpha)
		var c2 := _angular_velocity / alpha

		_angular_velocity = (c2 * cos_ - x0 * sin_) * alpha
		# FIXME: Ignoring changed position results in spring loosing energy even when damping is 0.0.
		# Use _global_direction
		# var position := target + (x0 * cos_ + c2 * sin_)

	# Limit rotation and angular rotation.
	if torque_angle > properties.swing_span:
		_global_direction = pose_target.rotated(torque_axis, properties.swing_span)

		pass

	_global_direction = _global_direction.normalized()

	# Remove rotation around bone forward axis.
	_angular_velocity = Plane(_global_direction, 0.0).project(_angular_velocity)

	# Time-independent velocity damping. [2]
	var velocity_decay := properties.angular_damp * _VELOCITY_DECAY_FACTOR
	_angular_velocity *= exp(-velocity_decay * delta)

	# Get rotation relative to current pose.
	var direction_local := pose_to_global_rotation.inverse() * _global_direction
	var rotation_relative := Quaternion(Vector3.UP, direction_local) \
		if not is_equal_approx(direction_local.dot(Vector3.UP), -1.0) \
		else Quaternion(1.0, 0.0, 0.0, 0.0) # Rotate around X axis as fallback when rotation is exactly 180°.

	# Set bone rotation.
	var bone_rotation := bone_pose_rotation * rotation_relative
	skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

	# Apply bone transform to Node3D.
	bone_pose.basis = Basis(bone_rotation)
	global_transform = skeleton.global_transform * skeleton_parent_pose * bone_pose

	_rotation_axis_mesh.global_transform.origin = global_transform.origin
	_rotation_axis_mesh.global_transform.basis = Basis(Quaternion(Vector3.UP, _angular_velocity.normalized()))
	_rotation_axis_mesh.global_transform.basis *= _angular_velocity.length()

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


## Reset rotation and angular velocity.
func reset() -> void:
	_should_reset = true


## Add torque to global angular velocity.
func add_torque_impulse(torque: Vector3) -> void:
	_angular_velocity += torque


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

	var global_bone_pose := skeleton.global_transform * skeleton_bone_pose
	_global_direction = global_bone_pose.basis * Vector3.UP
	_global_position = global_bone_pose * Vector3.UP
	_should_reset = true


func _on_properties_changed() -> void:
	update_gizmos()
