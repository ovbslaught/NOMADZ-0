@tool
extends EditorPlugin

const DOCK_SCENE = preload("res://addons/ai_assistant_hub/AIAssistantDock.tscn")
var dock_instance: Control

func _enter_tree() -> void:
	dock_instance = Control.new()
	dock_instance.name = "AI Assistant"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_instance)
	print("[AIAssistantHub] Plugin activated and dock registered.")

func _exit_tree() -> void:
	if dock_instance:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
	print("[AIAssistantHub] Plugin deactivated.")
