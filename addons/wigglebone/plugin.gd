@tool
extends EditorPlugin

const WiggleGizmoPlugin := preload("wiggle_gizmo_plugin.gd")
const WiggleDislocationGizmoPlugin := preload("wiggle_dislocation_gizmo_plugin.gd")
const WiggleRotationGizmoPlugin := preload("wiggle_rotation_gizmo_plugin.gd")

var _gizmo_plugin: WiggleGizmoPlugin
var _dislocation_gizmo_plugin: WiggleDislocationGizmoPlugin
var _rotation_gizmo_plugin: WiggleRotationGizmoPlugin


func _enter_tree() -> void:
	_gizmo_plugin = WiggleGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)

	_dislocation_gizmo_plugin = WiggleDislocationGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_dislocation_gizmo_plugin)

	_rotation_gizmo_plugin = WiggleRotationGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_rotation_gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_dislocation_gizmo_plugin)
	_dislocation_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_rotation_gizmo_plugin)
	_rotation_gizmo_plugin = null
