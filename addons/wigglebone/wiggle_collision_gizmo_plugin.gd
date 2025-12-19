@tool
extends EditorNode3DGizmoPlugin

const Functions := preload("functions.gd")

var _sphere_lines := Functions.create_sphere_lines()


func _init() -> void:
	create_material(&"main", Color.CADET_BLUE, false)


func _has_gizmo(spatial: Node3D) -> bool:
	return spatial is DMWBWiggleCollision3D


func _get_gizmo_name() -> String:
	return &"DMWBWiggleCollision3D"


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var node: DMWBWiggleCollision3D = gizmo.get_node_3d()

	if not node.shape:
		return

	var material := get_material(&"main", gizmo)
	Functions.gizmo_draw_sphere(gizmo, material, _sphere_lines, 0.5)
