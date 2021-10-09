tool
extends EditorSpatialGizmoPlugin

var cone_lines: = generate_cone_lines()
var sphere_lines: = generate_sphere_lines()

var handle_init_position: = Vector3.ZERO
var handle_position: = Vector3.ZERO
var handle_dragging: = false

func _init() -> void:
	create_material("main", Color.red, false)
	create_handle_material("handles")

func get_name() -> String:
	return "WiggleBone"

func has_gizmo(spatial: Spatial) -> bool:
	return spatial is WiggleBone

func get_handle_name(gizmo: EditorSpatialGizmo, index: int) -> String:
	match index:
		0:
			return "Force"
		_:
			return ""

func get_handle_value(gizmo: EditorSpatialGizmo, index: int):
	match index:
		0:
			return handle_position - handle_init_position
		_:
			return Vector3.ZERO

func set_handle(gizmo: EditorSpatialGizmo, index: int, camera: Camera, point: Vector2) -> void:
	var bone: WiggleBone = gizmo.get_spatial_node()
	var handle_position: = bone.global_transform * get_handle_position(bone.properties)
	var depth: = (handle_position - camera.global_transform.origin).length()

	handle_position = camera.project_position(point, depth)

	if not handle_dragging:
		handle_init_position = handle_position
		handle_dragging = true

	bone.set_const_force(handle_position - handle_init_position)

func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var bone: WiggleBone = gizmo.get_spatial_node()
	bone.set_const_force(Vector3.ZERO)

	handle_init_position = Vector3.ZERO
	handle_position = Vector3.ZERO
	handle_dragging = false

func redraw(gizmo: EditorSpatialGizmo) -> void:
	var wigglebone: WiggleBone = gizmo.get_spatial_node()
	var properties: WiggleProperties = wigglebone.properties

	gizmo.clear()

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
				lines.append(Vector3.ZERO)
				lines.append(properties.mass_center)
				gizmo.add_lines(lines, get_material("main", gizmo), false)

			WiggleProperties.Mode.DISLOCATION:
				var max_distance: = properties.max_distance
				var scale: = Vector3.ONE * max_distance
				var transform: = Basis().scaled(scale)

				var lines: = transform_points(sphere_lines, transform)
				gizmo.add_lines(lines, get_material("main", gizmo), true)

		var handle: = get_handle_position(properties)
		gizmo.add_handles([handle], get_material("handles"), false)

static func get_handle_position(properties: WiggleProperties) -> Vector3:
	if properties:
		match properties.mode:
			WiggleProperties.Mode.ROTATION:
				return properties.mass_center

			WiggleProperties.Mode.DISLOCATION:
				return Vector3.ZERO

	return Vector3.ZERO

static func generate_cone_lines() -> PoolVector3Array:
	var count: = 32
	var lines: = PoolVector3Array()
	var prev_point: = Vector3(1, 1, 0)

	for i in range(1, count + 1):
		var point: = Vector3(1, 1, 0).rotated(Vector3.UP, i * TAU / count)

		lines.append(prev_point)
		lines.append(point)

		if i % 8 == 0:
			lines.append(Vector3(0, 0, 0))
			lines.append(point)

		prev_point = point

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
		var new_points: = transform_points(points, transform)

		for i in count:
			lines.append(new_points[i])
			lines.append(new_points[(i + 1) % count])

	return lines

static func transform_points(points: PoolVector3Array, transform: Basis) -> PoolVector3Array:
	var new_points: = points

	for i in len(new_points):
		new_points[i] = transform * new_points[i]

	return new_points
