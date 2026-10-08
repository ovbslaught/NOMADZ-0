class_name State
extends Node

# Strict typing for the entity that owns this state (e.g., the Player or an Enemy)
# We use CharacterBody3D for standard kinematic physics.
var entity: CharacterBody3D
var state_machine: Node

# Initialize the state with its dependencies.
# This prevents "null instance" crashes later in the pipeline.
func setup(parent_entity: CharacterBody3D, parent_machine: Node) -> void:
	entity = parent_entity
	state_machine = parent_machine
	assert(entity != null, "State initialized without an Entity!")
	assert(state_machine != null, "State initialized without a StateMachine!")

# Called when entering the state (e.g., play 'Idle' animation)
func enter() -> void:
	pass

# Called when exiting the state (e.g., cleanup timers)
func exit() -> void:
	pass

# Corresponds to _process
func update(_delta: float) -> State:
	return null

# Corresponds to _physics_process
func physics_update(_delta: float) -> State:
	return null

# Corresponds to _input
func handle_input(_event: InputEvent) -> State:
	return null
