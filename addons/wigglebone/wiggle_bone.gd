@tool
class_name WiggleBone
extends BoneAttachment3D

## Adds jiggle physics to the bone.
##
## It reacts to animated or global motion as if it's connected with a rubber
## band to its initial position. As it reacts to acceleration instead of velocity,
## bones of constantly moving objects will not "lag behind" and have a more realistic behaviour.

const ACCELERATION_WEIGHT := 0.5
const SOFT_LIMIT_FACTOR := 0.5

## Enable WiggleBone.
@export var enabled := true: set = set_enabled
## The properties used to move the bone.
@export var properties: WiggleProperties: set = set_properties

@export_group("Const Force", "const_force")
## A constant global force.
@export var const_force_global := Vector3.ZERO # global force
## A constant local force relative to the bone's rest pose.
@export var const_force_local := Vector3.ZERO # local force relative to bone pose

var _skeleton: Skeleton3D
var _bone_idx := -1
var _parent_bone_idx := -1
#var _global_to_pose := Basis()
var _should_reset := true
var _bone_rest := Transform3D()
var _bone_rest_inv := Transform3D()
var _bone_rest_rotation := Quaternion()
var _global_position_prev := Vector3.ZERO
var _position_global := Vector3.ZERO
var _velocity_global_prev := Vector3.ZERO
#var _velocity_global_inc := Vector3.ZERO
var _velocity_local := Vector3.ZERO
var _velocity_local_prev := Vector3.ZERO

var _debug_mesh := MeshInstance3D.new()


func _ready() -> void:
	set_enabled(enabled)

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.4, 0.4, 0.4)
	_debug_mesh.mesh = mesh
	_debug_mesh.top_level = true

	add_child(_debug_mesh)


func _enter_tree() -> void:
	if get_use_external_skeleton():
		var skeleton_node := get_external_skeleton()
		if skeleton_node:
			_skeleton = get_node(skeleton_node)

	else:
		_skeleton = get_parent()

	_fetch_bone()
	reset()


func _exit_tree() -> void:
	_skeleton = null
	_fetch_bone()


func _set(property: StringName, value: Variant) -> bool:
	if property == &"bone_name":
		reset()
		set_bone_name(value)
		_fetch_bone()
		reset()
		update_configuration_warnings()

	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append("WiggleProperties resource is required")

	return warnings


func _process(delta: float) -> void:
	# Test stability for varying frame rates.
	_process_delta(randf_range(delta * 0.5, delta * 2.0))


# TEST
func _process_delta(delta: float) -> void:
	var parent_to_skeleton := _skeleton.get_bone_global_pose(_parent_bone_idx) \
		if _parent_bone_idx >= 0 \
		else Transform3D()

	var parent_to_global := _skeleton.global_transform * parent_to_skeleton
	var global_to_parent := parent_to_global.affine_inverse()

	if _should_reset:
		var bone_tail := _bone_rest * (Vector3.UP * properties.length)
		_position_global = parent_to_global * bone_tail

	var bone_head_global := parent_to_global * _bone_rest.origin
	var bone_head_to_pos_global := _position_global - bone_head_global
	var bone_dir_global := bone_head_to_pos_global.normalized()
	var position_global_new := bone_head_global + bone_dir_global * properties.length

	#_debug_mesh.global_transform = parent_to_global
	#_debug_mesh.global_position = bone_head_global

	if _should_reset:
		_global_position_prev = position_global_new
		_should_reset = false

	var velocity_global := (position_global_new - _global_position_prev) / delta
	_global_position_prev = position_global_new

	# Apply forces.
	velocity_global += properties.gravity + const_force_global
	velocity_global += parent_to_global.basis * const_force_local

	# Frame rate independent lerp.
	var decay := remap(properties.damping, 0.0, 1.0, 0.0, 50.0)
	velocity_global = lerp(velocity_global, Vector3.ZERO, 1.0 - exp(-decay * delta))

	position_global_new += velocity_global * delta
	_position_global = position_global_new

	#var velocity_local := global_to_parent * velocity_global

	#print(velocity_global)

	# Constrain position to bone length.
	_position_global = bone_head_global + (_position_global - bone_head_global).normalized() * properties.length

	var position_local := (_bone_rest_inv * global_to_parent) * _position_global
	var bone_forward := position_local.normalized()

	# Rotate to target point relative to bone up vector.
	var bone_rotation := Quaternion(Vector3.UP, bone_forward) \
		# Check if rotation is exactly 180°.
		if not is_equal_approx(bone_forward.dot(Vector3.DOWN), 1.0) \
		# Rotate 180° around X axis when exactly on opposite side.
		else Quaternion(1, 0, 0, 0)

	_skeleton.set_bone_pose_rotation(_bone_idx, _bone_rest_rotation * bone_rotation)


