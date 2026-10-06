class_name AIAssistedBuilder
extends Node3D

@export var builder_bridge: SceneBuilderBridge
@export var build_target_root: Node3D

const SYSTEM_PROMPT: String = """
You are an autonomous 3D level architect for a waterfront port scene.
Output ONLY raw JSON with no markdown wrapping or text explanation.
Valid asset_ids: ["dock_crane", "warehouse_brick", "shipping_container", "security_gate", "street_light"].
Schema:
{
  "commands": [
    {
      "asset_id": "string",
      "position": [float, float, float],
      "rotation_deg": [float, float, float],
      "scale": [float, float, float]
    }
  ]
}
"""

func request_auto_layout(user_instruction: String) -> void:
var payload: Dictionary = {
"model": "qwen2.5-coder:7b",
"messages": [
{"role": "system", "content": SYSTEM_PROMPT},
{"role": "user", "content": user_instruction}
],
"format": "json",
"stream": false
}

var http: HTTPRequest = HTTPRequest.new()
add_child(http)
var headers: PackedStringArray = ["Content-Type: application/json"]

var err: Error = http.request("http://127.0.0.1:11434/api/chat", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
if err != OK:
printerr("HTTP dispatch failed: ", err)
http.queue_free()
return

var result: Array = await http.request_completed
http.queue_free()

if result[1] == 200:
var response_body: String = (result[3] as PackedByteArray).get_string_from_utf8()
var res_json: Variant = JSON.parse_string(response_body)
if res_json and res_json.has("message") and res_json["message"].has("content"):
var generated_manifest: String = res_json["message"]["content"]
var target: Node3D = build_target_root if build_target_root else self
var placed: int = builder_bridge.execute_build_manifest(target, generated_manifest)
print("[BUILDER] Instanced objects count: ", placed)
