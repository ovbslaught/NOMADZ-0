## Door.gd
## Area2D — NOMADZ: Signal Descent
## Transition door. Supports: ability locks, enemy-clear locks, one-way doors.
## VultureCode / Sol / NOMADZ Universe

class_name Door
extends Area2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal player_entered_door(destination_room: String, spawn_marker: String)
signal door_locked()
signal door_unlocked()

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var destination_room   : String = ""
@export var destination_marker : String = "SpawnPoint"
@export var required_ability   : String = ""    ## Locks door if player lacks this
@export var locked_by_enemies  : bool   = false ## Locked until room enemies cleared
@export var one_way            : bool   = false ## Can only be entered from one side

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var sprite     : AnimatedSprite2D = $AnimatedSprite2D
@onready var lock_light : PointLight2D     = $LockLight
@onready var open_sfx   : AudioStreamPlayer = $OpenSFX

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false
var is_locked   : bool = false
var is_open     : bool = false

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_evaluate_lock_state()
	_update_visuals()

func _evaluate_lock_state() -> void:
	is_locked = false
	if not required_ability.is_empty():
		if not GameManager.has_ability(required_ability):
			is_locked = true
	if locked_by_enemies:
		is_locked = true

func unlock() -> void:
	if not is_locked:
		return
	is_locked = false
	door_unlocked.emit()
	_update_visuals()
	AudioManager.play_sfx("door_open")
	if DEBUG_MODE:
		print("[Door] Unlocked → %s" % destination_room)

func lock() -> void:
	is_locked = true
	door_locked.emit()
	_update_visuals()

# ─── TRIGGER ──────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_locked:
		_show_locked_feedback()
		return
	if destination_room.is_empty():
		push_error("Door: destination_room not set on '%s'" % name)
		return

	is_open = true
	player_entered_door.emit(destination_room, destination_marker)
	AudioManager.play_sfx("door_open")

func _show_locked_feedback() -> void:
	## Flash red to indicate locked
	if is_instance_valid(lock_light):
		var tween := create_tween()
		tween.tween_property(lock_light, "energy", 2.0, 0.1)
		tween.tween_property(lock_light, "energy", 0.6, 0.2)
	## Display hint if ability required
	if not required_ability.is_empty():
		var hint := GameManager.ABILITIES.get(required_ability, required_ability)
		if DEBUG_MODE:
			print("[Door] Locked — requires: %s" % hint)

func _update_visuals() -> void:
	if is_instance_valid(lock_light):
		lock_light.color  = Color(1.0, 0.1, 0.1) if is_locked else Color(0.1, 1.0, 0.3)
		lock_light.energy = 0.6
	if is_instance_valid(sprite):
		sprite.play("locked" if is_locked else "idle")
