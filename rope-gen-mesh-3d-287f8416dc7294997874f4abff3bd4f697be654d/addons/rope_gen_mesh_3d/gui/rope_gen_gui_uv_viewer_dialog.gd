@tool
extends RefCounted

const GUIControlFactory = preload("rope_gen_gui_control_factory.gd")

var _plugin: EditorPlugin
var _dialog: AcceptDialog

var _selected_mesh: RopeGenMesh3D
var _rot_origin_preview: Vector2
var _uv_lines: PackedVector2Array

# UI Controls
var _dialog_parent_hbox: HBoxContainer
var _debug_uv_tex: TextureRect
var _debug_uv_arc: AspectRatioContainer
var _debug_uv_controls_vbox: VBoxContainer
var _file_dialog: EditorFileDialog

var _controls_box_line: Array[HBoxContainer]

var _bg_file_select_label: Label
var _translation_label: Label
var _rot_origin_label: Label
var _rot_angle_label: Label
var _scale_label: Label

var _file_select_btn: Button
var _file_clear_btn: Button
var _translation_control: Dictionary
var _rot_origin_control: Dictionary
var _rot_angle_control: EditorSpinSlider
var _scale_control: Dictionary

func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_create_dialog()
	_create_uv_display()
	_create_settings_panel()

func _create_dialog() -> void:
	_dialog = AcceptDialog.new()
	_dialog.title = "View/Edit UV1"
	_dialog.canceled.connect(_on_dialog_closed)
	_dialog.confirmed.connect(_on_dialog_closed)
	_dialog.about_to_popup.connect(_on_dialog_about_to_popup)
	
	_dialog_parent_hbox = HBoxContainer.new()
	_dialog_parent_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_dialog.add_child(_dialog_parent_hbox)

func _create_settings_panel() -> void:
	_debug_uv_controls_vbox = VBoxContainer.new()
	_debug_uv_controls_vbox.custom_minimum_size.x = 300
	_debug_uv_controls_vbox.custom_minimum_size.y = 600
	_debug_uv_controls_vbox.add_theme_constant_override(&"separation", 16)
	_debug_uv_controls_vbox.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_debug_uv_controls_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_debug_uv_controls_vbox.size_flags_stretch_ratio = 0.2
	
	_create_file_selection_line()
	_create_translation_line()
	_create_rotation_origin_line()
	_create_rotation_angle_line()
	_create_scale_line()
	
	for line in _controls_box_line:
		_debug_uv_controls_vbox.add_child(line)
	
	_dialog_parent_hbox.add_child(_debug_uv_controls_vbox)

