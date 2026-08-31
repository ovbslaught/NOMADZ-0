extends Node
# Central state: mode, pause, quit, global signals.

enum ViewMode { TOPDOWN, SIDEVIEW, HYBRID }

var view_mode: ViewMode = ViewMode.TOPDOWN
var paused: bool = false
var player_ref: Node = null

signal mode_changed(new_mode: ViewMode)
signal game_paused(state: bool)

func set_view_mode(m: ViewMode) -> void:
    if view_mode == m:
        return
    view_mode = m
    emit_signal("mode_changed", m)

func set_paused(state: bool) -> void:
    paused = state
    get_tree().paused = state
    emit_signal("game_paused", state)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause"):
        set_paused(!paused)
