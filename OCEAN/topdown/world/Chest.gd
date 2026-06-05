class_name Chest
extends Area2D

enum Content { HEALTH, MAGIC, RUPEES, KEY, BOW, SPELL_FIRE, SPELL_ICE, SPELL_LIGHTNING }

@export var content: Content = Content.RUPEES
@export var amount := 5
@export var is_open := false

@onready var sprite := $AnimatedSprite2D
@onready var collision := $CollisionShape2D

func _ready() -> void:
	add_to_group("interactable")
	if is_open:
		_open(false)

func on_interact(player: Node2D) -> void:
	if is_open: return
	is_open = true
	_open(true)
	match content:
		Content.HEALTH:
			if player.has_method("heal"): player.heal(amount)
		Content.MAGIC:
			if player.has_method("add_magic"): player.add_magic(amount)
		Content.RUPEES:
			if player.has_method("add_rupees"): player.add_rupees(amount)
		Content.KEY:
			if player.has_method("add_key"): player.add_key()
		Content.BOW:
			if player.has_method("equip_bow"): player.equip_bow()
		Content.SPELL_FIRE:
			if player.has_method("equip_spell_fire"): player.equip_spell_fire()
		Content.SPELL_ICE:
			if player.has_method("equip_spell_ice"): player.equip_spell_ice()
		Content.SPELL_LIGHTNING:
			if player.has_method("equip_spell_lightning"): player.equip_spell_lightning()

func _open(play_anim: bool) -> void:
	collision.disabled = true
	if play_anim:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(0.8, 0.8, 0.8), 0.2)
