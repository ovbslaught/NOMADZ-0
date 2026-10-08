#GameManager.gd
extends Node

##  GLOBAL PLAYER STATS & INVENTORY
var player_health: int = 100
var player_stamina: int = 100
var player_max_health: int = 100
var player_max_stamina: int = 100

var player_inventory: Array = []     # Nomadz Cards & items
var player_currency: int = 0

##  SIGNALS
signal card_collected(card_name: String)
signal player_stat_changed()

##  SAVE / LOAD
var save_path := "user://savegame.json"

func _ready():
	print("GameManager loaded.")
	load_game()

func add_card(card_name: String):
	if card_name not in player_inventory:
		player_inventory.append(card_name)
		emit_signal("card_collected", card_name)
		print("Collected card: %s" % card_name)

func add_currency(amount: int):
	player_currency += amount
	emit_signal("player_stat_changed")

func modify_health(amount: int):
	player_health = clamp(player_health + amount, 0, player_max_health)
	emit_signal("player_stat_changed")

func modify_stamina(amount: int):
	player_stamina = clamp(player_stamina + amount, 0, player_max_stamina)
	emit_signal("player_stat_changed")

func save_game():
	var data = {
		"hp": player_health,
		"stamina": player_stamina,
		"inventory": player_inventory,
		"currency": player_currency
	}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("Game saved.")

func load_game():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(data) == TYPE_DICTIONARY:
			player_health = data.get("hp", 100)
			player_stamina = data.get("stamina", 100)
			player_inventory = data.get("inventory", [])
			player_currency = data.get("currency", 0)
			print("Game loaded.")