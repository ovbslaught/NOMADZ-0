class_name DynamicAnimationTreeController
extends Node

@export var animation_tree_path: NodePath
@export var suit_controller_path: NodePath

var animation_tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback

const PARAM_GROUND_LOCOMOTION = "parameters/GroundLocomotion/blend_position"
const PARAM_COSMIC_GLIDING = "parameters/CosmicGliding/blend_position"
const PARAM_POWERED_FLIGHT = "parameters/PoweredFlight/blend_position"
const PARAM_MECH_LOCOMOTION = "parameters/MechLocomotion/blend_position"
const PARAM_STATE_TRAVEL = "parameters/playback"

func _ready() -> void:
	if not animation_tree_path.is_empty():
		animation_tree = get_node_or_null(animation_tree_path) as AnimationTree
		if animation_tree:
			animation_tree.active = true
			playback = animation_tree.get(PARAM_STATE_TRAVEL) as AnimationNodeStateMachinePlayback

func update_ground_locomotion(strafe: float, forward: float) -> void:
	if animation_tree:
		animation_tree.set(PARAM_GROUND_LOCOMOTION, Vector2(strafe, forward))

func update_cosmic_gliding(carve_lean: float, pitch_angle: float) -> void:
	if animation_tree:
		animation_tree.set(PARAM_COSMIC_GLIDING, Vector2(carve_lean, pitch_angle))

func update_powered_flight(roll_bank: float, pitch_thrust: float) -> void:
	if animation_tree:
		animation_tree.set(PARAM_POWERED_FLIGHT, Vector2(roll_bank, pitch_thrust))

func transition_to_state(state_name: String) -> void:
	if playback:
		playback.travel(state_name)
