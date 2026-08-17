# NOMADZ-0 :: PlayerController.gd
# VCN-3.1 | Sol [GEO-LOGOS-AGI] | Palette: #00FFFF #FF00FF #FFFF00 #000080
extends CharacterBody3D
class_name PlayerController

@export var move_speed: float = 6.0
@export var run_speed: float = 10.0
@export var jump_velocity: float = 4.5
@export var air_dash_force: float = 8.0
@export var mouse_sensitivity: float = 0.002

@onready var camera: Camera3D = $Camera3D
@onready var fsm: PlayerFSM = $PlayerFSM
@onready var anim: AnimationPlayer = $AnimationPlayer

const GRAVITY: float = 9.8
var air_dashes_remaining: int = 1

enum State { WALKING, RUNNING, CROUCHING, SWIMMING, FLYING, DRIVING, JUMPING, DASHING }
var current_state: State = State.WALKING

func _ready() -> void:
	assert(camera != null, "Camera3D missing at Camera3D")
	assert(fsm != null, "PlayerFSM missing at PlayerFSM")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		air_dashes_remaining = 1

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else move_speed

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			current_state = State.JUMPING
		elif air_dashes_remaining > 0:
			velocity += -global_transform.basis.z * air_dash_force
			air_dashes_remaining -= 1
			current_state = State.DASHING

	move_and_slide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

func is_hero() -> bool:
	return true
