# NOMADZ-0 :: DroneSwarm.gd
# Kaela's microprobe fleet — 6 drones, target-follows IronSurfer
extends Node3D
class_name DroneSwarm

@export var drone_count: int = 6
@export var orbit_radius: float = 3.0

var drones: Array[RigidBody3D] = []
var swarm_target: Node3D = null
var _orbit_time: float = 0.0

func _ready() -> void:
	_spawn_drones()

func _process(delta: float) -> void:
	_orbit_time += delta
	if swarm_target:
		for i in drones.size():
			var angle := _orbit_time + (TAU / drones.size()) * i
			var offset := Vector3(cos(angle), sin(angle * 0.5) * 0.5, sin(angle)) * orbit_radius
			drones[i].global_position = drones[i].global_position.lerp(
				swarm_target.global_position + offset, delta * 4.0
			)

func _spawn_drones() -> void:
	for i in drone_count:
		var drone := RigidBody3D.new()
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.15
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission = Color(0.0, 1.0, 1.0)
		mat.emission_energy_multiplier = 2.0
		mesh.set_surface_override_material(0, mat)
		drone.add_child(mesh)
		add_child(drone)
		drones.append(drone)
		drone.global_position = global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))

func swarm_target_node(target: Node3D) -> void:
	swarm_target = target
