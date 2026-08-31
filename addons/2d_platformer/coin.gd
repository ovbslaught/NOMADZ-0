extends Area2D

func _on_body_entered(body):
	if body.name == "Player":
		body.coin += randi_range(1, 4)
		$"/root/CoinSfx".play()
		queue_free()
