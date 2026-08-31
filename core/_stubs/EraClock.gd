extends Node
## STUB — referenced by save_service.gd (EraClock.current_era, .set_era())
## but no source file for this singleton was ever provided.

signal era_changed(new_era: int)

var current_era: int = 0

func set_era(value: int) -> void:
	current_era = value
	era_changed.emit(current_era)
