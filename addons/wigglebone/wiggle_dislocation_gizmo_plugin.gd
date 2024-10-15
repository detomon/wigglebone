@tool
extends EditorNode3DGizmoPlugin

const HANDLE_ID_FORCE := 0
const FORCE_MULTIPLIER := 10.0

const Functions := preload("functions.gd")

var _handle_init_position := Vector3.ZERO
var _handle_position := Vector3.ZERO
var _handle_force := Vector3.ZERO
var _handle_dragging := false
var _sphere_lines := Functions.create_sphere_lines()
var _force_global := Vector3.ZERO


func _init() -> void:
	create_material(&"main", Color.RED, false)
	create_handle_material(&"handles")


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is WiggleDislocationModifier3D


func _get_handle_name(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> String:
	return &"Force"


func _get_handle_value(_gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool) -> Variant:
	return _handle_force


func _get_gizmo_name() -> String:
	return &"WiggleDislocationModifier3D"


func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node: WiggleDislocationModifier3D = gizmo.get_node_3d()
	var properties: WiggleDislocationProperties3D = node.properties
	var handle_position := _get_handle_position(properties)
	var depth := handle_position.distance_to(camera.global_transform.origin)

	handle_position = camera.project_position(point, depth)
	_handle_position = handle_position

	if not _handle_dragging:
		_force_global = node.force_global # Save current force.
		_handle_init_position = handle_position
		_handle_dragging = true

	_handle_force = _get_handle_force(handle_position, properties)
	node.force_global = _handle_force


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	var node: WiggleDislocationModifier3D = gizmo.get_node_3d()

	_handle_init_position = Vector3.ZERO
	_handle_position = Vector3.ZERO
	_handle_dragging = false
	node.force_global = _force_global # Reset force to previous value.


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var node: WiggleDislocationModifier3D = gizmo.get_node_3d()
	var properties: WiggleDislocationProperties3D = node.properties

	gizmo.clear()

	if not properties:
		return

	var handle_position := _get_handle_position(properties)
	gizmo.add_handles([handle_position], get_material(&"handles"), [HANDLE_ID_FORCE])

	var material := get_material(&"main", gizmo)
	Functions.gizmo_draw_sphere(gizmo, material, _sphere_lines, properties.max_distance)


func _get_handle_position(_properties: WiggleDislocationProperties3D) -> Vector3:
	return Vector3.ZERO


func _get_handle_force(handle_position: Vector3, properties: WiggleDislocationProperties3D) -> Vector3:
	if properties.motion_influence <= 0.0:
		return Vector3.ZERO

	var force := handle_position - _handle_init_position
	var force_multiplier := properties.spring_freq * FORCE_MULTIPLIER

	return force * force_multiplier
