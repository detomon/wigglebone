@tool
class_name DMWBWiggleModifier3D
extends SkeletonModifier3D

const Functions := preload("functions.gd")

## Bone names to modify.
@export var bones := PackedStringArray(): set = set_bones

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

	return warnings


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _shape_rid:
			PhysicsServer3D.free_rid(_shape_rid)
			_shape_rid = RID()


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


func _setup() -> void:
	reset()
	update_configuration_warnings()


func _resize_lists(count: int) -> void:
	_bone_indices.resize(count)
	_bone_parent_indices.resize(count)


func _get_shape() -> RID:
	if not _shape_rid:
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
