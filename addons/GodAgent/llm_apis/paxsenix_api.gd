@tool
class_name PaxsenixAPI
extends LLMInterface

var headers: PackedStringArray = []

func _initialize() -> void:
	llm_config_changed.connect(_rebuild_headers)
	_rebuild_headers()


func _rebuild_headers() -> void:
	headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % _api_key
	 ]


func send_get_models_request(http_request: HTTPRequest) -> bool:
	if not _is_ready:
		push_error("Paxsenix not ready.")
		return false

	return http_request.request(
		_models_url,
		headers,
		HTTPClient.METHOD_GET
	) == OK


func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return [INVALID_RESPONSE]

	var data := json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return [INVALID_RESPONSE]

	if data.has("data"):
		var models: Array[String] = []
		for m in data["data"]:
			if m.has("id"):
				models.append(m["id"])
		return models

	return [INVALID_RESPONSE]


func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if not _is_ready:
		push_error("Paxsenix not ready.")
		return false

	var body := {
		"model": model,
		"messages": content
	}

	if override_temperature:
		body["temperature"] = temperature

	return http_request.request(
		_chat_url,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	) == OK


func read_response(body: PackedByteArray) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return INVALID_RESPONSE

	var data := json.get_data()

	if typeof(data) != TYPE_DICTIONARY:
		return INVALID_RESPONSE

	if data.has("choices") and data["choices"].size() > 0:
		return data["choices"][0]["message"]["content"]

	return INVALID_RESPONSE
