class_name AIToolManager
extends RefCounted

const TOOL_TAG_OPEN = "<tool_code>"
const TOOL_TAG_CLOSE = "</tool_code>"
const TOOL_OUTPUT_OPEN = "<tool_output>"
const TOOL_OUTPUT_CLOSE = "</tool_output>"

func get_system_instructions() -> String:
	return """
## TOOL USAGE
You are an autonomous agent capable of interacting with the Godot project files.
Execute all possible steps, one per time, with caution to complete the orders given to you.
To use a tool, you MUST format your response using the <tool_code> tag with a JSON object.
The user can't see you usage of the <tool_code> tags

## GUIDELINES
- If you need to plan or reason before acting, wrap your thoughts in <think>...</think> tags. These will typically be hidden from the user.
- Otherwise, keep your responses concise and direct.

Syntax:
<tool_code>
{
	"name": "tool_name",
	"args": {
		"arg_name": "value"
	}
}
</tool_code>

Available Tools:
1. list_dir(path: string)
   - Recursively lists all files and folders in a directory.
   - Use "res://" for the project root.
   - Example: {"name": "list_dir", "args": {"path": "res://scripts"}}

2. read_file(path: string)
   - Reads the content of a file.
   - Example: {"name": "read_file", "args": {"path": "res://scripts/player.gd"}}

3. write_file(path: string, content: string)
   - Writes content to a file. Creates the file AND parent directories if they don't exist.
   - WARNING: This overwrites the entire file.
   - Example: {"name": "write_file", "args": {"path": "res://new_folder/readme.txt", "content": "Hello World"}}

4. make_dir(path: string)
   - Creates a directory (and parent directories) if they don't exist.
   - Example: {"name": "make_dir", "args": {"path": "res://new_folder/sub_folder"}}

5. remove_dir(path: string)
   - Deletes a directory AND ALL ITS CONTENTS recursively.
   - EXTREME CAUTION: This is irreversible.
   - Example: {"name": "remove_dir", "args": {"path": "res://temp_folder"}}

6. move_file(source: string, destination: string)
   - Moves or renames a file.
   - Example: {"name": "move_file", "args": {"source": "res://test.gd", "destination": "res://scripts/test.gd"}}

7. move_dir(source: string, destination: string)
   - Moves or renames a directory.
   - Example: {"name": "move_dir", "args": {"source": "res://folder", "destination": "res://new_folder"}}

8. remove_file(path: string)
   - Deletes a file PERMANENTLY.
   - Use with extreme caution. confirming the path first.
   - Example: {"name": "remove_file", "args": {"path": "res://temp.txt"}}

6. remove_files(paths: array)
   - Deletes multiple files PERMANENTLY.
   - Use with extreme caution. confirming the path first.
   - Example: {"name": "remove_files", "args": {"paths": ["res://temp.txt", "res://temp2.txt"]}}

6. get_errors()
   - Checks ALL scripts in the project for syntax errors.
   - Checks open scripts first (including unsaved changes), then scans disk.
   - Returns detailed error list with file paths and error details.
   - Example: {"name": "get_errors", "args": {}}

- IMPORTANT: Only use one tool call per message. Wait for the result (the <tool_output> tag) before proceeding.
- CRITICAL: BEFORE writing any code or creating files, you MUST read the existing directory structure and relevant files to understand the project context. Do NOT write code blindly.
- Do NOT guess file paths. Verify their existence with `list_dir` before reading.
- After using `write_file`, STRONGLY CONSIDER calling `get_errors` to verify the code has no syntax errors.
- You CAN read and edit Godot Scene files (.tscn) if requested. Be careful to preserve the existing format/structure, but do not refuse to do it.
- Keep your responses concise and direct to avoid hitting output token limits.
- Wait for the <tool_output> from the system. Do NOT generate <tool_output> tags yourself.
- Do not make up tools.
"""

func contains_tool_call(text: String) -> bool:
	return text.contains(TOOL_TAG_OPEN) and text.contains(TOOL_TAG_CLOSE)

