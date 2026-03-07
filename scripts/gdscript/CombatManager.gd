# CombatManager.gd - Combo chain system, hit detection, damage events
extends Node

signal combo_started(combo_name: String)
signal combo_completed(combo_name: String, damage: float)
signal hit_registered(target: Node, damage: float, hit_type: String)

@export var combo_timeout: float = 1.5
@export var base_damage_multiplier: float = 1.0

enum HitType { LIGHT, HEAVY, SPECIAL, FLIP_STRIKE, PROTON_BLAST }

var current_combo: Array[String] = []
var combo_timer: float = 0.0
var total_combo_damage: float = 0.0
var hit_history: Array = []

const COMBO_CHAINS = {
    "uridium_rush": ["light", "light", "heavy"],
    "flip_slam": ["flip_strike", "heavy"],
    "proton_cascade": ["proton_blast", "proton_blast", "special"],
    "tension_break": ["heavy", "special", "flip_strike"],
}

const DAMAGE_VALUES = {
    HitType.LIGHT: 10.0,
    HitType.HEAVY: 25.0,
    HitType.SPECIAL: 50.0,
    HitType.FLIP_STRIKE: 35.0,
    HitType.PROTON_BLAST: 40.0,
}

func _ready():
    set_process(true)
    Director.world_tension_changed.connect(_on_tension_changed)

func _process(delta: float) -> void:
    if combo_timer > 0.0:
        combo_timer -= delta
        if combo_timer <= 0.0:
            _reset_combo()

func register_hit(target: Node, hit_type: HitType) -> void:
    var hit_name = HitType.keys()[hit_type].to_lower()
    current_combo.append(hit_name)
    combo_timer = combo_timeout
    
    var damage = DAMAGE_VALUES[hit_type] * base_damage_multiplier
    var tension_bonus = Director.get_world_tension() * 0.5
    damage *= (1.0 + tension_bonus)
    
    total_combo_damage += damage
    hit_history.append({"target": target, "damage": damage, "type": hit_name, "time": Time.get_ticks_msec()})
    
    hit_registered.emit(target, damage, hit_name)
    _check_combo_completion()
    DebugTools.log("Hit: %s -> %.1f dmg (combo: %d)" % [hit_name, damage, current_combo.size()])

func _check_combo_completion() -> void:
    for combo_name in COMBO_CHAINS:
        var pattern = COMBO_CHAINS[combo_name]
        if current_combo.size() >= pattern.size():
            var match_found = true
            for i in pattern.size():
                if current_combo[current_combo.size() - pattern.size() + i] != pattern[i]:
                    match_found = false
                    break
            if match_found:
                _execute_combo(combo_name)
                return

func _execute_combo(combo_name: String) -> void:
    var bonus_damage = total_combo_damage * 0.5
    combo_completed.emit(combo_name, total_combo_damage + bonus_damage)
    DebugTools.log("COMBO: %s! Total: %.1f dmg" % [combo_name.to_upper(), total_combo_damage + bonus_damage])
    _reset_combo()

func _reset_combo() -> void:
    current_combo.clear()
    total_combo_damage = 0.0
    combo_timer = 0.0

func _on_tension_changed(t: float) -> void:
    base_damage_multiplier = 1.0 + (t * 0.3)
