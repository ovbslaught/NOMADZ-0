## LoreNode.gd
## Area2D — NOMADZ: Signal Descent
## BRAIN-FOOD lore terminal. Interact to unlock a LoreDatabase entry.
## Animal Well-style: found in unexpected places, rewards exploration.
## VultureCode / Sol / NOMADZ Universe

class_name LoreNode
extends Area2D

@export var entry_id     : String = ""
@export var glow_color   : Color  = Color(0.4, 0.8, 1.0)
@export var auto_discover: bool   = false  ## Discovered on room entry, not interact

@onready var sprite      : AnimatedSprite2D = $AnimatedSprite2D
@onready var node_light  : PointLight2D     = $NodeLight
@onready var prompt_label: Label            = $PromptLabel

const DEBUG_MODE := false
var _read        : bool = false

func _ready() -> void:
	if entry_id.is_empty():
		push_error("LoreNode: entry_id not set on '%s'" % name)
		return

	add_to_group("interactable")

	if LoreDatabase.is_discovered(entry_id):
		_set_read_state()
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if is_instance_valid(node_light):
		node_light.color  = glow_color
		node_light.energy = 1.0

	if is_instance_valid(prompt_label):
		prompt_label.visible = false
		prompt_label.text    = "[F] DOWNLOAD LOG"

	if auto_discover:
		_discover()

func on_interact(_player: Node) -> void:
	if _read:
		return
	_discover()

func _discover() -> void:
	_read = true
	var entry := LoreDatabase.get_entry(entry_id)
	GameManager.collect_lore(entry_id)
	AudioManager.play_sfx("collect_lore")
	_set_read_state()

	if DEBUG_MODE:
		print("[LoreNode] Read: %s — %s" % [entry_id, entry.get("title", "?")])

func _set_read_state() -> void:
	_read = true
	if is_instance_valid(node_light):
		node_light.energy = 0.25
		node_light.color  = Color(0.3, 0.3, 0.4)
	if is_instance_valid(sprite):
		sprite.play("read")
	if is_instance_valid(prompt_label):
		prompt_label.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _read:
		if is_instance_valid(prompt_label):
			prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if is_instance_valid(prompt_label):
			prompt_label.visible = false