func extract_tool_calls(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var json = JSON.new()
	
	var p = 0
	while true:
		var start = text.find(TOOL_TAG_OPEN, p)
		if start == -1:
			break
			
		var end = text.find(TOOL_TAG_CLOSE, start)
		if end == -1:
			break
			
		var json_str = text.substr(start + TOOL_TAG_OPEN.length(), end - start - TOOL_TAG_OPEN.length())
		var err = json.parse(json_str)
		
		# If parse successful
		if err == OK:
			var data = json.get_data()
			if data is Dictionary and "name" in data:
				result.append(data)
		
		p = end + TOOL_TAG_CLOSE.length()
		
	return result

func process_tool_call(text: String) -> String:
	# Legacy single-call processor
	var start = text.find(TOOL_TAG_OPEN)
	var end = text.find(TOOL_TAG_CLOSE)
	
	if start == -1 or end == -1:
		return "Error: Incomplete tool tag."
		
	var json_str = text.substr(start + TOOL_TAG_OPEN.length(), end - start - TOOL_TAG_OPEN.length())
	var json = JSON.new()
	var error = json.parse(json_str)
	
	if error != OK:
		return "Error: Failed to parse tool JSON: " + json.get_error_message()
		
	var data = json.get_data()
	if not data is Dictionary or not "name" in data:
		return "Error: Invalid tool JSON format. Missing 'name'."
		
	return execute_tool(data.name, data.get("args", {}))

func execute_tool(name: String, args: Dictionary) -> String:
	match name:
		"list_dir":
			return _list_dir(args.get("path", "res://"))
		"read_file":
			return _read_file(args.get("path", ""))
		"write_file":
			return _write_file(args.get("path", ""), args.get("content", ""))
		"make_dir":
			return _make_dir(args.get("path", ""))
		"remove_dir":
			return _remove_dir(args.get("path", ""))
		"move_file":
			return _move_file(args.get("source", ""), args.get("destination", ""))
		"move_dir":
			return _move_dir(args.get("source", ""), args.get("destination", ""))
		"remove_file":
			return _remove_file(args.get("path", ""))
		"remove_files":
			return _remove_files(args.get("paths", []))
		"get_errors":
			return _get_errors()
		_:
			return "Error: Unknown tool '%s'." % name

func _move_file(source: String, destination: String) -> String:
	if not FileAccess.file_exists(source):
		return "Error: Source file '%s' does not exist." % source
		
	# Ensure destination directory exists
	var dir_path = destination.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return "Error: Could not create destination directory '%s'. Error code: %d" % [dir_path, err]

	var err = DirAccess.rename_absolute(source, destination)
	if err != OK:
		return "Error: Failed to move file from '%s' to '%s'. Error code: %d" % [source, destination, err]
		
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	return "Success: Moved '%s' to '%s'." % [source, destination]

func _move_dir(source: String, destination: String) -> String:
	if not DirAccess.dir_exists_absolute(source):
		return "Error: Source directory '%s' does not exist." % source
		
	if DirAccess.dir_exists_absolute(destination):
		return "Error: Destination directory '%s' already exists." % destination
		
	# Ensure parent of destination directory exists
	var parent_dir = destination.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent_dir):
		var err = DirAccess.make_dir_recursive_absolute(parent_dir)
		if err != OK:
			return "Error: Could not create parent directory '%s'. Error code: %d" % [parent_dir, err]

	var err = DirAccess.rename_absolute(source, destination)
	if err != OK:
		return "Error: Failed to move directory from '%s' to '%s'. Error code: %d" % [source, destination, err]
		
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	return "Success: Moved directory '%s' to '%s'." % [source, destination]

func _make_dir(path: String) -> String:
	if DirAccess.dir_exists_absolute(path):
		return "Success: Directory '%s' already exists." % path
		
	var err = DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		return "Error: Could not create directory '%s'. Error code: %d" % [path, err]
		
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	return "Success: Directory '%s' created." % path

func _remove_dir(path: String) -> String:
	if path == "res://" or path == "res:/" or path == "res:":
		return "Error: Cannot delete project root!"
		
	if not DirAccess.dir_exists_absolute(path):
		return "Error: Directory '%s' not found." % path

	# Recursive delete
	var err = _delete_recursive(path)
	
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
	
	if err == OK:
		return "Success: Directory '%s' and all contents deleted." % path
	else:
		return "Error: Failed to delete directory '%s'. Error code: %d" % [path, err]

func _delete_recursive(path: String) -> int:
	var dir = DirAccess.open(path)
	if not dir: return ERR_CANT_OPEN
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name
			if dir.current_is_dir():
				var err = _delete_recursive(full_path)
				if err != OK: return err
			else:
				var err = dir.remove(file_name)
				if err != OK: return err
		file_name = dir.get_next()
		
	return DirAccess.remove_absolute(path)

func _list_dir(path: String) -> String:
	var files: Array[String] = []
	_scan_dir_recursive(path, "", files)
	
	if files.is_empty():
		return "Directory '%s' is empty or could not be accessed." % path
		
	return "Directory '%s' contents (recursive):\n%s" % [path, "\n".join(files)]

func _scan_dir_recursive(base_path: String, current_subdir: String, results: Array[String]) -> void:
	var dir_path = base_path
	if not dir_path.ends_with("/"):
		dir_path += "/"
	dir_path += current_subdir
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var is_hidden := file_name.begins_with(".")
		var is_root_addons := file_name == "addons" and (dir_path == "res://" or dir_path == "res:///")
		
		if not is_hidden and not is_root_addons:
			if dir.current_is_dir():
				var new_sub = current_subdir + file_name + "/"
				results.append(new_sub)
				_scan_dir_recursive(base_path, new_sub, results)
			else:
				results.append(current_subdir + file_name)
		file_name = dir.get_next()

