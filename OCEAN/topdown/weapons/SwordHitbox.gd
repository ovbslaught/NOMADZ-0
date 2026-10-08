class_name SwordHitbox
extends Area2D

signal hit_enemy(enemy: Node, damage: int)

@export var damage := 2

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		hit_enemy.emit(area.owner if area.owner else area, damage)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_enemy.emit(body, damage)
