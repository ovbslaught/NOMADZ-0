class_name MV_TransitionRoom
extends MV_RoomBase

@export var target_room_id := ""
@export var transition_direction: Vector2 = Vector2.RIGHT
@export var auto_transition := false
@export var transition_delay := 0.5

func _ready() -> void:
	super()
	add_to_group("transition_room")

func activate_room(player: Node2D) -> void:
	super(player)
	if auto_transition and not target_room_id.is_empty():
		_transition()

func _transition() -> void:
	await get_tree().create_timer(transition_delay).timeout
	GameManager.transition_to_room(target_room_id, transition_direction)
