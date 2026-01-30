extends RefCounted


## Get a naturally sorted list of bone names from [param skeleton].
static func get_sorted_skeleton_bones(skeleton: Skeleton3D) -> PackedStringArray:
	if not skeleton:
		return []

	var bone_names: Array = []
	var bone_count := skeleton.get_bone_count()

	bone_names.resize(bone_count)
	for i in bone_count:
		bone_names[i] = skeleton.get_bone_name(i)

	bone_names.sort_custom(func (a: String, b: String) -> bool:
		return a.naturalcasecmp_to(b) < 0
	)

	return PackedStringArray(bone_names)
