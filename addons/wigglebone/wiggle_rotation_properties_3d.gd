@tool
@icon("icons/wiggle_rotation_properties_3d.svg")
class_name DMWBWiggleRotationProperties3D
extends Resource

## Defines the properties used to rotate the bone.

const DEFAULT := {
	spring_freq = 3.0,
	angular_damp = 5.0,
	torque_scale = 1.0,
	force_scale = 180.0,
	linear_scale = 360.0,
	swing_span = 60.0 / 180.0 * PI,
	gravity = Vector3.ZERO,
}

## The spring's oscillation frequency. The frequency may change if forces are applied.
## If [code]0.0[/code], the bone is able to rotate freely.
## [br][br]
## [b]Note:[/b] Setting a very high value may cause the spring to become unstable.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var spring_freq := DEFAULT.spring_freq:
	set = set_spring_freq

## Damping factor of the angular velocity.
@export_range(0.0, 50.0, 0.001, "or_greater") var angular_damp := DEFAULT.angular_damp:
	set = set_angular_damp

## Defines how much the rotation is influenced by forces.
@export_range(0.0, 6000.0, 0.001, "or_greater") var force_scale := DEFAULT.force_scale:
	set = set_force_scale

## Defines how much the rotation is influenced by global movement.
@export_range(0.0, 6000.0, 0.001, "or_greater") var linear_scale := DEFAULT.linear_scale:
	set = set_linear_scale

## Maximum angle the bone can rotate around its pose.
@export_range(0.0, 180.0, 0.01, "radians") var swing_span := DEFAULT.swing_span:
	set = set_swing_span

## Applies a constant global force.
@export var gravity := DEFAULT.gravity:
	set = set_gravity


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT.get(property)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"force_scale":
			property.hint_string = &"0,6000,0.001,or_greater,suffix:°/m"

		&"linear_scale":
			property.hint_string = &"0,6000,0.001,or_greater,suffix:°/m"

		&"gravity":
			property.hint_string = &"suffix:m/s²"


func set_spring_freq(value: float) -> void:
	spring_freq = maxf(0.0, value)
	emit_changed()


func set_angular_damp(value: float) -> void:
	angular_damp = maxf(0.0, value)
	emit_changed()


func set_force_scale(value: float) -> void:
	force_scale = maxf(0.0, value)
	emit_changed()


func set_linear_scale(value: float) -> void:
	linear_scale = maxf(0.0, value)
	emit_changed()


func set_swing_span(value: float) -> void:
	swing_span = clampf(value, 0.0, PI)
	emit_changed()


func set_gravity(value: Vector3) -> void:
	gravity = value
	emit_changed()


## Get [member gravity].
func get_gravity() -> Vector3:
	return gravity
