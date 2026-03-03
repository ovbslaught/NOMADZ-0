extends Node3D

## NOMADZ SUIT STATE SENSOR v1.0
## Environmental Detection for OceanFFT and Terrain3D

@onready var ground_ray = $GroundRay
@onready var water_ray = $WaterRay
@onready var player = get_parent()

func _physics_process(_delta):
	check_water_transition()

func check_water_transition():
	if water_ray.is_colliding():
		var collider = water_ray.get_collider()
		if collider.is_in_group("water"):
			if player.current_state != player.State.SWIM:
				player.current_state = player.State.SWIM
				trigger_water_vfx()
	elif player.is_on_floor():
		if player.current_state == player.State.SWIM:
			player.current_state = player.State.WALK

func trigger_water_vfx():
	# Hook for signalverse_water.gdshader splash effects
	print("NOMADZ: Entering Water. Shader Displacement Active.")
