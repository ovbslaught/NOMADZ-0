extends Node

@export var endpoint_url: String = "http://127.0.0.1:7421/gossip"
var http: HTTPRequest

func _ready() -> void:
    http = HTTPRequest.new()
    add_child(http)

func emit_civ_event(event_type: String, payload: Dictionary) -> void:
    var packet = {
        "ts": Time.get_datetime_string_from_system(),
        "node": "NOMADZ-0-GODOT",
        "event": event_type,
        "data": payload
    }
    var json_payload = JSON.stringify(packet)
    var headers = ["Content-Type: application/json"]
    http.request(endpoint_url, headers, HTTPClient.METHOD_POST, json_payload)
