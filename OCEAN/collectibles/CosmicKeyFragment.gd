## CosmicKeyFragment.gd
## Area2D — NOMADZ: Signal Descent
## COSMIC KEY fragment. Collecting restores signal energy to MOTHER BRAIN link.
## Animal Well-style: each fragment is unique, has a lore entry, visual distinct.
## VultureCode / Sol / NOMADZ Universe

class_name CosmicKeyFragment
extends Area2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var fragment_id  : String = ""         ## Must be unique — used for save state
@export var lore_entry_id: String = ""         ## Optional linked lore unlock
@export var fragment_name: String = "Fragment" ## Display name in HUD popup
@export var signal_bonus : float  = 10.0       ## Signal energy added on collect
@export var float_height : float  = 6.0        ## Hover amplitude in pixels
@export var float_speed  : float  = 2.0        ## Hover cycles per second

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite      : AnimatedSprite2D = $AnimatedSprite2D
@onready var frag_light  : PointLight2D     = $FragmentLight
@onready var collect_particles: GPUParticles2D = $CollectParticles

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false
var _collected     : bool  = false
var _spawn_y       : float = 0.0
var _time          : float = 0.0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	if fragment_id.is_empty():
		push_error("CosmicKeyFragment: fragment_id not set on '%s'" % name)

	_spawn_y = position.y
	body_entered.connect(_on_body_entered)
	add_to_group("cosmic_fragments")

	## Skip if already collected
	if GameManager.collected_fragments.has(fragment_id):
		queue_free()
		return

	_setup_visuals()
	if DEBUG_MODE:
		print("[CosmicKeyFragment] Ready: %s" % fragment_id)

func _setup_visuals() -> void:
	if is_instance_valid(frag_light):
		frag_light.color  = Color(0.4, 0.8, 1.0)
		frag_light.energy = 1.2
	if is_instance_valid(sprite):
		sprite.play("idle")

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	## Hover float
	position.y = _spawn_y + sin(_time * float_speed * TAU) * float_height
	## Rotate light slightly
	if is_instance_valid(frag_light):
		frag_light.energy = 1.2 + sin(_time * 3.0) * 0.2

# ─── COLLECTION ───────────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return

	_collected = true
	_play_collect_effect()
	GameManager.collect_fragment(fragment_id)
	GameManager.add_signal_energy(signal_bonus)

	if not lore_entry_id.is_empty():
		GameManager.collect_lore(lore_entry_id)

	AudioManager.play_sfx("collect_fragment")

	if DEBUG_MODE:
		print("[CosmicKeyFragment] Collected: %s" % fragment_id)

func _play_collect_effect() -> void:
	## Disable physics, play particles, then free
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	if is_instance_valid(collect_particles):
		collect_particles.emitting = true

	var tween := create_tween()
	if is_instance_valid(sprite):
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.parallel().tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.5)
	if is_instance_valid(frag_light):
		tween.parallel().tween_property(frag_light, "energy", 0.0, 0.4)

	await get_tree().create_timer(0.8).timeout
	queue_free()
