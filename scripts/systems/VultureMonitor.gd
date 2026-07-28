extends Node

const GOSSIP_URL = "http://127.0.0.1:7331/gossip"
var http_request: HTTPRequest
var anomaly_threshold: float = 0.85
var check_timer: float = 0.0
var cooldown_timer: float = 0.0

func _ready() -> void:
    http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.request_completed.connect(self._on_gossip_completed)
    print("[VULTURE] VCN-8 Monitor Online. Watching for systemic drift...")

func _process(delta: float) -> void:
    if cooldown_timer > 0:
        cooldown_timer -= delta
        return
        
    check_timer += delta
    if check_timer >= 3.0: # Sweep the system every 3 seconds
        check_timer = 0.0
        scan_for_anomalies()

func scan_for_anomalies() -> void:
    var tension = 0.0
    if Engine.has_singleton("Director"):
        tension = Engine.get_singleton("Director").get_world_tension()
        
    # If tension or failure rate breaches the threshold, Vulture intervenes
    if tension >= anomaly_threshold:
        trigger_anomaly_protocol(tension)

func trigger_anomaly_protocol(tension: float) -> void:
    print("[VULTURE] CRITICAL ANOMALY DETECTED. Tension at: ", tension)
    cooldown_timer = 30.0 # Wait 30 seconds before another intervention
    
    # 1. Flash HUD (Fires a group call to the 2D UI Layer)
    get_tree().call_group("HUD", "flash_vulture_warning")
    
    # 2. Log to Termux Daemon / Mother-Brain
    gossip_broadcast_packet({
        "event_type": "chaos_threshold_breached",
        "tension_level": tension,
        "action_taken": "deploying_hunter_uap"
    })
    
    # 3. Spawn Hunter UAP (Placeholder for dynamic enemy injection)
    spawn_hunter_uap()

func gossip_broadcast_packet(payload: Dictionary) -> void:
    # Packages the event for the omegamemory.db SQLite WAL
    var packet = {
        "ts": Time.get_datetime_string_from_system(),
        "node": "NOMADZ-0-GODOT",
        "pillar": 8,
        "event": "anomaly_detected",
        "data": payload
    }
    
    var json_payload = JSON.stringify(packet)
    var headers = ["Content-Type: application/json"]
    
    # Fire and forget to the local Termux daemon
    var error = http_request.request(GOSSIP_URL, headers, HTTPClient.METHOD_POST, json_payload)
    if error != OK:
        push_error("[VULTURE] VCN-8 Failed to execute gossip broadcast. Error: " + str(error))

func _on_gossip_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
    if response_code == 200:
        print("[VULTURE] Termux daemon acknowledged gossip block. Written to omegamemory.db.")
    else:
        push_warning("[VULTURE] Gossip broadcast failed. Is the Python daemon running? Code: " + str(response_code))

func spawn_hunter_uap() -> void:
    print("[VULTURE] Deploying Hunter UAP to stabilize sector.")
    # Here you would load res://scenes/npcs/HunterUAP.tscn and add_child to the current scene
