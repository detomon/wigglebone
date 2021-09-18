tool
extends Resource

class_name WiggleProperties

# distance of mass center to bone root in pose space
var mass_center: = Vector3(0.0, 0.5, 0.0)

# gravity pulling at mass center
var gravity: = Vector3(0.0, -0.2, 0.0)

# tendency of bone to return to pose position
var stiffness: = 0.1

# reduction of motion
var damping: = 0.1

# maximum distance the bone root will be dislodged from its pose position
var max_dislocation: = 0.0 setget set_max_dislocation
func set_max_dislocation(value: float) -> void:
	max_dislocation = value

# maximum rotation
var angle_max_degrees: = 60.0

func _get_property_list() -> Array:
	return [{
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
		name = "max_dislocation",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,1000",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}, {
		name = "angle_max_degrees",
		type = TYPE_REAL,
		hint = PROPERTY_HINT_RANGE,
		hint_string = "0,90",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
	}]
