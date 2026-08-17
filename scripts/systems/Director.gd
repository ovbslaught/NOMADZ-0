extends Node

signal world_tension_changed(value)
signal codex_event(event_id)
signal player_flipped

@export var tension_decay: float = 0.05
@export var max_tension: float = 1.0

var world_tension: float = 0.0
var loot_modifier: float = 1.0
var spawn_scalar: float = 1.0
var death_count: int = 0
var time_since_reward: float = 0.0

func _process(delta: float) -> void:
    # Naturally decay tension so the game breathes between combat
    world_tension = max(0.0, world_tension - (tension_decay * delta))
    time_since_reward += delta
    update_modifiers()

func raise_tension(amount: float) -> void:
    world_tension = clamp(world_tension + amount, 0.0, max_tension)
    emit_signal("world_tension_changed", world_tension)

func report_event(event_type: String, data: Dictionary = {}) -> void:
    match event_type:
        "player_died":
            death_count += 1
            raise_tension(0.3)
            print("[DIRECTOR] Player Died. Death Count: ", death_count)
        "enemy_defeated":
            raise_tension(0.1)
        "reward_collected":
            time_since_reward = 0.0
            loot_modifier = max(1.0, loot_modifier - 0.1)
            print("[DIRECTOR] Reward Collected. Decreasing loot mod to: ", loot_modifier)
        "biome_entered":
            emit_signal("codex_event", data.get("biome_id", "unknown"))

# Hook called by MainScene when Player dies
func on_player_died() -> void:
    report_event("player_died")

# Hook called by MainScene when Player collects an item
func on_reward_collected(id: String) -> void:
    report_event("reward_collected", {"id": id})

func get_loot_modifier(ctx: Dictionary = {}) -> float:
    # If it's been a long time since a reward, increase drop chance
    return loot_modifier + (time_since_reward * 0.01)

func get_spawn_scalar(ctx: Dictionary = {}) -> float:
    # The higher the tension, the more enemies spawn
    return spawn_scalar + (world_tension * 0.5)

func get_world_tension() -> float:
    return world_tension

func update_modifiers() -> void:
    # Slowly normalize modifiers back to 1.0 over time
    loot_modifier = lerp(loot_modifier, 1.0, 0.001)
    spawn_scalar = lerp(spawn_scalar, 1.0, 0.001)
