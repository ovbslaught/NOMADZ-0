extends Node
class_name PhysicsDrift

var drift: float = 1.0

func _ready():
\tProjectSettings.set_setting("physics/3d/default_gravity", 9.8 * drift)

func apply_drift():
\tdrift *= 0.99  # Decay per death
\tProjectSettings.set_setting("physics/3d/default_gravity", 9.8 * drift)