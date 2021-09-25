tool
extends EditorPlugin

const gizmo_script: Script = preload("wigglegizmoplugin.gd")
const wigglebone: Script = preload("wigglebone.gd")
const icon: Texture = preload("icon.svg")

var gizmo_plugin: = gizmo_script.new()

func _enter_tree() -> void:
	add_custom_type("WiggleBone", "Spatial", wigglebone, icon)
	add_spatial_gizmo_plugin(gizmo_plugin)

func _exit_tree() -> void:
	remove_spatial_gizmo_plugin(gizmo_plugin)
	remove_custom_type("WiggleBone")
