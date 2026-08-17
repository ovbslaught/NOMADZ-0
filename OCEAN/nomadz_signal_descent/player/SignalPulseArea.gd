## SignalPulseArea.gd
## Area2D — NOMADZ: Signal Descent
## Expanding radial signal pulse. Stuns drones, destroys phantoms, reveals hidden lore.
## Spawned by Player on signal_pulse action.
## VultureCode / Sol / NOMADZ Universe

class_name SignalPulseArea
extends Area2D

@export var max_radius  : float = 180.0
@export var expand_time : float = 0.4
@export var damage      : int   = 30
@export var stun_enemies: bool  = true

@onready var pulse_sprite : AnimatedSprite2D = $AnimatedSprite2D
@onready var pulse_light  : PointLight2D     = $PulseLight
@onready var col_shape    : CollisionShape2D = $CollisionShape2D

const DEBUG_MODE := false
var _expanded    : bool = false
var _hit_targets : Array = []

func _ready() -> void:
	add_to_group("signal_pulse")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_expand()

func _expand() -> void:
	## Animate radius from 0 to max_radius
	if is_instance_valid(col_shape) and col_shape.shape is CircleShape2D:
		col_shape.shape.radius = 0.0
		var tween := create_tween()
		tween.tween_property(col_shape.shape, "radius", max_radius, expand_time)

	if is_instance_valid(pulse_sprite):
		pulse_sprite.scale = Vector2.ZERO
		var tween2 := create_tween()
		tween2.tween_property(pulse_sprite, "scale", Vector2.ONE * (max_radius / 32.0), expand_time)

	if is_instance_valid(pulse_light):
		pulse_light.color  = Color(0.4, 0.8, 1.0)
		pulse_light.energy = 3.0
		var tween3 := create_tween()
		tween3.tween_property(pulse_light, "energy", 0.0, expand_time * 1.5)

	## Broadcast to SignalverseManager so it can stun phantoms
	SignalverseManager.broadcast_event("signal_pulse_player", {"origin": global_position})

	await get_tree().create_timer(expand_time + 0.1).timeout
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body in _hit_targets:
		return
	_hit_targets.append(body)

	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, "SignalPulse")
		if DEBUG_MODE:
			print("[SignalPulse] Hit enemy: %s" % body.name)

func _on_area_entered(area: Area2D) -> void:
	## Reveal hidden lore nodes within pulse radius
	if area.is_in_group("hidden_lore"):
		area.call_deferred("reveal")
