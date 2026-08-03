extends Node
func emit_civ_event(event_type: String, payload: Dictionary) -> void:
    var packet = {"ts": Time.get_datetime_string_from_system(), "node": "NOMADZ-0-GODOT", "pillar": 8, "event": event_type, "data": payload}
    VultureDrone.gossip_broadcast_packet(packet)
