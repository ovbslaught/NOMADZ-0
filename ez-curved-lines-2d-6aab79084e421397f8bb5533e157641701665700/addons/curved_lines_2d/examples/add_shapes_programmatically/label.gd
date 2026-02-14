extends Label

func _process(delta: float) -> void:
	if modulate.a > 0.0:
		modulate.a -= delta * 0.25
	else:
		queue_free()
