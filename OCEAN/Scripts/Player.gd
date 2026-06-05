extends CharacterBody2D

const SPEED = 160.0
const JUMP_VELOCITY = -320.0
const DASH_SPEED = 450.0
const DASH_DURATION = 0.2

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var can_double_jump = false
var is_dashing = false
var dash_timer = 0.0
var facing_right = true

@onready var sprite = $Sprite2D
@onready var copilot = $MotherBrainCopilot

func _physics_process(delta):
    if is_dashing:
        dash_timer -= delta
        if dash_timer <= 0:
            is_dashing = false
        move_and_slide()
        return

    # Add the gravity.
    if not is_on_floor():
        velocity.y += gravity * delta
    else:
        can_double_jump = true

    # Handle Jump.
    if ProControllerManager.get_controller_input("ui_accept") > 0.5:
        if is_on_floor():
            velocity.y = JUMP_VELOCITY
            copilot.log_action("Thrusters engaged.")
        elif GameManager.has_double_jump and can_double_jump:
            velocity.y = JUMP_VELOCITY * 0.85
            can_double_jump = false
            copilot.log_action("Phase jump executed.")

    # Handle Dash
    if ProControllerManager.get_controller_input("dash") > 0.5 and GameManager.has_dash:
        is_dashing = true
        dash_timer = DASH_DURATION
        velocity.y = 0
        velocity.x = DASH_SPEED if facing_right else -DASH_SPEED
        copilot.log_action("Vector dash active.")
        return

    # Get the input direction and handle the movement/deceleration.
    var direction = ProControllerManager.get_controller_input("ui_right") - ProControllerManager.get_controller_input("ui_left")
    if direction:
        velocity.x = direction * SPEED
        facing_right = direction > 0
        sprite.flip_h = !facing_right
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    move_and_slide()
