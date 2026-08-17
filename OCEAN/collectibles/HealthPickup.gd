## HealthPickup.gd
## Area2D — NOMADZ: Signal Descent
## Health restoration drop. Spawned by defeated enemies or placed in rooms.
## Small = 15 HP, Large = 40 HP. Auto-pickup on touch.
## VultureCode / Sol / NOMADZ Universe

class_name HealthPickup
extends Area2D

enum Size { SMALL, LARGE }

@export var size          : Size  = Size.SMALL
@export var float_height  : float = 4.0
@export var auto_lifetime : float = 15.0  ## Despawn after N seconds (0 = never)

@onready var sprite     : AnimatedSprite2D = $AnimatedSprite2D
@onready var heal_light : PointLight2D     = $HealLight
@onready var life_timer : Timer            = $LifetimeTimer

const HEAL_AMOUNTS := { Size.SMALL: 15, Size.LARGE: 40 }
const DEBUG_MODE   := false

var _collected   : bool  = false
var _spawn_y     : float = 0.0
var _time        : float = 0.0

func _ready() -> void:
	_spawn_y = position.y
	body_entered.connect(_on_body_entered)

	if is_instance_valid(heal_light):
		heal_light.color  = Color(0.2, 1.0, 0.3)
		heal_light.energy = 0.8

	if is_instance_valid(sprite):
		sprite.play("small" if size == Size.SMALL else "large")

	if auto_lifetime > 0.0:
		_ensure_timer("LifetimeTimer", auto_lifetime, true)
		$LifetimeTimer.timeout.connect(queue_free)
		$LifetimeTimer.start()

func _ensure_timer(node_name: String, wait: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait
		t.one_shot  = one_shot
		add_child(t)

func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _spawn_y + sin(_time * 2.5) * float_height

func _on_body_entered(body: Node2D) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	var amount : int = HEAL_AMOUNTS[size]
	GameManager.heal(amount)
	AudioManager.play_sfx("collect_fragment")
	_collect_effect()
	if DEBUG_MODE:
		print("[HealthPickup] +%d HP" % amount)

func _collect_effect() -> void:
	set_deferred("monitoring", false)
	if is_instance_valid(sprite):
		var tween := create_tween()
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.parallel().tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.3)
	if is_instance_valid(heal_light):
		var tween2 := create_tween()
		tween2.tween_property(heal_light, "energy", 0.0, 0.3)
	await get_tree().create_timer(0.35).timeout
	queue_free()
