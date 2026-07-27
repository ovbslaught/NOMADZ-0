@tool
extends VBoxContainer
## NOMADZ Scene Kit — Editor Dock UI
## VULTURE:INC / VultureCode  |  Godot 4.5/4.6

func _ready() -> void:
	name = "NOMADZ Scene Kit"
	_build_ui()

func _build_ui() -> void:
	# Header
	var lbl := Label.new()
	lbl.text = "NOMADZ Scene Kit\nVULTURE:INC"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	add_child(HSeparator.new())

	# Scene Builder
	var btn_build := Button.new()
	btn_build.text = "⚡ Build Main Scene"
	btn_build.tooltip_text = "Generates NomadzMainScene.tscn source in Output"
	btn_build.pressed.connect(_build_main_scene)
	add_child(btn_build)
	add_child(HSeparator.new())

	# Environment switchers
	var lbl_env := Label.new()
	lbl_env.text = "Environment (Editor Preview)"
	add_child(lbl_env)

	var btn_space := Button.new()
	btn_space.text = "🚀 Set Environment: SPACE"
	btn_space.pressed.connect(_set_space)
	add_child(btn_space)

	var btn_ocean := Button.new()
	btn_ocean.text = "🌊 Set Environment: OCEAN"
	btn_ocean.pressed.connect(_set_ocean)
	add_child(btn_ocean)
	add_child(HSeparator.new())

	# Info
	var lbl_vessel := Label.new()
	lbl_vessel.text = "Vessel (runtime only)"
	add_child(lbl_vessel)

	var note := Label.new()
	note.text = "Press F1 in-game to swap\nenvironment & vessel."
	note.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	add_child(note)

	var lbl_keys := Label.new()
	lbl_keys.text = "W/S=Fwd/Back  A/D=Strafe\nE/Q=Rise/Sink  Arrows=Yaw"
	lbl_keys.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(lbl_keys)

func _build_main_scene() -> void:
	var builder := load("res://addons/nomadz_scene_kit/scripts/scene_builder.gd")
	if builder:
		builder.build()
		print("[NOMADZ] Scene source printed to Output — copy & save as NomadzMainScene.tscn")
	else:
		push_error("[NOMADZ] scene_builder.gd not found!")

func _set_space() -> void:
	var mgr := _get_manager()
	if mgr: mgr.switch_environment("space")
	else: push_warning("[NOMADZ] EnvironmentManager not found in current scene")

func _set_ocean() -> void:
	var mgr := _get_manager()
	if mgr: mgr.switch_environment("ocean")
	else: push_warning("[NOMADZ] EnvironmentManager not found in current scene")

func _get_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		return tree.current_scene.get_node_or_null("EnvironmentManager")
	return null
