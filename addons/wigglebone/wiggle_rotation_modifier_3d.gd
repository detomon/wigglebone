@tool
@icon("icons/wiggle_rotation_modifier_3d.svg")
class_name DMWBWiggleRotationModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone influencing the pose rotation.

const _SWING_LIMIT_EPSILON := 1e-4
const _DEGREES_TO_RAD := PI / 180.0

const Functions := preload("functions.gd")

## Bone names to modify.
@export var bones := PackedStringArray(): set = set_bones
## Properties which define the spring behaviour.
@export var properties: DMWBWiggleRotationProperties3D: set = set_properties

@export_group("Force", "force")
## Applies a constant global force.
@export var force_global := Vector3.ZERO
## Applies a constant force relative to the bone's pose.
@export var force_local := Vector3.ZERO

@export_group("Editor")
## Sets the distance of the editor handle on the bone's Y axis.
@export_range(0.01, 1.0, 0.01, "or_greater", "suffix:m") var handle_distance := 0.25:
	set = set_handle_distance

var _bone_indices := PackedInt32Array()
var _bone_parent_indices := PackedInt32Array()
var _global_positions := PackedVector3Array() # Global mass position.
var _global_directions := PackedVector3Array() # Global bone direction.
var _angular_velocities := PackedVector3Array() # Global angular velocity.
var _cache: DMWBCache
var _reset := true


func _enter_tree() -> void:
	var skeleton := get_skeleton()
	if skeleton:
		_cache = DMWBCache.get_for_skeleton(skeleton)

	_setup()


func _exit_tree() -> void:
	_resize_lists(0)
	_cache = null


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
		warnings.append(tr(&"DMWBWiggleRotationProperties3D resource is required.", &"DMWB"))

	return warnings


func _process_modification() -> void:
	if not _bone_indices:
		return

	var skeleton := get_skeleton()
	var colliders := _cache.get_colliders()
	var delta := 0.0

	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	# Limit delta.
	delta = clampf(delta, 0.0001, 0.1)

	var skeleton_bone_parent_global_pose := skeleton.global_transform
	var frequency := properties.spring_freq * TAU
	var has_pring := not is_zero_approx(frequency)
	var velocity_decay := properties.angular_damp
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
		var pose_to_global_rotation := pose_to_global.basis.get_rotation_quaternion()
		var global_to_pose_rotation := pose_to_global_rotation.inverse()
		var pose_global_direction := pose_to_global_rotation * Vector3.UP

		var global_position_new := pose_to_global.origin
		var global_velocity := (global_position_new - _global_positions[i]) / delta
		_global_positions[i] = global_position_new

		if _reset:
			_angular_velocities[i] = Vector3.ZERO
			global_velocity = Vector3.ZERO

		# Global forces.
		var force := global_force \
			# Add force relative to current pose.
			+ pose_to_global_rotation * force_local * properties.force_scale \
			# Add reverse global velocity.
			- global_velocity * properties.linear_scale

		# Add torque.
		var angular_acceleration := _global_directions[i].cross(force) * _DEGREES_TO_RAD
		_angular_velocities[i] += angular_acceleration * delta

		var rotation_axis := pose_global_direction.cross(_global_directions[i])
		var rotation_angle := pose_global_direction.angle_to(_global_directions[i])
		# Use fallback axis when exactly 0° or 180°.
		if rotation_axis.is_zero_approx():
			rotation_axis = pose_to_global_rotation * Vector3.RIGHT
		rotation_axis = rotation_axis.normalized()

		# Apply rotation velocity to spring without damping (see README.md).
		if has_pring:
			# Rotation axis where the length is the rotation difference to the pose in radians.
			var spring_rotation := rotation_axis * rotation_angle
			var x0 := spring_rotation
			var c2 := _angular_velocities[i] / frequency

			spring_rotation = x0 * cos_ + c2 * sin_
			_angular_velocities[i] = (c2 * cos_ - x0 * sin_) * frequency

			# FIXME: Handle wrapping around pole when rotation_angle > PI.
			rotation_angle = spring_rotation.length()
			if not is_zero_approx(rotation_angle):
				rotation_axis = spring_rotation / rotation_angle # Normalize axis.
				_global_directions[i] = pose_global_direction.rotated(rotation_axis, rotation_angle)

		# No spring tension; linear rotation.
		else:
			var velocity := _angular_velocities[i].length()
			if not is_zero_approx(velocity):
				var velocity_axis := _angular_velocities[i] / velocity
				var velocity_delta := velocity * delta
				_global_directions[i] = _global_directions[i].rotated(velocity_axis, velocity_delta)

				# FIXME: Optimize.
				rotation_axis = pose_global_direction.cross(_global_directions[i])
				rotation_angle = pose_global_direction.angle_to(_global_directions[i])
				# Use fallback axis when exactly 0° or 180°.
				if rotation_axis.is_zero_approx():
					rotation_axis = pose_to_global_rotation * Vector3.RIGHT
				rotation_axis = rotation_axis.normalized()

		# Limit rotation and angular velocity. _SWING_LIMIT_EPSILON prevents sticking to limit.
		if rotation_angle > properties.swing_span + _SWING_LIMIT_EPSILON:
			# Limit rotation.
			_global_directions[i] = pose_global_direction.rotated(rotation_axis, properties.swing_span)

			# Limit velocity when rotating towards limit
			if _angular_velocities[i].dot(rotation_axis) > 0.0:
				# Global velocity at bone tail.
				var torque_force := _angular_velocities[i].cross(_global_directions[i])
				# Limit force to tangent on swing span circle.
				torque_force = torque_force.project(rotation_axis)
				_angular_velocities[i] = _global_directions[i].cross(torque_force)

		if colliders:
			var pos := _global_positions[i]

			for collider in colliders:
				var pos_new := collider.collide(pos)
				if not pos_new.is_finite():
					continue

				# TODO: Implement.
				pos = pos_new

			_global_positions[i] = pos

		_global_directions[i] = _global_directions[i].normalized()
		# Remove rotation around bone forward axis.
		_angular_velocities[i] = Plane(_global_directions[i], 0.0).project(_angular_velocities[i])

		# Time-independent velocity damping (see README.md).
		_angular_velocities[i] *= velocity_decay_delta

		# Get rotation relative to current pose.
		var local_direction := global_to_pose_rotation * _global_directions[i]
		var rotation_relative := Quaternion(Vector3.UP, local_direction) \
			if not is_equal_approx(local_direction.dot(Vector3.UP), -1.0) \
			else Quaternion(1.0, 0.0, 0.0, 0.0) # Rotate around X axis as fallback when rotation is exactly 180°.

		# Set bone pose rotation.
		var bone_pose_rotation := skeleton.get_bone_pose_rotation(bone_idx)
		var bone_rotation := bone_pose_rotation * rotation_relative
		skeleton.set_bone_pose_rotation(bone_idx, bone_rotation)

		# Use first bone for modifier position.
		if i == 0:
			# Apply bone transform to node.
			bone_pose.basis = Basis(bone_rotation)
			global_transform = bone_parent_global_pose * bone_pose

	_reset = false


