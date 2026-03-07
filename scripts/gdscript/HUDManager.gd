extends CanvasLayer

# Main HUD manager for NOMADZ-0
# Handles health, stamina, inventory display, quest log

onready var health_bar = $MarginContainer/VBox/HealthBar
onready var stamina_bar = $MarginContainer/VBox/StaminaBar
onready var quest_panel = $QuestPanel
onready var inventory_grid = $InventoryPanel/Grid
onready var minimap = $Minimap

var player = null

func _ready():
    # Connect to player signals
    player = get_tree().get_nodes_in_group("player")[0]
    player.connect("health_changed", self, "_on_health_changed")
    player.connect("stamina_changed", self, "_on_stamina_changed")
    player.connect("inventory_updated", self, "_on_inventory_updated")
    
func _on_health_changed(current, maximum):
    health_bar.value = (float(current) / maximum) * 100
    health_bar.get_node("Label").text = str(current) + "/" + str(maximum)
    
func _on_stamina_changed(current, maximum):
    stamina_bar.value = (float(current) / maximum) * 100
    
func _on_inventory_updated(items):
    for child in inventory_grid.get_children():
        child.queue_free()
    for item in items:
        var slot = preload("res://scenes/ui/InventorySlot.tscn").instance()
        slot.set_item(item)
        inventory_grid.add_child(slot)
        
func update_quest_log(quests):
    quest_panel.get_node("List").clear()
    for quest in quests:
        quest_panel.get_node("List").add_item(quest.title)
