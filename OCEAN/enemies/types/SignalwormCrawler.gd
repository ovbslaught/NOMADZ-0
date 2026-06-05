## SignalwormCrawler.gd
## CharacterBody2D Enemy — NOMADZ: Signal Descent
## Signalverse fauna. Partially manifested bleed entity.
## Grazes signal energy. Ignores player unless signal output is high.
## Animal Well-style creature — not hostile by default.
## VultureCode / Sol / NOMADZ Universe

class_name SignalwormCrawler
extends CharacterBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal died(position: Vector2)
signal aggro_triggered()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE  := false

const GRAZE_SPEED : float = 45.0
const AGGRO_SPEED : float = 160.0
const AGGRO_RANGE : float = 160.0    ## Only aggros if player signal is HIGH
const SIGNAL_THRESHOLD : float = 60.0 ## GameManager.signal_meter above this → aggro
const DAMAGE_AMOUNT : int = 18
const MAX_HEALTH  : int   = 22
const GRAVITY     : float = 980.0
const TURN_DISTANCE: float = 24.0   ## Reverse direction when hitting a wall/edge
const AGGRO_LINGER: float = 4.0     ## Stays aggressive for N seconds after signal drops

# ─── EXPORTS ─────────────────────────────────────────────────────────────────
@export var starts_visible  : bool  = false   ## False = starts as shimmer (low bleed)
@export var segment_count   : int   = 4       ## Visual segments (placeholder)
@export var lore_drop_id    : String = "cr_002"

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite       : AnimatedSprite2D = $AnimatedSprite2D
@onready var worm_light   : PointLight2D     = $WormLight
@onready var wall_detector: RayCast2D        = $WallDetector
@onready var edge_detector: RayCast2D        = $EdgeDetector
@onready var aggro_timer  : Timer            = $AggroLingerTimer

# ─── STATE ────────────────────────────────────────────────────────────────────
enum State { DORMANT, GRAZE, AGGRO, DEAD }
var state        : State  = State.DORMANT
var health       : int    = MAX_HEALTH
var move_dir     : float  = 1.0
var is_aggressive: bool   = false
var target       : Node2D = null
var _frame_count : int    = 0
var _bleed_opacity: float = 0.0    ## 0 = shimmer, 1 = fully solid

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	_setup_nodes()
	_connect_signals()

	state = State.DORMANT if not starts_visible else State.GRAZE
	_log("SignalwormCrawler ready. Starts visible: %s" % str(starts_visible))

func _setup_nodes() -> void:
	_ensure_timer("AggroLingerTimer", AGGRO_LINGER, true)

	if is_instance_valid(worm_light):
		worm_light.color  = Color(0.2, 0.8, 0.4, 1.0)
		worm_light.energy = 0.3

	## Wall detector points forward
	if is_instance_valid(wall_detector):
		wall_detector.target_position = Vector2(24.0, 0.0)

	## Edge detector points down and forward
	if is_instance_valid(edge_detector):
		edge_detector.target_position = Vector2(20.0, 32.0)

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

func _connect_signals() -> void:
	if has_node("AggroLingerTimer"):
		$AggroLingerTimer.timeout.connect(_on_aggro_linger_ended)
	SignalverseManager.bleed_event_triggered.connect(_on_bleed_event)
	GameManager.signal_meter_changed.connect(_on_signal_meter_changed)

# ─── PHYSICS ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_frame_count += 1

	_tick_bleed_manifestation(delta)
	_apply_gravity(delta)

	match state:
		State.DORMANT: _state_dormant(delta)
		State.GRAZE  : _state_graze(delta)
		State.AGGRO  : _state_aggro(delta)

	move_and_slide()
	_update_visuals()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

# ─── DORMANT ──────────────────────────────────────────────────────────────────
func _state_dormant(_delta: float) -> void:
	velocity.x = 0.0
	## Transitions to GRAZE when corruption is high enough
	if SignalverseManager.corruption_level > 30.0:
		state = State.GRAZE
		_log("Manifesting from bleed — entering GRAZE")

