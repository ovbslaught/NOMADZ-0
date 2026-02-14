@tool
class_name RopeGenMesh3D extends Node3D

enum RopeDisableMode {
	REMOVE = 0, ## StaticBody is removed from the physics world space when node [member process_mode] is set to disabled.
	KEEP_STATIC = 1 ## StaticBody is being kept in the physics world space when [member process_mode] is set to disabled.
}

## Emitted when mesh generation finishes.
signal generation_finished()

# visuals
var current_vis_instance_idx := 0
var vis_instance_rids: Array[RID]
var vis_instance_meshes: Array[ArrayMesh]
var scenario: RID

# physics
var current_phys_instance_idx := 0
var phys_instance_rids: Array[RID]
var phys_instance_shapes: Array[Shape3D]

@export_tool_button("Regenerate meshes") var manual_regen: Callable

@export var rope_data: RopeData:
	set = _set_rope_data

## Specifies how the collisions (if enabled) of the rope should behave when node's [member process_mode] changes during game runtime.
@export var disable_mode: RopeDisableMode = RopeDisableMode.REMOVE

func _enter_tree() -> void:
	scenario = get_world_3d().scenario

	# gameplay
	if not Engine.is_editor_hint():
		if not has_generated_mesh():
			_regen_meshes(rope_data)
		return
	
	# editor
	if rope_data != null:
		if not rope_data.changed.is_connected(_on_rope_data_changed):
			rope_data.changed.connect(_on_rope_data_changed)
		if not has_generated_mesh():
			_regen_meshes(rope_data)

func _exit_tree() -> void:
	_free_rs_instances()
	_free_ps_instances()

	# gameplay
	if not Engine.is_editor_hint():
		return

	# editor
	if rope_data != null and rope_data.changed.is_connected(_on_rope_data_changed):
		rope_data.changed.disconnect(_on_rope_data_changed)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DISABLED:
			_disable_physics_space()
		NOTIFICATION_ENABLED:
			_enable_physics_space()

	if not has_generated_mesh() or not Engine.is_editor_hint():
		return

	match what:
		NOTIFICATION_TRANSFORM_CHANGED:
			# _update_rs_instance_xforms(rope_data)
			_regen_meshes(rope_data)
		NOTIFICATION_VISIBILITY_CHANGED:
			_update_rs_instance_visibility(rope_data)

func _regen_meshes(data: RopeData) -> void:
	_free_rs_instances()
	_free_ps_instances()

	if data == null or data.points.size() < 2:
		return

	var points := data.points
	var points_size := points.size()

	if data.single_mesh:
		# origin point of a signle mesh is located at segment_points[0]

		#region Single mesh generation
		var segment_points := PackedVector3Array()
		var segment_normals := PackedVector3Array()
		var segment_t_values := PackedFloat32Array()

		for i in range(points_size - 1):
			var start_point := points[i]
			var end_point := points[i + 1]
			var dir := start_point.direction_to(end_point)
			var dist := start_point.distance_to(end_point)

			var rings := rope_data.ext_v_segments
			for j in range(rings):
				var t := float(j) / (rings - 1)
				segment_points.push_back(start_point + dir * dist * t)
				segment_t_values.push_back(t)

		segment_normals = _calculate_tangents(segment_points)
		var array_mesh := _extrude_along_points_path(global_basis, rope_data, segment_points, segment_normals, segment_t_values, points_size)

		_create_rs_instance(rope_data, array_mesh, global_transform)

		if data.use_collisions:
			var shape := _generate_shape(array_mesh, data.col_shape_type)
			_create_ps_instance(data, shape, global_transform)

		#endregion
	else:
		# origin points of multiple meshes are located at segment_points respectively
		#region Multiple meshes generation
		for i in range(points_size - 1):
			var segment_points := PackedVector3Array()
			var segment_normals := PackedVector3Array()
			var segment_t_values := PackedFloat32Array()

			var start_point := points[i]
			var end_point := points[i + 1]
			var dir := start_point.direction_to(end_point)
			var dist := start_point.distance_to(end_point)

			var rings := rope_data.ext_v_segments
			for j in range(rings):
				var t := float(j) / (rings - 1) 
				segment_points.push_back(start_point + dir * dist * t)
				segment_t_values.push_back(t)

			segment_normals = _calculate_tangents(segment_points)
			var array_mesh = _extrude_along_points_path(global_basis, rope_data, segment_points, segment_normals, segment_t_values, points_size, i)

			_create_rs_instance(rope_data, array_mesh, global_transform)

			if data.use_collisions:
				var shape := _generate_shape(array_mesh, data.col_shape_type)
				_create_ps_instance(data, shape, global_transform)
		#endregion

	generation_finished.emit()


