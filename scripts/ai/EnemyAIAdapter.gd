extends CharacterBody3D

@export var max_health: float = 50.0
@export var speed: float = 4.0
@export var attack_range: float = 2.0

var health: float = 50.0
var dead: bool = false

# LimboAI's Behavior Tree Player
@onready var bt_player: BTPlayer = $BTPlayer

func _ready() -> void:
    health = max_health
    
    # Inject the Player into LimboAI's Blackboard so the tree knows who to hunt
    if bt_player and bt_player.blackboard:
        var player = get_tree().get_first_node_in_group("player")
        bt_player.blackboard.set_var("target", player)
        bt_player.blackboard.set_var("speed", speed)
        bt_player.blackboard.set_var("attack_range", attack_range)

func take_damage(amount: float) -> void:
    if dead: return
    health -= amount
    
    # Visual hit reaction (flash red)
    var mesh = get_node_or_null("MeshInstance3D")
    if mesh and mesh.material_override:
        mesh.material_override.albedo_color = Color.RED
        get_tree().create_timer(0.1).timeout.connect(func(): mesh.material_override.albedo_color = Color.WHITE)

    if health <= 0:
        die()

func is_dead() -> bool:
    return dead

func die() -> void:
    dead = true
    print("[ENEMY] Unit destroyed.")
    queue_free()
