@tool
class_name AIChat
extends Control

signal models_loaded
signal save_changed(chat: AIChat, save_on: bool)
signal settings_requested
signal chat_updated
signal history_requested
signal new_chat


enum Caller {
	NONE,
	YOU,
	BOT,
	SYSTEM
}

const CHAT_HISTORY_EDITOR = preload("res://addons/GodAgent/chat_history_editor.tscn")
const SAVE_PATH := "user://ai_assistant_hub/saved_chats/"

@onready var http_request: HTTPRequest = %HTTPRequest
@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var output_window: RichTextLabel = %OutputWindow
@onready var prompt_txt: TextEdit = %PromptTxt
@onready var send_button: Button = %SendButton

@onready var max_steps_spin_box: SpinBox = %MaxStepsSpinBox
@onready var mode_option_button: OptionButton = %ModeOptionButton
@onready var auto_plan_check_button: CheckBox = %AutoPlanCheckButton
# Nuevo: referencia al SettingsHBox y Label para tokens
@onready var settings_hbox: Container = %SettingsHBox
@onready var tokens_label: Label = null
@onready var chat_name: Label = $MainLayout/ChatHeader/HBox/VBoxContainer/ChatName

@onready var message_list: VBoxContainer = %MessageList
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var title_label: Label = $MainLayout/ChatHeader/HBox/VBoxContainer/Title

const CHAT_MESSAGE = preload("res://addons/GodAgent/chat_message.tscn")
const TOOL_MANAGER = preload("res://addons/GodAgent/tools/ai_tool_manager.gd")
const TITLE_SYSTEM_PROMPT := """
You are a title generator.

Create a concise, human-readable title (1–4 words) that summarizes the conversation. This is for the title of a chat

Rules:
- Output ONLY the title text
- No quotes
- No punctuation
- No emojis
- No extra commentary
"""


var _plugin: EditorPlugin
var _bot_name: String
var _assistant_settings: AIAssistantResource
var _bot_answer_handler: AIAnswerHandler
var _llm
var _conversation: AIConversation
var _chat_save_path: String
var _tool_manager = TOOL_MANAGER.new()
var _autonomous_loop_count := 0
var _last_caller: Caller = Caller.NONE
var _bot_block_open := false
var _is_thinking := false: set = _set_is_thinking
var _last_msg_bubble: PanelContainer = null
var _chat_title: String = ""
@onready var title_http_request: HTTPRequest = HTTPRequest.new()

@export var icon_available: Texture2D
@export var icon_thinking: Texture2D
@export var icon_user: Texture2D
@export var icon_bot: Texture2D
@export var icon_system: Texture2D

var _stop_icon: Texture2D # Deprecated, kept for safe transition logic/vars if needed, but logic below replaces it.
var _green_circle_icon: Texture2D # Deprecated


func get_chat_save_path() -> String:
	return _chat_save_path


func set_chat_save_path(path: String) -> void:
	_chat_save_path = path


func _set_is_thinking(value: bool):
	_is_thinking = value
	if send_button:
		if value:
			send_button.icon = icon_thinking
			send_button.disabled = false
			send_button.tooltip_text = "Stop generation"
		else:
			send_button.icon = icon_available
			send_button.disabled = true
			send_button.tooltip_text = "Send request"

	if prompt_txt:
		prompt_txt.editable = !value
		if !value:
			prompt_txt.grab_focus()


