extends Node
# Bitfield-style global flags. Keys are StringNames.
# Stored in save; loaded by SaveService.

var _flags: Dictionary = {}

signal flag_changed(key: StringName, value: bool)

func set_flag(key: StringName, value: bool = true) -> void:
    _flags[key] = value
    emit_signal("flag_changed", key, value)

func get_flag(key: StringName) -> bool:
    return _flags.get(key, false)

func toggle(key: StringName) -> void:
    set_flag(key, !get_flag(key))

func clear_flag(key: StringName) -> void:
    _flags.erase(key)

func export_flags() -> Dictionary:
    return _flags.duplicate()

func import_flags(data: Dictionary) -> void:
    _flags = data.duplicate()
