extends CharacterBody3D
class_name PlayerController

enum MovementState { WALKING, RUNNING, CROUCHING, SWIMMING, FLYING, DRIVING, JUMPING, DASHING }

@export_group("Movement Speeds")
@export var walk_speed: float = 5.0
@export var run_speed: float = 12.0
@export var fly_speed: float = 15.0
@export var jump_velocity: float = 8.0
@export var gravity: float = 9.8

@export_group("Retro Mechanics")
@export var can_flip: bool = true
@export var flip_impulse_strength: float = 1.2

var state: MovementState = MovementState.WALKING
var jumps_remaining: int = 2
var last_input_dir: Vector3 = Vector3.ZERO
var last_input_time: float = 0.0

@onready var pivot: Node3D = $Pivot
@onready var ground_ray: RayCast3D = $GroundRay

signal mode_changed(old_mode, new_mode)

func _physics_process(delta: float) -> void:
    var is_on_floor_cached = ground_ray.is_colliding()
    var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = transform.basis * Vector3(input_vec.x, 0, input_vec.y).normalized()
    
    if Input.is_action_just_pressed("jump") and is_on_floor_cached:
        velocity.y = jump_velocity
        state = MovementState.JUMPING
        
    if direction.length() > 0.01:
        if pivot: pivot.look_at(global_position + direction, Vector3.UP)
        velocity.x = direction.x * walk_speed
        velocity.z = direction.z * walk_speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, walk_speed)
        velocity.z = move_toward(velocity.z, 0.0, walk_speed)
        
    if not is_on_floor_cached and state != MovementState.FLYING:
        velocity.y -= gravity * delta

    move_and_slide()