func initialize(plugin: EditorPlugin, assistant_settings: AIAssistantResource, bot_name: String, save_path: String = "") -> void:
	_chat_save_path = save_path
	_plugin = plugin
	_assistant_settings = assistant_settings
	_bot_name = bot_name
	# Añadir label para tokens usados en el SettingsHBox si no existe
	if settings_hbox:
		tokens_label = settings_hbox.get_node_or_null("TokensLabel")
		if not tokens_label:
			tokens_label = Label.new()
			tokens_label.name = "TokensLabel"
			tokens_label.text = "Tokens usados: 0"
			settings_hbox.add_child(tokens_label)

	if not title_http_request.is_inside_tree():
		add_child(title_http_request)
		title_http_request.request_completed.connect(_on_title_request_completed)

	if not is_node_ready():
		await ready

	# Icons are now set via exports or loaded from default files if missing
	if icon_available == null:
		icon_available = load("res://addons/GodAgent/graphics/icons/status_available.svg")
	if icon_thinking == null:
		icon_thinking = load("res://addons/GodAgent/graphics/icons/status_thinking.svg")

	# _create_status_icons() # Removed procedural generation
	_set_is_thinking(false)

	# Reset visual state
	if message_list:
		for child in message_list.get_children():
			child.queue_free()
	_last_msg_bubble = null
	_last_caller = Caller.NONE
	if save_path.is_empty():
		_chat_title = ""

	# Code selector initialization removed
	_tool_manager.initialize(plugin)

	if _bot_answer_handler:
		_bot_answer_handler.bot_message_produced.disconnect(_on_bot_message_produced)
		_bot_answer_handler.error_message_produced.disconnect(_on_error_message_produced)

	_bot_answer_handler = AIAnswerHandler.new(plugin)
	_bot_answer_handler.bot_message_produced.connect(_on_bot_message_produced)
	_bot_answer_handler.error_message_produced.connect(_on_error_message_produced)
	_set_tab_label()

	if _chat_save_path.is_empty() and assistant_settings:
		var save_id = ("%s_%s_%s" % [Time.get_datetime_string_from_system(), assistant_settings.type_name, bot_name]).validate_filename()
		_chat_save_path = SAVE_PATH + save_id + ".cfg"
		if not DirAccess.dir_exists_absolute(SAVE_PATH):
			DirAccess.make_dir_absolute(SAVE_PATH)

	var llm_provider := _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.SYSTEM)
		return
	_create_conversation(llm_provider)

	if _assistant_settings: # We need to check this, otherwise this is called when editing the plugin
		_load_api(llm_provider)
		# Temperature UI removed
		max_steps_spin_box.value = _assistant_settings.max_autonomous_steps
		mode_option_button.selected = _assistant_settings.mode
		auto_plan_check_button.button_pressed = _assistant_settings.auto_execute_plan

		var is_agent_mode = (_assistant_settings.mode == AIAssistantResource.Mode.AGENT)
		max_steps_spin_box.visible = is_agent_mode
		auto_plan_check_button.visible = is_agent_mode


		_update_system_message()

		# Quick prompts removed

		if not Engine.is_editor_hint():
			models_http_request.cancel_request()
			_llm.send_get_models_request(models_http_request)
		prompt_txt.text = ""
		prompt_txt.editable = true

	update_llm()


func update_llm() -> void:
	var llm_provider := _find_llm_provider()
	if llm_provider:
		_load_api(llm_provider)
		# Update model from settings
		if _llm and _assistant_settings:
			_llm.model = _assistant_settings.ai_model


func get_assistant_settings() -> AIAssistantResource:
	return _assistant_settings



func initialize_from_file(plugin: EditorPlugin, file: String) -> void:
	_plugin = plugin
	_chat_save_path = file
	if not is_node_ready():
		await ready


	var config = ConfigFile.new()
	config.load(_chat_save_path)
	var res_path = config.get_value("setup", "assistant_res", "")
	if not res_path.is_empty() and FileAccess.file_exists(res_path):
		_assistant_settings = load(res_path)

	_chat_title = config.get_value("setup", "chat_title", "")

	if _assistant_settings == null:
		# Fallback to a default resource if the file doesn't exist or wasn't provided
		_assistant_settings = AIAssistantResource.new()
		_assistant_settings.type_name = config.get_value("setup", "type_name", "Assistant")
		_assistant_settings.agent_description = config.get_value("setup", "agent_description", config.get_value("setup", "ai_description", "Assistant"))
		_assistant_settings.chat_description = config.get_value("setup", "chat_description", config.get_value("setup", "ai_description", "Assistant"))
		_assistant_settings.plain_description = config.get_value("setup", "plain_description", "")
		_assistant_settings.ai_model = config.get_value("setup", "ai_model", "")
		_assistant_settings.mode = config.get_value("setup", "mode", AIAssistantResource.Mode.AGENT)

		_assistant_settings.agent_temperature = config.get_value("setup", "agent_temperature", 0.1)
		_assistant_settings.chat_temperature = config.get_value("setup", "chat_temperature", 0.7)
		_assistant_settings.plain_temperature = config.get_value("setup", "plain_temperature", 0.5)
	var bot_name: String = config.get_value("setup", "bot_name")
	var system_message: String = config.get_value("setup", "system_message")
	var chat_history: Array = config.get_value("chat", "entries", [])
	var llm_provider := _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.SYSTEM)
		return

	await initialize(plugin, _assistant_settings, bot_name, file)

	# Set the system message from saved config (not from chat history)
	if not system_message.is_empty():
		_conversation.set_system_message(system_message)

	# Load the chat history into the conversation and UI
	_conversation.overwrite_chat(chat_history)


func _create_save_file() -> void:
	var config = ConfigFile.new()
	config.load(_chat_save_path)
	if not _assistant_settings:
		return
	config.set_value("setup", "assistant_res", _assistant_settings.resource_path)
	config.set_value("setup", "type_name", _assistant_settings.type_name)
	config.set_value("setup", "ai_model", _assistant_settings.ai_model)
	config.set_value("setup", "mode", _assistant_settings.mode)
	config.set_value("setup", "agent_description", _assistant_settings.agent_description)
	config.set_value("setup", "chat_description", _assistant_settings.chat_description)
	config.set_value("setup", "plain_description", _assistant_settings.plain_description)
	config.set_value("setup", "agent_temperature", _assistant_settings.agent_temperature)
	config.set_value("setup", "chat_temperature", _assistant_settings.chat_temperature)
	config.set_value("setup", "plain_temperature", _assistant_settings.plain_temperature)
	config.set_value("setup", "bot_name", _bot_name)
	config.set_value("setup", "chat_title", _chat_title)
	config.set_value("setup", "system_message", _conversation.get_system_message())
	config.set_value("chat", "entries", _conversation.clone_chat())
	config.save(_chat_save_path)


