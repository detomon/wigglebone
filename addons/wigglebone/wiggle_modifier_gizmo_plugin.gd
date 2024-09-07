@tool
extends "wiggle_gizmo_plugin.gd"


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is WiggleModifier3D


func _get_gizmo_name() -> String:
	return "WiggleModifier"


func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node: WiggleModifier3D = gizmo.get_node_3d()
	var properties: WiggleModifierProperties3D = node.properties
	var handle_position := _get_modifier_handle_position(properties)
	var depth := handle_position.distance_to(camera.global_transform.origin)

	handle_position = camera.project_position(point, depth)
	_handle_position = handle_position

	if not _handle_dragging:
		_handle_init_position = handle_position
		_handle_dragging = true

	var force := handle_position - _handle_init_position
	node.force_global = force


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	var node: WiggleModifier3D = gizmo.get_node_3d()

	node.force_global = Vector3.ZERO
	_handle_init_position = Vector3.ZERO
	_handle_position = Vector3.ZERO
	_handle_dragging = false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var node: WiggleModifier3D = gizmo.get_node_3d()
	var properties: WiggleModifierProperties3D = node.properties

	gizmo.clear()

	if not properties:
		return

	match properties.mode:
		WiggleModifierProperties3D.Mode.ROTATION:
			_draw_cone(gizmo, properties.max_rotation, properties.length)

		WiggleModifierProperties3D.Mode.DISLOCATION:
			_draw_sphere(gizmo, properties.max_distance)

	var handle_position := _get_modifier_handle_position(properties)
	gizmo.add_handles([handle_position], get_material("handles"), [HandleID.FORCE])


func _get_modifier_handle_position(properties: WiggleModifierProperties3D) -> Vector3:
	match properties.mode:
		WiggleModifierProperties3D.Mode.ROTATION:
			return Vector3.UP * properties.length

		WiggleModifierProperties3D.Mode.DISLOCATION:
			return Vector3.ZERO

	return Vector3.ZERO
