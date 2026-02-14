@tool
extends EditorPlugin

const AUTOLOADS := {
	"GMap": "map.gd",
}


func _enter_tree() -> void:
	for autoload in AUTOLOADS:
		add_autoload_singleton(autoload, AUTOLOADS[autoload])
	return


func _exit_tree() -> void:
	for autoload in AUTOLOADS:
		remove_autoload_singleton(autoload)
	return
