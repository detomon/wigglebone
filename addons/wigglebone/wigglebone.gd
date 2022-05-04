tool
extends BoneAttachment
class_name WiggleBone

const ACCELERATION_WEIGHT: = 0.5

var enabled: = true setget set_enabled
func set_enabled(value: bool) -> void:
	enabled = value
	should_reset = true
	_update_enabled()

func set_bone_name(value: String) -> void:
	.set_bone_name(value)
	should_reset = true
	_fetch_bone()
	update_configuration_warning()

var properties: WiggleProperties setget set_properties
func set_properties(value: WiggleProperties) -> void:
	if properties:
		properties.disconnect("changed", self, "_properties_changed")
	properties = value
	if properties:
		properties.connect("changed", self, "_properties_changed")
	should_reset = true
	_update_enabled()
	update_configuration_warning()

var show_gizmo: = true setget set_show_gizmo
func set_show_gizmo(value: bool) -> void:
	show_gizmo = value
	update_gizmo()

var skeleton: Skeleton
var bone_idx: = -1
var bone_rest: Basis
var bone_rest_inv: Basis

var point_mass: = PointMass.new()
var global_bone_pose: = Transform()
var global_to_pose: = Basis()
var const_force: = Vector3.ZERO
var should_reset: = true

var acceleration: = Vector3.ZERO # local bone acceleration at mass center
var prev_mass_center: = Vector3.ZERO
var prev_velocity: = Vector3.ZERO

func _ready() -> void:
	set_enabled(enabled)

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
		name = "const_force",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "show_gizmo",
		type = TYPE_BOOL,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

func _get_configuration_warning() -> String:
	if not skeleton:
		return "Parent must be Skeleton"
	elif bone_idx < 0:
		return "Bone name '%s' not found" % bone_name
	elif not properties:
		return "WiggleProperties resource is required"
	return ""

func _process(delta: float) -> void:
	# may be 0.0 in editor on first frame
	if delta == 0.0:
		delta = 1.0 / float(Engine.iterations_per_second)

	global_bone_pose = global_bone_pose(skeleton, bone_idx)
	global_to_pose = global_bone_pose.basis.inverse()

	var new_acceleration: = _update_acceleration(delta)
	acceleration = acceleration.linear_interpolate(new_acceleration, ACCELERATION_WEIGHT)

func _physics_process(delta: float) -> void:
	var global_to_local: = global_bone_pose(skeleton, bone_idx).basis.inverse()
	_solve(global_to_local, acceleration, delta)

	var pose: = _pose()
	skeleton.set_bone_custom_pose(bone_idx, pose)

func _update_acceleration(delta: float) -> Vector3:
	var mass_center: = global_bone_pose * properties.mass_center
	var delta_mass_center: = prev_mass_center - mass_center
	prev_mass_center = mass_center

	if should_reset:
		delta_mass_center = Vector3.ZERO

	var global_velocity: = delta_mass_center / delta
	acceleration = global_velocity - prev_velocity

	prev_velocity = global_velocity

	if should_reset:
		prev_velocity = global_velocity
		acceleration = Vector3.ZERO
		point_mass.reset(Vector3.ZERO)
		should_reset = false

	return acceleration

func _solve(global_to_local: Basis, acceleration: Vector3, delta: float) -> void:
	#var global_force: = properties.gravity + const_force + acceleration
	var global_force: = properties.gravity + const_force
	var local_force: = global_to_local * global_force

	var mass_distance: = properties.mass_center.length()
	var local_acc: = global_to_local * acceleration

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			local_force = project_to_vector_plane(Vector3.ZERO, mass_distance, local_force)
			local_acc = project_to_vector_plane(Vector3.ZERO, mass_distance, local_acc)

	point_mass.p += local_acc * delta

	point_mass.apply_force(local_force)
	point_mass.inertia(delta, properties.damping)
	point_mass.solve_constraint(Vector3.ZERO, properties.stiffness)

func _pose() -> Transform:
	var pose: = Transform()

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var mass_distance: = properties.mass_center.length()
			var angular_offset: = Vector2.RIGHT.rotated(deg2rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit: = angular_offset * mass_distance
			var mass_constrained: = clamp_length(point_mass.p, 0.0, angular_limit)

			# TODO: soft limit
			var mass_local: = bone_rest * (properties.mass_center + mass_constrained)
			var axis_x: = bone_rest * Vector3.RIGHT
			var basis: = create_bone_look_at(mass_local, axis_x)

			pose.basis = bone_rest_inv * basis

		WiggleProperties.Mode.DISLOCATION:
			# TODO: soft limit
			var mass_constrained: = clamp_length(point_mass.p, 0.0, properties.max_distance)
			var mass_local: = bone_rest * (properties.mass_center + mass_constrained)

			pose.origin = bone_rest_inv * mass_local

	return pose

func _update_enabled() -> void:
	var valid: = skeleton != null and bone_idx >= 0 and properties != null
	var active: = enabled and valid
	set_physics_process(active)
	set_process(active)

	if valid and not enabled:
		skeleton.set_bone_custom_pose(bone_idx, Transform())

func _fetch_bone() -> void:
	bone_idx = skeleton.find_bone(bone_name) if skeleton else -1
	if bone_idx >= 0:
		bone_rest = skeleton.get_bone_rest(bone_idx).basis
		bone_rest_inv = bone_rest.inverse()
	_update_enabled()

func set_const_force(force: Vector3) -> void:
	const_force = force

func apply_impulse(impulse: Vector3, global: = false) -> void:
	if global:
		impulse = global_to_pose * impulse

	point_mass.apply_force(impulse)

func reset() -> void:
	should_reset = true

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
