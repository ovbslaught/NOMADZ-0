@tool
extends Control

@onready var chat_display = $VBoxContainer/ChatDisplay
@onready var input_field = $VBoxContainer/HBoxContainer/InputField
@onready var send_button = $VBoxContainer/HBoxContainer/SendButton
@onready var http_request = $HTTPRequest

const API_URL = "http://127.0.0.1:11033/v1/chat/completions"

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	send_button.pressed.connect(_on_send_pressed)
	http_request.request_completed.connect(_on_request_completed)

func _on_send_pressed() -> void:
	var prompt = input_field.text.strip_edges()
	if prompt.is_empty():
		return
	
	chat_display.text += "\n[b]NOMADZ:[/b] " + prompt
	input_field.text = ""
	
	var body = JSON.stringify({
		"model": "nomadz-local-llm",
		"messages": [{"role": "user", "content": prompt}]
	})
	var headers = ["Content-Type: application/json"]
	http_request.request(API_URL, headers, HTTPClient.METHOD_POST, body)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		var reply = response["choices"][0]["message"]["content"]
		chat_display.text += "\n\n[b]ARCHON:[/b] " + reply + "\n"
	else:
		chat_display.text += "\n\n[color=red][SYSTEM ERROR] Telemetry disconnected.[/color]\n"
