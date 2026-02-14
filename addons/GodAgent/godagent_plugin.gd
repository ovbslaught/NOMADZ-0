@tool
class_name AIHubPlugin
extends EditorPlugin

enum ThinkingTargets {OUTPUT, CHAT, DISCARD}
const PREF_REMOVE_THINK := "plugins/ai_assistant_hub/preferences/thinking_target"
const PREF_SCROLL_BOTTOM := "plugins/ai_assistant_hub/preferences/always_scroll_to_bottom"
const PREF_SKIP_GREETING := "plugins/ai_assistant_hub/preferences/skip_greeting"
const PREF_BORDER_COLOR := "plugins/ai_assistant_hub/preferences/border_color"


const CONFIG_LLM_API := "plugins/ai_assistant_hub/llm_api"
const CONFIG_LLM_MODEL := "plugins/ai_assistant_hub/llm_model"


# Configuration deprecated in version 1.6.0
const DEPRECATED_CONFIG_OPENROUTER_API_KEY := "plugins/ai_assistant_hub/openrouter_api_key"
const DEPRECATED_CONFIG_GEMINI_API_KEY := "plugins/ai_assistant_hub/gemini_api_key"
const DEPRECATED_CONFIG_OPENWEBUI_API_KEY := "plugins/ai_assistant_hub/openwebui_api_key"

var _hub_dock: AIAssistantHub

func _enter_tree() -> void:
	initialize_project_settings()

	if _hub_dock:
		return

	_hub_dock = load("res://addons/GodAgent/ai_assistant_hub.tscn").instantiate()
	_hub_dock.initialize(self)

	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, _hub_dock)


func initialize_project_settings() -> void:
	# Version 1.6.0 cleanup - Migrate base URL from global setting to per LLM setting
	var api_id: String = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "")
	if not api_id.is_empty():
		var config_base_url = LLMConfigManager.new(api_id)
		config_base_url.migrate_deprecated_1_5_0_base_url()

	# Version 1.6.0 cleanup - delete API key files and project settings
	var config_gemini = LLMConfigManager.new("gemini_api")
	config_gemini.migrate_deprecated_1_5_0_api_key(
		GeminiAPI.get_deprecated_api_key(),
		GeminiAPI.DEPRECATED_API_KEY_SETTING,
		GeminiAPI.DEPRECATED_API_KEY_FILE)

	var config_openrouter = LLMConfigManager.new("openrouter_api")
	config_openrouter.migrate_deprecated_1_5_0_api_key(
		OpenRouterAPI.get_deprecated_api_key(),
		OpenRouterAPI.DEPRECATED_API_KEY_SETTING,
		OpenRouterAPI.DEPRECATED_API_KEY_FILE)

	var config_openwebui = LLMConfigManager.new("openwebui_api")
	config_openwebui.migrate_deprecated_1_5_0_api_key(
		OpenWebUIAPI.get_deprecated_api_key(),
		OpenWebUIAPI.DEPRECATED_API_KEY_SETTING)

	if ProjectSettings.get_setting(CONFIG_LLM_API, "").is_empty():
		# In the future we can consider moving this back to simply:
		# ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
		# the code below handles migrating the config from 1.2.0 to 1.3.0
		var old_path := "ai_assistant_hub/llm_api"
		if ProjectSettings.has_setting(old_path):
			ProjectSettings.set_setting(CONFIG_LLM_API, ProjectSettings.get_setting(old_path))
			ProjectSettings.set_setting(old_path, null)
			ProjectSettings.save()
		else:
			ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")

	if not ProjectSettings.has_setting(PREF_REMOVE_THINK):
		ProjectSettings.set_setting(PREF_REMOVE_THINK, ThinkingTargets.OUTPUT)
		ProjectSettings.save()

	if not ProjectSettings.has_setting(PREF_SKIP_GREETING):
		ProjectSettings.set_setting(PREF_SKIP_GREETING, false)
		ProjectSettings.save()

	var property_info = {
		"name": PREF_REMOVE_THINK,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "OUTPUT,CHAT,DISCARD"
	}
	ProjectSettings.add_property_info(property_info)

	if not ProjectSettings.has_setting(PREF_SCROLL_BOTTOM):
		ProjectSettings.set_setting(PREF_SCROLL_BOTTOM, false)
		ProjectSettings.save()

	if not ProjectSettings.has_setting(PREF_BORDER_COLOR):
		ProjectSettings.set_setting(PREF_BORDER_COLOR, Color(0, 1, 1, 1)) # Default cyan
		ProjectSettings.save()


func _exit_tree() -> void:
	if is_instance_valid(_hub_dock):
		remove_control_from_docks(_hub_dock)
		_hub_dock.queue_free()
		_hub_dock = null



## Helper function: Add project setting
func _add_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if ProjectSettings.has_setting(name):
		return

	var property_info := {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}

	ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(name, default_value)


## Load the API dinamically based on the script name given in project setting: ai_assistant_hub/llm_api
## By default this is equivalent to: return OllamaAPI.new()
func new_llm(llm_provider: Resource) -> Object:
	if llm_provider == null:
		push_error("No LLM provider has been selected.")
		return null
	if llm_provider.api_id.is_empty():
		push_error("Provider %s has no API ID." % llm_provider.api_id)
		return null
	var script_path = "res://addons/GodAgent/llm_apis/%s.gd" % llm_provider.api_id
	var script = load(script_path)
	if script == null:
		push_error("Failed to load LLM provider script: %s" % script_path)
		return null
	var instance = script.new()
	if instance == null:
		push_error("Failed to instantiate the LLM provider from script: %s" % script_path)
		return null
	if instance.has_method("setup"):
		instance.setup(llm_provider)
	return instance


func get_current_llm_provider() -> Resource:
	return _hub_dock.get_selected_llm_resource()
