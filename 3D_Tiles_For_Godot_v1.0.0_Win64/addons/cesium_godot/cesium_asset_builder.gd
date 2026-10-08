extends Node

class_name CesiumAssetBuilder

enum TILESET_TYPE { Blank, OsmBuildings, GooglePhotorealistic, BingMapsAerial, BingMapsWithLabels }


const CESIUM_GLOBE_NAME = "CesiumGeoreference"
const CESIUM_GLOBE_GEOREF = "CesiumGeoreference"
const CESIUM_TILESET_NAME = "Cesium3DTileset"

var use_georeferences : bool

func instantiate_tileset(tileset_type: TILESET_TYPE) -> void:	
	# Create a new Globe
	var root : Node3D = self._get_root_of_edit_scene()
	var globe : CesiumGeoreference = self._find_or_create_globe()
	var tileset := Cesium3DTileset.new()
	globe.add_child(tileset)
	tileset.owner = globe.get_parent()
	
	tileset.cesiumConfig = self.cesiumConfig
	tileset.name = CESIUM_TILESET_NAME
	globe.global_rotation_degrees.x = -90
	tileset.rotation_degrees.x = 90

func instantiate_dynamic_cam() -> void:
	# Find an existing tileset
	var root : Node3D = self.get_tree().edited_scene_root
	var globe := self._find_or_create_globe()
	var camera : Camera3D = Camera3D.new()
	
	# We have to use set_script here instead of instantiating directly
	# Otherwise GD will try to run the input input functions in edit mode
	camera.set_script(GeoreferenceCameraController)	
	print("Created Cesium cam!")
	camera.globe_node = globe
	camera.tilesets = []
	camera.tilesets.append(globe.find_child(CESIUM_TILESET_NAME) as Cesium3DTileset)
	camera.near = 9
	camera.fov = 39
	if (camera.tilesets[0] == null):
		# Blank tileset as default instantiation
		self.instantiate_tileset(TILESET_TYPE.Blank)
	root.add_child(camera)
	camera.owner = root

func _add_overlay() -> void:
	pass

func _find_or_create_globe() -> CesiumGeoreference:
	var root : Node3D = self._get_root_of_edit_scene()
	# Try to find the globe
	var globe : CesiumGeoreference = null
	for child in root.get_children():
		var found_globe := child as CesiumGeoreference
		if found_globe != null: return found_globe
	print("Globe not found, creating one...")
	globe = CesiumGeoreference.new()
	globe.name = CESIUM_GLOBE_NAME		
	# Add it to the scene
	root.add_child(globe)
	globe.owner = root
	return globe

func _get_root_of_edit_scene() -> Node3D:
	var root : Node3D = self.get_tree().edited_scene_root
	return root
