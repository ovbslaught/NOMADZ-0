class_name Projectile
extends CharacterBody2D

signal hit_target(target: Node, damage: int)

enum Type { ARROW, FIRE, ICE, LIGHTNING }

@export var speed := 400.0
@export var damage := 2
@export var projectile_type: Type = Type.ARROW
@export var max_distance := 600.0

var direction: Vector2 = Vector2.RIGHT
var origin_pos: Vector2
var pierces := 0

func _ready() -> void:
	origin_pos = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	velocity = direction * speed
	move_and_slide()
	if global_position.distance_to(origin_pos) > max_distance:
		_despawn()
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider():
			_on_hit(col.get_collider())
			return

func _on_body_entered(body: Node2D) -> void:
	_on_hit(body)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy") or area.has_method("take_damage"):
		_on_hit(area)

func _on_hit(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage)
		hit_target.emit(target, damage)
	if pierces > 0:
		pierces -= 1
	else:
		_despawn()

func _despawn() -> void:
	queue_free()
