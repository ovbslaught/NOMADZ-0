extends Node
class_name RetroArchBridge

const ROM_BASE = "/storage/emulated/0/Roms"
var roms_database: Dictionary = {}
var active_game: String = ""

signal game_started(title: String)
signal rom_scan_complete(count: int)

func _ready():
    _scan_roms()  # Scans NES/SNES/Genesis/Arcade/N64/PS1/GameBoy

func launch_game(system: String, rom_name: String):
    # Launches game in RetroArch

func get_games_for_system(system: String) -> Array:
    return roms_database.get(system, [])