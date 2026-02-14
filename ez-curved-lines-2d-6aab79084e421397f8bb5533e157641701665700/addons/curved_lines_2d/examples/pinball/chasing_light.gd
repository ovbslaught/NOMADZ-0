extends CharacterBody2D

@onready var navigation_agent := $NavigationAgent2D

func _ready():
	set_physics_process(false)
	call_deferred("on_nav_serv_ready")


func on_nav_serv_ready():
	await get_tree().physics_frame
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	var pinball = get_tree().get_first_node_in_group("pinballs")
	if not is_instance_valid(pinball):
		return
	var target_pos : Vector2 = pinball.position
	navigation_agent.target_position = target_pos
	var current_agent_position = global_position
	var next_path_position = navigation_agent.get_next_path_position()
	velocity = current_agent_position.direction_to(next_path_position) * 600
	navigation_agent.set_velocity_forced(velocity)
	move_and_slide()

