# SceneLoader.gd (Autoload: SceneLoader)
# Handles asynchronous loading of planets and levels to prevent frame drops.

extends Node

signal loading_progress(progress: float)
signal loading_complete()
signal loading_failed(path: String)

var _loading_path: String = ""
var _is_loading: bool = false
var _progress: Array = []

func _process(_delta: float) -> void:
	if not _is_loading:
		return
	
	# Check loading status
	var status = ResourceLoader.load_threaded_get_status(_loading_path, _progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_progress.emit(_progress[0])
		
		ResourceLoader.THREAD_LOAD_LOADED:
			_is_loading = false
			_finalize_warp()
		
		ResourceLoader.THREAD_LOAD_FAILED:
			_is_loading = false
			loading_failed.emit(_loading_path)
			push_error("[SceneLoader] Failed to load: %s" % _loading_path)
		
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_loading = false
			loading_failed.emit(_loading_path)
			push_error("[SceneLoader] Invalid resource: %s" % _loading_path)

## Entry point for planet transitions
func warp_to_planet(planet_id: String) -> void:
	# Construct path (Adjust based on your project structure)
	var scene_path = "res://scenes/planets/%s.tscn" % planet_id
	
	if not FileAccess.file_exists(scene_path):
		push_error("[SceneLoader] Planet scene not found: %s" % scene_path)
		return
		
	_loading_path = scene_path
	_is_loading = true
	
	# Start background load
	var error = ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		push_error("[SceneLoader] Threaded request failed for %s" % scene_path)
		return

	print("[SceneLoader] Warping to %s..." % planet_id)

func _finalize_warp() -> void:
	var new_scene_resource = ResourceLoader.load_threaded_get(_loading_path)
	if new_scene_resource:
		# Transition scene
		get_tree().change_scene_to_packed(new_scene_resource)
		
		# Update GameManager state
		var planet_id = _loading_path.get_file().get_basename()
		GameManager.current_planet = planet_id
		
		loading_complete.emit()
		print("[SceneLoader] Warp complete: Arrived at %s" % planet_id)