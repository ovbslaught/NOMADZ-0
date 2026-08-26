@tool
class_name AIAnswerHandler

signal bot_message_produced(message: String)
signal error_message_produced(message: String)

const COMMENT_LENGTH := 80

# Code writer removed - was only for quick prompts


func _init(plugin: EditorPlugin) -> void:
	pass # Code writer initialization removed


func handle(text_answer: String) -> void:
	# Quick prompts removed - simple chat only
	bot_message_produced.emit(text_answer)

