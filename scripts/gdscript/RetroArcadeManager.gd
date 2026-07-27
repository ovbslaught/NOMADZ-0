extends Node
# RetroArcadeManager - Manages RetroArch arcade cabinets for in-game civilization agents
# Integrates libretro cores, ROMs, and learning systems for AI agents

class_name RetroArcadeManager

# RetroArch configuration paths
var retroarch_path = "C:/RetroArch" # Windows default
var cores_path = retroarch_path + "/cores"
var roms_path = retroarch_path + "/roms"
var config_path = retroarch_path + "/retroarch.cfg"
var bios_path = retroarch_path + "/system"

# Available libretro cores for different game systems
var available_cores = {
	"nes": "fceumm_libretro.dll",
	"snes": "snes9x_libretro.dll",
	"genesis": "genesis_plus_gx_libretro.dll",
	"arcade": "mame_libretro.dll",
	"gba": "mgba_libretro.dll",
	"ps1": "beetle_psx_hw_libretro.dll",
	"n64": "mupen64plus_next_libretro.dll",
	"doom": "prboom_libretro.dll",
	"scummvm": "scummvm_libretro.dll",
	"atari2600": "stella_libretro.dll"
}

# Arcade cabinets in the game world
var arcade_cabinets = []

# AI agent learning data
var agent_play_sessions = {}
var agent_skill_levels = {}

func _ready():
	print("[RetroArcadeManager] Initializing...")
	_detect_retroarch_installation()
	_scan_available_cores()
	_scan_roms()
	_initialize_arcade_cabinets()

func _detect_retroarch_installation():
	var dir = Directory.new()
	
	# Check Windows paths
	if dir.dir_exists("C:/RetroArch"):
		retroarch_path = "C:/RetroArch"
	elif dir.dir_exists("D:/RetroArch"):
		retroarch_path = "D:/RetroArch"
	elif dir.dir_exists("C:/Program Files/RetroArch"):
		retroarch_path = "C:/Program Files/RetroArch"
	else:
		print("[RetroArcadeManager] WARNING: RetroArch not found at default paths")
		return
	
	cores_path = retroarch_path + "/cores"
	roms_path = retroarch_path + "/roms"
	config_path = retroarch_path + "/retroarch.cfg"
	bios_path = retroarch_path + "/system"
	
	print("[RetroArcadeManager] Found RetroArch at: ", retroarch_path)

