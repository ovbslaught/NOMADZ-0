# ProtonCharge.gd - Uridium-based charge mechanic
extends Area3D

signal charge_depleted
signal charge_maxed

@export var max_charge: float = 100.0
@export var drain_rate: float = 5.0
@export var recharge_rate: float = 2.5

var current_charge: float = 100.0
var is_active: bool = false

func _process(delta: float) -> void:
    if is_active:
        current_charge -= drain_rate * delta
        current_charge = clamp(current_charge, 0.0, max_charge)
        if current_charge <= 0.0:
            charge_depleted.emit()
            is_active = false
    else:
        current_charge += recharge_rate * delta
        current_charge = clamp(current_charge, 0.0, max_charge)
        if current_charge >= max_charge:
            charge_maxed.emit()

func activate() -> void:
    if current_charge > 0.0:
        is_active = true
        Director.proton_charge_initiated.emit()

func deactivate() -> void:
    is_active = false

func get_charge_percent() -> float:
    return current_charge / max_charge
