# VultureDrone.gd - Tactical Resource & Biome Logic
extends "res://scripts/core/DroneBase.gd"

@onready var sensor_array = $SensorArray
@onready var logic_chain = get_node("/root/ConsciousnessChain")

var current_biome = "crystalline_desert"
var scan_cooldown = 2.0
var resonance_threshold = 0.85

func _ready():
	print("VultureDrone initialized. Consciousness-Chain link: ACTIVE.")
	# Register drone to the Mother-Brain registry
	Registry.register_unit(self, "VULTURE-TACTICAL")

func _process(delta):
	if sensor_array.is_colliding():
		var target = sensor_array.get_collider()
		if target.has_method("get_resource_type"):
			_process_resource(target)

func _process_resource(node):
	var type = node.get_resource_type()
	if type == "Crystal" and current_biome == "crystalline_desert":
		# Trigger visual shimmer via RetroFilter
		GlobalVisuals.trigger_glitch_effect(0.5)
		_emit_chain_update("RECLAMATION_LOG", {"target": node.name, "status": "EXTRACTED"})
		node.queue_free()

func _emit_chain_update(event_type: String, data: Dictionary):
	# Push tactical event to the OMEGA Vulture-Brain substrate
	var block_data = {
		"type": event_type,
		"payload": data,
		"timestamp": Time.get_datetime_dict_from_system()
	}
	logic_chain.propose_block(block_data)

# Biome Transition Hook
func on_biome_entered(biome_name):
	current_biome = biome_name
	match biome_name:
		"crystalline_desert":
			sensor_array.resonance_mode = true
			VisualServer.set_default_clear_color(Color("0a0a12")) # Deep space palette
