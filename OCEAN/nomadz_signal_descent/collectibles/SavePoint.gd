## SavePoint.gd
## Area2D — NOMADZ: Signal Descent
## MOTHER BRAIN uplink terminal. Saves game, restores health/fuel, sets checkpoint.
## VultureCode / Sol / NOMADZ Universe

class_name SavePoint
extends Area2D

@export var save_point_id   : String = ""
@export var restore_fuel    : bool   = true
@export var heal_on_save    : bool   = true
@export var heal_amount     : int    = 50

@onready var sprite         : AnimatedSprite2D = $AnimatedSprite2D
@onready var save_light     : PointLight2D     = $SaveLight
@onready var prompt_label   : Label            = $PromptLabel
@onready var pulse_particles: GPUParticles2D   = $PulseParticles

const DEBUG_MODE := false
var _saving      : bool = false

func _ready() -> void:
	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_instance_valid(save_light):
		save_light.color  = Color(0.2, 1.0, 0.6)
		save_light.energy = 1.0

	if is_instance_valid(prompt_label):
		prompt_label.visible = false
		prompt_label.text    = "[F] SYNC TO MOTHER BRAIN"

func on_interact(player: Node) -> void:
	if _saving:
		return
	_saving = true
	_do_save(player)

func _do_save(player: Node) -> void:
	## Set checkpoint
	if player is Node2D:
		GameManager.set_checkpoint((player as Node2D).global_position)

	## Restore resources
	if heal_on_save:
		GameManager.heal(heal_amount)

	if restore_fuel and player.has_method("update_fuel"):
		player.fuel = player.FUEL_MAX
		GameManager.update_fuel(player.FUEL_MAX)

	GameManager.save_game()
	AudioManager.play_sfx("save_point")

	_pulse_effect()

	if is_instance_valid(prompt_label):
		prompt_label.text    = "SYNCED TO MOTHER BRAIN"
		prompt_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(prompt_label):
		prompt_label.text    = "[F] SYNC TO MOTHER BRAIN"
	_saving = false

	if DEBUG_MODE:
		print("[SavePoint] Saved at: %s" % save_point_id)

func _pulse_effect() -> void:
	if is_instance_valid(pulse_particles):
		pulse_particles.emitting = true
	if is_instance_valid(save_light):
		var tween := create_tween()
		tween.tween_property(save_light, "energy", 4.0, 0.3)
		tween.tween_property(save_light, "energy", 1.0, 0.8)
	if is_instance_valid(sprite):
		sprite.play("save")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_instance_valid(prompt_label):
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_instance_valid(prompt_label):
			prompt_label.visible = false
