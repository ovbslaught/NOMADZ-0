@tool
class_name AIAssistantHub
extends Control

@onready var ai_chat: AIChat = %AIChat
@onready var settings_view: ScrollContainer = %SettingsView
@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var url_txt: LineEdit = %UrlTxt
@onready var api_key_txt: LineEdit = %APIKeyTxt
@onready var models_list: ItemList = %ModelsList
@onready var models_list_error: Label = %ModelsListError
@onready var llm_provider_option: OptionButton = %LLMProviderOption
@onready var back_to_chat_btn: Button = %BackToChatBtn
@onready var back_to_chat_btn2: Button = $ViewManager/HistoryView/CardHistory/VBox/HBox/BackToChatBtn
@onready var refresh_models_btn: Button = %RefreshModelsBtn
@onready var support_btn: Button = %SupportBtn
@onready var get_key_link: LinkButton = %GetKeyLink
@onready var key_warning: Label = %KeyWarning
@onready var history_view: ScrollContainer = %HistoryView

@onready var history_list: VBoxContainer = %HistoryList

const HISTORY_ITEM = preload("res://addons/GodAgent/conversation_history_item.tscn")

func _ready() -> void:
	models_http_request.request_completed.connect(_on_models_http_request_completed)
	randomize()
var _plugin: EditorPlugin

var _models_llm
var _current_api_id: String
var _models_cache: Dictionary = {} # api_id -> Array[String]
var _list_collapsed: bool = false
var _ignore_click: bool = false

var current_color: Color = Color.from_hsv(randf(), 0.9, 1.0)
var target_color: Color = Color.from_hsv(randf(), 0.9, 1.0)
var color_speed := 0.8


func _process(delta: float) -> void:
	if not is_instance_valid(ai_chat):
		return

	current_color = current_color.lerp(target_color, delta * color_speed)
	ai_chat.update_border_color(current_color)

	if (
		abs(current_color.r - target_color.r) < 0.02 and
		abs(current_color.g - target_color.g) < 0.02 and
		abs(current_color.b - target_color.b) < 0.02
	):
		target_color = Color.from_hsv(randf(), 0.9, 1.0)


func initialize(plugin: EditorPlugin) -> void:
	_plugin = plugin
	if not is_node_ready(): await ready

	_current_api_id = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "ollama_api")

	# Connect UI
	ai_chat.settings_requested.connect(_show_settings)
	ai_chat.history_requested.connect(_show_history)
	back_to_chat_btn.pressed.connect(_show_chat)
	back_to_chat_btn2.pressed.connect(_show_chat)
	refresh_models_btn.pressed.connect(_on_refresh_models_btn_pressed)
	support_btn.pressed.connect(_on_support_btn_pressed)
	llm_provider_option.item_selected.connect(_on_llm_provider_option_item_selected)
	url_txt.text_changed.connect(_on_settings_changed)
	api_key_txt.text_changed.connect(_on_settings_changed)
	ai_chat.chat_updated.connect(_refresh_history_list)
	models_list.item_selected.connect(_on_model_selected)
	models_list.item_clicked.connect(_on_models_list_item_clicked)
	ai_chat.new_chat.connect(new_chat)


	_initialize_llm_provider_options()
	_refresh_history_list()


	# Initialize last chat or new one
	_load_initial_chat()
	_show_chat()


func _show_settings():
	ai_chat.get_node("MainLayout").hide()
	settings_view.show()

func _show_chat():
	settings_view.hide()
	history_view.hide()
	ai_chat.get_node("MainLayout").show()

func _show_history():
	ai_chat.get_node("MainLayout").hide()
	settings_view.hide()
	history_view.show()

func _initialize_llm_provider_options() -> void:
	llm_provider_option.clear()
	var base_dir = self.scene_file_path.get_base_dir()
	var providers_path = base_dir + "/llm_providers"
	var dir = DirAccess.open(providers_path)
	if not dir: return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var i = 0
	while not file_name.is_empty():
		if file_name.ends_with(".tres"):
			var provider = load(providers_path + "/" + file_name)
			if provider is LLMProviderResource:
				llm_provider_option.add_item(provider.name)
				llm_provider_option.set_item_metadata(i, provider)
				if provider.api_id == _current_api_id:
					llm_provider_option.select(i)
					_on_llm_provider_option_item_selected(i)
				i += 1
		file_name = dir.get_next()


