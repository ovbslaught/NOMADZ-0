## HUD.gd
## CanvasLayer — NOMADZ: Signal Descent
## Full HUD: HP bar, fuel gauge, signal meter, ability list, whisper display,
## room name flash, and bleed corruption indicator.
## VultureCode / Sol / NOMADZ Universe

class_name HUD
extends CanvasLayer

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var hp_bar          : ProgressBar = $HPBar
@onready var fuel_bar        : ProgressBar = $FuelBar
@onready var signal_bar      : ProgressBar = $SignalMeterBar
@onready var signal_fill     : ColorRect   = $SignalMeterBar/Fill

@onready var room_label      : Label       = $RoomLabel
@onready var whisper_label   : Label       = $WhisperLabel
@onready var ability_panel   : VBoxContainer = $AbilityPanel
@onready var fragment_label  : Label       = $FragmentLabel
@onready var corruption_bar  : ProgressBar = $CorruptionBar
@onready var boss_hp_bar     : ProgressBar = $BossHPBar
@onready var boss_hp_container: Control    = $BossHPContainer
@onready var lore_popup      : Control     = $LorePopup
@onready var lore_title      : Label       = $LorePopup/Title
@onready var lore_text       : Label       = $LorePopup/Text

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false

var _whisper_visible   : bool  = false
var _room_flash_timer  : float = 0.0
const ROOM_FLASH_TIME  : float = 3.0
const WHISPER_DISPLAY  : float = 4.5
var _lore_queue        : Array[Dictionary] = []
var _showing_lore      : bool  = false

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_connect_signals()
	_init_bars()
	_hide_optional_elements()
	_log("HUD ready")

func _connect_signals() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.fuel_changed.connect(_on_fuel_changed)
	GameManager.signal_meter_changed.connect(_on_signal_changed)
	GameManager.room_changed.connect(_on_room_changed)
	GameManager.ability_unlocked.connect(_on_ability_unlocked)
	GameManager.cosmic_fragment_collected.connect(_on_fragment_collected)
	GameManager.lore_node_discovered.connect(_on_lore_discovered)

	AudioManager.whisper_displayed.connect(_on_whisper_displayed)
	SignalverseManager.corruption_level_changed.connect(_on_corruption_changed)

func _init_bars() -> void:
	## HP
	if is_instance_valid(hp_bar):
		hp_bar.min_value = 0
		hp_bar.max_value = GameManager.MAX_HEALTH
		hp_bar.value     = GameManager.current_health

	## Fuel
	if is_instance_valid(fuel_bar):
		fuel_bar.min_value = 0
		fuel_bar.max_value = GameManager.MAX_FUEL
		fuel_bar.value     = GameManager.current_fuel

	## Signal Meter
	if is_instance_valid(signal_bar):
		signal_bar.min_value = 0
		signal_bar.max_value = GameManager.MAX_SIGNAL
		signal_bar.value     = GameManager.signal_meter

	## Corruption
	if is_instance_valid(corruption_bar):
		corruption_bar.min_value = 0
		corruption_bar.max_value = 100
		corruption_bar.value     = 0

func _hide_optional_elements() -> void:
	if is_instance_valid(boss_hp_container):
		boss_hp_container.visible = false
	if is_instance_valid(lore_popup):
		lore_popup.visible = false
	if is_instance_valid(whisper_label):
		whisper_label.visible = false
	if is_instance_valid(room_label):
		room_label.modulate.a = 0.0

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_tick_room_label(delta)
	_update_fragment_label()

func _tick_room_label(delta: float) -> void:
	if _room_flash_timer > 0:
		_room_flash_timer -= delta
		if _room_flash_timer <= 0:
			_fade_room_label()

func _update_fragment_label() -> void:
	if is_instance_valid(fragment_label):
		fragment_label.text = "KEY: %d / 7" % GameManager.collected_fragments.size()

# ─── SIGNAL HANDLERS ─────────────────────────────────────────────────────────
func _on_health_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(hp_bar):
		return
	hp_bar.max_value = maximum
	var tween := create_tween()
	tween.tween_property(hp_bar, "value", float(current), 0.2)
	## Flash red on damage
	if current < hp_bar.value:
		_flash_bar(hp_bar, Color.RED)

func _on_fuel_changed(current: float, maximum: float) -> void:
	if not is_instance_valid(fuel_bar):
		return
	fuel_bar.max_value = maximum
	fuel_bar.value     = current
	## Warn on low fuel
	if current < GameManager.FUEL_LOW_THRESH:
		fuel_bar.modulate = Color(1.0, 0.3, 0.1)
	else:
		fuel_bar.modulate = Color.WHITE

