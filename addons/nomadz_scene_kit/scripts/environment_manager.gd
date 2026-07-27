extends Node
## NOMADZ Scene Kit — Environment Manager
## Handles SPACE <-> OCEAN runtime switching
## VULTURE:INC | Godot 4.5/4.6 Compat Renderer

signal environment_changed(env_name: String)

@export var space_ambient_energy: float = 0.05
@export var ocean_ambient_energy: float = 0.4
@export var ocean_fog_density: float = 0.04
@export var ocean_fog_color: Color = Color(0.01, 0.06, 0.14)

enum Env { SPACE, OCEAN }
var current_env: Env = Env.SPACE

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var starfield: Node = get_parent().get_node_or_null("Starfield")
@onready var uw_post: CanvasLayer = get_parent().get_node_or_null("UnderwaterPost")

func _ready() -> void:
	_apply_space()

func switch_environment(env_name: String) -> void:
	match env_name.to_lower():
		"space": _apply_space()
		"ocean": _apply_ocean()
		_: push_warning("[NOMADZ] Unknown environment: " + env_name)

func _apply_space() -> void:
	current_env = Env.SPACE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.1)
	env.ambient_light_energy = space_ambient_energy
	env.fog_enabled = false
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.1
	world_env.environment = env
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.4
	sun.visible = true
	if starfield: starfield.visible = true
	if uw_post:   uw_post.visible = false
	_set_vessel_mode("spaceship")
	environment_changed.emit("space")

func _apply_ocean() -> void:
	current_env = Env.OCEAN
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = ocean_fog_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.0, 0.12, 0.2)
	env.ambient_light_energy = ocean_ambient_energy
	env.fog_enabled = true
	env.fog_light_color = ocean_fog_color
	env.fog_density = ocean_fog_density
	env.glow_enabled = true
	env.glow_intensity = 0.3
	world_env.environment = env
	sun.light_color = Color(0.2, 0.5, 0.8)
	sun.light_energy = 0.5
	sun.visible = true
	if starfield: starfield.visible = false
	if uw_post:   uw_post.visible = true
	_set_vessel_mode("submarine")
	environment_changed.emit("ocean")

func _set_vessel_mode(mode: String) -> void:
	var vessel := get_parent().get_node_or_null("Vessel")
	if vessel and vessel.has_method("set_mode"):
		vessel.set_mode(mode)