func _on_llm_provider_option_item_selected(index: int) -> void:
	var provider: LLMProviderResource = llm_provider_option.get_item_metadata(index)

	_current_api_id = provider.api_id
	_models_llm = _plugin.new_llm(provider)

	ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_API, _current_api_id)
	ProjectSettings.save()

	var config = LLMConfigManager.new(_current_api_id)
	var url = config.load_url()
	if url.is_empty() or not provider.fix_url.is_empty():
		url = provider.fix_url

	url_txt.text = url
	url_txt.editable = provider.fix_url.is_empty()

	api_key_txt.text = config.load_key()
	get_key_link.visible = !provider.get_key_url.is_empty()
	get_key_link.uri = provider.get_key_url

	_check_api_key_warning(provider)
	ai_chat.update_llm()

	# Clear visual state
	models_list_error.hide()


	# Use cache if available
	if _models_cache.has(_current_api_id):
		_on_models_received(_models_cache[_current_api_id])
	else:
		_on_refresh_models_btn_pressed()

func _check_api_key_warning(provider: LLMProviderResource) -> void:
	if provider.requires_key and api_key_txt.text.is_empty():
		key_warning.show()
	else:
		key_warning.hide()


func _on_settings_changed(_text):
	var provider: LLMProviderResource = llm_provider_option.get_selected_metadata()
	_check_api_key_warning(provider)

	var config = LLMConfigManager.new(_current_api_id)
	config.save_url(url_txt.text)
	config.save_key(api_key_txt.text)
	if _models_llm:
		_models_llm.load_llm_parameters()

func _on_refresh_models_btn_pressed() -> void:
	if _models_llm:
		models_http_request.cancel_request()
		_models_llm.clear_busy()

		# Check API key before requesting to avoid console spam
		var provider: LLMProviderResource = llm_provider_option.get_selected_metadata()
		if provider.requires_key and api_key_txt.text.is_empty():
			models_list_error.text = "Error: API Key is required for this provider."
			models_list_error.show()
			return

		models_list.clear()
		models_list.add_item("Loading models...")
		_models_llm.send_get_models_request(models_http_request)



func _on_models_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _models_llm:
		_models_llm.clear_busy()
	if result == HTTPRequest.RESULT_SUCCESS:
		var models = _models_llm.read_models_response(body)
		_models_cache[_current_api_id] = models
		_on_models_received(models)
	else:
		models_list_error.text = "Error loading models. Check URL/Key."
		models_list_error.show()

func _on_models_received(models: Array) -> void:
	_list_collapsed = false
	models_list.clear()
	for m in models:
		models_list.add_item(m)

	models_list.custom_minimum_size.y = 150
	models_list.auto_height = false

	# If we have a saved model, try to select/collapse it
	var saved_model = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_MODEL, "")
	if not saved_model.is_empty():
		for j in range(models_list.item_count):
			if models_list.get_item_text(j) == saved_model:
				# ai_chat.set_model(saved_model)  # Eliminado: AIChat no tiene este método
				_collapse_models_list(saved_model)
				break




func _on_model_selected(index: int) -> void:
	if _list_collapsed:
		return

	var model_name = models_list.get_item_text(index)

	ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_MODEL, model_name)
	ProjectSettings.save()

	# ai_chat.set_model(model_name)  # Eliminado: AIChat no tiene este método
	_collapse_models_list(model_name)
	_ignore_click = true # Prevent immediate expansion from same-frame click


func _on_models_list_item_clicked(_index: int, _at_position: Vector2, _mouse_button: int) -> void:
	if _ignore_click:
		_ignore_click = false
		return

	if _list_collapsed:
		_expand_models_list()


