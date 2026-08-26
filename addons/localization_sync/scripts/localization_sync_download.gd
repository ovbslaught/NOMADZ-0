@tool
extends Button

@export var url_field : LineEdit
@export var sheet_options : OptionButton

const TRANSLATIONS = "internationalization/locale/translations"
const CSV_FILE_PATH = "res://addons/localization_sync/csv/"

const downloadSheetUrl = "{0}?action=getSheet"

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Sheet downloaded! Parsing CSV..")
	
	_clear_folder_recursively(CSV_FILE_PATH)
	
	var response_body = JSON.parse_string(body.get_string_from_utf8())
	
	var csv_dir = []
	for sheet in response_body:
		var dir_path = CSV_FILE_PATH + sheet.Name + "/"
		csv_dir.append(dir_path)
		var file_path = dir_path + sheet.Name + ".csv"
		DirAccess.make_dir_recursive_absolute(dir_path)
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if (!file):
			push_error("Failed to write file: " + file_path)
			continue
		
		file.store_line(sheet.Data)
		file.close()
	
	_poll_translations.call_deferred(csv_dir);

func _poll_translations(all_csv_dir):
	var fs = EditorInterface.get_resource_filesystem()
	fs.scan() ## reloads the file system and creates the .translation files
	
	var translation_files := []
	for sheet_path in all_csv_dir:
		var dir = DirAccess.open(sheet_path)
		if dir == null:
			push_error("Cannot open directory: " + sheet_path)
			return []
	
		var file_names = dir.get_files()
		while not _contains_translation_files(file_names):
			print("translation files aren't ready..")
			await get_tree().create_timer(.5).timeout
			file_names = dir.get_files()
		
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".translation"):
				translation_files.append(sheet_path + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	ProjectSettings.set_setting(TRANSLATIONS, translation_files)
	print("Translations applied!")

func _on_pressed() -> void:
	var url = url_field.text
	print("Requesting sheet data..")
	$HTTPRequest.request(downloadSheetUrl.format([url]))

func _contains_translation_files(file_names) -> bool:
	for name in file_names:
		if name.ends_with(".translation"):
			return true
	return false
	
func _clear_folder_recursively(folder):
	print("clearing folder: " + folder)
	var parentDir = DirAccess.open(folder)
	
	if parentDir == null:
		return

	for file in parentDir.get_files():
		print("removing file: " + file)
		parentDir.remove(file)
	for dir in parentDir.get_directories():
		_clear_folder_recursively(folder +"/"+ dir)
		print("removing dir: " + dir)
		parentDir.remove(dir)
