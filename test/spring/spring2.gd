@tool
extends Node3D

const SPRING_DAMPING_DEFAULT := 0.3
const SPRING_FREQUENCY_DEFAULT := 4.0
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
var _physics_time := 0.0

@onready var _weight: Node3D = $Weight


func _init() -> void:
	set_physics_fps(physics_fps)

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

	#var pos := _position + (_velocity_eff - (_acceleration_eff * _time)) * _time

	_weight.global_position = pos_ex


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"spring_frequency":
			property.hint_string = &"0.01,10,0.01,or_greater,suffix:Hz"

		&"force_gravity":
			property.hint_string = &"0,20,0.01,or_greater,suffix:m/s²"

		&"physics_fps":
			property.hint_string = &"15,120,1,suffix:FPS"


func set_spring_damping(value: float) -> void:
	spring_damping = clampf(value, 0.0, 4.0)


func set_spring_frequency(value: float) -> void:
	spring_frequency = maxf(0.01, value)


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
	#var time := Time.get_ticks_usec()

	var force := force_gravity

	if force_use_global_gravity:
		force += _global_gravity

	# Use position relative to given node.
	var node_position := global_position
	if relative_to_node:
		node_position -= relative_to_node.global_position

	_velocity += force * delta

	_spring(_position, node_position, _velocity, delta)

	var decay := remap(spring_damping, 0.0, 1.0, 0.0, 25.0)
	_velocity = _velocity * exp(-decay * delta)

	"""
	lerp(from, to, 1.0 - exp(-decay * delta))

	lerp(a, b, c) = a + (b - a) * c
	lerp(a, 0, c) = a * (1 - c)

	lerp(from, 0, c) = from * exp(-decay * delta))

	"""

	_acceleration_eff = (_velocity_prev - _velocity) / delta
	_velocity_prev = _velocity

	_velocity_eff = (_position - _position_prev) / delta
	_position_prev = _position

	#if not Engine.is_editor_hint():
		#print("%fs" % ((Time.get_ticks_usec() - time) / float(1_000_000)))


# Spring
func _spring(value: Vector3, target: Vector3, velocity: Vector3, delta: float) -> void:
	var frequency := spring_frequency * TAU
	var x0 := value - target
	var cos_ := cos(frequency * delta)
	var sin_ := sin(frequency * delta)
	var c2 := velocity / frequency

	_position = target + (x0 * cos_ + c2 * sin_)
	_velocity = (c2 * cos_ - x0 * sin_) * frequency


#func _verlet(value: Vector3, velocity: Vector3, acceleration: Vector3, force: Vector3, delta: float) -> void:
	#var new_pos := value + velocity * delta + acceleration * (delta * delta * 0.5)
	#var new_acc := force
	#var new_vel := velocity + (acceleration + new_acc) * (delta * 0.5)
#
	#_position = new_pos
	#_velocity = new_vel
	#_acceleration = new_acc

	"""
	https://gamedev.stackexchange.com/questions/94000/how-to-implement-accurate-frame-rate-independent-physics#answer-126069

	velocityOld = velocityX
	velocityX += acceleration * delta;
	posX += (velocityX + velocityOld) * delta * 0.5;

	https://gamedev.net/forums/topic/675751-verlet-integration-and-dampening/5277178/
	"""


func _update_global_gravity() -> void:
	var default_gravity: float = ProjectSettings.get_setting(&"physics/3d/default_gravity")
	var default_gravity_vector: Vector3 = ProjectSettings.get_setting(&"physics/3d/default_gravity_vector")

	_global_gravity = default_gravity_vector * default_gravity


func _on_project_settings_changed() -> void:
	_update_global_gravity()
