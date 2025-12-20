@tool
@icon("icons/wiggle_collision_3d.svg")
class_name DMWBWiggleCollision3D
extends Node3D

enum ShapeType {
	NONE,
	SPHERE,
	CAPSULE,
	BOX,
}

## Adds a collision shape for bones to collide with.
##
## Allows bones from [DMWBWiggleRotationModifier3D] or [DMWBWigglePositionModifier3D] to collide
## with this shape. This node can be placed anywhere as a descendant in a [Skeleton3D].

const _COLLISION_EPSILON := 1e-4

const Functions := preload("functions.gd")

## The collision shape for bones to collide with. Only a [BoxShape3D], [SphereShape3D], or
## [CapsuleShape3D] is supported at the moment. The shape properties [member Shape3D.custom_solver_bias]
## and [member Shape3D.margin] are ignored.
@export var shape: Shape3D: set = set_shape
## If [code]true[/code], the collision is disabled.
@export var disabled := false: set = set_disabled

var _shape_type := ShapeType.NONE
var _shape_radius := 0.0
var _cache: DMWBCache: set = _set_cache


func set_shape(value: Shape3D) -> void:
	if value == shape:
		return

	if shape:
		shape.changed.disconnect(_on_shape_changed)
	if value:
		value.changed.connect(_on_shape_changed)

	shape = value
	_update_shape()
	_register_collider()

	update_gizmos()
	update_configuration_warnings()


func set_disabled(value: bool) -> void:
	disabled = value
	_register_collider()
	update_gizmos()


func _enter_tree() -> void:
	var skeleton := Functions.search_parent_skeleton(self)
	if skeleton:
		_cache = DMWBCache.get_for_skeleton(skeleton)


func _exit_tree() -> void:
	_cache = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _cache:
		warnings.append(tr(&"DMWBWiggleCollision3D must be a descendant of a Skeleton3D.", &"DMWB"))

	if not shape:
		warnings.append(tr(&"A shape must be provided. Only BoxShape3D, SphereShape3D, or CapsuleShape3D is supported.", &"DMWB"))
	elif _shape_type == ShapeType.NONE:
		warnings.append(tr(&"Only BoxShape3D, SphereShape3D, or CapsuleShape3D is supported.", &"DMWB"))

	return warnings


func _set_cache(value: DMWBCache) -> void:
	if value == _cache:
		return

	if _cache:
		_cache.remove_collider(self)

	_cache = value
	_register_collider()


## Checks if [param point] collides with the shape surface in which case the nearest point on the
## surface is returned.[br][br]
## Returns [code]Vector3(INF, INF, INF)[/code], if no collision occurs, which
## can be checked with [method Vector3.is_finite].
func collide(point: Vector3) -> Vector3:
	var distance_sq := point.distance_squared_to(global_position)
	# No collision.
	if distance_sq >= _shape_radius * _shape_radius:
		return Vector3(INF, INF, INF)

	var distance := sqrt(distance_sq)
	var direction := (point - global_position) / distance
	point = global_position + direction * (_shape_radius + _COLLISION_EPSILON)

	return point


func _update_shape() -> void:
	if shape is BoxShape3D:
		_shape_type = ShapeType.BOX
	elif shape is SphereShape3D:
		_shape_type = ShapeType.SPHERE
	elif shape is CapsuleShape3D:
		_shape_type = ShapeType.CAPSULE
	else:
		_shape_type = ShapeType.NONE

	match _shape_type:
		ShapeType.BOX:
			var box: BoxShape3D = shape
			_shape_radius = box.size.length() * 0.5
		ShapeType.SPHERE:
			var sphere: SphereShape3D = shape
			_shape_radius = sphere.radius
		ShapeType.CAPSULE:
			var capsule: CapsuleShape3D = shape
			_shape_radius = capsule.height * 0.5


func _register_collider() -> void:
	if not _cache:
		return

	if not disabled and _shape_type != ShapeType.NONE:
		_cache.add_collider(self)
	else:
		_cache.remove_collider(self)


func _on_shape_changed() -> void:
	_update_shape()
	update_gizmos()
