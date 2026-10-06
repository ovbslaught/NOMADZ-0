extends Node
class_name ShadowProfile

const SAVE_PATH := "user://shadowprofile.json"

var traits: Dictionary = {
    "aggression_vs_caution": 0.5,
    "melee_vs_ranged_ratio": 0.5,
    "healing_usage": 0.0,
    "boss_retry_pattern": 0,
    "movement_style": "balanced"
}

func _ready() -> void:
    load_profile()

func record_session_summary(summary: Dictionary) -> void:
    if summary.has("melee_hits"):
        traits["melee_vs_ranged_ratio"] = lerp(float(traits["melee_vs_ranged_ratio"]), float(summary["melee_hits"]) / max(1.0, float(summary.get("total_hits", 1))), 0.2)
    if summary.has("deaths"):
        traits["boss_retry_pattern"] = summary["deaths"]
    save_profile()

func get_trait_snapshot() -> Dictionary:
    return traits.duplicate()

func save_profile() -> void:
    var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(traits))

func load_profile() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
        if f:
            var parsed = JSON.parse_string(f.get_as_text())
            if parsed is Dictionary:
                traits.merge(parsed, true)