func _create_conversation(llm_provider: Resource) -> void:
	_conversation = AIConversation.new(
		llm_provider.system_role_name,
		llm_provider.user_role_name,
		llm_provider.assistant_role_name
	)
	_conversation.chat_edited.connect(_on_conversation_chat_edited)
	_conversation.chat_appended.connect(_on_conversation_chat_appended)


func _find_llm_provider() -> Resource:
	if not _assistant_settings:
		return _plugin.get_current_llm_provider() if _plugin else null

	var llm_provider := _assistant_settings.llm_provider
	if llm_provider == null:
		#_add_to_chat("Warning: Assistant %s does not have LLM provider. Using the current LLM API selected in the main tab." % _assistant_settings.type_name, Caller.SYSTEM)
		llm_provider = _plugin.get_current_llm_provider()
	return llm_provider



func _set_tab_label() -> void:
	if not _chat_title.is_empty():
		chat_name.visible = true
		chat_name.text = _chat_title
	else:
		chat_name.visible = false



func _load_conversation_to_chat(chat_history: Array) -> void:
	for child in message_list.get_children():
		child.queue_free()

	_bot_block_open = false
	_last_caller = Caller.NONE
	_last_msg_bubble = null

	var llm_provider: LLMProviderResource = _find_llm_provider()
	if not llm_provider:
		return


	for entry in chat_history:
		if entry.has("role") and entry.has("content"):
			var role: String = str(entry.role).to_lower()
			if role == llm_provider.user_role_name.to_lower() or role == "user":
				if entry.content.begins_with(AIToolManager.TOOL_OUTPUT_OPEN):
					_add_to_chat(entry.content, Caller.SYSTEM)
				else:
					_add_to_chat(entry.content, Caller.YOU)
			elif role == llm_provider.assistant_role_name.to_lower() or role == "assistant" or role == "model" or role == "bot":
				_add_to_chat(entry.content, Caller.BOT)
			elif role == llm_provider.system_role_name.to_lower() or role == "system" or role == "system_instruction":
				_add_to_chat(entry.content, Caller.SYSTEM)
			else:
				# Fallback for unrecognized roles: try to guess based on common patterns or just show as system
				print("[GodAgent] WARNING: Unrecognized role '%s', displaying as SYSTEM" % role)
				_add_to_chat(entry.content, Caller.SYSTEM)
		else:
			print("[GodAgent] WARNING: Entry missing 'role' or 'content': %s" % str(entry))

	await get_tree().process_frame
	if not is_inside_tree() or not scroll_container: return
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value




func _load_api(llm_provider: Resource) -> void:
	_llm = _plugin.new_llm(llm_provider)
	if _llm and _assistant_settings:
		_llm.model = _assistant_settings.ai_model
		_llm.override_temperature = _assistant_settings.use_custom_temperature
		_llm.temperature = _get_current_temperature()
	else:
		push_error("LLM provider failed to initialize. Check the LLM API configuration for it.")




func _input(event: InputEvent) -> void:
	if prompt_txt.has_focus() and event.is_pressed() and event is InputEventKey:
		var e: InputEventKey = event
		var is_enter_key := e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER
		var shift_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
		if shift_pressed and is_enter_key:
			prompt_txt.insert_text_at_caret("\n")
		else:
			var ctrl_pressed = Input.is_physical_key_pressed(KEY_CTRL)
			if not ctrl_pressed:
				if not prompt_txt.text.is_empty() and is_enter_key:
					if _is_thinking:
						_abandon_request()
					get_viewport().set_input_as_handled()
					var prompt = _engineer_prompt(prompt_txt.text)
					prompt_txt.text = ""
					_add_to_chat(prompt, Caller.YOU)
					_submit_prompt(prompt, _get_editor_context())

func _find_code_editor() -> TextEdit:
	var script_editor := _plugin.get_editor_interface().get_script_editor().get_current_editor()
	return script_editor.get_base_editor()


func _get_editor_context() -> String:
	var root = EditorInterface.get_edited_scene_root()
	var context = ""
	if root:
		var mode = "3D" if root is Node3D else "2D"
		context = "\n\n[Editor context]:"
		context += "\n- Current scene: " + root.scene_file_path
		context += "\n- Scene type: " + mode
		context += "\n- Root node: " + root.name
	return context


