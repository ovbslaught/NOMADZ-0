extends Node3D

@onready var camera_3d: Camera3D = %Camera3D


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		
		rotate_y(event.relative.x * -0.001)
		camera_3d.rotate_x(event.relative.y * -0.001)

func _process(delta: float) -> void:
	var v : = Input.get_vector("w", 's', 'a', 'd') * delta * 2
	
	translate(Vector3(v.y, 0, v.x).rotated(Vector3.RIGHT, camera_3d.global_rotation.x))
