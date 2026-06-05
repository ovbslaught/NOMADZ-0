## AbilityPickup.gd
## Area2D — NOMADZ: Signal Descent
## NOMADZ ability unlock station. Interact to absorb ability data from station.
## Metroid Fusion style: locked behind lore paywall / boss gate.
## VultureCode / Sol / NOMADZ Universe

class_name AbilityPickup
extends Area2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var ability_id     : String = ""
@export var lore_entry_id  : String = ""   ## Plays lore before unlock
@export var requires_boss_defeated: String = ""  ## Fragment ID that gates this pickup

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite        : AnimatedSprite2D  = $AnimatedSprite2D
@onready var station_light : PointLight2D      = $StationLight
@onready var prompt_label  : Label             = $PromptLabel
@onready var interact_area : Area2D            = $InteractRange

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false
var _absorbed    : bool = false
var _player_near : bool = false

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	if ability_id.is_empty():
		push_error("AbilityPickup: ability_id not set on '%s'" % name)
		return

	## Already unlocked
	if GameManager.has_ability(ability_id):
		_set_absorbed_state()
		return

	add_to_group("interactable")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_instance_valid(prompt_label):
		prompt_label.visible = false
		prompt_label.text    = "[F] ABSORB — %s" % GameManager.ABILITIES.get(ability_id, ability_id)

	if is_instance_valid(station_light):
		station_light.color  = Color(0.2, 0.6, 1.0)
		station_light.energy = 1.5

func _set_absorbed_state() -> void:
	_absorbed = true
	if is_instance_valid(station_light):
		station_light.energy = 0.2
		station_light.color  = Color(0.3, 0.3, 0.3)
	if is_instance_valid(sprite):
		sprite.play("absorbed")

# ─── INTERACT ─────────────────────────────────────────────────────────────────
func on_interact(_player: Node) -> void:
	if _absorbed:
		return

	## Gate check
	if not requires_boss_defeated.is_empty():
		if not GameManager.collected_fragments.has(requires_boss_defeated):
			if DEBUG_MODE:
				print("[AbilityPickup] Gated — need fragment: %s" % requires_boss_defeated)
			return

	_absorb()

func _absorb() -> void:
	_absorbed = true
	GameManager.unlock_ability(ability_id)
	AudioManager.play_sfx("ability_unlock")

	if not lore_entry_id.is_empty():
		GameManager.collect_lore(lore_entry_id)

	_set_absorbed_state()
	if is_instance_valid(prompt_label):
		prompt_label.visible = false

	## Big flash
	if is_instance_valid(station_light):
		var tween := create_tween()
		tween.tween_property(station_light, "energy", 5.0, 0.2)
		tween.tween_property(station_light, "energy", 0.2, 1.0)

	if DEBUG_MODE:
		print("[AbilityPickup] Absorbed: %s" % ability_id)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		if is_instance_valid(prompt_label) and not _absorbed:
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		if is_instance_valid(prompt_label):
			prompt_label.visible = false