func _on_signal_changed(value: float) -> void:
	if not is_instance_valid(signal_bar):
		return
	var tween := create_tween()
	tween.tween_property(signal_bar, "value", value, 0.3)
	## Pulse signal fill
	if is_instance_valid(signal_fill):
		var fill_tween := create_tween()
		fill_tween.tween_property(signal_fill, "modulate", Color(0.8, 1.0, 1.5), 0.1)
		fill_tween.tween_property(signal_fill, "modulate", Color.WHITE, 0.3)

func _on_room_changed(room_id: String) -> void:
	if not is_instance_valid(room_label):
		return
	room_label.text = room_id.replace("room_", "").replace("_", " ").to_upper()
	room_label.modulate.a = 1.0
	_room_flash_timer = ROOM_FLASH_TIME

func _fade_room_label() -> void:
	if not is_instance_valid(room_label):
		return
	var tween := create_tween()
	tween.tween_property(room_label, "modulate:a", 0.0, 1.0)

func _on_ability_unlocked(ability_id: String) -> void:
	if not is_instance_valid(ability_panel):
		return
	var lbl := Label.new()
	lbl.text = "✓ " + GameManager.ABILITIES.get(ability_id, ability_id)
	ability_panel.add_child(lbl)
	## Flash it
	lbl.modulate = Color(0.4, 1.0, 0.8)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate", Color.WHITE, 1.0)

func _on_fragment_collected(_fragment_id: String) -> void:
	## Pulse fragment counter
	if is_instance_valid(fragment_label):
		var tween := create_tween()
		tween.tween_property(fragment_label, "modulate", Color(0.4, 0.8, 1.5), 0.15)
		tween.tween_property(fragment_label, "modulate", Color.WHITE, 0.5)

func _on_lore_discovered(entry_id: String) -> void:
	var entry := LoreDatabase.get_entry(entry_id)
	if entry.is_empty():
		return
	_lore_queue.append(entry)
	if not _showing_lore:
		_show_next_lore()

func _show_next_lore() -> void:
	if _lore_queue.is_empty() or not is_instance_valid(lore_popup):
		_showing_lore = false
		return
	_showing_lore = true
	var entry : Dictionary = _lore_queue.pop_front()

	if is_instance_valid(lore_title):
		lore_title.text = entry.get("title", "???")
	if is_instance_valid(lore_text):
		lore_text.text  = entry.get("text", "")

	lore_popup.visible  = true
	lore_popup.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(lore_popup, "modulate:a", 1.0, 0.4)
	await tween.finished
	await get_tree().create_timer(5.0).timeout
	var tween2 := create_tween()
	tween2.tween_property(lore_popup, "modulate:a", 0.0, 0.6)
	await tween2.finished
	lore_popup.visible = false
	_showing_lore = false
	_show_next_lore()

func _on_whisper_displayed(text: String) -> void:
	if not is_instance_valid(whisper_label):
		return
	whisper_label.text    = text
	whisper_label.visible = true
	whisper_label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(whisper_label, "modulate:a", 0.85, 0.5)
	await tween.finished
	await get_tree().create_timer(WHISPER_DISPLAY).timeout
	var tween2 := create_tween()
	tween2.tween_property(whisper_label, "modulate:a", 0.0, 1.0)
	await tween2.finished
	whisper_label.visible = false

func _on_corruption_changed(level: float) -> void:
	if is_instance_valid(corruption_bar):
		corruption_bar.value = level
		var color := Color(0.02 + level / 200.0, 0.02, 0.05 + level / 300.0).lerp(Color.RED, level / 100.0)
		corruption_bar.modulate = color

# ─── BOSS BAR ─────────────────────────────────────────────────────────────────
func show_boss_bar(boss_name: String, max_hp: int) -> void:
	if not is_instance_valid(boss_hp_container):
		return
	boss_hp_container.visible = true
	if is_instance_valid(boss_hp_bar):
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value     = max_hp

func update_boss_bar(current_hp: int) -> void:
	if is_instance_valid(boss_hp_bar):
		var tween := create_tween()
		tween.tween_property(boss_hp_bar, "value", float(current_hp), 0.3)

func hide_boss_bar() -> void:
	if is_instance_valid(boss_hp_container):
		boss_hp_container.visible = false

# ─── UTILITY ──────────────────────────────────────────────────────────────────
func _flash_bar(bar: ProgressBar, color: Color) -> void:
	var tween := create_tween()
	tween.tween_property(bar, "modulate", color, 0.1)
	tween.tween_property(bar, "modulate", Color.WHITE, 0.2)

func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[HUD] %s" % msg)