func _engineer_prompt(original: String) -> String:
	if original.contains("{CODE}"):
		var curr_code: String = _find_code_editor().get_selected_text()
		var prompt: String = original.replace("{CODE}", curr_code)
		return prompt
	else:
		return original


func _submit_prompt(prompt: String, ephemeral_context: String = "") -> void:
	if _is_thinking:
		_abandon_request()
	_is_thinking = true
	_autonomous_loop_count = 0
	_conversation.add_user_prompt(prompt)
	if not _llm:
		push_error("No language model provider loaded. Check configuration!")
		_add_to_chat("No language model provider loaded. Check configuration!", Caller.SYSTEM)
		_is_thinking = false
		return

	var messages = _conversation.build()
	if not ephemeral_context.is_empty():
		# We modify the last message (the one we just added) to include context for the LLM
		# but only for this request (not saved in _conversation history)
		var last_msg = messages[-1].duplicate()
		last_msg["content"] += ephemeral_context
		messages[-1] = last_msg

	var success = _llm.send_chat_request(http_request, messages)
	if not success:
		var error_msg = "Something went wrong. Review the details in Godot's Output tab."
		_add_to_chat(error_msg, Caller.SYSTEM)
		# Removed: _conversation.add_user_prompt(error_msg) -> Don't save UI errors in history


func _abandon_request() -> void:
	http_request.cancel_request()
	if _llm:
		_llm.clear_busy()
	_is_thinking = false
	_autonomous_loop_count = 0
	var msg = "Abandoned previous request."
	_add_to_chat(msg, Caller.SYSTEM)
	_conversation.forget_last_prompt()

func _abandon_button_pressed() -> void:
	_abandon_request()

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _llm:
		_llm.clear_busy()
	if result == HTTPRequest.RESULT_SUCCESS:
		var text_answer = _llm.read_response(body)
		# Actualizar el label de tokens usados si existe
		if tokens_label and _llm:
			var tokens_used = 0
			if _llm.has_method("get_tokens_used"):
				tokens_used = _llm.get_tokens_used()
			tokens_label.text = "Tokens usados: %d" % tokens_used

		# Clean the response (remove <think> tags, etc.)
		text_answer = ResponseCleaner.clean(text_answer)

		if text_answer == LLMInterface.INVALID_RESPONSE:

			_is_thinking = false
			push_error("Response: %s" % _llm.get_full_response(body))
			var error_msg = "An error occurred while processing your last request. Review the details in Godot's Output tab."
			_add_to_chat(error_msg, Caller.SYSTEM)
		else:
			_conversation.add_assistant_response(text_answer)
			_bot_answer_handler.handle(text_answer)

			var plan = _tool_manager.extract_plan(text_answer)
			if not plan.is_empty() and _assistant_settings.mode == AIAssistantResource.Mode.AGENT:
				if _assistant_settings.auto_execute_plan:
					_execute_full_plan(plan)
					return
				else:
					_is_thinking = false
					var bubble = _add_to_chat("", Caller.BOT)
					bubble.setup_plan(plan)
					bubble.step_clicked.connect(_on_plan_step_clicked)
					return

			var has_tool_code := _tool_manager.contains_tool_call(text_answer)
			if has_tool_code and _assistant_settings.mode == AIAssistantResource.Mode.AGENT:
				if _autonomous_loop_count < _assistant_settings.max_autonomous_steps:
					_autonomous_loop_count += 1
					# Keep thinking state
					_is_thinking = true

					var tool_calls = _tool_manager.extract_tool_calls(text_answer)
					var combined_output = ""

					for call_data in tool_calls:
						var tool_name = call_data.get("name", "")
						var tool_args = call_data.get("args", {})
						var output = _tool_manager.execute_tool(tool_name, tool_args)

						combined_output += "Tool '%s' Output:\n%s\n\n" % [tool_name, output]

					var feedback_msg = "%s\n%s\n%s" % [AIToolManager.TOOL_OUTPUT_OPEN, combined_output.strip_edges(), AIToolManager.TOOL_OUTPUT_CLOSE]

					_add_to_chat(feedback_msg, Caller.SYSTEM)
					_conversation.add_user_prompt(feedback_msg)

					if not _is_thinking:
						return

					var success = _llm.send_chat_request(http_request, _conversation.build())
					if not success:
						_is_thinking = false
						var error_msg = "Something went wrong triggering the autonomous step."
						_add_to_chat(error_msg, Caller.SYSTEM)
				else:
					_is_thinking = false
					var msg = "The agent performed the maximum number of steps defined. Please confirm if you want to continue."
					_add_to_chat(msg, Caller.SYSTEM)
					_autonomous_loop_count = 0
			else:
				# No tool call, finished
				_is_thinking = false
				_autonomous_loop_count = 0

				if _chat_title.is_empty():
					_generate_chat_title()
	else:
		_is_thinking = false
		var error_msg = _get_http_result_string(result)
		push_error("HTTP Request Error: %s (Result Code: %d). Response Code: %d." % [error_msg, result, response_code])
		var msg = "Connection error: %s. Check Godot Output for details." % error_msg
		_add_to_chat(msg, Caller.SYSTEM)


