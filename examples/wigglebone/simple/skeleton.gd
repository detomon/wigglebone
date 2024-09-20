@tool
extends Skeleton3D

@export var create_bones := false: set = set_create_bones


func set_create_bones(value: bool) -> void:
	if not value:
		return

	clear_bones()

	var idx0 := get_bone_count()
	add_bone("bone0")
	set_bone_rest(idx0, Transform3D().rotated(Vector3.RIGHT, PI).translated(Vector3(0.0, 0.0, -1.0)))

	var idx1 := get_bone_count()
	add_bone("bone1")
	set_bone_parent(idx1, idx0)
	set_bone_rest(idx1, Transform3D().translated(Vector3(0.0, 0.0, 1.0)).rotated(Vector3.RIGHT, -PI))

	# Needed for "bone1" to be visible in editor.
	var idx2 := get_bone_count()
	add_bone("end")
	set_bone_parent(idx2, idx1)
	set_bone_rest(idx2, Transform3D().translated(Vector3(0.0, 0.5, 0.0)))

	reset_bone_poses()
