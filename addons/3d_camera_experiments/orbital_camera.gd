class_name OrbitalCamera extends Node3D

@export var speed: float = 20.0
@export var mouse_sensitivity: float = 0.15
@export var right_stick_sensitivity: float = 2.5
@export var zoom_sensitivity: float = 4.0
@export var zoom_step: float = 32.0
@export var zoom_min: float = 1.5
@export var zoom_max: float = 12.0

@onready var _spring_arm: SpringArm3D = $SpringArm
@onready var _desired_arm_lenght: float = _spring_arm.spring_length

const HALF_PI: float = PI / 2.0

var _delta: float

func _ready() -> void:
	_spring_arm.add_excluded_object(get_parent())

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed(&"MouseRotateView"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if Input.is_action_just_released(&"MouseRotateView"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseMotion and Input.is_action_pressed(&"MouseRotateView"):
		rotate_y(-event.screen_relative.x * mouse_sensitivity * _delta)
		_spring_arm.rotation.x = clampf(_spring_arm.rotation.x - event.screen_relative.y * mouse_sensitivity * _delta, -HALF_PI, HALF_PI)
	

func _process(delta: float) -> void:
	_delta = delta
	
	var right_stick := Input.get_vector(&"RightStickLeft", &"RightStickRight", &"RightStickUp", &"RightStickDown")
	if right_stick:
		rotate_y(-right_stick.x * right_stick_sensitivity * delta)
		_spring_arm.rotation.x = clampf(_spring_arm.rotation.x - right_stick.y * right_stick_sensitivity * delta, -HALF_PI, HALF_PI)

	if Input.is_action_just_pressed(&"ZoomIn"):
		_desired_arm_lenght = clampf(_desired_arm_lenght - zoom_step * delta, zoom_min, zoom_max)
	if Input.is_action_just_pressed(&"ZoomOut"):
		_desired_arm_lenght = clampf(_desired_arm_lenght + zoom_step * delta, zoom_min, zoom_max)
	
	if _spring_arm.spring_length != _desired_arm_lenght:
		_spring_arm.spring_length = lerp(_spring_arm.spring_length, _desired_arm_lenght, zoom_sensitivity * delta)
