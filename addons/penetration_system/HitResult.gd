extends RefCounted
class_name HitResult

var position: Vector3
var normal: Vector3
var collider: Object
var damage: float
var penetration_index: int = 0
var material: StringName
var traveled_distance: float
var remaining_power: float

func _init(
	p_position: Vector3,
	p_normal: Vector3,
	p_collider: Object,
	p_damage: float,
	p_penetration_index: int,
	p_material: StringName,
	p_traveled_distance: float,
	p_remaining_power: float
):
	position = p_position
	normal = p_normal
	collider = p_collider
	damage = p_damage
	penetration_index = p_penetration_index
	material = p_material
	traveled_distance = p_traveled_distance
	remaining_power = p_remaining_power
