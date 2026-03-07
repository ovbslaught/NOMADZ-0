# AIAgentBase.gd - Base class for all AI agents in NOMADZ-0
extends Node

enum BehaviorState { IDLE, PATROL, CHASE, ATTACK, FLEE, EVOLVE }

@export var agent_id: String = "agent_001"
@export var behavior_state: BehaviorState = BehaviorState.IDLE
@export var evolution_threshold: float = 0.75

var tension_level: float = 0.0
var memory_log: Array = []

func _ready():
    set_process(true)
    _on_agent_ready()

func _on_agent_ready():
    pass

func evaluate_tension(t: float) -> void:
    tension_level = t
    if tension_level >= evolution_threshold:
        _trigger_evolution()

func _trigger_evolution() -> void:
    behavior_state = BehaviorState.EVOLVE
    Director.ai_evolved.emit(agent_id, BehaviorState.keys()[behavior_state])

func log_memory(event: String) -> void:
    memory_log.append({"time": Time.get_ticks_msec(), "event": event})
    if memory_log.size() > 100:
        memory_log.pop_front()
