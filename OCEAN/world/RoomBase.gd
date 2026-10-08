## RoomBase.gd
## Node2D — NOMADZ: Signal Descent
## Base class for all rooms. Handles: room entry/exit, atmosphere, camera bounds,
## enemy spawning, door management, checkpoint registration.
## VultureCode / Sol / NOMADZ Universe

class_name RoomBase
extends Node2D

# ─── SIGNALS ─────────────────────────────────────────────────────────────────
signal room_entered(room_id: String)
signal room_exited(room_id: String)
signal all_enemies_cleared()
signal secret_found(secret_id: String)

# ─── EXPORTS ──────────────────────────────────────────────────────────────────
@export var room_id          : String  = "room_undefined"
@export var room_display_name: String  = "Unknown Sector"
@export var music_layer      : String  = "descent"
@export var bleed_intensity  : float   = 0.3    ## 0 = clean, 1 = max corruption push
@export var requires_ability : String  = ""     ## Locks door if player lacks ability
@export var is_boss_room     : bool    = false
@export var ambient_color    : Color   = Color(0.02, 0.02, 0.05, 1.0)
@export var fog_density      : float   = 0.02
@export var checkpoint_pos   : Vector2 = Vector2.ZERO

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var camera_limits   : Node2D        = $CameraLimits       ## Has children marking bounds
@onready var enemy_container : Node2D        = $Enemies
@onready var item_container  : Node2D        = $Items
@onready var door_container  : Node2D        = $Doors
@onready var atmosphere      : WorldEnvironment = $WorldEnvironment
@onready var entry_trigger   : Area2D        = $EntryTrigger
@onready var spawn_point     : Marker2D      = $SpawnPoint

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := true

var is_active         : bool = false
var enemies_cleared   : bool = false
var has_been_visited  : bool = false
var _enemies_alive    : int  = 0
var _frame_count      : int  = 0

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_validate_room_id()
	_count_enemies()
	_connect_doors()
	_connect_entry_trigger()
	_configure_atmosphere()
	_log("Room ready: %s" % room_id)

func _validate_room_id() -> void:
	if room_id == "room_undefined" or room_id.is_empty():
		push_error("RoomBase: room_id not set on '%s'" % name)

func _count_enemies() -> void:
	if not is_instance_valid(enemy_container):
		return
	_enemies_alive = enemy_container.get_child_count()

func _connect_doors() -> void:
	if not is_instance_valid(door_container):
		return
	for door in door_container.get_children():
		if door.has_signal("player_entered_door"):
			door.player_entered_door.connect(_on_player_entered_door)

func _connect_entry_trigger() -> void:
	if not is_instance_valid(entry_trigger):
		return
	entry_trigger.body_entered.connect(_on_entry_trigger_body_entered)

func _configure_atmosphere() -> void:
	if not is_instance_valid(atmosphere):
		return
	var env := atmosphere.environment
	if env == null:
		env = Environment.new()
		atmosphere.environment = env
	env.background_color = ambient_color
	env.fog_enabled       = fog_density > 0.0
	env.fog_density       = fog_density

# ─── ROOM ACTIVATION ──────────────────────────────────────────────────────────
func activate_room(player: Node2D) -> void:
	if is_active:
		return
	is_active      = true
	has_been_visited = true

	GameManager.enter_room(room_id)
	room_entered.emit(room_id)
	AudioManager.play_music(music_layer)

	## Register checkpoint
	var cp_world := global_position + checkpoint_pos
	if cp_world != global_position:
		GameManager.set_checkpoint(cp_world)

	## Apply bleed push
	if bleed_intensity > 0:
		SignalverseManager.corruption_level = minf(
			100.0,
			SignalverseManager.corruption_level + bleed_intensity * 15.0
		)

	## Set camera limits
	_apply_camera_limits(player)

	_log("Room activated: %s" % room_id)

func deactivate_room() -> void:
	if not is_active:
		return
	is_active = false
	room_exited.emit(room_id)
	_log("Room deactivated: %s" % room_id)

# ─── CAMERA ───────────────────────────────────────────────────────────────────
func _apply_camera_limits(player: Node2D) -> void:
	var cam := _find_camera(player)
	if cam == null:
		return

	if not is_instance_valid(camera_limits):
		return

	## Expect children named: LimitLeft, LimitRight, LimitTop, LimitBottom
	var limit_left   := camera_limits.get_node_or_null("LimitLeft")
	var limit_right  := camera_limits.get_node_or_null("LimitRight")
	var limit_top    := camera_limits.get_node_or_null("LimitTop")
	var limit_bottom := camera_limits.get_node_or_null("LimitBottom")

	if limit_left   : cam.limit_left   = int(limit_left.global_position.x)
	if limit_right  : cam.limit_right  = int(limit_right.global_position.x)
	if limit_top    : cam.limit_top    = int(limit_top.global_position.y)
	if limit_bottom : cam.limit_bottom = int(limit_bottom.global_position.y)

func _find_camera(player: Node2D) -> Camera2D:
	if player == null:
		return null
	return player.get_node_or_null("Camera2D") as Camera2D

# ─── ENEMY TRACKING ───────────────────────────────────────────────────────────
func on_enemy_died(_position: Vector2) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	_log("Enemy died — remaining: %d" % _enemies_alive)
	if _enemies_alive == 0 and not enemies_cleared:
		enemies_cleared = true
		all_enemies_cleared.emit()
		_on_all_enemies_cleared()

func _on_all_enemies_cleared() -> void:
	_log("All enemies cleared in %s" % room_id)
	## Unlock locked doors
	if is_instance_valid(door_container):
		for door in door_container.get_children():
			if door.has_method("unlock"):
				door.unlock()

# ─── DOORS ────────────────────────────────────────────────────────────────────
func _on_player_entered_door(destination_room: String, spawn_marker: String) -> void:
	_log("Player entered door → %s : %s" % [destination_room, spawn_marker])
	deactivate_room()
	## Main scene handles the actual room transition
	get_tree().call_group("main_controller", "transition_to_room", destination_room, spawn_marker)

# ─── ENTRY TRIGGER ────────────────────────────────────────────────────────────
func _on_entry_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		activate_room(body)

# ─── SECRETS ──────────────────────────────────────────────────────────────────
func reveal_secret(secret_id: String) -> void:
	secret_found.emit(secret_id)
	GameManager.collect_lore(secret_id)
	_log("Secret found: %s" % secret_id)

# ─── PROCESS ──────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not is_active:
		return
	_frame_count += 1
	_update_atmosphere(delta)

func _update_atmosphere(delta: float) -> void:
	## Drift ambient color toward corruption tint
	if not is_instance_valid(atmosphere) or atmosphere.environment == null:
		return
	var corruption_color := SignalverseManager.get_corruption_color()
	var env := atmosphere.environment
	env.background_color = env.background_color.lerp(corruption_color, delta * 0.3)

# ─── DEBUG ────────────────────────────────────────────────────────────────────
func _log(msg: String) -> void:
	if DEBUG_MODE:
		print("[Room:%s | F%d] %s" % [room_id, _frame_count, msg])

func get_debug_snapshot() -> Dictionary:
	return {
		"room_id"         : room_id,
		"active"          : is_active,
		"enemies_alive"   : _enemies_alive,
		"enemies_cleared" : enemies_cleared,
		"visited"         : has_been_visited,
	}
