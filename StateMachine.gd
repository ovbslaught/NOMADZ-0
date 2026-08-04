class_name StateMachine
extends Node

signal state_changed(current_state_name: String)

@export var initial_state: State

var current_state: State
var states: Dictionary = {}

func _ready() -> void:
	await owner.ready
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.transitioned.connect(_on_child_transition)
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func _on_child_transition(state: State, new_state_name: String) -> void:
	if state != current_state:
		return
		
	var new_state: State = states.get(new_state_name.to_lower())
	if not new_state:
		push_error("StateMachine Error: State '%s' does not exist." % new_state_name)
		return
		
	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state
	state_changed.emit(current_state.name)
