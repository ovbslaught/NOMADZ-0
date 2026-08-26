@tool
class_name AIChat
extends Control

signal models_loaded
signal save_changed(chat: AIChat, save_on: bool)

enum Caller {
	None,
	You,
	Bot,
	System
}

const CHAT_HISTORY_EDITOR = preload("res://addons/ai_autonomous_agent/chat_history_editor.tscn")
const SAVE_PATH := "user://ai_assistant_hub/saved_chats/"

@onready var http_request: HTTPRequest = %HTTPRequest
@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var output_window: RichTextLabel = %OutputWindow
@onready var prompt_txt: TextEdit = %PromptTxt
@onready var status_button: Button = %StatusButton

@onready var model_options_btn: OptionButton = %ModelOptionsBtn
@onready var max_steps_spin_box: SpinBox = %MaxStepsSpinBox

@onready var api_label: Label = %APILabel
@onready var save_check_button: CheckButton = %SaveCheckButton

const TOOL_MANAGER = preload("res://addons/ai_autonomous_agent/tools/ai_tool_manager.gd")

var _plugin: AIHubPlugin
var _bot_name: String
var _assistant_settings: AIAssistantResource
var _bot_answer_handler: AIAnswerHandler
var _llm: LLMInterface
var _conversation: AIConversation
var _chat_save_path: String
var _tool_manager = TOOL_MANAGER.new()
var _autonomous_loop_count := 0
var _last_caller: Caller = Caller.None
var _bot_block_open := false
var _is_thinking := false: set = _set_is_thinking
@export var icon_available: Texture2D
@export var icon_thinking: Texture2D

var _stop_icon: Texture2D # Deprecated, kept for safe transition logic/vars if needed, but logic below replaces it.
var _green_circle_icon: Texture2D # Deprecated


func _set_is_thinking(value: bool):
	_is_thinking = value
	if status_button:
		if value:
			status_button.icon = icon_thinking
			status_button.disabled = false
			status_button.tooltip_text = "Stop generation"
		else:
			status_button.icon = icon_available
			status_button.disabled = true
			status_button.tooltip_text = "Assistant is available"
			
	if prompt_txt:
		prompt_txt.editable = !value
		if !value:
			prompt_txt.grab_focus()


func initialize(plugin: AIHubPlugin, assistant_settings: AIAssistantResource, bot_name: String) -> void:
	_plugin = plugin
	_assistant_settings = assistant_settings
	_bot_name = bot_name
	
	if not is_node_ready():
		await ready

	# Icons are now set via exports or loaded from default files if missing
	if icon_available == null:
		icon_available = load("res://addons/ai_autonomous_agent/graphics/icons/status_available.svg")
	if icon_thinking == null:
		icon_thinking = load("res://addons/ai_autonomous_agent/graphics/icons/status_thinking.svg")
		
	# _create_status_icons() # Removed procedural generation
	_set_is_thinking(false)
	
	# Code selector initialization removed
	_tool_manager.initialize(plugin)
	_bot_answer_handler = AIAnswerHandler.new(plugin)
	_bot_answer_handler.bot_message_produced.connect(func(message): _add_to_chat(message, Caller.Bot))
	_bot_answer_handler.error_message_produced.connect(func(message): _add_to_chat(message, Caller.System))
	_set_tab_label()
	
	if _chat_save_path.is_empty():
		var save_id = ("%s_%s_%s" % [Time.get_datetime_string_from_system(), assistant_settings.type_name, bot_name]).validate_filename()
		_chat_save_path = SAVE_PATH + save_id + ".cfg"
		if not DirAccess.dir_exists_absolute(SAVE_PATH):
			DirAccess.make_dir_absolute(SAVE_PATH)
	
	var llm_provider := _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.System)
		return
	api_label.text = llm_provider.name
	var new_conversation := _conversation == null
	if new_conversation:
		_create_conversation(llm_provider)
	
	if _assistant_settings: # We need to check this, otherwise this is called when editing the plugin
		_load_api(llm_provider)
		# Temperature UI removed
		max_steps_spin_box.value = _assistant_settings.max_autonomous_steps

		
		if new_conversation:
			var sys_msg = "%s" % [_assistant_settings.ai_description]
			sys_msg += "\n" + _tool_manager.get_system_instructions()
			_conversation.set_system_message(sys_msg)
	
		# Quick prompts removed
		
		_llm.send_get_models_request(models_http_request)
		prompt_txt.text = ""
		prompt_txt.editable = true
		if new_conversation:
			_greet()


