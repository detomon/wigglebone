tool
extends EditorPlugin

const GIZMO_SCRIPT: Script = preload("wigglegizmoplugin.gd")
const WIGGLEBONE: Script = preload("wigglebone.gd")
const ICON: Texture = preload("icon.svg")

var _gizmo_plugin: = GIZMO_SCRIPT.new()


func _enter_tree() -> void:
	add_custom_type("WiggleBone", "BoneAttachment", WIGGLEBONE, ICON)
	add_spatial_gizmo_plugin(_gizmo_plugin)

func _exit_tree() -> void:
	remove_spatial_gizmo_plugin(_gizmo_plugin)
	remove_custom_type("WiggleBone")
