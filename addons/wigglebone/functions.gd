extends RefCounted


## Create line segments for a normalized cone wireframe.
static func create_cone_lines() -> PackedVector3Array:
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


## Create line segments for a normalized sphere wireframe.
static func create_sphere_lines() -> PackedVector3Array:
	var count := 32
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


## Get a naturally sorted list of bone names from [param skeleton].
static func get_sorted_skeleton_bones(skeleton: Skeleton3D) -> PackedStringArray:
	if not skeleton:
		return []

	var bone_names: Array[String] = []
	var bone_count := skeleton.get_bone_count()

	bone_names.resize(bone_count)
	for i in bone_count:
		bone_names[i] = skeleton.get_bone_name(i)

	bone_names.sort_custom(func (a: String, b: String) -> bool:
		return a.naturalcasecmp_to(b) < 0
	)

	return PackedStringArray(bone_names)
