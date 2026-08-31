## TilemapImportAdapter.gd
## Reads a JSON tile-map export and emits validated source data.
## Source file is NEVER modified — read-only by design.
##
## Expected JSON schema (minimal):
## {
##   "project_id": "my_project",
##   "level_id":   "1-1",
##   "dimensions": { "cols": 32, "rows": 15 },
##   "palette":    [ "#000000", "#FFFFFF", ... ],
##   "tiles": [
##     { "coord": [0, 0], "tile_id": 1, "palette_index": 1 },
##     ...
##   ],
##   "entities": [],
##   "events":   []
## }
extends Node

signal import_progress(pct: float)

func import_from_path(path: String) -> void:
	if not OverlayConfig.SOURCE_READ_ONLY:
		push_warning("[TilemapImportAdapter] SOURCE_READ_ONLY is false.")

	if not FileAccess.file_exists(path):
		OverlayBus.source_import_failed.emit("File not found: %s" % path)
		return

	var file_size_mb := FileAccess.get_file_as_bytes(path).size() / 1_048_576.0
	if file_size_mb > OverlayConfig.MAX_IMPORT_FILE_MB:
		OverlayBus.source_import_failed.emit("File too large (%.1f MB > %.1f MB limit)" % [file_size_mb, OverlayConfig.MAX_IMPORT_FILE_MB])
		return

	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		OverlayBus.source_import_failed.emit("Cannot open file: %s" % path)
		return

	var raw_text := fa.get_as_text()
	fa.close()

	var json  := JSON.new()
	var err   := json.parse(raw_text)
	if err != OK:
		OverlayBus.source_import_failed.emit("JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	var data : Dictionary = json.data
	if not _validate(data):
		return   # validation emits its own failure/warning signals

	# Normalize coord arrays to Vector2i
	var tiles : Array = []
	for t in data.get("tiles", []):
		var c = t.get("coord", [0,0])
		tiles.append({
			"coord":         Vector2i(int(c[0]), int(c[1])),
			"tile_id":       int(t.get("tile_id", 0)),
			"palette_index": int(t.get("palette_index", 0))
		})
	data["tiles"] = tiles

	var meta := {
		"project_id": data.get("project_id", ""),
		"level_id":   data.get("level_id",   ""),
		"dimensions": data.get("dimensions", {"cols":0,"rows":0}),
		"tile_count": tiles.size()
	}

	OverlayBus.source_import_validated.emit(meta)

	# Build and push as frame 0
	data["source_type"] = "tilemap_import"
	data["frame_id"]    = 0
	OverlayBus.raw_frame_ready.emit(0, data)

func _validate(data: Dictionary) -> bool:
	var required := ["project_id", "level_id", "dimensions", "tiles"]
	for key in required:
		if not data.has(key):
			OverlayBus.validation_warning_added.emit("MISSING_KEY", "Required key absent: %s" % key)
			OverlayBus.source_import_failed.emit("Validation failed — missing key: %s" % key)
			return false
	OverlayBus.validation_passed.emit({"keys_checked": required})
	return true
