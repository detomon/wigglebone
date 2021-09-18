tool
extends Spatial

func _enter_tree() -> void:
	prepare_skeleton()
	print("prepare")

func prepare_skeleton() -> void:
	var skeleton: Skeleton = $Skeleton

	skeleton.clear_bones()

	var bone_idx1: = skeleton.get_bone_count()
	skeleton.add_bone("wiggle")
	var bone_idx2: = skeleton.get_bone_count()
	skeleton.add_bone("wiggle_end")
	var bone_idx3: = skeleton.get_bone_count()
	skeleton.add_bone("wiggle2_end")

	var bone_transform: = Transform().rotated(Vector3.RIGHT, PI * 0.5)

	skeleton.set_bone_rest(bone_idx1, bone_transform)
	skeleton.set_bone_rest(bone_idx2, Transform().translated(Vector3(0.0, 0.5, 0.0)))
	skeleton.set_bone_rest(bone_idx3, Transform().translated(Vector3(0.0, 0.5, 0.0)))
	skeleton.set_bone_parent(bone_idx2, bone_idx1)
	skeleton.set_bone_parent(bone_idx3, bone_idx2)
