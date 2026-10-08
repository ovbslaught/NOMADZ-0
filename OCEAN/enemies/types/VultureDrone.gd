## VultureDrone.gd
## CharacterBody2D Enemy — NOMADZ: Signal Descent
## VULTURE:INC security drone. Triangular patrol pattern. Signal disruptor.
## State machine: PATROL → ALERT → CHASE → ATTACK → STUNNED → DEAD
## VultureCode / Sol / NOMADZ Universe

class_name VultureDrone
extends CharacterBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal died(position: Vector2)
signal player_spotted(player: Node2D)
signal stunned_by_pulse()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := false

const PATROL_SPEED  : float = 70.0
const CHASE_SPEED   : float = 140.0
const ATTACK_RANGE  : float = 80.0
const DETECT_RANGE  : float = 200.0
const STUN_DURATION : float = 2.3      ## Signal pulse stun window
const DAMAGE_AMOUNT : int   = 12
const ATTACK_COOLDOWN: float = 1.4
const MAX_HEALTH    : int   = 30
const PATROL_DIST   : float = 8.0      ## Triangle corner size (meters)
const XP_VALUE      : int   = 10

# ─── EXPORTS ─────────────────────────────────────────────────────────────────
@export var patrol_point_a : Vector2 = Vector2(-80, 0)
@export var patrol_point_b : Vector2 = Vector2(80,  0)
@export var patrol_height  : float   = -60.0            ## Peak of triangle
@export var loot_fragment_id: String = ""               ## Optional fragment drop

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite        : AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D           = $DetectionArea
@onready var attack_area   : Area2D           = $AttackArea
@onready var stun_timer    : Timer            = $StunTimer
@onready var attack_timer  : Timer            = $AttackTimer
@onready var drone_light   : PointLight2D     = $DroneLight
@onready var navigation    : NavigationAgent2D = $NavigationAgent2D

# ─── STATE MACHINE ────────────────────────────────────────────────────────────
enum State { PATROL, ALERT, CHASE, ATTACK, STUNNED, DEAD }
var state          : State   = State.PATROL
var health         : int     = MAX_HEALTH
var target         : Node2D  = null
var patrol_index   : int     = 0
var patrol_points  : Array[Vector2] = []
var stun_remaining : float   = 0.0
var attack_ready   : bool    = true
var _frame_count   : int     = 0
var _spawn_position: Vector2 = Vector2.ZERO

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_spawn_position = global_position
	_build_patrol_triangle()
	_setup_nodes()
	_connect_signals()
	add_to_group("enemies")
	_log("VultureDrone ready at %s" % str(global_position))

func _build_patrol_triangle() -> void:
	## Triangle: A → peak → B → back to A
	var world_a := _spawn_position + patrol_point_a
	var world_b := _spawn_position + patrol_point_b
	var mid     := (world_a + world_b) * 0.5
	var peak    := mid + Vector2(0, patrol_height)
	patrol_points = [world_a, peak, world_b]

func _setup_nodes() -> void:
	_ensure_timer("StunTimer",   STUN_DURATION, true)
	_ensure_timer("AttackTimer", ATTACK_COOLDOWN, true)

	if is_instance_valid(drone_light):
		drone_light.color  = Color(0.9, 0.2, 0.1, 1.0)
		drone_light.energy = 0.8

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

func _connect_signals() -> void:
	if has_node("StunTimer"):
		$StunTimer.timeout.connect(_on_stun_ended)
	if has_node("AttackTimer"):
		$AttackTimer.timeout.connect(func(): attack_ready = true)
	if has_node("DetectionArea"):
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if has_node("AttackArea"):
		attack_area.body_entered.connect(_on_attack_body_entered)

	## Signal pulse stuns this drone
	SignalverseManager.bleed_event_triggered.connect(_on_bleed_event)

# ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_frame_count += 1

	match state:
		State.PATROL  : _state_patrol(delta)
		State.ALERT   : _state_alert(delta)
		State.CHASE   : _state_chase(delta)
		State.ATTACK  : _state_attack(delta)
		State.STUNNED : _state_stunned(delta)

	move_and_slide()
	_update_animation()
	_update_light()

# ─── PATROL ───────────────────────────────────────────────────────────────────
func _state_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var target_pos := patrol_points[patrol_index]
	var dir        := (target_pos - global_position)

	if dir.length() < 6.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return

	velocity = dir.normalized() * PATROL_SPEED

	## Check if player in range
	if _check_player_in_range(DETECT_RANGE):
		_enter_state(State.ALERT)

func _state_alert(delta: float) -> void:
	## Brief alert pause before chase
	velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(target):
		_enter_state(State.CHASE)
	else:
		_enter_state(State.PATROL)

