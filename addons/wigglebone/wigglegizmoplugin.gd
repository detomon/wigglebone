extends EditorSpatialGizmoPlugin

class_name WiggleGizmoPlugin

const SQRT_1_2: = 0.7071067812

var cone_lines: = generate_cone_lines()
var cube_lines: = generate_cube_lines()

func _init() -> void:
	create_material("main", Color.red, false, true)
	create_handle_material("handles")

func get_name() -> String:
	return "WiggleBone"

func has_gizmo(spatial: Spatial) -> bool:
	return spatial is WiggleBone

func redraw(gizmo: EditorSpatialGizmo) -> void:
	gizmo.clear()

	var wigglebone: WiggleBone = gizmo.get_spatial_node()
	var properties: WiggleProperties = wigglebone.properties

	if properties and wigglebone.show_gizmo:
		match properties.mode:
			WiggleProperties.Mode.ROTATION:
				var length: = properties.mass_center.length()
				var scale_x: = sin(deg2rad(properties.max_degrees)) / SQRT_1_2
				var scale_y: = cos(deg2rad(properties.max_degrees)) / SQRT_1_2
				var scale: = Vector3(scale_x, scale_y, scale_x)

				var bone_look_at: = WiggleBone.create_bone_look_at(properties.mass_center, Vector3.RIGHT)
				var transform: = bone_look_at * Basis().scaled(scale * length * 0.5)

				var lines: = transform_lines(cone_lines, transform)
				lines.append(Vector3(0, 0, 0))
				lines.append(properties.mass_center)

				gizmo.add_lines(lines, get_material("main", gizmo), false)

			WiggleProperties.Mode.DISLOCATION:
				var max_distance: = properties.max_distance
				var scale: = Vector3.ONE * max_distance
				var transform: = Basis().scaled(scale)

				var lines: = transform_lines(cube_lines, transform)

				gizmo.add_lines(lines, get_material("main", gizmo), false)

func generate_cone_lines() -> PoolVector3Array:
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

func generate_cube_lines() -> PoolVector3Array:
	return PoolVector3Array([
		Vector3(-1, -1, -1),
		Vector3(+1, -1, -1),
		Vector3(+1, -1, -1),
		Vector3(+1, -1, +1),
		Vector3(+1, -1, +1),
		Vector3(-1, -1, +1),
		Vector3(-1, -1, +1),
		Vector3(-1, -1, -1),

		Vector3(-1, +1, -1),
		Vector3(+1, +1, -1),
		Vector3(+1, +1, -1),
		Vector3(+1, +1, +1),
		Vector3(+1, +1, +1),
		Vector3(-1, +1, +1),
		Vector3(-1, +1, +1),
		Vector3(-1, +1, -1),

		Vector3(-1, -1, -1),
		Vector3(-1, +1, -1),
		Vector3(+1, -1, -1),
		Vector3(+1, +1, -1),
		Vector3(+1, -1, +1),
		Vector3(+1, +1, +1),
		Vector3(-1, -1, +1),
		Vector3(-1, +1, +1),
	])

static func transform_lines(lines: PoolVector3Array, transform: Basis) -> PoolVector3Array:
	var new_lines: = lines

	for i in len(new_lines):
		new_lines[i] = transform * new_lines[i]

	return new_lines
