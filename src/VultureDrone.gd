extends Node
const GOSSIP_URL = "http://127.0.0.1:7331/gossip"
var http_request: HTTPRequest
func _ready():
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(self._on_gossip_completed)
func gossip_broadcast_packet(packet: Dictionary) -> void:
    var error = http_request.request(GOSSIP_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(packet))
func _on_gossip_completed(result, response_code, headers, body):
    if response_code == 200:
        print("VultureDrone [VCN-8]: Daemon acknowledged gossip block!")
