@tool
class_name DMWBController
extends Node

static var _controller_skeletons := {} # Dictionary[Skeleton3D, DMWBWiggleCollision3D]

var _colliders: Array[DMWBWiggleCollision3D] = []


func _enter_tree() -> void:
	var skeleton: Skeleton3D = _controller_skeletons.find_key(self)
	_controller_skeletons.erase(skeleton)


static func get_for_skeleton(skeleton: Skeleton3D) -> DMWBController:
	if skeleton in _controller_skeletons:
		return _controller_skeletons[skeleton]

	var controller := _get_controller_in_skeleton(skeleton)
	if controller:
		return controller

	controller = DMWBController.new()
	_controller_skeletons[skeleton] = controller
	skeleton.add_child.call_deferred(controller)

	return controller


func get_colliders() -> Array[Node]:
	return []


func add_collider(collider: DMWBWiggleCollision3D) -> void:
	if collider not in _colliders:
		_colliders.append(collider)


func remove_collider(collider: DMWBWiggleCollision3D) -> void:
	_colliders.erase(collider)


static func _get_controller_in_skeleton(skeleton: Skeleton3D) -> DMWBController:
	var child_count := skeleton.get_child_count(true)
	for i in range(child_count - 1, -1, -1):
		var child := skeleton.get_child(i, true)
		if child is DMWBController:
			return child

	return null
