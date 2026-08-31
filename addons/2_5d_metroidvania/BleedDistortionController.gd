## BleedDistortionController.gd
## CanvasLayer/ColorRect — NOMADZ: Signal Descent
## Connects SignalverseManager bleed events to the bleed_distortion shader.
## Attach to a full-screen ColorRect with bleed_distortion.gdshader assigned.
## VultureCode / Sol / NOMADZ Universe

class_name BleedDistortionController
extends ColorRect

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var base_scanline : float = 0.12
@export var base_vignette : float = 0.35

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false
var _distortion   : float = 0.0
var _noise        : float = 0.0
var _target_dist  : float = 0.0
var _target_noise : float = 0.0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	if material == null:
		push_error("BleedDistortionController: no ShaderMaterial assigned")
		return

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_param("scanline_intensity", base_scanline)
	_set_param("vignette_strength",  base_vignette)
	_set_param("distortion_strength", 0.0)
	_set_param("noise_scale",         0.0)
	_set_param("corruption",          0.0)

	_connect_signals()

func _connect_signals() -> void:
	if SignalverseManager:
		SignalverseManager.distortion_started.connect(_on_distortion_started)
		SignalverseManager.distortion_ended.connect(_on_distortion_ended)
		SignalverseManager.corruption_level_changed.connect(_on_corruption_changed)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if material == null:
		return

	## Smoothly interpolate distortion
	_distortion = lerpf(_distortion, _target_dist, delta * 6.0)
	_noise      = lerpf(_noise,      _target_noise, delta * 4.0)

	_set_param("distortion_strength", _distortion)
	_set_param("noise_scale",         _noise)
	_set_param("time_offset",         fmod(Time.get_ticks_msec() * 0.001, 100.0))

# ─── EVENT HANDLERS ───────────────────────────────────────────────────────────
func _on_distortion_started(intensity: float, duration: float) -> void:
	_target_dist  = clampf(intensity, 0.0, 1.0)
	_target_noise = clampf(intensity * 0.4, 0.0, 1.0)
	if DEBUG_MODE:
		print("[BleedDistortion] Distortion: %.2f for %.2fs" % [intensity, duration])

func _on_distortion_ended() -> void:
	_target_dist  = 0.0
	_target_noise = 0.0

func _on_corruption_changed(level: float) -> void:
	var c := level / 100.0
	_set_param("corruption", c)
	## Corruption pushes base distortion level
	var base_dist := c * c * 0.25
	_target_dist = maxf(_target_dist, base_dist)
	_set_param("vignette_strength", base_vignette + c * 0.3)
	## Update tint
	var tint := SignalverseManager.get_corruption_color()
	_set_param("tint_color", tint)

# ─── UTILITY ──────────────────────────────────────────────────────────────────
func _set_param(param: String, value: Variant) -> void:
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter(param, value)
