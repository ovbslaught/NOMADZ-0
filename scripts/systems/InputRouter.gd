extends Node

var external_intent: Dictionary = {}

func get_move_vector() -> Vector2:
    return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

func is_action_active(action_name: String) -> bool:
    if external_intent.has(action_name):
        return external_intent[action_name]
    return Input.is_action_pressed(action_name)
