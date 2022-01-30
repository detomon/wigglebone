tool
extends Spatial
class_name WiggleBone

const PRECALCULATE_ITERATIONS: = 10

var enabled: = true setget set_enabled
func set_enabled(value: bool) -> void:
	enabled = value
	should_reset = true
	_update_enabled()

var bone_name: String setget set_bone_name
func set_bone_name(value: String) -> void:
	bone_name = value
	_fetch_bone()
	update_configuration_warning()

var properties: WiggleProperties setget set_properties
func set_properties(value: WiggleProperties) -> void:
	if properties:
		properties.disconnect("changed", self, "_properties_changed")
	properties = value
	if properties:
		properties.connect("changed", self, "_properties_changed")
	_update_enabled()
	update_configuration_warning()

var attachment: NodePath setget set_attachment
func set_attachment(value: NodePath) -> void:
	attachment = value

	if is_inside_tree() and not attachment.is_empty():
		attachment_spatial = get_node_or_null(attachment) as Spatial

		if not attachment_spatial or attachment_spatial.get_parent() != self:
			attachment = ""
			attachment_spatial = null
			printerr("WiggleBone: Attachment must be a direct Spatial child")

var show_gizmo: = true setget set_show_gizmo
func set_show_gizmo(value: bool) -> void:
	show_gizmo = value
	update_gizmo()

var skeleton: Skeleton
var bone_idx: = -1
var attachment_spatial: Spatial

var point_mass: = PointMass.new()
var global_bone_pose: = Transform()
var const_force: = Vector3.ZERO
var should_reset: = false

func _ready() -> void:
	set_as_toplevel(true)
	set_enabled(enabled)
	set_attachment(attachment)
	# execute before animations
	process_priority = -1

func _enter_tree() -> void:
	skeleton = get_parent() as Skeleton
	_fetch_bone()

func _exit_tree() -> void:
	skeleton = null
	_fetch_bone()

func _properties_changed() -> void:
	update_gizmo()

