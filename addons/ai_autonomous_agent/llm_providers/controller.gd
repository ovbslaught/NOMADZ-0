extends CharacterBody3D
class_name PlayerController

enum State { WALK, RUN, CROUCH, SWIM, FLY, DRIVE, JUMP, DASH }

@export_group("Speeds") var walk_speed: float = 5.0
@export var run_speed: float = 12.0
@export var swim_speed: float = 8.0
@export var fly_speed: float = 15.0
@export var gravity: float = 9.8
@export var jump_vel: float = 8.0
@export var dash_vel: float = 25.0
@export var dash_cd: float = 1.0

var state: State = State.WALK
var jumps_left: int = 2
var dash_cd_timer: float = 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var ground_ray: RayCast3D = $GroundRay
@onready var water_ray: RayCast3D = $WaterRay

func _ready():
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent):
    if event is InputEventMouseMotion:
        rotate_y(-event.relative.x * 0.002)
        camera.rotate_x(-event.relative.y * 0.002)
        camera.rotation.x = clamp(camera.rotation.x, -1.5, 1.5)

func _physics_process(delta: float):
    dash_cd_timer -= delta
    detect_state()
    handle_input()
    apply_gravity(delta)
    move_and_slide()
    update_anim()

func detect_state() -> void:
    var on_ground = ground_ray.is_colliding()
    var in_water = water_ray.is_colliding()
    if in_water: state = State.SWIM
    elif Input.is_action_pressed("fly"): state = State.FLY
    elif Input.is_action_pressed("crouch"): state = State.CROUCH
    elif Input.is_action_pressed("sprint") and on_ground: state = State.RUN
    else: state = State.WALK

func handle_input() -> void:
    var input_dir = Input.get_vector("move_left", "move_right", "move_fwd", "move_back")
    var dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    velocity.x = dir.x * get_speed()
    velocity.z = dir.z * get_speed()
    if Input.is_action_just_pressed("jump"): jump()
    if Input.is_action_just_pressed("dash") and dash_cd_timer <= 0: dash(dir)

func get_speed() -> float:
    match state:
        State.WALK: return walk_speed
        State.RUN: return run_speed
        State.SWIM, State.FLY: return fly_speed
    return walk_speed

func jump() -> void:
    if ground_ray.is_colliding() or state == State.FLY:
        velocity.y = jump_vel
        jumps_left = 1
    elif jumps_left > 0:
        velocity.y = jump_vel * 0.75
        jumps_left -= 1

func dash(dir: Vector3) -> void:
    velocity = dir * dash_vel
    dash_cd_timer = dash_cd
    state = State.DASH

func apply_gravity(delta: float) -> void:
    if not ground_ray.is_colliding() and state != State.FLY and state != State.SWIM:
        velocity.y -= gravity * delta

func update_anim() -> void:
    var hspeed = Vector2(velocity.x, velocity.z).length()
    # Hook to AnimationTree: idle/walk/run/swim/fly based on hspeed/state
