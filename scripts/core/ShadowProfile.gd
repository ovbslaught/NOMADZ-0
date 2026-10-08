# ShadowProfile.gd - Parallel Consciousness Traits (Autoload: ShadowProfile)
# Tracks Nomad habits → Codex perks + ghost replays. Director/Drift hooks.
class_name ShadowProfile
extends Node

signal trait_updated(trait: String, value: float)
signal profile_evolved(perk: String)

var traits: Dictionary = {
    "aggro": 0.5,      # Rush vs retreat
    "melee": 0.5,      # Punch vs gun
    "healer": 0.5,     # Pots vs risky
    "builder": 0.0,    # Ultrahand usage
    "explorer": 0.0     # Biomes visited
}

var death_log: Array[Dictionary] = []  # Session deaths
var run_history: Array[Dictionary] = [] # Compressed runs

@export var evolution_threshold: float = 0.8
@export var max_deaths: int = 50

func _ready() -> void:
    Director.player_death.connect(_log_death)
    Director.major_quest_completed.connect(_quest_update)

func update_trait(trait: String, delta: float) -> void:
    traits[trait] = clampf(traits.get(trait, 0.5) + delta, 0.0, 1.0)
    trait_updated.emit(trait, traits[trait])
    _check_evolution(trait)

func _log_death(biome: String = "") -> void:
    death_log.append({
        "ts": Time.get_unix_time_from_system(),
        "biome": biome,
        "traits_snapshot": traits.duplicate()
    })
    if death_log.size() > max_deaths: death_log.pop_front()
    Director.force_narration("Shadow echoes your fall...")

func log_run_end(final_pos: Vector3, kills: int) -> void:
    run_history.append({
        "ts": Time.get_unix_time_from_system(),
        "end_pos": final_pos,
        "kills": kills,
        "traits": traits.duplicate()
    })
    _spawn_ghost_replay()

func _quest_update(id: String) -> void:
    traits.explorer += 0.1
    trait_updated.emit("explorer", traits.explorer)

func _check_evolution(trait: String) -> void:
    match trait:
        "aggro" if traits.aggro > evolution_threshold:
            profile_evolved.emit("berserker_perk")
        "melee" if traits.melee > evolution_threshold:
            profile_evolved.emit("blade_master")
        "builder" if traits.builder > evolution_threshold:
            profile_evolved.emit("ultrahand_genius")

func _spawn_ghost_replay() -> void:
    # EchoRunRecorder call: Replay last run as ghost NPC
    EchoRunRecorder.replay_latest(biome_flags.current)

# Public: Codex query
func get_profile_summary() -> Dictionary:
    return {
        "traits": traits,
        "deaths": death_log.size(),
        "runs": run_history.size()
    }