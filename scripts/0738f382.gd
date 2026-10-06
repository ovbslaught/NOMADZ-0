extends Node3D
class_name MainScene

@export var player_scene: PackedScene
@export var world_scene: PackedScene

@onready var spawn_point: Node3D = $WorldRoot/PlayerSpawn
@onready var lighting_mgr: Node = $LightingManager
@onready var audio_mgr: Node = $AudioManager

func _ready() -> void:
    spawn_player()
    hook_autoloads()
    if lighting_mgr and lighting_mgr.has_method("apply_preset"):
        lighting_mgr.apply_preset("arcology_neon")
    if audio_mgr and audio_mgr.has_method("play_ambient"):
        audio_mgr.play_ambient("corridor_hum")

func spawn_player() -> void:
    if player_scene:
        var p = player_scene.instantiate()
        add_child(p)
        if is_instance_valid(spawn_point):
            p.global_position = spawn_point.global_position

func hook_autoloads() -> void:
    var dir = get_node_or_null("/root/Director")
    if dir:
        var player = get_tree().get_first_node_in_group("player")
        if player:
            if player.has_signal("player_died"):
                player.connect("player_died", Callable(dir, "on_player_died"))
            if player.has_signal("reward_collected"):
                player.connect("reward_collected", Callable(dir, "on_reward_collected"))

func reload_scene() -> void:
    get_tree().reload_current_scene()
