extends EditorSpatialGizmoPlugin

class_name WiggleGizmoPlugin

const GIZMO_SCALE: = Vector3(0.05, 0.2, 0.05)

var lines: = []

func _init() -> void:
	create_material("main", Color.red, false, true)
	create_handle_material("handles")
	lines = generate_lines(GIZMO_SCALE)

func get_name() -> String:
	return "Wiggle Bone"

func has_gizmo(spatial: Spatial) -> bool:
	return spatial is WiggleBone

func redraw(gizmo: EditorSpatialGizmo) -> void:
	print("redraw")

	gizmo.clear()

	var spatial: Spatial = gizmo.get_spatial_node()

	var handles: = PoolVector3Array([
		Vector3(0, 1, 0),
		Vector3(0, 2, 0),
	])

	gizmo.add_lines(lines, get_material("main", gizmo), false)
	gizmo.add_handles(handles, get_material("handles", gizmo))

func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	return [
		"Handle 1",
		"Handle 2",
	][index]

func get_handle_value(gizmo: EditorSpatialGizmo, index: int) -> float:
	return [
		0.1,
		0.5,
	][index]

func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	prints("commit", gizmo, index, restore, cancel)

func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	prints("handle", gizmo, index, camera, point)

func generate_lines(scale: Vector3) -> PoolVector3Array:
	return PoolVector3Array([
		Vector3(0, 0, 0) * scale,
		Vector3(1, 1, 1) * scale,
		Vector3(0, 0, 0) * scale,
		Vector3(-1, 1, 1) * scale,
		Vector3(0, 0, 0) * scale,
		Vector3(-1, 1, -1) * scale,
		Vector3(0, 0, 0) * scale,
		Vector3(1, 1, -1) * scale,

		Vector3(1, 1, 1) * scale,
		Vector3(-1, 1, 1) * scale,
		Vector3(-1, 1, 1) * scale,
		Vector3(-1, 1, -1) * scale,
		Vector3(-1, 1, -1) * scale,
		Vector3(1, 1, -1) * scale,
		Vector3(1, 1, -1) * scale,
		Vector3(1, 1, 1) * scale,
	])
