@tool
extends EditorPlugin

const WiggleGizmoPlugin := preload("wiggle_gizmo_plugin.gd")
const WiggleModifierGizmoPlugin := preload("wiggle_modifier_gizmo_plugin.gd")

var _gizmo_plugin: WiggleGizmoPlugin
var _modifier_gizmo_plugin: WiggleModifierGizmoPlugin


func _enter_tree() -> void:
	_gizmo_plugin = WiggleGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)

	_modifier_gizmo_plugin = WiggleModifierGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_modifier_gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_modifier_gizmo_plugin)
	_modifier_gizmo_plugin = null
