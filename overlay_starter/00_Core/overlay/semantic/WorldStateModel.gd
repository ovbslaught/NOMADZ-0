## WorldStateModel.gd
## Static utility — builds the canonical in-memory world-state dictionary
## from a raw adapter packet. Source data is never written back.
##
## Schema reference:
##   project_id     : String
##   source_type    : String     ("tilemap_import" | "live_stream" | "replay")
##   level_id       : String
##   frame_id       : int
##   palette        : Array[Color]
##   dimensions     : Vector2i   (cols, rows)
##   tiles_visual   : Array[Dictionary]  { coord, tile_id, palette_index }
##   tiles_semantic : Array[Dictionary]  (populated by SemanticInterpreter)
##   entities       : Array[Dictionary]  { id, class, position, facing, anim, active }
##   events         : Array[Dictionary]  { type, entity_id, payload }
##   bindings       : Dictionary         { binding_key -> PackedScene | null }
extends Node

static func build_from_raw(raw: Dictionary) -> Dictionary:
	var ws : Dictionary = {}

	ws["project_id"]  = raw.get("project_id",  "unknown_project")
	ws["source_type"] = raw.get("source_type",  "tilemap_import")
	ws["level_id"]    = raw.get("level_id",     "level_00")
	ws["frame_id"]    = raw.get("frame_id",     0)
	ws["palette"]     = _parse_palette(raw.get("palette", []))
	ws["dimensions"]  = _parse_dimensions(raw.get("dimensions", {"cols": 0, "rows": 0}))
	ws["tiles_visual"]= raw.get("tiles", [])
	ws["tiles_semantic"] = []   # filled by SemanticInterpreter after build
	ws["entities"]    = raw.get("entities", [])
	ws["events"]      = raw.get("events",   [])
	ws["bindings"]    = raw.get("bindings", {})

	return ws

static func _parse_palette(raw_palette: Array) -> Array:
	var out : Array = []
	for entry in raw_palette:
		if entry is Color:
			out.append(entry)
		elif entry is String:
			out.append(Color(entry))
		elif entry is Dictionary:
			out.append(Color(entry.get("r",0), entry.get("g",0), entry.get("b",0)))
	return out

static func _parse_dimensions(d: Dictionary) -> Vector2i:
	return Vector2i(int(d.get("cols", 0)), int(d.get("rows", 0)))

## Helper — returns an empty but valid world-state for initialization.
static func empty() -> Dictionary:
	return {
		"project_id": "", "source_type": "", "level_id": "",
		"frame_id": 0, "palette": [], "dimensions": Vector2i.ZERO,
		"tiles_visual": [], "tiles_semantic": [],
		"entities": [], "events": [], "bindings": {}
	}
