
@tool
extends RefCounted

static func create_vector2_control() -> Dictionary:
	var container = VBoxContainer.new()
	var editor := &"Editor"
	var theme := EditorInterface.get_editor_theme()
	
	var x_spinner := EditorSpinSlider.new()
	x_spinner.theme = theme
	x_spinner.min_value = -9999.0
	x_spinner.max_value = 9999.0
	x_spinner.label = "x"
	x_spinner.step = 0.001
	x_spinner.editing_integer = false
	x_spinner.hide_slider = true
	x_spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	x_spinner.add_theme_color_override(&"label_color", x_spinner.get_theme_color(&"property_color_x", editor))
	container.add_child(x_spinner)
	
	var y_spinner := EditorSpinSlider.new()
	y_spinner.theme = theme
	y_spinner.min_value = -9999.0
	y_spinner.max_value = 9999.0
	y_spinner.label = "y"
	y_spinner.step = 0.001
	y_spinner.editing_integer = false
	y_spinner.hide_slider = true
	y_spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	y_spinner.add_theme_color_override(&"label_color", y_spinner.get_theme_color(&"property_color_y", editor))
	container.add_child(y_spinner)
	
	return {
		&"container": container,
		&"x_spinner": x_spinner,
		&"y_spinner": y_spinner
	}

static func create_slider_control(min: float, max: float) -> EditorSpinSlider:
	var spinner := EditorSpinSlider.new()
	spinner.min_value = min
	spinner.max_value = max
	spinner.step = 0.001
	spinner.editing_integer = false
	spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spinner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	
	return spinner