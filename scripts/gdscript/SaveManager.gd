## SaveManager.gd
## NOMADZ-0 — Event-sourced save system with Write-Ahead Log (WAL).
## Branch: Cosmic-key
##
## Register as an AUTOLOAD in Project → Project Settings → Autoload:
##   Name: SaveManager   Path: res://SaveManager.gd
##
## Signals:
##   save_completed(slot: int)
##   load_completed(slot: int)
##   save_failed(reason: String)
##
## Save files:
##   user://nomadz_save_0.json .. nomadz_save_2.json  (snapshot per slot)
##   user://nomadz_wal.jsonl                          (append-only event log)
##
## WAL entry format:
##   {"timestamp":"<ISO8601>","event":"<type>","data":{...},"hash":"<sha256>"}
##   hash = SHA256( prev_hash + JSON.stringify(data) ) — monotonic chain.
##
## To pipe WAL into omega_memory.db:
##   # In your ingest pipeline (Python):
##   #   python ingest.py --source user://nomadz_wal.jsonl --db omega_memory.db
##   #   ingest.py reads each JSONL line, verifies hash chain, and UPSERTS into:
##   #     CREATE TABLE events (id INTEGER PRIMARY KEY, timestamp TEXT,
##   #                          event TEXT, data TEXT, hash TEXT);
##   # The WAL file path on desktop: ~/.local/share/godot/app_userdata/NOMADZ-0/nomadz_wal.jsonl
##   # On Android: /data/user/0/<package>/files/nomadz_wal.jsonl  (Godot handles user:// automatically)
##
## Android note:
##   Godot maps user:// to the app's internal storage automatically on Android.
##   No additional path logic is needed here.

extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(reason: String)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const SAVE_SLOTS: int = 3
const WAL_FILE: String = "user://nomadz_wal.jsonl"
const AUTO_SAVE_INTERVAL: float = 300.0   ## 5 minutes

# ---------------------------------------------------------------------------
# Auto-save timer
# ---------------------------------------------------------------------------
var _auto_save_timer: float = 0.0
var auto_save_enabled: bool = true
## Which slot to use for auto-saves (default slot 0).
var auto_save_slot: int = 0

# ---------------------------------------------------------------------------
# WAL hash chain — tracks the hash of the last written WAL entry.
# ---------------------------------------------------------------------------
var _last_wal_hash: String = "0" * 64  ## Initial "genesis" hash (64 zero chars).

# ---------------------------------------------------------------------------
# In-memory game state — populated on load, mutated by set_state helpers.
# ---------------------------------------------------------------------------
var _state: Dictionary = _default_state()

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	## Load or initialise WAL hash chain from existing WAL file.
	_load_last_wal_hash()
	## Append a startup event so the WAL reflects game sessions.
	_append_wal("session_start", {"godot_version": Engine.get_version_info()["string"]})


func _process(delta: float) -> void:
	if not auto_save_enabled:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		save_state(auto_save_slot)


# ---------------------------------------------------------------------------
# Default state structure
# ---------------------------------------------------------------------------

func _default_state() -> Dictionary:
	return {
		"player_position": {"x": 0.0, "y": 0.0, "z": 0.0},
		"current_biome": "SAHARA",
		"tension_level": 0.0,
		"uridium_amount": 100.0,
		"unlocked_pillars": [] as Array,
		"completed_quests": [] as Array,
		"world_seed": 42,
		"play_time_seconds": 0.0,
		"schema_version": 1,
	}


# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

func save_state(slot: int) -> void:
	## Snapshot current game state to slot file and record WAL milestone entry.
	if slot < 0 or slot >= SAVE_SLOTS:
		save_failed.emit("Invalid slot: %d" % slot)
		return

	## Pull live data from autoloads / Director before serializing.
	_sync_state_from_scene()

	var path := _slot_path(slot)
	var json_str := JSON.stringify(_state, "\t")

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err_msg := "Cannot open %s for writing (error %d)" % [path, FileAccess.get_open_error()]
		save_failed.emit(err_msg)
		push_error("SaveManager: " + err_msg)
		return

	file.store_string(json_str)
	file.close()

	## WAL milestone event — records that a save occurred and what slot.
	_append_wal("save", {
		"slot": slot,
		"player_position": _state["player_position"],
		"current_biome": _state["current_biome"],
		"tension_level": _state["tension_level"],
	})

	save_completed.emit(slot)


# ---------------------------------------------------------------------------
# Load
# ---------------------------------------------------------------------------

