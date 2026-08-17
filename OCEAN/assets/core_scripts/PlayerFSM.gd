# NOMADZ-0 :: PlayerFSM.gd
# Finite State Machine for PlayerController
extends Node
class_name PlayerFSM

var owner_body: CharacterBody3D
var state: String = "idle"

signal state_changed(from: String, to: String)

func bind_owner(body: CharacterBody3D) -> void:
	owner_body = body

func transition_to(next_state: String) -> void:
	if state == next_state:
		return
	emit_signal("state_changed", state, next_state)
	state = next_state

func tick(delta: float) -> void:
	# Director.gd can hook here for AI pacing
	pass
