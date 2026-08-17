extends Node
# NOMADZ: AI Scripting Bridge for Godot

const BRAIN_FOOD_PATH = "user://../../../../sdcard/BRAIN-HOLE/BRAIN-FOOD/"
const PROJECT_SCRIPTS_PATH = "res://scripts/generated/"

func _ready():
	# Ensure the generated directory exists
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scripts/generated"):
		dir.make_dir_recursive("scripts/generated")

func request_script(prompt: String, script_name: String):
	# 1. Write the prompt to BRAIN-FOOD for the Daemon to catch
	var file = FileAccess.open(BRAIN_FOOD_PATH + script_name + ".request", FileAccess.WRITE)
	if file:
		file.store_string(prompt)
		file.close()
		print("NOMADZ: Script request sent to BRAIN-HOLE: ", script_name)
	else:
		print("ERROR: Could not reach BRAIN-HOLE substrate.")

func ingest_generated_script(script_name: String, code: String):
	# 2. Save code received from AI into the Godot project
	var file = FileAccess.open(PROJECT_SCRIPTS_PATH + script_name + ".gd", FileAccess.WRITE)
	if file:
		file.store_string(code)
		file.close()
		print("NOMADZ: New AI Script Injected: ", script_name)
