tool
extends Spatial

class_name WiggleBone

const SQRT_2: = 1.4142135624

export var enabled: = true setget set_enabled
func set_enabled(flag: bool) -> void:
	enabled = flag
	should_reset = true
	set_physics_process(enabled)

var bone_name: String setget set_bone_name
func set_bone_name(new_name: String) -> void:
	bone_name = new_name
	_fetch_bone()
	update_configuration_warning()
var properties: WiggleProperties setget set_properties
func set_properties(new_properties: WiggleProperties) -> void:
	properties = new_properties
	update_configuration_warning()

var skeleton: Skeleton
var bone_idx: = -1

var point_mass: = PointMass.new()
var should_reset: = false

func _ready() -> void:
	set_as_toplevel(true)
	set_enabled(enabled)

func _enter_tree() -> void:
	skeleton = get_parent() as Skeleton
	_fetch_bone()

func _get_property_list() -> Array:
	return [
		_get_bone_name_property(),
	{
		name = "properties",
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "WiggleProperties",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

func _get_configuration_warning() -> String:
	if not skeleton:
		return "Parent must be Skeleton"
	if bone_idx < 0:
		return "Bone name '%s' not found" % bone_name
	if not properties:
		return "WiggleProperties resource is required"
	return ""

func _physics_process(delta: float) -> void:
	if should_reset:
		pass

	if not properties:
		return

	# For testing
	skeleton = get_parent() as Skeleton
	####

	var parent_pose: = Transform()
	var parent_idx: = skeleton.get_bone_parent(bone_idx)
	if parent_idx >= 0:
		parent_pose = skeleton.get_bone_global_pose(parent_idx)
	var rest_pose: = skeleton.get_bone_rest(bone_idx)
	var global_bone_pose: = skeleton.global_transform * parent_pose * rest_pose
	var global_to_pose: = global_bone_pose.affine_inverse()
	var mass_center: = global_bone_pose * properties.mass_center

	var origin: = global_bone_pose.origin
	var mass_distance: = properties.mass_center.length()
	var local_p: = point_mass.p - global_bone_pose.origin
	var local_gravity = project_to_vector_plane(local_p, mass_distance, properties.gravity)

	point_mass.apply_force(local_gravity)
	point_mass.inertia(delta, properties.damping)
	point_mass.solve_constraint(mass_center, properties.stiffness)

	var min_distance: = mass_distance
	var max_distance: = mass_distance

	# TODO: dislocation?
	if properties.max_dislocation >= 0:
		min_distance = max(0, min_distance - properties.max_dislocation)
		max_distance = max(0, max_distance + properties.max_dislocation)

	point_mass.p = clamped_distance_to(point_mass.p, origin, min_distance, max_distance)
	point_mass.pp = clamped_distance_to(point_mass.pp, origin, min_distance, max_distance)

	var angular_limit: = (1.0 - cos(deg2rad(properties.angle_max_degrees))) * mass_distance * SQRT_2
	angular_limit += properties.max_dislocation
	point_mass.p = clamped_distance_to(point_mass.p, mass_center, 0, angular_limit)
	#point_mass.pp = clamped_distance_to(point_mass.pp, mass_center, 0, angular_limit)

	# TODO: correct axis?
	var global_x: = global_bone_pose.basis * Vector3.RIGHT
	var axis_y: = (point_mass.p - origin).normalized()
	var axis_z: = global_x.cross(axis_y).normalized()
	var axis_x: = axis_y.cross(axis_z)
	var basis: = Basis(axis_x, axis_y, axis_z)

	skeleton.set_bone_pose(bone_idx, Transform(global_to_pose.basis * basis, Vector3()))

	# TODO: remove? to draw gizmo correctly
	global_transform.basis = basis
	global_transform.origin = origin

	var mc: Spatial = $MassCenter
	mc.set_as_toplevel(true)
	mc.global_transform.origin = point_mass.p

func _get_bone_name_property() -> Dictionary:
	var show_enum: = skeleton != null
	var bone_names: = _sorted_bone_names()

	# add empty option of bone_name is invalid
	if bone_idx < 0:
		bone_names.push_front("")

	var enum_string: = PoolStringArray(bone_names).join(",")

	return {
		name = "bone_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_ENUM if show_enum else PROPERTY_HINT_NONE,
		hint_string = enum_string,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}

func _fetch_bone() -> void:
	if not skeleton:
		bone_idx = -1
		return

	bone_idx = skeleton.find_bone(bone_name)
	set_physics_process(bone_idx >= 0)

func _sorted_bone_names() -> Array:
	if not skeleton:
		return []

	var bone_names: = []

	for i in skeleton.get_bone_count():
		var bone_name: = skeleton.get_bone_name(i)
		bone_names.append(bone_name)

	bone_names.sort()

	return bone_names

static func project_to_vector_plane(vector: Vector3, length: float, point: Vector3) -> Vector3:
	var plane: = Plane(vector, length)
	return plane.project(point)

static func clamped_distance(v: Vector3, min_length: = 1.0, max_length = 1.0) -> Vector3:
	return v.normalized() * clamp(v.length(), min_length, max_length)

static func clamped_distance_to(v: Vector3, origin: Vector3, min_length: = 1.0, max_length = 1.0) -> Vector3:
	return origin + clamped_distance(v - origin, min_length, max_length)

class PointMass:
	var p: Vector3
	var pp: Vector3
	var a: Vector3

	func inertia(delta: float, damping: float) -> void:
		var dtf: = 0.5 * delta * delta
		var v: = (p - pp) * (1.0 - damping)
		var n: = p + v + a * dtf

		pp = p
		p = n
		a = Vector3()

	func solve_constraint(target: Vector3, stiffness: float) -> void:
		p += (target - p) * stiffness

	func apply_force(force: Vector3) -> void:
		a += force
