extends Node

const RECOVERY_SCENE := "res://scene22.tscn"

func _ready() -> void:
	print("NOMADZ-0 recovery boot reached.")
	call_deferred("_start_recovery_scene")

func _start_recovery_scene() -> void:
	if not ResourceLoader.exists(RECOVERY_SCENE):
		push_error("Missing recovery scene: " + RECOVERY_SCENE)
		return

	var result := get_tree().change_scene_to_file(RECOVERY_SCENE)
	if result != OK:
		push_error(
			"Failed to load recovery scene: %s | error: %d"
			% [RECOVERY_SCENE, result]
		)
