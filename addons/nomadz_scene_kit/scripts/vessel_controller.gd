extends RigidBody3D
## NOMADZ Scene Kit — Vessel Controller
## Spaceship (6DOF) <-> Submarine (buoyancy+thrust)
## Input Map: thrust_fwd/back, strafe_left/right, rise, sink,
##             yaw_left/right, pitch_up/down, roll_left/right
## F1 = toggle environment at runtime
## VULTURE:INC | Godot 4.5/4.6

@export var thrust_force: float    = 28.0
@export var strafe_force: float    = 14.0
@export var vertical_force: float  = 14.0
@export var torque_force: float    = 3.0
@export var damping_linear: float  = 1.8
@export var damping_angular: float = 3.5
@export var buoyancy_force: float  = 9.81

enum Mode { SPACESHIP, SUBMARINE }
var mode: Mode = Mode.SPACESHIP

func _ready() -> void:
	linear_damp  = damping_linear
	angular_damp = damping_angular
	gravity_scale = 0.0

func set_mode(m: String) -> void:
	mode = Mode.SUBMARINE if m == "submarine" else Mode.SPACESHIP
	gravity_scale = 0.0

func _physics_process(delta: float) -> void:
	_handle_input(delta)
	if mode == Mode.SUBMARINE:
		_apply_buoyancy(delta)

func _is_action(action_name: String) -> bool:
	return InputMap.has_action(action_name) and Input.is_action_pressed(action_name)

func _handle_input(_delta: float) -> void:
	if _is_action("thrust_fwd"):
		apply_central_force(-transform.basis.z * thrust_force)
	if _is_action("thrust_back"):
		apply_central_force(transform.basis.z * thrust_force)
	if _is_action("strafe_left"):
		apply_central_force(-transform.basis.x * strafe_force)
	if _is_action("strafe_right"):
		apply_central_force(transform.basis.x * strafe_force)
	if _is_action("rise"):
		apply_central_force(transform.basis.y * vertical_force)
	if _is_action("sink"):
		apply_central_force(-transform.basis.y * vertical_force)
	if _is_action("yaw_left"):
		apply_torque(Vector3.UP * torque_force)
	if _is_action("yaw_right"):
		apply_torque(-Vector3.UP * torque_force)
	if _is_action("pitch_up"):
		apply_torque(transform.basis.x * torque_force)
	if _is_action("pitch_down"):
		apply_torque(-transform.basis.x * torque_force)
	if _is_action("roll_left"):
		apply_torque(transform.basis.z * torque_force * 0.5)
	if _is_action("roll_right"):
		apply_torque(-transform.basis.z * torque_force * 0.5)

func _apply_buoyancy(_delta: float) -> void:
	var world_gravity := PhysicsServer3D.area_get_param(
		get_world_3d().space, PhysicsServer3D.AREA_PARAM_GRAVITY
	) as float
	if world_gravity == 0.0: world_gravity = 9.81
	apply_central_force(Vector3.UP * world_gravity * mass)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			var mgr := get_parent().get_node_or_null("EnvironmentManager")
			if mgr:
				var next := "ocean" if mgr.current_env == mgr.Env.SPACE else "space"
				mgr.switch_environment(next)
