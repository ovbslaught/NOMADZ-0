@tool
class_name RopeGenPlugin extends EditorPlugin

const RopePathGizmo = preload("rope_path_gizmo.gd")
const RopePathGizmoToggles = preload("rope_path_gizmo_toggles.gd")
const RopeGenGui = preload("gui/rope_gen_gui_mesh_toolbar_button.gd")

var rope_path_gizmo_plugin: RopePathGizmo
var rope_gen_gui: RopeGenGui

func _enter_tree() -> void:
	var icon = preload("rope_gen_mesh_3d.svg")
	var gizmo_toggles := RopePathGizmoToggles.new()

	rope_path_gizmo_plugin = RopePathGizmo.new(self, gizmo_toggles)
	add_node_3d_gizmo_plugin(rope_path_gizmo_plugin)
	add_custom_type("RopeGenMesh3D", "Node3D", preload("rope_gen_mesh_3d.gd"), icon)
	
	var editor_selection = get_editor_interface().get_selection()
	editor_selection.selection_changed.connect(_on_selection_changed)

	rope_gen_gui = RopeGenGui.new(self)\
		.add_gizmo_toggles(gizmo_toggles)

func _exit_tree() -> void:
	rope_gen_gui.cleanup()
	remove_node_3d_gizmo_plugin(rope_path_gizmo_plugin)
	remove_custom_type("RopeGenMesh3D")

func _on_selection_changed() -> void:
	var selected = get_editor_interface().get_selection().get_selected_nodes()
	_refresh_gizmos(selected)

func _refresh_gizmos(nodes: Array[Node]) -> void:
	if nodes.is_empty():
		get_tree().root.propagate_call(&"update_gizmos")
		return

	for node in nodes:
		if not is_instance_valid(node):
			continue
		
		if node is RopeGenMesh3D:
			node.update_gizmos()