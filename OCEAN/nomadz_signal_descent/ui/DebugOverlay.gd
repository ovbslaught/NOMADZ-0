## DebugOverlay.gd
## CanvasLayer — NOMADZ: Signal Descent
## F1 toggleable debug overlay. Shows all subsystem snapshots.
## Only active in debug builds. Always-on if DEBUG_FORCE = true.
## VultureCode / Sol / NOMADZ Universe

class_name DebugOverlay
extends CanvasLayer

const DEBUG_FORCE := true    ## Set false for release builds

@onready var label : RichTextLabel = $DebugLabel

var _visible : bool = false
var _player  : Node2D = null
var _frame   : int = 0

func _ready() -> void:
	layer = 100
	if not DEBUG_FORCE:
		queue_free()
		return

	if is_instance_valid(label):
		label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   ## F1 or Escape depending on mapping
		_toggle()
	## Quick-toggle with backtick
	if event is InputEventKey:
		if (event as InputEventKey).physical_keycode == KEY_QUOTELEFT and event.pressed:
			_toggle()

func _toggle() -> void:
	_visible = not _visible
	if is_instance_valid(label):
		label.visible = _visible
	if _visible:
		_find_player()

func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0] as Node2D

func _process(_delta: float) -> void:
	if not _visible or not is_instance_valid(label):
		return
	_frame += 1
	if _frame % 6 != 0:  ## Update 10fps
		return
	label.text = _build_text()

func _build_text() -> String:
	var lines : Array[String] = []
	lines.append("[b][color=cyan]≡ NOMADZ: SIGNAL DESCENT — DEBUG OVERLAY ≡[/color][/b]")
	lines.append("[color=gray]FPS: %d | Frame: %d[/color]" % [Engine.get_frames_per_second(), _frame])
	lines.append("")

	## GameManager
	lines.append("[color=yellow]── GAME MANAGER ──[/color]")
	if GameManager:
		var snap := GameManager.get_debug_snapshot()
		for k in snap:
			lines.append("  %s: %s" % [k, str(snap[k])])
	else:
		lines.append("  [color=red]GameManager OFFLINE[/color]")

	lines.append("")

	## SignalverseManager
	lines.append("[color=magenta]── SIGNALVERSE ──[/color]")
	if SignalverseManager:
		var snap := SignalverseManager.get_debug_snapshot()
		for k in snap:
			lines.append("  %s: %s" % [k, str(snap[k])])

	lines.append("")

	## Player
	lines.append("[color=cyan]── PLAYER ──[/color]")
	if is_instance_valid(_player) and _player.has_method("get_debug_snapshot"):
		var snap := _player.get_debug_snapshot()
		for k in snap:
			lines.append("  %s: %s" % [k, str(snap[k])])
	else:
		_find_player()
		lines.append("  [searching for player...]")

	lines.append("")

	## Lore
	lines.append("[color=green]── LORE ──[/color]")
	if LoreDatabase:
		lines.append("  Discovered: %.0f%%" % LoreDatabase.get_discovery_percent())

	lines.append("")
	lines.append("[color=gray]` or ESC to close[/color]")

	return "\n".join(lines)
