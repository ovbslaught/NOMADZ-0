## SignalverseManager.gd
## Autoload Singleton — NOMADZ: Signal Descent
## Governs Signalverse bleed-through events: environmental horror, phantom spawns,
## visual distortion triggers, and lore whisper injection.
## Inspired by Metroid Fusion's SA-X paranoia + Animal Well's hidden creature logic.
## VultureCode / Sol / NOMADZ Universe

extends Node

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal bleed_event_triggered(event_type: String, payload: Dictionary)
signal phantom_spawned(position: Vector2)
signal distortion_started(intensity: float, duration: float)
signal distortion_ended()
signal whisper_played(text: String)
signal corruption_level_changed(level: float)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := true

## Bleed event types — keys used in event_registry
enum BleedType {
	PHANTOM_SPAWN,
	VISUAL_GLITCH,
	SOUND_WHISPER,
	GRAVITY_INVERT,
	ENEMY_SURGE,
	LORE_FLASH,
	SCREEN_TEAR,
	MOTHER_BRAIN_SIGNAL,
}

## Whispers — fragments of NOMADZ lore transmitted during bleed events
const WHISPERS := [
	"...MOTHER BRAIN signal: critical... fragment lost...",
	"NORA. The VULTURE-EYE watches the shaft below.",
	"The COSMIC KEY was never one piece. It was always us.",
	"ARCHON Protocol: survive first. Rebuild second.",
	"...Signalverse depth exceeding safe threshold... bleed rate: 87%...",
	"BRAIN-FOOD ingestion log corrupted. WORMHOLE offline.",
	"You are not the first NORA deployed to SIGMA Station.",
	"The creatures remember the signal. Do not use the pulse near them.",
	"VULTURE-EYE fragment count: 7. You hold: %d.",
	"JAX v3 last transmission: 'The shaft goes deeper than the map shows.'",
	"OMEGA-CORE integrity: FAILING. You have one window.",
	"Do not morph in the dark shafts. They wait there.",
	"ZED says the light is a trap. LYRA says it is the only way.",
	"GRAVITY ELSEWORLD bleed detected. Physics unreliable in next sector.",
]

# ─── STATE ────────────────────────────────────────────────────────────────────
var corruption_level   : float = 0.0      ## 0-100; rises over time, falls with signal energy
var is_bleeding        : bool  = false
var active_phantoms    : int   = 0
var total_bleed_events : int   = 0
var bleed_cooldown     : float = 0.0
var _min_bleed_interval: float = 20.0     ## seconds between bleed events
var _max_bleed_interval: float = 60.0
var _next_bleed_timer  : float = 0.0
var _frame_count       : int   = 0

## Event registry for custom handlers
var _event_registry: Dictionary = {}

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_log("SignalverseManager online")
	_schedule_next_bleed()

	# Listen for Mother Brain restoration to quiet the bleed
	if GameManager:
		GameManager.signal_meter_changed.connect(_on_signal_meter_changed)

func _process(delta: float) -> void:
	_frame_count += 1

	# Tick corruption
	if not GameManager.is_paused:
		_tick_corruption(delta)
		_tick_bleed_timer(delta)

# ─── CORRUPTION ───────────────────────────────────────────────────────────────
func _tick_corruption(delta: float) -> void:
	## Corruption slowly rises unless signal meter is high
	var signal_suppression := GameManager.signal_meter / 100.0  ## 0.0 - 1.0
	var rise_rate := lerpf(0.5, 0.0, signal_suppression)        ## max 0.5/sec
	corruption_level = minf(100.0, corruption_level + rise_rate * delta)
	corruption_level_changed.emit(corruption_level)

func _on_signal_meter_changed(value: float) -> void:
	## High signal suppresses corruption
	var suppression := value / 100.0
	corruption_level = maxf(0.0, corruption_level - suppression * 2.0)

# ─── BLEED TIMER ─────────────────────────────────────────────────────────────
func _tick_bleed_timer(delta: float) -> void:
	_next_bleed_timer -= delta
	if _next_bleed_timer <= 0.0:
		_trigger_random_bleed()
		_schedule_next_bleed()

func _schedule_next_bleed() -> void:
	## Higher corruption = faster bleed events
	var base_interval := lerpf(_max_bleed_interval, _min_bleed_interval, corruption_level / 100.0)
	_next_bleed_timer = base_interval + randf_range(-5.0, 5.0)
	_log("Next bleed event in %.1fs" % _next_bleed_timer)

