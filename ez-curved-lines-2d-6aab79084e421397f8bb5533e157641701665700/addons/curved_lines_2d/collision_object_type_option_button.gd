@tool
extends OptionButton

signal type_selected(obj_type : ScalableVectorShape2D.CollisionObjectType)


func _on_item_selected(index: int) -> void:
	type_selected.emit(index)
