@tool
class_name DMWBCache
extends Node

var skeleton: Skeleton3D

static var _space_rid: RID
static var _space_state: PhysicsDirectSpaceState3D
static var _skeleton_caches := {} # Dictionary[Skeleton3D, DMWBCache]

var _bone_tree_offset := PackedInt32Array()
var _bone_tree_span := PackedInt32Array()
var _bone_tree_offset_to_index := PackedInt32Array()
var _bone_tree_dirty := true


func _enter_tree() -> void:
	skeleton = get_parent() as Skeleton3D
	if skeleton:
		skeleton.bone_list_changed.connect(_on_bone_list_changed)
	_bone_tree_dirty = true


func _exit_tree() -> void:
	if skeleton:
		skeleton.bone_list_changed.disconnect(_on_bone_list_changed)
		skeleton = null


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


static func get_for_skeleton(parent_skeleton: Skeleton3D) -> DMWBCache:
	if not parent_skeleton:
		return null

	var cache: DMWBCache = _skeleton_caches.get(parent_skeleton)
	if cache:
		return cache

	cache = parent_skeleton.get_node_or_null(^"DMWBCache")
	if cache:
		return cache

	cache = DMWBCache.new()
	cache.name = &"DMWBCache"
	cache.skeleton = parent_skeleton
	_skeleton_caches[parent_skeleton] = cache

	cache.tree_entered.connect(func () -> void:
		_skeleton_caches.erase(parent_skeleton)
	, CONNECT_ONE_SHOT)

	parent_skeleton.add_child.call_deferred(cache, true, INTERNAL_MODE_BACK)

	return cache


static func clear() -> void:
	if _space_rid.is_valid():
		PhysicsServer3D.free_rid(_space_rid)
		_space_rid = RID()


func bone_get_offset(bone_idx: int) -> int:
	if _bone_tree_dirty:
		_update_bone_tree()

	return _bone_tree_offset[bone_idx]


func bone_get_span(bone_idx: int) -> int:
	if _bone_tree_dirty:
		_update_bone_tree()

	return _bone_tree_span[bone_idx]


func bone_get_index_from_tree_offset(tree_offset: int) -> int:
	if _bone_tree_dirty:
		_update_bone_tree()

	return _bone_tree_offset_to_index[tree_offset]


func _update_bone_tree() -> void:
	if not skeleton or not _bone_tree_dirty:
		return

	var bone_count := skeleton.get_bone_count()
	_bone_tree_offset.resize(bone_count)
	_bone_tree_span.resize(bone_count)
	_bone_tree_offset_to_index.resize(bone_count)

	var offset := 0
	for bone in skeleton.get_parentless_bones():
		offset += _update_bone_tree_bone(bone, offset)

	_bone_tree_dirty = false


func _update_bone_tree_bone(bone_idx: int, tree_offset: int) -> int:
	var offset := tree_offset + 1
	var span := 1

	for child_bone in skeleton.get_bone_children(bone_idx):
		var subspan := _update_bone_tree_bone(child_bone, offset)
		offset += subspan
		span += subspan

	_bone_tree_offset[bone_idx] = tree_offset
	_bone_tree_span[bone_idx] = span
	_bone_tree_offset_to_index[tree_offset] = bone_idx

	return span


func _on_bone_list_changed() -> void:
	_bone_tree_dirty = true
