class_name ProControllerManager
extends Node

signal controller_connected(device_id: int)
signal controller_disconnected(device_id: int)
signal button_pressed(button: String, device_id: int)
signal button_released(button: String, device_id: int)
signal axis_moved(axis: String, value: float, device_id: int)

const DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.05

enum JoyBtn {
	A = 0, B = 1, X = 2, Y = 3,
	L = 4, R = 5, ZL = 6, ZR = 7,
	MINUS = 8, PLUS = 9,
	LCLICK = 10, RCLICK = 11,
	HOME = 12, CAPTURE = 13,
	DPAD_UP = 14, DPAD_DOWN = 15,
	DPAD_LEFT = 16, DPAD_RIGHT = 17,
}

enum JoyAxis {
	LX = 0, LY = 1, RX = 2, RY = 3,
	L2 = 4, R2 = 5,
}

var connected_controllers: Array[int] = []
var controller_names: Dictionary = {}
var button_mappings: Dictionary = {}
var axis_mappings: Dictionary = {}
var rumble_supported: Dictionary = {}

func _ready() -> void:
	_load_default_mappings()
	_scan_controllers()
	_update_project_settings()

func _load_default_mappings() -> void:
	button_mappings = {
		"move_left": JoyBtn.DPAD_LEFT,
		"move_right": JoyBtn.DPAD_RIGHT,
		"move_forward": JoyBtn.DPAD_UP,
		"move_back": JoyBtn.DPAD_DOWN,
		"jump": JoyBtn.A,
		"shoot": JoyBtn.X,
		"dash": JoyBtn.B,
		"signal_pulse": JoyBtn.Y,
		"interact": JoyBtn.L,
		"jetpack": JoyBtn.R,
		"map": JoyBtn.MINUS,
		"pause": JoyBtn.PLUS,
		"sprint": JoyBtn.ZL,
		"morph": JoyBtn.ZR,
	}
	axis_mappings = {
		"move_h": JoyAxis.LX,
		"move_v": JoyAxis.LY,
		"look_h": JoyAxis.RX,
		"look_v": JoyAxis.RY,
		"trigger_l": JoyAxis.L2,
		"trigger_r": JoyAxis.R2,
	}

func _scan_controllers() -> void:
	for i in range(8):
		if Input.is_joy_known(i):
			_register_controller(i)
		elif Input.get_connected_joypads().has(i):
			_register_controller(i)

func _register_controller(device_id: int) -> void:
	if device_id in connected_controllers:
		return
	connected_controllers.append(device_id)
	var name := Input.get_joy_name(device_id)
	controller_names[device_id] = name
	rumble_supported[device_id] = Input.has_feature("gamepad_rumble") or (name.to_lower().contains("pro") or name.to_lower().contains("switch") or name.to_lower().contains("xbox"))
	controller_connected.emit(device_id)
	print("[ProController] Device %d connected: %s (rumble: %s)" % [device_id, name, rumble_supported[device_id]])

func _update_project_settings() -> void:
	var actions := [
		"move_left", "move_right", "move_forward", "move_back",
		"jump", "shoot", "dash", "signal_pulse",
		"interact", "jetpack", "map", "pause",
		"sprint", "morph",
	]
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		_add_joy_button(action, button_mappings.get(action, -1))

func _add_joy_button(action: String, btn: int) -> void:
	if btn < 0: return
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == btn:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = btn
	InputMap.action_add_event(action, event)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_handle_joy_button(event)
	elif event is InputEventJoypadMotion:
		_handle_joy_axis(event)

func _handle_joy_button(event: InputEventJoypadButton) -> void:
	var btn_name := _get_button_name(event.button_index)
	if btn_name.is_empty(): return
	if event.pressed:
		button_pressed.emit(btn_name, event.device)
	else:
		button_released.emit(btn_name, event.device)

func _handle_joy_axis(event: InputEventJoypadMotion) -> void:
	var axis_name := _get_axis_name(event.axis)
	if axis_name.is_empty(): return
	var value := event.axis_value
	if absf(value) < (TRIGGER_DEADZONE if event.axis >= 4 else DEADZONE):
		value = 0.0
	axis_moved.emit(axis_name, value, event.device)

func _get_button_name(btn: int) -> String:
	match btn:
		JoyBtn.A: return "a"
		JoyBtn.B: return "b"
		JoyBtn.X: return "x"
		JoyBtn.Y: return "y"
		JoyBtn.L: return "l"
		JoyBtn.R: return "r"
		JoyBtn.ZL: return "zl"
		JoyBtn.ZR: return "zr"
		JoyBtn.MINUS: return "minus"
		JoyBtn.PLUS: return "plus"
		JoyBtn.LCLICK: return "lstick"
		JoyBtn.RCLICK: return "rstick"
		JoyBtn.HOME: return "home"
		JoyBtn.CAPTURE: return "capture"
		_: return ""

func _get_axis_name(axis: int) -> String:
	match axis:
		JoyAxis.LX: return "lx"
		JoyAxis.LY: return "ly"
		JoyAxis.RX: return "rx"
		JoyAxis.RY: return "ry"
		JoyAxis.L2: return "l2"
		JoyAxis.R2: return "r2"
		_: return ""

func get_controller_input(action: String, device_id: int = -1) -> float:
	if device_id < 0:
		device_id = _get_active_controller()
	if device_id < 0: return 0.0
	if action in ["move_left", "move_right", "move_forward", "move_back"]:
		var axis := JoyAxis.LX if action in ["move_left", "move_right"] else JoyAxis.LY
		var val := Input.get_joy_axis(device_id, axis)
		if action in ["move_right", "move_back"]:
			return maxf(0, val)
		return maxf(0, -val)
	return 1.0 if Input.is_joy_button_pressed(device_id, button_mappings.get(action, -1)) else 0.0

func _get_active_controller() -> int:
	for device in connected_controllers:
		if Input.is_joy_button_pressed(device, 0) or Input.is_joy_button_pressed(device, 1):
			return device
		for axis in range(4):
			if absf(Input.get_joy_axis(device, axis)) > DEADZONE:
				return device
	return connected_controllers[0] if connected_controllers.size() > 0 else -1

func is_controller_active() -> bool:
	return _get_active_controller() >= 0

func get_controller_name(device_id: int = -1) -> String:
	if device_id < 0: device_id = _get_active_controller()
	if device_id < 0: return "No controller"
	return controller_names.get(device_id, "Unknown")

func supports_rumble(device_id: int = -1) -> bool:
	if device_id < 0: device_id = _get_active_controller()
	if device_id < 0: return false
	return rumble_supported.get(device_id, false)

func rumble(weak: float = 1.0, strong: float = 1.0, duration: float = 0.2, device_id: int = -1) -> void:
	if device_id < 0: device_id = _get_active_controller()
	if device_id < 0 or not supports_rumble(device_id): return
	Input.start_joy_vibration(device_id, weak, strong, duration)

func stop_rumble(device_id: int = -1) -> void:
	if device_id < 0: device_id = _get_active_controller()
	if device_id < 0: return
	Input.stop_joy_vibration(device_id)

func get_debug_snapshot() -> Dictionary:
	return {
		"connected": connected_controllers.duplicate(),
		"active": _get_active_controller(),
		"active_name": get_controller_name(),
		"rumble": supports_rumble(),
	}