func _get_property_list() -> Array:
	return [{
		name = "enabled",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	},
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
		name = "const_force",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "show_gizmo",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

func _get_bone_name_property() -> Dictionary:
	var show_enum: = skeleton != null
	var bone_names: = sorted_bone_names(skeleton)
	# add empty option if bone_name is invalid
	if bone_idx < 0:
		bone_names.push_front("")

	return {
		name = "bone_name",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_ENUM if show_enum else PROPERTY_HINT_NONE,
		hint_string = PoolStringArray(bone_names).join(","),
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}

func _get_configuration_warning() -> String:
	if not skeleton:
		return "Parent must be Skeleton"
	elif bone_idx < 0:
		return "Bone name '%s' not found" % bone_name
	elif not properties:
		return "WiggleProperties resource is required"
	return ""

func _physics_process(delta: float) -> void:
	global_bone_pose = global_bone_pose(skeleton, bone_idx)
	_solve(global_bone_pose, delta)

func _process(_delta: float) -> void:
	var physics_delta: = 1.0 / float(Engine.iterations_per_second)
	var fraction: = Engine.get_physics_interpolation_fraction()
	var extrapolation: = physics_delta * fraction

	var pose: = _pose(global_bone_pose, extrapolation)
	skeleton.set_bone_custom_pose(bone_idx, pose)

	# TODO: also update in _physics_process?
	global_transform = global_bone_pose
	if attachment_spatial:
		attachment_spatial.transform = pose

func _solve(global_bone_pose: Transform, delta: float) -> void:
	var gravity: = properties.gravity + const_force

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var origin: = global_bone_pose.origin
			var local_p: = point_mass.p - origin
			var mass_distance: = properties.mass_center.length()
			gravity = project_to_vector_plane(local_p, mass_distance, gravity)

		WiggleProperties.Mode.DISLOCATION:
			pass

	var interations: = 1
	var mass_center: = global_bone_pose * properties.mass_center

	if should_reset:
		point_mass.reset(mass_center)
		should_reset = false
		# try to reduce motion at first frame
		interations = PRECALCULATE_ITERATIONS

	for i in interations:
		point_mass.apply_force(gravity)
		point_mass.inertia(delta, properties.damping)
		point_mass.solve_constraint(mass_center, properties.stiffness)

func _pose(global_bone_pose: Transform, extrapolation: float) -> Transform:
	var pose: = Transform()
	var mass_center: = global_bone_pose * properties.mass_center
	var global_to_pose: = global_bone_pose.basis.inverse()
	var mass_distance: = properties.mass_center.length()
	var origin: = global_bone_pose.origin

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			point_mass.p = clamp_distance_to(point_mass.p, origin, mass_distance, mass_distance)
			point_mass.pp = clamp_distance_to(point_mass.pp, origin, mass_distance, mass_distance)

			var angular_offset: = Vector2.RIGHT.rotated(deg2rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit: = angular_offset * mass_distance

			point_mass.p = clamp_distance_to(point_mass.p, mass_center, 0, angular_limit)
			#point_mass.pp = project_to_vector_plane(point_mass.p - origin, mass_distance, point_mass.pp - origin) + origin

			# TODO: limit point_mass.pp?
			var p: = point_mass.p + (point_mass.p - point_mass.pp) * extrapolation

			var axis_x: = global_bone_pose.basis * Vector3.RIGHT
			var basis: = create_bone_look_at(p - origin, axis_x)

#			var y: = (global_to_pose * (p - origin)).normalized()
#			var y0: = properties.mass_center.normalized()
#			var d: = y.dot(y0)
#			var basis: = Basis()
#			var axis: = y0.cross(y).normalized()
#
#			print(d)

			pose.basis = global_to_pose * basis

		WiggleProperties.Mode.DISLOCATION:
			point_mass.p = clamp_distance_to(point_mass.p, origin, 0, mass_distance + properties.max_distance)
			point_mass.pp = clamp_distance_to(point_mass.pp, origin, 0, mass_distance + properties.max_distance)
			var p: = point_mass.p + (point_mass.p - point_mass.pp) * extrapolation

			var dislocation: = clamp_length(p - mass_center, 0, properties.max_distance)
			pose.origin = global_to_pose * dislocation

	return pose

func _update_enabled() -> void:
	var valid: = skeleton != null and bone_idx >= 0 and properties != null
	var active: = enabled and valid
	set_physics_process(active)
	set_process(active)

func _fetch_bone() -> void:
	bone_idx = skeleton.find_bone(bone_name) if skeleton else -1
	_update_enabled()

func set_const_force(force: Vector3) -> void:
	const_force = force

func apply_impulse(impulse: Vector3) -> void:
	point_mass.apply_force(impulse)

static func global_bone_pose(skeleton: Skeleton, bone_idx: int) -> Transform:
	var rest_pose: = skeleton.get_bone_rest(bone_idx)
	var pose: = skeleton.get_bone_pose(bone_idx)
	var parent_idx: = skeleton.get_bone_parent(bone_idx)
	var parent_pose: = skeleton.get_bone_global_pose(parent_idx) if parent_idx >= 0 else Transform()

	return skeleton.global_transform * parent_pose * rest_pose * pose

static func sorted_bone_names(skeleton: Skeleton) -> Array:
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
	var p: = Vector3.ZERO
	var pp: = Vector3.ZERO
	var a: = Vector3.ZERO

	func inertia(delta: float, damping: float) -> void:
		var v: = (p - pp) * (1.0 - damping)
		var pn: = p + v + a * delta

		pp = p
		p = pn
		a = Vector3.ZERO

	func solve_constraint(target: Vector3, stiffness: float) -> void:
		p += (target - p) * stiffness

	func apply_force(force: Vector3) -> void:
		a += force

	func reset(position: Vector3) -> void:
		p = position
		pp = position
		a = Vector3.ZERO
