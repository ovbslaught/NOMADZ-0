## Projectile.gd
## Area2D — NOMADZ: Signal Descent
## NORA's signal shot. Damages enemies. Passes through Phantoms (needs Signal Pulse instead).
## VultureCode / Sol / NOMADZ Universe

class_name Projectile
extends Area2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var damage      : int   = 10
@export var speed       : float = 400.0
@export var lifetime    : float = 1.2
@export var pierce      : bool  = false   ## Passes through multiple enemies

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite    : AnimatedSprite2D = $AnimatedSprite2D
@onready var proj_light: PointLight2D     = $ProjectileLight
@onready var life_timer: Timer            = $LifetimeTimer

# ─── STATE ────────────────────────────────────────────────────────────────────
var direction     : Vector2 = Vector2.RIGHT
var _hit_enemies  : Array   = []   ## For pierce — track already-hit

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	_ensure_timer("LifetimeTimer", lifetime, true)
	$LifetimeTimer.timeout.connect(queue_free)
	$LifetimeTimer.start()

	if is_instance_valid(proj_light):
		proj_light.color  = Color(0.3, 0.7, 1.0)
		proj_light.energy = 0.8

func _ensure_timer(node_name: String, wait_time: float, one_shot: bool) -> void:
	if not has_node(node_name):
		var t := Timer.new()
		t.name = node_name
		t.wait_time = wait_time
		t.one_shot  = one_shot
		add_child(t)

## Called by Player when spawning
func fire(dir: Vector2, fire_speed: float = speed, fire_damage: int = damage) -> void:
	direction = dir.normalized()
	speed     = fire_speed
	damage    = fire_damage
	rotation  = direction.angle()

# ─── PHYSICS ─────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	position += direction * speed * delta

# ─── COLLISION ────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemy") or body.has_method("take_damage"):
		_hit_target(body)
	elif body.is_in_group("terrain"):
		_impact()

func _on_area_entered(area: Area2D) -> void:
	## Boss core hitbox
	if area.is_in_group("boss_core"):
		var boss := area.get_parent()
		if boss and boss.has_method("take_damage"):
			boss.take_damage(damage)
		_impact()

func _hit_target(target: Node2D) -> void:
	if target in _hit_enemies:
		return
	_hit_enemies.append(target)

	if target.has_method("take_damage"):
		target.take_damage(damage, "PlayerProjectile")

	if not pierce:
		_impact()

func _impact() -> void:
	## Flash and die
	if is_instance_valid(sprite):
		sprite.play("impact")
	if is_instance_valid(proj_light):
		proj_light.energy = 2.0
	await get_tree().create_timer(0.08).timeout
	queue_free()
