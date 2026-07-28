extends Node3D
class_name CameraSystem

enum CameraMode { HELMET, SHOULDER, WIDE }
@export var mouse_sensitivity: float = 0.002
var current_mode: CameraMode = CameraMode.SHOULDER
var trauma: float = 0.0

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)

func apply_trauma(amount: float) -> void:
    trauma = clamp(trauma + amount, 0.0, 1.0)