func _collapse_models_list(selected_model: String) -> void:
	_list_collapsed = true
	models_list.clear()
	models_list.add_item(selected_model)
	models_list.select(0)
	models_list.auto_height = true
	models_list.custom_minimum_size.y = 0
	# Small delay to ensure ItemList re-renders before container re-layouts
	get_tree().process_frame.connect(func(): if is_instance_valid(models_list) and models_list.is_inside_tree(): models_list.update_minimum_size(), CONNECT_ONE_SHOT)


func _expand_models_list() -> void:
	_list_collapsed = false
	var models = _models_cache.get(_current_api_id, [])
	var current_model = ""
	if models_list.item_count > 0:
		current_model = models_list.get_item_text(0)

	models_list.clear()
	models_list.auto_height = false
	models_list.custom_minimum_size.y = 150

	for m in models:
		models_list.add_item(m)
		if m == current_model:
			models_list.select(models_list.item_count - 1)

	if models_list.get_selected_items().size() > 0:
		models_list.ensure_current_is_visible()





func get_selected_llm_resource() -> Resource:
	var idx = llm_provider_option.selected
	if idx < 0: return null
	return llm_provider_option.get_item_metadata(idx)



func _on_support_btn_pressed() -> void:
	OS.shell_open("https://github.com/AnvoltrixGames/GodAgent")

# --- History Management ---

func _load_initial_chat() -> void:
	var last_chat = ProjectSettings.get_setting("plugins/ai_assistant_hub/last_chat_path", "")
	if not last_chat.is_empty() and FileAccess.file_exists(last_chat):
		ai_chat.initialize_from_file(_plugin, last_chat)
	else:
		new_chat()

func _refresh_history_list() -> void:
	for child in history_list.get_children():
		child.queue_free()

	var path = AIChat.SAVE_PATH
	if not DirAccess.dir_exists_absolute(path):
		return

	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".cfg"):
				var chat_path = path + file_name
				var config = ConfigFile.new()
				config.load(chat_path)
				var bot_name = config.get_value("setup", "bot_name", "Assistant")
				var chat_title = config.get_value("setup", "chat_title", "")

				var display_name = chat_title
				if display_name.is_empty():
					display_name = bot_name
					var parts = file_name.get_basename().split("_")
					if parts.size() > 0:
						display_name += " (" + parts[0].replace("T", " ") + ")"

				var item = HISTORY_ITEM.instantiate()
				history_list.add_child(item)
				item.setup(display_name, chat_path)
				item.selected.connect(_on_history_item_clicked)
				item.delete_requested.connect(_on_history_item_delete_requested)

			file_name = dir.get_next()

func new_chat() -> void:
	var default_resource := AIAssistantResource.new()
	default_resource.type_name = "Assistant"
	default_resource.agent_description = "You are an autonomous GDscript programming agent for Godot 4.5. Execute all possible steps to complete the orders given to you."
	default_resource.chat_description = "You are a helpful Godot coding assistant, your name is GodAgent."
	default_resource.ai_model = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_MODEL, "")

	ai_chat.initialize(_plugin, default_resource, "GodAgent")
	# Update last chat setting
	ProjectSettings.set_setting("plugins/ai_assistant_hub/last_chat_path", ai_chat.get_chat_save_path())
	ProjectSettings.save()

	_refresh_history_list()
	_show_chat()

func _on_history_item_clicked(item: Control) -> void:
	var chat_path = item.chat_path
	ai_chat.initialize_from_file(_plugin, chat_path)

	ProjectSettings.set_setting("plugins/ai_assistant_hub/last_chat_path", chat_path)
	ProjectSettings.save()

	_show_chat()

func _on_history_item_delete_requested(item: Control) -> void:
	var chat_path = item.chat_path
	DirAccess.remove_absolute(chat_path)

	var last_chat = ProjectSettings.get_setting("plugins/ai_assistant_hub/last_chat_path", "")
	if last_chat == chat_path:
		ProjectSettings.set_setting("plugins/ai_assistant_hub/last_chat_path", "")
		ProjectSettings.save()
		new_chat()
	else:
		_refresh_history_list()
