tool
extends Spatial
class_name WiggleBone

const PRECALCULATE_ITERATIONS: = 10

export var enabled: = true setget set_enabled
func set_enabled(flag: bool) -> void:
	enabled = flag
	should_reset = true
	_update_enabled()

var bone_name: String setget set_bone_name
func set_bone_name(new_name: String) -> void:
	bone_name = new_name
	_fetch_bone()
	update_configuration_warning()

var properties: WiggleProperties setget set_properties
func set_properties(new_properties: WiggleProperties) -> void:
	if properties:
		properties.disconnect("changed", self, "_properties_changed")
	properties = new_properties
	_update_enabled()
	update_configuration_warning()
	if properties:
		properties.connect("changed", self, "_properties_changed")

var attachment: NodePath setget set_attachment
func set_attachment(new_attachment: NodePath) -> void:
	attachment = new_attachment
	attachment_spatial = get_node_or_null(attachment)

var show_gizmo: = true setget set_show_gizmo
func set_show_gizmo(value: bool) -> void:
	show_gizmo = value
	update_gizmo()

var skeleton: Skeleton
var bone_idx: = -1
var attachment_spatial: Spatial

var point_mass: = PointMass.new()
var should_reset: = false

func _ready() -> void:
	set_as_toplevel(true)
	set_enabled(enabled)
	set_attachment(attachment)
	# execute after animations (hopefully)
	process_priority = 1000

func _enter_tree() -> void:
	skeleton = get_parent() as Skeleton
	_fetch_bone()

func _exit_tree() -> void:
	skeleton = null
	_fetch_bone()

func _properties_changed() -> void:
	update_gizmo()

func _get_property_list() -> Array:
	return [
		_get_bone_name_property(),
	{
		name = "properties",
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		# produces error in editor when loading from file
		# use general resource type for now
		#hint_string = "WiggleProperties",
		hint_string = "Resource",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "attachment",
		type = TYPE_NODE_PATH,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "show_gizmo",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

func _get_bone_name_property() -> Dictionary:
	var show_enum: = skeleton != null
	var bone_names: = _sorted_bone_names()
	# add empty option if bone_name is invalid
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

func _get_configuration_warning() -> String:
	if not skeleton:
		return "Parent must be Skeleton"
	if bone_idx < 0:
		return "Bone name '%s' not found" % bone_name
	if not properties:
		return "WiggleProperties resource is required"
	return ""

func _physics_process(delta: float) -> void:
	var global_bone_pose: = _get_global_pose()
	var pose: = _solve_pose(global_bone_pose, delta)

	skeleton.set_bone_custom_pose(bone_idx, pose)

	global_transform = global_bone_pose
	if attachment_spatial:
		attachment_spatial.transform = pose

func _get_global_pose() -> Transform:
	var rest_pose: = skeleton.get_bone_rest(bone_idx)
	var pose: = skeleton.get_bone_pose(bone_idx)
	var parent_idx: = skeleton.get_bone_parent(bone_idx)
	var parent_pose: = skeleton.get_bone_global_pose(parent_idx) if parent_idx >= 0 else Transform()
	var global_bone_pose: = skeleton.global_transform * parent_pose * rest_pose * pose

	return global_bone_pose

func _solve_pose(global_bone_pose: Transform, delta: float) -> Transform:
	var interations: = 1
	var mode: = properties.mode
	var global_to_pose: = global_bone_pose.basis.inverse()
	var mass_center: = global_bone_pose * properties.mass_center
	var origin: = global_bone_pose.origin
	var mass_distance: = properties.mass_center.length()

	if should_reset:
		point_mass.reset(mass_center)
		should_reset = false
		# try to reduce motion for first frame
		interations = PRECALCULATE_ITERATIONS

	var gravity: = Vector3()
	var pose = Transform()

	match mode:
		WiggleProperties.Mode.ROTATION:
			var local_p: = point_mass.p - origin
			gravity = project_to_vector_plane(local_p, mass_distance, properties.gravity)

		WiggleProperties.Mode.DISLOCATION:
			gravity = properties.gravity

	for i in interations:
		point_mass.apply_force(gravity)
		point_mass.inertia(delta, properties.damping)
		point_mass.solve_constraint(mass_center, properties.stiffness)

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var min_distance: = mass_distance
			var max_distance: = mass_distance

			point_mass.p = clamp_distance_to(point_mass.p, origin, min_distance, max_distance)
			point_mass.pp = clamp_distance_to(point_mass.pp, origin, min_distance, max_distance)

			var angular_offset: = Vector2.RIGHT.rotated(deg2rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit: = angular_offset * mass_distance

			point_mass.p = clamp_distance_to(point_mass.p, mass_center, 0, angular_limit)
			# TODO: add?
			#point_mass.pp = clamped_distance_to(point_mass.pp, mass_center, 0, angular_limit)

			var basis: = create_bone_look_at(point_mass.p - origin, global_bone_pose.basis * Vector3.RIGHT)
			pose.basis = global_to_pose * basis

		WiggleProperties.Mode.DISLOCATION:
			var dislocation: = clamp_length(point_mass.p - mass_center, 0, properties.max_distance)
			pose.origin = global_to_pose * dislocation

	return pose

func _update_enabled() -> void:
	var valid: = skeleton != null and bone_idx >= 0 and properties != null
	set_physics_process(enabled and valid)

func _fetch_bone() -> void:
	bone_idx = skeleton.find_bone(bone_name) if skeleton else -1
	_update_enabled()

func _sorted_bone_names() -> Array:
	var bone_names: = []
	if skeleton:
		for i in skeleton.get_bone_count():
			var bone_name: = skeleton.get_bone_name(i)
			bone_names.append(bone_name)
	bone_names.sort()

	return bone_names

static func create_bone_look_at(axis_y: Vector3, pose_axis_x: Vector3) -> Basis:
	axis_y = axis_y.normalized()
	var axis_z: = pose_axis_x.cross(axis_y).normalized()
	var axis_x: = axis_y.cross(axis_z)

	return Basis(axis_x, axis_y, axis_z)

static func project_to_vector_plane(vector: Vector3, length: float, point: Vector3) -> Vector3:
	return Plane(vector.normalized(), length).project(point)

static func clamp_length(v: Vector3, min_length: float, max_length: float) -> Vector3:
	return v.normalized() * clamp(v.length(), min_length, max_length)

static func clamp_distance_to(v: Vector3, origin: Vector3, min_length: float, max_length: float) -> Vector3:
	return origin + clamp_length(v - origin, min_length, max_length)

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

	func reset(position: Vector3) -> void:
		p = position
		pp = position
		a = Vector3()
