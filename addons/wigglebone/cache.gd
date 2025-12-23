@tool
class_name DMWBCache
extends Node

static var _space_rid: RID
static var _space_state: PhysicsDirectSpaceState3D
static var _skeleton_caches := {} # Dictionary[Skeleton3D, DMWBCache]


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		var skeleton: Skeleton3D = _skeleton_caches.find_key(self)
		_skeleton_caches.erase(skeleton)


func _physics_process(_delta: float) -> void:
	if not _space_state:
		var space := get_space()
		_space_state = PhysicsServer3D.space_get_direct_state(space)

	# Run only once.
	set_physics_process(false)


static func get_for_skeleton(skeleton: Skeleton3D) -> DMWBCache:
	if skeleton in _skeleton_caches:
		return _skeleton_caches[skeleton]

	var cache := DMWBCache.new()
	_skeleton_caches[skeleton] = cache
	skeleton.add_child.call_deferred(cache, false, Node.INTERNAL_MODE_BACK)

	return cache


func get_space() -> RID:
	if not _space_rid:
		_space_rid = PhysicsServer3D.space_create()

	return _space_rid


func get_space_state() -> PhysicsDirectSpaceState3D:
	return _space_state


static func clear() -> void:
	if _space_rid:
		PhysicsServer3D.free_rid(_space_rid)
