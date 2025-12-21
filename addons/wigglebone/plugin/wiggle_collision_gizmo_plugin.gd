@tool
extends EditorNode3DGizmoPlugin

const Functions := preload("../functions.gd")

var _box_lines := Functions.create_box_lines()
var _sphere_lines := Functions.create_sphere_lines()
var _cap_lines := Functions.create_cap_lines()
var _ring_points := Functions.get_ring_points()
var _cylinder_lines := PackedVector3Array([
	Vector3(+1.0, -1.0, +0.0),
	Vector3(+1.0, +1.0, +0.0),
	Vector3(-1.0, -1.0, +0.0),
	Vector3(-1.0, +1.0, +0.0),
	Vector3(+0.0, -1.0, +1.0),
	Vector3(+0.0, +1.0, +1.0),
	Vector3(+0.0, -1.0, -1.0),
	Vector3(+0.0, +1.0, -1.0),
])


func _init() -> void:
	var editor_settings = EditorInterface.get_editor_settings()
	var shape_color: Color = editor_settings.get(&"editors/3d_gizmos/gizmo_colors/shape")
	var disabled_color: Color = editor_settings.get(&"editors/3d_gizmos/gizmo_colors/instantiated")

	create_material(&"main", shape_color, false)
	create_material(&"disabled", disabled_color, false)


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is DMWBWiggleCollision3D


func _get_gizmo_name() -> String:
	return &"DMWBWiggleCollision3D"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node: DMWBWiggleCollision3D = gizmo.get_node_3d()

	if not node.shape:
		return

	var material_name := &"disabled" if node.disabled else &"main"
	var material := get_material(material_name, gizmo)

	if node.shape is SphereShape3D:
		var shape: SphereShape3D = node.shape
		Functions.gizmo_draw_sphere(gizmo, material, _sphere_lines, shape.radius)

	elif node.shape is BoxShape3D:
		var shape: BoxShape3D = node.shape
		Functions.gizmo_draw_box(gizmo, material, _box_lines, shape.size)

	elif node.shape is CylinderShape3D:
		var shape: CylinderShape3D = node.shape
		var radius := shape.radius
		var height := shape.height
		var top_xform := Transform3D().scaled(Vector3.ONE * radius).translated(Vector3.UP * height * 0.5)
		var bottom_xform := top_xform.rotated(Vector3.RIGHT, PI)
		var cylinder_xform := Transform3D().scaled(Vector3(radius, height * 0.5, radius))

		var lines := top_xform * _ring_points
		lines.append_array(bottom_xform * _ring_points)
		lines.append_array(cylinder_xform * _cylinder_lines)

		gizmo.add_lines(lines, material, true)

	elif node.shape is CapsuleShape3D:
		var shape: CapsuleShape3D = node.shape
		var radius := shape.radius
		var height := shape.height - radius * 2.0
		var top_xform := Transform3D().scaled(Vector3.ONE * radius).translated(Vector3.UP * height * 0.5)
		var bottom_xform := top_xform.rotated(Vector3.RIGHT, PI)
		var cylinder_xform := Transform3D().scaled(Vector3(radius, height * 0.5, radius))

		var lines := top_xform * _cap_lines
		lines.append_array(bottom_xform * _cap_lines)
		lines.append_array(cylinder_xform * _cylinder_lines)

		gizmo.add_lines(lines, material, true)
