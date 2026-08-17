# CodexManager.gd - Lore database, intel unlock system
extends Node

signal entry_unlocked(entry_id: String, category: String)
signal category_completed(category: String)

@export var codex_data_path: String = "res://data/codex.json"

var codex_db: Dictionary = {}
var unlocked_entries: Dictionary = {}
var categories: Array[String] = ["pillars", "characters", "locations", "events", "tech"]

func _ready():
    _load_codex()
    Director.ai_evolved.connect(_on_ai_evolution)

func _load_codex() -> void:
    if FileAccess.file_exists(codex_data_path):
        var file = FileAccess.open(codex_data_path, FileAccess.READ)
        var json_text = file.get_as_text()
        file.close()
        var parsed = JSON.parse_string(json_text)
        if parsed:
            codex_db = parsed
            DebugTools.log("CodexManager: Loaded %d entries" % codex_db.size())
    else:
        _generate_default_codex()

func _generate_default_codex() -> void:
    codex_db = {
        "pillar_sovereignty": {
            "category": "pillars",
            "title": "Pillar of Sovereignty",
            "desc": "Antarctic Core — Master control node, reality firewall. Dormant, awakening sequence initiated.",
            "locked": true
        },
        "geologos": {
            "category": "tech",
            "title": "GeoLogos System",
            "desc": "Living intelligence woven into Earth's geology. Communicates via tectonic resonances.",
            "locked": true
        },
        "uridium_flip": {
            "category": "tech",
            "title": "Uridium Flip Mechanic",
            "desc": "Core mobility tech allowing instant 180° reversal. Powers the Sol Suit propulsion.",
            "locked": false
        }
    }
    _save_codex()

func _save_codex() -> void:
    var file = FileAccess.open(codex_data_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(codex_db, "\t"))
    file.close()

func unlock_entry(entry_id: String) -> bool:
    if entry_id in codex_db and codex_db[entry_id].get("locked", false):
        codex_db[entry_id]["locked"] = false
        unlocked_entries[entry_id] = true
        var cat = codex_db[entry_id].get("category", "unknown")
        entry_unlocked.emit(entry_id, cat)
        DebugTools.log("CODEX UNLOCKED: %s" % codex_db[entry_id].get("title", entry_id))
        _check_category_completion(cat)
        _save_codex()
        return true
    return false

func _check_category_completion(category: String) -> void:
    var total = 0
    var unlocked_count = 0
    for entry_id in codex_db:
        if codex_db[entry_id].get("category") == category:
            total += 1
            if not codex_db[entry_id].get("locked", false):
                unlocked_count += 1
    if total > 0 and unlocked_count == total:
        category_completed.emit(category)
        DebugTools.log("CODEX CATEGORY COMPLETE: %s" % category)

func get_entry(entry_id: String) -> Dictionary:
    return codex_db.get(entry_id, {})

func is_unlocked(entry_id: String) -> bool:
    return not codex_db.get(entry_id, {}).get("locked", true)

func _on_ai_evolution(agent_id: String, state: String) -> void:
    unlock_entry("geologos")
