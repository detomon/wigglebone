@tool
extends Node3D

const SPRING_DAMPING_DEFAULT := 0.3
const SPRING_FREQUENCY_DEFAULT := 3.0
const PHYSICS_FPS_MIN := 30
const PHYSICS_FPS_MAX := 120

@export_group("Force", "force")
@export var force_gravity := Vector3.ZERO
## Use the global gravity from the project settings.
@export var force_use_global_gravity := false

@export_group("Spring", "spring")
@export_range(0.0, 1.0, 0.01, "or_greater") var spring_damping := SPRING_DAMPING_DEFAULT:
	set = set_spring_damping
@export_range(0.01, 10.0, 0.01, "or_greater") var spring_frequency := SPRING_FREQUENCY_DEFAULT:
	set = set_spring_frequency

@export_group("Time")
@export_range(PHYSICS_FPS_MIN, PHYSICS_FPS_MAX, 1) var physics_fps := PHYSICS_FPS_MIN:
	set = set_physics_fps

@export_group("Node")
@export var relative_to_node: Node3D = null:
	set = set_relative_to_node

var _position := Vector3.ZERO
var _position_prev := Vector3.ZERO
var _velocity := Vector3.ZERO
var _velocity_eff := Vector3.ZERO
var _velocity_prev := Vector3.ZERO
var _acceleration := Vector3.ZERO
var _acceleration_eff := Vector3.ZERO
var _physics_delta := 1.0
var _global_gravity := Vector3.ZERO
var _spring_alpha := 0.0

@onready var _weight: Node3D = $Weight

var _physics_time := 0.0


func _init() -> void:
	set_physics_fps(physics_fps)

	_update_sprint()
	ProjectSettings.settings_changed.connect(_on_project_settings_changed)
	_update_global_gravity()


#func _physics_process(delta: float) -> void:
	#pass


func _process(delta: float) -> void:
	_physics_time += delta

	while _physics_time >= _physics_delta:
		_physics_time -= _physics_delta
		_update(_physics_delta)

	# Extrapolate position.
	#
	# Ignore first term (just use _velocity_eff) if not integrating with Verlet.
	#
	#var vel := _velocity_eff - _acceleration_eff * _time
	#var pos := _position + vel * _time - (_acceleration_eff * _time * _time)
	# 1.
	#var pos := _position + _velocity_eff * _time - (_acceleration_eff * _time * _time * 2.0)
	#
	# Extrapolate position. Compensate for Verlet integration and spring.
	# p' = p + v * Δt - a * Δt^2 * 2
	#    = p + (v - a * Δt * 2) * Δt
	#var pos_ex := _position + (_velocity_eff - (_acceleration_eff * _physics_time * 2.0)) * _physics_time
	var pos_ex := _position + (_velocity_eff - (_acceleration_eff * _physics_time)) * _physics_time

	# Pin to anchor.
	#var anchor := global_transform * (Vector3.UP * 0.5)
	#pos_ex = anchor + (pos_ex - anchor).normalized() * 0.5

	#var pos := _position + (_velocity_eff - (_acceleration_eff * _time)) * _time

	_weight.global_position = pos_ex


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"spring_frequency":
			property.hint_string = &"0.01,10,0.01,or_greater,suffix:Hz"

		&"force_gravity":
			property.hint_string = &"suffix:m/s²"

		&"physics_fps":
			property.hint_string = &"15,120,1,suffix:FPS"


func set_spring_damping(value: float) -> void:
	spring_damping = clampf(value, 0.0, 1.0)
	_update_sprint()


func set_spring_frequency(value: float) -> void:
	spring_frequency = maxf(0.01, value)
	_update_sprint()


func set_physics_fps(value: int) -> void:
	physics_fps = clampi(value, PHYSICS_FPS_MIN, PHYSICS_FPS_MAX)
	_physics_delta = 1.0 / float(physics_fps)


func set_relative_to_node(value: Node3D) -> void:
	if value:
		# Cannot set self or child.
		if value == self or is_ancestor_of(value):
			printerr(&"Node must be a parent or sibling node.")
			value = null

	relative_to_node = value


