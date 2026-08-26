@tool
extends EditorPlugin


func _enable_plugin() -> void:
	add_autoload_singleton("ItchAuth", "res://addons/itch-oauth/OAuth Manager/oauth_manager.tscn")


func _disable_plugin() -> void:
	remove_autoload_singleton("ItchAuth")


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
