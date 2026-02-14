@tool
extends Button

const url = "https://docs.google.com/spreadsheets/d/1Zq9dHfiID-aZKq3OgCoVpq4HFZIgliYjeNWFo3Xmhn0/copy"

func _on_pressed() -> void:
	OS.shell_open(url)
