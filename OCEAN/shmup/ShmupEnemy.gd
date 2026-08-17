class_name ShmupEnemy
extends CharacterBody2D

signal destroyed(score_value: int)

enum MovePattern { STRAIGHT, SINUSOID, TOWARD_PLAYER, CIRCLE }

@export var hp := 2
@export var score_value := 100
@export var move_speed := 120.0
@export var move_pattern: MovePattern = MovePattern.STRAIGHT
@export var fire_rate := 0.0
@export var damage := 1

@onready var sprite := $AnimatedSprite2D

var is_dead := false
var _fire_timer := 0.0
var _sin_time := 0.0
var _origin: Vector2

func _ready() -> void:
	add_to_group("enemy")
	_origin = global_position

func _physics_process(delta: float) -> void:
	if is_dead: return
	_sin_time += delta
	match move_pattern:
		MovePattern.STRAIGHT:
			velocity = Vector2(0, move_speed)
		MovePattern.SINUSOID:
			velocity = Vector2(sin(_sin_time * 3.0) * move_speed * 0.5, move_speed)
		MovePattern.TOWARD_PLAYER:
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var dir := global_position.direction_to(player.global_position + Vector2(0, -200))
				velocity = dir * move_speed
			else:
				velocity = Vector2(0, move_speed)
		MovePattern.CIRCLE:
			var rad := 100.0
			var center := _origin
			global_position = center + Vector2(cos(_sin_time) * rad, sin(_sin_time * 0.7) * rad * 0.5 + 50)
			velocity = Vector2.ZERO
	if fire_rate > 0:
		_fire_timer -= delta
		if _fire_timer <= 0:
			_fire_timer = fire_rate
			_fire()

	move_and_slide()

func _fire() -> void:
	var proj := preload("res://topdown/weapons/Projectile.tscn").instantiate()
	proj.damage = damage
	proj.direction = Vector2.DOWN
	proj.speed = 250.0
	proj.global_position = global_position
	get_parent().add_child(proj)

func take_damage(amount: int, _source: String = "player") -> void:
	if is_dead: return
	hp -= amount
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		destroyed.emit(score_value)
		queue_free()
	)