# ─── BLEED EVENTS ─────────────────────────────────────────────────────────────
func _trigger_random_bleed() -> void:
	if GameManager.is_cutscene or GameManager.is_dead:
		return

	var roll := randi() % 6
	match roll:
		0: _bleed_visual_glitch()
		1: _bleed_whisper()
		2: _bleed_phantom_spawn()
		3: _bleed_screen_tear()
		4: _bleed_gravity_pulse()
		5: _bleed_lore_flash()

	total_bleed_events += 1
	_log("Bleed event #%d triggered (corruption: %.1f%%)" % [total_bleed_events, corruption_level])

func _bleed_visual_glitch() -> void:
	var intensity := lerpf(0.1, 1.0, corruption_level / 100.0)
	var duration  := randf_range(0.3, 1.5)
	distortion_started.emit(intensity, duration)
	bleed_event_triggered.emit("visual_glitch", {"intensity": intensity, "duration": duration})
	await get_tree().create_timer(duration).timeout
	distortion_ended.emit()

func _bleed_whisper() -> void:
	var idx    := randi() % WHISPERS.size()
	var text   := WHISPERS[idx]
	## Inject fragment count if placeholder present
	if "%d" in text:
		text = text % GameManager.collected_fragments.size()
	whisper_played.emit(text)
	bleed_event_triggered.emit("whisper", {"text": text})
	_log("Whisper: %s" % text)

func _bleed_phantom_spawn() -> void:
	if active_phantoms >= 3:
		_log("Phantom cap reached — skipping spawn")
		return
	## Emit for the current room to handle spawn positioning
	var payload := {"corruption": corruption_level}
	phantom_spawned.emit(Vector2.ZERO)  ## Room overrides with real position
	bleed_event_triggered.emit("phantom_spawn", payload)

func _bleed_screen_tear() -> void:
	var duration := randf_range(0.1, 0.4)
	distortion_started.emit(0.8, duration)
	bleed_event_triggered.emit("screen_tear", {"duration": duration})
	await get_tree().create_timer(duration).timeout
	distortion_ended.emit()

func _bleed_gravity_pulse() -> void:
	## Gravity inversion — brief, disorienting
	bleed_event_triggered.emit("gravity_pulse", {"intensity": 0.5})

func _bleed_lore_flash() -> void:
	var lore_keys := LoreDatabase.get_all_entry_ids()
	if lore_keys.is_empty():
		return
	var entry_id := lore_keys[randi() % lore_keys.size()]
	bleed_event_triggered.emit("lore_flash", {"entry_id": entry_id})

# ─── PUBLIC API ───────────────────────────────────────────────────────────────
## Broadcast a named event with optional payload — used by GameManager + bosses
func broadcast_event(event_type: String, payload: Dictionary) -> void:
	bleed_event_triggered.emit(event_type, payload)
	_log("Broadcast: %s | %s" % [event_type, str(payload)])

## Called when a phantom enemy is destroyed
func on_phantom_destroyed() -> void:
	active_phantoms = max(0, active_phantoms - 1)

## Force a bleed event for scripted sequences
func force_bleed(type: String) -> void:
	match type:
		"visual_glitch" : _bleed_visual_glitch()
		"whisper"       : _bleed_whisper()
		"phantom_spawn" : _bleed_phantom_spawn()
		"screen_tear"   : _bleed_screen_tear()
		"gravity_pulse" : _bleed_gravity_pulse()
		"lore_flash"    : _bleed_lore_flash()
		_:
			push_warning("SignalverseManager.force_bleed: unknown type '%s'" % type)

func get_corruption_color() -> Color:
	## Returns a tint colour based on corruption — used by AtmosphereController
	return Color(
		lerpf(0.02, 0.18, corruption_level / 100.0),
		lerpf(0.02, 0.02, corruption_level / 100.0),
		lerpf(0.05, 0.02, corruption_level / 100.0),
		1.0
	)

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[SignalverseManager | F%d] %s" % [_frame_count, msg])

func get_debug_snapshot() -> Dictionary:
	return {
		"corruption"    : "%.1f%%" % corruption_level,
		"next_bleed"    : "%.1fs" % _next_bleed_timer,
		"total_bleeds"  : total_bleed_events,
		"active_phantoms": active_phantoms,
	}
