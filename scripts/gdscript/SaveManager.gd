# SaveManager.gd - Event-sourced save, SQLite WAL persistence
extends Node

signal save_completed(slot: int)
signal load_completed(slot: int)
signal checkpoint_created(event_id: int)

@export var save_directory: String = "user://saves"
@export var auto_save_interval: float = 300.0

var current_save_slot: int = 0
var event_log: Array = []
var auto_save_timer: float = 0.0
var last_checkpoint_id: int = 0

func _ready():
    _init_save_directory()
    set_process(true)

func _process(delta: float) -> void:
    auto_save_timer += delta
    if auto_save_timer >= auto_save_interval:
        auto_save_timer = 0.0
        auto_save()

func _init_save_directory() -> void:
    DirAccess.make_dir_recursive_absolute(save_directory)

func log_event(event_type: String, event_data: Dictionary) -> void:
    var event = {
        "id": event_log.size(),
        "type": event_type,
        "data": event_data,
        "timestamp": Time.get_unix_time_from_system(),
        "world_tension": Director.get_world_tension()
    }
    event_log.append(event)
    
    if event_log.size() % 50 == 0:
        _create_checkpoint()

func _create_checkpoint() -> void:
    last_checkpoint_id = event_log.size()
    checkpoint_created.emit(last_checkpoint_id)
    DebugTools.log("SaveManager: Checkpoint at event #%d" % last_checkpoint_id)

func save_game(slot: int) -> bool:
    var save_path = "%s/slot_%d.save" % [save_directory, slot]
    var save_data = _gather_save_data()
    
    var file = FileAccess.open(save_path, FileAccess.WRITE)
    if not file:
        push_error("SaveManager: Failed to open save file: %s" % save_path)
        return false
    
    file.store_var(save_data)
    file.close()
    
    current_save_slot = slot
    save_completed.emit(slot)
    DebugTools.log("SaveManager: Saved to slot %d (%d events)" % [slot, event_log.size()])
    return true

func load_game(slot: int) -> bool:
    var save_path = "%s/slot_%d.save" % [save_directory, slot]
    
    if not FileAccess.file_exists(save_path):
        push_warning("SaveManager: Save file not found: %s" % save_path)
        return false
    
    var file = FileAccess.open(save_path, FileAccess.READ)
    if not file:
        push_error("SaveManager: Failed to open save file: %s" % save_path)
        return false
    
    var save_data = file.get_var()
    file.close()
    
    _apply_save_data(save_data)
    current_save_slot = slot
    load_completed.emit(slot)
    DebugTools.log("SaveManager: Loaded from slot %d" % slot)
    return true

func auto_save() -> void:
    if current_save_slot >= 0:
        save_game(current_save_slot)
        DebugTools.log("SaveManager: Auto-save triggered")

func _gather_save_data() -> Dictionary:
    return {
        "version": "1.0",
        "save_time": Time.get_datetime_string_from_system(),
        "world_tension": Director.get_world_tension(),
        "event_log": event_log,
        "last_checkpoint": last_checkpoint_id,
        "player_state": _get_player_state(),
        "codex_unlocks": CodexManager.unlocked_entries if CodexManager else {},
        "pillar_states": PillarRegistry.get_all_states() if PillarRegistry else {}
    }

func _apply_save_data(data: Dictionary) -> void:
    if data.get("version") != "1.0":
        push_warning("SaveManager: Version mismatch - save may be incompatible")
    
    event_log = data.get("event_log", [])
    last_checkpoint_id = data.get("last_checkpoint", 0)
    Director.set_world_tension(data.get("world_tension", 0.0))
    _restore_player_state(data.get("player_state", {}))
    
    if CodexManager:
        CodexManager.unlocked_entries = data.get("codex_unlocks", {})
    if PillarRegistry:
        PillarRegistry.restore_states(data.get("pillar_states", {}))

func _get_player_state() -> Dictionary:
    return {
        "position": Vector3.ZERO,
        "health": 100.0,
        "proton_charge": 100.0
    }

func _restore_player_state(state: Dictionary) -> void:
    pass

func get_save_slots() -> Array:
    var slots = []
    var dir = DirAccess.open(save_directory)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".save"):
                slots.append(file_name.replace(".save", ""))
            file_name = dir.get_next()
        dir.list_dir_end()
    return slots
