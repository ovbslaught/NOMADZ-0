## Main.gd
## Node — NOMADZ: Signal Descent
## Root scene controller. Manages room transitions, game loop states,
## player spawning, and scene-level coordination.
## VultureCode / Sol / NOMADZ Universe

class_name Main
extends Node

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const DEBUG_MODE := true

## Room scene registry — maps room_id to packed scene path
const ROOM_REGISTRY : Dictionary = {
	"room_crash_site"       : "res://scenes/rooms/CrashSite.tscn",
	"room_bone_shafts_1"    : "res://scenes/rooms/BoneShafts1.tscn",
	"room_bone_shafts_2"    : "res://scenes/rooms/BoneShafts2.tscn",
	"room_signal_relay"     : "res://scenes/rooms/SignalRelay.tscn",
	"room_luminous_substrate": "res://scenes/rooms/LuminousSubstrate.tscn",
	"room_vulture_eye_antechamber": "res://scenes/rooms/VultureEyeAntechamber.tscn",
	"room_vulture_eye_boss" : "res://scenes/rooms/VultureEyeBossRoom.tscn",
	"room_mother_brain_core": "res://scenes/rooms/MotherBrainCore.tscn",
}

## Player scene
const PLAYER_SCENE := "res://player/Player.tscn"

## Transition scene (fade black)
const TRANSITION_SCENE := "res://scenes/Transition.tscn"

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var room_root      : Node2D     = $RoomRoot
@onready var player_root    : Node2D     = $PlayerRoot
@onready var hud            : CanvasLayer = $HUD
@onready var pause_menu     : CanvasLayer = $PauseMenu
@onready var debug_overlay  : CanvasLayer = $DebugOverlay
@onready var transition_anim: AnimationPlayer = $TransitionLayer/AnimationPlayer
@onready var transition_rect: ColorRect  = $TransitionLayer/FadeRect

# ─── STATE ────────────────────────────────────────────────────────────────────
var _current_room    : Node    = null
var _player          : Node2D  = null
var _is_transitioning: bool    = false
var _frame_count     : int     = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("main_controller")
	_connect_global_signals()
	_spawn_player()
	_load_start_room()
	_log("Main scene ready — ARCHON Protocol active")

func _connect_global_signals() -> void:
	GameManager.game_over.connect(_on_game_over)
	GameManager.game_loaded.connect(_on_game_loaded)
	GameManager.player_died.connect(_on_player_died)

func _spawn_player() -> void:
	if not ResourceLoader.exists(PLAYER_SCENE):
		push_warning("Main: Player scene not found at %s — using placeholder" % PLAYER_SCENE)
		_player = CharacterBody2D.new()
		_player.add_to_group("player")
		player_root.add_child(_player)
		return

	var packed : PackedScene = load(PLAYER_SCENE)
	_player = packed.instantiate()
	_player.add_to_group("player")
	player_root.add_child(_player)
	_log("Player spawned")

func _load_start_room() -> void:
	var start_room := GameManager.current_room_id
	if not ROOM_REGISTRY.has(start_room):
		start_room = ROOM_REGISTRY.keys()[0]
		_log("Start room '%s' not in registry — defaulting to '%s'" % [GameManager.current_room_id, start_room])

	_load_room(start_room, "SpawnPoint", false)

# ─── ROOM TRANSITIONS ─────────────────────────────────────────────────────────
## Called by doors via group call
func transition_to_room(room_id: String, spawn_marker: String = "SpawnPoint") -> void:
	if _is_transitioning:
		_log("Transition already in progress — skipping")
		return
	if not ROOM_REGISTRY.has(room_id):
		push_error("Main: Room '%s' not in ROOM_REGISTRY" % room_id)
		return
	_log("Transition: %s → %s [marker: %s]" % [GameManager.current_room_id, room_id, spawn_marker])
	_load_room(room_id, spawn_marker, true)

func _load_room(room_id: String, spawn_marker: String, animated: bool) -> void:
	_is_transitioning = true

	if animated:
		await _fade_out()

	## Remove current room
	if is_instance_valid(_current_room):
		if _current_room.has_method("deactivate_room"):
			_current_room.deactivate_room()
		_current_room.queue_free()
		_current_room = null
		await get_tree().process_frame

	## Load new room
	var path : String = ROOM_REGISTRY.get(room_id, "")
	if path.is_empty():
		push_error("Main: empty path for room '%s'" % room_id)
		_is_transitioning = false
		return

	if not ResourceLoader.exists(path):
		push_error("Main: room scene not found: %s" % path)
		_is_transitioning = false
		return

	var packed : PackedScene = load(path)
	_current_room = packed.instantiate()
	room_root.add_child(_current_room)

	## Place player at spawn marker
	_place_player(_current_room, spawn_marker)

	## Activate room
	if _current_room.has_method("activate_room"):
		_current_room.activate_room(_player)

	if animated:
		await _fade_in()

	_is_transitioning = false
	_log("Room loaded: %s" % room_id)

func _place_player(room: Node, marker_name: String) -> void:
	if _player == null:
		return

	var marker := room.get_node_or_null(marker_name)
	if marker == null:
		marker = room.get_node_or_null("SpawnPoint")

	if marker is Node2D:
		_player.global_position = (marker as Node2D).global_position
		GameManager.set_checkpoint(_player.global_position)
	else:
		_player.global_position = Vector2(100, 100)
		push_warning("Main: spawn marker '%s' not found in room" % marker_name)

# ─── FADE TRANSITIONS ─────────────────────────────────────────────────────────
func _fade_out() -> void:
	if not is_instance_valid(transition_rect):
		return
	transition_rect.visible  = true
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, 0.35)
	await tween.finished

func _fade_in() -> void:
	if not is_instance_valid(transition_rect):
		return
	await get_tree().create_timer(0.1).timeout
	var tween := create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, 0.35)
	await tween.finished
	transition_rect.visible = false

# ─── GAME EVENTS ─────────────────────────────────────────────────────────────
func _on_player_died() -> void:
	_log("Player died — respawn sequence")
	await get_tree().create_timer(3.0).timeout
	_respawn_player()

func _respawn_player() -> void:
	GameManager.respawn_at_checkpoint()
	_load_room(GameManager.current_room_id, "SpawnPoint", true)

func _on_game_over() -> void:
	_log("GAME OVER — NORA signal lost")
	## Show game over screen — placeholder
	await get_tree().create_timer(2.0).timeout
	## Reload to title (placeholder)
	get_tree().reload_current_scene()

func _on_game_loaded() -> void:
	_log("Game loaded — re-entering room: %s" % GameManager.current_room_id)
	_load_room(GameManager.current_room_id, "SpawnPoint", false)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	_frame_count += 1

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[Main | F%d] %s" % [_frame_count, msg])
