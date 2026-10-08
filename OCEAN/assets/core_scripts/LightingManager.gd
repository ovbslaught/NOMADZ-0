# NOMADZ-0 :: LightingManager.gd
# 1980s palette neon pulses — navy fog, cyan glow, φ-resonance tween
# Phi = 0.618 golden ratio pulse timing
extends Node
class_name LightingManager

const PHI: float = 0.618
const PALETTE := {
	"cyan":    Color(0.0,  1.0,  1.0),
	"magenta": Color(1.0,  0.0,  1.0),
	"yellow":  Color(1.0,  1.0,  0.0),
	"green":   Color(0.0,  1.0,  0.0),
	"navy":    Color(0.0,  0.0,  0.502)
}

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var omni_cyan: OmniLight3D = $OmniLightCyan

func _ready() -> void:
	_apply_retro_fog()
	_start_phi_pulse()

func _apply_retro_fog() -> void:
	var env := world_env.environment
	env.background_color = PALETTE["navy"]
	env.fog_enabled = true
	env.fog_density = 0.05
	env.ambient_light_color = PALETTE["cyan"]
	env.ambient_light_energy = 0.4

func _start_phi_pulse() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(omni_cyan, "light_energy", 2.5, PHI * 2.0)
	tween.tween_property(omni_cyan, "light_energy", 0.5, PHI * 2.0)

func pulse_cyan() -> void:
	omni_cyan.light_color = PALETTE["cyan"]
	omni_cyan.light_energy = 3.0
	var tween := create_tween()
	tween.tween_property(omni_cyan, "light_energy", 0.5, 0.3)

func pulse_color(color_key: String) -> void:
	if PALETTE.has(color_key):
		omni_cyan.light_color = PALETTE[color_key]
		pulse_cyan()
