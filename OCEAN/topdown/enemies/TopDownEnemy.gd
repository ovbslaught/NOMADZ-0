class_name TopDownEnemy
extends CharacterBody2D

enum AI { IDLE, PATROL, CHASE, SHOOTER, BOSS }

@export var ai_type: AI = AI.IDLE
@export var hp := 3
@export var move_speed := 60.0
@export var damage := 1
@export var chase_radius := 160.0
@export var shoot_cooldown := 2.0

@onready var sprite := $AnimatedSprite2D
@onready var detection := $DetectionArea

var player_ref: Node2D
var is_dead := false
var patrol_points: Array[Vector2] = []
var patrol_index := 0
var _shoot_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	player_ref = get_tree().get_first_node_in_group("player")
	if detection:
		detection.body_entered.connect(_on_player_enter)
		detection.body_exited.connect(_on_player_exit)

func _physics_process(delta: float) -> void:
	if is_dead: return
	match ai_type:
		AI.IDLE: _idle(delta)
		AI.PATROL: _patrol(delta)
		AI.CHASE: _chase(delta)
		AI.SHOOTER: _shooter(delta)
		AI.BOSS: _boss(delta)
	move_and_slide()

func _idle(_delta: float) -> void:
	velocity = Vector2.ZERO

func _patrol(delta: float) -> void:
	if patrol_points.is_empty(): return
	var target := patrol_points[patrol_index]
	if global_position.distance_to(target) < 8:
		patrol_index = (patrol_index + 1) % patrol_points.size()
	velocity = global_position.direction_to(target) * move_speed

func _chase(delta: float) -> void:
	if not player_ref: return
	var dir := global_position.direction_to(player_ref.global_position)
	velocity = dir * move_speed

func _shooter(delta: float) -> void:
	if not player_ref: return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist > chase_radius:
		_chase(delta)
		return
	velocity = Vector2.ZERO
	_shoot_timer -= delta
	if _shoot_timer <= 0:
		_shoot_timer = shoot_cooldown
		_fire_projectile()

func _boss(delta: float) -> void:
	_chase(delta)

func _fire_projectile() -> void:
	if not player_ref: return
	var dir := global_position.direction_to(player_ref.global_position)
	var proj := preload("res://topdown/weapons/Projectile.tscn").instantiate()
	proj.damage = damage
	proj.direction = dir
	proj.speed = 200.0
	proj.global_position = global_position
	get_parent().add_child(proj)

func _on_player_enter(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_player_exit(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null

func take_damage(amount: int, _source: String = "player") -> void:
	if is_dead: return
	hp -= amount
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	if hp <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
