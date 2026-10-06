class_name CustomArtifactItem
extends CogitoItem

@export_group("Artifact Properties")
@export var signal_charge: float = 100.0
@export var is_harmonic: bool = true

func use(player_interaction: Node) -> bool:
if signal_charge > 0.0:
signal_charge -= 10.0
return true
return false