#func _process_delta(delta: float) -> void:
	#var parent_to_skeleton := _skeleton.get_bone_global_pose(_parent_bone_idx) \
		#if _parent_bone_idx >= 0 \
		#else Transform3D()
#
	#var parent_to_global := _skeleton.global_transform * parent_to_skeleton
	#var global_to_parent := parent_to_global.affine_inverse()
#
	#var bone_head_global := parent_to_global * _bone_rest.origin
	#var bone_head_to_pos_global := _position_global - bone_head_global
	#bone_head_to_pos_global = bone_head_to_pos_global.normalized() * properties.length
#
	#var position_global := bone_head_global + bone_head_to_pos_global
#
	#if _should_reset:
		#_global_position_prev = position_global
		#_should_reset = false
#
	#var velocity_global := (position_global - _global_position_prev) / delta
	#_global_position_prev = position_global
#
	#velocity_global += properties.gravity + const_force_global
#
	#var acceleration := (velocity_global - _velocity_global_prev) / delta
	#_velocity_global_prev = velocity_global
	##_velocity_global_inc += acceleration * delta
	##_velocity_global_inc += properties.gravity + const_force_global
	##var decay_2 := remap(1.0, 0.0, 1.0, 0.0, 50.0)
	##_velocity_global_inc = lerp(_velocity_global_inc, Vector3.ZERO, 1.0 - exp(-decay_2 * delta))
#
	#var decay := remap(properties.damping, 0.0, 1.0, 0.0, 50.0)
	## Frame rate independent lerp.
	#velocity_global = lerp(velocity_global, Vector3.ZERO, 1.0 - exp(-decay * delta))
#
	#position_global += velocity_global * delta
	##position_global += _velocity_global_inc * delta
#
	#_position_global = position_global
	## Constrain position to bone length.
	#_position_global = bone_head_global + (_position_global - bone_head_global).normalized() * properties.length
#
	#var position_local := global_to_parent * _position_global - _bone_rest.origin
	#var bone_forward := position_local.normalized()
#
	#var bone_rotation := Quaternion(Vector3.UP, bone_forward) \
		#if not is_equal_approx(bone_forward.dot(Vector3.DOWN), 1.0) \
		#else Quaternion(1, 0, 0, 0) # 180°
#
	#_skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)


func set_enabled(value: bool) -> void:
	enabled = value
	reset()
	_update_enabled()


func set_properties(value: WiggleProperties) -> void:
	if properties:
		properties.changed.disconnect(_on_properties_changed)
		properties.behaviour_changed.disconnect(_on_behaviour_changed)

	properties = value

	if properties:
		properties.changed.connect(_on_properties_changed)
		properties.behaviour_changed.connect(_on_behaviour_changed)

	reset()
	_update_enabled()
	update_configuration_warnings()
	update_gizmos()


func apply_impulse(impulse: Vector3, global := false) -> void:
	pass

	#if global:
		#impulse = _global_to_pose * impulse

	#_point_mass.apply_force(impulse)


func reset() -> void:
	#if _skeleton:
		#_skeleton.set_bone_global_pose_override(_bone_idx, Transform3D(), 0.0)

	#_point_mass.reset()

	_should_reset = true
	#_position_local = Vector3.UP * properties.length

	if _skeleton:
		_skeleton.reset_bone_pose(_bone_idx)