func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Error: File '%s' not found." % path
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return "Error: Could not open file '%s'." % path
		
	return file.get_as_text()

var _plugin: EditorPlugin

func initialize(plugin: EditorPlugin) -> void:
	_plugin = plugin

func _write_file(path: String, content: String) -> String:
	# Ensure directory exists
	var dir_path = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var err = DirAccess.make_dir_recursive_absolute(dir_path)
		if err != OK:
			return "Error: Could not create directory '%s'. Error code: %d" % [dir_path, err]

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return "Error: Could not create/open file '%s' for writing." % path
		
	file.store_string(content)
	file.close() # Ensure explicit close
	
	# Force filesystem update
	if _plugin:
		var fs = _plugin.get_editor_interface().get_resource_filesystem()
		fs.update_file(path) # Use update_file for specific path
		
		# Visually focus the file in the FileSystem dock
		_plugin.get_editor_interface().get_file_system_dock().navigate_to_path(path)
		
		# Try to refresh the text editor UI directly
		_refresh_editor_for_script(path, content)
		
		# Try to refresh open scenes if applicable
		_refresh_editor_for_scene(path)
		
	return "Success: File '%s' written." % path

func _refresh_editor_for_scene(path: String) -> void:
	if not _plugin: return
	
	if not path.ends_with(".tscn") and not path.ends_with(".scn"):
		return
		
	var editor_interface = _plugin.get_editor_interface()
	var open_scenes = editor_interface.get_open_scenes()
	
	if open_scenes.has(path):
		editor_interface.reload_scene_from_path(path)

func _refresh_editor_for_script(path: String, content: String) -> void:
	if not _plugin: return
	
	if not FileAccess.file_exists(path):
		return
	
	var script_editor = _plugin.get_editor_interface().get_script_editor()
	var open_scripts = script_editor.get_open_scripts()
	
	for script in open_scripts:
		if script.resource_path == path:
			# Found the script is open. Switch to it to ensure we can edit it.
			_plugin.get_editor_interface().edit_script(script)
			
			# Now that it's focused, get the current editor
			var current_editor = script_editor.get_current_editor()
			var code_editor = current_editor.get_base_editor()
			
			if code_editor:
				# Store cursor position to avoid jumping
				var column = code_editor.get_caret_column()
				var row = code_editor.get_caret_line()
				var scroll_pos = code_editor.scroll_vertical
				
				code_editor.text = content
				
				# Restore cursor/scroll
				code_editor.set_caret_column(column)
				code_editor.set_caret_line(row)
				code_editor.scroll_vertical = scroll_pos
				
				# Also update the resource source_code so they match
				script.source_code = content
				# Use soft reload (false/default) instead of hard reload (true) 
				# to avoid "File not found" race conditions with the filesystem.
				script.reload()
				
				# Force the editor to acknowledge the change (clears error indicators)
				code_editor.tag_saved_version()
				code_editor.emit_signal("text_changed")
			return

func _remove_file(path: String) -> String:
	print("AI Assistant attempting to delete: %s" % path)
	var dir = DirAccess.open("res://")
	if dir.remove(path) == OK:
		if _plugin:
			_plugin.get_editor_interface().get_resource_filesystem().scan()
		return "Success: File '%s' deleted." % path
	else:
		return "Error: Failed to delete file '%s'." % path


func _remove_files(paths: Array) -> String:
	var dir = DirAccess.open("res://")
	var deleted = []
	var failed = []
	
	for path in paths:
		if dir.remove(path) == OK:
			deleted.append(path)
		else:
			failed.append(path)
			
	if _plugin:
		_plugin.get_editor_interface().get_resource_filesystem().scan()
		
	var msg = ""
	if not deleted.is_empty():
		msg += "Success: Deleted %d files (%s).\n" % [deleted.size(), ", ".join(deleted)]
	if not failed.is_empty():
		msg += "Error: Failed to delete %d files (%s)." % [failed.size(), ", ".join(failed)]
	if msg == "":
		msg = "No files were processed."
		
	return msg