func set_properties(value: DMWBWiggleRotationProperties3D) -> void:
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


func set_handle_distance(value: float) -> void:
	handle_distance = maxf(0.0, value)
	update_gizmos()


## Resets rotation and angular velocity.
func reset() -> void:
	_reset = true


## Adds a global torque impulse.
func add_torque_impulse(torque: Vector3) -> void:
	for i in len(_angular_velocities):
		_angular_velocities[i] += torque


## Adds a global force impulse.
func add_force_impulse(force: Vector3) -> void:
	if not properties:
		return

	force *= properties.force_scale

	for i in len(_global_directions):
		var angular_acceleration := _global_directions[i].cross(force)
		# Add torque impulse.
		_angular_velocities[i] += angular_acceleration


func _setup() -> void:
	_resize_lists(0)

	var skeleton := get_skeleton()
	if not properties or not skeleton:
		return

	var count := len(bones)
	var skeleton_global_xform := skeleton.global_transform

	_resize_lists(count)

	for i in count:
		var bone_idx := skeleton.find_bone(bones[i])
		if bone_idx < 0:
			_resize_lists(0)
			break

		_bone_indices[i] = bone_idx

		var skeleton_bone_pose := skeleton.get_bone_pose(bone_idx)
		var parent_idx := skeleton.get_bone_parent(bone_idx)
		_bone_parent_indices[i] = parent_idx
		if parent_idx >= 0:
			skeleton_bone_pose = skeleton.get_bone_global_pose(parent_idx) * skeleton_bone_pose

		var global_bone_pose := skeleton_global_xform * skeleton_bone_pose
		_global_directions[i] = (global_bone_pose.basis * Vector3.UP).normalized()
		_global_positions[i] = global_bone_pose * Vector3.UP
		_angular_velocities[i] = Vector3.ZERO

	reset()

	update_configuration_warnings()


func _resize_lists(count: int) -> void:
	_bone_indices.resize(count)
	_bone_parent_indices.resize(count)
	_global_positions.resize(count)
	_global_directions.resize(count)
	_angular_velocities.resize(count)


func _on_properties_changed() -> void:
	update_gizmos()
