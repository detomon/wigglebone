@tool
extends EditorPlugin

const WigglePositionGizmoPlugin := preload("plugin/wiggle_position_gizmo_plugin.gd")
const WiggleRotationGizmoPlugin := preload("plugin/wiggle_rotation_gizmo_plugin.gd")
const WiggleCollisionGizmo := preload("plugin/wiggle_collision_gizmo_plugin.gd")
const WiggleGizmoPlugin := preload("plugin/wiggle_gizmo_plugin.gd")

var _position_gizmo_plugin: WigglePositionGizmoPlugin
var _rotation_gizmo_plugin: WiggleRotationGizmoPlugin
var _collision_gizmo_plugin: WiggleCollisionGizmo
var _gizmo_plugin: WiggleGizmoPlugin


func _enter_tree() -> void:
	_position_gizmo_plugin = WigglePositionGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_position_gizmo_plugin)

	_rotation_gizmo_plugin = WiggleRotationGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_rotation_gizmo_plugin)

	_collision_gizmo_plugin = WiggleCollisionGizmo.new()
	add_node_3d_gizmo_plugin(_collision_gizmo_plugin)

	_gizmo_plugin = WiggleGizmoPlugin.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(_position_gizmo_plugin)
	_position_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_rotation_gizmo_plugin)
	_rotation_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_collision_gizmo_plugin)
	_collision_gizmo_plugin = null

	remove_node_3d_gizmo_plugin(_gizmo_plugin)
	_gizmo_plugin = null
