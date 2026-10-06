# NOMADZ-0 :: AudioManager.gd
# Bioluminescent flash SFX + ambient director
extends Node
class_name AudioManager

@onready var sfx_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var ambient_player: AudioStreamPlayer = $AudioStreamPlayer

const AUDIO_PATHS := {
	"trench_ambient": "res://audio/abyssal_trench.ogg",
	"cyan_pulse":     "res://audio/cyan_pulse.ogg",
	"sonar_ping":     "res://audio/sonar_ping.ogg",
	"proton_blade":   "res://audio/proton_blade.ogg"
}

func _ready() -> void:
	play_ambient("trench_ambient")

func play_ambient(key: String) -> void:
	if not AUDIO_PATHS.has(key):
		return
	var stream := load(AUDIO_PATHS[key]) as AudioStream
	ambient_player.stream = stream
	ambient_player.play()

func flash_biolum() -> void:
	_play_sfx("cyan_pulse")

func sonar_ping() -> void:
	_play_sfx("sonar_ping")

func proton_strike() -> void:
	_play_sfx("proton_blade")

func _play_sfx(key: String) -> void:
	if not AUDIO_PATHS.has(key):
		return
	var stream := load(AUDIO_PATHS[key]) as AudioStream
	sfx_player.stream = stream
	sfx_player.play()
