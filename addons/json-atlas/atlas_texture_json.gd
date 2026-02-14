@tool
@icon("atlas_texture_json.svg")
extends AtlasTexture
class_name AtlasTextureJSON
## Draws an [member AtlasTexture] based on a given [Texture2D] [member texture] and it's
## associated [JSON] [member json_file].
##
## [b]Notice:[/b] when exporting via Aseprite, ensure the [b]Item Filename[/b] is formatted as:
##[codeblock lang=text]
##{tag}_{tagframe0000}
##[/codeblock]
## or somethin like that. You just need seperator for symbol name and frame. (only for Aseprite)
##
## @tutorial(Adobe Animate sprite sheet export guide): https://www.adobe.com/africa/learn/animate/web/export-sprite-sheet
## @tutorial(Aseprite`s sprite sheets export formating): https://www.aseprite.org/docs/cli/#filename-format
##

## Signal emitted once the [member frames] and [member symbols] have been populated.
signal data_compiled

@export_tool_button("Update", "Edit") var _call_update = _update_all

## The name of the Symbol that will be selected.
## [br]Set by [method set_symbol].
@export var symbol: String = "": set = set_symbol

## The source [Texture2D] image from which the image will be taken for output.
## [br]Set by [method set_texture]
@export var texture: Texture2D: set = set_texture

##if [code]true[/code], [AtlasTextureJSON] splits [param symbols] and [param symbol`s frame].[br]
##Its only find nums at end of [param Symbol name], and if your symbol has nums at end ([code]Frog01[/code], [code]Frog02[/code] eg.), its makes frames for first symbol with same name without nums at end (after removing "frames nums")[br]
@export var split_frames: bool = false: set = set_split_frames

## The [int] frame of the [member symbol] that will be rendered.
## [br]Set by [method set_frame].
@export var frame: int = 0: set = set_frame

## Split char what splits name and frame of the symbol. (don't make '' splitter, you MUST make some sort of )
@export var frame_num_splitter := &"_":
	set = set_frame_num_splitter

## The [enum FrameBehaviourTypes] type of behaviour for [member frame] when it is set.
@export var frame_behaviour: FrameBehaviourTypes = FrameBehaviourTypes.STOP

#@export var symbols_offets: Dictionary[String, Rect2]

#region STORAGE
## [JSON] file with the atlas data for the [member texture].
## [br]Set by [method set_json_file].
@export_storage var json_file: JSON: set = _set_json_file

## A [PackedStringArray] that stores the [String] symbol names to be used within the animation.
@export_storage var symbols: PackedStringArray

## Stores the [Array] of [Rect2i] ([Vector4]) frames to be used within the animation.
@export_storage var frames: Dictionary[StringName, PackedVector4Array]

## Check what [code].json[/code] is expoted from Adobe's software.
@export_storage var is_adobe := false
#endregion


## Enum to define the behaviour of out-of-bounds sets to [member frame].
enum FrameBehaviourTypes {
	## Clamp higher/lower values of the max/min when setting [member frame].
	STOP = 0,
	## Loop the frames forward/backward. Setting [member frame] higher/lower than the max/min
	## will loop to the start/end.
	LOOP = 1,
}

# Everything, whats starts with [get_*]/[_get_*].
#region GET
## Returns the [int] number of frames in the given [String] [param symbol_name].
func get_frame_count(symbol_name: String = symbol) -> int:
	if !frames.has(symbol_name):
		return 0
	return frames[symbol_name].size()
#endregion

# Everything, whats starts with [set_*]/[_set_*].
#region SET

## Sets current [member symbol] to the given [String] [param new_ymbol].
func set_symbol(new_symbol: String = "") -> void:
	if symbols.is_empty():
		await data_compiled
	if !symbols.has(new_symbol):
		await _load_json()

	
	symbol = new_symbol
	set_frame(frame)
	notify_property_list_changed()


## Set current [member frame] to the given [String] [param new_frame].
func set_frame(new_frame: int) -> void:
	if !frames.has(symbol):
		if symbols.is_empty():
			return
	
	# Just wait...
	if frames.is_empty():
		await data_compiled
	
	# Checks frame_behaviour
	match frame_behaviour:
		FrameBehaviourTypes.LOOP:
			if new_frame < 0:
				new_frame = get_frame_count() - 1
			elif new_frame > get_frame_count() - 1:
				new_frame = 0
		_:
			if new_frame < 0:
				new_frame = 0
			elif new_frame > get_frame_count() - 1:
				new_frame = get_frame_count() - 1
	
	# Sets the values
	frame = new_frame
	region = vec4_to_rect2(frames[StringName(symbol)][frame])

