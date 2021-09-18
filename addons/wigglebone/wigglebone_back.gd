tool
extends Spatial

export var bone_name: String setget set_bone_name
func set_bone_name(name: String) -> void:
	bone_name = name
	fetch_bone()

export var enabled: bool = true setget set_enabled
func set_enabled(flag: bool) -> void:
	enabled = flag
	if not enabled:
		init_position = true
	update_active()

var properties: WiggleProperties

var skeleton: Skeleton
var bone_idx: int = -1

# keep global position as separate value to work in editor
var position: Vector3
var prev_position: Vector3
var init_position: = true

func _ready() -> void:
	# set positioning independent of Skeleton
	set_as_toplevel(true)
	# set export vars again
	set_enabled(enabled)
	# fetch skeleton and bone
	fetch_bone()

func _get_property_list() -> Array:
	return [{
		name = "properties",
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "WiggleProperties",
		usage = PROPERTY_USAGE_DEFAULT,
	}]

func _enter_tree() -> void:
	fetch_bone()

func _exit_tree() -> void:
	skeleton = null
	update_active()

func _process(delta: float) -> void:
	if not skeleton or not properties:
		return

	# delta may be 0.0 when first initialized in editor
	if delta <= 0.0:
		return

	var local_to_world: = skeleton.global_transform
	var world_to_local: = local_to_world.affine_inverse()
	var bone_xform: = skeleton.get_bone_global_pose_no_override(bone_idx)
	var bone_global_xform: = local_to_world * bone_xform

	if init_position:
		position = bone_global_xform.origin
		prev_position = position
		init_position = false

	#var result_: = solve_point(position, prev_position, bone_global_position, delta * 0.5)
	#var result: = solve_point(result_.current, result_.prev, bone_global_position, delta * 0.5)
	var result: = solve_point(position, prev_position, bone_global_xform.origin, delta)

	position = result.current
	prev_position = result.prev
	global_transform.origin = position

	var new_bone_position: Vector3 = world_to_local * position

	skeleton.set_bone_global_pose_override(bone_idx, Transform(bone_xform.basis, new_bone_position), 1.0, true)

func _get_configuration_warning() -> String:
	if not properties:
		return "Needs WiggleProperties resource"

	if not skeleton:
		if bone_idx >= 0:
			return "Node must be child of a Skeleton"
		else:
			return "No bone found in Skeleton with name '%s'" % bone_name

	return ""

func fetch_bone() -> void:
	if get_parent() is Skeleton:
		skeleton = get_parent()
		bone_idx = skeleton.find_bone(bone_name)
	if bone_idx < 0:
		skeleton = null

	update_active()

func update_active() -> void:
	var active: = skeleton != null and enabled
	set_process(active)
	if not active:
		disable_override()

func disable_override() -> void:
	if skeleton:
		skeleton.set_bone_global_pose_override(bone_idx, Transform(), 0.0, false)

static func vector3_max(v: Vector3, m: float) -> Vector3:
	if v.length() > m:
		v = v.normalized() * m
	return v

func solve_point(from_point: Vector3, prev_position: Vector3, to_point: Vector3, delta: float) -> Dictionary:
	var props: WiggleProperties = properties
	var stiffness: = props.stiffness
	var damping: = props.damping
	var max_dist: = props.max_distance
	var dist: = from_point - to_point
	var weight: = 1.0

	if max_dist >= 0.0:
		dist = vector3_max(dist, max_dist)
		from_point = to_point + dist

	from_point -= dist * stiffness / weight
	var vel: = from_point - prev_position

	# limit velocity
	if max_dist >= 0.0:
		vel = vector3_max(vel, max_dist)

	prev_position = from_point
	from_point += vel * (1.0 - min(damping * delta * delta, 1.0))

	return {
		"current": from_point,
		"prev": prev_position,
	}

static func clamped_distance_to(v: Vector3, origin: Vector3, min_length: = 1.0, max_length = 1.0) -> Vector3:
	v -= origin
	v = v.normalized() * clamp(v.length(), min_length, max_length)
	v += origin

	return v

#class PointMass:
#	var p: Vector3
#	var pp: Vector3
#
#	func solve(new_p: Vector3, delta: float, stiffness: float, damping: float) -> void:
#		var d: = p - new_p
#		var l: = d.length()
#		p -= d * stiffness
#
#		var v: = p - pp
#		v -= v * min(damping * delta * delta, 1.0)
#
#		pp = p
#		p += v
