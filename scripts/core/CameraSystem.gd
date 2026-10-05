extends Node3D
class_name CameraSystem

enum CameraMode { HELMET, SHOULDER, WIDE }

@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -75.0
@export var max_pitch: float = 45.0
@export var min_zoom: float = 1.5
@export var max_zoom: float = 8.0
@export var zoom_step: float = 0.5

var current_mode: CameraMode = CameraMode.SHOULDER
var trauma: float = 0.0
var pitch: float = -15.0

@onready var spring_arm: SpringArm3D = get_node_or_null("SpringArm3D")
@onready var camera: Camera3D = get_node_or_null("SpringArm3D/Camera3D")

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    if not spring_arm:
        spring_arm = SpringArm3D.new()
        spring_arm.name = "SpringArm3D"
        spring_arm.spring_length = 3.5
        spring_arm.margin = 0.2
        spring_arm.position = Vector3(0, 1.4, 0)
        add_child(spring_arm)
        
    if not camera and spring_arm:
        var existing_cam = spring_arm.get_node_or_null("Camera3D")
        if existing_cam:
            camera = existing_cam
        else:
            camera = Camera3D.new()
            camera.name = "Camera3D"
            camera.current = true
            spring_arm.add_child(camera)
            
    _update_pitch()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
        else:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            
    if event is InputEventMouseButton and event.pressed:
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        elif event.button_index == MOUSE_BUTTON_WHEEL_UP and spring_arm:
            spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_step, min_zoom, max_zoom)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and spring_arm:
            spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_step, min_zoom, max_zoom)

    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        pitch = clamp(pitch - event.relative.y * mouse_sensitivity * 50.0, min_pitch, max_pitch)
        _update_pitch()

func _process(delta: float) -> void:
    if trauma > 0.0:
        trauma = max(0.0, trauma - delta * 1.5)
        if camera:
            var shake = trauma * trauma * 0.08
            camera.h_offset = randf_range(-shake, shake)
            camera.v_offset = randf_range(-shake, shake)
    elif camera and (camera.h_offset != 0.0 or camera.v_offset != 0.0):
        camera.h_offset = 0.0
        camera.v_offset = 0.0

func _update_pitch() -> void:
    if spring_arm:
        spring_arm.rotation_degrees.x = pitch

func apply_trauma(amount: float) -> void:
    trauma = clamp(trauma + amount, 0.0, 1.0)

func get_camera_basis() -> Basis:
    if camera:
        return camera.global_transform.basis
    return global_transform.basis
