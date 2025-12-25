@tool
@icon("icons/wiggle_rotation_modifier_3d.svg")
class_name DMWBWiggleRotationModifier3D
extends DMWBWiggleModifier3D

## Adds jiggle physics to a bone influencing the pose rotation.

const _SWING_LIMIT_EPSILON := 1e-4
const _DEGREES_TO_RAD := PI / 180.0

## Properties which define the spring behaviour.
@export var properties: DMWBWiggleRotationProperties3D: set = set_properties

@export_group("Editor")
## Sets the distance of the editor handle on the bone's Y axis.
@export_range(0.01, 1.0, 0.01, "or_greater", "suffix:m") var handle_distance := 0.25:
	set = set_handle_distance

var _global_positions := PackedVector3Array() # Global pose positions.
var _global_directions := PackedVector3Array() # Global bone direction.
var _angular_velocities := PackedVector3Array() # Global angular velocity.


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()

	if not properties:
		warnings.append(tr(&"DMWBWiggleRotationProperties3D resource is required.", &"DMWB"))

	return warnings


func _process_modification() -> void:
	if not _bone_indices:
		return

	var delta := 0.0
	var skeleton := get_skeleton()

	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	# Limit delta.
	delta = clampf(delta, 0.0001, 0.1)

	var skeleton_bone_parent_global_pose := skeleton.global_transform
	var frequency := properties.spring_freq * TAU
	var has_spring := not is_zero_approx(frequency)
	var velocity_decay := properties.angular_damp
	var velocity_decay_delta := exp(-velocity_decay * delta)
	var global_force := (force_global + properties.get_gravity()) * properties.force_scale
	var a := frequency * delta
	var sin_ := sin(a)
	var cos_ := cos(a)

	var space_state: PhysicsDirectSpaceState3D
	var shape_query: PhysicsShapeQueryParameters3D
	if collision_enabled:
		space_state = _cache.get_space_state()
		if space_state:
			shape_query = _get_query_params()

	for i in len(_bone_indices):
		var bone_idx := _bone_indices[i]
		var parent_idx := _bone_parent_indices[i]
		var position_global := _global_positions[i]
		var direction_global := _global_directions[i]
		var angular_velocity := _angular_velocities[i]

		var bone_parent_global_pose := skeleton_bone_parent_global_pose
		if parent_idx >= 0:
			bone_parent_global_pose *= skeleton.get_bone_global_pose(parent_idx)

		var bone_pose := skeleton.get_bone_pose(bone_idx)
		var pose_to_global := bone_parent_global_pose * bone_pose
		var pose_to_global_rotation := pose_to_global.basis.get_rotation_quaternion()
		var global_to_pose_rotation := pose_to_global_rotation.inverse()
		var pose_global_direction := pose_to_global_rotation * Vector3.UP

		var global_position_new := pose_to_global.origin
		var global_velocity := (global_position_new - position_global) / delta
		position_global = global_position_new

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
		var angular_acceleration := direction_global.cross(force) * _DEGREES_TO_RAD
		angular_velocity += angular_acceleration * delta

		var rotation_axis := pose_global_direction.cross(direction_global)
		var rotation_angle := pose_global_direction.angle_to(direction_global)
		# Use fallback axis when exactly 0° or 180°.
		if rotation_axis.is_zero_approx():
			rotation_axis = pose_to_global_rotation * Vector3.RIGHT
		rotation_axis = rotation_axis.normalized()

		# Apply rotation velocity to spring without damping (see README.md).
		if has_spring:
			# Rotation axis where the length is the rotation difference to the pose in radians.
			var spring_rotation := rotation_axis * rotation_angle

			var x0 := spring_rotation
			var c2 := angular_velocity / frequency

			spring_rotation = x0 * cos_ + c2 * sin_
			angular_velocity = (c2 * cos_ - x0 * sin_) * frequency

			# FIXME: Handle wrapping around pole when rotation_angle > PI.
			rotation_angle = spring_rotation.length()
			if not is_zero_approx(rotation_angle):
				rotation_axis = spring_rotation / rotation_angle # Normalize axis.
				direction_global = pose_global_direction.rotated(rotation_axis, rotation_angle)

		# No spring tension; linear rotation.
		else:
			var velocity := angular_velocity.length()
			if not is_zero_approx(velocity):
				var velocity_axis := angular_velocity / velocity
				var velocity_delta := velocity * delta
				direction_global = direction_global.rotated(velocity_axis, velocity_delta)

				# FIXME: Optimize.
				rotation_axis = pose_global_direction.cross(direction_global)
				rotation_angle = pose_global_direction.angle_to(direction_global)
				# Use fallback axis when exactly 0° or 180°.
				if rotation_axis.is_zero_approx():
					rotation_axis = pose_to_global_rotation * Vector3.RIGHT
				rotation_axis = rotation_axis.normalized()

		# Limit rotation and angular velocity. _SWING_LIMIT_EPSILON prevents sticking to limit.
		if rotation_angle > properties.swing_span + _SWING_LIMIT_EPSILON:
			# Limit rotation.
			direction_global = pose_global_direction.rotated(rotation_axis, properties.swing_span)

			# Limit velocity when rotating towards limit
			if angular_velocity.dot(rotation_axis) > 0.0:
				# Global velocity at bone tail.
				var torque_force := angular_velocity.cross(direction_global)
				# Limit force to tangent on swing span circle.
				torque_force = torque_force.project(rotation_axis)
				angular_velocity = direction_global.cross(torque_force)

		if shape_query:
			var shape_basis := Basis(Quaternion(Vector3.UP, direction_global))
			var shape_offset := shape_basis * (Vector3.UP * collision_length * 0.5)
			var shape_origin := position_global + shape_offset
			shape_query.transform = Transform3D(shape_basis, shape_origin)

			var points := space_state.collide_shape(shape_query, 1)
			for j in range(0, len(points), 2):
				var coll_a := points[j]
				var coll_b := points[j + 1]
				var pos_delta := coll_b - coll_a
				var direction := shape_origin + pos_delta - position_global

				if not direction.is_zero_approx():
					direction_global = direction.normalized()

				# Global velocity at bone tail.
				var torque_force := angular_velocity.cross(direction_global)
				# Limit velocity if it points towards the collision surface.
				if torque_force.dot(pos_delta) < 0.0:
					torque_force = Plane(pos_delta.normalized(), 0.0).project(torque_force)
					angular_velocity = direction_global.cross(torque_force)

		direction_global = direction_global.normalized()
		# Remove rotation around bone forward axis.
		angular_velocity = Plane(direction_global, 0.0).project(angular_velocity)
		# Time-independent velocity damping.
		angular_velocity *= velocity_decay_delta

		# Get rotation relative to current pose.
		var local_direction := global_to_pose_rotation * direction_global
		var rotation_relative := Quaternion(Vector3.UP, local_direction)
		# Set bone pose rotation.
		var bone_pose_rotation := bone_pose.basis.get_rotation_quaternion()
		var bone_rotation := bone_pose_rotation * rotation_relative
		skeleton.set_bone_pose_rotation(bone_idx, bone_rotation)

		_global_positions[i] = position_global
		_global_directions[i] = direction_global
		_angular_velocities[i] = angular_velocity

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

	if is_inside_tree():
		_setup()
		update_gizmos()


func set_handle_distance(value: float) -> void:
	handle_distance = maxf(0.0, value)
	update_gizmos()


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

		_global_positions[i] = global_bone_pose * Vector3.UP
		_global_directions[i] = (global_bone_pose.basis * Vector3.UP).normalized()

	_angular_velocities.fill(Vector3.ZERO)

	super()


func _resize_lists(count: int) -> void:
	super(count)
	_global_positions.resize(count)
	_global_directions.resize(count)
	_angular_velocities.resize(count)


func _on_properties_changed() -> void:
	update_gizmos()
