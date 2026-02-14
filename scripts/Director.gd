extends Node
class_name Director

var tension: float = 0.0
var player: Node

func _ready():
\tplayer = get_tree().get_first_node_in_group("player")

func _process(delta):
\tupdate_tension()
\tadjust_difficulty()

func update_tension():
\tif player.health < 30:
\t\ttension += delta * 2
\telse:
\t\ttension -= delta

func adjust_difficulty():
\tGlobal.loot_multiplier = 1.0 + tension * 0.1
\tGlobal.enemy_spawn_rate = 1.0 + tension * 0.05