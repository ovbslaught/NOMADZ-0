extends CharacterBody3D
class_name PlayerController

enum State { WALK, RUN, SWIM, FLY }

@export var walk_speed: float = 5.0
@export var run_speed: float = 12.0
@export var swim_speed: float = 8.0
@export var fly_speed: float = 15.0
@export var gravity: float = 9.8
@export var jump_vel: float = 8.0

var state = State.WALK
@onready var ground_ray = $GroundRay
@onready var water_ray = $WaterRay

func _ready():
\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
\tif event is InputEventMouseMotion:
\t\trotate_y(-event.relative.x * 0.002)
\t\t$CameraPivot/Camera3D.rotate_x(-event.relative.y * 0.002)
\t\t$CameraPivot/Camera3D.rotation.x = clamp($CameraPivot/Camera3D.rotation.x, -1.5, 1.5)

func _physics_process(delta):
\t# State detection
\tif water_ray.is_colliding():
\t\tstate = State.SWIM
\telif Input.is_action_pressed("fly"):
\t\tstate = State.FLY
\telif Input.is_action_pressed("run") and ground_ray.is_colliding():
\t\tstate = State.RUN
\telse:
\t\tstate = State.WALK
\t
\t# Input
\tvar input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
\tvar direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
\t
\tif direction:
\t\tvelocity.x = direction.x * get_speed()
\t\tvelocity.z = direction.z * get_speed()
\telse:
\t\tvelocity.x = move_toward(velocity.x, 0, get_speed())
\t\tvelocity.z = move_toward(velocity.z, 0, get_speed())
\t
\t# Jump
\tif Input.is_action_just_pressed("jump") and ground_ray.is_colliding():
\t\tvelocity.y = jump_vel
\t
\t# Gravity
\tif not ground_ray.is_colliding() and state != State.FLY and state != State.SWIM:
\t\tvelocity.y -= gravity * delta
\telse:
\t\tvelocity.y = move_toward(velocity.y, 0, gravity * delta)
\t
\tmove_and_slide()

func get_speed() -> float:
\tmatch state:
\t\tState.WALK: return walk_speed
\t\tState.RUN: return run_speed
\t\tState.SWIM, State.FLY: return fly_speed
\treturn walk_speed