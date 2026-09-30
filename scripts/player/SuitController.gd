class_name SuitController
extends Node

enum SuitForm { NO_SUIT, ROBOCOP_TACTICAL, IRON_MAN_FLIGHT, SILVER_SURFER_COSMIC, MEKA_HEAVY }

@export var active_form: SuitForm = SuitForm.NO_SUIT
@export var player_body_path: NodePath

var player_body: CharacterBody3D

func _ready() -> void:
	if not player_body_path.is_empty():
		player_body = get_node_or_null(player_body_path) as CharacterBody3D

func set_suit_form(new_form: SuitForm) -> void:
	active_form = new_form
	match active_form:
		SuitForm.ROBOCOP_TACTICAL:
			_apply_tactical_physics()
		SuitForm.IRON_MAN_FLIGHT:
			_apply_flight_physics()
		SuitForm.SILVER_SURFER_COSMIC:
			_apply_cosmic_physics()
		SuitForm.MEKA_HEAVY:
			_apply_meka_physics()

func _apply_tactical_physics() -> void:
	if player_body:
		player_body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED

func _apply_flight_physics() -> void:
	if player_body:
		player_body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func _apply_cosmic_physics() -> void:
	if player_body:
		player_body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING

func _apply_meka_physics() -> void:
	if player_body:
		player_body.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
