extends Node
class_name Telemetry

var enabled: bool = false
var session_id: String = ""
var _ring: PackedStringArray = []
const RING_MAX := 20

func _ready() -> void:
	# If GameLoop exists as autoload, bind session_id
	if has_node("/root/GameLoop"):
		session_id = get_node("/root/GameLoop").session_id

func set_enabled(v: bool) -> void:
	enabled = v
	log_action("telemetry_enabled=%s" % str(enabled))

func log_action(action_name: String) -> void:
	var msg := "%s | %s" % [_ts_utc(), action_name]
	_ring.append(msg)
	if _ring.size() > RING_MAX:
		_ring.remove_at(0)
	if enabled:
		_append_to_file(msg + "\n")

func log_state_change(old_state: int, new_state: int) -> void:
	log_action("state_changed %d -> %d" % [old_state, new_state])

func dump_ring() -> String:
	return "\n".join(_ring)

func _append_to_file(text: String) -> void:
	var sid := session_id
	if sid.is_empty():
		sid = "nosession"
	DirAccess.make_dir_recursive_absolute("user://telemetry")
	var path := "user://telemetry/session-%s.log" % sid
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f:
		f.seek_end()
		f.store_string(text)

func _ts_utc() -> String:
	return str(Time.get_unix_time_from_system())
