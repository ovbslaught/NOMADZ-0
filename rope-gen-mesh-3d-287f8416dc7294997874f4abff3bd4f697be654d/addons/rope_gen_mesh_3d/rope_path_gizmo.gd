extends EditorNode3DGizmoPlugin

const RopePathGizmoToggles = preload("rope_path_gizmo_toggles.gd")

const LINE_MAT: String = "line"
const AABB_MAT: String = "line_aabb"
const HANDLE_MAT: String = "handle"
const ORIGIN_PIN_MAT: String = "origin_sphere"
const ORIGIN_BILLBOARD_MAT: String = "origin_billboard"
const SHAPE_MATERIAL: String = "shape_material"

var lines := PackedVector3Array([])
var handles := PackedVector3Array([])

var origin_top_mesh: SphereMesh
var origin_base_mesh: CylinderMesh
var origin_billboard_mesh: PointMesh

var _plugin: RopeGenPlugin
var _toggles: RopePathGizmoToggles
var _drag_plane: Plane = Plane()
var _is_dragging: bool = false
var _selected_nodes: Array[Node] = []

func _init(plugin: RopeGenPlugin, toggles: RopePathGizmoToggles) -> void:
	_plugin = plugin
	_toggles = toggles

	# handles
	create_handle_material(HANDLE_MAT)
	create_handle_material(ORIGIN_BILLBOARD_MAT, true, preload("rope_gen_mesh_3d.svg"))
	create_material(AABB_MAT, Color('#fff380'))

	# origin
	create_material(LINE_MAT, Color('#fc7f7f'))
	create_material(ORIGIN_PIN_MAT, Color('#fc7f7f80'))
	origin_top_mesh = _create_sphere_mesh()
	origin_base_mesh = _create_cyllinder_mesh()
	origin_billboard_mesh = _create_billboard_mesh()

	# collision shapes
	var shape_color: Color = ProjectSettings.get_setting("debug/shapes/collision/shape_color")
	create_material(SHAPE_MATERIAL, shape_color)

func _get_gizmo_name() -> String:
	return "RopeGenMesh3D"

func _has_gizmo(for_node_3d) -> bool:
	return for_node_3d is RopeGenMesh3D

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return "Rope point " + str(handle_id)

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	return handles[handle_id]

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return

	var pts := node.rope_data.points
	var pts_size := pts.size()

	if pts_size == 0 or handle_id >= pts_size:
		return
	
	if not _is_dragging:
		_drag_plane = _calc_drag_plane(node, camera, handle_id)

	var ray_from := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	
	var intersection := _drag_plane.intersects_ray(ray_from, ray_dir)
	
	if intersection == null:
		return
	
	pts[handle_id] = node.to_local(intersection)
	
	# only update gizmo visuals & inspector instead of regenerating mesh while dragging
	node.notify_property_list_changed()
	_redraw(gizmo)

