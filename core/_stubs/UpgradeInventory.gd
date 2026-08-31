extends Node
## STUB — referenced by save_service.gd (UpgradeInventory.export(), .import())
## but no source file for this singleton was ever provided.

var _upgrades: Array = []

func export() -> Array:
	return _upgrades.duplicate()

func import(list: Array) -> void:
	_upgrades = list.duplicate()