func escape_bbcode(bbcode_text):
	return bbcode_text.replace("[", "[lb]")

func _format_markdown(text: String) -> String:
	# Escape brackets first to avoid conflict with BBCode tags we are about to add
	var res = escape_bbcode(text)

	var regex = RegEx.new()

	# Bold: **text** -> [b]text[/b]
	regex.compile("\\*\\*(?P<content>.*?)\\*\\*")
	res = regex.sub(res, "[b]$1[/b]", true)

	# Bullet points: * text -> • text (at start of line)
	regex.compile("(\\n|^)\\s*\\*\\s+(?P<content>.*)")
	res = regex.sub(res, "$1 • $2", true)

	return res


# Configure auto-scroll based on message sender
func _configure_auto_scroll(caller: Caller) -> bool:
	var auto_scroll := ProjectSettings.get_setting(AIHubPlugin.PREF_SCROLL_BOTTOM, false)

	if caller == Caller.YOU or caller == Caller.SYSTEM:
		output_window.scroll_following = true
	else:
		output_window.scroll_following = auto_scroll

	return auto_scroll


# --- RENDERERS ---
func _render_user_message(text: String) -> void:
	text = text.strip_edges(true, true)
	_reset_visual_context()
	output_window.append_text(text)



func _render_bot_message(text: String) -> void:
	_render_bot_header_if_needed()

	if text.count("```") >= 2 and text.count("```") % 2 == 0:
		_render_bot_with_code(text)
	else:
		_render_bot_plain(text)


func _render_system_message(text: String) -> void:
	if text.contains(AIToolManager.TOOL_OUTPUT_OPEN):
		var content = text.replace(AIToolManager.TOOL_OUTPUT_OPEN, "").replace(AIToolManager.TOOL_OUTPUT_CLOSE, "").strip_edges()
		if content.is_empty(): return

		output_window.push_font_size(11)
		output_window.push_color(Color(0.5, 0.8, 1.0)) # Cyan/Blue-ish for tool feedback
		output_window.push_mono()
		output_window.append_text(escape_bbcode(content))
		output_window.pop_all()
		output_window.newline()
	else:
		output_window.push_font_size(11)
		output_window.push_color(Color(0.7, 0.5, 0.2))
		output_window.append_text(text)
		output_window.pop_all()
		output_window.newline()



func _render_bot_header_if_needed() -> void:
	_bot_block_open = true



func _render_heading(line: String) -> bool:
	if line.begins_with("### "):
		output_window.push_color(Color(0xAAAAAAFF))
		output_window.push_bold()
		output_window.append_text(line.substr(4))
		output_window.pop()
		output_window.pop()
		output_window.newline()
		return true

	if line.begins_with("## "):
		output_window.push_color(Color(0xFFFFFFFF))
		output_window.push_bold()
		output_window.append_text(line.substr(3))
		output_window.pop()
		output_window.pop()
		output_window.newline()
		return true

	if line.begins_with("# "):
		output_window.push_color(Color(0xFFFFFFFF))
		output_window.push_bold()
		output_window.append_text(line.substr(2))
		output_window.pop()
		output_window.pop()
		output_window.newline()
		return true

	return false


func _render_bot_plain(text: String) -> void:
	var regex = RegEx.new()
	# Remove tool output / tool code / tool_call blocks from displayed text
	regex.compile("(?s)<tool_output>.*?</tool_output>")
	text = regex.sub(text, "", true)
	regex.compile("(?s)<tool_code>.*?</tool_code>")
	text = regex.sub(text, "", true)
	regex.compile("(?s)<tool_call>.*?</tool_call>")
	text = regex.sub(text, "", true)

	var parsed := _parse_tool_block(text)
	var prefix := String(parsed.prefix).strip_edges()
	var suffix := String(parsed.suffix).strip_edges()

	_reset_visual_context()

	if prefix != "":
		for line in prefix.split("\n"):
			if _render_heading(line):
				continue
			output_window.append_text(_format_markdown(line))
			output_window.newline()

	if parsed.has_tool:
		output_window.push_color(Color(0x4DA6FFFF))
		output_window.push_italics()
		output_window.append_text("[ " + parsed.status + " ]")
		output_window.pop()
		output_window.pop()
		output_window.newline()

	if suffix != "":
		if parsed.has_tool:
			_render_bot_plain(suffix)
		else:
			for line in suffix.split("\n"):
				if _render_heading(line):
					continue
				output_window.append_text(_format_markdown(line))
				output_window.newline()



