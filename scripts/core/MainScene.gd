extends Node3D

var player_scene = preload("res://scenes/player/Player.tscn")
@onready var spawn_point: Node3D = $WorldRoot/PlayerSpawn

func _ready() -> void:
    spawn_player()
    hook_autoloads()

func spawn_player() -> void:
    if player_scene and is_instance_valid(spawn_point):
        var p = player_scene.instantiate()
        add_child(p)
        p.global_position = spawn_point.global_position

func hook_autoloads() -> void:
    if Engine.has_singleton("Director"):
        var dir = Engine.get_singleton("Director")
        var player = get_tree().get_first_node_in_group("player")
        if player and player.has_signal("player_died"):
            player.connect("player_died", Callable(dir, "on_player_died"))
