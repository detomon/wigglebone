@tool
class_name DMWBCache
extends Node

static var _space_rid: RID
static var _space_state: PhysicsDirectSpaceState3D
static var _skeleton_caches := {} # Dictionary[Skeleton3D, DMWBCache]


func _physics_process(_delta: float) -> void:
	if not _space_state:
		var space := get_space()
		_space_state = PhysicsServer3D.space_get_direct_state(space)

	# Run only once.
	set_physics_process(false)


func get_space() -> RID:
	if not _space_rid.is_valid():
		_space_rid = PhysicsServer3D.space_create()

	return _space_rid


func get_space_state() -> PhysicsDirectSpaceState3D:
	if not is_instance_valid(_space_state):
		_space_state = null

	return _space_state


static func get_for_skeleton(skeleton: Skeleton3D) -> DMWBCache:
	var cache: DMWBCache = _skeleton_caches.get(skeleton)
	if cache:
		return cache

	cache = skeleton.get_node_or_null(^"DMWBCache")
	if cache:
		return cache

	cache = DMWBCache.new()
	cache.name = &"DMWBCache"
	_skeleton_caches[skeleton] = cache

	cache.tree_entered.connect(func () -> void:
		_skeleton_caches.erase(skeleton)
	, CONNECT_ONE_SHOT)

	skeleton.add_child.call_deferred(cache, true, INTERNAL_MODE_BACK)

	return cache


static func clear() -> void:
	if _space_rid.is_valid():
		PhysicsServer3D.free_rid(_space_rid)
		_space_rid = RID()
