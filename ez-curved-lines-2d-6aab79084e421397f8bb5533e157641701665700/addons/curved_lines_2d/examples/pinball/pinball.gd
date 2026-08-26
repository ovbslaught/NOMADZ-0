extends RigidBody2D


func _process(_delta: float) -> void:
	$Gradient.rotation = -rotation
