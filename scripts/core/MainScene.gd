# NOMADZ-0 :: MainScene.gd
# Autoload root — boots player, lighting, audio, debug
# Wires CameraSystem target, Director signals
extends Node
class_name MainScene

@onready var player: PlayerController = $Player
@onready var camera_sys: CameraSystem = $CameraSystem
@onready var lighting: LightingManager = $LightingManager
@onready var audio: AudioManager = $AudioManager
@onready var debug: DebugTools = $DebugTools

func _ready() -> void:
	# Wire camera to player
	camera_sys.target = player

	# Boot retro lighting
	lighting.pulse_cyan()

	# Boot ambient audio
	audio.play_ambient("trench_ambient")

	# Register player in group for debug + director hooks
	player.add_to_group("player")

	# Director autoload hook
	var director := get_node_or_null("/root/Director")
	if director:
		director.connect("loot_drop", _on_loot_drop)
		director.connect("boss_spawned", _on_boss_spawned)

	print("[NOMADZ-0] MainScene ready. VCN-3.1 | Sol | φ=0.618")

func _on_loot_drop(position: Vector3) -> void:
	lighting.pulse_color("yellow")
	audio.flash_biolum()

func _on_boss_spawned(_boss: Node3D) -> void:
	lighting.pulse_color("magenta")