#region Mesh generation internals
func _calculate_tangents(points: PackedVector3Array) -> PackedVector3Array:
	assert(points.size() >= 2, "Cannot calculate tangent normals for points array of size less than 2")

	var tangents := PackedVector3Array()
	var count := points.size()

	for i in range(count):
		var tangent: Vector3
		if i == 0:
			#tangent = (points[1] - points[0]).normalized()
			tangent = points[0].direction_to(points[1])
		elif i == count - 1:
			#tangent = (points[i] - points[i - 1]).normalized()
			tangent = points[i - 1].direction_to(points[i])
		else:
			#tangent = (points[i + 1] - points[i - 1]).normalized()
			tangent = points[i - 1].direction_to(points[i + 1])

		tangents.push_back(tangent)
	
	return tangents

func _calculate_cumulative_distances(points: PackedVector3Array) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var cumulative := 0.0
	var count := points.size()

	distances.push_back(0.0)

	for i in range(1, count):
		var segment_length := points[i].distance_to(points[i - 1])
		cumulative += segment_length
		distances.push_back(cumulative)

	return distances

func _generate_lod_indices(ring_count: int, p_segments: int, ring_step: int, segment_step: int) -> PackedInt32Array:
	var indices := PackedInt32Array()
	var verts_per_ring := p_segments + 1

	var ring_idx := 0
	while ring_idx < ring_count - 1:
		var next_ring_idx := mini(ring_idx + ring_step, ring_count - 1)

		var seg_idx := 0
		while seg_idx < p_segments:
			var next_seg_idx := mini(seg_idx + segment_step, p_segments)

			var curr_start := ring_idx * verts_per_ring
			var next_start := next_ring_idx * verts_per_ring

			var bl = curr_start + seg_idx
			var br = curr_start + next_seg_idx
			var tl = next_start + seg_idx
			var tr = next_start + next_seg_idx

			indices.append_array([
				bl, br, tl, 
				br, tr, tl
			])

			seg_idx += segment_step

		ring_idx += ring_step

	return indices

