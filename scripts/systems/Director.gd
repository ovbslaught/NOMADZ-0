extends Node

signal world_tension_changed(value)
signal codex_event(event_id)

@export var max_tension: float = 1.0
var world_tension: float = 0.0
var death_count: int = 0

func raise_tension(amount: float) -> void:
    world_tension = clamp(world_tension + amount, 0.0, max_tension)
    emit_signal("world_tension_changed", world_tension)

func on_player_died() -> void:
    death_count += 1
    raise_tension(0.3)