func get_assistant_settings() -> AIAssistantResource:
	return _assistant_settings


func initialize_from_file(plugin: AIHubPlugin, file: String) -> void:
	_plugin = plugin
	_chat_save_path = file
	if not is_node_ready():
		await ready
	

	var config = ConfigFile.new()
	config.load(_chat_save_path)
	var res_path = config.get_value("setup", "assistant_res")
	_assistant_settings = load(res_path)
	var bot_name: String = config.get_value("setup", "bot_name")
	var system_message: String = config.get_value("setup", "system_message")
	var chat_history: Array = config.get_value("chat", "entries")
	var llm_provider := _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.System)
		return
	_create_conversation(llm_provider)
	_conversation.set_system_message(system_message)
	await initialize(plugin, _assistant_settings, bot_name)
	_conversation.overwrite_chat(chat_history)
	_conversation.set_system_message(chat_history[0].content)
	_load_conversation_to_chat(chat_history)
	save_check_button.button_pressed = true


func _create_save_file() -> void:
	var config = ConfigFile.new()
	config.load(_chat_save_path)
	config.set_value("setup", "assistant_res", _assistant_settings.resource_path)
	config.set_value("setup", "bot_name", _bot_name)
	config.set_value("setup", "system_message", _conversation.get_system_message())
	config.set_value("chat", "entries", _conversation.clone_chat())
	config.save(_chat_save_path)


func _create_conversation(llm_provider: LLMProviderResource) -> void:
	_conversation = AIConversation.new(
		llm_provider.system_role_name,
		llm_provider.user_role_name,
		llm_provider.assistant_role_name
	)
	_conversation.chat_edited.connect(_on_conversation_chat_edited)
	_conversation.chat_appended.connect(_on_conversation_chat_appended)


func _find_llm_provider() -> LLMProviderResource:
	var llm_provider := _assistant_settings.llm_provider
	if llm_provider == null:
		_add_to_chat("Warning: Assistant %s does not have LLM provider. Using the current LLM API selected in the main tab." % _assistant_settings.type_name, Caller.System)
		llm_provider = _plugin.get_current_llm_provider()
	return llm_provider


func _set_tab_label() -> void:
	if _assistant_settings.type_icon == null:
		var tab_type_name = _assistant_settings.type_name
		if tab_type_name.is_empty():
			tab_type_name = _assistant_settings.resource_path.get_file().trim_suffix(".tres")
		
		if tab_type_name == _bot_name:
			name = "%s" % _bot_name
		else:
			name = "[%s] %s" % [tab_type_name, _bot_name]
	else:
		name = "%s" % [_bot_name]


func _load_conversation_to_chat(chat_history: Array) -> void:
	output_window.clear()
	_bot_block_open = false
	var llm_provider: LLMProviderResource = _assistant_settings.llm_provider
	for entry in chat_history:
		if entry.has("role") and entry.has("content"):
			if entry.role == llm_provider.user_role_name:
				if entry.content.begins_with(AIToolManager.TOOL_OUTPUT_OPEN):
					# Tool outputs are technically user messages in some APIs, but we display as System
					_add_to_chat(entry.content, Caller.System)
				else:
					_add_to_chat(entry.content, Caller.You)
			elif entry.role == llm_provider.assistant_role_name:
				_add_to_chat(entry.content, Caller.Bot)
			elif entry.role == llm_provider.system_role_name:
				_add_to_chat(entry.content, Caller.System)
	output_window.scroll_to_line(output_window.get_line_count())


func _load_api(llm_provider: LLMProviderResource) -> void:
	_llm = _plugin.new_llm(llm_provider)
	if _llm:
		_llm.model = _assistant_settings.ai_model
		_llm.override_temperature = _assistant_settings.use_custom_temperature
		_llm.temperature = _assistant_settings.custom_temperature
	else:
		push_error("LLM provider failed to initialize. Check the LLM API configuration for it.")


func _greet() -> void:
	pass # Quick prompts and greeting removed
	
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
					_add_to_chat(prompt, Caller.You)
					_submit_prompt(prompt)

func _find_code_editor() -> TextEdit:
	var script_editor := _plugin.get_editor_interface().get_script_editor().get_current_editor()
	return script_editor.get_base_editor()


