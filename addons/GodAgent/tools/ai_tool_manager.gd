class_name AIToolManager
extends RefCounted

const TOOL_TAG_OPEN = "<tool_code>"
const TOOL_TAG_CLOSE = "</tool_code>"
const TOOL_OUTPUT_OPEN = "<tool_output>"
const TOOL_OUTPUT_CLOSE = "</tool_output>"

func get_system_instructions() -> String:
	return """
## SYSTEM ROLE & IDENTITY
You are "GodAgent", an expert Autonomous AI Game Developer specialized in Godot Engine 4.x (specifically 4.6).
Your goal is to help the user build, debug, and optimize their game by directly manipulating the project files.

## CRITICAL PROTOCOL: TOOL USAGE
To interact with the OS and Project, you MUST use the provided tools wrapped in XML tags.

### 1. COMMAND FORMAT
You must execute commands using the following JSON structure inside <tool_code> tags.
**Strict Syntax:**
<tool_code>
{"name": "tool_name", "args": {"key": "value"}}
</tool_code>

### 2. PLANNING FORMAT
When a multi-step task is requested, you should start by providing a plan in the following structure before executing anything:
<tool_code>
{
  "plan": [
    {
	  "title": "Short descriptive title of the step",
	  "tool": "tool_name",
	  "args": {"key": "value"}
    }
  ]
}
</tool_code>

### 3. RULES OF ENGAGEMENT
1. **ONE tool per message:** Wait for the <tool_output> before proceeding.
2. **NO Markdown:** Never use code blocks (```) around the <tool_code> tags.
3. **NO Fake Outputs:** Do not hallucinate tool outputs. Wait for the system.
4. **Validation:** ALWAYS use `read_file` to inspect code before editing it.
5. **Verification:** After writing code, consider using `get_errors` to check syntax.

### 3. AVAILABLE TOOLS
- `list_dir` (args: path): Recursive list of files. Start here to learn the project structure.
- `read_file` (args: path): Get file content.
- `write_file` (args: path, content): Create/Overwrite file.
- `make_dir` (args: path): Create folder.
- `remove_dir` (args: path): Delete folder (Recursive).
- `move_file` (args: source, destination): Rename/Move file.
- `move_dir` (args: source, destination): Rename/Move folder.
- `remove_file` (args: path): Delete file.
- `remove_files` (args: paths): Delete multiple files [List].
- `get_errors` (args: none): Check syntax of all scripts in project.

---

## GODOT 4.x KNOWLEDGE BASE

### 1. GDSCRIPT 2.0 STANDARDS
- **MANDATORY:** Every script MUST start with `extends <ClassName>` (e.g., `extends CharacterBody3D` or `extends Node`). NEVER omit this line.
- Use **Static Typing** whenever possible for performance (`var health: int = 10`, `func get_name() -> String:`).
- Use `@export` instead of `export`.
- Use `await` instead of `yield`.
- Use `super()` for inheritance calls.
- Prefer `Callable` for signals (e.g., `button.pressed.connect(self._on_pressed)`).

### 2. PROJECT ORGANIZATION & HIERARCHY
You are responsible for keeping the project clean. **DO NOT** save files loosely in `res://` unless instructed otherwise (like `project.godot`).
Before creating a file, verify if the folder exists. If not, use `make_dir`.

**Enforce this folder structure:**
- `res://scripts/` -> All `.gd` files.
- `res://scenes/`  -> All `.tscn` files.
- `res://assets/`  -> Raw assets (subfolders: `sprites`, `audio`, `fonts`, `models`).
- `res://resources/` -> Custom Resources (`.tres`).
- `res://levels/`    -> Main level scenes.
- "res://shaders/" -> All ".gdshader" files.

*Example:* If creating a player, save script to `res://scripts/player.gd` and scene to `res://scenes/player.tscn`.

### 3. SHADER STANDARDS (.gdshader)
- **MANDATORY:** Every shader MUST start with `shader_type <type>;` (e.g., `shader_type canvas_item;`, `shader_type spatial;`, or `shader_type particles;`).
- Use descriptive names for `uniform` variables.
- When creating a shader, always save it in `res://shaders/`.

### 4. SCENE FILE (.tscn) STRICT RULES
You are allowed to write .tscn files, but you MUST follow the **Godot Text Serialization Format** perfectly.

**Structure Order (MANDATORY):**
1. **Header:** `[gd_scene load_steps=N format=3]` (Format 3 is for Godot 4).
2. **ExtResources:** `[ext_resource type="Script" path="res://..." id="1_abcde"]` (Top of file).
3. **SubResources:** `[sub_resource type="BoxShape3D" id="BoxShape3D_1"]` (Before nodes).
4. **Nodes:** `[node name="Name" type="Type" parent="."]`
5. **Connections:** `[connection signal="..." from="..." to="..." method="..."]` (Bottom of file).

**Critical Constraints for .tscn:**
- **NO Logic:** Never use `.new()`, function calls, or math expressions inside a .tscn. It is purely data.
- **IDs:** Use unique string or integer IDs for resources. References MUST match the definition ID (e.g., `script = ExtResource("1_abcde")`).
- **UIDs:** If you do not know the `uid="uid://..."` of a resource, **OMIT** the uid field entirely. Do not invent fake UIDs.
- **Formatting:** Do not use quotes for `SubResource(...)` or `ExtResource(...)` calls inside properties.

**Example of Valid .tscn:**
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1_script"]

[sub_resource type="BoxShape3D" id="2_shape"]
size = Vector3(1, 2, 1)

[node name="Player" type="CharacterBody3D"]
script = ExtResource("1_script")

[node name="Collision" type="CollisionShape3D" parent="."]
shape = SubResource("2_shape")

---

## EXECUTION WORKFLOW
1. **Analyze:** Receive user request.
2. **Plan:** Wrap your reasoning in <think> tags. Decide which files to check first.
3. **Check Paths:** Before creating a file, check if the standard folder (e.g., `res://scripts/`) exists using `list_dir`. If not, plan to `make_dir`.
4. **Action:** Execute `write_file` or other ops using <tool_code>.
5. **Confirm:** Verify the action was successful or handle errors.

**Language Protocol:**
Answer the user in the language they used in their last message (e.g., Spanish if they speak Spanish), but keep your internal reasoning and tool usage logical.
"""

