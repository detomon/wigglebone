@tool
extends "wiggle_gizmo_plugin.gd"

const FORCE_MULTIPLIER := 50.0


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is WiggleRotationModifier3D


func _get_gizmo_name() -> String:
	return "WiggleRotationModifier3D"


func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node: WiggleRotationModifier3D = gizmo.get_node_3d()
	var properties: WiggleRotationProperties3D = node.properties
	var handle_position := _get_modifier_handle_position(properties)
	var depth := handle_position.distance_to(camera.global_transform.origin)

	handle_position = camera.project_position(point, depth)
	_handle_position = handle_position

	if not _handle_dragging:
		_force_global = node.force_global
		_handle_init_position = handle_position
		_handle_dragging = true

	var force := handle_position - _handle_init_position
	var force_multiplier := properties.length * maxf(1.0, properties.frequency) * FORCE_MULTIPLIER

	node.force_global = force * force_multiplier


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	var node: WiggleRotationModifier3D = gizmo.get_node_3d()

	node.force_global = _force_global
	_handle_init_position = Vector3.ZERO
	_handle_position = Vector3.ZERO
	_handle_dragging = false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var node: WiggleRotationModifier3D = gizmo.get_node_3d()
	var properties: WiggleRotationProperties3D = node.properties

	gizmo.clear()

	if not properties:
		return

	_draw_cone(gizmo, properties.max_rotation, properties.length)

	var handle_position := _get_modifier_handle_position(properties)
	gizmo.add_handles([handle_position], get_material("handles"), [HandleID.FORCE])


func _get_modifier_handle_position(properties: WiggleRotationProperties3D) -> Vector3:
	return Vector3.UP * properties.length
