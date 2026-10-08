extends CharacterBody3D
class_name PlayerController

enum MovementState { WALKING, RUNNING, CROUCHING, SWIMMING, FLYING, DRIVING, JUMPING, DASHING }

@export_group("Movement Speeds")
@export var walk_speed: float = 5.0
@export var run_speed: float = 12.0
@export var crawl_speed: float = 2.5
@export var swim_speed: float = 8.0
@export var fly_speed: float = 15.0
@export var drive_speed: float = 25.0
@export var jump_velocity: float = 8.0
@export var dash_velocity: float = 25.0
@export var gravity: float = 9.8

@export_group("Double Jump / Dash")
@export var double_jump_velocity: float = 6.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0

@export_group("Retro Mechanics")
@export var can_flip: bool = true
@export var flip_input_window: float = 0.15
@export var flip_impulse_strength: float = 1.2

var state: MovementState = MovementState.WALKING
var jumps_remaining: int = 2
var dashes_remaining: int = 2
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_on_floor_cached: bool = false
var is_in_water: bool = false
var last_input_dir: Vector3 = Vector3.ZERO
var last_input_time: float = 0.0

signal player_damaged(amount)
signal player_died
signal reward_collected(id)
signal mode_changed(old_mode, new_mode)

@onready var pivot: Node3D = $Pivot
@onready var camera_system: Node = $"../CameraSystem"
@onready var ground_ray: RayCast3D = $GroundRay
@onready var water_ray: RayCast3D = $WaterRay
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("togglefly"):
        state = MovementState.FLYING if state != MovementState.FLYING else MovementState.WALKING

func _physics_process(delta: float) -> void:
    dash_timer -= delta
    dash_cooldown_timer -= delta
    detect_environment()
    handle_input(delta)
    update_movement(delta)
    update_animation()
    move_and_slide()

func detect_environment() -> void:
    is_on_floor_cached = ground_ray.is_colliding()
    is_in_water = water_ray.is_colliding()
    var old_state := state
    if is_in_water:
        state = MovementState.SWIMMING
    elif Input.is_action_pressed("togglefly"):
        state = MovementState.FLYING
    elif Input.is_action_pressed("crouch"):
        state = MovementState.CROUCHING
    elif Input.is_action_pressed("sprint") and is_on_floor_cached:
        state = MovementState.RUNNING
    elif state not in [MovementState.FLYING, MovementState.DRIVING, MovementState.JUMPING, MovementState.DASHING]:
        state = MovementState.WALKING
    if state != old_state:
        emit_signal("mode_changed", old_state, state)

func handle_input(delta: float) -> void:
    var input_vec := Input.get_vector("moveleft", "moveright", "moveforward", "movebackward")
    var direction := (transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
    handle_flip_logic(direction)
    if Input.is_action_just_pressed("jump"):
        handle_jump()
    if Input.is_action_just_pressed("dash") and dashes_remaining > 0 and dash_cooldown_timer <= 0.0:
        handle_dash(direction)
    if direction.length() > 0.01:
        if pivot:
            pivot.look_at(global_position + direction, Vector3.UP)
        velocity.x = direction.x * get_current_speed()
        velocity.z = direction.z * get_current_speed()
    else:
        velocity.x = move_toward(velocity.x, 0.0, get_current_speed())
        velocity.z = move_toward(velocity.z, 0.0, get_current_speed())

func get_current_speed() -> float:
    match state:
        MovementState.WALKING: return walk_speed
        MovementState.RUNNING: return run_speed
        MovementState.CROUCHING: return crawl_speed
        MovementState.SWIMMING: return swim_speed
        MovementState.FLYING: return fly_speed
        MovementState.DRIVING: return drive_speed
        _: return walk_speed

func handle_jump() -> void:
    if state == MovementState.FLYING:
        velocity.y = jump_velocity
    elif state == MovementState.SWIMMING:
        velocity.y = jump_velocity * 0.5
    elif is_on_floor_cached:
        velocity.y = jump_velocity
        jumps_remaining = 1
        state = MovementState.JUMPING
    elif jumps_remaining > 0:
        velocity.y = double_jump_velocity
        jumps_remaining -= 1

func handle_dash(direction: Vector3) -> void:
    velocity.x = direction.x * dash_velocity
    velocity.z = direction.z * dash_velocity
    dashes_remaining -= 1
    dash_timer = dash_duration
    dash_cooldown_timer = dash_cooldown
    state = MovementState.DASHING

func handle_flip_logic(direction: Vector3) -> void:
    if not can_flip or direction.length() < 0.1:
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    if last_input_dir.length() > 0.1:
        if last_input_dir.dot(direction) < -0.8 and now - last_input_time < flip_input_window:
            execute_flip(direction)
            return
    last_input_dir = direction
    last_input_time = now

func execute_flip(new_direction: Vector3) -> void:
    if pivot:
        pivot.look_at(global_position + new_direction, Vector3.UP)
    velocity *= -flip_impulse_strength
    if camera_system and camera_system.has_method("apply_trauma"):
        camera_system.apply_trauma(0.4)

func update_movement(delta: float) -> void:
    match state:
        MovementState.WALKING, MovementState.RUNNING, MovementState.CROUCHING:
            if not is_on_floor_cached:
                velocity.y -= gravity * delta
            if collision_shape and collision_shape.shape is CapsuleShape3D:
                (collision_shape.shape as CapsuleShape3D).height = 0.9 if state == MovementState.CROUCHING else 1.8
        MovementState.SWIMMING:
            velocity.y *= 0.95
        MovementState.FLYING:
            velocity.y = Input.get_axis("flydown", "flyup") * fly_speed
        MovementState.DASHING:
            if dash_timer <= 0.0:
                state = MovementState.WALKING
    if is_on_floor_cached and state == MovementState.JUMPING:
        jumps_remaining = 2
        dashes_remaining = 2
        state = MovementState.WALKING

func update_animation() -> void:
    if velocity.length() > 0.1:
        rotation.y = lerp_angle(rotation.y, atan2(velocity.x, velocity.z), 0.1)
