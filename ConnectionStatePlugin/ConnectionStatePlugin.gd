#
# © 2025-present https://github.com/cengiz-pz
#

@tool
extends EditorPlugin


const PLUGIN_NODE_TYPE_NAME = "ConnectionState"
const PLUGIN_PARENT_NODE_TYPE = "Node"
const PLUGIN_NAME: String = "ConnectionStatePlugin"
const ANDROID_DEPENDENCIES: Array = [ "androidx.appcompat:appcompat:1.7.1" ]
const IOS_PLATFORM_VERSION: String = "14.3"
const IOS_FRAMEWORKS: Array = [ "Foundation.framework", "Network.framework" ]
const IOS_EMBEDDED_FRAMEWORKS: Array = [  ]
const IOS_LINKER_FLAGS: Array = [ "-ObjC" ]


var android_export_plugin: AndroidExportPlugin
var ios_export_plugin: IosExportPlugin


func _enter_tree() -> void:
	add_custom_type(PLUGIN_NODE_TYPE_NAME, PLUGIN_PARENT_NODE_TYPE, preload("%s.gd" % PLUGIN_NODE_TYPE_NAME), preload("icon.png"))
	android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(android_export_plugin)
	ios_export_plugin = IosExportPlugin.new()
	add_export_plugin(ios_export_plugin)


func _exit_tree() -> void:
	remove_custom_type(PLUGIN_NODE_TYPE_NAME)
	remove_export_plugin(android_export_plugin)
	android_export_plugin = null
	remove_export_plugin(ios_export_plugin)
	ios_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = PLUGIN_NAME


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["%s/bin/debug/%s-debug.aar" % [_plugin_name, _plugin_name]])
		else:
			return PackedStringArray(["%s/bin/release/%s-release.aar" % [_plugin_name, _plugin_name]])


	func _get_name() -> String:
		return _plugin_name


	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(ANDROID_DEPENDENCIES)


class IosExportPlugin extends EditorExportPlugin:
	var _plugin_name = PLUGIN_NAME


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformIOS


	func _get_name() -> String:
		return _plugin_name


	func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if _supports_platform(get_export_platform()):
			for __framework in IOS_FRAMEWORKS:
				add_apple_embedded_platform_framework(__framework)

			for __framework in IOS_EMBEDDED_FRAMEWORKS:
				add_apple_embedded_platform_embedded_framework(__framework)

			for __flag in IOS_LINKER_FLAGS:
				add_apple_embedded_platform_linker_flags(__flag)