func _create_file_selection_line() -> void:
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.file_selected.connect(func(path: String):
		var texture = load(path)
		if texture is Texture2D:
			_debug_uv_tex.texture = texture
		else:
			push_error("Failed to load texture: " + path)
	)
	_dialog.add_child(_file_dialog)
	
	_controls_box_line.push_back(HBoxContainer.new())
	_controls_box_line[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_bg_file_select_label = Label.new()
	_bg_file_select_label.text = "Background image preview"
	_bg_file_select_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bg_file_select_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_controls_box_line[0].add_child(_bg_file_select_label)
	
	_file_select_btn = Button.new()
	_file_select_btn.text = "Select"
	_file_select_btn.pressed.connect(func(): _file_dialog.popup_centered(Vector2i(900, 600)))
	_controls_box_line[0].add_child(_file_select_btn)
	
	_file_clear_btn = Button.new()
	_file_clear_btn.text = "Clear"
	_file_clear_btn.pressed.connect(func(): _debug_uv_tex.texture = null)
	_controls_box_line[0].add_child(_file_clear_btn)

func _create_translation_line() -> void:
	_controls_box_line.push_back(HBoxContainer.new())
	_controls_box_line[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_translation_label = Label.new()
	_translation_label.text = "UV Translation\n(in UV local space)"
	_translation_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_translation_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_controls_box_line[1].add_child(_translation_label)
	
	_translation_control = GUIControlFactory.create_vector2_control()
	_translation_control.container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_translation_control.x_spinner.value_changed.connect(_on_changed_translation_x)
	_translation_control.y_spinner.value_changed.connect(_on_changed_translation_y)
	_controls_box_line[1].add_child(_translation_control.container)

func _create_rotation_origin_line() -> void:
	_controls_box_line.push_back(HBoxContainer.new())
	_controls_box_line[2].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_rot_origin_label = Label.new()
	_rot_origin_label.text = "UV Rotation Origin\n(in global space)"
	_rot_origin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rot_origin_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_controls_box_line[2].add_child(_rot_origin_label)
	
	_rot_origin_control = GUIControlFactory.create_vector2_control()
	_rot_origin_control.container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rot_origin_control.x_spinner.value_changed.connect(_on_changed_rot_origin_x)
	_rot_origin_control.y_spinner.value_changed.connect(_on_changed_rot_origin_y)
	_controls_box_line[2].add_child(_rot_origin_control.container)

func _create_rotation_angle_line() -> void:
	_controls_box_line.push_back(HBoxContainer.new())
	_controls_box_line[3].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_rot_angle_label = Label.new()
	_rot_angle_label.text = "UV Rotation Angle Degrees"
	_rot_angle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_rot_angle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rot_angle_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_controls_box_line[3].add_child(_rot_angle_label)
	
	_rot_angle_control = GUIControlFactory.create_slider_control(-360.0, 360.0)
	_rot_angle_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rot_angle_control.value_changed.connect(_on_changed_rot_angle_degrees)
	_controls_box_line[3].add_child(_rot_angle_control)

func _create_scale_line() -> void:
	_controls_box_line.push_back(HBoxContainer.new())
	_controls_box_line[4].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_scale_label = Label.new()
	_scale_label.text = "UV Scale"
	_scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_controls_box_line[4].add_child(_scale_label)
	
	_scale_control = GUIControlFactory.create_vector2_control()
	_scale_control.container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scale_control.x_spinner.value_changed.connect(_on_changed_scale_x)
	_scale_control.y_spinner.value_changed.connect(_on_changed_scale_y)
	_controls_box_line[4].add_child(_scale_control.container)

func _create_uv_display() -> void:
	_debug_uv_arc = AspectRatioContainer.new()
	_debug_uv_arc.alignment_horizontal = AspectRatioContainer.ALIGNMENT_BEGIN
	_debug_uv_arc.size_flags_stretch_ratio = 0.8
	_dialog_parent_hbox.add_child(_debug_uv_arc)
	
	_debug_uv_tex = TextureRect.new()
	_debug_uv_tex.custom_minimum_size = Vector2(600, 600) * EditorInterface.get_editor_scale()
	_debug_uv_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_debug_uv_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_uv_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debug_uv_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_uv_tex.draw.connect(_debug_uv_draw)
	_debug_uv_arc.add_child(_debug_uv_tex)

func _on_dialog_about_to_popup() -> void:
	var uv_translation := _selected_mesh.rope_data.tex_uv_translation
	var uv_rot_origin := _selected_mesh.rope_data.tex_uv_rotation_origin
	var uv_rot_angle_degrees := _selected_mesh.rope_data.tex_uv_rotation_angle_degrees
	_rot_origin_preview = uv_rot_origin
	var uv_scale := _selected_mesh.rope_data.tex_uv_scale
	
	_translation_control.x_spinner.set_value_no_signal(uv_translation.x)
	_translation_control.y_spinner.set_value_no_signal(uv_translation.y)
	_rot_origin_control.x_spinner.set_value_no_signal(uv_rot_origin.x)
	_rot_origin_control.y_spinner.set_value_no_signal(uv_rot_origin.y)
	_rot_angle_control.set_value_no_signal(uv_rot_angle_degrees)
	_scale_control.x_spinner.set_value_no_signal(uv_scale.x)
	_scale_control.y_spinner.set_value_no_signal(uv_scale.y)

func _on_dialog_closed() -> void:
	_debug_uv_tex.texture = null

# UV setting change callbacks
func _on_changed_translation_x(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_translation.x = value
	_redraw_uv_lines()

func _on_changed_translation_y(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_translation.y = value
	_redraw_uv_lines()

func _on_changed_rot_origin_x(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_rotation_origin.x = value
	_rot_origin_preview.x = value
	_redraw_uv_lines()

func _on_changed_rot_origin_y(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_rotation_origin.y = value
	_rot_origin_preview.y = value
	_redraw_uv_lines()

func _on_changed_rot_angle_degrees(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_rotation_angle_degrees = value
	_redraw_uv_lines()

func _on_changed_scale_x(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_scale.x = value
	_redraw_uv_lines()

func _on_changed_scale_y(value: float) -> void:
	_selected_mesh.rope_data.tex_uv_scale.y = value
	_redraw_uv_lines()

func _redraw_uv_lines() -> void:
	_create_uv_lines(_selected_mesh.vis_instance_meshes[0], 0)
	_debug_uv_tex.call_deferred(&"queue_redraw")

# pulled from godot's source: mesh_instance_3d_editor_plugin.cpp (with modifications)
func _debug_uv_draw() -> void:
	if _uv_lines.is_empty(): 
		return
	
	var editor_theme := &"Editor"
	var e_scale := roundf(EditorInterface.get_editor_scale())
	var grid_color := _debug_uv_tex.get_theme_color(&"mono_color", editor_theme) * Color(1, 1, 1, 0.125)
	var lines_color := _debug_uv_tex.get_theme_color(&"mono_color", editor_theme) * Color(1, 1, 1, 0.5)
	
	_debug_uv_tex.clip_contents = true
	
	# background
	_debug_uv_tex.draw_rect(
		Rect2(Vector2.ZERO, _debug_uv_tex.size), 
		_debug_uv_tex.get_theme_color(&"dark_color_3", editor_theme) * Color(1, 1, 1, 0.5)
	)
	
	# border
	_debug_uv_tex.draw_rect(
		Rect2(Vector2.ONE, _debug_uv_tex.size - Vector2.ONE), 
		grid_color,
		false,
		e_scale
		)
	
	# grid lines
	var cell_size := 0.125
	for x: int in range(8):
		_debug_uv_tex.draw_line(
			Vector2(_debug_uv_tex.size.x * cell_size * x, 0),
			Vector2(_debug_uv_tex.size.x * cell_size * x, _debug_uv_tex.size.y),
			grid_color,
			e_scale
		)
	
	for y: int in range(8):
		_debug_uv_tex.draw_line(
			Vector2(0, _debug_uv_tex.size.y * cell_size * y),
			Vector2(_debug_uv_tex.size.x, _debug_uv_tex.size.y * cell_size * y),
			grid_color,
			e_scale
		)
	
	# UV lines
	_debug_uv_tex.draw_multiline(_uv_lines, lines_color, e_scale)
	
	# rotation origin crosshair
	var cross_line_size := cell_size / 4.0
	_debug_uv_tex.draw_line(
		Vector2((_rot_origin_preview.x - cross_line_size) * _debug_uv_tex.size.x, _rot_origin_preview.y * _debug_uv_tex.size.y),
		Vector2((_rot_origin_preview.x + cross_line_size) * _debug_uv_tex.size.x, _rot_origin_preview.y * _debug_uv_tex.size.y),
		Color.RED,
		e_scale
	)
	_debug_uv_tex.draw_line(
		Vector2(_rot_origin_preview.x * _debug_uv_tex.size.x, (_rot_origin_preview.y - cross_line_size) * _debug_uv_tex.size.y),
		Vector2(_rot_origin_preview.x * _debug_uv_tex.size.x, (_rot_origin_preview.y + cross_line_size) * _debug_uv_tex.size.y),
		Color.RED,
		e_scale
	)

# pulled from godot's source: mesh_instance_3d_editor_plugin.cpp (with modifications)
func _create_uv_lines(mesh: Mesh, p_layer: int) -> void:
	if mesh == null:
		push_error("Mesh is null")
		return
	
	var edges: Dictionary = {}
	_uv_lines.clear()
	
	for i in range(mesh.get_surface_count()):
		if mesh.surface_get_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		
		var arrays: Array = mesh.surface_get_arrays(i)
		var uv_array_index = Mesh.ARRAY_TEX_UV if p_layer == 0 else Mesh.ARRAY_TEX_UV2
		var uv: PackedVector2Array = arrays[uv_array_index]
		
		if uv.is_empty():
			push_error("Mesh has no UV in layer %d." % (p_layer + 1))
			return
		
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var ic: int
		
		if not indices.is_empty():
			ic = indices.size()
		else:
			ic = uv.size()
		
		for j in range(0, ic, 3):
			for k in range(3):
				var edge_a: Vector2
				var edge_b: Vector2
				
				if not indices.is_empty():
					edge_a = uv[indices[j + k]]
					edge_b = uv[indices[j + ((k + 1) % 3)]]
				else:
					edge_a = uv[j + k]
					edge_b = uv[j + ((k + 1) % 3)]
				
				# make edge key (normalized so edge is same regardless of direction)
				var edge_key: String
				if edge_a.x < edge_b.x or (edge_a.x == edge_b.x and edge_a.y < edge_b.y):
					edge_key = "%v|%v" % [edge_a, edge_b]
				else:
					edge_key = "%v|%v" % [edge_b, edge_a]
				
				if edges.has(edge_key):
					continue
				
				# multiplied by container size to appear correctly sized
				# godot's source code does not do that strangely
				_uv_lines.push_back(edge_a * _debug_uv_tex.size)
				_uv_lines.push_back(edge_b * _debug_uv_tex.size)
				edges[edge_key] = true

# public interface
func show_for_mesh(mesh: RopeGenMesh3D) -> void:
	_selected_mesh = mesh
	_create_uv_lines(mesh.vis_instance_meshes[0], 0)
	_dialog.popup_centered()

func get_dialog() -> AcceptDialog:
	return _dialog

func cleanup() -> void:
	_dialog_parent_hbox.queue_free()
	_bg_file_select_label.queue_free()
	_file_select_btn.queue_free()
	_file_clear_btn.queue_free()
	_translation_label.queue_free()
	_rot_origin_label.queue_free()
	_rot_angle_label.queue_free()
	_scale_label.queue_free()
	
	for key in _translation_control.keys():
		_translation_control[key].queue_free()
	
	while not _controls_box_line.is_empty():
		_controls_box_line.pop_back().queue_free()
	
	_debug_uv_controls_vbox.queue_free()
	_debug_uv_tex.queue_free()
	_debug_uv_arc.queue_free()
	_file_dialog.queue_free()
	_dialog.queue_free()