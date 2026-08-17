@tool
extends EditorPlugin
## NOMADZ Scene Kit — EditorPlugin entry point
## Loads dock UI + registers custom types
## VULTURE:INC / VultureCode

const DOCK_SCENE = preload("res://addons/nomadz_scene_kit/nomadz_scene_kit.gd")
var _dock: Control

func _enter_tree() -> void:
	_dock = DOCK_SCENE.new()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	add_custom_type(
		"SceneSwitcher",
		"Node3D",
		preload("res://addons/nomadz_scene_kit/scene_switcher.gd"),
		null
	)
	print("[NOMADZ Scene Kit] Plugin v1.0.0 loaded — VULTURE:INC")

func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	remove_custom_type("SceneSwitcher")
	print("[NOMADZ Scene Kit] Plugin unloaded")
