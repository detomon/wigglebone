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

	bone.const_force = handle_position - handle_init_position

func commit_handle(gizmo: EditorSpatialGizmo, index: int, restore, cancel: bool = false) -> void:
	var bone: WiggleBone = gizmo.get_spatial_node()
	bone.const_force = Vector3.ZERO

	handle_init_position = Vector3.ZERO
	handle_position = Vector3.ZERO
	handle_dragging = false

func redraw(gizmo: EditorSpatialGizmo) -> void:
	var wigglebone: WiggleBone = gizmo.get_spatial_node()
	var properties: = wigglebone.properties

	gizmo.clear()

	if properties:
		match properties.mode:
			WiggleProperties.Mode.ROTATION:
				var length: = properties.mass_center.length()
				var angle: = deg2rad(properties.max_degrees)
				var scale_x: = sin(angle)
				var scale_y: = cos(angle)
				var scale: = Vector3(scale_x, scale_y, scale_x)

				var bone_look_at: = WiggleBone.create_bone_look_at(properties.mass_center, Vector3.RIGHT)
				var transform: = Transform(bone_look_at.scaled(scale * length * 0.75), Vector3.ZERO)

				var lines: PoolVector3Array = transform.xform(cone_lines)
				lines.append(Vector3.ZERO)
				lines.append(properties.mass_center)
				gizmo.add_lines(lines, get_material("main", gizmo), false)

			WiggleProperties.Mode.DISLOCATION:
				var max_distance: = properties.max_distance
				var scale: = Vector3.ONE * max_distance
				var transform: = Transform().scaled(scale)

				var lines: PoolVector3Array = transform.xform(sphere_lines)
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
	var points: = PoolVector3Array()

	for i in count:
		points.append(Vector3(1, 1, 0).rotated(Vector3.UP, i * TAU / count))

	var lines: = PoolVector3Array()

	for i in len(points) - 1:
		lines.append(points[i])
		lines.append(points[i + 1])

		if i % 8 == 0:
			lines.append(Vector3.ZERO)
			lines.append(points[i])

	lines.append(points[0])
	lines.append(points[len(points) - 1])

	return lines

static func generate_sphere_lines() -> PoolVector3Array:
	var count: = 24
	var points: = PoolVector3Array()

	for i in count:
		points.append(Vector3.RIGHT.rotated(Vector3.UP, i * TAU / count))

	var lines: = PoolVector3Array()
	var rotations: = [
		Transform(),
		Transform().rotated(Vector3.RIGHT, PI * 0.5),
		Transform().rotated(Vector3.BACK, PI * 0.5),
	]

	for transform in rotations:
		var new_lines: PoolVector3Array = transform.xform(points)

		for i in len(new_lines) - 1:
			lines.append(new_lines[i])
			lines.append(new_lines[i + 1])

		lines.append(new_lines[0])
		lines.append(new_lines[len(new_lines) - 1])

	return lines
