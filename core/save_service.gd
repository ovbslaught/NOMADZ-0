extends Node
# Auto-save + manual save to user://save_slot_N.cfg
# Dirty flag prevents write spam.

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 3

var _dirty: bool = false
var _active_slot: int = 0

signal saved(slot: int)
signal loaded(slot: int)

func _ready() -> void:
    DirAccess.make_dir_absolute(SAVE_DIR)

func mark_dirty() -> void:
    _dirty = true

func auto_save() -> void:
    if _dirty:
        save(_active_slot)

func save(slot: int = 0) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("meta","slot", slot)
    cfg.set_value("meta","timestamp", Time.get_unix_time_from_system())
    cfg.set_value("era","current", EraClock.current_era)
    cfg.set_value("flags","data", EventFlags.export_flags())
    cfg.set_value("upgrades","list", UpgradeInventory.export())
    cfg.set_value("quest","log", QuestMemory.export())
    cfg.save(SAVE_DIR + "slot_%d.cfg" % slot)
    _dirty = false
    emit_signal("saved", slot)

func load_slot(slot: int = 0) -> bool:
    var path := SAVE_DIR + "slot_%d.cfg" % slot
    var cfg := ConfigFile.new()
    if cfg.load(path) != OK:
        return false
    EraClock.set_era(cfg.get_value("era","current", 0))
    EventFlags.import_flags(cfg.get_value("flags","data", {}))
    UpgradeInventory.import(cfg.get_value("upgrades","list", []))
    QuestMemory.import(cfg.get_value("quest","log", []))
    _active_slot = slot
    _dirty = false
    emit_signal("loaded", slot)
    return true

func slot_exists(slot: int) -> bool:
    return FileAccess.file_exists(SAVE_DIR + "slot_%d.cfg" % slot)
