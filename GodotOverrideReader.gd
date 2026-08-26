# WORMHOLE/NOMADZ-0/scripts/physics/GodotOverrideReader.gd
extends Node
class_name GodotOverrideReader

@export var config_path: String = "res://config/physics_override.json"
signal overrides_applied(channel: String, k: float, dt: float)

func load_overrides(target_channel: String) -> void:
	if not FileAccess.file_exists(config_path):
		printerr("[ERROR] Physics override config missing: ", config_path)
		return
		
	var file = FileAccess.open(config_path, FileAccess.READ)
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		printerr("[ERROR] Failed to parse physics JSON config")
		return
		
	var data = json.get_data()
	if data.has("overrides") and data["overrides"].has(target_channel):
		var ch_data = data["overrides"][target_channel]
		emit_signal("overrides_applied", target_channel, ch_data["applied_spring_k"], ch_data["recommended_dt"])
		print("[GODOT] Applied telemetry override for ", target_channel, " | k: ", ch_data["applied_spring_k"])
