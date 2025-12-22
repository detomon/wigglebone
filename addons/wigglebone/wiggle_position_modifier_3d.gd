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

@export_group("Collision", "collision")
## If [code]true[/code], collision is enabled and all [member bones] collide with [DMWBWiggleCollision3D]
## nodes in the same [Skeleton3D]. The bone collision shape is always a capsule.
@export var collision_enabled := false
## Defines the length of the bone capsule shape used for all [member bones].
@export_range(0, 1, 0.01, "or_greater", "suffix:m") var collision_length := 0.2: set = set_collision_length
## Defines the radius of the bone capsule shape used for all [member bones].
@export_range(0, 1, 0.01, "or_greater", "suffix:m") var collision_radius := 0.1: set = set_collision_radius

var _bone_indices := PackedInt32Array()
var _bone_parent_indices := PackedInt32Array()
var _global_positions := PackedVector3Array() # Global pose positions.
var _global_velocities := PackedVector3Array() # Global velocities.
var _local_positions := PackedVector3Array() # Positions in pose space.
var _cache: DMWBCache
var _shape_rid: RID
var _query_params: PhysicsShapeQueryParameters3D
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
		warnings.append(tr(&"DMWBWigglePositionProperties3D resource is required.", &"DMWB"))

	return warnings


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PhysicsServer3D.free_rid(_shape_rid)
		_shape_rid = RID()


func _process_modification() -> void:
	if not _bone_indices:
		return

	var space_state: PhysicsDirectSpaceState3D
	var shape_query: PhysicsShapeQueryParameters3D
	if collision_enabled:
		space_state = _cache.get_space_state()
		if space_state:
			shape_query = _get_query_params()

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

		if shape_query:
			var query_xform := pose_to_global
			query_xform.origin = _global_positions[i] + query_xform * (Vector3.UP * collision_length * 0.5)
			shape_query.transform = query_xform

			var points := space_state.collide_shape(shape_query, 2)
			for j in range(0, len(points), 2):
				var coll_a := points[j]
				var coll_b := points[j + 1]
				var pos_old := _global_positions[i]
				var pos_new := pos_old + (coll_b - coll_a)
				var pos_delta := pos_new - pos_old

				# Limit velocity if it points towards the collision surface.
				var velocity := _global_velocities[i]
				if pos_delta.dot(velocity) < 0.0:
					velocity = Plane(pos_delta.normalized(), 0.0).project(velocity)
					_global_velocities[i] = velocity

				_global_positions[i] = pos_new

		# Set local position to calculate parent speed in next iteration.
		_local_positions[i] = global_to_pose * _global_positions[i]
		# Time-independent velocity damping.
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


func set_collision_length(value: float) -> void:
	collision_length = maxf(0.0, value)
	_update_shape()


func set_collision_radius(value: float) -> void:
	collision_radius = maxf(0.0, value)
	_update_shape()


## Resets position and velocity.
func reset() -> void:
	_reset = true


## Adds a global force impulse.
func add_force_impulse(force: Vector3) -> void:
	for i in len(_global_velocities):
		_global_velocities[i] += force


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

		_global_positions[i] = skeleton_global_xform * skeleton_bone_pose.origin
		_global_velocities[i] = Vector3.ZERO
		_local_positions[i] = Vector3.ZERO

	reset()
	update_configuration_warnings()


func _resize_lists(count: int) -> void:
	_bone_indices.resize(count)
	_bone_parent_indices.resize(count)
	_global_positions.resize(count)
	_global_velocities.resize(count)
	_local_positions.resize(count)


func _get_shape() -> RID:
	if not _shape_rid.is_valid():
		_shape_rid = PhysicsServer3D.capsule_shape_create()

	return _shape_rid


func _get_query_params() -> PhysicsShapeQueryParameters3D:
	if not _query_params:
		_query_params = PhysicsShapeQueryParameters3D.new()
		_query_params.collide_with_areas = true
		_query_params.collide_with_bodies = false
		_query_params.shape_rid = _get_shape()

	return _query_params


func _update_shape() -> void:
	var shape_rid := _get_shape()
	PhysicsServer3D.shape_set_data(shape_rid, {
		height = collision_length,
		radius = collision_radius,
	})


func _on_properties_changed() -> void:
	update_gizmos()
