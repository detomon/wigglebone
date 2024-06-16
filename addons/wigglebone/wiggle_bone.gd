@tool
class_name WiggleBone
extends BoneAttachment3D

## Adds jiggle physics to the bone.
##
## It reacts to animated or global motion as if it's connected with a rubber
## band to its initial position. As it reacts to acceleration instead of velocity,
## bones of constantly moving objects will not "lag behind" and have a more realistic behaviour.

## Enable WiggleBone.
@export var enabled := true: set = set_enabled
## The properties used to move the bone.
@export var properties: WiggleProperties: set = set_properties

@export_group("Const Force", "const_force")
## A constant global force.
@export var const_force_global := Vector3.ZERO
## A constant local force relative to the bone's rest pose.
@export var const_force_local := Vector3.ZERO

@export_group("Spring", "spring")

@export_range(0.0, 1.0) var spring_damping := 0.1
@export_range(0.0, 10.0, 0.01, "or_greater") var spring_frequency := 2.0

@export_group("Time")

## Sets the number of frames per second to make updates. If [code]0[/code],
## the actual frame time us used.
@export var fixed_fps := 0: set = set_fixed_fps

var const_force_gizmo := Vector3.ZERO

var _skeleton: Skeleton3D
var _bone_idx := -1
var _bone_parent_idx := -1
var _bone_rest := Transform3D()
var _bone_rest_inv := Transform3D()
var _bone_rest_rotation := Quaternion()

var _position_local := Vector3.ZERO
var _position_local_prev := Vector3.ZERO
var _rest_to_global_prev := Transform3D()

# Current rotation.
var _rotation_local := Quaternion()
# Rotation per second.
var _velocity_local := Quaternion()

var _frame_time := 0.0
var _frame_delta := 0.0
var _impulse := Vector3.ZERO
var _should_reset := true


func _ready() -> void:
	set_enabled(enabled)


func _enter_tree() -> void:
	if get_use_external_skeleton():
		var skeleton_node := get_external_skeleton()
		if skeleton_node:
			_skeleton = get_node(skeleton_node)

	else:
		_skeleton = get_parent()

	_fetch_bone(bone_name)
	reset()


func _exit_tree() -> void:
	_skeleton = null
	_bone_idx = -1
	_bone_parent_idx = -1


func _set(property: StringName, value: Variant) -> bool:
	if property == &"bone_name":
		reset()
		_fetch_bone(value)
		reset()
		update_configuration_warnings()

	return false


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not properties:
		warnings.append("WiggleProperties resource is required")

	return warnings


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"fixed_fps":
			property.hint_string = "0,60,1,suffix:FPS"


func _process(delta: float) -> void:
	if fixed_fps:
		_frame_time += delta
		delta = _frame_time
		if _frame_time >= _frame_delta:
			_frame_time = wrapf(_frame_delta, 0.0, _frame_delta)
		else:
			return

	var parent_to_skeleton := _skeleton.get_bone_global_pose(_bone_parent_idx) \
		if _bone_parent_idx >= 0 \
		else Transform3D()

	var parent_to_global := _skeleton.global_transform * parent_to_skeleton
	var rest_to_global := parent_to_global * _bone_rest

	if _should_reset:
		_rest_to_global_prev = rest_to_global
		_should_reset = false

	var transform_local_relative := _rest_to_global_prev.affine_inverse() * rest_to_global
	_rest_to_global_prev = rest_to_global

	# Test stability for varying frame rates.
	#var time := Time.get_ticks_usec()

	#var delta_test := randf_range(delta * 0.5, delta * 2.0)
	_process_rotation(transform_local_relative, delta)

	#if not Engine.is_editor_hint():
	#print("%fsec" % (float(Time.get_ticks_usec() - time) / 1_000_000.0))

	#_time += delta
	#while _time >= time_delta:
		#_process_delta(time_delta)
		#_time -= time_delta


func set_fixed_fps(value: int) -> void:
	fixed_fps = value
	_frame_time = 0.0
	_frame_delta = 1.0 / float(fixed_fps)


@export var impulse := false:
	set(value):
		_velocity_local = Quaternion.from_euler(Vector3(PI, 0.0, 0.0))


