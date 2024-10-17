@tool
@icon("icons/wiggle_dislocation_properties_3d.svg")
class_name WiggleDislocationProperties3D
extends Resource

## Defines the properties used to move the bone.

const DEFAULT := {
	spring_freq = 3.0,
	linear_damp = 0.1,
	motion_influence = 1.0,
	max_distance = 0.1,
	gravity = Vector3.ZERO,
}

## Spring frequency without damping.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:Hz") var spring_freq := DEFAULT.spring_freq:
	set = set_spring_freq
## Damping factor. Can be greater than [code]1.0[/code] to have even more influence.
## [br][br]
## [b]Note:[/b] Setting a damping factor near [code]0.0[/code] and having a [member frequency] near
## the process frequency may cause a resonance effect.
@export_range(0.0, 1.0, 0.001, "or_greater") var linear_damp := DEFAULT.linear_damp:
	set = set_linear_damp
## Defines, how much global movement influences motion.
@export_range(0.0, 1.0, 0.001, "or_greater") var motion_influence := DEFAULT.motion_influence:
	set = set_motion_influence
## Maximum distance the bone can move around its pose position.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:m") var max_distance := DEFAULT.max_distance:
	set = set_max_distance
## Uses the global gravity define in the project settings
## [member ProjectSettings.physics/3d/default_gravity] and
## [member ProjectSettings.physics/3d/default_gravity_vector]
@export var use_global_gravity := false:
	set = set_use_global_gravity
## Global gravity pulling at the mass center.
@export var custom_gravity := DEFAULT.gravity:
	set = set_custom_gravity

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
		&"custom_gravity":
			property.usage = PROPERTY_HIDDEN if use_global_gravity else PROPERTY_VISIBLE
			property.hint_string = &"suffix:m/s²"


func set_spring_freq(value: float) -> void:
	spring_freq = maxf(0.0, value)
	emit_changed()


func set_linear_damp(value: float) -> void:
	linear_damp = maxf(0.0, value)
	emit_changed()

func set_motion_influence(value: float) -> void:
	motion_influence = maxf(0.0, value)
	emit_changed()


func set_max_distance(value: float) -> void:
	max_distance = value
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