func _scan_available_cores():
	var dir = Directory.new()
	if not dir.dir_exists(cores_path):
		print("[RetroArcadeManager] Cores directory not found")
		return
	
	if dir.open(cores_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var found_cores = []
		
		while file_name != "":
			if file_name.ends_with("_libretro.dll") or file_name.ends_with("_libretro.so"):
				found_cores.append(file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
		print("[RetroArcadeManager] Found cores: ", found_cores.size())
		for core in found_cores:
			print("  - ", core)

func _scan_roms():
	var dir = Directory.new()
	if not dir.dir_exists(roms_path):
		print("[RetroArcadeManager] ROMs directory not found")
		return
	
	var rom_count = 0
	for system in available_cores.keys():
		var system_rom_path = roms_path + "/" + system
		if dir.dir_exists(system_rom_path):
			if dir.open(system_rom_path) == OK:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				
				while file_name != "":
					if not file_name.begins_with(".") and not dir.current_is_dir():
						rom_count += 1
					file_name = dir.get_next()
				
				dir.list_dir_end()
	
	print("[RetroArcadeManager] Total ROMs found: ", rom_count)

func _initialize_arcade_cabinets():
	# Create virtual arcade cabinets for each core type
	for system in available_cores.keys():
		var cabinet = {
			"id": "arcade_" + system,
			"system": system,
			"core": available_cores[system],
			"active_rom": null,
			"current_player": null,
			"play_sessions": 0,
			"total_playtime": 0.0,
			"position": Vector3.ZERO # Will be set by planet generator
		}
		arcade_cabinets.append(cabinet)
	
	print("[RetroArcadeManager] Initialized ", arcade_cabinets.size(), " arcade cabinets")

func launch_game(cabinet_id: String, rom_path: String, agent_id = null):
	"""Launch a RetroArch game on a specific cabinet"""
	var cabinet = _get_cabinet_by_id(cabinet_id)
	if not cabinet:
		print("[RetroArcadeManager] Cabinet not found: ", cabinet_id)
		return false
	
	# Build RetroArch command
	var core_path = cores_path + "/" + cabinet["core"]
	var retroarch_exe = retroarch_path + "/retroarch.exe"
	
	if not File.new().file_exists(retroarch_exe):
		print("[RetroArcadeManager] RetroArch executable not found")
		return false
	
	var args = [
		"-L", core_path,
		"-f", # Fullscreen
		rom_path
	]
	
	# If agent is playing, track the session
	if agent_id:
		if not agent_play_sessions.has(agent_id):
			agent_play_sessions[agent_id] = []
			agent_skill_levels[agent_id] = {}
		
		var session = {
			"cabinet": cabinet_id,
			"rom": rom_path,
			"start_time": OS.get_ticks_msec(),
			"score": 0,
			"actions": []
		}
		agent_play_sessions[agent_id].append(session)
	
	cabinet["active_rom"] = rom_path
	cabinet["current_player"] = agent_id
	cabinet["play_sessions"] += 1
	
	print("[RetroArcadeManager] Launching ", cabinet["system"], " game: ", rom_path)
	# OS.execute(retroarch_exe, args, false) # Uncomment for actual launch
	
	return true

func get_agent_learning_data(agent_id):
	"""Get AI agent's learning progress from arcade games"""
	if not agent_play_sessions.has(agent_id):
		return {"sessions": 0, "skills": {}}
	
	var sessions = agent_play_sessions[agent_id]
	var total_time = 0.0
	var game_experience = {}
	
	for session in sessions:
		var duration = (OS.get_ticks_msec() - session["start_time"]) / 1000.0
		total_time += duration
		
		var game_name = session["rom"].get_file()
		if not game_experience.has(game_name):
			game_experience[game_name] = {"plays": 0, "time": 0.0, "avg_score": 0}
		
		game_experience[game_name]["plays"] += 1
		game_experience[game_name]["time"] += duration
	
	return {
		"sessions": sessions.size(),
		"total_playtime": total_time,
		"games_played": game_experience,
		"skills": agent_skill_levels.get(agent_id, {})
	}

func simulate_ai_gameplay(agent_id, cabinet_id, duration_seconds: float):
	"""Simulate AI agent playing arcade game for learning"""
	var cabinet = _get_cabinet_by_id(cabinet_id)
	if not cabinet:
		return
	
	if not agent_skill_levels.has(agent_id):
		agent_skill_levels[agent_id] = {}
	
	var system = cabinet["system"]
	if not agent_skill_levels[agent_id].has(system):
		agent_skill_levels[agent_id][system] = 0.0
	
	# Skill increases with playtime (diminishing returns)
	var skill_gain = duration_seconds * 0.01 * (1.0 - agent_skill_levels[agent_id][system])
	agent_skill_levels[agent_id][system] += skill_gain
	agent_skill_levels[agent_id][system] = min(agent_skill_levels[agent_id][system], 1.0)
	
	cabinet["total_playtime"] += duration_seconds
	
	print("[RetroArcadeManager] Agent ", agent_id, " skill in ", system, ": ",
		  agent_skill_levels[agent_id][system])

func _get_cabinet_by_id(cabinet_id: String):
	for cabinet in arcade_cabinets:
		if cabinet["id"] == cabinet_id:
			return cabinet
	return null

func get_random_cabinet():
	if arcade_cabinets.size() > 0:
		return arcade_cabinets[randi() % arcade_cabinets.size()]
	return null

func get_cabinets_by_system(system: String):
	var results = []
	for cabinet in arcade_cabinets:
		if cabinet["system"] == system:
			results.append(cabinet)
	return results