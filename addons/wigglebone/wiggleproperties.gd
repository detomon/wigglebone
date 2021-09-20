tool
extends Resource

class_name WiggleProperties

enum Mode {
	ROTATION,
	DISLOCATION,
}

# distance of mass center to bone root in pose space
var mass_center: = Vector3(0.0, 0.5, 0.0) setget set_mass_center
func set_mass_center(value: Vector3) -> void:
	mass_center = value
	emit_changed()

# gravity pulling at mass center
var gravity: = Vector3(0.0, -50.0, 0.0) setget set_gravity
func set_gravity(value: Vector3) -> void:
	gravity = value
	emit_changed()

# tendency of bone to return to pose position
var stiffness: = 0.1 setget set_stiffness
func set_stiffness(value: float) -> void:
	stiffness = value
	emit_changed()

# reduction of motion
var damping: = 0.1 setget set_damping
func set_damping(value: float) -> void:
	damping = value
	emit_changed()

# wiggle mode
var mode: int = Mode.ROTATION setget set_mode
func set_mode(new_mode: int) -> void:
	mode = new_mode
	property_list_changed_notify()
	emit_changed()

# maximum distance the bone root will be dislodged from its pose position
var max_distance: = 0.1 setget set_max_distance
func set_max_distance(value: float) -> void:
	max_distance = value
	emit_changed()

# maximum rotation
var max_degrees: = 60.0 setget set_max_degrees
func set_max_degrees(value: float) -> void:
	max_degrees = value
	emit_changed()

func _get_property_list() -> Array:
	var props: = [{
		name = "mass_center",
		type = TYPE_VECTOR3,
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "gravity",
		type = TYPE_VECTOR3,
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
		hint_string = "0,1",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "mode",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Rotation,Dislocation",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]

	match mode:
		Mode.ROTATION:
			props.append({
				name = "max_degrees",
				type = TYPE_REAL,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0,90",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			})
		Mode.DISLOCATION:
			props.append({
				name = "max_distance",
				type = TYPE_REAL,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0,1,or_greater",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			})

	return props
