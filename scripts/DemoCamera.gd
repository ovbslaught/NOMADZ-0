extends Camera3D

## Orbit camera for looking at the sky.
##
##   LMB + mouse move  - look around
##   wheel             - move closer to / further from the props
##   space             - pause/resume time (freezes the clouds for a screenshot)

@export var target := Vector3(0.0, 9.0, 0.0)
@export var distance := 18.0
@export var yaw := -58.0
@export var pitch := 25.0

var _dragging := false
var _paused := false


func _ready() -> void:
	_apply()


func _apply() -> void:
	var y := deg_to_rad(yaw)
	var p := deg_to_rad(pitch)
	var offset := Vector3(
		cos(p) * sin(y),
		sin(p),
		cos(p) * cos(y)) * distance
	# The camera sits on an orbit around the target and always faces it.
	look_at_from_position(target - offset, target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(2.0, distance - 1.0)
				_apply()
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(120.0, distance + 1.0)
				_apply()
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.3
		pitch = clampf(pitch - event.relative.y * 0.3, -85.0, 85.0)
		_apply()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_paused = not _paused
			# Freezing time freezes TIME in the shader - handy for judging the
			# cloud shape or taking a screenshot.
			Engine.time_scale = 0.0 if _paused else 1.0
