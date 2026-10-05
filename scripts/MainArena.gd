extends Node3D

@onready var player: CharacterBody3D = $Player
@onready var health_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/HealthBar
@onready var stamina_bar: ProgressBar = $HUD/MarginContainer/VBoxContainer/StaminaBar
@onready var char_label: Label = $HUD/MarginContainer/VBoxContainer/CharLabel
@onready var combo_label: Label = $HUD/MarginContainer/VBoxContainer/ComboLabel

func _ready() -> void:
    if player:
        if player.has_signal("health_changed"):
            player.connect("health_changed", Callable(self, "_on_player_health_changed"))
        if player.has_signal("stamina_changed"):
            player.connect("stamina_changed", Callable(self, "_on_player_stamina_changed"))
        if player.has_signal("character_switched"):
            player.connect("character_switched", Callable(self, "_on_character_switched"))
        
        var combat = player.get_node_or_null("Pivot/CombatManager")
        if combat and combat.has_signal("attack_executed"):
            combat.connect("attack_executed", Callable(self, "_on_combat_attack"))
            
    # Set initial values
    if health_bar: health_bar.value = 100
    if stamina_bar: stamina_bar.value = 100
    if char_label: char_label.text = "CHARACTER: SPIDER-MAN [Press C or 1-4 to swap]"
    if combo_label: combo_label.text = "COMBO: READY"

func _on_player_health_changed(curr: float, max_h: float) -> void:
    if health_bar:
        health_bar.max_value = max_h
        health_bar.value = curr

func _on_player_stamina_changed(curr: float, max_s: float) -> void:
    if stamina_bar:
        stamina_bar.max_value = max_s
        stamina_bar.value = curr

func _on_character_switched(idx: int, cname: String) -> void:
    if char_label:
        char_label.text = "CHARACTER: %s [Slot %d] (Keys: 1=Spidey, 2=Surfer, 3=Soldier, 4=Warrior)" % [cname.to_upper(), idx + 1]

func _on_combat_attack(tier: int) -> void:
    if combo_label:
        combo_label.text = "COMBO: TIER %d!" % tier
        var t = create_tween()
        combo_label.scale = Vector2(1.3, 1.3)
        t.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2)
