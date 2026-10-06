extends Node
class_name BuildManifest

func write_manifest(platform_override: String = "") -> String:
	DirAccess.make_dir_recursive_absolute("user://manifests")

	var platform := platform_override
	if platform.is_empty():
		platform = OS.get_name()

	var stamp := _stamp()
	var path := "user://manifests/manifest-%s-%s.json" % [stamp, platform.to_lower()]

	var data := {
		"game_version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"engine_version": Engine.get_version_info(),
		"platform": platform,
		"build_time_utc": Time.get_datetime_string_from_system(true),
		"session_id": _safe_session_id(),
		"key_files": [
			"user://telemetry/",
			"user://manifests/"
		]
	}

	var json := JSON.stringify(data, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(json)
		print("[BuildManifest] wrote: ", path)
	return path

func _safe_session_id() -> String:
	if has_node("/root/GameLoop"):
		return get_node("/root/GameLoop").session_id
	return ""

func _stamp() -> String:
	var d := Time.get_datetime_dict_from_system(true)
	return "%04d%02d%02d-%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]