@tool
@icon("icons/resource_spring.svg")
class_name WiggleRotationProperties3D
extends Resource

## Defines the properties used to move the bone.

const PROPERTY_VISIBLE := PROPERTY_USAGE_DEFAULT
const PROPERTY_HIDDEN := PROPERTY_VISIBLE & ~PROPERTY_USAGE_EDITOR
const DEFAULT_VALUES := {
	frequency = 3.0,
	damping = 0.1,
	gravity = Vector3.ZERO,
	length = 0.1,
	max_rotation = 60.0 / 180.0 * PI,
}

## Spring frequency without damping.
## [br][br]
## [b]Note:[/b] Setting a value above [code]15[/code] may cause a resonance effect with the process
## frequency.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var frequency := DEFAULT_VALUES.frequency:
	set = set_frequency
## Damping factor. Can be greater than [code]1.0[/code] to have even more influence.
@export_range(0.0, 1.0, 0.001, "or_greater") var damping := DEFAULT_VALUES.damping: set = set_damping
## The bone length. This influences, how much of the global movement is applied to the rotation.
@export_range(0.01, 1, 0.001, "or_greater", "suffix:m") var length := DEFAULT_VALUES.length:
	set = set_length
## Maximum rotation relative to the pose position.
@export_range(0.0, 90.0, 0.01, "radians") var max_rotation := DEFAULT_VALUES.max_rotation:
	set = set_max_rotation
## Uses the global gravity define in the project settings
## [member ProjectSettings.physics/3d/default_gravity] and
## [member ProjectSettings.physics/3d/default_gravity_vector]
@export var use_global_gravity := false: set = set_use_global_gravity
## Global gravity pulling at the mass center.
@export var custom_gravity := DEFAULT_VALUES.gravity: set = set_custom_gravity

var _gravity := Vector3.ZERO
var _spring_alpha := 0.0


func _init() -> void:
	ProjectSettings.settings_changed.connect(_on_project_settings_changed)


func _property_can_revert(property: StringName) -> bool:
	return property in DEFAULT_VALUES


func _property_get_revert(property: StringName) -> Variant:
	return DEFAULT_VALUES.get(property)


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"set_max_rotation":
			property.usage = PROPERTY_HIDDEN

		&"custom_gravity":
			property.usage = PROPERTY_HIDDEN if use_global_gravity else PROPERTY_VISIBLE
			property.hint_string = &"suffix:m/s²"


func set_frequency(value: float) -> void:
	frequency = maxf(0.0, value)
	_update_values()
	emit_changed()


func set_damping(value: float) -> void:
	damping = maxf(0.0, value)
	_update_values()
	emit_changed()


func set_length(value: float) -> void:
	length = maxf(0.01, value)
	emit_changed()


func set_max_rotation(value: float) -> void:
	max_rotation = value
	emit_changed()


func set_use_global_gravity(value: bool) -> void:
	use_global_gravity = value
	_update_gravity()
	emit_changed()
	notify_property_list_changed()


func set_custom_gravity(value: Vector3) -> void:
	custom_gravity = value
	_update_gravity()
	emit_changed()


## Get [member custom_gravity] or global gravity if [member use_global_gravity] is
## [code]true[/code].
func get_gravity() -> Vector3:
	return _gravity


## Internally used value.
func get_spring_alpha() -> float:
	return _spring_alpha


func _update_values() -> void:
	_spring_alpha = frequency * sqrt(1.0 - damping * damping)


func _update_gravity() -> void:
	if use_global_gravity:
		var default_gravity: float = ProjectSettings.get_setting(&"physics/3d/default_gravity")
		var default_gravity_vector: Vector3 = ProjectSettings.get_setting(&"physics/3d/default_gravity_vector")

		_gravity = default_gravity_vector * default_gravity

	else:
		_gravity = custom_gravity


func _on_project_settings_changed() -> void:
	_update_gravity()
