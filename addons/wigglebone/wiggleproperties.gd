tool
extends Resource

class_name WiggleProperties

enum Mode {
	ROTATION,
	DISLOCATION,
}

# distance of mass center to bone root in pose space
var mass_center: = Vector3(0.0, 0.5, 0.0)

# gravity pulling at mass center
var gravity: = Vector3(0.0, -50.0, 0.0)

# tendency of bone to return to pose position
var stiffness: = 0.1

# reduction of motion
var damping: = 0.1

# wiggle mode
var mode: int = Mode.ROTATION setget set_mode
func set_mode(new_mode: int) -> void:
	mode = new_mode
	property_list_changed_notify()

# maximum distance the bone root will be dislodged from its pose position
var max_dislocation: = 0.1 setget set_max_dislocation
func set_max_dislocation(value: float) -> void:
	max_dislocation = value

# maximum rotation
var max_degrees: = 60.0

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
				name = "max_dislocation",
				type = TYPE_REAL,
				hint = PROPERTY_HINT_RANGE,
				hint_string = "0,1000",
				usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE,
			})

	return props