func _update(delta: float) -> void:
	# Test lag
	#if randf_range(0.0., 1.0) < 0.02:
		#delta *= 5.0

	var force := force_gravity
	if force_use_global_gravity:
		force = _global_gravity

	# Use position relative to given node.
	var node_position := global_position
	if relative_to_node:
		node_position -= relative_to_node.global_position

	#if spring_frequency > 0.0:
		#var spring := _spring(_position, node_position, _velocity, delta, spring_damping, spring_frequency)

	_velocity += force * delta

	var frequency := spring_frequency * TAU

	#_spring(_position, node_position, _velocity, delta, spring_damping, frequency)

	_spring_no_damping(_position, node_position, _velocity, delta, frequency)

	# Pin to anchor.
	#var anchor := global_transform * (Vector3.UP * 0.5)
	#_position = anchor + (_position - anchor).normalized() * 0.5

	var decay := remap(spring_damping, 0.0, 1.0, 0.0, 25.0)
	_velocity *= exp(-decay * delta)

	"""
	lerp(from, to, 1.0 - exp(-decay * delta))

	lerp(a, b, c) = a + (b - a) * c
	lerp(a, 0, c) = a * (1 - c)

	lerp(from, 0, c) = from * exp(-decay * delta))
	"""

	#_position = spring[0]
	#_velocity = spring[1]

	#if _position.distance_to(node_position) > 0.5:
		#_position = node_position + (_position - node_position).normalized() * 0.5

	#var new_pos := _position + _velocity * delta + _acceleration * (delta * delta * 0.5)
	#var new_acc := force
	#var new_vel := _velocity + (_acceleration + new_acc) * (delta * 0.5)
#
	#_position = new_pos
	#_velocity = new_vel
	#_acceleration = new_acc

	#var verlet := _verlet(_position, _velocity, _acceleration, force, delta)

	#_verlet(_position, _velocity, _acceleration, force, delta)

	#_position = verlet[0]
	#_velocity = verlet[1]
	#_acceleration = verlet[2]

	_acceleration_eff = (_velocity_prev - _velocity) / delta
	_velocity_prev = _velocity

	_velocity_eff = (_position - _position_prev) / delta
	_position_prev = _position


func _verlet(value: Vector3, velocity: Vector3, acceleration: Vector3, force: Vector3, delta: float) -> void:
	var new_pos := value + velocity * delta + acceleration * (delta * delta * 0.5)
	var new_acc := force
	var new_vel := velocity + (acceleration + new_acc) * (delta * 0.5)

	_position = new_pos
	_velocity = new_vel
	_acceleration = new_acc

	"""
	https://gamedev.stackexchange.com/questions/94000/how-to-implement-accurate-frame-rate-independent-physics#answer-126069

	velocityOld = velocityX
	velocityX += acceleration * delta;
	posX += (velocityX + velocityOld) * delta * 0.5;

	https://gamedev.net/forums/topic/675751-verlet-integration-and-dampening/5277178/
	"""

	#return [new_pos, new_vel, new_acc]


# Spring
func _spring(value: Vector3, target: Vector3, velocity: Vector3, delta: float, damping: float, frequency: float) -> void:
	if damping >= 1.0:
		_position = target
		_velocity = Vector3.ZERO
		return
		#return [target, Vector3.ZERO]

	if damping < 0.0:
		damping = 0.0

	var x0 := value - target
	var omega_zeta := frequency * damping
	var alpha := _spring_alpha
	var exp_ := exp(-delta * omega_zeta)
	var cos_ := cos(delta * alpha)
	var sin_ := sin(delta * alpha)
	var c2 := (velocity + x0 * omega_zeta) / alpha

	var pos := target + exp_ * (x0 * cos_ + c2 * sin_)
	var vel := -exp_ * ((x0 * omega_zeta - c2 * alpha) * cos_ + (x0 * alpha + c2 * omega_zeta) * sin_)

	_position = pos
	_velocity = vel


# Spring
func _spring_no_damping(value: Vector3, target: Vector3, velocity: Vector3, delta: float, frequency: float) -> void:
	var x0 := value - target
	var alpha := frequency
	var cos_ := cos(delta * alpha)
	var sin_ := sin(delta * alpha)
	var c2 := velocity / alpha

	var pos := target + (x0 * cos_ + c2 * sin_)
	var vel := (c2 * cos_ - x0 * sin_) * alpha

	_position = pos
	_velocity = vel


func _update_sprint() -> void:
	var omega := spring_frequency
	var zeta := spring_damping
	_spring_alpha = omega * sqrt(1.0 - zeta * zeta)


func _update_global_gravity() -> void:
	var default_gravity: float = ProjectSettings.get_setting(&"physics/3d/default_gravity")
	var default_gravity_vector: Vector3 = ProjectSettings.get_setting(&"physics/3d/default_gravity_vector")

	_global_gravity = default_gravity_vector * default_gravity


func _on_project_settings_changed() -> void:
	_update_global_gravity()