func _process_rotation(transform_local_relative: Transform3D, delta: float) -> void:
	#var position_new := transform_local_relative * _position_local
	#var position_relative := position_new - _position_local

	#_position_local -= position_relative
	#_position_local_prev = _position_local

	# .
	#var bone_forward := _position_local.normalized()
	#_position_local = bone_forward * properties.length

	## Rotate to target point relative to bone up vector.
	#var bone_rotation_relative := Quaternion(Vector3.UP, bone_forward) \
		## Check if rotation is exactly 180°.
		#if not is_equal_approx(bone_forward.dot(Vector3.DOWN), 1.0) \
		## Rotate 180° around X axis when on opposite side.
		#else Quaternion(1, 0, 0, 0)

	#_velocity_local = _rotation_local.inverse() * bone_rotation_relative
	#_velocity_local = Quaternion().slerp(_velocity_local, 1.0 / delta).normalized()
	#_rotation_local = bone_rotation_relative

	var bone_head_shift := transform_local_relative.origin
	var bone_tail := _rotation_local * (Vector3.UP * properties.length)
	var bone_tail_shift := (bone_tail + bone_head_shift).normalized() * properties.length
	var proj_position := Plane(bone_tail.normalized(), properties.length).project(bone_tail_shift)

	var acceleration := Quaternion(proj_position.normalized(), _rotation_local * Vector3.UP)
	_velocity_local *= acceleration

	var velocity_decay := remap(properties.damping, 0.0, 1.0, 0.0, 25.0)
	_velocity_local = _velocity_local.slerp(Quaternion(), 1.0 - exp(-velocity_decay * delta)).normalized()

	var stiffness_decay := remap(properties.stiffness, 0.0, 1.0, 0.0, 25.0)
	var rotation_target := _rotation_local.slerp(Quaternion(), 1.0 - exp(-stiffness_decay * delta)).normalized()
	_velocity_local *= (_rotation_local.inverse() * rotation_target)

	_rotation_local *= Quaternion().slerp(_velocity_local, delta)
	_rotation_local = _rotation_local.normalized()

	var bone_rotation := _bone_rest_rotation * _rotation_local
	_skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)

	#_spring(position, Vector3.ZERO, position, delta)


# Spring
#
# zeta = damping ratio
# omega = angular frequency
func _spring(value: Vector3, target: Vector3, velocity: Vector3, delta: float, zeta := 0.9, omega := 0.1) -> Array[Vector3]:
	if zeta >= 1.0:
		return [target, velocity]

	if zeta < 0.0:
		zeta = 0.0

	var x0 := value - target
	var omega_zeta := omega * zeta
	# TODO: Only calculate if omega or zeta changes.
	var alpha := omega * sqrt(1.0 - zeta * zeta)
	var exp := exp(-delta * omega_zeta)
	var cos := cos(delta * alpha)
	var sin := sin(delta * alpha)
	var c2 := (velocity + x0 * omega_zeta) / alpha

	var pos := target + exp * (x0 * cos + c2 * sin)
	var vel := -exp * ((x0 * omega_zeta - c2 * alpha) * cos + (x0 * alpha + c2 * omega_zeta) * sin)

	return [pos, vel]


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
	# TODO: Calculate once per frame.
	var parent_to_skeleton := _skeleton.get_bone_global_pose(_bone_parent_idx) \
		if _bone_parent_idx >= 0 \
		else Transform3D()
	var parent_to_global := _skeleton.global_transform * parent_to_skeleton
	var global_to_parent := parent_to_global.affine_inverse()

	if global:
		# Make force local to bone parent.
		impulse = global_to_parent * impulse

	_impulse = impulse


func reset() -> void:
	_rotation_local = Quaternion()
	_velocity_local = Quaternion()
	_should_reset = true

	if _skeleton:
		_skeleton.reset_bone_pose(_bone_idx)


func _update_enabled() -> void:
	var valid := _skeleton != null and _bone_idx >= 0 and properties != null
	var active := enabled and valid

	set_process(active)


func _fetch_bone(new_name: String) -> void:
	if not _skeleton:
		return

	_bone_idx = _skeleton.find_bone(new_name) if _skeleton else -1
	_bone_parent_idx = _skeleton.get_bone_parent(_bone_idx) if _bone_idx >= 0 else -1
	_bone_rest = _skeleton.get_bone_rest(_bone_idx)
	_bone_rest_inv = _bone_rest.affine_inverse()
	_bone_rest_rotation = _bone_rest.basis.get_rotation_quaternion()

	_update_enabled()


func _on_properties_changed() -> void:
	update_gizmos()


func _on_behaviour_changed() -> void:
	reset()
