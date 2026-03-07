# MainScene.gd - Root scene controller
extends Node

@onready var player: CharacterBody3D = $Player
@onready var world_tension_meter: Control = $HUD/WorldTensionMeter
@onready var asset_placer: Node = $AssetPlacer
@onready var audio_manager: Node = $"/root/AudioManager"

const TENSION_RISE_INTERVAL = 30.0
var tension_timer: float = 0.0

func _ready():
    DebugTools.log("MainScene: Initialized NOMADZ-0 Cosmic-key")
    asset_placer.place_assets_around(Vector3.ZERO, 42)
    Director.world_tension_changed.connect(_on_tension)

func _process(delta: float) -> void:
    tension_timer += delta
    if tension_timer >= TENSION_RISE_INTERVAL:
        tension_timer = 0.0
        Director.raise_tension(0.05)

func _on_tension(t: float) -> void:
    DebugTools.log("World tension: %.2f" % t)
    if t >= 1.0:
        _trigger_endgame()

func _trigger_endgame() -> void:
    DebugTools.log("CRITICAL TENSION — Initiating finale sequence")
    get_tree().paused = true
