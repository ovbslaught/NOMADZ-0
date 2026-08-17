extends Node

const LOG_DIR = "user://data/runtime/events/"
var log_file: FileAccess
var session_id: String

func begin_run(new_session_id: String) -> void:
    session_id = new_session_id
    DirAccess.make_dir_recursive_absolute(LOG_DIR)
    
    var path = LOG_DIR + "events-%s.jsonl" % Time.get_date_string_from_system()
    log_file = FileAccess.open(path, FileAccess.WRITE)
    print("[ECHO] Started recording session: ", session_id)

func record_event(event_data: Dictionary) -> void:
    if not log_file:
        return
        
    event_data["session"] = session_id
    event_data["ts"] = Time.get_unix_time_from_system()
    
    log_file.store_line(JSON.stringify(event_data))

func record_transform_sample(sample: Dictionary) -> void:
    record_event({"type": "transform_sample", "data": sample})

func end_run() -> void:
    if log_file:
        log_file.close()
        log_file = null
        print("[ECHO] Ended session: ", session_id)

func spawn_echo_scene(path: String) -> Node:
    if not ResourceLoader.exists(path):
        push_error("[ECHO] Ghost scene not found: " + path)
        return null
        
    var ghost = load(path).instantiate()
    get_tree().current_scene.add_child(ghost)
    return ghost
