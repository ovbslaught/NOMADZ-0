@tool
extends HBoxContainer

signal selected(item: Control)
signal delete_requested(item: Control)

@onready var label: Button = $ChatTitle
@onready var delete_btn: Button = $DeleteBtn

var chat_path: String = ""

func setup(title: String, path: String) -> void:
	if not is_node_ready(): await ready
	label.text = title
	chat_path = path

func _on_chat_title_pressed() -> void:
	selected.emit(self)

func _on_delete_btn_pressed() -> void:
	delete_requested.emit(self)
