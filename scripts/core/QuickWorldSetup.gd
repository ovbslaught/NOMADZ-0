extends Node3D
class_name QuickWorldSetup

@export var ground_size: Vector2 = Vector2(40, 40)
@export var ground_height: float = 1.0
@export var ground_color: Color = Color(0.15, 0.15, 0.18)

@export var sky_top_color: Color = Color(0.02, 0.02, 0.05)
@export var sky_horizon_color: Color = Color(0.05, 0.08, 0.12)

@export var sun_energy: float = 2.0
@export var sun_angle: Vector3 = Vector3(-45, 45, 0) # degrees

@export var spawn_player: bool = false
@export var player_scene: PackedScene

func _ready() -> void:
    _create_environment()
    _create_sun_light()
    _create_ground()

    if spawn_player and player_scene:
        _spawn_player()

func _create_environment() -> void:
    if get_node_or_null("WorldEnvironment"):
        return

    var env_node := WorldEnvironment.new()
    env_node.name = "WorldEnvironment"
    add_child(env_node)

    var env := Environment.new()
    env.background_mode = Environment.BG_SKY

    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = sky_top_color
    sky_mat.sky_horizon_color = sky_horizon_color
    sky_mat.ground_horizon_color = ground_color
    sky.material = sky_mat

    env.sky = sky
    env_node.environment = env

func _create_sun_light() -> void:
    if get_node_or_null("Sun"):
        return

    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.light_energy = sun_energy
    sun.rotation_degrees = sun_angle
    sun.shadow_enabled = true
    add_child(sun)

func _create_ground() -> void:
    if get_node_or_null("Ground"):
        return

    var ground := StaticBody3D.new()
    ground.name = "Ground"
    add_child(ground)

    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = "GroundMesh"
    var quad_mesh := QuadMesh.new()
    quad_mesh.size = ground_size
    mesh_instance.mesh = quad_mesh

    var mat := StandardMaterial3D.new()
    mat.albedo_color = ground_color
    mat.roughness = 1.0
    quad_mesh.material = mat

    ground.add_child(mesh_instance)

    var collision := CollisionShape3D.new()
    collision.name = "GroundCollision"
    var shape := BoxShape3D.new()
    shape.size = Vector3(ground_size.x, ground_height, ground_size.y)
    collision.shape = shape
    collision.translation = Vector3(0, -ground_height / 2.0, 0)
    ground.add_child(collision)

func _spawn_player() -> void:
    var existing := get_node_or_null("Player")
    if existing:
        return

    var player := player_scene.instantiate()
    player.name = "Player"

    # Spawn a bit above ground in the center
    player.global_transform.origin = global_transform.origin + Vector3(0, 2.5, 0)
    add_child(player)