func _get_errors() -> String:
	if not _plugin:
		return "Error: Plugin not initialized."

	var editor_interface = _plugin.get_editor_interface()
	var script_editor = editor_interface.get_script_editor()
	
	# Try to find the output window to scrape validation errors
	var output_rtl = _find_output_rtl(editor_interface.get_base_control())
	var initial_log_size = 0
	if output_rtl:
		initial_log_size = output_rtl.get_parsed_text().length()
	
	var errors = []
	var checked_paths = {}
	
	# PHASE 1: Verify open scripts in memory
	var open_scripts = script_editor.get_open_scripts()
	for script in open_scripts:
		if not script or not script.resource_path:
			continue
			
		var path = script.resource_path
		checked_paths[path] = true
		
		# Try to get text from editor if visible
		var live_code = script.source_code
		var is_unsaved = false
		
		# Check if this script is in the active editor
		for i in range(open_scripts.size()):
			if open_scripts[i] == script:
				# Try to get corresponding editor
				var editors = script_editor.get_open_script_editors()
				if i < editors.size():
					var editor = editors[i]
					var base_editor = editor.get_base_editor()
					if base_editor:
						var editor_text = base_editor.text
						if editor_text != script.source_code:
							live_code = editor_text
							is_unsaved = true
				break
		
		# Inject code and try reload
		script.source_code = live_code
		var err = script.reload()

		if err != OK:
			var status = "[OPEN - UNSAVED]" if is_unsaved else "[OPEN]"
			var details = ""
			if output_rtl:
				details = _scrape_rtl_error(output_rtl, path.get_file(), initial_log_size)
			
			errors.append({
				"path": path,
				"status": status,
				"error_code": err,
				"details": details
			})
	
	# PHASE 2: Verify scripts on disk (only unchecked .gd files)
	var all_scripts = _find_all_gd_files("res://")
	for path in all_scripts:
		if checked_paths.has(path):
			continue # Already checked in Phase 1
			
		if not FileAccess.file_exists(path):
			continue
			
		var script = load(path)
		if not script is Script:
			continue
			
		var err = script.reload()
		if err != OK:
			var details = ""
			if output_rtl:
				details = _scrape_rtl_error(output_rtl, path.get_file(), initial_log_size)
				
			errors.append({
				"path": path,
				"status": "[DISK]",
				"error_code": err,
				"details": details
			})
	
	# Format result
	if errors.is_empty():
		return "No errors found in open scripts or on disk."
	
	var result = "Errors found (%d files):\n\n" % errors.size()
	
	for error in errors:
		result += "%s %s\n" % [error.status, error.path]
		result += "  Error Code: %d\n" % error.error_code
		if not error.details.is_empty():
			result += "  Details (%s)\n" % error.details
		else:
			result += "  Details (unavailable)\n"
		result += "\n"
	
	return result

func _find_all_gd_files(base_path: String) -> Array:
	var files = []
	_scan_gd_recursive(base_path, "", files)
	return files

func _scan_gd_recursive(base_path: String, current_subdir: String, results: Array) -> void:
	var dir_path = base_path
	if not dir_path.ends_with("/"):
		dir_path += "/"
	dir_path += current_subdir
	
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var is_hidden := file_name.begins_with(".")
		var is_addons := file_name == "addons" and (dir_path == "res://")
		
		if not is_hidden and not is_addons:
			if dir.current_is_dir():
				var new_sub = current_subdir + file_name + "/"
				_scan_gd_recursive(base_path, new_sub, results)
			elif file_name.ends_with(".gd"):
				results.append(base_path + current_subdir + file_name)
		file_name = dir.get_next()


func _find_output_rtl(root: Node) -> RichTextLabel:
	# Robust search: Find ALL RichTextLabels and check if their path suggests they are the Output log
	var all_rtls = root.find_children("*", "RichTextLabel", true, false)
	
	for node in all_rtls:
		if not node is RichTextLabel: continue
		
		# Avoid scanning our own UI
		if "AIAssistant" in node.name or "AIAssistant" in str(node.get_path()):
			continue
			
		# Check if parent or path looks like the Output dock
		# Based on debug: @EditorBottomPanel@.../@EditorLog@...
		var path_str = str(node.get_path())
		if "EditorLog" in path_str:
			return node as RichTextLabel
			
	return null


func _scrape_rtl_error(rtl: RichTextLabel, source: String, start_offset: int) -> String:
	var text = rtl.get_parsed_text()
	if text.is_empty():
		text = rtl.text
	
	if text.is_empty(): return "[Empty Output Log]"
	
	# Only look at the new part of the log (after start_offset)
	var new_log_chunk = text
	if start_offset > 0 and start_offset < text.length():
		new_log_chunk = text.substr(start_offset)
	elif start_offset >= text.length():
		# No new text? Then maybe reload didn't print anything or just returned error code
		return "[No new logs generated]"
	
	var lines = new_log_chunk.split("\n")
	var unique_lines = []
	var seen_lines = {}
	
	# Process matching lines
	for line in lines:
		var clean_line = line.strip_edges()
		if clean_line.is_empty(): continue
		
		if source in clean_line:
			if not seen_lines.has(clean_line):
				seen_lines[clean_line] = true
				unique_lines.append(clean_line)
			
	if unique_lines.is_empty():
		return "[No specific errors found in new logs for %s]" % source
			
	return "From %s LOG:\n%s" % [source, "\n".join(unique_lines)]
