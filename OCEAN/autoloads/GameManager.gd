## GameManager.gd
## Autoload Singleton — NOMADZ: Signal Descent
## Core game state: health, abilities, map, save/load, scene transitions
## VultureCode / Sol / NOMADZ Universe

extends Node

# ─── SIGNALS ────────────────────────────────────────────────────────────────
signal health_changed(current: int, maximum: int)
signal fuel_changed(current: float, maximum: float)
signal signal_meter_changed(value: float)
signal ability_unlocked(ability_id: String)
signal cosmic_fragment_collected(fragment_id: String)
signal room_changed(room_id: String)
signal player_died()
signal game_over()
signal game_saved()
signal game_loaded()
signal lore_node_discovered(entry_id: String)

# ─── CONSTANTS ───────────────────────────────────────────────────────────────
const SAVE_PATH := "user://nomadz_save.json"
const DEBUG_MODE := true
const VERSION := "0.1.0-alpha"
const MAX_HEALTH := 100
const MAX_FUEL := 100.0
const MAX_SIGNAL := 100.0

# Ability IDs — must match LoreDatabase and AbilitySystem
const ABILITIES := {
	"jetpack_boost"   : "Overcharged Jetpack Thrust",
	"signal_pulse"    : "SIGNAL PULSE — Signalverse scan wave",
	"morph_compress"  : "OMEGA-COMPRESS — morph through tight shafts",
	"dash"            : "ARCHON DASH — short-range blink",
	"grapple"         : "WORMHOLE TETHER — swing/pull anchor",
	"double_jump"     : "GRAVITY ELSEWORLD — second jump mid-air",
	"shield_aura"     : "ECHO SHIELD — temporary invulnerability burst",
	"signal_bomb"     : "SIGMA BOMB — AOE damage + bleed reveal",
}

# ─── GAME STATE ──────────────────────────────────────────────────────────────
var current_health    : int   = MAX_HEALTH
var current_fuel      : float = MAX_FUEL
var signal_meter      : float = 0.0          ## 0-100; reach 100 to restore Mother Brain

var unlocked_abilities : Array[String] = []
var collected_fragments: Array[String] = []
var discovered_lore    : Array[String] = []
var visited_rooms      : Array[String] = []
var current_room_id    : String = "room_crash_site"
var checkpoint_position: Vector2 = Vector2.ZERO

var is_paused    : bool = false
var is_dead      : bool = false
var is_cutscene  : bool = false
var play_time    : float = 0.0

# Internal
var _save_data   : Dictionary = {}
var _frame_count : int = 0

# ─── LIFECYCLE ───────────────────────────────────────────────────────────────
func _ready() -> void:
	_log("GameManager online — ARCHON Protocol active")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_or_init()

func _process(delta: float) -> void:
	if not is_paused and not is_dead and not is_cutscene:
		play_time += delta
	_frame_count += 1

# ─── HEALTH ──────────────────────────────────────────────────────────────────
func take_damage(amount: int, source: String = "unknown") -> void:
	if is_dead:
		return
	if amount <= 0:
		push_warning("GameManager.take_damage: invalid amount %d from %s" % [amount, source])
		return

	current_health = max(0, current_health - amount)
	_log("Damage: -%d from [%s] | HP: %d/%d" % [amount, source, current_health, MAX_HEALTH])
	health_changed.emit(current_health, MAX_HEALTH)

	if current_health <= 0:
		_trigger_death()

func heal(amount: int) -> void:
	if amount <= 0:
		return
	current_health = min(MAX_HEALTH, current_health + amount)
	health_changed.emit(current_health, MAX_HEALTH)
	_log("Healed +%d | HP: %d/%d" % [amount, current_health, MAX_HEALTH])

func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	_log("NORA SIGNAL LOST — triggering death sequence")
	player_died.emit()
	await get_tree().create_timer(2.5).timeout
	game_over.emit()

func respawn_at_checkpoint() -> void:
	current_health = int(MAX_HEALTH * 0.5)
	current_fuel   = MAX_FUEL
	is_dead        = false
	health_changed.emit(current_health, MAX_HEALTH)
	fuel_changed.emit(current_fuel, MAX_FUEL)
	_log("Respawn at checkpoint: %s" % str(checkpoint_position))

# ─── FUEL ─────────────────────────────────────────────────────────────────────
func update_fuel(new_value: float) -> void:
	current_fuel = clampf(new_value, 0.0, MAX_FUEL)
	fuel_changed.emit(current_fuel, MAX_FUEL)

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	_log("Checkpoint set: %s" % str(pos))

# ─── SIGNAL METER ─────────────────────────────────────────────────────────────
func add_signal_energy(amount: float) -> void:
	signal_meter = minf(MAX_SIGNAL, signal_meter + amount)
	signal_meter_changed.emit(signal_meter)
	_log("Signal +%.1f | Meter: %.1f/%.1f" % [amount, signal_meter, MAX_SIGNAL])
	if signal_meter >= MAX_SIGNAL:
		_trigger_mother_brain_restored()

