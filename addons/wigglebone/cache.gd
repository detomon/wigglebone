@tool
class_name DMWBCache
extends Node

static var _space: RID
static var _space_state: PhysicsDirectSpaceState3D
static var _skeleton_caches := {} # Dictionary[Skeleton3D, DMWBCache]


func _enter_tree() -> void:
	var skeleton: Skeleton3D = _skeleton_caches.find_key(self)
	_skeleton_caches.erase(skeleton)


# Run once.
func _physics_process(_delta: float) -> void:
	if not _space_state:
		var space := get_space()
		_space_state = PhysicsServer3D.space_get_direct_state(space)
		set_physics_process(false)


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


func get_space() -> RID:
	if not _space:
		_space = PhysicsServer3D.space_create()
	return _space


func get_space_state() -> PhysicsDirectSpaceState3D:
	return _space_state
