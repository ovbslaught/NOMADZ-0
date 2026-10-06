class_name SceneBuilderBridge
extends Node

signal build_completed(total_placed: int)

const ASSET_CATALOG: Dictionary = {
"dock_crane": "res://assets/norfolk/dock_crane.tscn",
"warehouse_brick": "res://assets/norfolk/warehouse_brick.tscn",
"shipping_container": "res://assets/props/shipping_container.tscn",
"security_gate": "res://assets/norfolk/security_gate.tscn",
"street_light": "res://assets/props/street_light.tscn"
}

func execute_build_manifest(parent_node: Node3D, manifest_json: String) -> int:
var parser: JSON = JSON.new()
if parser.parse(manifest_json) != OK:
printerr("JSON Parsing Error: ", parser.get_error_message())
return 0

var data: Variant = parser.get_data()
if not (data is Dictionary and data.has("commands")):
printerr("Invalid manifest structure: missing 'commands'")
return 0

var commands: Array = data["commands"]
var count: int = 0

for item: Variant in commands:
if not item is Dictionary:
continue

var asset_id: String = item.get("asset_id", "")
if not ASSET_CATALOG.has(asset_id):
continue

var scene_path: String = ASSET_CATALOG[asset_id]
if not ResourceLoader.exists(scene_path):
continue

var scene_res: PackedScene = load(scene_path)
var instance: Node3D = scene_res.instantiate() as Node3D
if not instance:
continue

var pos_arr: Array = item.get("position", [0.0, 0.0, 0.0])
var rot_arr: Array = item.get("rotation_deg", [0.0, 0.0, 0.0])

instance.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
instance.rotation_degrees = Vector3(rot_arr[0], rot_arr[1], rot_arr[2])

if item.has("scale"):
var sc: Array = item["scale"]
instance.scale = Vector3(sc[0], sc[1], sc[2])

parent_node.add_child(instance)
count += 1

emit_signal("build_completed", count)
return count
