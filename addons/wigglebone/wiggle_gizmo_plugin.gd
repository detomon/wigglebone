@tool
extends EditorNode3DGizmoPlugin

## @deprecated

const HANDLE_ID_FORCE := 0

const Functions := preload("functions.gd")

var _handle_init_position := Vector3.ZERO
var _handle_position := Vector3.ZERO
var _handle_dragging := false
var _cone_lines := Functions.create_cone_lines()
var _sphere_lines := Functions.create_sphere_lines()
var _force_global := Vector3.ZERO


func _init() -> void:
	create_material("main", Color.RED, false)
	create_handle_material("handles")


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is WiggleBone


func _get_gizmo_name() -> String:
	return "WiggleBone"


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	return "Force"


func _get_handle_value(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	return _handle_position - _handle_init_position


func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node: WiggleBone = gizmo.get_node_3d()
	var properties: WiggleProperties = node.properties
	var handle_position := _get_handle_position(properties)
	var depth := handle_position.distance_to(camera.global_transform.origin)

	handle_position = camera.project_position(point, depth)
	_handle_position = handle_position

	if not _handle_dragging:
		_force_global = node.const_force_global # Save current force.
		_handle_init_position = handle_position
		_handle_dragging = true

	var force := handle_position - _handle_init_position
	node.const_force_global = force


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	var node: WiggleBone = gizmo.get_node_3d()

	_handle_init_position = Vector3.ZERO
	_handle_position = Vector3.ZERO
	_handle_dragging = false
	node.const_force_global = _force_global # Reset force to previous value.


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var node: WiggleBone = gizmo.get_node_3d()
	var properties: WiggleProperties = node.properties
	var material := get_material("main", gizmo)

	gizmo.clear()

	if not properties:
		return

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var angle := deg_to_rad(properties.max_degrees)
			Functions.gizmo_draw_cone(gizmo, material, _cone_lines, angle, properties.length)

		WiggleProperties.Mode.DISLOCATION:
			Functions.gizmo_draw_sphere(gizmo, material, _sphere_lines, properties.max_distance)

	var handle_position := _get_handle_position(properties)
	gizmo.add_handles([handle_position], get_material("handles"), [HANDLE_ID_FORCE])


func _get_handle_position(properties: WiggleProperties) -> Vector3:
	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			return Vector3.UP * properties.length

		WiggleProperties.Mode.DISLOCATION:
			return Vector3.ZERO

	return Vector3.ZERO
