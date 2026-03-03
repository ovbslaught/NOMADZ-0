extends Node

## NOMADZ WARP DRIVE v1.0
## Pillar 05 & 06: Astronomical Navigation

func initiate_warp(new_seed: int):
	print("NOMADZ: Folding Space-Time. New Seed: ", new_seed)
	# Clear existing Terrain3D data
	# Regenerate using FastNoiseLite and Zylann Voxel Tools
	# Update Visor HUD with new celestial coordinates
	get_tree().call_group("World", "regenerate_from_seed", new_seed)
