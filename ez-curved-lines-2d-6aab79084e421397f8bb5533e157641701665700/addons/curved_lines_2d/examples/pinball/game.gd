extends Node2D

var PinballScene : PackedScene = preload("res://addons/curved_lines_2d/examples/pinball/pinball.tscn")
@onready var pinball_spawn_point : Vector2 = $Pinball.position

func _process(_delta: float) -> void:
	$LeftFlipper.flipping_up = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	$RightFlipper.flipping_up = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)


func _on_catch_ball_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("pinballs"):
		body.remove_from_group("pinballs")
		await get_tree().create_timer(1).timeout
		body.queue_free()
		var new_ball : Node2D = PinballScene.instantiate()
		new_ball.position = pinball_spawn_point
		add_child.call_deferred(new_ball)