#func _update_acceleration(global_bone_pose: Transform3D, delta: float) -> Vector3:
	#var mass_center := Vector3.ZERO
#
	#match properties.mode:
		#WiggleProperties.Mode.ROTATION:
			#mass_center = Vector3.UP * properties.length
#
	#mass_center = global_bone_pose * mass_center
	#var delta_mass_center := _prev_mass_center - mass_center
	#_prev_mass_center = mass_center
#
	#if _should_reset:
		#delta_mass_center = Vector3.ZERO
#
	#var global_velocity := delta_mass_center / delta
	#_acceleration = global_velocity - _prev_velocity
	#_prev_velocity = global_velocity
#
	#if _should_reset:
		#_acceleration = Vector3.ZERO
		#_should_reset = false
#
	#return _acceleration


#func _solve(global_to_local: Basis, acceleration: Vector3, delta: float) -> void:
	#var global_force := properties.gravity + const_force_global
	#var local_force := global_to_local * global_force + const_force_local
#
	#var mass_distance := properties.length
	#var local_acc := global_to_local * acceleration
#
	#match properties.mode:
		#WiggleProperties.Mode.ROTATION:
			#local_force = _project_to_vector_plane(Vector3.ZERO, mass_distance, local_force)
			#local_acc = _project_to_vector_plane(Vector3.ZERO, mass_distance, local_acc)
#
	#_point_mass.accelerate(local_acc, delta)
	#_point_mass.apply_force(local_force)
	#_point_mass.solve(properties.stiffness, properties.damping, delta)


#func _pose() -> Transform3D:
	#var pose := Transform3D()
#
	#match properties.mode:
		#WiggleProperties.Mode.ROTATION:
			#var mass_distance := properties.length
			#var angular_offset := Vector2.RIGHT.rotated(deg_to_rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			#var angular_limit := angular_offset * mass_distance
			#var k := angular_limit * SOFT_LIMIT_FACTOR
			#var mass_constrained := _clamp_length_soft(_point_mass.p, 0.0, angular_limit, k)
#
			#var mass_local := (Vector3.UP * properties.length) + mass_constrained
			#var relative_rotation := Quaternion(Vector3.UP, mass_local.normalized())
#
			#pose.basis = Basis(relative_rotation)
#
		#WiggleProperties.Mode.DISLOCATION:
			#var k := properties.max_distance * SOFT_LIMIT_FACTOR
			#var mass_constrained := _clamp_length_soft(_point_mass.p, 0.0, properties.max_distance, k)
#
			#pose.origin = mass_constrained
#
	#return pose


func _update_enabled() -> void:
	var valid := _skeleton != null and _bone_idx >= 0 and properties != null
	var active := enabled and valid

	set_physics_process(active)
	set_process(active)

	#if valid and not enabled:
		#_skeleton.set_bone_global_pose_override(_bone_idx, Transform3D(), 0.0)


func _fetch_bone() -> void:
	if _skeleton:
		_bone_idx = _skeleton.find_bone(bone_name) if _skeleton else -1
		_parent_bone_idx = _skeleton.get_bone_parent(_bone_idx) if _bone_idx >= 0 else -1
		_bone_rest = _skeleton.get_bone_rest(_bone_idx)
		_bone_rest_inv = _bone_rest.affine_inverse()
		_bone_rest_rotation = _bone_rest.basis.get_rotation_quaternion()
		_update_enabled()


func _on_properties_changed() -> void:
	update_gizmos()


func _on_behaviour_changed() -> void:
	reset()


func _project_to_vector_plane(vector: Vector3, length: float, point: Vector3) -> Vector3:
	return Plane(vector.normalized(), length).project(point)


func _clamp_length_soft(v: Vector3, min_length: float, max_length: float, k: float) -> Vector3:
	return v.normalized() * _smin(maxf(min_length, v.length()), max_length, k)


# https://iquilezles.org/articles/smin/
func _smin(a: float, b: float, k: float) -> float:
	var h := maxf(0.0, k - absf(a - b))
	return minf(a, b) - h * h / (4.0 * k)
