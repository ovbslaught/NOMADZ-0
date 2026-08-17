## BossTransitionTrigger.gd
## Area2D — NOMADZ: Signal Descent
## Placed at the entrance of a boss room. Locks the door behind player,
## starts music, shows boss HP bar, triggers boss intro cutscene.
## Metroid Fusion style: no escape once entered.
## VultureCode / Sol / NOMADZ Universe

class_name BossTransitionTrigger
extends Area2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var boss_name         : String = "VULTURE-EYE"
@export var boss_node_path    : NodePath = NodePath("")
@export var door_behind_path  : NodePath = NodePath("")
@export var music_layer       : String = "boss"

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var seal_light : PointLight2D = $SealLight

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := true
var _triggered   : bool = false

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_instance_valid(seal_light):
		seal_light.visible = false

func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	_trigger_boss_sequence(body)

func _trigger_boss_sequence(player: Node2D) -> void:
	## Lock door behind
	var door := get_node_or_null(door_behind_path)
	if is_instance_valid(door) and door.has_method("lock"):
		door.lock()
		if is_instance_valid(seal_light):
			seal_light.visible = true
			seal_light.color   = Color(1.0, 0.1, 0.1)
			seal_light.energy  = 2.0

	## Start boss music
	AudioManager.play_music(music_layer)

	## Get boss node
	var boss := get_node_or_null(boss_node_path)
	if boss == null:
		push_warning("BossTransitionTrigger: boss node not found at '%s'" % str(boss_node_path))
		return

	## Show boss HP bar
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	for hud in hud_nodes:
		if hud.has_method("show_boss_bar"):
			hud.show_boss_bar(boss_name, boss.get("MAX_HEALTH") if boss.get("MAX_HEALTH") else 300)

	## Connect boss signals to HUD
	if boss.has_signal("boss_damaged"):
		for hud in hud_nodes:
			if hud.has_method("update_boss_bar"):
				boss.boss_damaged.connect(hud.update_boss_bar)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

	## Screen flash
	SignalverseManager.force_bleed("screen_tear")

	if DEBUG_MODE:
		print("[BossTransitionTrigger] Boss sequence started: %s" % boss_name)

func _on_boss_defeated() -> void:
	## Unlock door
	var door := get_node_or_null(door_behind_path)
	if is_instance_valid(door) and door.has_method("unlock"):
		door.unlock()
	if is_instance_valid(seal_light):
		var tween := create_tween()
		tween.tween_property(seal_light, "energy", 0.0, 1.0)

	## Hide boss bar
	var hud_nodes := get_tree().get_nodes_in_group("hud")
	for hud in hud_nodes:
		if hud.has_method("hide_boss_bar"):
			await get_tree().create_timer(3.0).timeout
			hud.hide_boss_bar()

	if DEBUG_MODE:
		print("[BossTransitionTrigger] Boss defeated — door unlocked")
