@tool
@icon("icons/wiggle_position_properties_3d.svg")
class_name DMWBWigglePositionProperties3D
extends Resource

## Defines the properties used to move the bone.

## The spring's oscillation frequency in [code]Hz[/code]. The frequency may change if forces are applied.
## If [code]0.0[/code], the bone is able to move freely.
## [br][br]
## [b]Note:[/b] Setting a very high value may cause the spring to become unstable.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var spring_freq := 3.0:
	set = set_spring_freq

## Damping factor of the velocity.
@export_range(0.0, 50.0, 0.001, "or_greater") var linear_damp := 5.0:
	set = set_linear_damp

## A factor which defines how much the position is influenced by forces.
@export_range(0.0, 100.0, 0.001, "or_greater") var force_scale := 25.0:
	set = set_force_scale

## A factor which defines how much the position is influenced by global movement.
@export_range(0.0, 1.0, 0.001, "or_greater") var linear_scale := 1.0:
	set = set_linear_scale

## Maximum distance in meters the bone can move around its pose position.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:m") var max_distance := 0.1:
	set = set_max_distance

## Applies a constant global force ([code]m/s²[/code]).
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s²") var gravity := Vector3.ZERO:
	set = set_gravity


func set_spring_freq(value: float) -> void:
	spring_freq = maxf(0.0, value)
	emit_changed()


func set_linear_damp(value: float) -> void:
	linear_damp = maxf(0.0, value)
	emit_changed()


func set_force_scale(value: float) -> void:
	force_scale = maxf(0.0, value)
	emit_changed()


func set_linear_scale(value: float) -> void:
	linear_scale = maxf(0.0, value)
	emit_changed()


func set_max_distance(value: float) -> void:
	max_distance = value
	emit_changed()


func set_gravity(value: Vector3) -> void:
	gravity = value
	emit_changed()


## Get [member gravity].
func get_gravity() -> Vector3:
	return gravity
