extends RefCounted

const SEGMENT_COUNT := 64

static var _ring_points := PackedVector3Array()


static func get_ring_points() -> PackedVector3Array:
	if _ring_points:
		return _ring_points.duplicate()

	const POINT_COUNT := SEGMENT_COUNT * 2
	_ring_points.resize(POINT_COUNT)

	for i in SEGMENT_COUNT:
		var point := Vector3.RIGHT.rotated(Vector3.UP, (i + 1) * TAU / SEGMENT_COUNT)
		_ring_points[(i * 2 + 1) % POINT_COUNT] = point
		_ring_points[(i * 2 + 2) % POINT_COUNT] = point

	return _ring_points


## Create line segments for a normalized cone wireframe.
static func create_cone_lines() -> PackedVector3Array:
	var transform := Transform3D().translated(Vector3.UP)
	var lines := transform * get_ring_points()
	var count := len(lines)

	for i in range(0, count, SEGMENT_COUNT / 4):
		lines.append(Vector3.ZERO)
		lines.append(lines[i])

	return lines


## Create line segments for a normalized sphere wireframe.
static func create_sphere_lines() -> PackedVector3Array:
	var rotations: Array[Transform3D] = [
		Transform3D(),
		Transform3D().rotated(Vector3.RIGHT, PI * 0.5),
		Transform3D().rotated(Vector3.BACK, PI * 0.5),
	]
	var points := get_ring_points()
	var lines := PackedVector3Array()

	for transform in rotations:
		lines.append_array(transform * points)

	return lines


## Create line segments for a normalized box wireframe.
static func create_box_lines() -> PackedVector3Array:
	var points := PackedVector3Array([
		Vector3(-0.5, -0.5, -0.5),
		Vector3(+0.5, -0.5, -0.5),
		Vector3(-0.5, +0.5, -0.5),
		Vector3(+0.5, +0.5, -0.5),
		Vector3(-0.5, -0.5, +0.5),
		Vector3(+0.5, -0.5, +0.5),
		Vector3(-0.5, +0.5, +0.5),
		Vector3(+0.5, +0.5, +0.5),
	])
	var rotations: Array[Transform3D] = [
		Transform3D(),
		Transform3D().rotated(Vector3.BACK, PI * 0.5),
		Transform3D().rotated(Vector3.UP, PI * 0.5),
	]
	var lines := PackedVector3Array()

	for transform in rotations:
		lines.append_array(transform * points)

	return lines


static func create_cap_lines() -> PackedVector3Array:
	var rotations: Array[Transform3D] = [
		Transform3D().rotated(Vector3.RIGHT, PI * 0.5),
		Transform3D().rotated(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, PI * 0.5),
	]
	var points := get_ring_points()
	var lines := PackedVector3Array()

	lines.append_array(points)

	points.resize(len(points) / 2) # Half circle.
	for transform in rotations:
		lines.append_array(transform * points)

	return lines


## Draw line segments created with [member create_cone_lines] to [param gizmo].
static func gizmo_draw_cone(gizmo: EditorNode3DGizmo, material: StandardMaterial3D, lines: PackedVector3Array, angle: float, length: float) -> void:
	var scale_x := sin(angle)
	var scale_y := cos(angle)
	var scale := Vector3(scale_x, scale_y, scale_x) * length * 0.75
	var transform := Transform3D().scaled(scale)

	lines = transform * lines
	lines.append(Vector3.ZERO)
	lines.append(Vector3.UP * length)
	gizmo.add_lines(lines, material, false)


## Draw line segments created with [member create_sphere_lines] to [param gizmo].
static func gizmo_draw_sphere(gizmo: EditorNode3DGizmo, material: StandardMaterial3D, lines: PackedVector3Array, length: float) -> void:
	var scale := Vector3.ONE * length
	var transform := Transform3D().scaled(scale)

	lines = transform * lines
	gizmo.add_lines(lines, material, true)


## Draw line segments created with [member create_box_lines] to [param gizmo].
static func gizmo_draw_box(gizmo: EditorNode3DGizmo, material: StandardMaterial3D, lines: PackedVector3Array, scale: Vector3) -> void:
	var transform := Transform3D().scaled(scale)

	lines = transform * lines
	gizmo.add_lines(lines, material, true)


## Get a naturally sorted list of bone names from [param skeleton].
static func get_sorted_skeleton_bones(skeleton: Skeleton3D) -> PackedStringArray:
	if not skeleton:
		return []

	var bone_count := skeleton.get_bone_count()
	var bone_names: Array[String] = []
	bone_names.resize(bone_count)

	for i in bone_count:
		bone_names[i] = skeleton.get_bone_name(i)

	bone_names.sort_custom(func (a: String, b: String) -> bool:
		return a.naturalcasecmp_to(b) < 0
	)

	return PackedStringArray(bone_names)


static func search_parent_skeleton(node: Node) -> Skeleton3D:
	var parent := node.get_parent()

	while parent:
		if parent is Skeleton3D:
			return parent
		parent = parent.get_parent()

	return null
