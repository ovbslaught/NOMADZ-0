class_name MV_RoomBase
extends Node2D

signal room_activated(room_id: String)
signal room_deactivated(room_id: String)

@export var room_id := ""
@export var room_name := "Unknown"
@export var ambient_color: Color = Color(0.02, 0.02, 0.05)

@onready var spawn_points := $SpawnPoints
@onready var enemies := $Enemies
@onready var doors := $Doors
@onready var world_environment := $WorldEnvironment

func _ready() -> void:
	if room_id.is_empty():
		room_id = name
	add_to_group("metroidvania_room")

func activate_room(player: Node2D) -> void:
	visible = true
	set_process(true)
	_activate_enemies()
	room_activated.emit(room_id)
	GameManager.enter_room(room_id)

func deactivate_room() -> void:
	visible = false
	set_process(false)
	_deactivate_enemies()
	room_deactivated.emit(room_id)

func _activate_enemies() -> void:
	for enemy in get_enemy_nodes():
		if enemy.has_method("set_active"):
			enemy.set_active(true)

func _deactivate_enemies() -> void:
	for enemy in get_enemy_nodes():
		if enemy.has_method("set_active"):
			enemy.set_active(false)

func get_enemy_nodes() -> Array[Node]:
	return enemies.get_children() if enemies else []

func get_door_nodes() -> Array[Node]:
	return doors.get_children() if doors else []

func get_spawn_marker(marker_name: String = "SpawnPoint") -> Node2D:
	if spawn_points and spawn_points.has_node(marker_name):
		return spawn_points.get_node(marker_name) as Node2D
	return null

func _on_enemy_cleared() -> void:
	var remaining := get_enemy_nodes().filter(func(e): return is_instance_valid(e))
	if remaining.is_empty():
		_open_doors()

func _open_doors() -> void:
	for door in get_door_nodes():
		if door.has_method("open"):
			door.open()
