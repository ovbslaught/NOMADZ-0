class_name CombatManager
extends Node

@export var current_weapon: "PROTON_BLADE"
@export var elemental_affinity: "NONE"
var combo_count: int = 0
var combo_timer: Timer

func _ready() -> void:
	combo_timer = Timer.new()
	combo_timer.wait_time = 1.5
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_reset_combo)
	add_child(combo_timer)

func register_hit() -> void:
	combo_count += 1
	combo_timer.start()
	_trigger_hit_stop()
	print("[CombatManager] Hit registered. Combo: ", combo_count, " | Element: ", elemental_affinity)

func _trigger_hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.05 * 0.05).timeout
	Engine.time_scale = 1.0

func _reset_combo() -> void:
	combo_count = 0
	print("[CombatManager] Combo dropped.")

func set_elemental_affinity(affinity: String) -> void:
	elemental_affinity = affinity
