@tool
@icon("icons/node_spring.svg")
class_name WiggleRotationModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone.
##
## It reacts to animated or global motion as if it's connected with a rubber band to its initial
## position.

const VELOCITY_DECAY_FACTOR := 25.0

## The bone name to animate.
@export var bone_name := "": set = set_bone_name
## The properties used to move the bone.
@export var properties: WiggleRotationProperties3D: set = set_properties

@export_group("Force", "force")
## A constant global force.
@export var force_global := Vector3.ZERO
## A constant local force relative to the bone's rest pose.
@export var force_local := Vector3.ZERO

var _bone_idx := -1
var _mass_position := Vector3.ZERO # Global mass position.
var _direction := Vector3.UP # Rotation relative to parent bone.
var _angular_velocity := Vector3.ZERO
var _should_reset := true


func _enter_tree() -> void:
	_fetch_bone()
	_setup()


func _exit_tree() -> void:
	_bone_idx = -1
	reset()


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"bone_name":
			var bone_names = _get_sorted_skeleton_bones()
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
	var delta := 0.016667

	# FIXME: Is there a better method to get the current delta?
	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var global_bone_pose := bone_pose
	var global_parent_pose := Transform3D()

	# Bone is not a root bone.
	if parent_bone_idx >= 0:
		global_parent_pose = skeleton.get_bone_global_pose(parent_bone_idx)
		global_bone_pose = global_parent_pose * global_bone_pose

	var global_bone_xform := skeleton.global_transform * global_parent_pose
	var global_to_parent := global_bone_xform.basis.inverse()

	var mass_global := global_bone_xform * (Vector3.UP * properties.length)
	var mass_velocity := (_mass_position - mass_global) / delta
	_mass_position = mass_global

	if _should_reset:
		mass_velocity = Vector3.ZERO
		_angular_velocity = Vector3.ZERO
		_should_reset = false

	# Global forces.
	var force := force_global + properties.get_gravity()
	# Add global velocity.
	force += mass_velocity
	# Add force relative to current pose.
	var global_bone_rotation := global_bone_pose.basis.get_rotation_quaternion()
	force += global_bone_rotation * force_local

	var rotation_axis = Vector3.ZERO
	var velocity := _angular_velocity.length()

	# Apply angular velocity.
	if not is_zero_approx(velocity):
		rotation_axis = _angular_velocity / velocity
		_direction = Quaternion(rotation_axis, velocity * delta) * _direction

	var bone_rest := bone_pose.basis * Vector3.UP
	var bone_value := _direction.cross(bone_rest)
	var frequency := properties.frequency * TAU

	if not is_zero_approx(frequency):
		var value := Vector3.ZERO
		var target := bone_value
		var x0 := value - target
		var alpha := frequency
		var cos_ := cos(delta * alpha)
		var sin_ := sin(delta * alpha)
		var c2 := _angular_velocity / alpha

		var pos := target + (x0 * cos_ + c2 * sin_)
		var vel := (c2 * cos_ - x0 * sin_) * alpha

		_angular_velocity = vel

	_direction = _direction.normalized()

	# Add torque.
	# Inverse inertia is simplified to inverse of bone length.
	var inv_inertia := 1.0 / properties.length \
		if properties.length > 0.0 \
		else 1.0
	var force_pose := global_to_parent * force
	var angular_acceleration := _direction.cross(force_pose) * inv_inertia
	_angular_velocity += angular_acceleration * delta

	# Remove rotation around bone forward axis.
	_angular_velocity = Plane(_direction, 0.0).project(_angular_velocity)

	# Time-independent velocity damping.
	# Factor is arbitary but gives useful results.
	var velocity_decay := properties.damping * VELOCITY_DECAY_FACTOR
	_angular_velocity *= exp(-velocity_decay * delta)

	var bone_rotation := Quaternion(Vector3.UP, _direction) \
		if not is_equal_approx(_direction.dot(Vector3.DOWN), 1.0) \
		# Rotate around X axis when rotation is exactly 180°.
		else Quaternion(1.0, 0.0, 0.0, 0.0)

	# Set bone pose rotation.
	skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

	# Apply bone transform to Node3D.
	bone_pose.basis = Basis(bone_rotation)
	global_transform = skeleton.global_transform * global_parent_pose * bone_pose

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

	reset()
	update_gizmos()
	update_configuration_warnings()


func set_bone_name(value: String) -> void:
	bone_name = value
	_fetch_bone()
	reset()
	update_gizmos()


func reset() -> void:
	_should_reset = true


func _setup() -> void:
	if _bone_idx < 0:
		return

	var skeleton := get_skeleton()
	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var global_bone_pose := bone_pose
	var global_parent_pose := Transform3D()

	# Bone is not a root bone.
	if parent_bone_idx >= 0:
		global_parent_pose = skeleton.get_bone_global_pose(parent_bone_idx)
		global_bone_pose = global_parent_pose * global_bone_pose

	_direction = bone_pose.basis.get_rotation_quaternion() * Vector3.UP

	var mass_global := skeleton.global_transform * global_bone_pose * (Vector3.UP * properties.length)
	_mass_position = mass_global


func _fetch_bone() -> void:
	var skeleton := get_skeleton()

	_bone_idx = skeleton.find_bone(bone_name) \
		if skeleton \
		else -1


func _get_sorted_skeleton_bones() -> PackedStringArray:
	var skeleton := get_skeleton()
	if not skeleton:
		return []

	var bone_names = []
	var bone_count := skeleton.get_bone_count()

	bone_names.resize(bone_count)
	for i in bone_count:
		bone_names[i] = skeleton.get_bone_name(i)

	bone_names.sort_custom(func (a: String, b: String) -> bool:
		return a.naturalcasecmp_to(b) < 0
	)

	return PackedStringArray(bone_names)


func _on_properties_changed() -> void:
	update_gizmos()
