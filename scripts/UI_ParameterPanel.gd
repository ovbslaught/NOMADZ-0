extends Control

## Runtime parameter panel for the EA_Skybox demo.
##
## The layout is saved data: every group, slider, label and drop-down lives in
## UI_ParameterPanel.tscn and is visible in the editor without running the game.
## This script only wires those existing controls to the shader parameters of
## the selected sky preset and keeps the numbers next to the sliders current.
##
## Nothing here writes to disk. The panel calls set_shader_parameter() on the
## already loaded ShaderMaterial, which only changes the copy living in memory;
## ResourceSaver is never used, so the .tres presets stay exactly as shipped and
## every restart of the demo comes back to the authored look.
##
##   H - hide / show the panel (and the help overlay), for clean screenshots
##
## Colours stay in the inspector on purpose - sliders cover the numbers, the
## colour pickers of the material cover the rest.

## WorldEnvironment holding the sky this panel edits.
@export var environment_path: NodePath = ^"../../WorldEnvironment"

## Sky presets offered by the drop-down, in the same order as its items.
@export var presets: Array[ShaderMaterial] = []

## Help text drawn by the demo scene. Hidden together with the panel.
@export var help_overlay_path: NodePath = ^"../Help"

## Key that hides and shows the panel.
@export var toggle_key: Key = KEY_H

@onready var _panel: PanelContainer = $Panel
@onready var _params: VBoxContainer = $Panel/Layout/Scroll/Params
@onready var _preset_selector: OptionButton = $Panel/Layout/SurfaceRow/SurfaceSelector

## Material currently being edited. Null until a preset is picked.
var _material: ShaderMaterial = null

var _slider_rows: Array[Node] = []
var _bool_rows: Array[CheckBox] = []


func _ready() -> void:
	_collect_rows()
	_preset_selector.item_selected.connect(_on_preset_selected)
	_select_preset(_preset_selector.selected)


# -- Wiring -------------------------------------------------------------------
# Every row is named after the shader uniform it drives, so the panel needs no
# parallel table of names that could drift away from the scene.
func _collect_rows() -> void:
	for row in _params.get_children():
		if row is CheckBox:
			var box := row as CheckBox
			box.toggled.connect(_on_bool_toggled.bind(box))
			_bool_rows.append(box)
			continue
		var slider := row.get_node_or_null(^"Slider") as HSlider
		if slider != null:
			slider.value_changed.connect(_on_slider_changed.bind(row))
			_slider_rows.append(row)


func _on_preset_selected(index: int) -> void:
	_select_preset(index)


func _select_preset(index: int) -> void:
	var world_env := get_node_or_null(environment_path) as WorldEnvironment
	if world_env == null or index < 0 or index >= presets.size():
		_refresh_from_material()
		return
	_material = presets[index]
	# The WorldEnvironment script also turns the sun light to match the preset,
	# so shadows keep agreeing with the sun drawn in the sky.
	if world_env.has_method("_apply_preset"):
		world_env.call("_apply_preset", _material)
	elif world_env.environment != null and world_env.environment.sky != null:
		world_env.environment.sky.sky_material = _material
	_refresh_from_material()


# -- Control callbacks --------------------------------------------------------
func _on_slider_changed(value: float, row: Node) -> void:
	var slider := row.get_node(^"Slider") as HSlider
	_update_value_label(row, value, slider.step)
	if _material == null:
		return
	_material.set_shader_parameter(row.name, value)


func _on_bool_toggled(pressed: bool, box: CheckBox) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(box.name, pressed)


# -- Reading the material back ------------------------------------------------
# On start and after every switch the controls show what the picked preset
# really holds, not the defaults written into the scene.
func _refresh_from_material() -> void:
	for row in _slider_rows:
		var slider := row.get_node(^"Slider") as HSlider
		var value := float(_shader_value(row.name, slider.value))
		slider.set_value_no_signal(clampf(value, slider.min_value, slider.max_value))
		_update_value_label(row, slider.value, slider.step)
	for box in _bool_rows:
		box.set_pressed_no_signal(bool(_shader_value(box.name, box.button_pressed)))


## Value of one uniform on the current material. A material that never had the
## uniform assigned falls back to the default declared in the shader, and only
## then to what the scene shows.
func _shader_value(uniform: StringName, fallback: Variant) -> Variant:
	if _material == null:
		return fallback
	var value: Variant = _material.get_shader_parameter(uniform)
	if value == null and _material.shader != null:
		value = RenderingServer.shader_get_parameter_default(_material.shader.get_rid(), uniform)
	if value == null:
		return fallback
	return value


func _update_value_label(row: Node, value: float, step: float) -> void:
	var label := row.get_node_or_null(^"Header/Value") as Label
	if label == null:
		return
	if step >= 1.0:
		label.text = "%d" % int(round(value))
	elif step < 0.01:
		label.text = "%.3f" % value
	else:
		label.text = "%.2f" % value


# -- Hide / show --------------------------------------------------------------
# This node stays visible and only switches its child panel off, so the key
# still reaches the script once the panel is gone.
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != toggle_key:
		return
	var show_ui := not _panel.visible
	_panel.visible = show_ui
	var help := get_node_or_null(help_overlay_path) as CanvasItem
	if help != null:
		help.visible = show_ui
	get_viewport().set_input_as_handled()
