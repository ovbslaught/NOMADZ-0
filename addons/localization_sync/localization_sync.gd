@tool
extends EditorPlugin

const TRANSLATIONS = "internationalization/locale/translations"
const PLUGIN_FOLDER = "res://addons/localization_sync"
const TOOL_NAME = "Localization Sync"
const LOCALIZATION_SYNC_PANEL = preload("uid://2eruroryqtba")
var panel 


func _enter_tree():
	add_tool_menu_item(TOOL_NAME, _open_tool)
	_open_tool()

func _enable_plugin() -> void:
	pass

func _open_tool():
	if panel:
		remove_control_from_docks(panel)
		panel.queue_free()
		
	panel = LOCALIZATION_SYNC_PANEL.instantiate()
	panel.name = "Localization Auto Sync"
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, panel)

func _disable_plugin() -> void:
	remove_tool_menu_item(TOOL_NAME)
	if panel:
		remove_control_from_docks(panel)
		panel.queue_free()
