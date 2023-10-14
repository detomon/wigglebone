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

const PROPERTY_VISIBLE := PROPERTY_USAGE_DEFAULT
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
@export_enum("Rotation", "Dislocation") var mode: int = Mode.ROTATION: set = set_mode
## Rendency of bone to return to pose position.
@export_range(0, 1, 0.01) var stiffness := DEFAULT_VALUES.stiffness: set = set_stiffness
## Reduction of motion.
@export_range(0.01, 1, 0.01) var damping := DEFAULT_VALUES.damping: set = set_damping
## Gravity pulling at mass center.
@export var gravity := DEFAULT_VALUES.gravity: set = set_gravity
## The bone length.
@export_range(0.01, 1, 0.01, "or_greater", "suffix:m") var length := DEFAULT_VALUES.length: set = set_length
## Maximum distance the bone can move around its pose position.
@export_range(0, 1, 0.01, "or_greater", "suffix:m") var max_distance := DEFAULT_VALUES.max_distance: set = set_max_distance
## Maximum rotation relative to pose position.
@export_range(0, 90, 0.1, "suffix:°") var max_degrees := DEFAULT_VALUES.max_degrees: set = set_max_degrees


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT_VALUES


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT_VALUES.get(property)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"max_distance":
			property.usage = PROPERTY_VISIBLE if mode == Mode.DISLOCATION else PROPERTY_HIDDEN

		&"max_degrees":
			property.usage = PROPERTY_VISIBLE if mode == Mode.ROTATION else PROPERTY_HIDDEN


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
