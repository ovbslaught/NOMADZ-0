extends Node
class_name GameModeManager

enum Mode {
	SCENE_KIT_3D,
	CHALLENGER_DEEP_3D,
	OCEAN_WORLD_2D,
	CITY_METROIDVANIA,
	MULTI_AGENT_SIM
}

@export var default_mode: Mode = Mode.SCENE_KIT_3D

var current_scene_node: Node = null

var mode_scenes = {
	Mode.SCENE_KIT_3D: "res://scenes/NomadzMainScene.tscn",
	Mode.CHALLENGER_DEEP_3D: "res://scenes/SpaceChallengerDeep.tscn",
	Mode.OCEAN_WORLD_2D: "res://scenes/ocean_world.tscn",
	Mode.CITY_METROIDVANIA: "res://scenes/maincity.tscn",
	Mode.MULTI_AGENT_SIM: "res://scenes/multi_agent_demo.tscn"
}

func _ready() -> void:
	print("[NOMADZ-0] GameModeManager Initialized. Booting mode: ", default_mode)
	load_mode(default_mode)

func load_mode(mode: Mode) -> void:
	if current_scene_node:
		current_scene_node.queue_free()
		current_scene_node = null
	
	var scene_path = mode_scenes.get(mode, "res://scenes/NomadzMainScene.tscn")
	if ResourceLoader.exists(scene_path):
		var packed = load(scene_path) as PackedScene
		if packed:
			current_scene_node = packed.instantiate()
			add_child(current_scene_node)
			print("[NOMADZ-0] Successfully switched to mode: ", mode, " -> ", scene_path)
	else:
		push_error("[NOMADZ-0] Mode scene not found: " + scene_path)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				load_mode(Mode.SCENE_KIT_3D)
			KEY_F2:
				load_mode(Mode.CHALLENGER_DEEP_3D)
			KEY_F3:
				load_mode(Mode.OCEAN_WORLD_2D)
			KEY_F4:
				load_mode(Mode.CITY_METROIDVANIA)
			KEY_F5:
				load_mode(Mode.MULTI_AGENT_SIM)
