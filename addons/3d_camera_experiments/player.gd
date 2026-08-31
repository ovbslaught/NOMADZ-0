class_name Player extends CharacterBody3D

@export var speed: float = 5.0
@export var gravity: float = -9.8
@export var jump_impulse: float = 4.5
@export var rotation_velocity: float = 10.0

@onready var _orbital_camera: Node3D = $OrbitalCamera
@onready var _model: Node3D = $Model

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed(&"Jump") and is_on_floor():
		velocity.y = jump_impulse

	var directional_input: Vector2 = Input.get_vector(&"Left", &"Right", &"Up", &"Down")
	if directional_input:
		var movement_direction: Vector3 = _orbital_camera.global_transform.basis.z * directional_input.y + _orbital_camera.global_transform.basis.x * directional_input.x
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(movement_direction.x, movement_direction.z), rotation_velocity * delta)
		
		velocity.x = movement_direction.x * speed
		velocity.z = movement_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()
