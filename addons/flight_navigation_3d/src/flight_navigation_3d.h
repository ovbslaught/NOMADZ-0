#pragma once

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

// NOTE: this is a real, compilable GDExtension skeleton, not a full
// voxelizer. It wires up exactly what the existing GDScript side
// (voxelize_button.gd, flight_navigation_3d_editor_plugin.gd) already
// calls: the ProgressStep enum, the `progress` signal, the
// `sparse_voxel_octree` property, and an async-shaped `build_navigation()`.
// The actual voxelization/SVO math (steps below) are TODOs.

namespace godot {

class SVO : public Resource {
	GDCLASS(SVO, Resource)

protected:
	static void _bind_methods();

public:
	SVO() = default;
};

class FlightNavigation3D : public Node3D {
	GDCLASS(FlightNavigation3D, Node3D)

public:
	enum ProgressStep {
		GET_ALL_VOXELIZATION_TARGET,
		BUILD_MESH,
		REMOVE_THIN_TRIANGLES,
		OFFSET_VERTICES_TO_LOCAL_COORDINATE,
		DETERMINE_ACTIVE_LAYER_1_NODES,
		CONSTRUCT_SVO,
		SOLID_VOXELIZATION,
		HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION,
		YZ_PLANE_RASTERIZATION,
		PREPARE_FLAGS_AND_HEAD_NODES,
		XP_BIT_FLIP_PROPAGATION,
		PREPARE_FLIP_FLAG_LAYER_1,
		FLIP_BOTTOM_UP_LAYER_1,
		PROPAGATE_FLIP_INFORMATION_LAYER_1,
		PREPARE_FLIP_FLAG_FROM_LAYER_2,
		FLIP_BOTTOM_UP_FROM_LAYER_2,
		PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2,
		PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES,
		PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS,
		SURFACE_VOXELIZATION,
		CALCULATE_COVERAGE_FACTOR,
		MAX_STEP
	};

private:
	Ref<SVO> sparse_voxel_octree;

protected:
	static void _bind_methods();

public:
	FlightNavigation3D() = default;

	void set_sparse_voxel_octree(const Ref<SVO> &p_svo);
	Ref<SVO> get_sparse_voxel_octree() const;

	// Called by voxelize_button.gd as: `await flight_navigation_3d_scene.build_navigation()`
	// TODO: replace the stub body with real voxelization; emit `progress`
	// for each ProgressStep as work completes (step, svo, work_completed, total_work)
	// matching what voxelize_button.gd's _on_progress() already expects.
	Ref<SVO> build_navigation();
};

} // namespace godot

VARIANT_ENUM_CAST(godot::FlightNavigation3D::ProgressStep);