func _begin_handle_action(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null or handle_id >= node.rope_data.points.size():
		return

	_drag_plane = _calc_drag_plane(node, EditorInterface.get_editor_viewport_3d(0).get_camera_3d(), handle_id)
	_is_dragging = true

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, _secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return

	var pts := node.rope_data.points
	var pts_size := pts.size()

	if pts_size == 0:
		return

	if cancel:
		pts[handle_id] = restore
		return
	
	var undo_redo: EditorUndoRedoManager = _plugin.get_undo_redo()
	var method := &"_set_rope_path_point"
	undo_redo.create_action("Set Rope Path Point")
	undo_redo.add_undo_method(self, method, node, handle_id, restore)
	undo_redo.add_do_method(self, method, node, handle_id, pts[handle_id])
	undo_redo.commit_action()

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var editor_selection = EditorInterface.get_selection()
	var is_selected = gizmo.get_node_3d() in editor_selection.get_selected_nodes()

	if not is_selected:
		return

	if _toggles.visible_aabbs: _draw_aabbs(gizmo)
	if _toggles.visible_collision_shapes: _draw_collision_shapes(gizmo)
	if _toggles.visible_origins: _draw_origin(gizmo)
	_draw_lines(gizmo)
	_draw_handles(gizmo)

func _draw_lines(gizmo: EditorNode3DGizmo) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return

	var pts := node.rope_data.points
	var pts_size := pts.size()

	if pts_size < 2: 
		return

	lines.clear()

	for i in range(pts_size - 1):
		lines.push_back(pts[i])
		lines.push_back(pts[i + 1])

	gizmo.add_lines(lines, get_material(LINE_MAT, gizmo))

func _draw_handles(gizmo: EditorNode3DGizmo) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return

	var pts := node.rope_data.points
	var pts_size := pts.size()

	if pts_size == 0:
		return

	handles.clear()

	for i in range(pts_size):
		handles.push_back(pts[i])

	gizmo.add_handles(handles, get_material(HANDLE_MAT, gizmo), [])

func _draw_aabbs(gizmo: EditorNode3DGizmo) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return
	
	for mesh in node.vis_instance_meshes:
		lines.clear()
		lines = _get_aabb_lines(mesh.get_aabb())
		gizmo.add_lines(lines, get_material(AABB_MAT, gizmo))

func _draw_collision_shapes(gizmo: EditorNode3DGizmo) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	if node.rope_data == null: 
		return

	if not node.rope_data.use_collisions or node.rope_data.points.size() == 0:
		return

	var xform_base := Transform3D()
	var st := SurfaceTool.new()

	for shape in node.phys_instance_shapes:
		st.append_from(shape.get_debug_mesh(), 0, xform_base)

	gizmo.add_mesh(st.commit(), get_material(SHAPE_MATERIAL, gizmo))


func _draw_origin(gizmo: EditorNode3DGizmo) -> void:
	var node := gizmo.get_node_3d() as RopeGenMesh3D

	var xform_base := Transform3D()
	xform_base.origin = Vector3(0.0, 0.25, 0.0)

	var xform_top := Transform3D()
	xform_top.origin = Vector3(0.0, 0.6, 0.0)

	var xform_billboard := Transform3D()
	xform_billboard.origin = Vector3(0.0, 0.85, 0.0)

	gizmo.add_mesh(origin_base_mesh, get_material(ORIGIN_PIN_MAT, gizmo), xform_base)
	gizmo.add_mesh(origin_top_mesh, get_material(ORIGIN_PIN_MAT, gizmo), xform_top)
	gizmo.add_mesh(origin_billboard_mesh, get_material(ORIGIN_BILLBOARD_MAT, gizmo), xform_billboard)

func _set_rope_path_point(rope_gen: RopeGenMesh3D, id: int, pos: Vector3) -> void:
	if rope_gen && rope_gen.rope_data && rope_gen.rope_data.points.size() > 0:
		var pts := rope_gen.rope_data.points
		pts[id] = pos
		rope_gen.rope_data.emit_changed()

func _calc_drag_plane(rope_gen: RopeGenMesh3D, camera_3d: Camera3D, handle_id: int) -> Plane:
	var current_point_local := rope_gen.rope_data.points[handle_id]
	var current_point_global := rope_gen.to_global(current_point_local)
	var camera_normal := -camera_3d.global_transform.basis.z

	return Plane(camera_normal, current_point_global.dot(camera_normal))

func _get_aabb_lines(aabb: AABB) -> PackedVector3Array:
	var c: Array[Vector3] = [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0, 0),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0),
		aabb.position + Vector3(0, aabb.size.y, 0),
		aabb.position + Vector3(0, 0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, 0, aabb.size.z),
		aabb.end,
		aabb.position + Vector3(0, aabb.size.y, aabb.size.z)
	]
	
	return PackedVector3Array([
		c[0], c[1], c[1], c[2], c[2], c[3], c[3], c[0],  # bottom
		c[4], c[5], c[5], c[6], c[6], c[7], c[7], c[4],  # top
		c[0], c[4], c[1], c[5], c[2], c[6], c[3], c[7]   # verticals
	])

func _create_sphere_mesh() -> SphereMesh:
	var sph := SphereMesh.new()
	sph.radius = 0.125
	sph.height = 0.25
	sph.radial_segments = 8
	sph.rings = 4

	return sph

func _create_cyllinder_mesh() -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.03
	cyl.height = 0.5
	cyl.radial_segments = 8
	cyl.rings = 0
	cyl.cap_top = false

	return cyl

func _create_billboard_mesh() -> PointMesh:
	return PointMesh.new()
