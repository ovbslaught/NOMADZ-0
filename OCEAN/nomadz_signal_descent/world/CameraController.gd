## CameraController.gd
## Camera2D — NOMADZ: Signal Descent
## Smooth follow with room limit locking, trauma-based screen shake,
## zoom transitions, and Signalverse distortion offset.
## VultureCode / Sol / NOMADZ Universe

class_name CameraController
extends Camera2D

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var follow_speed      : float = 5.0
@export var lookahead_x       : float = 40.0   ## Pixels ahead of player
@export var lookahead_y       : float = 20.0
@export var default_zoom      : Vector2 = Vector2(1.5, 1.5)
@export var boss_zoom         : Vector2 = Vector2(1.0, 1.0)
@export var zoom_speed        : float  = 2.0
@export var max_shake_offset  : float  = 12.0
@export var shake_decay       : float  = 4.0    ## Per second

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false

var _target          : Node2D = null
var _trauma          : float  = 0.0   ## 0-1; trauma squared = shake intensity
var _shake_offset    : Vector2 = Vector2.ZERO
var _target_zoom     : Vector2 = Vector2.ONE
var _bleed_offset    : Vector2 = Vector2.ZERO
var _frame_count     : int    = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	zoom          = default_zoom
	_target_zoom  = default_zoom
	position_smoothing_enabled = false  ## We handle smoothing manually
	_connect_signals()
	_log("CameraController ready")

func _connect_signals() -> void:
	if SignalverseManager:
		SignalverseManager.distortion_started.connect(_on_distortion_started)
		SignalverseManager.distortion_ended.connect(_on_distortion_ended)
	if GameManager:
		GameManager.room_changed.connect(_on_room_changed)

func set_target(node: Node2D) -> void:
	_target = node

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_frame_count += 1
	if _target == null:
		_auto_find_target()
		return

	_follow(delta)
	_tick_shake(delta)
	_tick_zoom(delta)
	_tick_bleed_offset(delta)

func _auto_find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_target = players[0] as Node2D

func _follow(delta: float) -> void:
	if _target == null:
		return

	## Lookahead based on player velocity
	var lookahead := Vector2.ZERO
	if _target.has_method("get") and _target.get("velocity") != null:
		var vel : Vector2 = _target.velocity
		lookahead.x = sign(vel.x) * lookahead_x * clampf(absf(vel.x) / 180.0, 0.0, 1.0)
		lookahead.y = sign(vel.y) * lookahead_y * clampf(absf(vel.y) / 300.0, 0.0, 0.5)

	var target_pos := _target.global_position + lookahead
	global_position = global_position.lerp(target_pos, follow_speed * delta)

func _tick_shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - shake_decay * delta)
	var shake := _trauma * _trauma
	_shake_offset = Vector2(
		randf_range(-max_shake_offset, max_shake_offset) * shake,
		randf_range(-max_shake_offset, max_shake_offset) * shake
	)
	offset = _shake_offset + _bleed_offset

func _tick_zoom(delta: float) -> void:
	zoom = zoom.lerp(_target_zoom, zoom_speed * delta)

func _tick_bleed_offset(delta: float) -> void:
	## Subtle random drift when corruption is high
	var corruption := SignalverseManager.corruption_level / 100.0
	if corruption > 0.5:
		var drift_strength := (corruption - 0.5) * 4.0
		_bleed_offset = _bleed_offset.lerp(
			Vector2(randf_range(-2, 2), randf_range(-2, 2)) * drift_strength,
			delta * 3.0
		)
	else:
		_bleed_offset = _bleed_offset.lerp(Vector2.ZERO, delta * 5.0)

# ─── PUBLIC API ───────────────────────────────────────────────────────────────
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)

func set_boss_mode(active: bool) -> void:
	_target_zoom = boss_zoom if active else default_zoom

# ─── SIGNALS ──────────────────────────────────────────────────────────────────
func _on_distortion_started(intensity: float, _duration: float) -> void:
	add_trauma(intensity * 0.6)

func _on_distortion_ended() -> void:
	pass

func _on_room_changed(room_id: String) -> void:
	var is_boss := room_id.contains("boss")
	set_boss_mode(is_boss)

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[CameraController | F%d] %s" % [_frame_count, msg])
