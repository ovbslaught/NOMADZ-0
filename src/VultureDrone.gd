extends Node

var socket = WebSocketPeer.new()
const VIBE_URL = "ws://127.0.0.1:7331"

func _ready():
    socket.connect_to_url(VIBE_URL)
    print("[VCN8] Initiating vortex connection to Termux...")

func _process(delta):
    socket.poll()
    var state = socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        while socket.get_available_packet_count() > 0:
            var packet = socket.get_packet().get_string_from_utf8()
            _handle_incoming_command(packet)
    elif state == WebSocketPeer.STATE_CLOSED:
        var code = socket.get_close_code()
        var reason = socket.get_close_reason()
        print("[VCN8] Vortex Closed ", code, ", reason: ", reason)
        set_process(false) # Stop polling if closed

func gossip_broadcast_packet(payload: Dictionary) -> void:
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(payload))
    else:
        print("[VCN8] Cannot broadcast; vortex is not open.")

func _handle_incoming_command(raw_json: String) -> void:
    var parsed = JSON.parse_string(raw_json)
    if parsed typeof Dictionary and parsed.has("command"):
        print("[GODOT-RECEIVED] Termux Ordered: ", parsedX"command"])
        if parsedX"command"] == "spawn_particles":
            print(" -> Spawning Particles with data: ", parsedX"data"])