@tool
@icon("icons/wiggle_collision_3d.svg")
class_name DMWBWiggleCollision3D
extends Node3D

const Functions := preload("functions.gd")

## The collision shape. Only [BoxShape3D], [SphereShape3D], or [CapsuleShape3D] is supported.
## The shape properties [code]custom_solver_bias[/code] and [code]margin[/code] are ignored.
@export var shape: Shape3D: set = set_shape

var _controller: DMWBController: set = _set_collider


func set_shape(value: Shape3D) -> void:
	if value == shape:
		return

	if Engine.is_editor_hint():
		if shape:
			shape.changed.disconnect(_on_shape_changed)
		if value:
			value.changed.connect(_on_shape_changed)

	shape = value

	if _controller:
		if is_valid_shape():
			_controller.add_collider(self)
		else:
			_controller.remove_collider(self)

	update_gizmos()
	update_configuration_warnings()


func _enter_tree() -> void:
	var skeleton := Functions.search_parent_skeleton(self)
	if skeleton:
		_controller = DMWBController.get_for_skeleton(skeleton)


func _exit_tree() -> void:
	_controller = null


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if not _controller:
		warnings.append(tr(&"DMWBWiggleCollision3D must be a descendant of a Skeleton3D.", &"DMWB"))

	if not shape:
		warnings.append(tr(&"A shape must be provided. Only BoxShape3D, SphereShape3D, or CapsuleShape3D is supported.", &"DMWB"))
	elif not is_valid_shape():
		warnings.append(tr(&"Only BoxShape3D, SphereShape3D, or CapsuleShape3D is supported.", &"DMWB"))

	return warnings


func is_valid_shape() -> bool:
	return shape is BoxShape3D or shape is SphereShape3D or shape is CapsuleShape3D


func _set_collider(value: DMWBController) -> void:
	if value == _controller:
		return

	if _controller:
		_controller.remove_collider(self)
	if value:
		value.add_collider(self)

	_controller = value


func _on_shape_changed() -> void:
	update_gizmos()
