extends CharacterBody3D
class_name VultureRLAgent

## Tension Thresholds matching Director signals
const TENSION_PATROL_MAX: float = 0.3
const TENSION_ESCORT_MAX: float = 0.7

## Swarm & Flight Parameters
@export_group("Flight Tuning")
@export var base_speed: float = 14.0
@export var sprint_speed: float = 22.0
@export var accel: float = 8.0
@export var rotation_speed: float = 10.0
@export var hover_amplitude: float = 0.4
@export var hover_frequency: float = 2.5
@export var flock_separation_radius: float = 2.5
@export var separation_weight: float = 1.6

@export_group("Data & Sync")
@export var vulture_data_path: String = "res://data/swarm/vultureexport.json"
@export var agent_index: int = 0
@export var dynamic_tension: bool = true

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var plasma_particles: GPUParticles3D = get_node_or_null("PlasmaThrusters")

var target_position: Vector3 = Vector3.ZERO
var hover_time: float = 0.0
var target_yaw: float = 0.0
var player_ref: Node3D = null

enum SwarmMode {
	PATROL,   # Loose circular orbit (Tension < 0.3)
	ESCORT,   # Tight diamond / flank formation relative to player facing (Tension 0.3 - 0.7)
	DEFEND    # Interlocking forward shield / wall facing target (Tension > 0.7)
}

var current_mode: SwarmMode = SwarmMode.ESCORT

func _ready() -> void:
	add_to_group("vulture_swarm")
	hover_time = agent_index * 0.75 # Phase offset per drone
	
	# Connect to world director tension bus if available
	if Engine.has_singleton("Director") or get_node_or_null("/root/Director"):
		var director = get_node_or_null("/root/Director")
		if director and director.has_signal("worldtensionchanged"):
			director.worldtensionchanged.connect(_on_world_tension_changed)
			_on_world_tension_changed(director.worldtension)
	
	_resolve_player()

func _resolve_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_ref = players[0]

func _on_world_tension_changed(new_tension: float) -> void:
	if not dynamic_tension:
		return
	
	if new_tension < TENSION_PATROL_MAX:
		current_mode = SwarmMode.PATROL
	elif new_tension <= TENSION_ESCORT_MAX:
		current_mode = SwarmMode.ESCORT
	else:
		current_mode = SwarmMode.DEFEND
	
	_update_vfx_intensity(new_tension)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		_resolve_player()
		if not player_ref:
			return

	hover_time += delta
	var target_dest: Vector3 = _compute_formation_slot()
	var separation_vector: Vector3 = _compute_swarm_separation()
	
	# Blend slot target with avoidance steering
	var desired_pos = target_dest + separation_vector
	var move_vector = desired_pos - global_position
	
	var desired_speed = sprint_speed if current_mode == SwarmMode.DEFEND else base_speed
	var target_vel = move_vector.normalized() * min(move_vector.length() * 4.0, desired_speed)
	
	velocity = velocity.lerp(target_vel, accel * delta)
	move_and_slide()
	
	_orient_agent(delta)

func _compute_formation_slot() -> Vector3:
	var player_pos = player_ref.global_position
	var p_forward = -player_ref.global_transform.basis.z.normalized()
	var p_right = player_ref.global_transform.basis.x.normalized()
	var p_up = Vector3.UP
	
	var vertical_bob = sin(hover_time * hover_frequency) * hover_amplitude
	
	match current_mode:
		SwarmMode.PATROL:
			var orbit_radius = 9.0
			var angle = (hover_time * 0.8) + (agent_index * (TAU / 6.0))
			var orbit_offset = Vector3(cos(angle) * orbit_radius, 3.5 + vertical_bob, sin(angle) * orbit_radius)
			return player_pos + orbit_offset
			
		SwarmMode.ESCORT:
			var slot_offset = Vector3.ZERO
			match agent_index % 4:
				0:
					slot_offset = (-p_right * 3.8) + (-p_forward * 2.5) + (p_up * 1.8)
				1:
					slot_offset = (p_right * 3.8) + (-p_forward * 2.5) + (p_up * 1.8)
				2:
					slot_offset = (-p_forward * 4.5) + (p_up * 3.2)
				3:
					slot_offset = (p_forward * 4.0) + (p_up * 1.4)
			return player_pos + slot_offset + Vector3(0, vertical_bob, 0)
			
		SwarmMode.DEFEND:
			var spread_x = (agent_index - 1.5) * 2.2
			var shield_offset = (p_forward * 3.2) + (p_right * spread_x) + (p_up * (1.2 + vertical_bob * 0.5))
			return player_pos + shield_offset
			
	return player_pos

func _compute_swarm_separation() -> Vector3:
	var push = Vector3.ZERO
	var swarm = get_tree().get_nodes_in_group("vulture_swarm")
	for drone in swarm:
		if drone == self or not is_instance_valid(drone):
			continue
		var dist = global_position.distance_to(drone.global_position)
		if dist < flock_separation_radius and dist > 0.001:
			var diff = global_position - drone.global_position
			push += (diff.normalized() / dist) * separation_weight
	return push

func _orient_agent(delta: float) -> void:
	var facing_dir = velocity.normalized()
	if current_mode == SwarmMode.DEFEND and is_instance_valid(player_ref):
		facing_dir = -player_ref.global_transform.basis.z.normalized()
		
	if facing_dir.length_squared() > 0.01:
		target_yaw = atan2(-facing_dir.x, -facing_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
		
		var lateral_speed = transform.basis.x.dot(velocity)
		var target_roll = clamp(-lateral_speed * 0.04, -0.45, 0.45)
		rotation.z = lerp(rotation.z, target_roll, 8.0 * delta)

func _update_vfx_intensity(tension: float) -> void:
	if mesh_instance and mesh_instance.get_surface_override_material(0):
		var mat = mesh_instance.get_surface_override_material(0)
		if mat is StandardMaterial3D:
			mat.emission_energy_multiplier = lerp(1.2, 3.8, tension)
	
	if plasma_particles:
		plasma_particles.amount_ratio = clamp(0.4 + tension * 0.6, 0.4, 1.0)