func _render_bot_with_code(text: String) -> void:
	var parts := text.split("```")
	var writing_code := false

	for part in parts:
		if writing_code:
			_render_code_block(part)
		else:
			_render_bot_plain(part)
		writing_code = !writing_code


func _render_code_block(content: String) -> void:
	content = content.strip_edges(true, true)
	var lines := content.split("\n", false)
	var code := ""

	if lines.size() > 1:
		code = "\n".join(lines.slice(1, lines.size()))
	else:
		code = content

	_reset_visual_context()
	output_window.push_color(Color(0x4CE0B3FF))
	output_window.push_mono()
	output_window.append_text(escape_bbcode(code))
	output_window.pop()
	output_window.pop()
	output_window.newline()



# --- END RENDERERS ---


func _parse_tool_block(text: String) -> Dictionary:
	var result := {
		"has_tool": false,
		"prefix": text,
		"status": "",
		"suffix": ""
	}

	# Use constants from Tool Manager for consistency
	var tag_open = AIToolManager.TOOL_TAG_OPEN
	var tag_close = AIToolManager.TOOL_TAG_CLOSE

	if not text.contains(tag_open):
		return result

	var start := text.find(tag_open)
	var end := text.find(tag_close)

	# If start exists but end is missing, we assume truncation or formatting error.
	# We will try to parse from tag_open to the end of string.
	if end == -1:
		end = text.length()
	elif end <= start:
		return result

	var tool_json_str := text.substr(start + tag_open.length(), end - start - tag_open.length())
	var prefix := text.substr(0, start)
	var suffix := ""

	# Only set suffix if we actually found the closing tag
	if text.contains(tag_close):
		suffix = text.substr(end + tag_close.length())

	var status_msg := ""

	var json := JSON.new()
	if json.parse(tool_json_str) == OK:
		var data := json.get_data()
		if data is Dictionary and "name" in data:
			var args: Dictionary = data.get("args", {})
			match data.name:
				"list_dir": status_msg = "Listing files in %s..." % args.get("path", "res://")
				"read_file": status_msg = "Reading file %s..." % args.get("path", "???")
				"write_file": status_msg = "Writing file %s..." % args.get("path", "???")
				"move_file": status_msg = "Moving %s -> %s..." % [args.get("source", "?"), args.get("destination", "?")]
				"move_dir": status_msg = "Moving dir %s -> %s..." % [args.get("source", "?"), args.get("destination", "?")]
				"make_dir": status_msg = "Creating dir %s..." % args.get("path", "???")
				"remove_file", "remove_files": status_msg = "Deleting file %s..." % args.get("path", "???")
				"remove_dir": status_msg = "Deleting dir %s..." % args.get("path", "???")
				"get_errors": status_msg = "Checking for errors..."
				_: status_msg = "Using tool: %s..." % data.name
	else:
		# Fallback if JSON parsing fails (e.g. truncation)
		status_msg = "Error parsing tool output"

	result.has_tool = true
	result.prefix = prefix
	result.status = status_msg
	result.suffix = suffix

	return result


func _reset_visual_context() -> void:
	if _last_msg_bubble:
		_last_msg_bubble.content_label.pop_all()


func _add_to_chat(text: String, caller: Caller) -> PanelContainer:
	if _last_caller != caller or _last_msg_bubble == null:
		_last_msg_bubble = CHAT_MESSAGE.instantiate()
		message_list.add_child(_last_msg_bubble)

		var sender_name := "You"
		var icon: Texture2D = null
		var is_user := false

		match caller:
			Caller.YOU:
				sender_name = "You"
				icon = icon_user
				is_user = true
			Caller.BOT:
				sender_name = _bot_name
				icon = icon_bot
				is_user = false
			Caller.SYSTEM:
				sender_name = "System"
				icon = icon_system
				is_user = false

		_last_msg_bubble.setup(sender_name, icon, "", is_user, Color(1,1,1,1))
	else:
		if not _last_msg_bubble.content_label.text.is_empty():
			_last_msg_bubble.content_label.append_text("\n")

	# Redirect output_window to the bubble's label temporarily for renderers
	var old_output = output_window
	output_window = _last_msg_bubble.content_label

	match caller:
		Caller.YOU:
			_render_user_message(text)
		Caller.BOT:
			_render_bot_message(text)
		Caller.SYSTEM:
			_render_system_message(text)

	output_window = old_output
	_last_caller = caller

	_scroll_to_bottom()
	return _last_msg_bubble

func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or not scroll_container: return
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value




func _on_clear_btn_pressed() -> void:
	for child in message_list.get_children():
		child.queue_free()
	_last_msg_bubble = null
	_last_caller = Caller.NONE
	_conversation.clear_history()

func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_prompt_txt_text_changed() -> void:
	# Add any specific logic for text change if needed,
	# e.g. limiting characters or specific highlights
	pass




