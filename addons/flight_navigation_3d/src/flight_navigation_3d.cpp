#include "flight_navigation_3d.h"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void SVO::_bind_methods() {}

void FlightNavigation3D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("build_navigation"), &FlightNavigation3D::build_navigation);
	ClassDB::bind_method(D_METHOD("set_sparse_voxel_octree", "svo"), &FlightNavigation3D::set_sparse_voxel_octree);
	ClassDB::bind_method(D_METHOD("get_sparse_voxel_octree"), &FlightNavigation3D::get_sparse_voxel_octree);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "sparse_voxel_octree", PROPERTY_HINT_RESOURCE_TYPE, "SVO"),
			"set_sparse_voxel_octree", "get_sparse_voxel_octree");

	ADD_SIGNAL(MethodInfo("progress",
			PropertyInfo(Variant::INT, "step"),
			PropertyInfo(Variant::OBJECT, "svo"),
			PropertyInfo(Variant::INT, "work_completed"),
			PropertyInfo(Variant::INT, "total_work")));

	BIND_ENUM_CONSTANT(GET_ALL_VOXELIZATION_TARGET);
	BIND_ENUM_CONSTANT(BUILD_MESH);
	BIND_ENUM_CONSTANT(REMOVE_THIN_TRIANGLES);
	BIND_ENUM_CONSTANT(OFFSET_VERTICES_TO_LOCAL_COORDINATE);
	BIND_ENUM_CONSTANT(DETERMINE_ACTIVE_LAYER_1_NODES);
	BIND_ENUM_CONSTANT(CONSTRUCT_SVO);
	BIND_ENUM_CONSTANT(SOLID_VOXELIZATION);
	BIND_ENUM_CONSTANT(HIERARCHICAL_INSIDE_OUTSIDE_PROPAGATION);
	BIND_ENUM_CONSTANT(YZ_PLANE_RASTERIZATION);
	BIND_ENUM_CONSTANT(PREPARE_FLAGS_AND_HEAD_NODES);
	BIND_ENUM_CONSTANT(XP_BIT_FLIP_PROPAGATION);
	BIND_ENUM_CONSTANT(PREPARE_FLIP_FLAG_LAYER_1);
	BIND_ENUM_CONSTANT(FLIP_BOTTOM_UP_LAYER_1);
	BIND_ENUM_CONSTANT(PROPAGATE_FLIP_INFORMATION_LAYER_1);
	BIND_ENUM_CONSTANT(PREPARE_FLIP_FLAG_FROM_LAYER_2);
	BIND_ENUM_CONSTANT(FLIP_BOTTOM_UP_FROM_LAYER_2);
	BIND_ENUM_CONSTANT(PROPAGATE_FLIP_INFORMATION_FROM_LAYER_2);
	BIND_ENUM_CONSTANT(PROPAGATE_INSIDE_FLAGS_TOPDOWN_FOR_TREE_NODES);
	BIND_ENUM_CONSTANT(PROPAGATE_INSIDE_FLAGS_TO_SUBGRID_VOXELS);
	BIND_ENUM_CONSTANT(SURFACE_VOXELIZATION);
	BIND_ENUM_CONSTANT(CALCULATE_COVERAGE_FACTOR);
	BIND_ENUM_CONSTANT(MAX_STEP);
}

void FlightNavigation3D::set_sparse_voxel_octree(const Ref<SVO> &p_svo) {
	sparse_voxel_octree = p_svo;
}

Ref<SVO> FlightNavigation3D::get_sparse_voxel_octree() const {
	return sparse_voxel_octree;
}

Ref<SVO> FlightNavigation3D::build_navigation() {
	// TODO: real pipeline. For now: walk MAX_STEP emitting progress so the
	// existing voxelize_button.gd dialog has something real to render,
	// and return a (currently empty) SVO so callers don't null-deref.
	if (sparse_voxel_octree.is_null()) {
		sparse_voxel_octree.instantiate();
	}
	for (int step = 0; step < ProgressStep::MAX_STEP; step++) {
		emit_signal("progress", step, sparse_voxel_octree, 1, 1);
	}
	return sparse_voxel_octree;
}
