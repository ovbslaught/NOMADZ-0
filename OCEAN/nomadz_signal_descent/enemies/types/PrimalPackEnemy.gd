## PrimalPackEnemy.gd
## CharacterBody2D Enemy — NOMADZ: Signal Descent
## Pre-station organic fauna. Pack-coordinated. Territorial.
## Does NOT respond to signal pulse (not synthetic, not bleed-construct).
## Avoids bioluminescent growth. Coordinates with siblings in group.
## VultureCode / Sol / NOMADZ Universe

class_name PrimalPackEnemy
extends CharacterBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal died(position: Vector2)
signal territory_violated(position: Vector2)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE   := false

const WALK_SPEED   : float = 90.0
const CHASE_SPEED  : float = 210.0
const LEAP_FORCE   : Vector2 = Vector2(180.0, -260.0)
const GRAVITY      : float = 980.0
const DETECT_RANGE : float = 180.0
const ATTACK_RANGE : float = 36.0
const DAMAGE_AMOUNT: int   = 20
const MAX_HEALTH   : int   = 35
const LEAP_COOLDOWN: float = 2.5
const PACK_ALERT_RADIUS: float = 240.0  ## Alerts siblings within this range
const TERRITORY_MARKER_RANGE: float = 200.0

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var pack_group_id    : String  = "pack_default"  ## Siblings share this group
@export var territory_center : Vector2 = Vector2.ZERO
@export var territory_radius : float   = 220.0
@export var spine_color      : Color   = Color(0.2, 0.7, 0.3)

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite       : AnimatedSprite2D = $AnimatedSprite2D
@onready var spine_light  : PointLight2D     = $SpineLight
@onready var leap_timer   : Timer            = $LeapTimer
@onready var ground_check : RayCast2D        = $GroundCheck

# ─── STATE ────────────────────────────────────────────────────────────────────
enum State { IDLE, PATROL, ALERT, CHASE, LEAP, ATTACK, RETREAT, DEAD }
var state         : State  = State.IDLE
var health        : int    = MAX_HEALTH
var target        : Node2D = null
var move_dir      : float  = 1.0
var can_leap      : bool   = true
var _spawn_pos    : Vector2 = Vector2.ZERO
var _frame_count  : int    = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_spawn_pos = global_position
	if territory_center == Vector2.ZERO:
		territory_center = global_position

	add_to_group("enemies")
	add_to_group(pack_group_id)

	_ensure_timer("LeapTimer", LEAP_COOLDOWN, true)
	if has_node("LeapTimer"):
		$LeapTimer.timeout.connect(func(): can_leap = true)

	if is_instance_valid(spine_light):
		spine_light.color  = spine_color
		spine_light.energy = 0.5

	state = State.PATROL
	_log("PrimalPack '%s' ready" % pack_group_id)

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

# ─── PHYSICS ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_frame_count += 1

	## Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, 600.0)

	match state:
		State.IDLE   : _state_idle(delta)
		State.PATROL : _state_patrol(delta)
		State.ALERT  : _state_alert(delta)
		State.CHASE  : _state_chase(delta)
		State.LEAP   : _state_leap(delta)
		State.ATTACK : _state_attack(delta)
		State.RETREAT: _state_retreat(delta)

	move_and_slide()
	_update_visuals()

# ─── STATES ───────────────────────────────────────────────────────────────────
func _state_idle(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * _delta)
	if _check_player_in_range(DETECT_RANGE):
		_enter_state(State.ALERT)
	elif randf() < 0.002:
		_enter_state(State.PATROL)

func _state_patrol(delta: float) -> void:
	velocity.x = move_dir * WALK_SPEED

	## Reverse at territory edge
	var dist_from_center := global_position.distance_to(territory_center)
	if dist_from_center > territory_radius:
		move_dir = sign(territory_center.x - global_position.x)
		_flip()

	## Reverse at wall
	if is_on_wall():
		move_dir *= -1.0
		_flip()

	if _check_player_in_range(DETECT_RANGE):
		_enter_state(State.ALERT)

func _state_alert(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * _delta)
	## Alert pack siblings
	_alert_pack()
	## Brief pause before chase
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(target):
		_enter_state(State.CHASE)
	else:
		_enter_state(State.PATROL)

