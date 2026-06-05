## EnemyDropper.gd
## Node — NOMADZ: Signal Descent
## Attach to any enemy to handle death loot drops.
## Configurable drop tables. Respects global state.
## VultureCode / Sol / NOMADZ Universe

class_name EnemyDropper
extends Node

const HEALTH_SMALL_SCENE := "res://collectibles/HealthPickupSmall.tscn"
const HEALTH_LARGE_SCENE := "res://collectibles/HealthPickupLarge.tscn"

@export var drop_health_small_chance: float = 0.30
@export var drop_health_large_chance: float = 0.08
@export var drop_lore_id            : String = ""
@export var drop_fragment_id        : String = ""

const DEBUG_MODE := false

var _parent_enemy : Node2D = null

func _ready() -> void:
	_parent_enemy = get_parent() as Node2D
	if _parent_enemy == null:
		push_error("EnemyDropper: must be child of a Node2D enemy")
		return

	## Connect to parent's died signal
	if _parent_enemy.has_signal("died"):
		_parent_enemy.died.connect(_on_parent_died)

func _on_parent_died(death_pos: Vector2) -> void:
	_try_drop(death_pos)

func _try_drop(pos: Vector2) -> void:
	## Lore drop (always, if configured)
	if not drop_lore_id.is_empty():
		GameManager.collect_lore(drop_lore_id)

	## Fragment drop (always, if configured)
	if not drop_fragment_id.is_empty():
		GameManager.collect_fragment(drop_fragment_id)

	## Health drops — probabilistic
	var roll := randf()
	if roll < drop_health_large_scene_chance():
		_spawn_pickup(HEALTH_LARGE_SCENE, pos)
		if DEBUG_MODE:
			print("[EnemyDropper] Dropped large health at %s" % str(pos))
	elif roll < drop_health_small_chance:
		_spawn_pickup(HEALTH_SMALL_SCENE, pos)
		if DEBUG_MODE:
			print("[EnemyDropper] Dropped small health at %s" % str(pos))

func drop_health_large_scene_chance() -> float:
	## Dynamic: higher chance when player is low HP
	var hp_pct := float(GameManager.current_health) / float(GameManager.MAX_HEALTH)
	return drop_health_large_chance * (1.0 + (1.0 - hp_pct) * 2.0)

func _spawn_pickup(scene_path: String, pos: Vector2) -> void:
	if not ResourceLoader.exists(scene_path):
		if DEBUG_MODE:
			print("[EnemyDropper] Pickup scene not found: %s" % scene_path)
		return
	var pickup := (load(scene_path) as PackedScene).instantiate()
	get_tree().current_scene.add_child(pickup)
	(pickup as Node2D).global_position = pos