func _extrude_along_points_path(
	p_node_basis: Basis,
	p_rope_data: RopeData,
	p_points: PackedVector3Array, 
	p_normals: PackedVector3Array,
	p_t_values: PackedFloat32Array,
	p_hooks_count: int,
	p_segment_index: int = -1,
) -> ArrayMesh:
	#region ====== 0. Data gathering & assertions ======
	assert(p_points.size() == p_normals.size(), "Points and normals array must have the same size")
	assert(p_points.size() == p_t_values.size(), "Points and t_values array must have the same size")
	assert(p_points.size() >= 2, "At least 2 points are needed")

	var p_sag_offset := rope_data.sag_offset
	var p_sag_keep_local := rope_data.sag_keep_local_space
	var p_radius := rope_data.ext_radius
	var p_u_segments := rope_data.ext_u_segments
	var p_v_segments := rope_data.ext_v_segments
	var p_material := rope_data.material
	var p_uv_translate := rope_data.tex_uv_translation
	var p_uv_scale := rope_data.tex_uv_scale
	var p_uv_rot_origin := rope_data.tex_uv_rotation_origin
	var p_uv_rot_angle_deg := rope_data.tex_uv_rotation_angle_degrees
	var p_lod1_dist := rope_data.lod_level1_distance
	var p_lod2_dist := rope_data.lod_level2_distance
	var p_lod3_dist := rope_data.lod_level3_distance
	#endregion

	#region ====== 1. Ring frames matrices construction ======
	var frames: Array[Basis] = []

	var forward := p_normals[0].normalized()
	var up := Vector3.UP

	if abs(forward.dot(up)) > 0.99:
		up = Vector3.FORWARD

	var right = forward.cross(up).normalized()
	up = right.cross(forward).normalized()

	frames.push_back(Basis(right, up, forward))

	var ring_count := p_points.size()
	for i in range(1, ring_count):
		var prev_forwad := p_normals[i - 1].normalized()
		var curr_forward := p_normals[i].normalized()

		var prev_right := frames[i - 1].x
		var prev_up := frames[i - 1].y

		var rot_axis := prev_forwad.cross(curr_forward)

		if rot_axis.length_squared() > 0.0001:
			rot_axis = rot_axis.normalized()
			var rot_angle := prev_forwad.angle_to(curr_forward)
			var rot := Basis(rot_axis, rot_angle)

			var new_right := (rot * prev_right).normalized()
			var new_up := (rot * prev_up).normalized()

			frames.push_back(Basis(new_right, new_up, curr_forward))
		else:
			frames.push_back(Basis(prev_right, prev_up, curr_forward))
	#endregion

	#region ====== 2. Vertex data construction ======
	var vertices_arr := PackedVector3Array()
	var normals_arr := PackedVector3Array()
	var uvs_arr := PackedVector2Array()
	var colors_arr := PackedColorArray()
	var distances := _calculate_cumulative_distances(p_points)

	var uv_angle := deg_to_rad(p_uv_rot_angle_deg)
	var cos_uv_rot := cos(uv_angle)
	var sin_uv_rot := sin(uv_angle)
	var current_hook := 0.0

	for ring_idx in range(ring_count):
		var center := p_points[ring_idx]
		var frame := frames[ring_idx]
		var frame_right := frame.x
		var frame_up := frame.y

		var v := (p_t_values[ring_idx] * float(p_v_segments - 1))
		var t := p_t_values[ring_idx]

		var anim_offset: float

		if p_segment_index == -1:
			# no index passed, single mesh - infer the animation offset from t_values
			current_hook += floorf(p_t_values[maxi(ring_idx - 1, 0)])
			anim_offset = current_hook / float(p_hooks_count)
		else:
			anim_offset = (current_hook + float(p_segment_index)) / float(p_hooks_count)

		var sag_factor := sin(t * PI)

		# vertex colors:
		# red = how far from the hook is current vertex, or - how much affected by the wind forces the rope is at this place
		# green = segment/mesh based offset, to break unison movement
		var ring_color := Color(sag_factor, anim_offset, 0.0, 0.0)

		var verts_per_ring := p_u_segments + 1
		for i in range(verts_per_ring):
			var angle := float(i) / p_u_segments * TAU
			var cos_a := cos(angle)
			var sin_a := sin(angle)

			var offset := (frame_right * cos_a + frame_up * sin_a) * p_radius
			var sag_offset := p_sag_offset * sag_factor if p_sag_keep_local else p_node_basis.inverse() * p_sag_offset * sag_factor
			var vertex_pos := center + offset + sag_offset
			var vertex_normal = offset.normalized()
			var u = (float(i) / p_u_segments)

			var uv := Vector2(u, v)

			# first - scale and translate UV in local space
			var xformed_uv = (
				Transform2D()
					.scaled(p_uv_scale)
					.translated(p_uv_translate)
			) * uv

			# then - rotate around the specified global space origin point
			# avoids non-uniform scale skewing issues arising when doing this in one step
			xformed_uv = (
				Transform2D()
					.translated(-p_uv_rot_origin)
					.rotated(uv_angle)
					.translated(p_uv_rot_origin)
			) * xformed_uv

			vertices_arr.push_back(vertex_pos)
			normals_arr.push_back(vertex_normal)
			uvs_arr.push_back(xformed_uv)
			colors_arr.push_back(ring_color)
	#endregion

	#region ====== 3. ImporterMesh creation ======
	var importer_mesh := ImporterMesh.new()
	var indices_lod0 := _generate_lod_indices(ring_count, p_u_segments, 1, 1)

	var base_arrays = []
	base_arrays.resize(Mesh.ARRAY_MAX)
	base_arrays[Mesh.ARRAY_VERTEX] = vertices_arr
	base_arrays[Mesh.ARRAY_NORMAL] = normals_arr
	base_arrays[Mesh.ARRAY_TEX_UV] = uvs_arr;
	base_arrays[Mesh.ARRAY_COLOR] = colors_arr;
	base_arrays[Mesh.ARRAY_INDEX] = indices_lod0

	var indices_lod1 := _generate_lod_indices(ring_count, p_u_segments, 2, 2)
	var indices_lod2 := _generate_lod_indices(ring_count, p_u_segments, 4, 4)
	var indices_lod3 := _generate_lod_indices(ring_count, p_u_segments, 8, 8)

	var lods := {}
	lods[p_lod1_dist] = indices_lod1
	lods[p_lod2_dist] = indices_lod2
	lods[p_lod3_dist] = indices_lod3

	importer_mesh.add_surface(
		Mesh.PRIMITIVE_TRIANGLES, 
		base_arrays, 
		[], 
		lods, 
		p_material, 
		"RopeSurface", 
		Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
	)
	
	#endregion

	var array_mesh := importer_mesh.get_mesh()

	return array_mesh

