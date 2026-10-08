## AtmosphereController.gd
## Node2D — NOMADZ: Signal Descent
## Per-room atmosphere: ambient lighting, fog, parallax backgrounds,
## bioluminescent floor activity, dynamic corruption response.
## Animal Well-style: lighting IS gameplay information.
## VultureCode / Sol / NOMADZ Universe

class_name AtmosphereController
extends Node2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var base_ambient_color    : Color  = Color(0.02, 0.02, 0.06)
@export var base_fog_density      : float  = 0.018
@export var enable_bio_floor      : bool   = true
@export var bio_floor_base_color  : Color  = Color(0.08, 0.55, 0.35)
@export var bio_alert_color       : Color  = Color(0.7, 0.08, 0.04)
@export var parallax_depth        : float  = 0.3     ## 0 = fixed, 1 = full parallax
@export var light_flicker_scale   : float  = 0.08    ## Corruption-driven flicker amount

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var world_env    : WorldEnvironment  = $WorldEnvironment
@onready var bio_floor    : TileMapLayer      = $BioFloorLayer     ## Uses bio shader
@onready var bg_layer_far : ParallaxLayer     = $Parallax/Far
@onready var bg_layer_mid : ParallaxLayer     = $Parallax/Mid
@onready var ambient_lights: Node2D           = $AmbientLights
@onready var drip_particles: GPUParticles2D   = $DripParticles     ## Ceiling drips

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false

var _alert_level    : float = 0.0   ## 0 = calm bio, 1 = fully alert red
var _target_alert   : float = 0.0
var _corruption     : float = 0.0
var _player_near    : bool  = false
var _player_dist    : float = 300.0
var _time           : float = 0.0
var _frame_count    : int   = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_configure_environment()
	_configure_bio_shader()
	_connect_signals()
	_log("AtmosphereController ready")

func _configure_environment() -> void:
	if not is_instance_valid(world_env):
		return
	var env := world_env.environment
	if env == null:
		env = Environment.new()
		world_env.environment = env
	env.background_mode  = Environment.BG_COLOR
	env.background_color = base_ambient_color
	env.fog_enabled      = base_fog_density > 0.0
	env.fog_density      = base_fog_density

func _configure_bio_shader() -> void:
	if not is_instance_valid(bio_floor) or not enable_bio_floor:
		return
	var mat := bio_floor.material
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("base_color", bio_floor_base_color)
		(mat as ShaderMaterial).set_shader_parameter("alert_color", bio_alert_color)

func _connect_signals() -> void:
	SignalverseManager.corruption_level_changed.connect(_on_corruption_changed)
	SignalverseManager.bleed_event_triggered.connect(_on_bleed_event)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_frame_count += 1
	_time += delta

	_update_player_proximity()
	_tick_alert_level(delta)
	_update_bio_shader()
	_update_environment(delta)
	_update_ambient_flicker(delta)

func _update_player_proximity() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_player_near = false
		_player_dist = 300.0
		return
	var p := players[0] as Node2D
	_player_dist = global_position.distance_to(p.global_position)
	_player_near = _player_dist < 150.0

	## High player speed triggers alert
	if p.has_method("get") and p.get("velocity") != null:
		var spd : float = (p.velocity as Vector2).length()
		if enable_bio_floor:
			_target_alert = maxf(_target_alert, clampf((spd - 100.0) / 200.0, 0.0, 1.0))

func _tick_alert_level(delta: float) -> void:
	## Alert decays toward 0 over time
	_target_alert = maxf(0.0, _target_alert - delta * 0.4)
	_alert_level  = lerpf(_alert_level, _target_alert, delta * 3.0)

func _update_bio_shader() -> void:
	if not is_instance_valid(bio_floor) or not enable_bio_floor:
		return
	var mat := bio_floor.material
	if not mat is ShaderMaterial:
		return
	var sm := mat as ShaderMaterial
	sm.set_shader_parameter("alert_level",     _alert_level)
	sm.set_shader_parameter("player_distance", _player_dist)
	sm.set_shader_parameter("corruption",      _corruption)

func _update_environment(delta: float) -> void:
	if not is_instance_valid(world_env) or world_env.environment == null:
		return
	var env := world_env.environment
	## Fog thickens with corruption
	var target_fog := base_fog_density + _corruption * 0.04
	env.fog_density = lerpf(env.fog_density, target_fog, delta * 0.5)
	## Ambient darkens with corruption
	var target_bg := base_ambient_color.lerp(Color(0.06, 0.01, 0.01), _corruption)
	env.background_color = env.background_color.lerp(target_bg, delta * 0.3)

func _update_ambient_flicker(delta: float) -> void:
	if not is_instance_valid(ambient_lights):
		return
	if _corruption < 0.2:
		return
	for light in ambient_lights.get_children():
		if light is PointLight2D:
			var flicker := sin(_time * 8.0 + light.position.x * 0.1) * _corruption * light_flicker_scale
			(light as PointLight2D).energy += flicker * delta * 10.0

# ─── EVENTS ───────────────────────────────────────────────────────────────────
func _on_corruption_changed(level: float) -> void:
	_corruption = level / 100.0

func _on_bleed_event(event_type: String, _payload: Dictionary) -> void:
	match event_type:
		"phantom_spawn":
			## Phantom nearby spooks bio floor
			_target_alert = minf(1.0, _target_alert + 0.4)
		"gravity_pulse":
			## Drip particles reverse briefly
			if is_instance_valid(drip_particles):
				drip_particles.emitting = true
		"signal_pulse_player":
			## Pulse calms bio floor
			_target_alert = 0.0
			_alert_level  = 0.0

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[AtmosphereController | F%d] %s" % [_frame_count, msg])

func trigger_alert(level: float) -> void:
	_target_alert = clampf(level, 0.0, 1.0)