func load_state(slot: int) -> void:
	## Read snapshot from slot file, merge into _state, emit signal.
	if slot < 0 or slot >= SAVE_SLOTS:
		save_failed.emit("Invalid slot: %d" % slot)
		return

	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		save_failed.emit("No save found at slot %d (%s)" % [slot, path])
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		save_failed.emit("Cannot open %s for reading" % path)
		return

	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		save_failed.emit("Corrupt save at slot %d: JSON parse failed" % slot)
		return

	_state = parsed as Dictionary
	## Ensure any new keys from _default_state are present (forward-compat).
	for key in _default_state().keys():
		if not _state.has(key):
			_state[key] = _default_state()[key]

	## Push loaded state back into the scene.
	_apply_state_to_scene()

	_append_wal("load", {"slot": slot})
	load_completed.emit(slot)


# ---------------------------------------------------------------------------
# State sync helpers
# ---------------------------------------------------------------------------

func _sync_state_from_scene() -> void:
	## Pull current values from scene nodes / autoloads into _state.
	## WorldTensionMeter.
	if Engine.has_singleton("WorldTensionMeter"):
		var wtm = Engine.get_singleton("WorldTensionMeter")
		_state["tension_level"] = wtm.get("tension") if wtm.get("tension") != null else _state["tension_level"]

	## Director — play time, world seed, etc.
	if Engine.has_singleton("Director"):
		var dir = Engine.get_singleton("Director")
		var seed_val = dir.get("world_seed")
		if seed_val != null:
			_state["world_seed"] = seed_val
		var pt = dir.get("play_time_seconds")
		if pt != null:
			_state["play_time_seconds"] = pt

	## Player position — find PlayerController in the scene tree.
	var player := _find_player()
	if player:
		var pos: Vector3 = player.global_position
		_state["player_position"] = _serialize_vec3(pos)
		var uridium = player.get("uridium")
		if uridium != null:
			_state["uridium_amount"] = float(uridium)

	## BiomeGenerator — active biome and pillar list.
	var biome_gen := _find_biome_generator()
	if biome_gen:
		var active: Dictionary = biome_gen.get_active_biome()
		if active.has("name"):
			_state["current_biome"] = active["name"]
		_state["unlocked_pillars"] = biome_gen._activated_pillars.duplicate()


func _apply_state_to_scene() -> void:
	## Push loaded _state back into scene nodes.
	var player := _find_player()
	if player:
		player.global_position = _deserialize_vec3(_state.get("player_position", {}))
		var uridium = _state.get("uridium_amount", 100.0)
		player.set("uridium", float(uridium))

	if Engine.has_singleton("WorldTensionMeter"):
		var wtm = Engine.get_singleton("WorldTensionMeter")
		wtm.set("tension", float(_state.get("tension_level", 0.0)))

	if Engine.has_singleton("Director"):
		var dir = Engine.get_singleton("Director")
		dir.set("world_seed", int(_state.get("world_seed", 42)))
		dir.set("play_time_seconds", float(_state.get("play_time_seconds", 0.0)))

	## Restore BiomeGenerator pillar state.
	var biome_gen := _find_biome_generator()
	if biome_gen:
		biome_gen._activated_pillars = (_state.get("unlocked_pillars", []) as Array).duplicate()


# ---------------------------------------------------------------------------
# State mutation API (call from quest system, etc.)
# ---------------------------------------------------------------------------

func record_state_change(key: String, value: Variant) -> void:
	## Mutate a single key and write a WAL state_change entry.
	_state[key] = value
	_append_wal("state_change", {"key": key, "value": str(value)})


func record_milestone(name: String, extra_data: Dictionary = {}) -> void:
	## Record a narrative milestone event in the WAL (quest complete, pillar unlocked, etc.).
	var data := {"milestone": name}
	data.merge(extra_data)
	_append_wal("milestone", data)


func mark_quest_complete(quest_id: String) -> void:
	var quests: Array = _state.get("completed_quests", [])
	if quest_id not in quests:
		quests.append(quest_id)
		_state["completed_quests"] = quests
		record_milestone("quest_complete", {"quest_id": quest_id})


func unlock_pillar(pillar_id: String) -> void:
	var pillars: Array = _state.get("unlocked_pillars", [])
	if pillar_id not in pillars:
		pillars.append(pillar_id)
		_state["unlocked_pillars"] = pillars
		record_milestone("pillar_unlocked", {"pillar_id": pillar_id})


# ---------------------------------------------------------------------------
# WAL (Write-Ahead Log) implementation
# ---------------------------------------------------------------------------

