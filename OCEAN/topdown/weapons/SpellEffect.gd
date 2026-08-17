class_name SpellEffect
extends Node2D

@onready var animation_player := $AnimationPlayer
@onready var hitbox := $Hitbox

var damage := 3
var effect_duration := 0.5

func _ready() -> void:
	if hitbox:
		hitbox.body_entered.connect(_on_hit)
		hitbox.area_entered.connect(_on_hit)
	var tween := create_tween()
	tween.tween_callback(queue_free).set_delay(effect_duration)

func _on_hit(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
