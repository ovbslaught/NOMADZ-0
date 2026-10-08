class_name MV_TreasureRoom
extends MV_RoomBase

signal treasure_collected(room_id: String, item_id: String)

@export var chest_count := 1
@export var items: Array[String] = []
@export var respawnable := false

var _collected_chests := 0

func activate_room(player: Node2D) -> void:
	super(player)
	if _collected_chests >= chest_count and not respawnable: return

func on_chest_opened(item_id: String) -> void:
	_collected_chests += 1
	items.append(item_id)
	treasure_collected.emit(room_id, item_id)
	if not item_id.is_empty():
		GameManager.add_item(item_id)
