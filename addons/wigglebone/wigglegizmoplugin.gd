tool
extends EditorSpatialGizmoPlugin
class_name WiggleGizmoPlugin

var cone_lines: = generate_cone_lines()
var sphere_lines: = generate_sphere_lines()

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
				var scale_x: = sin(deg2rad(properties.max_degrees))
				var scale_y: = cos(deg2rad(properties.max_degrees))
				var scale: = Vector3(scale_x, scale_y, scale_x)

				var bone_look_at: = WiggleBone.create_bone_look_at(properties.mass_center, Vector3.RIGHT)
				var transform: = bone_look_at * Basis().scaled(scale * length * 0.75)

				var lines: = transform_points(cone_lines, transform)
				lines.append(Vector3(0, 0, 0))
				lines.append(properties.mass_center)

				gizmo.add_lines(lines, get_material("main", gizmo), false)

			WiggleProperties.Mode.DISLOCATION:
				var max_distance: = properties.max_distance
				var scale: = Vector3.ONE * max_distance
				var transform: = Basis().scaled(scale)

				var lines: = transform_points(sphere_lines, transform)

				gizmo.add_lines(lines, get_material("main", gizmo), true)

static func generate_cone_lines() -> PoolVector3Array:
	var count: = 32
	var points: = PoolVector3Array()

	for i in count:
		points.append(Vector3(1, 1, 0).rotated(Vector3.UP, i * TAU / count))

	var lines: = PoolVector3Array()

	for i in len(points) - 1:
		lines.append(points[i])
		lines.append(points[i + 1])

		if i % 8 == 0:
			lines.append(Vector3(0, 0, 0))
			lines.append(points[i])

	lines.append(points[0])
	lines.append(points[len(points) - 1])

	return lines

static func generate_sphere_lines() -> PoolVector3Array:
	var count: = 24
	var points: = PoolVector3Array()

	for i in count:
		points.append(Vector3(1, 0, 0).rotated(Vector3.UP, i * TAU / count))

	var lines: = PoolVector3Array()
	var rotations: = [
		Basis(),
		Basis().rotated(Vector3.RIGHT, PI * 0.5),
		Basis().rotated(Vector3.BACK, PI * 0.5),
	]

	for transform in rotations:
		var new_lines: = transform_points(points, transform)

		for i in len(new_lines) - 1:
			lines.append(new_lines[i])
			lines.append(new_lines[i + 1])

		lines.append(new_lines[0])
		lines.append(new_lines[len(new_lines) - 1])

	return lines

static func transform_points(points: PoolVector3Array, transform: Basis) -> PoolVector3Array:
	var new_points: = points

	for i in len(new_points):
		new_points[i] = transform * new_points[i]

	return new_points