func _state_chase(delta: float) -> void:
	if not is_instance_valid(target):
		_enter_state(State.PATROL)
		return

	var dist := global_position.distance_to(target.global_position)

	## Lost target outside territory + range
	if dist > DETECT_RANGE * 1.6 and global_position.distance_to(territory_center) > territory_radius:
		_enter_state(State.RETREAT)
		return

	if dist <= ATTACK_RANGE:
		_enter_state(State.ATTACK)
		return

	## Leap if target is elevated and leap is ready
	var height_diff := global_position.y - target.global_position.y
	if height_diff > 40.0 and can_leap and is_on_floor():
		_enter_state(State.LEAP)
		return

	var dir := sign(target.global_position.x - global_position.x)
	velocity.x = dir * CHASE_SPEED
	move_dir = dir
	_flip()

func _state_leap(_delta: float) -> void:
	if not is_instance_valid(target):
		_enter_state(State.PATROL)
		return
	var dir := sign(target.global_position.x - global_position.x)
	velocity = Vector2(LEAP_FORCE.x * dir, LEAP_FORCE.y)
	can_leap = false
	$LeapTimer.start()
	AudioManager.play_sfx("jump")
	await get_tree().create_timer(0.1).timeout
	_enter_state(State.CHASE)

func _state_attack(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * _delta)
	if is_instance_valid(target) and target.has_method("take_damage"):
		var dist := global_position.distance_to(target.global_position)
		if dist <= ATTACK_RANGE:
			target.take_damage(DAMAGE_AMOUNT, "PrimalPack_bite")
			AudioManager.play_sfx("hit_enemy")
	await get_tree().create_timer(0.5).timeout
	_enter_state(State.CHASE)

func _state_retreat(delta: float) -> void:
	var dir := sign(territory_center.x - global_position.x)
	velocity.x = dir * WALK_SPEED
	if global_position.distance_to(territory_center) < 40.0:
		target = null
		_enter_state(State.IDLE)

# ─── TRANSITIONS ─────────────────────────────────────────────────────────────
func _enter_state(new_state: State) -> void:
	state = new_state
	_log("State → %s" % State.keys()[new_state])
	match new_state:
		State.ALERT:
			if is_instance_valid(spine_light):
				spine_light.energy = 1.5
				spine_light.color  = Color(1.0, 0.4, 0.0)
		State.PATROL, State.IDLE:
			if is_instance_valid(spine_light):
				spine_light.energy = 0.5
				spine_light.color  = spine_color

# ─── PACK COORDINATION ────────────────────────────────────────────────────────
func _alert_pack() -> void:
	var siblings := get_tree().get_nodes_in_group(pack_group_id)
	for sibling in siblings:
		if sibling == self:
			continue
		if sibling is PrimalPackEnemy:
			var dist := global_position.distance_to(sibling.global_position)
			if dist <= PACK_ALERT_RADIUS:
				(sibling as PrimalPackEnemy)._receive_pack_alert(target)
				territory_violated.emit(global_position)

func _receive_pack_alert(alert_target: Node2D) -> void:
	if state == State.DEAD or state == State.CHASE:
		return
	target = alert_target
	_enter_state(State.ALERT)
	_log("Pack alert received — joining chase")

# ─── DETECTION ────────────────────────────────────────────────────────────────
func _check_player_in_range(range: float) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node2D:
			if global_position.distance_to((p as Node2D).global_position) <= range:
				target = p as Node2D
				return true
	return false

# ─── DAMAGE ───────────────────────────────────────────────────────────────────
func take_damage(amount: int, source: String = "unknown") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_hit()
	AudioManager.play_sfx("hit_enemy")
	_log("Took %d from %s | HP: %d" % [amount, source, health])
	if health <= 0:
		_die()
	elif state == State.PATROL or state == State.IDLE:
		## Attacked from stealth — alert
		_check_player_in_range(DETECT_RANGE * 2)
		_enter_state(State.ALERT)

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	AudioManager.play_sfx("enemy_die")
	died.emit(global_position)
	if is_instance_valid(sprite):
		sprite.play("death")
	await get_tree().create_timer(1.2).timeout
	queue_free()

func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.5, 0.6, 0.6), 0.07)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.10)

# ─── VISUALS ──────────────────────────────────────────────────────────────────
func _flip() -> void:
	if is_instance_valid(sprite):
		sprite.flip_h = move_dir < 0

func _update_visuals() -> void:
	if not is_instance_valid(sprite):
		return
	match state:
		State.IDLE    : sprite.play("idle")
		State.PATROL  : sprite.play("walk")
		State.ALERT   : sprite.play("alert")
		State.CHASE   : sprite.play("run")
		State.LEAP    : sprite.play("leap")
		State.ATTACK  : sprite.play("attack")
		State.RETREAT : sprite.play("walk")
		State.DEAD    : sprite.play("death")

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[PrimalPack | F%d] %s" % [_frame_count, msg])
