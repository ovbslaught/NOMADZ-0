@tool
extends RefCounted

const RopePathGizmoToggles = preload("../rope_path_gizmo_toggles.gd")

enum GizmoCheckbox {
	SHOW_AABBS = 10,
	SHOW_COLLISION_SHAPES = 11, 
	SHOW_ORIGIN = 12,
}

var _plugin: EditorPlugin
var _submenu: PopupMenu
var _toggles: RopePathGizmoToggles
var _submenu_name := "DebugGizmos"

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_create_submenu()

func _create_submenu() -> void:
	_submenu = PopupMenu.new()
	_submenu.name = _submenu_name
	_submenu.add_check_item("Show AABBs", GizmoCheckbox.SHOW_AABBS)
	_submenu.add_check_item("Show CollisionShapes", GizmoCheckbox.SHOW_COLLISION_SHAPES)
	_submenu.add_check_item("Show Origins", GizmoCheckbox.SHOW_ORIGIN)
	_submenu.id_pressed.connect(_on_gizmos_submenu_item_pressed)

func _on_gizmos_submenu_item_pressed(id: int) -> void:
	match id:
		GizmoCheckbox.SHOW_AABBS:
			_toggles.visible_aabbs = not _toggles.visible_aabbs
		GizmoCheckbox.SHOW_COLLISION_SHAPES:
			_toggles.visible_collision_shapes = not _toggles.visible_collision_shapes
		GizmoCheckbox.SHOW_ORIGIN:
			_toggles.visible_origins = not _toggles.visible_origins
	
	_reflect_toggles_in_submenu()
	_plugin.get_tree().root.propagate_call(&"update_gizmos")

func _reflect_toggles_in_submenu() -> void:
	if _toggles == null:
		return
	
	var show_aabbs_idx := _submenu.get_item_index(GizmoCheckbox.SHOW_AABBS)
	var show_collsion_shapes_idx := _submenu.get_item_index(GizmoCheckbox.SHOW_COLLISION_SHAPES)
	var show_origin_idx := _submenu.get_item_index(GizmoCheckbox.SHOW_ORIGIN)
	
	_submenu.set_item_checked(show_aabbs_idx, _toggles.visible_aabbs)
	_submenu.set_item_checked(show_collsion_shapes_idx, _toggles.visible_collision_shapes)
	_submenu.set_item_checked(show_origin_idx, _toggles.visible_origins)

# public interface
func set_toggles(toggles: RopePathGizmoToggles) -> void:
	_toggles = toggles
	_reflect_toggles_in_submenu.call_deferred()

func get_submenu() -> PopupMenu:
	return _submenu

func get_submenu_name() -> String:
	return _submenu.name

func cleanup() -> void:
	_submenu.queue_free()