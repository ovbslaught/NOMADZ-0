# NOMADZ-0 :: KaelaSilentEcho.gd
# Deaf Nomadz NPC — sonar gestures, drone swarm, cyber-hood
extends RigidBody3D
class_name KaelaNPC

@export var sonar_range: float = 50.0

@onready var hands: Node3D = $SuitArmsHands
@onready var drone_swarm: Node3D = $DroneSwarm
@onready var suit_glow: OmniLight3D = $SuitOmniLight
@onready var hood_mask: MeshInstance3D = $SuitHoodMask
@onready var cyber_arm: Node3D = $SuitRightArmMechClaw

signal sonar_ping(targets: Array)

func _ready() -> void:
	suit_glow.light_color = Color(0.0, 1.0, 1.0)  # Cyan
	_activate_sonar_cycle()

func _activate_sonar_cycle() -> void:
	while true:
		var heroes := _detect_nearby_heroes()
		emit_signal("sonar_ping", heroes)
		_animate_gesture("scan")
		suit_glow.light_energy = 3.0
		await get_tree().create_timer(2.0).timeout
		suit_glow.light_energy = 0.8

func _detect_nearby_heroes() -> Array:
	var heroes := []
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = sonar_range
	query.shape = sphere
	query.transform = Transform3D(Basis(), global_position)
	var results := space_state.intersect_shape(query, 32)
	for hit in results:
		if hit.collider.has_method("is_hero"):
			heroes.append(hit.collider)
			# Cyan glow ping on hero
			hit.collider.modulate = Color.CYAN
	return heroes

func _animate_gesture(gesture: String) -> void:
	var tween := create_tween()
	tween.tween_property(hands, "rotation_degrees:y", 45.0, 0.5)
	tween.tween_property(hands, "rotation_degrees:y", 0.0, 0.5)

func cyber_gesture() -> void:
	hood_mask.mesh.surface_get_material(0).emission_energy_multiplier = 2.0
	_animate_gesture("claw_scan")
