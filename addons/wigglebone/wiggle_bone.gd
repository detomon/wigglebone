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


#var _time := 0.0
#@export var time_delta := 1.0 / 30.0

func _process(delta: float) -> void:
	# Test stability for varying frame rates.
	#var time := Time.get_ticks_usec()
	_process_delta(randf_range(delta * 0.5, delta * 2.0))
	#print("%fsec" % (float(Time.get_ticks_usec() - time) / 1_000_000.0))

	#_time += delta
	#while _time >= time_delta:
		#_process_delta(time_delta)
		#_time -= time_delta


@export var impulse := false:
	set(value):
		apply_impulse(Vector3(1.0, 0.0, 0.0))


func _process_delta(delta: float) -> void:
	var parent_to_skeleton := _skeleton.get_bone_global_pose(_bone_parent_idx) \
		if _bone_parent_idx >= 0 \
		else Transform3D()

	var parent_to_global := _skeleton.global_transform * parent_to_skeleton
	var rest_to_global := parent_to_global * _bone_rest

	if _should_reset:
		_rest_to_global_prev = rest_to_global

	var transform_local_relative := _rest_to_global_prev.affine_inverse() * rest_to_global
	_rest_to_global_prev = rest_to_global

	if _should_reset:
		_position_local = Vector3.UP * properties.length
		_position_local_prev = _position_local
		_should_reset = false

	var position_new := transform_local_relative * _position_local
	var position_relative := position_new - _position_local

	_position_local -= position_relative

	var velocity := (_position_local - _position_local_prev) / delta
	_position_local_prev = _position_local

	var velocity_decay := remap(properties.damping, 0.0, 1.0, 0.0, 25.0)
	velocity = lerp(velocity, Vector3.ZERO, 1.0 - exp(-velocity_decay * delta))

	_position_local += velocity * delta

	var bone_forward := _position_local.normalized()
	_position_local = bone_forward * properties.length

	# Rotate to target point relative to bone up vector.
	var bone_rotation_relative := Quaternion(Vector3.UP, bone_forward) \
		# Check if rotation is exactly 180°.
		if not is_equal_approx(bone_forward.dot(Vector3.DOWN), 1.0) \
		# Rotate 180° around X axis when on opposite side.
		else Quaternion(1, 0, 0, 0)

	var bone_rotation := _bone_rest_rotation * bone_rotation_relative
	_skeleton.set_bone_pose_rotation(_bone_idx, bone_rotation)


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
	_should_reset = true

	if _skeleton:
		_skeleton.reset_bone_pose(_bone_idx)


func _update_enabled() -> void:
	var valid := _skeleton != null and _bone_idx >= 0 and properties != null
	var active := enabled and valid

	set_physics_process(active)
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
