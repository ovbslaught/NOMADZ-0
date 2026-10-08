@tool
extends EditorPlugin

## NOMADZ Scene Kit - Runtime-Switchable Environments
## DEEP SPACE <-> OCEAN UNDERWATER
## Compatible: Godot 4.5/4.6 + Compatibility Renderer (GLES3)

enum SceneMode {
	DEEP_SPACE,
	OCEAN_UNDERWATER
}

var current_mode: SceneMode = SceneMode.DEEP_SPACE
var environment_node: WorldEnvironment
var directional_light: DirectionalLight3D

func _enter_tree():
	print("[NOMADZ Scene Kit] Plugin activated")
	add_custom_type(
		"SceneSwitcher",
		"Node3D",
		preload("scene_switcher.gd"),
		null
	)

func _exit_tree():
	print("[NOMADZ Scene Kit] Plugin deactivated")
	remove_custom_type("SceneSwitcher")

func switch_environment(mode: SceneMode):
	current_mode = mode
	
	match mode:
		SceneMode.DEEP_SPACE:
			_setup_space_environment()
		SceneMode.OCEAN_UNDERWATER:
			_setup_ocean_environment()

func _setup_space_environment():
	print("[Scene Kit] Switching to DEEP SPACE mode")
	# Space: Dark background, distant stars, minimal ambient light
	if environment_node:
		var env = environment_node.environment
		env.background_mode = Environment.BG_SKY
		env.ambient_light_color = Color(0.05, 0.05, 0.1)
		env.ambient_light_energy = 0.2
	
	if directional_light:
		directional_light.light_color = Color.WHITE
		directional_light.light_energy = 0.8

func _setup_ocean_environment():
	print("[Scene Kit] Switching to OCEAN UNDERWATER mode")
	# Ocean: Blue tint, caustics, volumetric fog
	if environment_node:
		var env = environment_node.environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.0, 0.15, 0.3)
		env.ambient_light_color = Color(0.1, 0.3, 0.5)
		env.ambient_light_energy = 0.5
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.02
	
	if directional_light:
		directional_light.light_color = Color(0.7, 0.85, 1.0)
		directional_light.light_energy = 0.6
