extends CharacterBody3D

## NOMADZ SUIT MESH CONTROLLER v1.0
## Targeted for 'Sol' - Retro Future Open World

@export_group("Locomotion")
@export var base_speed: float = 6.0
@export var sprint_multiplier: float = 2.0
@export var rotation_speed: float = 12.0
@export var air_control: float = 0.4

@onready var anim_tree = $AnimationTree
@onready var camera_pivot = get_node("/root/Main/MultiCam/Pivot")

func _physics_process(delta):
    var input_dir = Input.get_vector("move_left", "move_right", "move_fwd", "move_back")
    var direction = (camera_pivot.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    if direction:
        # Align mesh rotation with movement direction
        var target_rotation = atan2(direction.x, direction.z)
        rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
        
        var speed = base_speed * (sprint_multiplier if Input.is_action_pressed("sprint") else 1.0)
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, base_speed)
        velocity.z = move_toward(velocity.z, 0, base_speed)

    # Animation Hook: Locomotion BlendSpace2D
    anim_tree.set("parameters/locomotion/blend_position", velocity.length() / (base_speed * sprint_multiplier))
    
    move_and_slide()
