extends Node

class_name DebugTools

var log_enabled: bool = true
var error_count: int = 0
var warning_count: int = 0
var log_file_path: String = "user://nomadz_debug.log"
var logs: PackedStringArray = []

const MAX_LOG_LINES: int = 1000

func _ready() -> void:
    print([DebugTools] Initialized - Logging to: , log_file_path)

func log(message: String, level: String = "INFO") -> void:
    if not log_enabled:
        return
    var timestamp = Time.get_ticks_msec() / 1000.0
    var formatted = "[%.2f] [%s] %s" % [timestamp, level, message]

    match level:
        "ERROR":
            error_count += 1
            push_error(formatted)
        "WARN":
            warning_count += 1
            push_warning(formatted)
    _print(formatted)
    logs.append(formatted)
    if logs.size() > MAX_LOG_LINES:
        logs.remove_at(0)
    _write_to_file(formatted)

func error(message: String) -> void:
    log(message, "ERROR")

func warn(message: String) -> void:
    log(message, "WARN")

func debug(message: String) -> void:
    log(message, "DEBUG")

func info(message: String) -> void:
    log(message, "INFO")

func _write_to_file(message: String) -> void:
    var file = FileAccess.open(log_file_path, FileAccess.READ_WRITE)
    if file:
        file.seek_end()
        file.store_line(message)

func get_logs() -> PackedStringArray:
    return logs.duplicate()

func get_stats() -> Dictionary:
    return { errors: error_count, warnings: warning_count, total_logs: logs.size() }