#endregion

#region RenderingServer instance methods
func _create_rs_instance(rope_data: RopeData, mesh: ArrayMesh, xform: Transform3D) -> void:
	var rs := RenderingServer
	var instance_rid = rs.instance_create()

	rs.instance_set_base(instance_rid, mesh.get_rid())
	rs.instance_set_scenario(instance_rid, scenario)
	rs.instance_set_transform(instance_rid, xform)
	rs.instance_set_visible(instance_rid, visible)
	rs.instance_set_layer_mask(instance_rid, rope_data.visibility_layers)
	rs.instance_geometry_set_lod_bias(instance_rid, rope_data.lod_bias)
	rs.instance_geometry_set_cast_shadows_setting(instance_rid, rs.SHADOW_CASTING_SETTING_ON)

	rs.instance_teleport(instance_rid)

	vis_instance_rids.push_back(instance_rid)
	vis_instance_meshes.push_back(mesh)
	current_vis_instance_idx += 1

func _update_rs_instance_xforms(rope_data: RopeData) -> void:
	var rs := RenderingServer
	var i := 0

	while i < current_vis_instance_idx:
		var rid := vis_instance_rids[i]
		rs.instance_set_transform(rid, global_transform)
		i += 1

func _update_rs_instance_visibility(rope_data: RopeData) -> void:
	var rs := RenderingServer
	var i := 0

	while i < current_vis_instance_idx:
		var rid := vis_instance_rids[i]
		rs.instance_set_visible(rid, visible)
		i += 1

func _free_rs_instances() -> void:
	for rid in vis_instance_rids:
		RenderingServer.free_rid(rid)
	
	vis_instance_rids.clear()
	vis_instance_meshes.clear()
	current_vis_instance_idx = 0
#endregion

#region PhysicsServer instance methods
func _generate_shape(mesh: ArrayMesh, type: RopeData.ColShapeType) -> Shape3D:
	match type:
		RopeData.ColShapeType.TRIMESH:
			return mesh.create_trimesh_shape()
		RopeData.ColShapeType.SINGLE_CONVEX:
			return mesh.create_convex_shape(true, false)
		RopeData.ColShapeType.SIMPLIFIED_CONVEX:
			return mesh.create_convex_shape(true, true)
		_:
			return mesh.create_trimesh_shape()

func _disable_physics_space() -> void:
	var ps := PhysicsServer3D

	for body_rid in phys_instance_rids:
		if disable_mode == RopeDisableMode.REMOVE:
			if is_inside_tree(): ps.body_set_space(body_rid, RID())

