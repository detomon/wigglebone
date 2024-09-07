@tool
extends EditorNode3DGizmoPlugin

enum HandleID {
	FORCE,
}

var _handle_init_position := Vector3.ZERO
var _handle_position := Vector3.ZERO
var _handle_dragging := false
var _cone_lines := _generate_cone_lines()
var _sphere_lines := _generate_sphere_lines()


func _init() -> void:
	create_material("main", Color.RED, false)
	create_handle_material("handles")


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is WiggleBone


func _get_gizmo_name() -> String:
	return "WiggleBone"


func _get_handle_name(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> String:
	match handle_id:
		HandleID.FORCE:
			return "Force"

		_:
			return ""


func _get_handle_value(_gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool) -> Variant:
	match handle_id:
		HandleID.FORCE:
			return _handle_position - _handle_init_position

		_:
			return Vector3.ZERO


func _set_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node: WiggleBone = gizmo.get_node_3d()
	var properties: WiggleProperties = node.properties
	var handle_position := _get_handle_position(properties)
	var depth := handle_position.distance_to(camera.global_transform.origin)

	handle_position = camera.project_position(point, depth)
	_handle_position = handle_position

	if not _handle_dragging:
		_handle_init_position = handle_position
		_handle_dragging = true

	var force := handle_position - _handle_init_position
	node.const_force_global = force


func _commit_handle(gizmo: EditorNode3DGizmo, _handle_id: int, _secondary: bool, _restore: Variant, _cancel: bool) -> void:
	var node: WiggleBone = gizmo.get_node_3d()

	node.const_force_global = Vector3.ZERO
	_handle_init_position = Vector3.ZERO
	_handle_position = Vector3.ZERO
	_handle_dragging = false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	var node: WiggleBone = gizmo.get_node_3d()
	var properties: WiggleProperties = node.properties

	gizmo.clear()

	if not properties:
		return

	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			var angle := deg_to_rad(properties.max_degrees)
			_draw_cone(gizmo, angle, properties.length)

		WiggleProperties.Mode.DISLOCATION:
			_draw_sphere(gizmo, properties.max_distance)

	var handle_position := _get_handle_position(properties)
	gizmo.add_handles([handle_position], get_material("handles"), [HandleID.FORCE])


func _draw_cone(gizmo: EditorNode3DGizmo, angle: float, length: float) -> void:
	var scale_x := sin(angle)
	var scale_y := cos(angle)
	var scale := Vector3(scale_x, scale_y, scale_x) * length * 0.75
	var transform := Transform3D().scaled(scale)

	var lines: PackedVector3Array = transform * _cone_lines
	lines.append(Vector3.ZERO)
	lines.append(Vector3.UP * length)
	gizmo.add_lines(lines, get_material("main", gizmo), false)


func _draw_sphere(gizmo: EditorNode3DGizmo, length: float) -> void:
	var scale := Vector3.ONE * length
	var transform := Transform3D().scaled(scale)

	var lines: PackedVector3Array = transform * _sphere_lines
	gizmo.add_lines(lines, get_material("main", gizmo), true)


func _get_handle_position(properties: WiggleProperties) -> Vector3:
	match properties.mode:
		WiggleProperties.Mode.ROTATION:
			return Vector3.UP * properties.length

		WiggleProperties.Mode.DISLOCATION:
			return Vector3.ZERO

	return Vector3.ZERO


func _generate_cone_lines() -> PackedVector3Array:
	var count := 32
	var points := PackedVector3Array()

	for i in count:
		points.append(Vector3(1, 1, 0).rotated(Vector3.UP, i * TAU / count))

	var lines := PackedVector3Array()

	for i in len(points) - 1:
		lines.append(points[i])
		lines.append(points[i + 1])

		if i % 8 == 0:
			lines.append(Vector3.ZERO)
			lines.append(points[i])

	lines.append(points[0])
	lines.append(points[len(points) - 1])

	return lines


func _generate_sphere_lines() -> PackedVector3Array:
	var count := 24
	var points := PackedVector3Array()

	for i in count:
		points.append(Vector3.RIGHT.rotated(Vector3.UP, i * TAU / count))

	var lines := PackedVector3Array()
	var rotations := [
		Transform3D(),
		Transform3D().rotated(Vector3.RIGHT, PI * 0.5),
		Transform3D().rotated(Vector3.BACK, PI * 0.5),
	]

	for transform: Transform3D in rotations:
		var new_lines := transform * points

		for i in len(new_lines) - 1:
			lines.append(new_lines[i])
			lines.append(new_lines[i + 1])

		lines.append(new_lines[0])
		lines.append(new_lines[len(new_lines) - 1])

	return lines
