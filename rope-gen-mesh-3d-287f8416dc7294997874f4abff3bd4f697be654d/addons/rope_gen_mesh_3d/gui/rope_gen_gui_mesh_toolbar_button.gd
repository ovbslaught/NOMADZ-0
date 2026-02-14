@tool
extends RefCounted

# the convention chosen is to not pollute user class space with irrelevant stuff
# so all the important classes for ui components are resolved as preloads bound to consts
# and all of them start with rope_gen_gui_* prefix to avoid getting caught in random file search
# todo: replace with uids
const RopePathGizmoToggles = preload("../rope_path_gizmo_toggles.gd")
const UVViewerDialog = preload("rope_gen_gui_uv_viewer_dialog.gd")
const GizmoMenuHandler = preload("rope_gen_gui_gizmo_submenu_handler.gd")

var _plugin: EditorPlugin
var _menu_button: MenuButton
var _menu_icon: Texture2D
var _err_dialog: AcceptDialog

var _selected_rope_gen_mesh_3d: RopeGenMesh3D
var _uv_viewer: UVViewerDialog
var _gizmo_submenu: GizmoMenuHandler

enum MenuOption {
	DEBUG_GIZMOS_SUBMENU = 0,
	VIEW_UV = 1,
}

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	
	var editor_selection := _plugin.get_editor_interface().get_selection()
	editor_selection.selection_changed.connect(_on_selection_changed)

	_err_dialog = AcceptDialog.new()
	_uv_viewer = UVViewerDialog.new(_plugin)
	_gizmo_submenu = GizmoMenuHandler.new(_plugin)
	_menu_button = MenuButton.new()
	_menu_button.text = "RopeGenMesh3D"

	var menu_icon = preload("../rope_gen_mesh_3d.svg")
	if menu_icon:
		_menu_button.icon = menu_icon
		_menu_button.add_theme_constant_override(&"icon_max_width", 16)
		_menu_button.add_theme_constant_override(&"h_separation", 4)
	
	_menu_button.add_child(_err_dialog)
	_menu_button.add_child(_uv_viewer.get_dialog())
	
	_plugin.add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _menu_button)
	
	var popup := _menu_button.get_popup()
	popup.add_child(_gizmo_submenu.get_submenu())
	popup.add_submenu_item("Debug Gizmos", _gizmo_submenu.get_submenu_name(), MenuOption.DEBUG_GIZMOS_SUBMENU)
	popup.add_separator()
	popup.add_item("View/Edit UV1", MenuOption.VIEW_UV)
	popup.id_pressed.connect(_on_menu_item_pressed)

func cleanup() -> void:
	_plugin.remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, _menu_button)
	_err_dialog.queue_free()
	_uv_viewer.cleanup()
	_gizmo_submenu.cleanup()
	_menu_button.queue_free()

func _on_selection_changed() -> void:
	var selected = _plugin.get_editor_interface().get_selection().get_selected_nodes()
	
	if selected.is_empty():
		_menu_button.visible = false
		return
	
	for node in selected:
		if not (node is RopeGenMesh3D):
			_menu_button.visible = false
			return
	
	_menu_button.visible = true
	
	var popup := _menu_button.get_popup()
	var uv_viewer_idx := popup.get_item_index(MenuOption.VIEW_UV)
	popup.set_item_disabled(uv_viewer_idx, selected.size() != 1)
	
	if selected.size() == 1:
		_selected_rope_gen_mesh_3d = selected[0] as RopeGenMesh3D

func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuOption.VIEW_UV:
			if _selected_rope_gen_mesh_3d.rope_data == null:
				_err_dialog.dialog_text = "Selected node does not have any RopeData resource present!"
				_err_dialog.popup_centered()
				return
			
			if not _selected_rope_gen_mesh_3d.has_generated_mesh():
				_err_dialog.dialog_text = "Selected node does not contain any generated meshes!"
				_err_dialog.popup_centered()
				return
			
			_uv_viewer.show_for_mesh(_selected_rope_gen_mesh_3d)

# builder methods
func add_gizmo_toggles(toggles: RopePathGizmoToggles) -> RefCounted:
	_gizmo_submenu.set_toggles(toggles)
	return self