func _on_models_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if _llm:
		_llm.clear_busy()
	if result == HTTPRequest.RESULT_SUCCESS:
		var models_returned: Array = _llm.read_models_response(body)
		if models_returned.size() == 0:
			push_error("No models found. Download at least one model and try again.")
		else:
			if models_returned[0] == LLMInterface.INVALID_RESPONSE:
				push_error("Error while trying to get the models list. Response: %s" % _llm.get_full_response(body))
			else:
				_load_models(models_returned)
	else:
		var error_msg = _get_http_result_string(result)
		push_error("HTTP Request Error: %s (Result Code: %d). Response Code: %d." % [error_msg, result, response_code])


func _get_http_result_string(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS: return "Success"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: return "Chunked Body Size Mismatch"
		HTTPRequest.RESULT_CANT_CONNECT: return "Can't Connect"
		HTTPRequest.RESULT_CANT_RESOLVE: return "Can't Resolve DNS"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "Connection Error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLS Handshake Error"
		HTTPRequest.RESULT_NO_RESPONSE: return "No Response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "Body Size Limit Exceeded"
		HTTPRequest.RESULT_REQUEST_FAILED: return "Request Failed"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "Download File Can't Open"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "Download File Write Error"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "Redirect Limit Reached"
		HTTPRequest.RESULT_TIMEOUT: return "Timeout"
		_: return "Unknown Error (%d)" % result


func _load_models(models: Array[String]) -> void:
	models_loaded.emit()


func _on_edit_history_pressed() -> void:
	var history_editor: ChatHistoryEditor = CHAT_HISTORY_EDITOR.instantiate()
	history_editor.initialize(_conversation)
	add_child(history_editor)
	history_editor.popup()



func _on_max_steps_spin_box_value_changed(value: float) -> void:
	if _assistant_settings:
		_assistant_settings.max_autonomous_steps = int(value)


# Scroll the output window by one page
func _scroll_output_by_page() -> void:
	if output_window == null:
		return
	# Get the vertical scrollbar of the output window
	var v_scroll_bar := output_window.get_v_scroll_bar()
	if v_scroll_bar == null:
		return
	# Get the visible height of the output window (one page height)
	var visible_height = output_window.size.y
	# Calculate new position by adding one page height, but don't exceed maximum value
	var new_value = min(v_scroll_bar.value + visible_height, v_scroll_bar.max_value)
	# Set the new scroll position
	v_scroll_bar.value = new_value


func _on_save_check_button_toggled(toggled_on: bool) -> void:
	save_changed.emit(self, toggled_on)
	if toggled_on:
		_create_save_file()
	else:
		DirAccess.remove_absolute(_chat_save_path)


func _on_conversation_chat_edited(chat_history: Array) -> void:
	_load_conversation_to_chat(chat_history)
	_create_save_file()
	chat_updated.emit()

func _on_conversation_chat_appended(_entry: Dictionary) -> void:
	_create_save_file()
	chat_updated.emit()

func _ready() -> void:
	pass

func set_model(model_name: String) -> void:
	if _assistant_settings:
		_assistant_settings.ai_model = model_name
	if _llm:
		_llm.model = model_name

func _on_mode_option_button_item_selected(index: int) -> void:
	if _assistant_settings:
		_assistant_settings.mode = index as AIAssistantResource.Mode
		_update_system_message()

		# Show/hide max steps and auto plan based on mode
		var is_agent_mode = (_assistant_settings.mode == AIAssistantResource.Mode.AGENT)
		max_steps_spin_box.visible = is_agent_mode
		auto_plan_check_button.visible = is_agent_mode

func _on_auto_plan_check_button_toggled(toggled_on: bool) -> void:
	if _assistant_settings:
		_assistant_settings.auto_execute_plan = toggled_on

func _update_system_message() -> void:
	if not _assistant_settings or not _conversation:
		return

	var sys_msg = ""
	match _assistant_settings.mode:
		AIAssistantResource.Mode.AGENT:
			sys_msg = "%s" % [_assistant_settings.agent_description]
			sys_msg += "\n" + _tool_manager.get_system_instructions()
		AIAssistantResource.Mode.CHAT:
			sys_msg = "%s" % [_assistant_settings.chat_description]
		AIAssistantResource.Mode.PLAIN:
			sys_msg = _assistant_settings.plain_description

	_conversation.set_system_message(sys_msg)

	if _llm:
		_llm.temperature = _get_current_temperature()

func _get_current_temperature() -> float:
	if not _assistant_settings:
		return 0.5
	match _assistant_settings.mode:
		AIAssistantResource.Mode.AGENT: return _assistant_settings.agent_temperature
		AIAssistantResource.Mode.CHAT: return _assistant_settings.chat_temperature
		AIAssistantResource.Mode.PLAIN: return _assistant_settings.plain_temperature
	return 0.5

func _on_plan_step_clicked(step_data: Dictionary) -> void:
	if _is_thinking: return

	var tool_name = step_data.get("tool", "")
	var tool_args = step_data.get("args", {})

	if tool_name == "":
		var error_msg = "Error: No tool name in step."
		_add_to_chat(error_msg, Caller.SYSTEM)
		return

	_is_thinking = true
	var output = _tool_manager.execute_tool(tool_name, tool_args)

	var feedback_msg = "%s\nTool '%s' Output:\n%s\n%s" % [AIToolManager.TOOL_OUTPUT_OPEN, tool_name, output.strip_edges(), AIToolManager.TOOL_OUTPUT_CLOSE]
	_add_to_chat(feedback_msg, Caller.SYSTEM)
	_conversation.add_user_prompt(feedback_msg)

	var success = _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_is_thinking = false
		var error_msg = "Something went wrong triggering the next step."
		_add_to_chat(error_msg, Caller.SYSTEM)

func _execute_full_plan(plan: Array[Dictionary]) -> void:
	_is_thinking = true
	var combined_output = ""
	for step in plan:
		var tool_name = step.get("tool", "")
		var tool_args = step.get("args", {})
		if tool_name == "": continue

		# Feedback to user about what is being executed
		_add_to_chat("Executing: %s..." % step.get("title", tool_name), Caller.SYSTEM)

		var output = _tool_manager.execute_tool(tool_name, tool_args)
		combined_output += "Step '%s' Output:\n%s\n\n" % [step.get("title", tool_name), output]

	var feedback_msg = "%s\n%s\n%s" % [AIToolManager.TOOL_OUTPUT_OPEN, combined_output.strip_edges(), AIToolManager.TOOL_OUTPUT_CLOSE]
	_add_to_chat(feedback_msg, Caller.SYSTEM)
	_conversation.add_user_prompt(feedback_msg)
	var success = _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_is_thinking = false
		var error_msg = "Something went wrong executing the plan."
		_add_to_chat(error_msg, Caller.SYSTEM)


func _on_send_button_pressed() -> void:
	if send_button.icon == icon_available:
		var prompt = _engineer_prompt(prompt_txt.text)
		prompt_txt.text = ""
		_add_to_chat(prompt, Caller.YOU)
		_submit_prompt(prompt, _get_editor_context())
	else:
		_abandon_request()


func update_border_color(color: Color) -> void:
	var style_bg = self.get_theme_stylebox("panel")
	if style_bg and style_bg is StyleBoxFlat:
		style_bg.border_color = color
	var header_panel = get_node_or_null("MainLayout/ChatHeader")
	if header_panel:
		var style_header = header_panel.get_theme_stylebox("panel")
		if style_header and style_header is StyleBoxFlat:
			style_header.border_color = color
	var input_panel = get_node_or_null("MainLayout/ContentSplitter/InputArea/VBox/PanelContainer")
	if input_panel:
		var style_input = input_panel.get_theme_stylebox("panel")
		if style_input and style_input is StyleBoxFlat:
			style_input.border_color = color
	$MainLayout/ChatHeader/HBox/VBoxContainer/Title.add_theme_color_override("font_color", color)


func _on_history_pressed() -> void:
	history_requested.emit()

func _on_bot_message_produced(message: String) -> void:
	_add_to_chat(message, Caller.BOT)

func _on_error_message_produced(message: String) -> void:
	_add_to_chat(message, Caller.SYSTEM)


func _generate_chat_title() -> void:
	if not _llm or not _conversation:
		return

	var chat_history = _conversation.clone_chat()
	if chat_history.is_empty():
		return

	if _llm.is_busy():
		return

	var title_prompt := [
		{
			"role": _llm.get_system_role(),
			"content": TITLE_SYSTEM_PROMPT
		}
	]

	var history_text := ""
	for i in range(min(4, chat_history.size())):
		var msg = chat_history[i]
		history_text += "%s: %s\n" % [msg.role, msg.content]

	title_prompt.append({
		"role": _llm.get_user_role(),
		"content": "Conversation:\n" + history_text
	})

	_llm.send_chat_request(title_http_request, title_prompt)



func _on_title_request_completed(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _llm:
		_llm.clear_busy()

	if result == HTTPRequest.RESULT_SUCCESS:
		var raw_title = _llm.read_response(body)
		if raw_title != LLMInterface.INVALID_RESPONSE:
			var cleaned_title = raw_title.strip_edges().replace("\"", "").replace("Title:", "").strip_edges()
			if cleaned_title.length() > 50:
				cleaned_title = cleaned_title.substr(0, 47) + "..."

			if not cleaned_title.is_empty() and cleaned_title.length() > 2:
				_chat_title = cleaned_title
				_set_tab_label()
				_create_save_file()
				chat_updated.emit()


func _on_new_chat_pressed() -> void:
	new_chat.emit()
