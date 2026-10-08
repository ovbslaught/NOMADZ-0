class_name TopDownCamera
extends Camera2D

@export var target: Node2D
@export var follow_speed := 8.0
@export var top_left_limit: Vector2
@export var bottom_right_limit: Vector2

func _ready() -> void:
	if not target:
		target = get_tree().get_first_node_in_group("player")
	if top_left_limit != Vector2.ZERO:
		limit_left = int(top_left_limit.x)
		limit_top = int(top_left_limit.y)
	if bottom_right_limit != Vector2.ZERO:
		limit_right = int(bottom_right_limit.x)
		limit_bottom = int(bottom_right_limit.y)

func _physics_process(delta: float) -> void:
	if not target: return
	global_position = global_position.lerp(target.global_position, follow_speed * delta)
