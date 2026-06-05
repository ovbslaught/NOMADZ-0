class_name ShmupPlayer
extends CharacterBody2D

signal laser_fired(direction: Vector2, origin: Vector2)
signal bomb_detonated(origin: Vector2)

const SPEED := 350.0
const LASER_COOLDOWN := 0.15
const BOMB_COOLDOWN := 3.0
const INVINCIBILITY_TIME := 1.5
const MAX_HEALTH := 5

@onready var sprite := $AnimatedSprite2D
@onready var shoot_origin := $ShootOrigin
@onready var laser_timer := $LaserTimer
@onready var bomb_timer := $BombTimer
@onready var invincibility_timer := $InvincibilityTimer

var health := MAX_HEALTH
var score := 0
var power_level := 1
var is_invincible := false
var screen_bounds: Rect2

func _ready() -> void:
	_ensure_timer("LaserTimer", LASER_COOLDOWN, true)
	_ensure_timer("BombTimer", BOMB_COOLDOWN, true)
	_ensure_timer("InvincibilityTimer", INVINCIBILITY_TIME, true)
	if has_node("InvincibilityTimer"):
		$InvincibilityTimer.timeout.connect(func(): is_invincible = false)

func _ensure_timer(name: String, wait: float, one_shot: bool) -> void:
	if not has_node(name):
		var t := Timer.new()
		t.name = name
		t.wait_time = wait
		t.one_shot = one_shot
		add_child(t)

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	velocity = input_dir * SPEED
	move_and_slide()
	_clamp_to_screen()

	if Input.is_action_pressed("shoot") and $LaserTimer.is_stopped():
		_fire_laser()
	if Input.is_action_just_pressed("dash") and $BombTimer.is_stopped():
		_fire_bomb()

func _clamp_to_screen() -> void:
	if screen_bounds != Rect2():
		global_position = Vector2(
			clampf(global_position.x, screen_bounds.position.x, screen_bounds.end.x),
			clampf(global_position.y, screen_bounds.position.y, screen_bounds.end.y)
		)

func _fire_laser() -> void:
	$LaserTimer.start()
	for i in power_level:
		var offset := Vector2(0, -8 * (i - power_level / 2.0))
		var origin := shoot_origin.global_position + offset
		laser_fired.emit(Vector2.UP, origin)

func _fire_bomb() -> void:
	$BombTimer.start()
	bomb_detonated.emit(global_position)

func take_damage(amount: int, _source: String = "enemy") -> void:
	if is_invincible: return
	is_invincible = true
	$InvincibilityTimer.start()
	health -= amount
	GameManager.current_health = health * 20
	GameManager.health_changed.emit(GameManager.current_health, GameManager.MAX_HEALTH)
	var tween := create_tween()
	for i in 4:
		tween.tween_property(sprite, "modulate:a", 0.2, 0.08)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
	if health <= 0:
		GameManager.player_died.emit()

func add_power() -> void:
	power_level = mini(power_level + 1, 5)

func add_score(pts: int) -> void:
	score += pts

func _on_health_pickup() -> void:
	health = mini(MAX_HEALTH, health + 2)