## Sets the [member texture] to the given [Texture2D] [param new_texture].
func set_texture(new_texture: Texture2D) -> void:
	texture = new_texture
	if new_texture:
		var path: String = texture.resource_path.replace(
			texture.resource_path.get_extension(),
			"json"
		)
		if FileAccess.file_exists(path):
			json_file = load(path)
			atlas = new_texture
		else:
			printerr("JSON file for `%s` doesn`t exist!" % texture.resource_path.get_file())
	else:
		json_file = null
		symbols.clear()
		symbol = ""
		frame = 0
		atlas = null
	notify_property_list_changed()

## Sets the [member json_file] to the given [JSON] [param given_file].
func _set_json_file(given_file: JSON) -> void:
	var old_json: JSON = json_file
	json_file = given_file
	is_adobe = json_file.data.meta.app == "Adobe Animate"
	if given_file:
		if !given_file.changed.is_connected(_update_json):
			given_file.changed.connect(_update_json)
		_load_json()
	else:
		old_json.changed.disconnect(_update_json)

## Sets the [member split_frames] to the given [bool] [param new].
func set_split_frames(new: bool):
	split_frames = new
	_update_all()
	symbol = symbols[0]
	notify_property_list_changed()

func set_frame_num_splitter(char: StringName):
	frame_num_splitter = char
	await _update_all()

#endregion

#region UPDATERS
## Loads the [member json_file] and gets frame data.
func _load_json() -> void:
	if !json_file: return
	if !json_file.data.has("frames"):
		printerr("Provided JSON file has no frame data!")
		return
	symbols.clear()
	frames.clear()
	var data: Dictionary = json_file.data
	for element: Variant in data.frames:
		var chunk: Dictionary
		var symbolName: String
		
		if data.frames is Dictionary:
			chunk = data.frames[element]
			symbolName = element
		
		if data.frames is Array:
			chunk = element
			symbolName = chunk["filename"]
		
		if split_frames:
			var reg: RegEx
			if is_adobe:
				reg = RegEx.create_from_string("(?<name>\\S*)\\d{4}")
			else:
				reg = RegEx.create_from_string("(?<name>\\S*)%s\\d*" % String(frame_num_splitter))
			var search := reg.search(symbolName)
			if search:
				symbolName = search.get_string("name")
		
		if !symbols.has(symbolName):
			symbols.append(symbolName)
		if !frames.has(symbolName):
			frames[symbolName] = PackedVector4Array([])
		
		frames[symbolName].append(rect2_to_vec4(Rect2(
			chunk.frame.x,
			chunk.frame.y,
			chunk.frame.w,
			chunk.frame.h,
		)))
	data_compiled.emit()

## Reloads the [member json_file] if changed.
func _update_json() -> void:
	if json_file: json_file = load(json_file.resource_path)

func _update_all():
	await _load_json()
	set_symbol(symbol)
	notify_property_list_changed()

#endregion

func _validate_property(property: Dictionary) -> void:
	match property.name:
		"symbol":
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(symbols)
		"frames_end_nums", "frame_behaviour":
			if !split_frames:
				property.usage = PROPERTY_USAGE_NO_EDITOR
		"atlas", "region":
			property.usage = PROPERTY_USAGE_NO_EDITOR
		"frame":
			if (frames && frames.get(StringName(symbol), []).size() == 1) || !split_frames:
				property.usage = PROPERTY_USAGE_NO_EDITOR

## Converts [Vector4] into [Rect2].
func vec4_to_rect2(vector: Vector4) -> Rect2:
	return Rect2(
		vector.x,
		vector.y,
		vector.z,
		vector.w,
	)

## Converts [Rect2] into [Vector4].
func rect2_to_vec4(rect: Rect2) -> Vector4:
	return Vector4(
		rect.position.x,
		rect.position.y,
		rect.size.x,
		rect.size.y
	)

## Returns an [AtlasTextureJSON] for the given [String] [param source_path] [memeber texture] path, set to the given [StringName] [param symbol_name] [memeber symbol] name.
static func get_symbol(source_path: String, symbol_name: StringName) -> AtlasTextureJSON:
	var sprite := AtlasTextureJSON.new()
	sprite.texture = load(source_path)
	sprite.set_symbol(symbol_name)
	
	return sprite
