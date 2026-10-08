## BleedPhantom.gd
## CharacterBody2D Enemy — NOMADZ: Signal Descent
## Signalverse construct. Replays the death loop of a fallen NOMADZ agent.
## Not conscious. Cannot learn. Find the gap in the loop.
## Spawned by SignalverseManager during bleed events.
## VultureCode / Sol / NOMADZ Universe

class_name BleedPhantom
extends CharacterBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal died(position: Vector2)
signal loop_completed()

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE  := false

const PHANTOM_SPEED : float = 100.0
const DAMAGE_AMOUNT : int   = 15
const MAX_HEALTH    : int   = 15        ## Weak — meant to be avoided, not fought
const LOOP_DURATION : float = 4.0      ## Full loop cycle time
const ATTACK_WINDOW : float = 0.6      ## Fraction of loop that is dangerous
const LIFETIME      : float = 25.0     ## Auto-despawn after N seconds

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var loop_path       : Array[Vector2] = []   ## Waypoints the phantom replays
@export var loop_offset_sec : float = 0.0           ## Start offset for variety

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite        : AnimatedSprite2D = $AnimatedSprite2D
@onready var phantom_light : PointLight2D     = $PhantomLight
@onready var lifetime_timer: Timer            = $LifetimeTimer
@onready var attack_area   : Area2D           = $AttackArea

# ─── STATE ────────────────────────────────────────────────────────────────────
var health      : int   = MAX_HEALTH
var loop_timer  : float = 0.0
var loop_index  : int   = 0
var is_attacking: bool  = false
var is_dead     : bool  = false
var _frame_count: int   = 0
var _opacity    : float = 0.0    ## Fade-in on spawn

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("enemies")
	add_to_group("phantoms")

	loop_timer = loop_offset_sec
	_build_default_path()
	_setup_nodes()
	_connect_signals()

	## Notify SignalverseManager a phantom exists
	if SignalverseManager:
		SignalverseManager.active_phantoms += 1

	_log("BleedPhantom spawned at %s" % str(global_position))

func _build_default_path() -> void:
	if not loop_path.is_empty():
		return
	## Default loop: a horizontal patrol if no path was injected
	var here := global_position
	loop_path = [
		here,
		here + Vector2(80, 0),
		here + Vector2(80, -40),
		here + Vector2(-80, -40),
		here + Vector2(-80, 0),
	]
	## Convert to local space
	for i in loop_path.size():
		loop_path[i] = loop_path[i] - global_position

func _setup_nodes() -> void:
	_ensure_timer("LifetimeTimer", LIFETIME, true)

	if is_instance_valid(phantom_light):
		phantom_light.color  = Color(0.5, 0.2, 1.0, 1.0)
		phantom_light.energy = 0.6

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

func _connect_signals() -> void:
	if has_node("LifetimeTimer"):
		$LifetimeTimer.start()
		$LifetimeTimer.timeout.connect(_on_lifetime_expired)
	if has_node("AttackArea"):
		attack_area.body_entered.connect(_on_attack_body_entered)
	SignalverseManager.bleed_event_triggered.connect(_on_bleed_event)

# ─── PHYSICS ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_frame_count += 1

	_tick_opacity(delta)
	_tick_loop(delta)
	move_and_slide()
	_update_visuals()

func _tick_opacity(delta: float) -> void:
	_opacity = minf(1.0, _opacity + delta * 1.5)
	if is_instance_valid(sprite):
		sprite.modulate.a = _opacity * 0.75  ## Phantoms are translucent

func _tick_loop(delta: float) -> void:
	loop_timer = fmod(loop_timer + delta, LOOP_DURATION)
	var progress := loop_timer / LOOP_DURATION         ## 0.0 – 1.0

	## Determine current waypoint
	var num_points := loop_path.size()
	if num_points < 2:
		return

	var seg_frac  := progress * float(num_points)
	var seg_idx   := int(seg_frac) % num_points
	var seg_t     := fmod(seg_frac, 1.0)
	var from_pos  := global_position + loop_path[seg_idx]
	var to_pos    := global_position + loop_path[(seg_idx + 1) % num_points]

	## Move toward next waypoint
	var target_pos := from_pos.lerp(to_pos, seg_t)
	var dir        := (target_pos - global_position)

	if dir.length() > 2.0:
		velocity = dir.normalized() * PHANTOM_SPEED
	else:
		velocity = Vector2.ZERO

	## Attack window: last 15% of the loop
	is_attacking = progress >= (1.0 - ATTACK_WINDOW)

	if is_attacking and (loop_timer - delta) / LOOP_DURATION < (1.0 - ATTACK_WINDOW):
		loop_completed.emit()
		AudioManager.play_sfx("bleed_glitch")

# ─── ATTACK ───────────────────────────────────────────────────────────────────
func _on_attack_body_entered(body: Node2D) -> void:
	if not is_attacking:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(DAMAGE_AMOUNT, "BleedPhantom_loop")
		_log("Loop attack connected")

# ─── DAMAGE ───────────────────────────────────────────────────────────────────
func take_damage(amount: int, source: String = "unknown") -> void:
	if is_dead:
		return
	health -= amount
	_flash_hit()
	_log("Took %d from %s | HP: %d" % [amount, source, health])
	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	died.emit(global_position)

	if SignalverseManager:
		SignalverseManager.on_phantom_destroyed()

	if is_instance_valid(sprite):
		sprite.play("death")

	## Fade out
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.8) if is_instance_valid(sprite) else null
	await get_tree().create_timer(0.9).timeout
	queue_free()

func _flash_hit() -> void:
	if not is_instance_valid(sprite):
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE * 2.0, 0.06)
	tween.tween_property(sprite, "modulate:a", 0.75, 0.08)

func _on_lifetime_expired() -> void:
	_log("Lifetime expired — dissolving")
	_die()

func _on_bleed_event(event_type: String, _payload: Dictionary) -> void:
	## Signal pulse destroys phantoms instantly
	if event_type == "signal_pulse_player":
		_die()

# ─── VISUALS ──────────────────────────────────────────────────────────────────
func _update_visuals() -> void:
	if is_instance_valid(phantom_light):
		var flicker := sin(Time.get_ticks_msec() * 0.015) * 0.3
		phantom_light.energy = (0.8 if is_attacking else 0.4) + flicker
		phantom_light.color  = Color(1.0, 0.2, 0.2) if is_attacking else Color(0.5, 0.2, 1.0)
	if is_instance_valid(sprite):
		sprite.play("attack" if is_attacking else "idle")

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[BleedPhantom | F%d] %s" % [_frame_count, msg])
