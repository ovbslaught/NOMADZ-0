# NOMADZ-0 :: DebugTools.gd
# Console overlay — FPS, velocity, state, Director tension
extends CanvasLayer
class_name DebugTools

@onready var label: Label = $DebugLabel
@onready var director_label: Label = $DirectorLabel

var show_debug: bool = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		show_debug = !show_debug
		visible = show_debug

	if not show_debug:
		return

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var vel_len := player.velocity.length() if player else 0.0
	label.text = "FPS: %d | vel: %.2f | state: %s" % [
		Engine.get_frames_per_second(),
		vel_len,
		"active"
	]

	# Hook Director.gd tension display
	var director := get_node_or_null("/root/Director")
	if director:
		director_label.text = "Tension: %.2f | Loot: x%.1f" % [
			director.session_tension,
			director.loot_modifier
		]
