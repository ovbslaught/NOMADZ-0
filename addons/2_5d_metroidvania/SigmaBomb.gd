## SigmaBomb.gd
## Area2D — NOMADZ: Signal Descent
## SIGMA BOMB: thrown AOE device. Explodes with radius damage, stuns drones,
## destroys phantoms, and reveals hidden lore nodes within blast radius.
## Spawned by Player when ability unlocked. Inherits player's facing direction.
## VultureCode / Sol / NOMADZ Universe

class_name SigmaBomb
extends RigidBody2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal exploded(position: Vector2)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const BLAST_RADIUS  : float = 120.0
const DAMAGE_AMOUNT : int   = 40
const FUSE_TIME     : float = 1.5       ## Seconds before detonation
const THROW_FORCE   : float = 420.0
const BOUNCE_COUNT  : int   = 2         ## Max bounces before forced detonation
const GRAVITY_SCALE_VAL : float = 2.0

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite      : AnimatedSprite2D = $AnimatedSprite2D
@onready var bomb_light  : PointLight2D     = $BombLight
@onready var blast_area  : Area2D           = $BlastArea
@onready var fuse_timer  : Timer            = $FuseTimer
@onready var blast_particles: GPUParticles2D = $BlastParticles

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE   := false
var _bounces       : int    = 0
var _exploded      : bool   = false
var _fuse_elapsed  : float  = 0.0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	gravity_scale = GRAVITY_SCALE_VAL
	contact_monitor = true
	max_contacts_reported = 4

	_ensure_timer("FuseTimer", FUSE_TIME, true)
	$FuseTimer.timeout.connect(_detonate)
	$FuseTimer.start()

	if is_instance_valid(bomb_light):
		bomb_light.color  = Color(0.3, 0.8, 1.0)
		bomb_light.energy = 1.0

	if is_instance_valid(blast_area):
		var shape := CircleShape2D.new()
		shape.radius = BLAST_RADIUS
		var col      := CollisionShape2D.new()
		col.shape    = shape
		blast_area.add_child(col)

	body_entered.connect(_on_body_entered)
	_log("SigmaBomb armed | fuse: %.1fs" % FUSE_TIME)

func _ensure_timer(node_name: String, wait: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait
		t.one_shot  = one_shot
		add_child(t)

## Called by Player to throw the bomb
func throw(direction: Vector2, force: float = THROW_FORCE) -> void:
	apply_central_impulse(direction.normalized() * force)

# ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _exploded:
		return
	_fuse_elapsed += delta
	## Blink faster as fuse runs out
	var blink_rate := lerpf(2.0, 20.0, _fuse_elapsed / FUSE_TIME)
	if is_instance_valid(bomb_light):
		bomb_light.energy = 1.0 + sin(_fuse_elapsed * blink_rate) * 0.5

	## Spin sprite
	if is_instance_valid(sprite):
		sprite.rotation += delta * 4.0

func _on_body_entered(_body: Node2D) -> void:
	_bounces += 1
	if _bounces >= BOUNCE_COUNT:
		_detonate()

# ─── DETONATE ─────────────────────────────────────────────────────────────────
func _detonate() -> void:
	if _exploded:
		return
	_exploded = true
	freeze = true

	exploded.emit(global_position)
	AudioManager.play_sfx("signal_pulse")
	_apply_blast()

	if is_instance_valid(blast_particles):
		blast_particles.emitting = true

	if is_instance_valid(bomb_light):
		bomb_light.energy = 5.0
		bomb_light.color  = Color(1.0, 0.6, 0.1)

	if is_instance_valid(sprite):
		sprite.visible = false

	## Notify SignalverseManager — bomb blast counts as a bleed event reveal
	SignalverseManager.broadcast_event("sigma_bomb_blast", {"origin": global_position})

	await get_tree().create_timer(0.6).timeout
	queue_free()

func _apply_blast() -> void:
	if not is_instance_valid(blast_area):
		return

	## Get all overlapping bodies
	blast_area.monitoring = true
	await get_tree().process_frame

	var bodies := blast_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			continue  ## Does not damage NORA
		if body.is_in_group("enemy") and body.has_method("take_damage"):
			body.take_damage(DAMAGE_AMOUNT, "SigmaBomb")
			_log("Blast hit: %s" % body.name)

	var areas := blast_area.get_overlapping_areas()
	for area in areas:
		## Reveal hidden lore
		if area.is_in_group("hidden_lore"):
			area.call_deferred("reveal")
		## Boss core
		if area.is_in_group("boss_core"):
			var boss := area.get_parent()
			if boss and boss.has_method("take_damage"):
				boss.take_damage(DAMAGE_AMOUNT)

	blast_area.monitoring = false

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[SigmaBomb] %s" % msg)
