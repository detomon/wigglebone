@tool
class_name DMWBCache
extends Node

static var _space: RID
static var _space_state: PhysicsDirectSpaceState3D
static var _skeleton_caches := {} # Dictionary[Skeleton3D, DMWBCache]

var _area_rid: RID
var _colliders: Array[DMWBWiggleCollision3D] = []


func _init() -> void:
	_space = get_space()
	_area_rid = PhysicsServer3D.area_create()
	PhysicsServer3D.area_set_space(_area_rid, _space)

	add_to_group(&"DMWBCache")


func _enter_tree() -> void:
	var skeleton: Skeleton3D = _skeleton_caches.find_key(self)
	_skeleton_caches.erase(skeleton)


# Run once.
func _physics_process(_delta: float) -> void:
	if not _space_state:
		var space := get_space()
		_space_state = PhysicsServer3D.space_get_direct_state(space)
		set_physics_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		PhysicsServer3D.free_rid(_area_rid)
		_area_rid = RID()


static func get_for_skeleton(skeleton: Skeleton3D) -> DMWBCache:
	if skeleton in _skeleton_caches:
		return _skeleton_caches[skeleton]

	var cache: DMWBCache
	var child_count := skeleton.get_child_count(true)
	for i in range(child_count - 1, -1, -1):
		var child := skeleton.get_child(i, true)
		if child is DMWBCache:
			cache = child
			break

	if cache:
		return cache

	cache = DMWBCache.new()
	_skeleton_caches[skeleton] = cache
	skeleton.add_child.call_deferred(cache)

	return cache


func get_area() -> RID:
	return _area_rid


func get_space() -> RID:
	if not _space:
		_space = PhysicsServer3D.space_create()
	return _space


func get_space_state() -> PhysicsDirectSpaceState3D:
	return _space_state


func get_colliders() -> Array[DMWBWiggleCollision3D]:
	return _colliders


func add_collider(collider: DMWBWiggleCollision3D) -> void:
	if not collider or collider in _colliders:
		return

	_colliders.append(collider)


func remove_collider(collider: DMWBWiggleCollision3D) -> void:
	_colliders.erase(collider)
