extends Node3D
class_name CombatManager

signal attack_executed(combo_step)
signal parry_triggered
signal nova_burst_fired

@export var combo_timeout: float = 0.8
@export var base_damage: float = 10.0

var current_combo: int = 0
var last_attack_time: float = 0.0
var is_parrying: bool = false
var input_cooldown: float = 0.0

@onready var hit_box: Area3D = $HitBox
@onready var hit_col: CollisionShape3D = $HitBox/CollisionShape3D

func _ready():
    if hit_col:
        hit_col.disabled = true

func _process(delta):
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Combo decay
    if current_combo > 0 and (current_time - last_attack_time) > combo_timeout:
        reset_combo()

    # Fallback to hardcoded keys (J = Attack, K = Parry, L = Nova Burst)
    # This ensures it works instantly without opening Godot's Input Map
    if current_time > input_cooldown:
        if Input.is_physical_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            execute_attack()
            input_cooldown = current_time + 0.3
        elif Input.is_physical_key_pressed(KEY_K) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            trigger_parry()
            input_cooldown = current_time + 0.5
        elif Input.is_physical_key_pressed(KEY_L):
            fire_nova_burst()
            input_cooldown = current_time + 1.0

func execute_attack():
    current_combo = min(current_combo + 1, 3)
    last_attack_time = Time.get_ticks_msec() / 1000.0
    
    # Enable hitbox briefly for collision detection
    if hit_col:
        hit_col.disabled = false
        get_tree().create_timer(0.15).timeout.connect(func(): hit_col.disabled = true)
    
    emit_signal("attack_executed", current_combo)
    print("[COMBAT] Proton Strike! Combo Tier: ", current_combo)
    
    # Telemetry: Tell the AI DM you're being aggressive
    if Engine.has_singleton("Director"):
        Engine.get_singleton("Director").raise_tension(0.1)

func trigger_parry():
    is_parrying = true
    emit_signal("parry_triggered")
    print("[COMBAT] Parry Stance Active (i-frames on)")
    
    # i-frames last for 0.3 seconds
    get_tree().create_timer(0.3).timeout.connect(func(): is_parrying = false)

func fire_nova_burst():
    emit_signal("nova_burst_fired")
    print("[COMBAT] NOVABURST AoE Triggered!")
    
    # Emit gossip packet to Termux Backend!
    if Engine.has_singleton("TelemetryBridge"):
        Engine.get_singleton("TelemetryBridge").emit_civ_event("nova_burst_attack", {"combo_tier": current_combo})
    
    current_combo = 0

func reset_combo():
    current_combo = 0
    print("[COMBAT] Combo Chain Reset")