# ─── GRAZE ────────────────────────────────────────────────────────────────────
func _state_graze(_delta: float) -> void:
	velocity.x = move_dir * GRAZE_SPEED

	## Turn on wall
	if is_instance_valid(wall_detector):
		wall_detector.target_position.x = 24.0 * move_dir
		if wall_detector.is_colliding():
			move_dir *= -1.0
			_flip_sprite()

	## Turn on edge (don't walk off platforms)
	if is_instance_valid(edge_detector):
		edge_detector.target_position.x = 20.0 * move_dir
		if not edge_detector.is_colliding() and is_on_floor():
			move_dir *= -1.0
			_flip_sprite()

	## Check aggro condition
	if is_aggressive:
		state = State.AGGRO
		aggro_triggered.emit()

func _state_aggro(_delta: float) -> void:
	if not is_instance_valid(target) or not is_aggressive:
		state = State.GRAZE
		return

	var dist := global_position.distance_to(target.global_position)

	## Chase
	var dir_to_target := sign(target.global_position.x - global_position.x)
	velocity.x = dir_to_target * AGGRO_SPEED
	move_dir = dir_to_target
	_flip_sprite()

	## Contact damage
	if dist < 28.0 and target.has_method("take_damage"):
		target.take_damage(DAMAGE_AMOUNT, "SignalwormCrawler_contact")

# ─── SIGNAL METER RESPONSE ────────────────────────────────────────────────────
func _on_signal_meter_changed(value: float) -> void:
	var player_near := _get_nearest_player()
	if player_near == null:
		return

	var dist := global_position.distance_to(player_near.global_position)
	if dist > AGGRO_RANGE:
		return

	## Aggro when player has high signal + is near
	if value > SIGNAL_THRESHOLD and not is_aggressive:
		is_aggressive = true
		target = player_near
		if has_node("AggroLingerTimer"):
			$AggroLingerTimer.stop()
		_log("Aggro triggered by high signal: %.1f" % value)

func _on_aggro_linger_ended() -> void:
	is_aggressive = false
	target = null
	state = State.GRAZE
	_log("Aggro linger ended — returning to graze")

# ─── BLEED EVENTS ─────────────────────────────────────────────────────────────
func _on_bleed_event(event_type: String, _payload: Dictionary) -> void:
	match event_type:
		"signal_pulse_player":
			## Signal pulse terrifies the worm — it flees
			move_dir *= -1.0
			_flip_sprite()
			is_aggressive = false
		"phantom_spawn":
			## Phantom spawns excite the worm
			if state != State.DEAD:
				velocity.x = move_dir * AGGRO_SPEED * 0.5

# ─── DAMAGE ───────────────────────────────────────────────────────────────────
func take_damage(amount: int, source: String = "unknown") -> void:
	if state == State.DEAD:
		return
	health -= amount
	_flash_hit()
	_log("Took %d from %s | HP: %d" % [amount, source, health])
	if health <= 0:
		_die()

func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	AudioManager.play_sfx("enemy_die")
	died.emit(global_position)
	GameManager.collect_lore(lore_drop_id)

	if is_instance_valid(sprite):
		sprite.play("death")
	await get_tree().create_timer(0.8).timeout
	queue_free()

func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.GREEN, 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)

# ─── BLEED MANIFESTATION ──────────────────────────────────────────────────────
func _tick_bleed_manifestation(delta: float) -> void:
	## The worm becomes more solid as corruption rises
	var target_opacity := clampf(SignalverseManager.corruption_level / 60.0, 0.1, 1.0)
	_bleed_opacity = lerpf(_bleed_opacity, target_opacity, delta * 2.0)
	if is_instance_valid(sprite):
		sprite.modulate.a = _bleed_opacity

# ─── HELPERS ──────────────────────────────────────────────────────────────────
func _get_nearest_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	var nearest : Node2D = null
	var min_dist := INF
	for p in players:
		if p is Node2D:
			var d := global_position.distance_to((p as Node2D).global_position)
			if d < min_dist:
				min_dist = d
				nearest = p as Node2D
	return nearest

func _flip_sprite() -> void:
	if is_instance_valid(sprite):
		sprite.flip_h = move_dir < 0

func _update_visuals() -> void:
	if not is_instance_valid(worm_light):
		return
	## Green glow; intensifies when aggressive
	worm_light.energy = 0.3 + (0.6 if is_aggressive else 0.0)
	worm_light.color  = Color(1.0, 0.1, 0.1) if is_aggressive else Color(0.2, 0.8, 0.4)

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[SignalwormCrawler | F%d] %s" % [_frame_count, msg])
