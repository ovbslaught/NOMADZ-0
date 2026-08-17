class_name CharacterCustomizer
extends Control

signal customization_applied(data: Dictionary)
signal customization_saved(slot: int)

@export var preview_scene: PackedScene
@export var slots := 3

@onready var preview := $Preview as Node3D
@onready var color_palette := $ColorPalette as GridContainer
@onready var slot_container := $Slots as HBoxContainer
@onready var apply_btn := $ApplyButton as Button

var current_data: Dictionary = {
	skin_color = Color("#e8b88a"),
	hair_color = Color("#000000"),
	eye_color = Color("#00ffff"),
	primary_color = Color("#00ffff"),
	secondary_color = Color("#ff00ff"),
	accent_color = Color("#ffff00"),
	body_type = 0,
	hair_style = 0,
	outfit = 0,
	head_gear = 0,
}

var saved_slots: Array[Dictionary] = []

func _ready() -> void:
	_connect_signals()
	_build_color_palette()
	_build_slot_ui()
	_update_preview()

func _connect_signals() -> void:
	apply_btn.pressed.connect(_on_apply)

func _build_color_palette() -> void:
	var swatches := [
		Color("#00ffff"), Color("#ff00ff"), Color("#ffff00"),
		Color("#00ff00"), Color("#000080"), Color("#ffffff"),
		Color("#000000"), Color("#ff0000"), Color("#0000ff"),
		Color("#e8b88a"), Color("#8b4513"), Color("#c0c0c0"),
	]
	for swatch in swatches:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.modulate = swatch
		btn.tooltip_text = swatch.to_html()
		btn.pressed.connect(_on_swatch_picked.bind(swatch))
		color_palette.add_child(btn)

func _build_slot_ui() -> void:
	for i in range(slots):
		var btn := Button.new()
		btn.text = "Slot %d" % [i + 1]
		btn.pressed.connect(_on_slot_selected.bind(i))
		slot_container.add_child(btn)

func _on_swatch_picked(color: Color) -> void:
	current_data.primary_color = color
	_update_preview()

func _on_slot_selected(slot: int) -> void:
	if slot < saved_slots.size():
		current_data = saved_slots[slot].duplicate(true)
		_update_preview()

func _on_apply() -> void:
	customization_applied.emit(current_data)

func save_to_slot(slot: int) -> void:
	while saved_slots.size() <= slot:
		saved_slots.append({})
	saved_slots[slot] = current_data.duplicate(true)
	customization_saved.emit(slot)

func _update_preview() -> void:
	pass
