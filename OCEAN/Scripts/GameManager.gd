extends Node

# Persistent Metroidvania State (Ouroboros Ready)
var player_hp = 5
var max_hp = 5
var scrap_count = 0

# Unlockables
var has_double_jump = false
var has_dash = false
var has_blaster = false
var signal_core_restored = false

func _ready():
    print("GameManager/WORMHOLE state initialized.")

func unlock_ability(ability_name: String):
    if ability_name == "double_jump":
        has_double_jump = true
        print("ABILITY UNLOCKED: Phase Jump")
    elif ability_name == "dash":
        has_dash = true
        print("ABILITY UNLOCKED: Vector Dash")
