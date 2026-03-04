# CodexManager.gd - Hardened for NOMADZ-ARCHON-SECURITY-V4.0
extends Control

@export_group("Network")
@export var kernel_url: String = "http://localhost:8000"

@onready var telemetry_label = $MainContainer/TelemetryPanel/LogOutput
@onready var planet_info = $MainContainer/GeologosPanel/PlanetData
@onready var agent_status = $MainContainer/VulturePanel/AgentStatus
@onready var http_request = HTTPRequest.new() # Persistent node

func _ready():
	add_child(http_request)
	http_request.request_completed.connect(_on_telemetry_received)
	
	# Initial sync
	refresh_telemetry()
	
	# Optional: Auto-refresh every 5 seconds for live telemetry
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.autostart = true
	timer.timeout.connect(refresh_telemetry)
	add_child(timer)
	
func refresh_telemetry():
	# ASPP Check: Ensure we aren't already busy with a request
	if http_request.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		http_request.request(kernel_url + "/vulture/snapshot")

func _on_telemetry_received(_result, response_code, _headers, body):
	if response_code == 200:
		var json_string = body.get_string_from_utf8()
		var data = JSON.parse_string(json_string)
		
		if data is Dictionary:
			update_ui_elements(data)
		else:
			push_error("TELEMETRY_BREACH: Malformed JSON received.")
	else:
		agent_status.text = "VULTURE-AGENT: [OFFLINE]"

func update_ui_elements(data: Dictionary):
	# Updating the "Cortex" with Signal Sigma narrative style
	var coherence = data.get("coherence", "0.0")
	telemetry_label.text = "COHERENCE: %s%%" % [str(coherence)]
	
	var is_active = data.get("vulture_active", false)
	agent_status.text = "VULTURE-STATUS: " + ("◈ ACTIVE" if is_active else "◇ IDLE")
	
	if data.has("geologos"):
		var world = data.geologos.get("current_world", "Void")
		planet_info.text = "SURVEYING_GEOS: " + world.to_upper()
# CodexManager.gd
# The diegetic dashboard for Project VULTURE and Mother Brain telemetry.
extends Control

@export_group("Network")
@export var kernel_url: String = "http://localhost:8000" # Omega Kernel endpoint

@onready var telemetry_label = $MainContainer/TelemetryPanel/LogOutput
@onready var planet_info = $MainContainer/GeologosPanel/PlanetData
@onready var agent_status = $MainContainer/VulturePanel/AgentStatus

func _ready():
	# Initial sync with Mother Brain persistence report
	refresh_telemetry()
	
func refresh_telemetry():
	# Requesting the latest snapshot from vulture_snapshot.py via the Bridge
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_telemetry_received)
	http_request.request(kernel_url + "/vulture/snapshot")

func _on_telemetry_received(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		update_ui_elements(json)

func update_ui_elements(data: Dictionary):
	# Updating the "Cortex" dashboard
	telemetry_label.text = "COHERENCE: " + str(data.get("coherence", "0.0"))
	agent_status.text = "VULTURE-AGENT: " + ("ACTIVE" if data.get("vulture_active") else "IDLE")
	
	# If Geologos data is present, update the survey tab
	if data.has("geologos"):
		planet_info.text = "Surveying: " + data.geologos.get("current_world", "Unknown")
