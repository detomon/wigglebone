@tool
@icon("icons/node.svg")
class_name WiggleModifier3D
extends SkeletonModifier3D

## Adds jiggle physics to a bone.
##
## It reacts to animated or global motion as if it's connected with a rubber band to its initial
## position.

const SOFT_LIMIT_FACTOR := 0.5

## The bone name to animate.
@export var bone_name := "": set = set_bone_name
## The properties used to move the bone.
@export var properties: WiggleModifierProperties3D: set = set_properties

@export_group("Force", "force")
## A constant global force.
@export var force_global := Vector3.ZERO
## A constant local force relative to the bone's rest pose.
@export var force_local := Vector3.ZERO

var _bone_idx := -1
var _bone_rest_rotation := Quaternion()
var _bone_rest_position := Vector3.ZERO
var _should_reset := true

var _rotation := Quaternion()
var _velocity := Vector3.ZERO


func _enter_tree() -> void:
	_fetch_bone()


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
		warnings.append(tr(&"WiggleModifierProperties3D resource is required.", &"DMWB"))

	return warnings


"""
func _spring_no_damping(value: Vector3, target: Vector3, velocity: Vector3, delta: float, frequency: float) -> void:
	var x0 := value - target
	var alpha := frequency
	var cos_ := cos(delta * alpha)
	var sin_ := sin(delta * alpha)
	var c2 := velocity / alpha

	var pos := target + (x0 * cos_ + c2 * sin_)
	var vel := (c2 * cos_ - x0 * sin_) * alpha

	_position = pos
	_velocity = vel
"""


func _process_modification() -> void:
	if not properties or _bone_idx < 0:
		return

	var delta := 0.0
	var skeleton := get_skeleton()

	match skeleton.modifier_callback_mode_process:
		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE:
			delta = get_process_delta_time()

		Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS:
			delta = get_physics_process_delta_time()

	var force := force_global + properties.get_gravity()
	_velocity += force * delta

	var mass := _rotation * Vector3.UP
	var mass_next := (mass + _velocity * delta).normalized()
	var rotation_delta := Quaternion(mass, mass_next)

	_rotation = Quaternion(Vector3.UP, mass_next)
	_velocity = rotation_delta * _velocity
	# Limit velocity.
	_velocity = _velocity.limit_length(1.0)

	var velocity_decay := remap(properties.damping, 0.0, 1.0, 0.0, 25.0)
	_velocity *= exp(-velocity_decay * delta)

	skeleton.set_bone_pose_rotation(_bone_idx, _rotation)

	# ---

	var bone_pose := skeleton.get_bone_pose(_bone_idx)
	var parent_bone_idx := skeleton.get_bone_parent(_bone_idx)
	var parent_pose := Transform3D()

	if parent_bone_idx >= 0:
		parent_pose = skeleton.get_bone_global_pose(parent_bone_idx)
		bone_pose = parent_pose * bone_pose

	global_transform = skeleton.global_transform * bone_pose


func set_properties(value: WiggleModifierProperties3D) -> void:
	var is_editor := Engine.is_editor_hint()

	if properties:
		if is_editor:
			properties.changed.disconnect(_on_properties_changed)
		properties.behaviour_changed.disconnect(_on_behaviour_changed)

	properties = value

	if properties and is_editor:
		if is_editor:
			properties.changed.connect(_on_properties_changed)
		properties.behaviour_changed.connect(_on_behaviour_changed)

	reset()
	update_configuration_warnings()
	update_gizmos()


func set_bone_name(value: String) -> void:
	bone_name = value
	_fetch_bone()
	reset()
	update_gizmos()


func reset() -> void:
	_should_reset = true


func _fetch_bone() -> void:
	var skeleton := get_skeleton()

	_bone_idx = skeleton.find_bone(bone_name) \
		if skeleton \
		else -1

	if _bone_idx >= 0:
		var bone_rest := skeleton.get_bone_rest(_bone_idx)
		_bone_rest_rotation = bone_rest.basis.get_rotation_quaternion()
		_bone_rest_position = bone_rest.origin


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


func _on_behaviour_changed() -> void:
	reset()
