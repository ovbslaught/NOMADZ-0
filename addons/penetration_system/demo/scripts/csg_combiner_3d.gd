extends CSGCombiner3D

@export var _material : StringName 

func _ready() -> void:
	#set all children materials
	set_meta(&"material", _material)
	
	for child in get_children(true):
		child.set_meta(&"material", _material)
