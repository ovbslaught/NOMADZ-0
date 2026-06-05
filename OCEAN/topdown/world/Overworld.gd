class_name Overworld
extends Node2D

signal room_entered(room_id: String)

@export var overworld_id := "overworld_1"
@export var tilemap: TileMap

@onready var player_spawn := $PlayerSpawn
@onready var enemies := $Enemies
@onready var interactables := $Interactables

func _ready() -> void:
	if not tilemap:
		tilemap = $TileMap as TileMap
	_spawn_player()
	GameManager.enter_room(overworld_id)

func _spawn_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("Overworld: No player in group 'player'")
		return
	if player_spawn:
		player.global_position = player_spawn.global_position

func get_enemies() -> Array[Node]:
	return enemies.get_children() if enemies else []

func get_interactables() -> Array[Node]:
	return interactables.get_children() if interactables else []

func _on_room_transition_entered(_body: Node2D, target_room: String, spawn_marker: String) -> void:
	room_entered.emit(target_room)
	var main := get_node_or_null("/root/Main")
	if main and main.has_method("transition_to_room"):
		main.transition_to_room(target_room, spawn_marker)
