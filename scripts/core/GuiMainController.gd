extends CanvasLayer
class_name GuiMainController

@onready var panel: PanelContainer = $Panel
@onready var state_label: Label = $Panel/Margin/VBox/StateLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel
@onready var seed_edit: LineEdit = $Panel/Margin/VBox/SeedRow/SeedEdit
@onready var time_scale: HSlider = $Panel/Margin/VBox/TimeScaleRow/TimeScale
@onready var dbg_toggle: CheckBox = $Panel/Margin/VBox/Toggles/DebugOverlay
@onready var regen_btn: Button = $Panel/Margin/VBox/Buttons/RegenButton
@onready var manifest_btn: Button = $Panel/Margin/VBox/Buttons/ManifestButton
@onready var tel_toggle: CheckBox = $Panel/Margin/VBox/Toggles/TelemetryOptIn

var _visible := false

func _ready() -> void:
\tpanel.visible = false
\t_bind_singletons()

func _process(_delta: float) -> void:
\tfps_label.text = "FPS: %d" % int(Engine.get_frames_per_second())

func _unhandled_input(event: InputEvent) -> void:
\tif event.is_action_pressed("ui_debug"):
\t\t_visible = !_visible
\t\tpanel.visible = _visible
\t\tget_viewport().set_input_as_handled()

\t# Optional: log actions if telemetry enabled
\tif event is InputEventAction and event.pressed and has_node("/root/Telemetry"):
\t\tget_node("/root/Telemetry").log_action(event.action)

func _bind_singletons() -> void:
\tif has_node("/root/GameLoop"):
\t\tvar gl := get_node("/root/GameLoop")
\t\tgl.state_changed.connect(_on_state_changed)
\t\t_on_state_changed(gl.current_state, gl.current_state)
\t\ttime_scale.value = gl.time_scale

\ttime_scale.value_changed.connect(_on_timescale_changed)
\tregen_btn.pressed.connect(_on_regen_pressed)
\tmanifest_btn.pressed.connect(_on_manifest_pressed)
\ttel_toggle.toggled.connect(_on_telemetry_toggled)

func _on_state_changed(_old: int, new_state: int) -> void:
\tif has_node("/root/GameLoop"):
\t\tvar gl := get_node("/root/GameLoop")
\t\tstate_label.text = "State: %s" % GameLoop.State.keys()[new_state]
\t\tif has_node("/root/Telemetry"):
\t\t\tget_node("/root/Telemetry").log_state_change(_old, new_state)

func _on_timescale_changed(v: float) -> void:
\tif has_node("/root/GameLoop"):
\t\tget_node("/root/GameLoop").set_timescale(v)

func _on_regen_pressed() -> void:
\t# Placeholder: later call your procgen singleton
\tvar seed := int(seed_edit.text) if seed_edit.text.is_valid_int() else randi()
\tif has_node("/root/GameLoop"):
\t\tget_node("/root/GameLoop").start_run(seed)

func _on_manifest_pressed() -> void:
\tif has_node("/root/BuildManifest"):
\t\tget_node("/root/BuildManifest").write_manifest()

func _on_telemetry_toggled(v: bool) -> void:
\tif has_node("/root/Telemetry"):
\t\tget_node("/root/Telemetry").set_enabled(v)