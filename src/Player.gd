extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

func _physics_process(delta: float) -> void:
    # Trigger the Uridium Flip on spacebar / accept
    if Input.is_action_just_pressed("ui_accept"):
        perform_uridium_flip()

func perform_uridium_flip() -> void:
    print("Executing Uridium Flip!")
    var payload = {
        "action": "uridium_flip",
        "mana_cost": 15,
        "position": {"x": position.x, "y": position.y, "z": position.z}
    }
    # Fire the event to the Termux gossip daemon
    GameCoordinator.emit_civ_event("player_action", payload)
