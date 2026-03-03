extends Control
# PILLAR DISPLAY: Visualizes the 26 GEOLOGOS Pillars

@onready var registry = get_node("/root/PillarRegistry") # Adjust path as needed

func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"): # Press Enter to refresh
		_render_pillars()

func _render_pillars():
	var data = registry.pillar_data
	if data.is_empty():
		print("[UI] No data to display.")
		return
		
	print("--- CURRENT PILLAR STATES ---")
	for p_id in data["pillars"]:
		var p = data["pillars"][p_id]
		var status_icon = "🟢" if p["status"] == "ACTIVE" else "🔴"
		print("%s %s: %s (Weight: %f)" % [status_icon, p_id, p["core_trait"], p["weight"]])
