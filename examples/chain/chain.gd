tool
extends Spatial

func _enter_tree() -> void:
	build_skeleton()

func build_skeleton() -> void:
	var skeleton: Skeleton = $Skeleton

	skeleton.clear_bones()

	var idx1: = skeleton.get_bone_count()
	skeleton.add_bone("bone1")
	skeleton.set_bone_rest(idx1, Transform())

	var idx2: = skeleton.get_bone_count()
	skeleton.add_bone("bone2")
	skeleton.set_bone_parent(idx2, idx1)
	skeleton.set_bone_rest(idx2, Transform().translated(Vector3(0.0, 0.5, 0.0)))

	# only needed for bone2 to be visible in Skeleton
	var idx3: = skeleton.get_bone_count()
	skeleton.add_bone("end")
	skeleton.set_bone_parent(idx3, idx2)
	skeleton.set_bone_rest(idx3, Transform().translated(Vector3(0.0, 0.5, 0.0)))
