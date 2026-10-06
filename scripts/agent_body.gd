extends CharacterBody3D

var server := TCPServer.new()
var client: StreamPeerTCP
var port: int = 11033
var spawn_position: Vector3

func _ready() -> void:
spawn_position = global_position
if server.listen(port) != OK:
printerr("NOMADZ-0: Failed to start server on port ", port)
else:
print("NOMADZ-0: TCP Server listening on port ", port)

func _physics_process(_delta: float) -> void:
if not client:
if server.is_connection_available():
client = server.take_connection()
print("NOMADZ-0: RL Client connected.")
else:
if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
_process_socket_communication()
else:
client = null
print("NOMADZ-0: RL Client disconnected.")

func _process_socket_communication() -> void:
while client.get_available_bytes() > 0:
var line = client.get_utf8_string(client.get_available_bytes())
for packet in line.split("\n"):
if packet.strip_edges().is_empty():
continue
var json_obj = JSON.parse_string(packet)
if json_obj is Dictionary:
if json_obj.get("cmd") == "reset":
_reset_agent()
elif json_obj.has("action"):
_apply_actions(json_obj["action"])
_send_state()

func _apply_actions(actions: Array) -> void:
velocity.x = float(actions[0]) * 5.0
velocity.z = float(actions[1]) * 5.0
move_and_slide()

func _reset_agent() -> void:
global_position = spawn_position
velocity = Vector3.ZERO
rotation = Vector3.ZERO

func _send_state() -> void:
var state = {
"position": [global_position.x, global_position.y, global_position.z],
"velocity": [velocity.x, velocity.y, velocity.z],
"rotation": rotation.y
}
var payload = JSON.stringify(state) + "\n"
client.put_data(payload.to_utf8_buffer())
