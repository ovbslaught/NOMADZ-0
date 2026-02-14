@tool
extends EditorPlugin

const POPUP = preload("uid://dfvnwk61l0e75")

var fetch_button: Button
var git_user: String
var git_repo: String
var popup: Window
var fetched_dir: String

func _enter_tree() -> void:
	fetch_button = Button.new()
	fetch_button.text = "fetch"
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, fetch_button)
	fetch_button.get_parent().move_child(fetch_button,-2)
	fetch_button.pressed.connect(_fetch_pressed)

func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR,fetch_button)
	fetch_button.queue_free()
	
func _fetch_pressed():
	var cfg: ConfigFile = ConfigFile.new()
	var script_path: String = get_script().resource_path
	var cfg_path: String = script_path.get_base_dir().path_join("setup.cfg")
	var err: int = cfg.load(cfg_path)
	if err == OK:
		git_user = str(cfg.get_value("MAIN", "github_username", ""))
		git_repo = str(cfg.get_value("MAIN", "github_repo", ""))
	else:
		push_warning("Failed to load config: %s" % cfg_path)
		return
	
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_fetch_init_complete)
	req.request("https://api.github.com/repos/%s/%s/contents" % [git_user, git_repo])
	await req.request_completed
	req.queue_free()

func _fetch_init_complete(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var body_string: String = body.get_string_from_utf8()
	var parsed: Array = JSON.parse_string(body_string)
	var dirs: PackedStringArray = []
	var readme_raw: String = ""
	for file in parsed:
		if file["type"] == "dir":
			dirs.append(file["name"])
		if file["name"] == "README.md":
			readme_raw = file["download_url"]
	if not readme_raw.is_empty():
		readme(readme_raw)
	popup = POPUP.instantiate()
	add_child(popup)
	popup.show()
	popup.close_requested.connect(func(): popup.queue_free())
	for folder in dirs:
		var folder_button := Button.new()
		folder_button.text = folder
		folder_button.pressed.connect(_script_fetch.bind(folder))
		folder_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		folder_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		popup.get_child(0).get_child(0).add_child(folder_button)

func _script_fetch(dir: String):
	print(dir)
	fetched_dir = dir
	popup.queue_free()
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_fetch_final)
	req.request("https://api.github.com/repos/%s/%s/contents/%s?ref=main" % [git_user,git_repo,dir])
	await req.request_completed
	req.queue_free()

func readme(raw: String):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_fetch_readme)
	req.request(raw)
	await req.request_completed
	req.queue_free()
	
func _fetch_readme(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	print_rich(body.get_string_from_utf8())

func _fetch_final(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var body_string: String = body.get_string_from_utf8()
	var parsed: Array = JSON.parse_string(body_string)
	var files: Dictionary[String,String] = {}
	var readme_raw: String = ""
	for file in parsed:
		if file["type"] == "file":
			files[file["name"]] = file["download_url"]
		if file["name"] == "README.md":
			readme_raw = file["download_url"]
	if not readme_raw.is_empty():
		readme(readme_raw)
	var script_path: String = get_script().resource_path
	var dir_path: String = script_path.get_base_dir().path_join(fetched_dir)
	if !DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
	for file in files.keys():
		var file_path: String = dir_path.path_join(file)
		save_file(file_path,files[file])

func save_file(file_path: String, download_url: String):
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_write_request.bind(file_path))
	req.request(download_url)
	await req.request_completed
	req.queue_free()
	
func _write_request(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, file_path: String):
	var file_text: String = body.get_string_from_utf8()
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(file_text)
		file.close()
	else:
		push_warning("Failed to open file for writing: %s (err %d)" % [file_path, FileAccess.get_open_error()])
