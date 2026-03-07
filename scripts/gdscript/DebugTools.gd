# DebugTools.gd - Autoload debug overlay and logging
extends CanvasLayer

@export var enabled: bool = true
@export var show_fps: bool = true
@export var show_tension: bool = true

@onready var fps_label: Label = $FPSLabel
@onready var tension_label: Label = $TensionLabel
@onready var log_panel: RichTextLabel = $LogPanel

var log_buffer: Array[String] = []
const MAX_LOG = 50

func _ready():
    if not enabled:
        hide()
        return
    Director.world_tension_changed.connect(_on_tension_changed)

func _process(_delta: float) -> void:
    if not enabled:
        return
    if show_fps:
        fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _on_tension_changed(t: float) -> void:
    if show_tension:
        tension_label.text = "TENSION: %.2f" % t

func log(msg: String) -> void:
    var ts = Time.get_datetime_string_from_system()
    var entry = "[%s] %s" % [ts, msg]
    log_buffer.append(entry)
    if log_buffer.size() > MAX_LOG:
        log_buffer.pop_front()
    log_panel.text = "
".join(log_buffer)
    print(entry)
