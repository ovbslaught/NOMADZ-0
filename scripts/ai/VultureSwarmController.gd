extends Node3D
class_name VultureSwarmController

@export var vulture_scene: PackedScene = preload("res://scenes/ai/VultureRLAgent.tscn")
@export var swarm_size: int = 4
@export var spawn_radius: float = 6.0

func _ready() -> void:
	spawn_swarm(swarm_size)

func spawn_swarm(count: int) -> void:
	for i in range(count):
		var vulture = vulture_scene.instantiate() as VultureRLAgent
		vulture.agent_index = i
		var angle = (TAU / count) * i
		var spawn_pos = global_position + Vector3(cos(angle) * spawn_radius, 2.0, sin(angle) * spawn_radius)
		vulture.global_position = spawn_pos
		add_child(vulture)
