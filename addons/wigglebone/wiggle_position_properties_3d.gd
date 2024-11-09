@tool
@icon("icons/wiggle_position_properties_3d.svg")
class_name DMWBWigglePositionProperties3D
extends Resource

## Defines the properties used to move the bone.

const DEFAULT := {
	spring_freq = 3.0,
	linear_damp = 5.0,
	force_scale = 25.0,
	linear_scale = 1.0,
	max_distance = 0.1,
	gravity = Vector3.ZERO,
}

## The spring's oscillation frequency. The frequency may change if forces are applied.
## If [code]0.0[/code], the bone is able to move freely.
## [br][br]
## [b]Note:[/b] Setting a very high value may cause the spring to become unstable.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var spring_freq := DEFAULT.spring_freq:
	set = set_spring_freq

## Damping factor of the velocity.
@export_range(0.0, 50.0, 0.001, "or_greater") var linear_damp := DEFAULT.linear_damp:
	set = set_linear_damp

## Defines how much the position is influenced by forces.
@export_range(0.0, 100.0, 0.001, "or_greater") var force_scale := DEFAULT.force_scale:
	set = set_force_scale

## Defines how much the position is influenced by global movement.
@export_range(0.0, 1.0, 0.001, "or_greater") var linear_scale := DEFAULT.linear_scale:
	set = set_linear_scale

## Maximum distance the bone can move around its pose position.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:m") var max_distance := DEFAULT.max_distance:
	set = set_max_distance

## Applies a constant global force.
@export var gravity := DEFAULT.gravity:
	set = set_gravity


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT.get(property)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"gravity":
			property.hint_string = &"suffix:m/s²"


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
