class_name MV_BossRoom
extends MV_RoomBase

signal boss_engaged(room_id: String, boss_name: String)
signal boss_defeated(room_id: String, boss_name: String)

@export var boss_name := "Unknown"
@export var boss_scene: PackedScene
@export var arena_bounds: Rect2
@export var reward_item_id := ""

var _boss_instance: Node2D
var _engaged := false
var _defeated := false

func activate_room(player: Node2D) -> void:
	super(player)
	if _defeated or _engaged: return
	_engage_boss(player)

func _engage_boss(player: Node2D) -> void:
	_engaged = true
	boss_engaged.emit(room_id, boss_name)
	if boss_scene:
		_boss_instance = boss_scene.instantiate()
		enemies.add_child(_boss_instance)
		if _boss_instance.has_signal("defeated"):
			_boss_instance.defeated.connect(_on_boss_defeated)
	_lock_arena()

func _lock_arena() -> void:
	for door in get_door_nodes():
		if door.has_method("lock"):
			door.lock()

func _on_boss_defeated() -> void:
	_defeated = true
	boss_defeated.emit(room_id, boss_name)
	for door in get_door_nodes():
		if door.has_method("open"):
			door.open()
	if not reward_item_id.is_empty():
		GameManager.add_item(reward_item_id)
