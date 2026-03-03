extends Node3D

## NOMADZ VOXEL HAMMER v1.0
## Pillar 26: Computational Tools (Destruction Sub-module)

@export var excavate_radius: float = 2.5
@onready var terrain = get_node("/root/Main/VoxelTerrain")

func punch_hole(impact_point: Vector3):
	# Convert world position to voxel local position
	var local_pos = terrain.to_local(impact_point)
	
	# Execute spherical subtraction
	# Mode 0 = Subtract/Remove
	terrain.get_storage().edit_sphere(local_pos, excavate_radius, 0)
	
	# Trigger "Voxel Deletion" VFX
	spawn_deletion_particles(impact_point)
	print("NOMADZ: Terrain Deletion at ", impact_point)

func spawn_deletion_particles(pos: Vector3):
	# Instance retro-pixel particle effect here
	pass
