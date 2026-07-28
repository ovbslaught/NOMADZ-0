extends CharacterBody3D
class_name PlayerController

enum MovementState { WALKING, RUNNING, CROUCHING, SWIMMING, FLYING, DRIVING, JUMPING, DASHING }

@export_group("Movement Speeds")
@export var walk_speed: float = 6.0
@export var run_speed: float = 12.0
@export var jump_velocity: float = 8.0
@export var dash_velocity: float = 25.0
@export var gravity: float = 12.0

@export_group("Retro Mechanics")
@export var can_flip: bool = true
@export var flip_input_window: float = 0.15
@export var flip_impulse_strength: float = 1.2

var state: MovementState = MovementState.WALKING
var jumps_remaining: int = 2
var dashes_remaining: int = 2
var dash_timer: float = 0.0

var last_input_dir: Vector3 = Vector3.ZERO
var last_input_time: float = 0.0

@onready var pivot: Node3D = $Pivot
@onready var camera_rig: Node3D = get_node_or_null("../CameraSystem")
@onready var ground_ray: RayCast3D = $GroundRay
@onready var combat_manager: Node = get_node_or_null("../CombatManager")

func _physics_process(delta: float) -> void:
    if dash_timer > 0:
        dash_timer -= delta
        
    var is_on_floor_cached = ground_ray.is_colliding() if ground_ray else is_on_floor()

    if not is_on_floor_cached and state != MovementState.FLYING and dash_timer <= 0:
        velocity.y -= gravity * delta

    if is_on_floor_cached:
        jumps_remaining = 2
        dashes_remaining = 2
        if state in [MovementState.JUMPING, MovementState.FLYING, MovementState.DASHING]:
            state = MovementState.WALKING

    handle_gamepad_input(delta)
    move_and_slide()

func handle_gamepad_input(delta: float) -> void:
    # 1. PURE ANALOG MOVEMENT (Left Stick)
    # Using InputMap actions (Requires setup in Godot: Project -> Project Settings -> Input Map)
    var stick_input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var direction = (transform.basis * Vector3(stick_input.x, 0, stick_input.y)).normalized()
    
    # Align stick movement to where the right stick (Camera) is looking
    if camera_rig:
        var cam = camera_rig.get_node_or_null("HelmetCamera")
        if not cam or not cam.current:
            cam = camera_rig.get_node_or_null("ShoulderCamera")
        
        if cam:
            var cam_basis = cam.global_transform.basis
            direction = (cam_basis * Vector3(stick_input.x, 0, stick_input.y)).normalized()
            direction.y = 0
            direction = direction.normalized()

    # 2. CHECK URIDIUM FLIP (Left Stick Flick)
    handle_flip_logic(direction)

    # 3. JUMP (South Button: Switch 'B' / PS4 'X')
    if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
        velocity.y = jump_velocity
        jumps_remaining -= 1
        state = MovementState.JUMPING

    # 4. DASH (Right Shoulder/Trigger: R1/R)
    if Input.is_action_just_pressed("dash") and dashes_remaining > 0 and dash_timer <= 0:
        # If no stick input, dash forward relative to where we're looking
        if direction.length() < 0.01 and pivot:
            direction = -pivot.global_transform.basis.z
            
        velocity.x = direction.x * dash_velocity
        velocity.z = direction.z * dash_velocity
        dashes_remaining -= 1
        dash_timer = 0.2
        state = MovementState.DASHING

    # 5. APPLY ANALOG MOVEMENT
    if dash_timer <= 0:
        var current_speed = run_speed if state == MovementState.RUNNING else walk_speed
        
        # Deadzone handling built into get_vector()
        if direction.length() > 0.1: 
            if pivot:
                var target_look = global_position + direction
                if global_position.distance_to(target_look) > 0.1:
                    pivot.look_at(target_look, Vector3.UP)
            velocity.x = direction.x * current_speed
            velocity.z = direction.z * current_speed
        else:
            # Smooth deceleration when stick is released
            velocity.x = move_toward(velocity.x, 0.0, current_speed)
            velocity.z = move_toward(velocity.z, 0.0, current_speed)

func handle_flip_logic(direction: Vector3) -> void:
    if not can_flip or direction.length() < 0.1: 
        return
    
    var now = Time.get_ticks_msec() / 1000.0
    
    if last_input_dir.length() > 0.1:
        # If stick is violently snapped opposite (dot product < -0.8)
        if last_input_dir.dot(direction) < -0.8 and (now - last_input_time) < flip_input_window:
            execute_flip(direction)
            last_input_time = now # Debounce
            return
            
    last_input_dir = direction
    last_input_time = now

func execute_flip(new_direction: Vector3) -> void:
    if pivot: 
        pivot.look_at(global_position + new_direction, Vector3.UP)
        
    velocity = -velocity * flip_impulse_strength
    velocity.y = jump_velocity * 0.8 
    
    if Engine.has_singleton("Director"):
        Engine.get_singleton("Director").raise_tension(0.2)
    if camera_rig and camera_rig.has_method("apply_trauma"):
        camera_rig.apply_trauma(0.4)
