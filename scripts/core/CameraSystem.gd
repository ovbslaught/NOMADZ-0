# NOMADZ-0 :: CameraSystem.gd
# Third-person follow cam with retro scanline bob
# Modes: helmet_fp | over_shoulder | wide_third | editor_flycam
extends Node3D
class_name CameraSystem

@export var target: Node3D
@export var distance: float = 5.0
@export var height: float = 2.0
@export var bob_amplitude: float = 0.1

enum Mode { HELMET_FP, OVER_SHOULDER, WIDE_THIRD, EDITOR_FLYCAM }
@export var mode: Mode = Mode.WIDE_THIRD

var bob_time: float = 0.0
@onready var spring_arm: SpringArm3D = $SpringArm3D

func _process(delta: float) -> void:
	if not target:
		return
	bob_time += delta
	var bob_offset := Vector3(
		sin(bob_time * 4.0) * bob_amplitude,
		sin(bob_time * 2.0) * bob_amplitude * 0.5,
		0.0
	)
	match mode:
		Mode.WIDE_THIRD:
			global_position = target.global_position + Vector3(0, height, distance) + bob_offset
			look_at(target.global_position, Vector3.UP)
		Mode.OVER_SHOULDER:
			global_position = target.global_position + Vector3(0.6, height * 0.8, distance * 0.6) + bob_offset
			look_at(target.global_position + Vector3(0, 0.5, 0), Vector3.UP)
		Mode.HELMET_FP:
			global_position = target.global_position + Vector3(0, 1.7, 0)
			global_rotation = target.global_rotation
		Mode.EDITOR_FLYCAM:
			pass  # Free camera handled by EditorFlycam addon

func set_mode(new_mode: Mode) -> void:
	mode = new_mode
