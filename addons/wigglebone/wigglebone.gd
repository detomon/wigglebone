tool
extends BoneAttachment
class_name WiggleBone

const ACCELERATION_WEIGHT: = 0.5
const SOFT_LIMIT_FACTOR: = 0.5

var enabled: = true setget set_enabled
func set_enabled(value: bool) -> void:
	enabled = value
	_should_reset = true
	_update_enabled()

func set_bone_name(value: String) -> void:
	.set_bone_name(value)
	_should_reset = true
	_fetch_bone()
	update_configuration_warning()

var properties: WiggleProperties setget set_properties
func set_properties(value: WiggleProperties) -> void:
	if properties:
		properties.disconnect("changed", self, "_properties_changed")
	properties = value
	if properties:
		properties.connect("changed", self, "_properties_changed")
	_should_reset = true
	_update_enabled()
	update_configuration_warning()

var const_force: = Vector3.ZERO # global force
var const_force_local: = Vector3.ZERO # local force relative to bone pose

var _skeleton: Skeleton
var _bone_idx: = -1

var _point_mass: = PointMass.new()
var _global_to_pose: = Basis()
var _should_reset: = true

var _acceleration: = Vector3.ZERO # local bone acceleration at mass center
var _prev_mass_center: = Vector3.ZERO
var _prev_velocity: = Vector3.ZERO

func _ready() -> void:
	set_enabled(enabled)

func _enter_tree() -> void:
	_skeleton = get_parent() as Skeleton
	_fetch_bone()

func _exit_tree() -> void:
	_skeleton = null
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
		name = "const_force_local",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

func _get_configuration_warning() -> String:
	if not _skeleton:
		return "Parent must be Skeleton"
	elif _bone_idx < 0:
		return "Bone name '%s' not found" % bone_name
	elif not properties:
		return "WiggleProperties resource is required"
	return ""

func _process(delta: float) -> void:
	# may be 0.0 in editor on first frame
	if delta == 0.0:
		delta = 1.0 / float(Engine.iterations_per_second)

	var custom_pose_inv: = _skeleton.get_bone_custom_pose(_bone_idx).inverse()
	# global pose including nomal pose but without custom pose
	var global_bone_pose: = global_transform * custom_pose_inv
	_global_to_pose = global_bone_pose.basis.inverse()

	var new_acceleration: = _update_acceleration(global_bone_pose, delta)
	_acceleration = _acceleration.linear_interpolate(new_acceleration, ACCELERATION_WEIGHT)

	var pose: = _pose()
	_skeleton.set_bone_custom_pose(_bone_idx, pose)

func _physics_process(delta: float) -> void:
	_solve(_global_to_pose, _acceleration, delta)

func _update_acceleration(global_bone_pose: Transform, delta: float) -> Vector3:
	var mass_center: = global_bone_pose * properties.mass_center
	var delta_mass_center: = _prev_mass_center - mass_center
	_prev_mass_center = mass_center

	if _should_reset:
		delta_mass_center = Vector3.ZERO

	var global_velocity: = delta_mass_center / delta
	_acceleration = global_velocity - _prev_velocity

	_prev_velocity = global_velocity

	if _should_reset:
		_prev_velocity = global_velocity
		_acceleration = Vector3.ZERO
		_point_mass.reset(Vector3.ZERO)
		_should_reset = false

	return _acceleration

func _solve(global_to_local: Basis, acceleration: Vector3, delta: float) -> void:
	var global_force: = properties.gravity + const_force
	var local_force: = global_to_local * global_force + const_force_local

	var mass_distance: = properties.mass_center.length()
	var local_acc: = global_to_local * acceleration

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			local_force = project_to_vector_plane(Vector3.ZERO, mass_distance, local_force)
			local_acc = project_to_vector_plane(Vector3.ZERO, mass_distance, local_acc)

	_point_mass.accelerate(local_acc, delta)
	_point_mass.apply_force(local_force)
	_point_mass.solve(properties.stiffness, properties.damping, delta)

func _pose() -> Transform:
	var pose: = Transform()

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var mass_distance: = properties.mass_center.length()
			var angular_offset: = Vector2.RIGHT.rotated(deg2rad(properties.max_degrees)).distance_to(Vector2.RIGHT)
			var angular_limit: = angular_offset * mass_distance
			var k: = angular_limit * SOFT_LIMIT_FACTOR
			var mass_constrained: = clamp_length_soft(_point_mass.p, 0.0, angular_limit, k)

			var mass_local: = properties.mass_center + mass_constrained
			var axis_x: = Vector3.RIGHT
			var basis: = create_bone_look_at(mass_local, axis_x)

			pose.basis = basis

		WiggleProperties.Mode.DISLOCATION:
			var k: = properties.max_distance * SOFT_LIMIT_FACTOR
			var mass_constrained: = clamp_length_soft(_point_mass.p, 0.0, properties.max_distance, k)
			var mass_local: = properties.mass_center + mass_constrained

			pose.origin = mass_local

	return pose

func _update_enabled() -> void:
	var valid: = _skeleton != null and _bone_idx >= 0 and properties != null
	var active: = enabled and valid
	set_physics_process(active)
	set_process(active)

	if valid and not enabled:
		_skeleton.set_bone_custom_pose(_bone_idx, Transform())

func _fetch_bone() -> void:
	_bone_idx = _skeleton.find_bone(bone_name) if _skeleton else -1
	_update_enabled()

func apply_impulse(impulse: Vector3, global: = false) -> void:
	if global:
		impulse = _global_to_pose * impulse

	_point_mass.apply_force(impulse)

func reset() -> void:
	_should_reset = true

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

static func clamp_length_soft(v: Vector3, min_length: float, max_length: float, k: float) -> Vector3:
	return v.normalized() * smin(max(min_length, v.length()), max_length, k)

static func smin(a: float, b: float, k: float) -> float:
	var h: = max(0.0, k - abs(a - b))
	return min(a, b) - h * h / (4.0 * k)

class PointMass:
	var p: = Vector3.ZERO
	var v: = Vector3.ZERO
	var a: = Vector3.ZERO

	func solve(stiffness: float, damping: float, delta: float) -> void:
		# inertia
		v = v * (1.0 - damping) + a * delta
		p += v
		a = Vector3.ZERO

		# constraint
		v -= p * stiffness

	func accelerate(a: Vector3, delta: float) -> void:
		v += a * delta

	func apply_force(force: Vector3) -> void:
		a += force

	func reset(position: Vector3) -> void:
		p = position
		v = position
		a = Vector3.ZERO
