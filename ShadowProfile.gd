extends Node
class_name ShadowProfile

var decisions: Array = []
var ghost = preload("res://scenes/GhostPlayer.tscn")

func record_decision(action: String, pos: Vector3):
\tdecisions.append({"action": action, "pos": pos})

func spawn_ghost():
\tvar instance = ghost.instantiate()
\tget_tree().current_scene.add_child(instance)