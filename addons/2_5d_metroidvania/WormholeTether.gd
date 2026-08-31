## WormholeTether.gd
## Node2D — NOMADZ: Signal Descent
## WORMHOLE TETHER ability: grapple hook that swings NORA or pulls her to anchor.
## Fires on shoot if ability is unlocked. Line2D visual + spring physics.
## Attach as child of Player.
## VultureCode / Sol / NOMADZ Universe

class_name WormholeTether
extends Node2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal tether_attached(anchor: Vector2)
signal tether_released()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE      := false
const CAST_RANGE      : float = 280.0
const PULL_SPEED      : float = 340.0
const SWING_FORCE     : float = 500.0
const COOLDOWN        : float = 0.8
const MIN_TETHER_LEN  : float = 30.0
const REEL_SPEED      : float = 80.0      ## Holds S to shorten tether

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var tether_line  : Line2D     = $TetherLine
@onready var anchor_light : PointLight2D = $AnchorLight
@onready var cast         : RayCast2D  = $TetherCast
@onready var cd_timer     : Timer      = $CooldownTimer

# ─── STATE ────────────────────────────────────────────────────────────────────
var is_attached    : bool   = false
var anchor_pos     : Vector2 = Vector2.ZERO
var tether_length  : float  = 0.0
var _player        : CharacterBody2D = null
var _can_fire      : bool   = true

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		push_error("WormholeTether: must be child of CharacterBody2D (Player)")

	_ensure_timer("CooldownTimer", COOLDOWN, true)
	if has_node("CooldownTimer"):
		$CooldownTimer.timeout.connect(func(): _can_fire = true)

	if is_instance_valid(tether_line):
		tether_line.default_color = Color(0.3, 0.7, 1.0, 0.9)
		tether_line.width         = 2.0
		tether_line.visible       = false

	if is_instance_valid(anchor_light):
		anchor_light.energy  = 0.0
		anchor_light.color   = Color(0.3, 0.7, 1.0)

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

# ─── INPUT ────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.has_ability("grapple"):
		return
	if GameManager.is_paused or GameManager.is_dead:
		return

	## Fire or release on shoot press
	if event.is_action_pressed("shoot"):
		if is_attached:
			_release()
		elif _can_fire:
			_fire_tether()

	## Reel in while tether active
	if is_attached and event.is_action_pressed("morph"):
		_reel_in()

# ─── PHYSICS ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_attached or _player == null:
		return

	## Vector from player to anchor
	var to_anchor  := anchor_pos - _player.global_position
	var dist       := to_anchor.length()

	## Enforce max tether length (pendulum constraint)
	if dist > tether_length:
		## Project velocity onto perpendicular of tether (swing)
		var tether_dir := to_anchor.normalized()
		var perp       := Vector2(-tether_dir.y, tether_dir.x)
		var vel        := _player.velocity
		var swing_vel  := perp * vel.dot(perp)
		var pull       := tether_dir * (dist - tether_length) * SWING_FORCE * delta
		_player.velocity = swing_vel + pull

	## Reel in if S held
	if Input.is_action_pressed("morph"):
		tether_length = maxf(MIN_TETHER_LEN, tether_length - REEL_SPEED * delta)

	_update_line()

# ─── FIRE / RELEASE ───────────────────────────────────────────────────────────
func _fire_tether() -> void:
	if not is_instance_valid(cast):
		return

	## Aim at mouse, or ahead of player
	var mouse_world := get_viewport().get_camera_2d().get_global_mouse_position() if get_viewport().get_camera_2d() else Vector2.ZERO
	var aim_dir     : Vector2
	if mouse_world != Vector2.ZERO:
		aim_dir = (_player.global_position - mouse_world).normalized() * -1.0
	else:
		aim_dir = Vector2.UP  ## Default: fire straight up

	cast.target_position = aim_dir * CAST_RANGE
	cast.force_raycast_update()

	if not cast.is_colliding():
		_log("Tether missed")
		return

	var hit := cast.get_collision_point()
	var collider := cast.get_collider()

	## Only attach to terrain (static body) or grapple points
	if collider is StaticBody2D or (collider is Node2D and collider.is_in_group("grapple_point")):
		_attach(hit)
	else:
		_log("Tether hit non-attachable: %s" % str(collider))

func _attach(pos: Vector2) -> void:
	is_attached   = true
	anchor_pos    = pos
	tether_length = _player.global_position.distance_to(pos)
	_can_fire     = false
	$CooldownTimer.start()

	tether_attached.emit(anchor_pos)
	AudioManager.play_sfx("signal_pulse")

	if is_instance_valid(tether_line):
		tether_line.visible = true
	if is_instance_valid(anchor_light):
		anchor_light.global_position = anchor_pos
		anchor_light.energy = 1.5

	_log("Tether attached at %s | length: %.1f" % [str(anchor_pos), tether_length])

func _release() -> void:
	is_attached = false
	tether_released.emit()

	if is_instance_valid(tether_line):
		tether_line.visible = false
	if is_instance_valid(anchor_light):
		anchor_light.energy = 0.0

	_log("Tether released")

func _reel_in() -> void:
	## Already handled in _physics_process
	pass

func _update_line() -> void:
	if not is_instance_valid(tether_line) or _player == null:
		return
	tether_line.points = [Vector2.ZERO, tether_line.to_local(anchor_pos)]
	## Slack visual: add midpoint sag
	var mid := (Vector2.ZERO + tether_line.to_local(anchor_pos)) * 0.5
	mid.y += 8.0
	tether_line.points = [Vector2.ZERO, mid, tether_line.to_local(anchor_pos)]

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[WormholeTether] %s" % msg)