func _engineer_prompt(original: String) -> String:
	if original.contains("{CODE}"):
		var curr_code: String = _find_code_editor().get_selected_text()
		var prompt: String = original.replace("{CODE}", curr_code)
		return prompt
	else:
		return original


func _submit_prompt(prompt: String) -> void:
	if _is_thinking:
		_abandon_request()
	# Quick prompt assignment removed
	_is_thinking = true
	_autonomous_loop_count = 0
	_conversation.add_user_prompt(prompt)
	if not _llm:
		push_error("No language model provider loaded. Check configuration!")
		_add_to_chat("No language model provider loaded. Check configuration!", Caller.System)
		return
	var success := _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_add_to_chat("Something went wrong. Review the details in Godot's Output tab.", Caller.System)


func _abandon_request() -> void:
	http_request.cancel_request()
	_is_thinking = false
	_autonomous_loop_count = 0
	_add_to_chat("Abandoned previous request.", Caller.System)
	_conversation.forget_last_prompt()

func _abandon_button_pressed() -> void:
	_abandon_request()

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	#print("HTTP response: Result: %d, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])
	if result == HTTPRequest.RESULT_SUCCESS:
		var text_answer = _llm.read_response(body)
		if text_answer == LLMInterface.INVALID_RESPONSE:
			_is_thinking = false
			push_error("Response: %s" % _llm.get_full_response(body))
			_add_to_chat("An error occurred while processing your last request. Review the details in Godot's Output tab.", Caller.System)
		else:
			_conversation.add_assistant_response(text_answer)
			_bot_answer_handler.handle(text_answer)
			
			if _tool_manager.contains_tool_call(text_answer):
				if _autonomous_loop_count < _assistant_settings.max_autonomous_steps:
					_autonomous_loop_count += 1
					# Keep thinking state
					_is_thinking = true
					
					var tool_calls = _tool_manager.extract_tool_calls(text_answer)
					var combined_output = ""
					
					for call_data in tool_calls:
						var tool_name = call_data.name
						var tool_args = call_data.get("args", {})
						var output = _tool_manager.execute_tool(tool_name, tool_args)
						
						combined_output += "Tool '%s' Output:\n%s\n\n" % [tool_name, output]
					
					var feedback_msg = "%s\n%s\n%s" % [AIToolManager.TOOL_OUTPUT_OPEN, combined_output.strip_edges(), AIToolManager.TOOL_OUTPUT_CLOSE]
					
					_add_to_chat(feedback_msg, Caller.System)
					_conversation.add_user_prompt(feedback_msg)
					
					# Removed timer to prevent main thread suspension cancellation during script reloads
					# prompted by filesystem updates.
					
					if not _is_thinking:
						return
					
					var success := _llm.send_chat_request(http_request, _conversation.build())
					if not success:
						_is_thinking = false
						_add_to_chat("Something went wrong triggering the autonomous step.", Caller.System)
				else:
					_is_thinking = false
					_add_to_chat("The agent performed the maximum number of steps defined. Please confirm if you want to continue.", Caller.System)
					_autonomous_loop_count = 0
			else:
				# No tool call, finished
				_is_thinking = false
				_autonomous_loop_count = 0
	else:
		_is_thinking = false
		var error_msg = _get_http_result_string(result)
		push_error("HTTP Request Error: %s (Result Code: %d). Response Code: %d." % [error_msg, result, response_code])
		_add_to_chat("Connection error: %s. Check Godot Output for details." % error_msg, Caller.System)


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
	
	if caller == Caller.You or caller == Caller.System:
		output_window.scroll_following = true
	else:
		output_window.scroll_following = auto_scroll
	
	return auto_scroll


# --- RENDERERS ---
func _render_user_message(text: String) -> void:
	text = text.strip_edges(true, true)

	_reset_visual_context()
	output_window.newline() # entrada limpa
	output_window.push_indent(1)
	output_window.push_color(Color(0xFFFF00FF))
	output_window.append_text("> %s" % text)
	output_window.newline() # saída limpa


func _render_bot_message(text: String) -> void:
	_render_bot_header_if_needed()

	if text.count("```") >= 2 and text.count("```") % 2 == 0:
		_render_bot_with_code(text)
	else:
		_render_bot_plain(text)


func _render_system_message(text: String) -> void:
	if text.begins_with(AIToolManager.TOOL_OUTPUT_OPEN):
		pass
	else:
		output_window.push_color(Color(0xFF7700FF))
		output_window.append_text("\n[center]%s[/center]\n" % text)


