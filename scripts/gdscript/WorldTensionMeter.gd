# WorldTensionMeter.gd - Global tension visualization
extends Control

@onready var tension_bar: ProgressBar = $TensionBar
@onready var tension_label: Label = $TensionLabel
@onready var pulse_anim: AnimationPlayer = $PulseAnim

func _ready():
    Director.world_tension_changed.connect(_on_tension_changed)

func _on_tension_changed(new_tension: float) -> void:
    tension_bar.value = new_tension * 100.0
    tension_label.text = "TENSION: %.0f%%" % (new_tension * 100.0)
    if new_tension > 0.75:
        pulse_anim.play("critical_pulse")
    elif new_tension > 0.5:
        pulse_anim.play("warning_pulse")
    else:
        pulse_anim.stop()
