tool
class_name WiggleProperties
extends Resource

const PROPERTY_VISIBLE: = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
const PROPERTY_HIDDEN: = PROPERTY_VISIBLE & ~PROPERTY_USAGE_EDITOR

enum Mode {
	ROTATION,
	DISLOCATION,
}

# wiggle mode
var mode: int = Mode.ROTATION setget set_mode
# tendency of bone to return to pose position
var stiffness: = 0.1 setget set_stiffness
# reduction of motion
var damping: = 0.1 setget set_damping
# gravity pulling at mass center
var gravity: = Vector3.DOWN * 0.5 setget set_gravity
# distance of mass center to bone root in pose space
var mass_center: = Vector3.UP * 0.5 setget set_mass_center
# maximum distance the bone can move around its pose position
var max_distance: = 0.1 setget set_max_distance
# maximum rotation relative to pose position
var max_degrees: = 60.0 setget set_max_degrees


func _get_property_list() -> Array:
	return [{
		name = "mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Rotation,Dislocation",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "stiffness",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "damping",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0.01,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "gravity",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "mass_center",
		type = TYPE_VECTOR3,
		usage = PROPERTY_VISIBLE if mode == Mode.ROTATION else PROPERTY_HIDDEN,
	}, {
		name = "max_degrees",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,90",
		usage = PROPERTY_VISIBLE if mode == Mode.ROTATION else PROPERTY_HIDDEN,
	}, {
		name = "max_distance",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1,or_greater",
		usage = PROPERTY_VISIBLE if mode == Mode.DISLOCATION else PROPERTY_HIDDEN,
	}]


func set_mode(value: int) -> void:
	mode = value
	property_list_changed_notify()
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


func set_mass_center(value: Vector3) -> void:
	mass_center = value
	emit_changed()


func set_max_distance(value: float) -> void:
	max_distance = value
	emit_changed()


func set_max_degrees(value: float) -> void:
	max_degrees = value
	emit_changed()
