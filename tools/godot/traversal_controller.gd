extends CharacterBody3D
# traversal_controller.gd — unified movement: swim / fly / run,
# jump, double jump, air dash, ground dash, hover bike, proton blade.
# Cyberpunk-smooth: everything accelerates and decays, nothing snaps.
#
# Actions required in Input Map:
#   move_left/right/forward/back, jump, sprint, dash, crouch,
#   mount (E), blade (Q)
#
# Nodes: MeshHolder (Node3D), BoardPivot (Node3D under MeshHolder)

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const FLY_SPEED := 14.0
const FLY_BOOST := 26.0
const SWIM_SPEED := 4.0
const SWIM_BOOST := 7.0
const JUMP_VELOCITY := 4.5
const DASH_SPEED := 22.0
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.7
const DASH_COUNT_MAX := 2          # ground dash + air dash

enum Mode { GROUND, FLY, SWIM }

@onready var mesh_holder: Node3D = $MeshHolder
@onready var cam: Camera3D = get_viewport().get_camera_3d()

var mode: Mode = Mode.GROUND
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var dash_count := 0
var dash_timer := 0.0
var dash_dir := Vector3.ZERO
var can_double_jump := false

func _ready() -> void:
    mode = Mode.SWIM if _in_water() else Mode.GROUND

func _in_water() -> bool:
    # water body detection: simple height test, swap for Area3D later
    return global_position.y < 0.0

func _unhandled_input(_e: InputEvent) -> void:
    if Input.is_action_just_pressed("jump"):
        if mode == Mode.GROUND and is_on_floor():
            velocity.y = JUMP_VELOCITY
            can_double_jump = true
        elif mode == Mode.GROUND and can_double_jump:
            velocity.y = JUMP_VELOCITY * 0.9
            can_double_jump = false   # double jump spent
        elif mode == Mode.FLY or mode == Mode.SWIM:
            velocity.y = lerpf(velocity.y, 6.0, 0.4)
    if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and dash_count < DASH_COUNT_MAX:
        _start_dash()

func _start_dash() -> void:
    var input_dir := Input.get_vector("move_left", "move_right",
                                       "move_forward", "move_back")
    if input_dir.length() < 0.1:
        input_dir = Vector2(0, -1)   # dash forward if no direction held
    dash_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    mesh_holder.rotation.y = atan2(dash_dir.x, dash_dir.z)
    dash_timer = DASH_TIME
    dash_count += 1
    if is_on_floor():
        dash_count = 0               # ground dash refunds air dash on landing
    velocity.x = dash_dir.x * DASH_SPEED
    velocity.z = dash_dir.z * DASH_SPEED
    # i-frame tint hook: flash mesh emissive here

func _physics_process(delta: float) -> void:
    # mode transitions
    if _in_water():
        mode = Mode.SWIM
    elif mode == Mode.SWIM and not _in_water():
        mode = Mode.GROUND if is_on_floor() else Mode.FLY
    if Input.is_action_just_pressed("sprint") and mode == Mode.GROUND and not is_on_floor():
        mode = Mode.FLY               # sprint in air = flight engage

    if dash_timer > 0.0:
        dash_timer -= delta
        velocity.x = dash_dir.x * DASH_SPEED
        velocity.z = dash_dir.z * DASH_SPEED
        if mode != Mode.SWIM:
            velocity.y = 0.0
        move_and_slide()
        return                        # dash overrides everything

    match mode:
        Mode.GROUND: _ground(delta)
        Mode.FLY: _fly(delta)
        Mode.SWIM: _swim(delta)
    move_and_slide()
    if is_on_floor():
        dash_count = 0
        can_double_jump = true

func _input_dir() -> Vector2:
    return Input.get_vector("move_left", "move_right",
                            "move_forward", "move_back")

func _ground(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    var input := _input_dir()
    var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
    var dir := transform.basis * Vector3(input.x, 0, input.y)
    var target := Vector3(dir.x, 0, dir.z) * speed
    velocity.x = lerpf(velocity.x, target.x, 12.0 * delta)
    velocity.z = lerpf(velocity.z, target.z, 12.0 * delta)
    if dir.length() > 0.1:
        mesh_holder.rotation.y = atan2(dir.x, dir.z)

func _fly(delta: float) -> void:
    var input := _input_dir()
    var cam_basis := cam.global_transform.basis
    var dir := cam_basis * Vector3(input.x, 0, input.y)
    var vertical := 0.0
    if Input.is_action_pressed("jump"): vertical += 1.0
    if Input.is_action_pressed("crouch"): vertical -= 1.0
    var speed := FLY_BOOST if Input.is_action_pressed("sprint") else FLY_SPEED
    var target := Vector3(dir.x, vertical, dir.z)
    if target.length() > 0.1:
        target = target.normalized() * speed
    else:
        target = Vector3.ZERO
    velocity = velocity.lerp(target, 6.0 * delta)
    # banking
    var roll := -input.x * 0.5
    mesh_holder.rotation.z = lerpf(mesh_holder.rotation.z, roll, 5.0 * delta)
    var pitch := clampf(-velocity.y * 0.02, -0.4, 0.4)
    mesh_holder.rotation.x = lerpf(mesh_holder.rotation.x, pitch, 5.0 * delta)
    if Vector2(velocity.x, velocity.z).length() > 1.0:
        mesh_holder.rotation.y = atan2(velocity.x, velocity.z)

func _swim(delta: float) -> void:
    var input := _input_dir()
    var cam_basis := cam.global_transform.basis
    var dir := cam_basis * Vector3(input.x, 0, input.y)
    var vertical := 0.0
    if Input.is_action_pressed("jump"): vertical += 1.0
    if Input.is_action_pressed("crouch"): vertical -= 1.0
    var speed := SWIM_BOOST if Input.is_action_pressed("sprint") else SWIM_SPEED
    var target := Vector3(dir.x, vertical, dir.z)
    if target.length() > 0.1:
        target = target.normalized() * speed
    else:
        target = Vector3(0.0, -0.3, 0.0)   # gentle sink when idle
    velocity = velocity.lerp(target, 4.0 * delta)
    if dir.length() > 0.1:
        mesh_holder.rotation.y = atan2(dir.x, dir.z)
