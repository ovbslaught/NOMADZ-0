extends Node

const GOSSIP_URL = "http://127.0.0.1:7331/gossip"

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._on_gossip_completed)

func gossip_broadcast(packet: Dictionary) -> void:
	var json_payload = JSON.stringify(packet)
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(
		GOSSIP_URL,
		headers,
		HTTPClient.METHOD_POST,
		json_payload
	)
	if error != OK:
		push_error("VultureDrone [VCN-8]: Failed to execute gossip broadcast. Error code: " + str(error))
	else:
		print("VultureDrone [VCN-8]: Emitting packet to " + GOSSIP_URL)

func _on_gossip_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var response = JSON.parse_string(body.get_string_from_utf8())
		if response is Dictionary:
			print("VultureDrone [VCN-8]: Daemon acknowledged gossip block at ts: ", response.get("recorded_ts", "Unknown"))
	else:
		push_warning("VultureDrone [VCN-8]: Gossip broadcast failed. Response code: " + str(response_code))
