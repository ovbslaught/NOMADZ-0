class_name MV_HubRoom
extends MV_RoomBase

signal player_rested(room_id: String)

@export var has_save_point := true
@export var has_shop := false
@export var ambient_audio: AudioStream

func activate_room(player: Node2D) -> void:
	super(player)
	if has_save_point:
		GameManager.set_save_point(room_id)

func rest_player() -> void:
	GameManager.heal_player(GameManager.get_max_health())
	player_rested.emit(room_id)
