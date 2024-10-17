@tool
@icon("icons/wiggle_rotation_properties_3d.svg")
class_name WiggleRotationProperties3D
extends Resource

## Defines the properties used to rotate the bone.

const DEFAULT := {
	spring_freq = 3.0,
	angular_damp = 0.2,
	torque_scale = 1.0,
	swing_span = 60.0 / 180.0 * PI,
	custom_gravity = Vector3.ZERO,
	handle_distance = 0.1,
}

## Spring frequence without damping and forces. The frequency may change if forces are applied.
## If [code]0.0[/code], the bone is able to rotate
## freely.
## [br][br]
## [b]Note:[/b] Setting a very high value may cause the spring to become unstable.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var spring_freq := DEFAULT.spring_freq:
	set = set_spring_freq
## Damping factor. Can be greater than [code]1.0[/code] to have an even greater effect.
@export_range(0.0, 1.0, 0.001, "or_greater") var angular_damp := DEFAULT.angular_damp:
	set = set_angular_damp
## Defines, how much forces and global movement influences the rotation.
@export_range(0.0, 1.0, 0.001, "or_greater") var torque_scale := DEFAULT.torque_scale:
	set = set_torque_scale
## Maximum rotation relative to the pose position.
@export_range(0.0, 180.0, 0.01, "radians") var swing_span := DEFAULT.swing_span:
	set = set_swing_span

@export_group("Gravity")
## If [code]true[/code], the gravity is calculated by multiplying
## [member ProjectSettings.physics/3d/default_gravity_vector] with
## [member ProjectSettings.physics/3d/default_gravity]. If [code]false[/code],
## [member custom_gravity] is used.
@export var use_global_gravity := false:
	set = set_use_global_gravity
## A constant global force.
@export var custom_gravity := DEFAULT.custom_gravity:
	set = set_custom_gravity

@export_group("Editor")
## Sets the distance of the editor handle on the bone's Y axis.
@export_range(0.01, 1.0, 0.01, "or_greater", "suffix:m") var handle_distance := DEFAULT.handle_distance:
	set = set_handle_distance

var _gravity := Vector3.ZERO
var _gravity_needs_update := true


func _init() -> void:
	ProjectSettings.settings_changed.connect(_on_project_settings_changed)


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT.get(property)


func _validate_property(property: Dictionary) -> void:
	const PROPERTY_VISIBLE := PROPERTY_USAGE_DEFAULT
	const PROPERTY_HIDDEN := PROPERTY_VISIBLE & ~PROPERTY_USAGE_EDITOR

	match property.name:
		&"set_swing_span":
			property.usage = PROPERTY_HIDDEN

		&"custom_gravity":
			property.usage = PROPERTY_HIDDEN if use_global_gravity else PROPERTY_VISIBLE
			property.hint_string = &"suffix:m/s²"


func set_spring_freq(value: float) -> void:
	spring_freq = maxf(0.0, value)
	emit_changed()


func set_angular_damp(value: float) -> void:
	angular_damp = maxf(0.0, value)
	emit_changed()


func set_torque_scale(value: float) -> void:
	torque_scale = maxf(0.0, value)
	emit_changed()


func set_swing_span(value: float) -> void:
	swing_span = clampf(value, 0.0, PI)
	emit_changed()


func set_use_global_gravity(value: bool) -> void:
	use_global_gravity = value
	_gravity_needs_update = true
	emit_changed()
	notify_property_list_changed()


func set_custom_gravity(value: Vector3) -> void:
	custom_gravity = value
	_gravity_needs_update = true
	emit_changed()


func set_handle_distance(value: float) -> void:
	handle_distance = maxf(0.0, value)
	emit_changed()


## Get [member custom_gravity] or global gravity if [member use_global_gravity] is
## [code]true[/code].
func get_gravity() -> Vector3:
	if _gravity_needs_update:
		if use_global_gravity:
			var default_gravity: float = ProjectSettings.get_setting(&"physics/3d/default_gravity")
			var default_gravity_vector: Vector3 = ProjectSettings.get_setting(&"physics/3d/default_gravity_vector")

			_gravity = default_gravity_vector * default_gravity

		else:
			_gravity = custom_gravity

		_gravity_needs_update = false

	return _gravity


func _on_project_settings_changed() -> void:
	_gravity_needs_update = true
