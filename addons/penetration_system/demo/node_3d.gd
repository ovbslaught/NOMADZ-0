extends Node3D

# NOTE: If you're using camera_3d to get direction, ray_cast_3d is not needed
#@onready var camera_3d: Camera3D = %Camera3D
# NOTE: If you're using ray_cast_3d to get direction, camera_3d is not needed
@onready var ray_cast_3d: RayCast3D = %RayCast3D
# Alternatively, you can remove both and use get_raycast_global_direction(p_ray_cast_3d : RayCast3D)

func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		#NOTE: Get direction by mouse position
		#var direction : Vector3 = camera_3d.project_ray_normal(get_viewport().get_mouse_position())
		#NOTE: Get direction by RayCast direction
		var direction : Vector3 = PenetrationSystem.get_raycast_global_direction(ray_cast_3d)
		
		#NOTE: Uncomment this block to display the time spent processing
		#var start: int = Time.get_ticks_usec()
		
		var data : Array[HitResult] = G_PenetrationSystem.fire_bullet(ray_cast_3d.global_transform.origin, direction, 4, G_PenetrationSystem.penetration_data)
		
		for i in data as Array[HitResult]:
			printt(i.normal, i.collider, i.damage, i.penetration_index)
		
		#var end: int = Time.get_ticks_usec()
		#print("usecs taken: " + str(end - start))