func _append_wal(event_type: String, data: Dictionary) -> void:
	## Append a single line to the JSONL WAL file.
	## Hash chain: SHA256( prev_hash + JSON.stringify(data) )
	## This gives a tamper-evident event log suitable for omega_memory.db ingestion.

	var timestamp := _iso8601_now()
	var data_str := JSON.stringify(data)
	var hash_input := _last_wal_hash + data_str
	var new_hash := _sha256_hex(hash_input)
	_last_wal_hash = new_hash

	var entry := {
		"timestamp": timestamp,
		"event": event_type,
		"data": data,
		"hash": new_hash,
	}

	var line := JSON.stringify(entry) + "\n"

	## Open for append — WAL never overwrites existing entries.
	var file := FileAccess.open(WAL_FILE, FileAccess.READ_WRITE)
	if not file:
		## File doesn't exist yet; create it.
		file = FileAccess.open(WAL_FILE, FileAccess.WRITE)
	if not file:
		push_warning("SaveManager: Cannot open WAL file for writing: " + WAL_FILE)
		return

	file.seek_end(0)      ## Move to EOF before appending.
	file.store_string(line)
	file.close()


func _load_last_wal_hash() -> void:
	## Scan to the last line of the WAL file to restore the hash chain tip.
	if not FileAccess.file_exists(WAL_FILE):
		return  ## Fresh install — genesis hash remains.

	var file := FileAccess.open(WAL_FILE, FileAccess.READ)
	if not file:
		return

	var last_line := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.length() > 0:
			last_line = line
	file.close()

	if last_line.is_empty():
		return

	var parsed = JSON.parse_string(last_line)
	if parsed is Dictionary and parsed.has("hash"):
		_last_wal_hash = parsed["hash"]


# ---------------------------------------------------------------------------
# Vector3 serialization helpers
# ---------------------------------------------------------------------------

func _serialize_vec3(v: Vector3) -> Dictionary:
	return {"x": v.x, "y": v.y, "z": v.z}


func _deserialize_vec3(d: Dictionary) -> Vector3:
	return Vector3(
		float(d.get("x", 0.0)),
		float(d.get("y", 0.0)),
		float(d.get("z", 0.0))
	)


# ---------------------------------------------------------------------------
# ISO-8601 timestamp helper
# ---------------------------------------------------------------------------

func _iso8601_now() -> String:
	## Returns current UTC time as ISO 8601 string: "2026-03-22T05:56:00Z"
	var dt := Time.get_datetime_dict_from_system(true)  ## true = UTC
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		dt["year"], dt["month"], dt["day"],
		dt["hour"], dt["minute"], dt["second"]
	]


# ---------------------------------------------------------------------------
# SHA-256 implementation
## Godot 4 does not expose SHA-256 in a one-liner for arbitrary strings,
## but HashingContext provides it for PackedByteArrays.
# ---------------------------------------------------------------------------

func _sha256_hex(input: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(input.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	## Convert bytes to lowercase hex string.
	var hex := ""
	for byte in digest:
		hex += "%02x" % byte
	return hex


# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

func _slot_path(slot: int) -> String:
	return "user://nomadz_save_%d.json" % slot


# ---------------------------------------------------------------------------
# Scene node finders
# ---------------------------------------------------------------------------

func _find_player() -> Node:
	## Attempt to locate the PlayerController via group membership.
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	## Fallback: traverse root for CharacterBody3D named "Cope".
	return get_tree().root.find_child("Cope", true, false)


func _find_biome_generator() -> Node:
	var nodes := get_tree().get_nodes_in_group("biome_generator")
	if nodes.size() > 0:
		return nodes[0]
	return get_tree().root.find_child("BiomeGenerator", true, false)


# ---------------------------------------------------------------------------
# Public query API
# ---------------------------------------------------------------------------

func get_state() -> Dictionary:
	return _state.duplicate(true)


func get_slot_info(slot: int) -> Dictionary:
	## Returns metadata from a saved file without fully loading it.
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"exists": false, "slot": slot}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"exists": false, "slot": slot, "error": "Cannot open"}

	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {"exists": false, "slot": slot, "error": "Corrupt"}

	return {
		"exists": true,
		"slot": slot,
		"current_biome": parsed.get("current_biome", "?"),
		"play_time_seconds": parsed.get("play_time_seconds", 0.0),
		"tension_level": parsed.get("tension_level", 0.0),
	}


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func get_wal_entry_count() -> int:
	## Returns the number of events in the WAL file (for debug / stats).
	if not FileAccess.file_exists(WAL_FILE):
		return 0
	var file := FileAccess.open(WAL_FILE, FileAccess.READ)
	if not file:
		return 0
	var count := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.length() > 0:
			count += 1
	file.close()
	return count