func _trigger_mother_brain_restored() -> void:
	_log("MOTHER BRAIN SIGNAL RESTORED — ARCHON Protocol complete")
	SignalverseManager.broadcast_event("mother_brain_restored", {})

# ─── ABILITIES ────────────────────────────────────────────────────────────────
func unlock_ability(ability_id: String) -> void:
	if not ABILITIES.has(ability_id):
		push_error("GameManager.unlock_ability: unknown ability '%s'" % ability_id)
		return
	if ability_id in unlocked_abilities:
		_log("Ability already unlocked: %s" % ability_id)
		return

	unlocked_abilities.append(ability_id)
	ability_unlocked.emit(ability_id)
	_log("ABILITY UNLOCKED: %s — %s" % [ability_id, ABILITIES[ability_id]])

func has_ability(ability_id: String) -> bool:
	return ability_id in unlocked_abilities

# ─── FRAGMENTS ────────────────────────────────────────────────────────────────
func collect_fragment(fragment_id: String) -> void:
	if fragment_id in collected_fragments:
		return
	collected_fragments.append(fragment_id)
	cosmic_fragment_collected.emit(fragment_id)
	add_signal_energy(10.0)
	_log("COSMIC KEY fragment collected: %s" % fragment_id)

func collect_lore(entry_id: String) -> void:
	if entry_id in discovered_lore:
		return
	discovered_lore.append(entry_id)
	lore_node_discovered.emit(entry_id)
	_log("BRAIN-FOOD lore node: %s" % entry_id)

# ─── ROOM TRACKING ────────────────────────────────────────────────────────────
func enter_room(room_id: String) -> void:
	if room_id.is_empty():
		push_error("GameManager.enter_room: empty room_id")
		return
	current_room_id = room_id
	if not room_id in visited_rooms:
		visited_rooms.append(room_id)
	room_changed.emit(room_id)
	_log("Entered room: %s" % room_id)

# ─── SAVE / LOAD ─────────────────────────────────────────────────────────────
func save_game() -> void:
	_save_data = {
		"version"           : VERSION,
		"timestamp"         : Time.get_datetime_string_from_system(),
		"play_time"         : play_time,
		"current_health"    : current_health,
		"current_fuel"      : current_fuel,
		"signal_meter"      : signal_meter,
		"unlocked_abilities": unlocked_abilities,
		"collected_fragments": collected_fragments,
		"discovered_lore"   : discovered_lore,
		"visited_rooms"     : visited_rooms,
		"current_room_id"   : current_room_id,
		"checkpoint_position": {
			"x": checkpoint_position.x,
			"y": checkpoint_position.y
		}
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GameManager: cannot open save file — %s" % FileAccess.get_open_error())
		return

	file.store_string(JSON.stringify(_save_data, "\t"))
	file.close()
	game_saved.emit()
	_log("Game saved to: %s" % SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		_log("No save file found — starting fresh")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GameManager: cannot read save file — %s" % FileAccess.get_open_error())
		return false

	var raw := file.get_as_text()
	file.close()

	var result := JSON.parse_string(raw)
	if result == null:
		push_error("GameManager: corrupt save file — JSON parse failed")
		return false

	_save_data          = result
	play_time           = float(_save_data.get("play_time", 0.0))
	current_health      = int(_save_data.get("current_health", MAX_HEALTH))
	current_fuel        = float(_save_data.get("current_fuel", MAX_FUEL))
	signal_meter        = float(_save_data.get("signal_meter", 0.0))
	unlocked_abilities  = Array(_save_data.get("unlocked_abilities", []))
	collected_fragments = Array(_save_data.get("collected_fragments", []))
	discovered_lore     = Array(_save_data.get("discovered_lore", []))
	visited_rooms       = Array(_save_data.get("visited_rooms", []))
	current_room_id     = str(_save_data.get("current_room_id", "room_crash_site"))

	var cp : Dictionary = _save_data.get("checkpoint_position", {"x": 0, "y": 0})
	checkpoint_position = Vector2(float(cp.get("x", 0)), float(cp.get("y", 0)))

	game_loaded.emit()
	_log("Game loaded — play time: %.1fs" % play_time)
	return true

func _load_or_init() -> void:
	if not load_game():
		_log("Fresh game — NOMADZ SIGNAL DESCENT initialised")

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("nomadz_save.json")
			_log("Save file deleted")

# ─── PAUSE ────────────────────────────────────────────────────────────────────
func set_pause(value: bool) -> void:
	is_paused = value
	get_tree().paused = value

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[GameManager | F%d] %s" % [_frame_count, msg])

func get_debug_snapshot() -> Dictionary:
	return {
		"hp"          : "%d/%d" % [current_health, MAX_HEALTH],
		"fuel"        : "%.1f/%.1f" % [current_fuel, MAX_FUEL],
		"signal"      : "%.1f%%" % signal_meter,
		"room"        : current_room_id,
		"abilities"   : unlocked_abilities,
		"fragments"   : collected_fragments.size(),
		"play_time"   : "%.1fs" % play_time,
	}
