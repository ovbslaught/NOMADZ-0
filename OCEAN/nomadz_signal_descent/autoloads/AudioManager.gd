## AudioManager.gd
## Autoload Singleton — NOMADZ: Signal Descent
## Dynamic music layering, ambient atmosphere, spatial SFX, whisper injection.
## Animal Well-style silent-then-loud audio design.
## VultureCode / Sol / NOMADZ Universe

extends Node

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal music_layer_changed(layer_id: String)
signal whisper_displayed(text: String)

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := true
const MASTER_BUS  := "Master"
const MUSIC_BUS   := "Music"
const SFX_BUS     := "SFX"
const AMBIENT_BUS := "Ambient"

## SFX event keys — mapped to AudioStreamPlayer paths
## (Placeholder paths — replace with actual .ogg/.wav assets)
const SFX_EVENTS := {
	"jump"           : "res://audio/sfx/jump.ogg",
	"land"           : "res://audio/sfx/land.ogg",
	"jetpack_thrust" : "res://audio/sfx/jetpack_loop.ogg",
	"jetpack_end"    : "res://audio/sfx/jetpack_end.ogg",
	"dash"           : "res://audio/sfx/dash.ogg",
	"shoot"          : "res://audio/sfx/shoot.ogg",
	"hit_player"     : "res://audio/sfx/hit_player.ogg",
	"hit_enemy"      : "res://audio/sfx/hit_enemy.ogg",
	"enemy_die"      : "res://audio/sfx/enemy_die.ogg",
	"collect_fragment": "res://audio/sfx/collect_fragment.ogg",
	"collect_lore"   : "res://audio/sfx/collect_lore.ogg",
	"door_open"      : "res://audio/sfx/door_open.ogg",
	"signal_pulse"   : "res://audio/sfx/signal_pulse.ogg",
	"bleed_glitch"   : "res://audio/sfx/bleed_glitch.ogg",
	"boss_roar"      : "res://audio/sfx/boss_roar.ogg",
	"ui_confirm"     : "res://audio/sfx/ui_confirm.ogg",
	"ui_cancel"      : "res://audio/sfx/ui_cancel.ogg",
	"save_point"     : "res://audio/sfx/save_point.ogg",
	"player_die"     : "res://audio/sfx/player_die.ogg",
	"morph_enter"    : "res://audio/sfx/morph_enter.ogg",
	"morph_exit"     : "res://audio/sfx/morph_exit.ogg",
	"ability_unlock" : "res://audio/sfx/ability_unlock.ogg",
}

## Music layers per zone type
const MUSIC_LAYERS := {
	"surface"   : "res://audio/music/surface_base.ogg",
	"descent"   : "res://audio/music/descent_base.ogg",
	"deep"      : "res://audio/music/deep_base.ogg",
	"boss"      : "res://audio/music/boss_theme.ogg",
	"restored"  : "res://audio/music/mother_brain_restored.ogg",
	"silence"   : "",
}

# ─── STATE ────────────────────────────────────────────────────────────────────
var master_volume   : float = 1.0
var music_volume    : float = 0.7
var sfx_volume      : float = 1.0
var ambient_volume  : float = 0.8
var current_music   : String = "silence"
var is_music_fading : bool  = false
var _frame_count    : int   = 0

## Pooled SFX players
var _sfx_pool       : Array[AudioStreamPlayer] = []
var _music_player   : AudioStreamPlayer
var _ambient_player : AudioStreamPlayer
var _jetpack_player : AudioStreamPlayer  ## Looping jetpack SFX

const SFX_POOL_SIZE := 8

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_audio_buses()
	_build_sfx_pool()
	_build_music_player()
	_build_ambient_player()
	_build_jetpack_player()
	_connect_signals()
	_log("AudioManager online")

func _process(_delta: float) -> void:
	_frame_count += 1

func _build_audio_buses() -> void:
	## Ensure buses exist (Godot auto-creates Master; add Music/SFX/Ambient)
	for bus_name in [MUSIC_BUS, SFX_BUS, AMBIENT_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, MASTER_BUS)
	_apply_volumes()

func _apply_volumes() -> void:
	_set_bus_db(MASTER_BUS, linear_to_db(master_volume))
	_set_bus_db(MUSIC_BUS,  linear_to_db(music_volume))
	_set_bus_db(SFX_BUS,    linear_to_db(sfx_volume))
	_set_bus_db(AMBIENT_BUS,linear_to_db(ambient_volume))

