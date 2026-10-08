class_name MV_CombatRoom
extends MV_RoomBase

signal room_cleared(room_id: String)

@export var locked_doors_on_enter := true
@export var spawn_enemies_on_enter := true
@export var clear_condition: String = "all_enemies"

var _cleared := false

func _ready() -> void:
	super()
	add_to_group("combat_room")

func activate_room(player: Node2D) -> void:
	super(player)
	if _cleared: return
	if locked_doors_on_enter:
		_lock_doors()

func _on_enemy_cleared() -> void:
	var remaining := get_enemy_nodes().filter(func(e): return is_instance_valid(e) and e.has_method("is_alive") and e.is_alive())
	if remaining.is_empty() and not _cleared:
		_cleared = true
		_open_doors()
		room_cleared.emit(room_id)

func _lock_doors() -> void:
	for door in get_door_nodes():
		if door.has_method("lock"):
			door.lock()

func _open_doors() -> void:
	for door in get_door_nodes():
		if door.has_method("open"):
			door.open()

func is_cleared() -> bool:
	return _cleared
