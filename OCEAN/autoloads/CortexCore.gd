extends Node
# CORTEX CORE: The Central Processing Unit of the NOMADZ System

var master_data = {
	"world_state": {
		"integrity": 1.0,
		"entropy": 0.0
	},
	"system_meta": {
		"status": "BOOTING",
		"version": "OMEGA-1.0"
	}
}

func _ready():
	print("[CORTEX] Neural Link Established.")

func update_integrity(value: float):
	master_data.world_state.integrity = clamp(value, 0.0, 1.0)
	print("[CORTEX] Integrity adjusted to: ", master_data.world_state.integrity)
