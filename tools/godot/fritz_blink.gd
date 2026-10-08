extends CharacterBody3D
# fritz_blink.gd — Fritz, the living glitch. Teleport portal ability.
# Actions: blink (E), move/jump/sprint as usual, flight_toggle unused for Fritz.
# Camera-based aim: blinks to where the camera looks, up to MAX_BLINK meters,
# stopping short on wall collision (safe teleport).

const SPEED := 5.0
const RUN_SPEED := 8.5
const JUMP_VELOCITY := 4.5
const BLINK_COOLDOWN := 1.2
const MAX_BLINK := 18.0

@onready var mesh_holder: Node3D = $MeshHolder
@onready var glitch_mat: ShaderMaterial = $MeshHolder/Body.get_active_material(0)

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var blink_ready := true

func _ready() -> void:
    set_glitch(0.15)

func set_glitch(amount: float) -> void:
    if glitch_mat:
        glitch_mat.set_shader_parameter("glitch_amount", amount)

func _unhandled_input(_e: InputEvent) -> void:
    if Input.is_action_just_pressed("blink") and blink_ready:
        _do_blink()

func _do_blink() -> void:
    blink_ready = false
    var cam := get_viewport().get_camera_3d()
    var from := global_position + Vector3.UP * 1.0
    var to := from + (-cam.global_transform.basis.z * MAX_BLINK)

    # safe teleport: raycast, stop short of walls
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        to = hit.position - (-cam.global_transform.basis.z * 0.8)

    _spawn_portal(global_position)          # entry ring
    _flash_glitch()
    global_position = to
    velocity = Vector3.ZERO
    _spawn_portal(global_position)          # exit ring

    get_tree().create_timer(BLINK_COOLDOWN).timeout.connect(func(): blink_ready = true)

func _flash_glitch() -> void:
    set_glitch(1.0)
    var tween := create_tween()
    tween.tween_method(set_glitch, 1.0, 0.15, 0.25)

func _spawn_portal(at: Vector3) -> void:
    # portal ring: decal or thin cylinder mesh, scale-up + fade-out
    var ring := preload("res://characters/attachments/portal_ring.tscn").instantiate()
    get_tree().current_scene.add_child(ring)
    ring.global_position = at + Vector3.UP * 1.0
    var tween := ring.create_tween()
    tween.tween_property(ring, "scale", Vector3(2.5, 2.5, 2.5), 0.4)
    tween.parallel().tween_property(ring, "transparency", 1.0, 0.4)
    tween.tween_callback(ring.queue_free)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta
    if Input.is_action_just_pressed("jump") and is_on_floor():
        velocity.y = JUMP_VELOCITY
    var input_dir := Input.get_vector("move_left", "move_right",
                                       "move_forward", "move_back")
    var speed := RUN_SPEED if Input.is_action_pressed("sprint") else SPEED
    var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
    if dir:
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        mesh_holder.rotation.y = atan2(dir.x, dir.z)
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)
    move_and_slide()
