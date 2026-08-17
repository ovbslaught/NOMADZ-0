extends Node3D
class_name LimboSpawner

@export var enemy_scene: PackedScene
@export var base_spawn_rate: float = 6.0
@export var spawn_radius: float = 15.0
@export var max_enemies: int = 12

var spawn_timer: float = 0.0

func _ready() -> void:
    reset_timer()
    print("[SPAWNER] LimboAI Spawner Online. Listening to AI Director...")

func _process(delta: float) -> void:
    spawn_timer -= delta
    if spawn_timer <= 0.0:
        spawn_enemy()
        reset_timer()

func reset_timer() -> void:
    var scalar = 1.0
    if Engine.has_singleton("Director"):
        scalar = Engine.get_singleton("Director").get_spawn_scalar()
    
    # The higher the tension scalar, the shorter the timer. 
    # At 2.0x scalar, enemies spawn twice as fast.
    spawn_timer = base_spawn_rate / max(0.5, scalar)

func spawn_enemy() -> void:
    # 1. Ensure we don't exceed the max enemy cap
    var current_enemies = get_tree().get_nodes_in_group("enemy")
    if current_enemies.size() >= max_enemies:
        return
        
    # 2. Locate the Player
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        return
        
    # 3. Load the LimboAI Enemy Scene if not explicitly set
    if not enemy_scene:
        var path = "res://scenes/npcs/EnemyBase.tscn"
        if ResourceLoader.exists(path):
            enemy_scene = load(path)
        else:
            return
            
    # 4. Instantiate and position
    var inst = enemy_scene.instantiate()
    get_tree().current_scene.add_child(inst)
    
    # Calculate a random position on the XZ plane around the player
    var angle = randf() * TAU
    var offset = Vector3(cos(angle), 0, sin(angle)) * spawn_radius
    
    # Drop them slightly above the ground so they fall in cleanly
    inst.global_position = player.global_position + offset
    inst.global_position.y += 3.0
    
    # Add to group so we can track the cap
    inst.add_to_group("enemy")
    print("[SPAWNER] Dropped LimboAI unit. Tension scalar: ", Engine.get_singleton("Director").get_spawn_scalar())
