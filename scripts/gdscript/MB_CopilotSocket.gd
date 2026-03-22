## MB_CopilotSocket.gd
## Mother-Brain WebSocket client for NOMADZ-0
## GDScript 4.x — attach to any Node in your scene tree.
##
## Signals:
##   response_chunk(token: String)      — emitted for each streamed token
##   response_complete(full_text: String) — emitted when LLM finishes
##   connection_changed(connected: bool) — emitted on connect / disconnect
##
## Usage:
##   var mb := $MB_CopilotSocket
##   mb.response_complete.connect(_on_mb_response)
##   mb.send_query("What is the current ERA status?")

extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

## Emitted for each token streamed from Mother-Brain.
signal response_chunk(token: String)

## Emitted when Mother-Brain finishes a full response.
signal response_complete(full_text: String)

## Emitted whenever the connection state changes.
signal connection_changed(connected: bool)

# ---------------------------------------------------------------------------
# Configuration (export so you can set in the Godot Inspector)
# ---------------------------------------------------------------------------

## WebSocket URL for the Mother-Brain copilot endpoint.
@export var mb_url: String = "ws://localhost:7421/ws/copilot"

## Seconds between reconnection attempts when disconnected.
@export var reconnect_interval: float = 5.0

## Maximum context chunks to request from Mother-Brain per query.
@export var context_limit: int = 5

## Print verbose debug output to the Godot console.
@export var verbose: bool = false

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _ws := WebSocketPeer.new()
var _connected: bool = false
var _reconnect_timer: float = 0.0
var _accumulated_text: String = ""
var _session_id: String = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_dbg("MB_CopilotSocket ready — connecting to %s" % mb_url)
	_connect_ws()


func _process(delta: float) -> void:
	_ws.poll()

	var state := _ws.get_ready_state()

	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				_reconnect_timer = 0.0
				_dbg("WebSocket connected")
				emit_signal("connection_changed", true)

			# Drain all available packets
			while _ws.get_available_packet_count() > 0:
				var raw_bytes := _ws.get_packet()
				var raw_text  := raw_bytes.get_string_from_utf8()
				_handle_message(raw_text)

		WebSocketPeer.STATE_CLOSED:
			if _connected:
				_connected = false
				_dbg("WebSocket disconnected — retrying in %.1fs" % reconnect_interval)
				emit_signal("connection_changed", false)

			# Count down and reconnect
			_reconnect_timer += delta
			if _reconnect_timer >= reconnect_interval:
				_reconnect_timer = 0.0
				_dbg("Attempting reconnect…")
				_connect_ws()

		WebSocketPeer.STATE_CONNECTING:
			pass  # Waiting — do nothing

		WebSocketPeer.STATE_CLOSING:
			pass  # Drain remaining packets then closed state fires

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Send a natural-language query to Mother-Brain.
## Tokens will be emitted via response_chunk; the full answer via response_complete.
func send_query(text: String) -> void:
	if not _connected:
		push_warning("MB_CopilotSocket: not connected — queuing not implemented, ignoring query.")
		return

	_accumulated_text = ""

	var payload := {
		"query":         text,
		"context_limit": context_limit,
	}

	var json_str := JSON.stringify(payload)
	_ws.send_text(json_str)
	_dbg("Sent query: %s" % text.left(120))


## Returns true if the WebSocket is currently open.
func is_connected_to_mb() -> bool:
	return _connected


## Gracefully close the WebSocket connection.
func disconnect_mb() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close(1000, "Client disconnect")

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _connect_ws() -> void:
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(mb_url)
	if err != OK:
		push_warning("MB_CopilotSocket: connect_to_url failed (error %d)" % err)


func _handle_message(raw: String) -> void:
	_dbg("← %s" % raw.left(200))

	var parse_result := JSON.parse_string(raw)
	if typeof(parse_result) != TYPE_DICTIONARY:
		push_warning("MB_CopilotSocket: non-JSON message received: %s" % raw.left(80))
		return

	var msg: Dictionary = parse_result

	match msg.get("type", ""):

		"connected":
			_session_id = str(msg.get("session", ""))
			_dbg("Session ID: %s" % _session_id)

		"ack":
			_dbg("Query acknowledged: %s" % str(msg.get("query", "")).left(60))

		"token":
			var token: String = str(msg.get("token", ""))
			_accumulated_text += token
			emit_signal("response_chunk", token)

		"complete":
			# Use the server's full text if provided, otherwise fall back to accumulated
			var full_text: String = str(msg.get("text", _accumulated_text))
			emit_signal("response_complete", full_text)
			_dbg("Response complete (%d chars)" % full_text.length())
			_accumulated_text = ""

		"error":
			var err_msg: String = str(msg.get("message", "Unknown error"))
			push_error("MB_CopilotSocket server error: %s" % err_msg)
			emit_signal("response_complete", "[Mother-Brain error: %s]" % err_msg)
			_accumulated_text = ""

		_:
			_dbg("Unhandled message type: %s" % str(msg.get("type", "?")))


func _dbg(msg: String) -> void:
	if verbose:
		print("[MB_CopilotSocket] ", msg)
