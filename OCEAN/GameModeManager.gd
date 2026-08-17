class_name GameModeManager
extends Node

enum Mode { TITLE, TOPDOWN_ZELDA, METROIDVANIA, SHMUP, MODE_SELECT }

var current_mode: Mode = Mode.TITLE
var mode_loaded := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	switch_mode(Mode.TITLE)

func switch_mode(mode: Mode) -> void:
	current_mode = mode
	mode_loaded = false
	_clear_scene()
	match mode:
		Mode.TITLE:
			_load_title()
		Mode.MODE_SELECT:
			_load_mode_select()
		Mode.TOPDOWN_ZELDA:
			_load_topdown()
		Mode.METROIDVANIA:
			_load_metroidvania()
		Mode.SHMUP:
			_load_shmup()

func _clear_scene() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	get_tree().paused = false

func _load_title() -> void:
	var label := Label.new()
	label.text = "NOMADZ-0: COSMIC KEY\n\nPress ENTER to begin"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	add_child(label)

func _load_mode_select() -> void:
	var panel := VBoxContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	var title := Label.new()
	title.text = "SELECT MODE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	panel.add_child(title)
	var modes := ["1. TOP-DOWN ZELDA-LIKE", "2. METROIDVANIA", "3. SHMUP", "PRESS 1-3 TO SELECT"]
	for text in modes:
		var lbl := Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(lbl)
	add_child(panel)

func _load_topdown() -> void:
	mode_loaded = true
	var scene := preload("res://topdown/world/Overworld.tscn").instantiate()
	add_child(scene)

func _load_metroidvania() -> void:
	mode_loaded = true
	var main_scene := preload("res://Scenes/Main.tscn").instantiate()
	add_child(main_scene)

func _load_shmup() -> void:
	mode_loaded = true
	var scene := preload("res://shmup/ShmupLevel.tscn").instantiate()
	add_child(scene)
	scene.add_to_group("shmup_level")

func _unhandled_input(event: InputEvent) -> void:
	match current_mode:
		Mode.TITLE:
			if event.is_action_pressed("shoot") or event.is_action_pressed("interact"):
				switch_mode(Mode.MODE_SELECT)
		Mode.MODE_SELECT:
			if event.is_action_pressed("shoot"):
				switch_mode(Mode.TOPDOWN_ZELDA)
			if event.is_action_pressed("dash"):
				switch_mode(Mode.METROIDVANIA)
			if event.is_action_pressed("jetpack"):
				switch_mode(Mode.SHMUP)
