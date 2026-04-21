@tool
class_name SceneSwitcher
extends Node3D

## Runtime Scene Switcher for NOMADZ environments
## Usage: Add to your scene, call switch_mode() to toggle

enum Mode { SPACE, OCEAN }

@export var auto_switch_time: float = 0.0  ## Auto-switch interval (0 = disabled)
@export var start_mode: Mode = Mode.SPACE

var current_mode: Mode
var timer: float = 0.0
var world_env: WorldEnvironment
var sun: DirectionalLight3D

func _ready():
	current_mode = start_mode
	_find_scene_nodes()
	switch_mode(current_mode)

func _process(delta):
	if auto_switch_time > 0:
		timer += delta
		if timer >= auto_switch_time:
			timer = 0.0
			toggle_mode()

func _find_scene_nodes():
	# Find WorldEnvironment and DirectionalLight3D in scene
	for node in get_tree().root.find_children("*", "WorldEnvironment"):
		world_env = node
		break
	
	for node in get_tree().root.find_children("*", "DirectionalLight3D"):
		sun = node
		break

func toggle_mode():
	if current_mode == Mode.SPACE:
		switch_mode(Mode.OCEAN)
	else:
		switch_mode(Mode.SPACE)

func switch_mode(mode: Mode):
	current_mode = mode
	
	match mode:
		Mode.SPACE:
			_apply_space_settings()
		Mode.OCEAN:
			_apply_ocean_settings()

func _apply_space_settings():
	if not world_env or not world_env.environment:
		return
	
	var env = world_env.environment
	env.background_mode = Environment.BG_SKY
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.1)
	env.ambient_light_energy = 0.2
	env.volumetric_fog_enabled = false
	
	if sun:
		sun.light_color = Color.WHITE
		sun.light_energy = 0.8
	
	print("[SceneSwitcher] Switched to DEEP SPACE mode")

func _apply_ocean_settings():
	if not world_env or not world_env.environment:
		return
	
	var env = world_env.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.1, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.3, 0.5)
	env.ambient_light_energy = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.015
	env.volumetric_fog_albedo = Color(0.2, 0.4, 0.6)
	
	if sun:
		sun.light_color = Color(0.7, 0.85, 1.0)
		sun.light_energy = 0.5
	
	print("[SceneSwitcher] Switched to OCEAN UNDERWATER mode")
