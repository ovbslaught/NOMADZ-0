class_name TopDownHUD
extends CanvasLayer

@onready var hp_hearts := $HBoxContainer/Hearts
@onready var magic_bar := $HBoxContainer/MagicBar
@onready var rupee_label := $HBoxContainer/Rupees
@onready var key_label := $HBoxContainer/Keys
@onready var weapon_label := $HBoxContainer/WeaponLabel
@onready var item_slot := $HBoxContainer/ItemSlot

func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	hide()

func show() -> void:
	visible = true
	_update_all()

func _on_health_changed(_current: int, _maximum: int) -> void:
	_update_hearts()

func _update_all() -> void:
	_update_hearts()
	_update_rupees()
	_update_keys()
	_update_weapon()

func _update_hearts() -> void:
	var player := get_tree().get_first_node_in_group("player") as TopDownPlayer
	if not player or not is_instance_valid(hp_hearts): return
	var text := ""
	for i in player.max_health:
		if i < player.health: text += "\u2665 "
		else: text += "\u2661 "
	hp_hearts.text = text.strip_edges()

func _update_rupees() -> void:
	var player := get_tree().get_first_node_in_group("player") as TopDownPlayer
	if not player: return
	rupee_label.text = "\u25C8 %d" % player.rupees

func _update_keys() -> void:
	var player := get_tree().get_first_node_in_group("player") as TopDownPlayer
	if not player: return
	key_label.text = "\u26BF %d" % player.keys

func _update_weapon() -> void:
	var player := get_tree().get_first_node_in_group("player") as TopDownPlayer
	if not player: return
	var names := {0: "SWORD", 1: "BOW", 2: "FIRE", 3: "ICE", 4: "LIGHTNING"}
	weapon_label.text = names.get(player.current_weapon, "SWORD")
