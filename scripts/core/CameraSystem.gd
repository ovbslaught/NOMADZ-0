class_name CameraSystem
extends Node3D

enum CameraMode { HELMET, SHOULDER, WIDE }
@export var current_mode: CameraMode = CameraMode.SHOULDER
@export var target_player: NodePath

@onready var camera = $Camera3D
var player: CharacterBody3D

const MODE_OFFSETS = {
	CameraMode.HELMET: Vector3(0, 1.6, 0),
	CameraMode.SHOULDER: Vector3(1.2, 1.5, 3.0),
	CameraMode.WIDE: Vector3(0, 4.0, 8.0)
}

func _ready() -> void:
	if not target_player.is_empty():
		player = get_node_or_null(target_player) as CharacterBody3D

func _process(delta: float) -> void:
	if not player:
		return
	
	var target_pos = player.global_position + MODE_OFFSETS[current_mode]
	global_position = global_position.lerp(target_pos, 10.0 * delta)
	
	if current_mode != CameraMode.HELMET:
		look_at(player.global_position + Vector3.UP * 1.0, Vector3.UP)

func switch_mode(new_mode: CameraMode) -> void:
	current_mode = new_mode
	print("[CameraSystem] Switched to mode: ", CameraMode.keys()[current_mode])
