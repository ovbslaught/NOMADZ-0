extends Node

# ProControllerManager handles Nintendo Switch Pro controller inputs and maps them to game actions.

# Input action mapping
const ACTION_JUMP = "jump"
const ACTION_SPRINT = "sprint"
const ACTION_TRANSFORM = "transform"
const ACTION_URIDIAN_FLIP = "uridium_flip"
const ACTION_MOVE_LEFT = "move_left"
const ACTION_MOVE_RIGHT = "move_right"

# Define the input mapping for Pro controller buttons
const BUTTON_A = "ui_accept"
const BUTTON_B = "ui_cancel"
const BUTTON_L = "move_left"
const BUTTON_R = "move_right"

func _ready():
    # Set up input processing
    Input.map_action(ACTION_JUMP, BUTTON_A)
    Input.map_action(ACTION_SPRINT, BUTTON_B)
    Input.map_action(ACTION_TRANSFORM, BUTTON_L)
    Input.map_action(ACTION_URIDIAN_FLIP, BUTTON_R)

func _process(delta):
    # Check for input actions and handle them
    if Input.is_action_just_pressed(ACTION_JUMP):
        jump()
    if Input.is_action_pressed(ACTION_SPRINT):
        sprint()
    if Input.is_action_just_pressed(ACTION_TRANSFORM):
        transform()
    if Input.is_action_just_pressed(ACTION_URIDIAN_FLIP):
        uridium_flip()

    # Handle movement
    var direction = Vector2.ZERO
    if Input.is_action_pressed(ACTION_MOVE_LEFT):
        direction.x -= 1
    if Input.is_action_pressed(ACTION_MOVE_RIGHT):
        direction.x += 1
    move_player(direction)

func jump():
    print("Jump action triggered.")
    # Add jump logic here

func sprint():
    print("Sprint action triggered.")
    # Add sprint logic here

func transform():
    print("Transform action triggered.")
    # Add transform logic here

func uridium_flip():
    print(" Uridium flip action triggered.")
    # Add uridium flip logic here

func move_player(direction):
    # Logic for moving the player character
    if direction != Vector2.ZERO:
        print("Moving player in direction: " + str(direction))
