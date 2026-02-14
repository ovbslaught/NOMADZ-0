@tool
extends PopupPanel

var rx_input : EditorSpinSlider
var ry_input : EditorSpinSlider
var rotation_input : EditorSpinSlider
var _arc_under_edit : ScalableArc

var _dragging := false
var _drag_start := Vector2.ZERO

func _enter_tree() -> void:
	visible = false
	rx_input = _mk_input()
	ry_input = _mk_input()
	rotation_input = _mk_input(1.0)
	%RxInputContainer.add_child(rx_input)
	%RyInputContainer.add_child(ry_input)
	%RotationInputContainer.add_child(rotation_input)
	if not rx_input.value_changed.is_connected(_on_radius_changed):
		rx_input.value_changed.connect(_on_radius_changed)
	if not ry_input.value_changed.is_connected(_on_radius_changed):
		ry_input.value_changed.connect(_on_radius_changed)
	if not rotation_input.value_changed.is_connected(_on_rotation_changed):
		rotation_input.value_changed.connect(_on_rotation_changed)

func _on_button_pressed() -> void:
	hide()


func _on_rotation_changed(new_rot : float) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update arc rotation")
	undo_redo.add_do_property(_arc_under_edit, 'rotation_deg', new_rot)
	undo_redo.add_undo_property(_arc_under_edit, 'rotation_deg', _arc_under_edit.rotation_deg)
	undo_redo.commit_action()


func _on_radius_changed(_v : float) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update arc radius")
	undo_redo.add_do_property(_arc_under_edit, 'radius', Vector2(rx_input.value, ry_input.value))
	undo_redo.add_undo_property(_arc_under_edit, 'radius', _arc_under_edit.radius)
	undo_redo.commit_action()


func _on_sweep_check_box_toggled(toggled_on: bool) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update arc sweep flag")
	undo_redo.add_do_property(_arc_under_edit, 'sweep_flag', toggled_on)
	undo_redo.add_undo_property(_arc_under_edit, 'sweep_flag', _arc_under_edit.sweep_flag)
	undo_redo.commit_action()


func _on_large_arc_check_box_toggled(toggled_on: bool) -> void:
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("Update arc large arc flag")
	undo_redo.add_do_property(_arc_under_edit, 'large_arc_flag', toggled_on)
	undo_redo.add_undo_property(_arc_under_edit, 'large_arc_flag', _arc_under_edit.large_arc_flag)
	undo_redo.commit_action()


func popup_with_value(arc : ScalableArc):
	_arc_under_edit = arc
	rx_input.set_value_no_signal(arc.radius.x)
	ry_input.set_value_no_signal(arc.radius.y)
	rotation_input.set_value_no_signal(arc.rotation_deg)
	%LargeArcCheckBox.set_pressed_no_signal(arc.large_arc_flag)
	%SweepCheckBox.set_pressed_no_signal(arc.sweep_flag)
	popup_centered()


func _mk_input(step := 0.001) -> EditorSpinSlider:
	var num_input := EditorSpinSlider.new()
	num_input.suffix = "px"
	num_input.hide_slider = true
	num_input.value = 0.0
	num_input.editing_integer = false
	num_input.allow_lesser = true
	num_input.allow_greater = true
	num_input.step = 0.001
	return num_input


func _on_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if not _dragging:
				_dragging = true
				_drag_start = EditorInterface.get_base_control().get_local_mouse_position()
		else:
			_dragging = false
	if event is InputEventMouseMotion and _dragging:
		position += Vector2i(EditorInterface.get_base_control().get_local_mouse_position() - _drag_start)
		_drag_start = EditorInterface.get_base_control().get_local_mouse_position()
