class_name RoomTransition
extends Area2D

@export var target_room_id := ""
@export var spawn_marker := "SpawnPoint"
@export var transition_dir := Vector2.DOWN

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("room_transition")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var main := get_node_or_null("/root/Main")
		if main and main.has_method("transition_to_room"):
			main.transition_to_room(target_room_id, spawn_marker)
