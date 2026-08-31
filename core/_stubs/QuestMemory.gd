extends Node
## STUB — referenced by save_service.gd (QuestMemory.export(), .import())
## but no source file for this singleton was ever provided.

var _log: Array = []

func export() -> Array:
	return _log.duplicate()

func import(log: Array) -> void:
	_log = log.duplicate()
