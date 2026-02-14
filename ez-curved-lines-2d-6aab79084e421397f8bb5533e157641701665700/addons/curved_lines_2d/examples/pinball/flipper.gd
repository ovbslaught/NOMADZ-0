extends Node2D

@export var flipping_up := false
@export var min_rotation := 0.0
@export var max_rotation := 45.0
@export var base_acceleration := 3.0

var acceleration = 0.0

func _physics_process(delta: float) -> void:
	if flipping_up:
		if $AnimatableBody2D.rotation > deg_to_rad(min_rotation) + 0.01:
			if acceleration == 0:
				acceleration = 2 * base_acceleration
			$AnimatableBody2D.rotation -= acceleration * delta
			acceleration += base_acceleration
		else:
			$AnimatableBody2D.rotation = deg_to_rad(min_rotation)
			acceleration = 0.0
	else:
		if $AnimatableBody2D.rotation < deg_to_rad(max_rotation) - 0.01:
			$AnimatableBody2D.rotation += acceleration * delta
			acceleration = base_acceleration * 4
		else:
			$AnimatableBody2D.rotation = deg_to_rad(max_rotation)
			acceleration = 0.0
