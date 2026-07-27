extends MeshInstance3D

## NOMADZ VISOR HUD v1.0
## Retro-Future Helmet Overlay (Inside-Out)

@onready var state_label = $CanvasLayer/StateDisplay
@onready var health_bar = $CanvasLayer/HealthBar
@onready var player = get_owner()

func _process(_delta):
	# Update HUD based on current player state
	state_label.text = "MODE: " + str(player.State.keys()[player.current_state])
	
	# Pulse effect for the 'Cosmic Key' energy vertices
	var pulse = sin(Time.get_ticks_msec() * 0.005) * 0.1
	self.get_active_material(0).set_shader_parameter("glow_intensity", 1.0 + pulse)