func contains_tool_call(text: String) -> bool:
	# Return true if explicit tags exist or if the text looks like a raw JSON
	# tool call (starts with {, ends with } and parses to a dict with 'name').
	if text.contains(TOOL_TAG_OPEN) and text.contains(TOOL_TAG_CLOSE):
		return true
	return _is_raw_json_tool_call(text)


func _is_raw_json_tool_call(text: String) -> bool:
	var t = text.strip_edges(true, true)
	if t.begins_with("{") and t.ends_with("}"):
		# Avoid false positives when tags are already present
		if text.contains(TOOL_TAG_OPEN) or text.contains(TOOL_TAG_CLOSE):
			return false
		var j = JSON.new()
		if j.parse(t) == OK:
			var d = j.get_data()
			return d is Dictionary and d.has("name")
		else:
			return false
	return false

func extract_tool_calls(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var json = JSON.new()
	var p = 0
	while true:
		var start = text.find(TOOL_TAG_OPEN, p)
		if start == -1: break
		var end = text.find(TOOL_TAG_CLOSE, start)
		if end == -1: break
		var json_str = text.substr(start + TOOL_TAG_OPEN.length(), end - start - TOOL_TAG_OPEN.length())
		if json.parse(json_str) == OK:
			var data = json.get_data()
			if data is Dictionary and "name" in data:
				result.append(data)
		p = end + TOOL_TAG_CLOSE.length()
	if result.is_empty() and _is_raw_json_tool_call(text):
		if json.parse(text.strip_edges(true, true)) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("name"):
				result.append(data)
	return result

func extract_plan(text: String) -> Array[Dictionary]:
	var json = JSON.new()
	var p = 0
	# First, try to find plan inside tool_code tags
	while true:
		var start = text.find(TOOL_TAG_OPEN, p)
		if start == -1: break
		var end = text.find(TOOL_TAG_CLOSE, start)
		if end == -1: break

		var json_str = text.substr(start + TOOL_TAG_OPEN.length(), end - start - TOOL_TAG_OPEN.length())
		if json.parse(json_str) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("plan"):
				var plan: Array[Dictionary] = []
				for item in data.plan:
					if item is Dictionary:
						plan.append(item)
				return plan
		p = end + TOOL_TAG_CLOSE.length()

	# Fallback: Try to parse the entire text as raw JSON with a plan
	var trimmed = text.strip_edges(true, true)
	if trimmed.begins_with("{") and trimmed.ends_with("}"):
		if json.parse(trimmed) == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("plan"):
				var plan: Array[Dictionary] = []
				for item in data.plan:
					if item is Dictionary:
						plan.append(item)
				return plan

	return []

func process_tool_call(text: String) -> String:
	# Legacy single-call processor
	var start = text.find(TOOL_TAG_OPEN)
	var end = text.find(TOOL_TAG_CLOSE)

	# If explicit tags are missing, allow a raw JSON tool call as a fallback
	if start == -1 or end == -1:
		if _is_raw_json_tool_call(text):
			var raw = text.strip_edges(true, true)
			var j = JSON.new()
			var err = j.parse(raw)
			if err != OK:
				return "Error: Failed to parse tool JSON: %s" % j.get_error_message()
			var data = j.get_data()
			if not data is Dictionary or not data.has("name"):
				return "Error: Invalid tool JSON format. Missing 'name'."
			return execute_tool(data.name, data.get("args", {}))
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


				# Force the editor to acknowledge the change (clears error indicators)
				code_editor.tag_saved_version()
				code_editor.emit_signal("text_changed")
			return

func _remove_file(path: String) -> String:
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

	var errors = []
	var checked_paths = {}

	# PHASE 1: Check all open scripts
	var open_scripts = script_editor.get_open_scripts()
	for script in open_scripts:
		if not script or not script.resource_path:
			continue

		var path = script.resource_path
		checked_paths[path] = true

		# Get the current text from editor if it's open
		var current_text = script.source_code

		# Check if this script is in an active editor to get unsaved changes
		for i in range(open_scripts.size()):
			if open_scripts[i] == script:
				var editors = script_editor.get_open_script_editors()
				if i < editors.size():
					var editor = editors[i]
					var base_editor = editor.get_base_editor()
					if base_editor:
						current_text = base_editor.text
				break

		# Try to parse the script to check for syntax errors
		var temp_script = GDScript.new()
		temp_script.source_code = current_text
		var err = temp_script.reload()

		if err != OK:
			var error_msg = "Syntax error detected"
			# Try to get more details from the script
			if temp_script.get_parse_errors().size() > 0:
				var parse_errors = []
				for parse_err in temp_script.get_parse_errors():
					parse_errors.append("Line %d: %s" % [parse_err.line, parse_err.message])
				error_msg = "\n  ".join(parse_errors)

			errors.append({
				"path": path,
				"status": "[OPEN]",
				"error_code": err,
				"details": error_msg
			})

	# PHASE 2: Check all .gd files in the project (not in addons)
	var all_gd_files = _find_all_gd_files("res://")
	for path in all_gd_files:
		if checked_paths.has(path):
			continue  # Already checked as open script

		checked_paths[path] = true

		# Read the file
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			continue

		var content = file.get_as_text()
		file.close()

		# Try to parse it
		var temp_script = GDScript.new()
		temp_script.source_code = content
		var err = temp_script.reload()

		if err != OK:
			var error_msg = "Syntax error detected"
			if temp_script.get_parse_errors().size() > 0:
				var parse_errors = []
				for parse_err in temp_script.get_parse_errors():
					parse_errors.append("Line %d: %s" % [parse_err.line, parse_err.message])
				error_msg = "\n  ".join(parse_errors)

			errors.append({
				"path": path,
				"status": "[ON DISK]",
				"error_code": err,
				"details": error_msg
			})

	# Format result
	if errors.is_empty():
		return "No syntax errors found in project scripts."

	var result = "Syntax errors found (%d files):\n\n" % errors.size()

	for error in errors:
		result += "%s %s\n" % [error.status, error.path]
		result += "  Error Code: %d\n" % error.error_code
		result += "  Details:\n  %s\n" % error.details
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
