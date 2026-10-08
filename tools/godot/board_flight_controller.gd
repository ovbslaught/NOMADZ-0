extends CharacterBody3D
# board_flight_controller.gd — Iron Man / Surfer-style board flight mode.
# Add actions to Input Map: flight_toggle, boost, board_toggle.
# Board scene: a Node3D with the silver_board.glb mesh, preloaded below.

const WALK_SPEED := 5.0
const RUN_SPEED := 8.5
const JUMP_VELOCITY := 4.5
const FLY_SPEED := 14.0
const BOOST_SPEED := 26.0

@onready var mesh_holder: Node3D = $MeshHolder
@onready var board_pivot: Node3D = $MeshHolder/BoardPivot
@onready var board: Node3D = preload("res://characters/attachments/silver_board.tscn").instantiate()

var flying := false
var board_equipped := false
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
    board.visible = false
    board_pivot.add_child(board)

func _unhandled_input(_e: InputEvent) -> void:
    if Input.is_action_just_pressed("flight_toggle"):
        flying = !flying
        _set_board(true)
        velocity.y = 0.0
        print("[FLIGHT] ", "ON" if flying else "OFF")
    if Input.is_action_just_pressed("board_toggle") and not flying:
        _set_board(not board_equipped)

func _set_board(on: bool) -> void:
    board_equipped = on
    board.visible = on
    # character spread-leg surf stance is best done as a per-body anim override;
    # fallback: hide nothing, board just offsets under the feet
    board_pivot.position = Vector3(0, -0.05, 0)

func _physics_process(delta: float) -> void:
    if flying:
        _fly(delta)
    else:
        _walk(delta)
    move_and_slide()

func _fly(delta: float) -> void:
    var input_dir := Input.get_vector("move_left", "move_right",
                                       "move_forward", "move_back")
    var cam_basis: Basis = get_viewport().get_camera_3d().global_transform.basis
    var dir := (cam_basis * Vector3(input_dir.x, 0, input_dir.y))
    var vertical := 0.0
    if Input.is_action_pressed("jump"): vertical += 1.0
    if Input.is_action_pressed("crouch"): vertical -= 1.0

    var speed := BOOST_SPEED if Input.is_action_pressed("boost") else FLY_SPEED
    var target := Vector3(dir.x, vertical, dir.z).normalized() * speed if dir.length() > 0.1 or vertical != 0 else Vector3.ZERO

    # smooth accel/decel — the difference between floating and flying
    velocity = velocity.lerp(target, 6.0 * delta)

    # banking: roll the holder into turns, pitch with vertical motion
    var roll := -input_dir.x * 0.5
    var pitch := clampf(-velocity.y * 0.02, -0.4, 0.4)
    mesh_holder.rotation.z = lerpf(mesh_holder.rotation.z, roll, 5.0 * delta)
    mesh_holder.rotation.x = lerpf(mesh_holder.rotation.x, pitch, 5.0 * delta)

    # face travel direction on the horizontal plane
    if Vector2(velocity.x, velocity.z).length() > 1.0:
        mesh_holder.rotation.y = atan2(velocity.x, velocity.z)

func _walk(delta: float) -> void:
    mesh_holder.rotation.x = lerpf(mesh_holder.rotation.x, 0.0, 5.0 * delta)
    mesh_holder.rotation.z = lerpf(mesh_holder.rotation.z, 0.0, 5.0 * delta)
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    var input_dir := Input.get_vector("move_left", "move_right",
                                       "move_forward", "move_back")
    var speed := RUN_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
    var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
    if dir:
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        mesh_holder.rotation.y = atan2(dir.x, dir.z)
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)