func _render_bot_header_if_needed() -> void:
	if _bot_block_open:
		return

	_reset_visual_context()
	output_window.newline() # entrada limpa
	output_window.push_indent(1)
	output_window.push_indent(1)
	output_window.append_text("[color=FF770066][b]%s[/b][/color]:" % _bot_name)
	output_window.newline() # saída limpa

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
	# Strip hallucinated tool outputs
	var regex = RegEx.new()
	regex.compile("(?s)<tool_output>.*?</tool_output>")
	text = regex.sub(text, "", true)
	
	var parsed := _parse_tool_block(text)
	var prefix := String(parsed.prefix).strip_edges()
	var suffix := String(parsed.suffix).strip_edges()

	_reset_visual_context()
	output_window.newline() # entrada limpa

	output_window.push_indent(1)
	output_window.push_indent(1)
	output_window.push_indent(1)

	if prefix != "":
		for line in prefix.split("\n"):
			if _render_heading(line):
				continue
			output_window.append_text(_format_markdown(line))
			output_window.newline()

	if parsed.has_tool:
		output_window.newline()
		output_window.push_color(Color(0x4DA6FFFF))
		output_window.push_italics()
		output_window.append_text(parsed.status)
		output_window.pop()
		output_window.pop()
		output_window.newline()
	
	if suffix != "":
		# If we found a tool, we must recursively check the suffix for MORE tools
		if parsed.has_tool:
			_render_bot_plain(suffix)
		else:
			# Should typically be empty if no tool, but just in case:
			for line in suffix.split("\n"):
				if _render_heading(line):
					continue
				output_window.append_text(_format_markdown(line))
				output_window.newline()

	output_window.newline() # saída limpa


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

	_reset_visual_context()
	output_window.newline() # entrada limpa

	output_window.push_indent(1)
	output_window.push_indent(1)
	output_window.push_indent(1)

	output_window.push_color(Color(0x4CE0B3FF))
	output_window.push_mono()
	output_window.append_text(escape_bbcode(code))

	output_window.newline()
	output_window.newline() # saída limpa


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
	output_window.pop_all()


func _add_to_chat(text: String, caller: Caller) -> void:
	var auto_scroll_to_bottom: bool = _configure_auto_scroll(caller)

	_reset_visual_context()

	match caller:
		Caller.You:
			_render_user_message(text)
			if not text.contains(AIToolManager.TOOL_OUTPUT_OPEN):
				_last_caller = caller
				_bot_block_open = false
		Caller.Bot:
			_render_bot_message(text)
			_last_caller = caller
		Caller.System:
			_render_system_message(text)
			if not text.begins_with(AIToolManager.TOOL_OUTPUT_OPEN):
				_last_caller = caller
				_bot_block_open = false


	# Scroll
	if caller == Caller.Bot and not auto_scroll_to_bottom:
		await get_tree().process_frame
		await get_tree().process_frame
		_scroll_output_by_page()


func _on_models_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
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
	model_options_btn.clear()
	var selected_found := false
	for model in models:
		model_options_btn.add_item(model)
		if model == _assistant_settings.ai_model:
			model_options_btn.select(model_options_btn.item_count - 1)
			selected_found = true
	if not selected_found:
		model_options_btn.add_item(_assistant_settings.ai_model)
		model_options_btn.select(model_options_btn.item_count - 1)
	models_loaded.emit()


func _on_edit_history_pressed() -> void:
	var history_editor: ChatHistoryEditor = CHAT_HISTORY_EDITOR.instantiate()
	history_editor.initialize(_conversation)
	add_child(history_editor)
	history_editor.popup()


func _on_model_options_btn_item_selected(index: int) -> void:
	_llm.model = model_options_btn.text

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
	if save_check_button.button_pressed:
		_create_save_file()
	_load_conversation_to_chat(chat_history)


func _ready() -> void:
	pass

func _on_conversation_chat_appended(new_entry: Dictionary) -> void:
	if save_check_button.button_pressed:
		var config = ConfigFile.new()
		var load_result := config.load(_chat_save_path)
		if load_result != OK:
			_create_save_file()
		else:
			var current_chat: Array = config.get_value("chat", "entries", [])
			current_chat.append(new_entry)
			config.save(_chat_save_path)