func _state_chase(delta: float) -> void:
	if not is_instance_valid(target):
		_enter_state(State.PATROL)
		return

	var dist := global_position.distance_to(target.global_position)

	if dist > DETECT_RANGE * 1.4:
		target = null
		_enter_state(State.PATROL)
		return

	if dist <= ATTACK_RANGE:
		_enter_state(State.ATTACK)
		return

	var dir  := (target.global_position - global_position).normalized()
	velocity  = dir * CHASE_SPEED

func _state_attack(_delta: float) -> void:
	if not is_instance_valid(target):
		_enter_state(State.PATROL)
		return

	velocity = velocity.move_toward(Vector2.ZERO, 400.0 * _delta)

	if global_position.distance_to(target.global_position) > ATTACK_RANGE * 1.2:
		_enter_state(State.CHASE)
		return

	if attack_ready:
		_fire_disruptor()

func _state_stunned(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)

# ─── TRANSITIONS ─────────────────────────────────────────────────────────────
func _enter_state(new_state: State) -> void:
	state = new_state
	_log("State → %s" % State.keys()[new_state])

	match new_state:
		State.ALERT:
			if is_instance_valid(drone_light):
				drone_light.color = Color(1.0, 0.8, 0.0, 1.0)
			AudioManager.play_sfx("bleed_glitch")
		State.CHASE:
			if is_instance_valid(drone_light):
				drone_light.color = Color(1.0, 0.1, 0.0, 1.0)
		State.PATROL:
			if is_instance_valid(drone_light):
				drone_light.color = Color(0.9, 0.2, 0.1, 1.0)
		State.STUNNED:
			if is_instance_valid(drone_light):
				drone_light.color = Color(0.1, 0.4, 1.0, 1.0)
			$StunTimer.start()
			stunned_by_pulse.emit()

func _on_stun_ended() -> void:
	if state == State.STUNNED:
		_enter_state(State.ALERT if is_instance_valid(target) else State.PATROL)

# ─── COMBAT ───────────────────────────────────────────────────────────────────
func _fire_disruptor() -> void:
	attack_ready = false
	$AttackTimer.start()
	## Damage dealt via AttackArea overlap, but also direct if adjacent
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(DAMAGE_AMOUNT, "VultureDrone_disruptor")
	AudioManager.play_sfx("hit_enemy")
	_log("Disruptor fired at target")

func take_damage(amount: int, source: String = "unknown") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_hit()
	AudioManager.play_sfx("hit_enemy")
	_log("Took %d damage from %s | HP: %d" % [amount, source, health])

	if health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	AudioManager.play_sfx("enemy_die")
	died.emit(global_position)

	## Drop lore or fragment
	if not loot_fragment_id.is_empty():
		GameManager.collect_fragment(loot_fragment_id)

	if is_instance_valid(sprite):
		sprite.play("death")

	await get_tree().create_timer(1.0).timeout
	queue_free()

func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.08)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.08)

# ─── DETECTION ────────────────────────────────────────────────────────────────
func _check_player_in_range(range: float) -> bool:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node2D:
			if global_position.distance_to((p as Node2D).global_position) <= range:
				target = p as Node2D
				return true
	return false

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target = body
		if state == State.PATROL:
			_enter_state(State.ALERT)
		player_spotted.emit(body)
		_log("Player detected")

func _on_detection_body_exited(body: Node2D) -> void:
	if body == target and state != State.ATTACK:
		target = null

func _on_attack_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		if state == State.ATTACK or state == State.CHASE:
			body.take_damage(DAMAGE_AMOUNT, "VultureDrone_contact")

# ─── SIGNAL PULSE STUN ────────────────────────────────────────────────────────
func _on_bleed_event(event_type: String, _payload: Dictionary) -> void:
	if event_type != "signal_pulse_player":
		return
	if state == State.DEAD or state == State.STUNNED:
		return
	_enter_state(State.STUNNED)
	_log("Stunned by signal pulse")

# ─── VISUAL ───────────────────────────────────────────────────────────────────
func _update_animation() -> void:
	if not is_instance_valid(sprite):
		return
	match state:
		State.PATROL : sprite.play("fly_patrol")
		State.ALERT  : sprite.play("fly_alert")
		State.CHASE  : sprite.play("fly_chase")
		State.ATTACK : sprite.play("fly_attack")
		State.STUNNED: sprite.play("stunned")
		State.DEAD   : sprite.play("death")

func _update_light() -> void:
	if not is_instance_valid(drone_light):
		return
	## Alert flicker
	if state == State.ALERT:
		drone_light.energy = 0.8 + sin(Time.get_ticks_msec() * 0.02) * 0.4

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[VultureDrone | F%d] %s" % [_frame_count, msg])
