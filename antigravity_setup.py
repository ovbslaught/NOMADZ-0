import os

scripts_dir = os.path.expanduser("~/NOMADZ-0/src")
project_file = os.path.expanduser("~/NOMADZ-0/project.godot")
os.makedirs(scripts_dir, exist_ok=True)

with open(os.path.join(scripts_dir, "VultureDrone.gd"), "w") as f:
    f.write("""extends Node
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
""")

with open(os.path.join(scripts_dir, "GameCoordinator.gd"), "w") as f:
    f.write("""extends Node
func emit_civ_event(event_type: String, payload: Dictionary) -> void:
    var packet = {"ts": Time.get_datetime_string_from_system(), "node": "NOMADZ-0-GODOT", "pillar": 8, "event": event_type, "data": payload}
    VultureDrone.gossip_broadcast_packet(packet)
""")

if os.path.exists(project_file):
    with open(project_file, "r") as f:
        c = f.read()
    
    if "[autoload]" not in c:
        c += chr(10) + "[autoload]" + chr(10)
        
    if "VultureDrone=" not in c:
        c = c.replace("[autoload]", "[autoload]" + chr(10) + 'VultureDrone="*res://src/VultureDrone.gd"')
        
    if "GameCoordinator=" not in c:
        c = c.replace("[autoload]", "[autoload]" + chr(10) + 'GameCoordinator="*res://src/GameCoordinator.gd"')
        
    with open(project_file, "w") as f:
        f.write(c)
    print("[*] Wired project.godot successfully")

print("[*] DONE")