func _set_bus_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, db)

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_pool.append(p)

func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	_music_player.volume_db = 0.0
	add_child(_music_player)

func _build_ambient_player() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = AMBIENT_BUS
	add_child(_ambient_player)

func _build_jetpack_player() -> void:
	_jetpack_player = AudioStreamPlayer.new()
	_jetpack_player.bus = SFX_BUS
	_jetpack_player.volume_db = -6.0
	add_child(_jetpack_player)

func _connect_signals() -> void:
	if SignalverseManager:
		SignalverseManager.whisper_played.connect(_on_whisper_played)
		SignalverseManager.distortion_started.connect(_on_distortion_started)
	if GameManager:
		GameManager.player_died.connect(_on_player_died)
		GameManager.ability_unlocked.connect(func(_id): play_sfx("ability_unlock"))

# ─── SFX API ─────────────────────────────────────────────────────────────────
func play_sfx(event_id: String) -> void:
	if not SFX_EVENTS.has(event_id):
		push_warning("AudioManager.play_sfx: unknown event '%s'" % event_id)
		return

	## Skip if no asset path defined (placeholder)
	var path : String = SFX_EVENTS[event_id]
	if path.is_empty():
		return

	var player := _get_free_sfx_player()
	if player == null:
		_log("SFX pool exhausted — skipping '%s'" % event_id)
		return

	## In production, load stream from path. Guarded for missing assets.
	if ResourceLoader.exists(path):
		player.stream = load(path)
		player.play()
	else:
		_log("SFX asset missing: %s" % path)

func _get_free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return null  ## All busy

# ─── JETPACK SFX ─────────────────────────────────────────────────────────────
func start_jetpack_sfx() -> void:
	if _jetpack_player.playing:
		return
	var path : String = SFX_EVENTS["jetpack_thrust"]
	if ResourceLoader.exists(path):
		_jetpack_player.stream = load(path)
		_jetpack_player.play()

func stop_jetpack_sfx() -> void:
	if _jetpack_player.playing:
		_jetpack_player.stop()
		play_sfx("jetpack_end")

# ─── MUSIC API ────────────────────────────────────────────────────────────────
func play_music(layer_id: String, fade_duration: float = 1.5) -> void:
	if layer_id == current_music:
		return
	if not MUSIC_LAYERS.has(layer_id):
		push_warning("AudioManager.play_music: unknown layer '%s'" % layer_id)
		return

	current_music = layer_id
	music_layer_changed.emit(layer_id)
	_log("Music → %s" % layer_id)

	var path : String = MUSIC_LAYERS[layer_id]
	if path.is_empty():
		_fade_music_out(fade_duration)
		return

	if ResourceLoader.exists(path):
		_crossfade_to(path, fade_duration)
	else:
		_log("Music asset missing: %s" % path)

func _crossfade_to(path: String, duration: float) -> void:
	is_music_fading = true
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, duration * 0.5)
	await tween.finished
	_music_player.stream = load(path)
	_music_player.play()
	var tween2 := create_tween()
	tween2.tween_property(_music_player, "volume_db", 0.0, duration * 0.5)
	await tween2.finished
	is_music_fading = false

func _fade_music_out(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -80.0, duration)
	await tween.finished
	_music_player.stop()

# ─── WHISPER SYSTEM ───────────────────────────────────────────────────────────
func _on_whisper_played(text: String) -> void:
	## AudioManager receives the whisper — plays ambient bleed sound + emits for HUD
	play_sfx("bleed_glitch")
	whisper_displayed.emit(text)

func _on_distortion_started(_intensity: float, _duration: float) -> void:
	play_sfx("bleed_glitch")

func _on_player_died() -> void:
	play_sfx("player_die")
	_fade_music_out(2.0)

# ─── VOLUME SETTINGS ─────────────────────────────────────────────────────────
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_set_bus_db(MASTER_BUS, linear_to_db(master_volume))

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_set_bus_db(MUSIC_BUS, linear_to_db(music_volume))

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_db(SFX_BUS, linear_to_db(sfx_volume))

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[AudioManager | F%d] %s" % [_frame_count, msg])
