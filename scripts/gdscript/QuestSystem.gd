extends Node
# QuestSystem - Procedural quest generation and management
# Generates dynamic quests based on game state, resources, and agent behaviors

class_name QuestSystem

enum QuestType {
	EXPLORE,
	MINE,
	TRADE,
	COMBAT,
	DIPLOMACY,
	RESEARCH,
	ARCADE_CHALLENGE
}

enum QuestDifficulty {
	EASY,
	MEDIUM,
	HARD,
	EXTREME
}

var active_quests = []
var completed_quests = []
var quest_templates = {}
var quest_id_counter = 0

func _ready():
	print("[QuestSystem] Initializing...")
	_load_quest_templates()

func _load_quest_templates():
	# Exploration quests
	quest_templates[QuestType.EXPLORE] = [
		{"title": "Discover the Unknown", "desc": "Explore {count} uncharted planets", "reward": 1000},
		{"title": "System Survey", "desc": "Map the entire {system_name} system", "reward": 2500},
		{"title": "First Contact", "desc": "Find a new civilization", "reward": 5000}
	]
	
	# Mining quests
	quest_templates[QuestType.MINE] = [
		{"title": "Resource Rush", "desc": "Mine {amount} units of {resource}", "reward": 800},
		{"title": "Exotic Harvest", "desc": "Extract rare Exotics from {planet}", "reward": 3000}
	]
	
	# Trade quests
	quest_templates[QuestType.TRADE] = [
		{"title": "Trade Route", "desc": "Establish trade between {planet_a} and {planet_b}", "reward": 1500},
		{"title": "Market Manipulation", "desc": "Control {resource} prices", "reward": 4000}
	]
	
	# Arcade challenge quests
	quest_templates[QuestType.ARCADE_CHALLENGE] = [
		{"title": "Retro Master", "desc": "Achieve mastery in {arcade_system} games", "reward": 2000},
		{"title": "High Score Hunt", "desc": "Beat the high score in {game_name}", "reward": 1000},
		{"title": "Arcade Marathon", "desc": "Play {count} different arcade games", "reward": 3500}
	]

func generate_quest(type: int = -1, difficulty: int = QuestDifficulty.MEDIUM) -> Dictionary:
	"""Generate a new procedural quest"""
	if type == -1:
		type = randi() % QuestType.size()
		
	var templates = quest_templates.get(type, [])
	if templates.size() == 0:
		return {}
		
	var template = templates[randi() % templates.size()].duplicate()
	var quest = {
		"id": quest_id_counter,
		"type": type,
		"difficulty": difficulty,
		"title": template["title"],
		"description": _fill_template(template["desc"], type),
		"reward": int(template["reward"] * _difficulty_multiplier(difficulty)),
		"progress": 0.0,
		"target": 100.0,
		"active": true,
		"timestamp": OS.get_ticks_msec()
	}
	
	quest_id_counter += 1
	active_quests.append(quest)
	print("[QuestSystem] Generated quest: ", quest["title"])
	return quest

func _fill_template(template: String, type: int) -> String:
	"""Fill quest template with procedural data"""
	var filled = template
	
	# Replace placeholders
	filled = filled.replace("{count}", str(randi() % 5 + 1))
	filled = filled.replace("{amount}", str(randi() % 1000 + 500))
	filled = filled.replace("{system_name}", _random_system_name())
	filled = filled.replace("{planet}", _random_planet_name())
	filled = filled.replace("{planet_a}", _random_planet_name())
	filled = filled.replace("{planet_b}", _random_planet_name())
	filled = filled.replace("{resource}", _random_resource())
	filled = filled.replace("{arcade_system}", _random_arcade_system())
	filled = filled.replace("{game_name}", _random_game_name())
	
	return filled

func _difficulty_multiplier(difficulty: int) -> float:
	match difficulty:
		QuestDifficulty.EASY: return 0.5
		QuestDifficulty.MEDIUM: return 1.0
		QuestDifficulty.HARD: return 2.0
		QuestDifficulty.EXTREME: return 4.0
		_: return 1.0

func _random_system_name() -> String:
	var names = ["Alpha Centauri", "Betelgeuse", "Sirius", "Vega", "Rigel", "Procyon"]
	return names[randi() % names.size()]

func _random_planet_name() -> String:
	var names = ["Nexus Prime", "Void Station", "Crystal Haven", "Terra Nova", "Obsidian", "Elysium"]
	return names[randi() % names.size()]

func _random_resource() -> String:
	var resources = ["Metals", "Crystals", "Energy", "Organics", "Exotics", "Data"]
	return resources[randi() % resources.size()]

func _random_arcade_system() -> String:
	var systems = ["NES", "SNES", "Genesis", "Arcade", "N64", "PS1"]
	return systems[randi() % systems.size()]

func _random_game_name() -> String:
	var games = ["Galactic Runner", "Void Fighter", "Crystal Quest", "Nebula Racer"]
	return games[randi() % games.size()]

func update_quest_progress(quest_id: int, progress: float):
	for quest in active_quests:
		if quest["id"] == quest_id:
			quest["progress"] = min(progress, quest["target"])
			if quest["progress"] >= quest["target"]:
				_complete_quest(quest)
			return

func _complete_quest(quest: Dictionary):
	quest["active"] = false
	quest["completed_time"] = OS.get_ticks_msec()
	completed_quests.append(quest)
	active_quests.erase(quest)
	print("[QuestSystem] Quest completed: ", quest["title"], " | Reward: ", quest["reward"])
	# Trigger reward distribution
	_distribute_reward(quest)

func _distribute_reward(quest: Dictionary):
	pass  # Integrate with ResourceManager

func get_active_quests() -> Array:
	return active_quests

func get_quest_by_id(quest_id: int) -> Dictionary:
	for quest in active_quests:
		if quest["id"] == quest_id:
			return quest
	return {}
