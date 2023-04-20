@tool
class_name WiggleProperties
extends Resource

## Defines the properties used to move the bone.

## Emitted when the behaviour changed.
signal behaviour_changed()

## The wiggle mode.
enum Mode {
	ROTATION,    ## Rotates the bone around its origin.
	DISLOCATION, ## Moves the bone around its origin.
}

const PROPERTY_VISIBLE := PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
const PROPERTY_HIDDEN := PROPERTY_VISIBLE & ~PROPERTY_USAGE_EDITOR
const DEFAULT_VALUES := {
	mode = Mode.ROTATION,
	stiffness = 0.1,
	damping = 0.1,
	gravity = Vector3.ZERO,
	length = 0.1,
	max_distance = 0.1,
	max_degrees = 60.0,
}

## The wiggle mode.
var mode: int = Mode.ROTATION: set = set_mode
## Rendency of bone to return to pose position.
var stiffness := 0.1: set = set_stiffness
## Reduction of motion.
var damping := 0.1: set = set_damping
## Gravity pulling at mass center.
var gravity := Vector3.ZERO: set = set_gravity
## The bone length.
var length := 0.1: set = set_length
## Maximum distance the bone can move around its pose position.
var max_distance := 0.1: set = set_max_distance
## Maximum rotation relative to pose position.
var max_degrees := 60.0: set = set_max_degrees


func _get_property_list() -> Array[Dictionary]:
	return [{
		name = "mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Rotation,Dislocation",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "stiffness",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "damping",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "gravity",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "length",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,1.0,or_greater",
		usage = PROPERTY_VISIBLE if mode == Mode.ROTATION else PROPERTY_HIDDEN,
	}, {
		name = "max_degrees",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,90",
		usage = PROPERTY_VISIBLE if mode == Mode.ROTATION else PROPERTY_HIDDEN,
	}, {
		name = "max_distance",
		type = TYPE_FLOAT,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,or_greater",
		usage = PROPERTY_VISIBLE if mode == Mode.DISLOCATION else PROPERTY_HIDDEN,
	}]


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT_VALUES


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT_VALUES.get(property)


func set_mode(value: int) -> void:
	mode = value
	notify_property_list_changed()
	behaviour_changed.emit()
	emit_changed()


func set_stiffness(value: float) -> void:
	stiffness = value
	emit_changed()


func set_damping(value: float) -> void:
	damping = value
	emit_changed()


func set_gravity(value: Vector3) -> void:
	gravity = value
	emit_changed()


func set_length(value: float) -> void:
	length = maxf(0.01, value)
	behaviour_changed.emit()
	emit_changed()


func set_max_distance(value: float) -> void:
	max_distance = value
	emit_changed()


func set_max_degrees(value: float) -> void:
	max_degrees = value
	emit_changed()