func _enable_physics_space() -> void:
	var ps := PhysicsServer3D

	for body_rid in phys_instance_rids:
		if disable_mode == RopeDisableMode.REMOVE:
			if is_inside_tree(): ps.body_set_space(body_rid, get_world_3d().space)

func _create_ps_instance(rope_data: RopeData, shape: Shape3D, xform: Transform3D) -> void:
	var ps := PhysicsServer3D
	var body_rid := ps.body_create()

	ps.body_set_mode(body_rid, PhysicsServer3D.BODY_MODE_STATIC)
	ps.body_set_space(body_rid, get_world_3d().space)
	ps.body_add_shape(body_rid, shape.get_rid())
	ps.body_set_collision_layer(body_rid, rope_data.col_collision_layer)
	ps.body_set_collision_mask(body_rid, rope_data.col_collision_mask)
	ps.body_set_state(body_rid, PhysicsServer3D.BODY_STATE_TRANSFORM, xform)

	phys_instance_rids.push_back(body_rid)
	phys_instance_shapes.push_back(shape)
	current_phys_instance_idx += 1

func _free_ps_instances() -> void:
	for rid in phys_instance_rids:
		PhysicsServer3D.free_rid(rid)

	phys_instance_rids.clear()
	phys_instance_shapes.clear()
	current_phys_instance_idx = 0
#endregion

func _set_rope_data(value) -> void:
	if Engine.is_editor_hint() \
	and rope_data != null \
	and rope_data.changed.is_connected(_on_rope_data_changed):
		rope_data.changed.disconnect(_on_rope_data_changed)
	
	rope_data = value

	if Engine.is_editor_hint():
		manual_regen = func(): _regen_meshes(rope_data) if rope_data else null
	
		if rope_data != null:
			if not rope_data.changed.is_connected(_on_rope_data_changed):
				rope_data.changed.connect(_on_rope_data_changed)
			if is_inside_tree():
				_regen_meshes(rope_data)
		else:
			_free_rs_instances()

func _on_rope_data_changed() -> void:
	if Engine.is_editor_hint():
		update_gizmos()
	if rope_data != null and is_inside_tree():
		_regen_meshes(rope_data)

# public api
func has_generated_mesh() -> bool:
	return rope_data != null and not vis_instance_rids.is_empty()

## Calculates 3d point in global coordinates which will be placed at given index point of [member rope_data], 
## interpolated by the [member factor] to the next index, point will be affected by sag factor.
## Use it when you want to spawn things "on" the rope.
func calculate_global_point_at(rope_point_idx: int, factor: float) -> Vector3:
	if rope_data == null or rope_data.points.is_empty():
		return Vector3.ZERO
	
	var points := rope_data.points
	var points_size := points.size()
	
	rope_point_idx = clampi(rope_point_idx, 0, points_size - 1)
	factor = clampf(factor, 0.0, 1.0)
	
	# if at the last point or factor is 0, return the point at index
	if rope_point_idx >= points_size - 1 or factor == 0.0:
		var point := points[rope_point_idx]
		var sag_factor := 0.0 if rope_point_idx == 0 or rope_point_idx == points_size - 1 else 1.0
		var sag_offset := rope_data.sag_offset * sag_factor if rope_data.sag_keep_local_space else global_basis.inverse() * rope_data.sag_offset * sag_factor
		return global_transform * (point + sag_offset)
	
	var start_point := points[rope_point_idx]
	var end_point := points[rope_point_idx + 1]
	var interpolated_point := start_point.lerp(end_point, factor)
	
	var t := (float(rope_point_idx) + factor) / float(points_size - 1)
	var sag_factor := sin(t * PI)
	
	var sag_offset := rope_data.sag_offset * sag_factor if rope_data.sag_keep_local_space else global_basis.inverse() * rope_data.sag_offset * sag_factor
	
	return global_transform * (interpolated_point + sag_offset)
