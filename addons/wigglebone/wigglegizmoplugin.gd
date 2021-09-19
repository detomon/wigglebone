extends EditorSpatialGizmoPlugin

class_name WiggleGizmoPlugin

const SQRT_1_2: = 0.7071067812

var gizmo_lines: = generate_lines()

func _init() -> void:
	create_material("main", Color.red, false, true)
	create_handle_material("handles")

func get_name() -> String:
	return "WiggleBone"

func has_gizmo(spatial: Spatial) -> bool:
	return spatial is WiggleBone

func redraw(gizmo: EditorSpatialGizmo) -> void:
	gizmo.clear()

	var spatial: WiggleBone = gizmo.get_spatial_node()
	var properties: WiggleProperties = spatial.properties

	if properties and spatial.show_gizmo:
		var length: = properties.mass_center.length()
		var scale_x: = sin(deg2rad(properties.max_degrees)) / SQRT_1_2
		var scale_y: = cos(deg2rad(properties.max_degrees)) / SQRT_1_2
		var scale: = Vector3(scale_x, scale_y, scale_x) * length * 0.5

		var lines: = lines(scale)
		lines.append(Vector3(0, 0, 0))
		lines.append(properties.mass_center)

		gizmo.add_lines(lines, get_material("main", gizmo), false)

func generate_lines() -> PoolVector3Array:
	var count: = 6
	var lines: = PoolVector3Array()
	var prev_point: = Vector3()
	var points: = PoolVector3Array()

	for i in count:
		var x: = cos(i * TAU / float(count))
		var y: = sin(i * TAU / float(count))
		var point: = Vector3(x, 1, y)

		points.append(point)
		lines.append(Vector3(0, 0, 0))
		lines.append(point)

	for i in len(points) - 1:
		lines.append(points[i])
		lines.append(points[i + 1])

	lines.append(points[0])
	lines.append(points[len(points) - 1])

	return lines

func lines(scale: Vector3) -> PoolVector3Array:
	var new_lines: = gizmo_lines

	for i in len(new_lines):
		new_lines[i] *= scale

	return new_lines
