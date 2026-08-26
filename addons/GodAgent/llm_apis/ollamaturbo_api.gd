@tool
class_name OllamaTurboAPI
extends LLMInterface

var _last_tokens_used: int = 0

## Headers usados en requests HTTP
var _headers: PackedStringArray


func _initialize() -> void:
	_rebuild_headers()

	if llm_config_changed.is_connected(_rebuild_headers) == false:
		llm_config_changed.connect(_rebuild_headers)


func _rebuild_headers() -> void:
	_headers = PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key,
	])


# ============================================================
# MODELS
# ============================================================

func send_get_models_request(http_request: HTTPRequest) -> bool:
	if not super.send_get_models_request(http_request):
		return false
	var error: int = http_request.request(
		_models_url,
		_headers,
		HTTPClient.METHOD_GET
	)

	if error != OK:
		_busy = false
		push_error("Something went wrong with last AI API call: %s" % _models_url)
		return false

	return true


func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		return [INVALID_RESPONSE]

	var response = json.get_data()
	if typeof(response) != TYPE_DICTIONARY:
		return [INVALID_RESPONSE]

	if response.has("models"):
		var model_names: Array[String] = []

		for entry in response["models"]:
			if entry.has("model"):
				model_names.append(entry["model"])

		model_names.sort()
		return model_names

	return [INVALID_RESPONSE]


# ============================================================
# CHAT
# ============================================================

func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if not super.send_chat_request(http_request, content):
		return false
	if model.is_empty():
		_busy = false
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false

	var body_dict: Dictionary = {
		"messages": content,
		"stream": false,
		"model": model,
	}

	if override_temperature:
		body_dict["options"] = {
			"temperature": temperature
		}

	var body: String = JSON.new().stringify(body_dict)

	var error: int = http_request.request(
		_chat_url,
		_headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		_busy = false
		push_error(
			"Something went wrong with last AI API call.\nURL: %s\nBody:\n%s"
			% [_chat_url, body]
		)
		return false

	return true


func read_response(body: PackedByteArray) -> String:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())

	if parse_error != OK:
		_last_tokens_used = 0
		return LLMInterface.INVALID_RESPONSE

	var response = json.get_data()
	if typeof(response) != TYPE_DICTIONARY:
		_last_tokens_used = 0
		return LLMInterface.INVALID_RESPONSE

	# Guardar tokens usados
	if response.has("usage") and response["usage"].has("total_tokens"):
		_last_tokens_used = int(response["usage"]["total_tokens"])
	else:
		_last_tokens_used = 0

	if response.has("message") and response["message"].has("content"):
		return ResponseCleaner.clean(response["message"]["content"])

	return LLMInterface.INVALID_RESPONSE


func get_tokens_used() -> int:
	return _last_tokens_used
