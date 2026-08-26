@tool
class_name LLMInterface
# The intention of this class is to serve as a base class for any LLM API
# to be implemented in this plugin. It is mainly to have a clear definition
# of what properties or functions should be used by other classes.

signal model_changed(model:String)
signal override_temperature_changed(value:bool)
signal temperature_changed(temperature:float)
signal llm_config_changed

const INVALID_RESPONSE := "[INVALID_RESPONSE]"

# Public properties can be modified from the chat tab, you can subscribe to their change events
var _model: String = ""
var _override_temperature: bool = false
var _temperature: float = 0.7

var model: String:
	set(value):
		_model = value
		model_changed.emit(value)
	get:
		return _model

		
var override_temperature: bool:
	set(value):
		_override_temperature = value
		override_temperature_changed.emit(value)
	get:
		return _override_temperature
		
var temperature: float:
	set(value):
		_temperature = value
		temperature_changed.emit(value)
	get:
		return _temperature

var _base_url:String
var _models_url:String
var _chat_url:String
var _api_key:String
var _busy := false
var _is_ready := false
var _llm_provider: Resource

func is_busy() -> bool:
	return _busy


func _set_busy(value: bool) -> void:
	_busy = value


func clear_busy() -> void:
	_busy = false


func setup(provider: Resource) -> void:
	if provider == null:
		push_error("Tried to setup LLM instance with no provider.")
		return
	_llm_provider = provider
	load_llm_parameters()
	_initialize()


func load_llm_parameters() -> void:
	_is_ready = false
	var config = LLMConfigManager.new(_llm_provider.api_id)

	if _llm_provider.fix_url.is_empty():
		_base_url = config.load_url()
	else:
		_base_url = _llm_provider.fix_url

	if _base_url.is_empty():
		push_error("LLM base URL is empty.")
		return

	# Si no tiene protocolo -> romper
	if not _base_url.begins_with("http"):
		push_error("Invalid LLM base URL: %s" % _base_url)
		return

	if not _llm_provider.models_url_postfix.is_empty() and not _llm_provider.models_url_postfix.begins_with("/"):
		push_error("models_url_postfix must start with /")
	
	if not _llm_provider.chat_url_postfix.is_empty() and not _llm_provider.chat_url_postfix.begins_with("/"):
		push_error("chat_url_postfix must start with /")

	_models_url = _base_url.rstrip("/") + _llm_provider.models_url_postfix
	_chat_url = _base_url.rstrip("/") + _llm_provider.chat_url_postfix

	_api_key = config.load_key()
	_is_ready = true
	llm_config_changed.emit()



func get_full_response(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		push_error("Failed to parse JSON in get_full_response: %s" % json.get_error_message())
		return body.get_string_from_utf8()
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		return data
	else:
		push_error("Parsed JSON is not a Dictionary in get_full_response.")
		return body.get_string_from_utf8()


#--- All methods below should be overriden by child classes, see for example OllamaAPI ---

func send_get_models_request(http_request:HTTPRequest) -> bool:
	if not _is_ready:
		push_error("LLMInterface not initialized")
		return false
	if _busy:
		push_warning("LLM request already in progress")
		return false
	
	_busy = true
	return true


func read_models_response(body:PackedByteArray) -> Array[String]:
	return [INVALID_RESPONSE]


func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	if not _is_ready:
		push_error("LLMInterface not initialized")
		return false
	if _busy:
		push_warning("LLM request already in progress")
		return false
	
	_busy = true
	return true


func read_response(body:PackedByteArray) -> String:
	return INVALID_RESPONSE


## This is an optional method to override, only if you need to perform any logic
## after the URL and API key are loaded, e.g. generate custom headers
func _initialize() -> void:
	return


func _model_changed() -> void:
	return


func _override_temperature_changed() -> void:
	return


func _temperature_changed() -> void:
	return


func get_system_role() -> String:
	return _llm_provider.system_role_name if _llm_provider else "system"


func get_user_role() -> String:
	return _llm_provider.user_role_name if _llm_provider else "user"


func get_assistant_role() -> String:
	return _llm_provider.assistant_role_name if _llm_provider else "assistant"

