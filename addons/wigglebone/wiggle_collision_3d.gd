@tool
@icon("icons/wiggle_collision_3d.svg")
class_name DMWBWiggleCollision3D
extends Node3D

## Adds a collision shape for bones to collide with.
##
## Allows bones from [DMWBWiggleRotationModifier3D] or [DMWBWigglePositionModifier3D] to collide
## with this shape. This node can be placed anywhere as a descendant in a [Skeleton3D].
## [br][br]
## [b]Note:[/b] Scaling is not supported. This node, the parent [Skeleton3D], and all nodes before
## it have to be unscaled.

const Functions := preload("functions.gd")

## The collision shape for bones to collide with. Only a [SphereShape3D], [BoxShape3D],
## [CapsuleShape3D], or [CylinderShape3D] is supported at the moment. The shape properties
## [member Shape3D.custom_solver_bias] and [member Shape3D.margin] are ignored.
@export var shape: Shape3D: set = set_shape
## If [code]true[/code], the collision is disabled.
@export var disabled := false: set = set_disabled

var _area_rid: RID
var _shape_rid: RID
var _cache: DMWBCache: set = _set_cache


func _init() -> void:
	_area_rid = PhysicsServer3D.area_create()


func set_shape(value: Shape3D) -> void:
	if value == shape:
		return

	if shape:
		shape.changed.disconnect(_on_shape_changed)
	if value:
		value.changed.connect(_on_shape_changed)
	shape = value

	if is_inside_tree():
		_update_shape()

	update_gizmos()
	update_configuration_warnings()


func set_disabled(value: bool) -> void:
	disabled = value

	if _shape_rid:
		PhysicsServer3D.area_set_shape_disabled(_area_rid, 0, disabled)

	update_gizmos()


func _enter_tree() -> void:
	var skeleton := Functions.search_parent_skeleton(self)
	if skeleton:
		_cache = DMWBCache.get_for_skeleton(skeleton)

	_update_shape()


func _exit_tree() -> void:
	PhysicsServer3D.area_set_shape_disabled(_area_rid, 0, true)
	_cache = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _cache:
		warnings.append(tr(&"DMWBWiggleCollision3D must be a descendant of a Skeleton3D.", &"DMWB"))
	if not _shape_rid:
		warnings.append(tr(&"A shape must be provided. Only SphereShape3D, BoxShape3D, CapsuleShape3D, CylinderShape3D is supported.", &"DMWB"))

	return warnings


func _process(_delta: float) -> void:
	# TODO: Update once.
	PhysicsServer3D.area_set_transform(_area_rid, global_transform)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PhysicsServer3D.free_rid(_shape_rid)
		PhysicsServer3D.free_rid(_area_rid)


func _set_cache(value: DMWBCache) -> void:
	if value == _cache:
		return

	_cache = value

	if _cache:
		var space_rid := _cache.get_space()
		PhysicsServer3D.area_set_space(_area_rid, space_rid)


func _update_shape() -> void:
	if _shape_rid:
		PhysicsServer3D.free_rid(_shape_rid)
		_shape_rid = RID()

	if shape is SphereShape3D:
		_shape_rid = PhysicsServer3D.sphere_shape_create()
	elif shape is BoxShape3D:
		_shape_rid = PhysicsServer3D.box_shape_create()
	elif shape is CapsuleShape3D:
		_shape_rid = PhysicsServer3D.capsule_shape_create()
	elif shape is CylinderShape3D:
		_shape_rid = PhysicsServer3D.cylinder_shape_create()

	if _shape_rid:
		PhysicsServer3D.area_add_shape(_area_rid, _shape_rid)
		PhysicsServer3D.area_set_shape_disabled(_area_rid, 0, disabled)

	_update_shape_data()


func _update_shape_data() -> void:
	if not _shape_rid:
		return

	match PhysicsServer3D.shape_get_type(_shape_rid):
		PhysicsServer3D.SHAPE_SPHERE:
			var sphere: SphereShape3D = shape
			PhysicsServer3D.shape_set_data(_shape_rid, sphere.radius)

		PhysicsServer3D.SHAPE_BOX:
			var box: BoxShape3D = shape
			PhysicsServer3D.shape_set_data(_shape_rid, box.size * 0.5)

		PhysicsServer3D.SHAPE_CAPSULE:
			var capsule: CapsuleShape3D = shape
			PhysicsServer3D.shape_set_data(_shape_rid, {
				height = capsule.height,
				radius = capsule.radius,
			})

		PhysicsServer3D.SHAPE_CYLINDER:
			var cylinder: CylinderShape3D = shape
			PhysicsServer3D.shape_set_data(_shape_rid, {
				height = cylinder.height,
				radius = cylinder.radius,
			})


func _on_shape_changed() -> void:
	_update_shape_data()
	update_gizmos()
