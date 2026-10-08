## EchoShield.gd
## Node2D — NOMADZ: Signal Descent
## ECHO SHIELD ability: temporary invulnerability + contact damage burst.
## Attach as child of Player. Activated on dash when ability unlocked.
## Visual: expanding ring + brief full-body aura.
## VultureCode / Sol / NOMADZ Universe

class_name EchoShield
extends Node2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal shield_activated()
signal shield_expired()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const SHIELD_DURATION  : float = 1.8
const SHIELD_COOLDOWN  : float = 8.0
const CONTACT_DAMAGE   : int   = 15
const RING_SCALE_MAX   : float = 2.2

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var ring_sprite   : AnimatedSprite2D = $RingSprite
@onready var shield_light  : PointLight2D     = $ShieldLight
@onready var aura_area     : Area2D           = $AuraArea
@onready var duration_timer: Timer            = $DurationTimer
@onready var cooldown_timer: Timer            = $CooldownTimer

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE    := false
var is_active       : bool  = false
var can_activate    : bool  = true
var _player         : Node2D = null
var _hit_this_activation: Array = []

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_player = get_parent() as Node2D
	_setup_nodes()
	_connect_signals()
	set_active(false)

func _setup_nodes() -> void:
	_ensure_timer("DurationTimer", SHIELD_DURATION, true)
	_ensure_timer("CooldownTimer", SHIELD_COOLDOWN, true)

	if is_instance_valid(shield_light):
		shield_light.color  = Color(0.5, 0.9, 1.0)
		shield_light.energy = 0.0

	if is_instance_valid(ring_sprite):
		ring_sprite.scale = Vector2.ZERO

func _ensure_timer(node_name: String, wait: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait
		t.one_shot  = one_shot
		add_child(t)

func _connect_signals() -> void:
	if has_node("DurationTimer"):
		$DurationTimer.timeout.connect(_on_duration_expired)
	if has_node("CooldownTimer"):
		$CooldownTimer.timeout.connect(func(): can_activate = true)
	if is_instance_valid(aura_area):
		aura_area.body_entered.connect(_on_aura_body_entered)
	## Listen for player dash to auto-activate (if ability unlocked)
	if _player and _player.has_signal("dashed"):
		_player.dashed.connect(_on_player_dashed)

# ─── ACTIVATION ───────────────────────────────────────────────────────────────
func activate() -> void:
	if is_active or not can_activate:
		return
	if not GameManager.has_ability("shield_aura"):
		return

	is_active   = true
	can_activate = false
	_hit_this_activation.clear()

	set_active(true)
	$DurationTimer.start()
	$CooldownTimer.start()

	## Make player invincible
	if _player and _player.has_method("set"):
		_player.set("is_invincible", true)

	shield_activated.emit()
	AudioManager.play_sfx("signal_pulse")

	## Expand ring animation
	if is_instance_valid(ring_sprite):
		ring_sprite.scale = Vector2.ZERO
		ring_sprite.play("activate")
		var tween := create_tween()
		tween.tween_property(ring_sprite, "scale",
			Vector2.ONE * RING_SCALE_MAX, 0.35).set_ease(Tween.EASE_OUT)

	if is_instance_valid(shield_light):
		var tween2 := create_tween()
		tween2.tween_property(shield_light, "energy", 2.5, 0.2)

	_log("ECHO SHIELD activated | duration: %.1fs" % SHIELD_DURATION)

func set_active(value: bool) -> void:
	if is_instance_valid(ring_sprite):
		ring_sprite.visible = value
	if is_instance_valid(aura_area):
		aura_area.monitoring = value

func _on_duration_expired() -> void:
	is_active = false

	## Remove invincibility from player unless they got it from dash
	if _player and _player.has_method("get") and not _player.get("is_dashing"):
		_player.set("is_invincible", false)

	set_active(false)
	shield_expired.emit()

	## Shrink ring
	if is_instance_valid(ring_sprite):
		var tween := create_tween()
		tween.tween_property(ring_sprite, "scale", Vector2.ZERO, 0.25)

	if is_instance_valid(shield_light):
		var tween2 := create_tween()
		tween2.tween_property(shield_light, "energy", 0.0, 0.3)

	_log("ECHO SHIELD expired")

func _on_player_dashed(_direction: Vector2) -> void:
	## Dash auto-triggers shield if available
	if GameManager.has_ability("shield_aura") and can_activate:
		activate()

func _on_aura_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body in _hit_this_activation:
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		_hit_this_activation.append(body)
		body.take_damage(CONTACT_DAMAGE, "EchoShield_aura")
		_log("Aura contact damage on: %s" % body.name)

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[EchoShield] %s" % msg)
