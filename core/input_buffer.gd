extends Node
# Per-action frame countdown buffer.
# Use: InputBuffer.is_recent("attack") instead of Input.is_action_just_pressed

const BUFFER_FRAMES := 8

var _timers: Dictionary = {}

func _process(_dt: float) -> void:
    for action in _timers.keys():
        if Input.is_action_just_pressed(action):
            _timers[action] = BUFFER_FRAMES
        elif _timers[action] > 0:
            _timers[action] -= 1

func register(action: StringName) -> void:
    _timers[action] = 0

func is_recent(action: StringName) -> bool:
    return _timers.get(action, 0) > 0

func consume(action: StringName) -> bool:
    if _timers.get(action, 0) > 0:
        _timers[action] = 0
        return true
    return false

func is_held(action: StringName) -> bool:
    return Input.is_action_pressed(action)

func _ready() -> void:
    for a in ["attack","item","jump","interact","era_shift"]:
        register(a)
