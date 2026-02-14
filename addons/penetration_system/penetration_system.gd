## Penetration System for Godot 4 - Advanced bullet physics with material properties
##MIT License
##
##Copyright (c) [2025] [Danila Yanchuk aka Lakamfo]
##
##Permission is hereby granted, free of charge, to any person obtaining a copy
##of this software and associated documentation files (the "Software"), to deal
##in the Software without restriction, including without limitation the rights
##to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
##copies of the Software, and to permit persons to whom the Software is
##furnished to do so, subject to the following conditions:
##
##The above copyright notice and this permission notice shall be included in all
##copies or substantial portions of the Software.
##
##THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
##IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
##FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
##AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
##LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
##OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
##SOFTWARE.

# NOTE: Add this script as singleton 

@icon("res://addons/penetration_system/icon.png")
extends StaticBody3D
class_name PenetrationSystem

## Enable to print penetration debug info to console.
## Warning: Debug output reduces performance by ~=50%, disable in release.
@export var debug_output: bool = false  # Enable/disable debug prints
@export var debug_draw: bool = false  # Enable/disable debug draw

@export_flags_3d_physics var _collision_mask = 1

@export var base_damage: float = 10.0
@export var max_distance: float = 5.0
@export var bullet_power : float = 1.0
@export var max_penetrations: int = 4
@export var min_damage_threshold: float = 0.1  # Stop if damage falls below this value

@export var penetration_data = {
	&"wood": {
		&"max_thickness": 0.6, # Maximum penetration thickness of one object
		&"damage_multiplier": 0.8, # Base Penetration Damage Multiplier
		&"penetration_cost": 0.5 # Hardness of the material, how much the bullet's force and damage will decrease after penetration
	},
	&"metal": {
		&"max_thickness": 0.1,
		&"damage_multiplier": 0.3,
		&"penetration_cost": 3.0
	},
	&"concrete": {
		&"max_thickness": 0.3,
		&"damage_multiplier": 0.5,
		&"penetration_cost": 1.0
	}
}

var exclude_bodies : Array[RID]

func setup_bullet_params(p_base_damage: float = 20.0, p_max_distance: float = 20.0, p_bullet_power: float = 1.0, p_max_penetrations: int = 3, p_min_damage: float = 0.1):
	base_damage = p_base_damage; max_distance = p_max_distance
	bullet_power = p_bullet_power; max_penetrations = p_max_penetrations
	min_damage_threshold = p_min_damage

func fire_bullet(origin: Vector3, direction: Vector3, p_max_penetrations: int, _penetration_data: Dictionary) -> Array[HitResult]:
	var bullet_direction: Vector3 = direction.normalized()
	var hits : Array[HitResult]
	
	# Use dictionary to track damaged collisions instead of RID
	var hit_collisions: Dictionary[int, bool] = {}  # Key: collision_id, Value: true
	
	_fire_penetration_ray(
		origin,
		bullet_direction,
		p_max_penetrations,
		base_damage,
		0.0,
		hit_collisions,
		bullet_power,
		_penetration_data,
		hits,
		0
	)
	
	return hits

func _fire_penetration_ray(
	origin: Vector3,
	direction: Vector3,
	remaining_penetrations: int,
	current_damage: float,
	traveled_distance: float,
	hit_collisions: Dictionary,
	remaining_power: float,
	_penetration_data: Dictionary,
	hits: Array[HitResult],
	penetration_index: int
) -> void:
	# Check if damage is critically low - stop the ray
	if current_damage <= min_damage_threshold:
		if debug_output:
			print("Ray stopped: damage too low (%.3f <= %.3f)" % [current_damage, min_damage_threshold])
		return
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	if remaining_penetrations < 0 or traveled_distance >= max_distance or remaining_power <= 0:
		if debug_output:
			print("Result: penetrations %d, damage %.1f, distance %.1f, remaining power: %.3f" % 
				  [max_penetrations - remaining_penetrations, current_damage, traveled_distance, remaining_power])
		return
	
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction * (max_distance - traveled_distance)
	)
	query.exclude = exclude_bodies
	query.collision_mask = _collision_mask
	
	# HACK: RID sucks with multiple collision shapes on one object
	# Don't use exclude (except player or other body)(RID) - filter results instead
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		if debug_output:
			print("Result: penetrations %d, damage %.1f, distance %.1f, remaining power: %.3f" % 
				  [max_penetrations - remaining_penetrations, current_damage, traveled_distance, remaining_power])
		return
	
	var hit_position: Vector3 = result.position
	var collider: Node = result.collider
	var normal: Vector3 = result.normal
	var hit_rid: RID = result.rid
	var collision_id: int = _get_fast_collision_id(result)
	
	# Check if we've already hit this specific collision
	if hit_collisions.has(collision_id):
		# Already hit this collision - skip and continue with small offset
		var s_distance_to_hit: float = origin.distance_to(hit_position)
		var s_new_traveled_distance = traveled_distance + s_distance_to_hit
		var new_origin = hit_position + direction * 0.1  # Move further
		
		_fire_penetration_ray(new_origin, direction, remaining_penetrations,
							current_damage, s_new_traveled_distance, hit_collisions, 
							remaining_power, _penetration_data, hits, penetration_index)
		return
	
	# Mark this collision as processed
	hit_collisions[collision_id] = true
	
	var distance_to_hit: float = origin.distance_to(hit_position)
	var new_traveled_distance = traveled_distance + distance_to_hit
	
	# NOTE: Change to your material detection algorithm if you don't use meta-data
	# Determine material
	var material_type: StringName = &"wood"
	if collider.has_meta(&"material"):
		material_type = collider.get_meta(&"material")
	elif collider is RigidBody3D:
		material_type = &"metal" if collider.mass > 50.0 else &"wood"
	
	var penetration_info: Dictionary = _penetration_data.get(material_type, {
		&"max_thickness": 0.3,
		&"damage_multiplier": 0.5,
		&"penetration_cost": 1.0
	})
	
	# Calculate thickness-based damage reduction
	var thickness_adjusted_damage = current_damage
	var thickness: float = 0.0
	var reverse_hit: Dictionary = {}  # Initialize reverse_hit
	var exit_position: Vector3 = Vector3.ZERO  # Initialize exit_position
	
	# Check if we can determine thickness for damage calculation
	var forward_check_point: Vector3 = hit_position + direction * penetration_info.max_thickness
	var forward_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(hit_position, forward_check_point)
	forward_query.exclude = exclude_bodies
	forward_query.collision_mask = _collision_mask
	
	var forward_hit = space_state.intersect_ray(forward_query)
	
	# Filter forward_hit result to avoid repeated collision with same object
	if forward_hit:
		var forward_collision_id = _get_fast_collision_id(forward_hit)
		if hit_collisions.has(forward_collision_id):
			forward_hit = {}  # Ignore if we've already hit this collision
	
	if forward_hit.is_empty():
		# Check thickness with reverse ray
		var reverse_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(forward_check_point, hit_position)
		reverse_query.exclude = exclude_bodies
		reverse_query.collision_mask = _collision_mask
		reverse_hit = space_state.intersect_ray(reverse_query)  # Assign to the declared variable
		if reverse_hit:
			var reverse_collision_id = _get_fast_collision_id(reverse_hit)
			if hit_collisions.has(reverse_collision_id):
				reverse_hit = {}  # Ignore if we've already hit
		
		if reverse_hit and reverse_hit.get(&"rid", RID()) == hit_rid:
			exit_position = reverse_hit.position  # Assign to the declared variable
			thickness = exit_position.distance_to(hit_position)
			thickness_adjusted_damage = current_damage * _calculate_thickness_damage(thickness, penetration_info, remaining_power)
		
		hits.append(
			HitResult.new(
				hit_position,
				normal,
				collider,
				current_damage,
				penetration_index,
				material_type,
				traveled_distance,
				remaining_power
			))
	
	# Apply damage with thickness consideration
	apply_damage(collider, thickness_adjusted_damage, hit_position)
	draw_ray(origin, hit_position)
	
	if remaining_penetrations <= 0:
		if debug_output:
			print("Result: penetrations %d, damage %.1f, distance %.1f, remaining power: %.3f" % 
				  [max_penetrations - remaining_penetrations, thickness_adjusted_damage, new_traveled_distance, remaining_power])
		return
	
	# Penetration check (without RID exclusion)
	var effective_max_thickness = penetration_info.max_thickness * (remaining_power / penetration_info.penetration_cost)
	var current_max_thickness = min(penetration_info.max_thickness, effective_max_thickness)
	
	if forward_hit.is_empty():
		if reverse_hit and reverse_hit.get(&"rid", RID()) == hit_rid:
			if thickness <= current_max_thickness:
				# Successful penetration
				var penetration_cost: float = (thickness / penetration_info.max_thickness) * penetration_info.penetration_cost
				var new_remaining_power = remaining_power - penetration_cost
				var new_damage = thickness_adjusted_damage * penetration_info.damage_multiplier
				
				# Check if damage after penetration is too low
				if new_damage <= min_damage_threshold:
					if debug_output:
						print("Penetration stopped: damage too low after penetration (%.3f)" % new_damage)
					return
				
				var new_penetrations = remaining_penetrations - 1
				var new_traveled = new_traveled_distance + thickness
				
				var new_hit_collisions = hit_collisions.duplicate()
				
				_fire_penetration_ray(exit_position + direction * 0.01, direction, new_penetrations,
									new_damage, new_traveled, new_hit_collisions, new_remaining_power, _penetration_data, hits, penetration_index + 1)
				return
	
	# Check scenario with object ahead
	if forward_hit and forward_hit.get(&"rid", RID()) != hit_rid:
		var thickness_to_next_object = hit_position.distance_to(forward_hit.position)
		
		if thickness_to_next_object <= current_max_thickness:
			var thickness_damage_multiplier = _calculate_thickness_damage(thickness_to_next_object, penetration_info, remaining_power)
			var partial_thickness_adjusted_damage = current_damage * thickness_damage_multiplier
			
			var penetration_cost = (thickness_to_next_object / penetration_info.max_thickness) * penetration_info.penetration_cost
			var new_remaining_power = remaining_power - penetration_cost
			var new_damage = partial_thickness_adjusted_damage * penetration_info.damage_multiplier
			
			# Check if damage after penetration is too low
			if new_damage <= min_damage_threshold:
				if debug_output:
					print("Penetration stopped: damage too low after penetration (%.3f)" % new_damage)
				return
			
			var new_penetrations = remaining_penetrations - 1
			var new_traveled = new_traveled_distance + thickness_to_next_object
			
			var new_hit_collisions = hit_collisions.duplicate()
			
			# Apply damage to object ahead
			apply_damage(forward_hit.collider, new_damage, forward_hit.position)
			new_hit_collisions[_get_fast_collision_id(forward_hit)] = true
			
			_fire_penetration_ray(forward_hit.position + direction * 0.01, direction, new_penetrations,
								new_damage, new_traveled, new_hit_collisions, new_remaining_power, _penetration_data, hits, penetration_index + 1)
			return
	
	if debug_output:
		print("Result: penetrations %d, damage %.1f, distance %.1f, remaining power: %.3f" % 
			  [max_penetrations - remaining_penetrations, thickness_adjusted_damage, new_traveled_distance, remaining_power])

# Create unique ID for collision based on position and RID
func _get_fast_collision_id(collision_result: Dictionary) -> int:
	var pos: Vector3 = collision_result.position
	# Quantize position to 1mm for grouping close collisions
	var quantized_pos = Vector3i(pos * 1000.0)
	var rid_id = collision_result.rid.get_id()
	
	return hash(quantized_pos.x ^ quantized_pos.y ^ quantized_pos.z ^ rid_id)

static func get_raycast_global_direction(p_ray_cast_3d : RayCast3D) -> Vector3:
	# Global direction in global coordinates
	var global_start = p_ray_cast_3d.global_position
	var global_end = p_ray_cast_3d.global_position + p_ray_cast_3d.global_transform.basis * p_ray_cast_3d.target_position
	
	return (global_end - global_start).normalized()

func apply_damage(collider: Object, damage: float, hit_position: Vector3) -> void:
	# NOTE: Customize this function for your project
	if damage <= min_damage_threshold:
		return  # Skip damage application if it's too low
	
	if collider.has_method("take_damage"):
		collider.take_damage(damage, hit_position)
	elif collider is RigidBody3D:
		var impulse_dir = (hit_position - collider.global_transform.origin).normalized()
		collider.apply_impulse(impulse_dir * damage * 0.05, hit_position)

# Calculate damage multiplier based on material thickness, hardness and bullet power
func _calculate_thickness_damage(thickness: float, penetration_info: Dictionary, bullet_power: float = 1.0) -> float:
	# Calculate maximum effective penetration thickness considering bullet power
	# More powerful bullets can penetrate thicker materials
	var max_effective_thickness = penetration_info.max_thickness * bullet_power

	# Thickness ratio: 0.0 (very thin) - 1.0 (maximum penetrable thickness)
	var thickness_ratio = thickness / max_effective_thickness
	
	# Adjust material hardness based on bullet power
	# Powerful bullets penetrate hard materials more easily
	var adjusted_hardness = penetration_info.penetration_cost / (bullet_power * 0.7 + 0.3)
	
	# Calculate final damage multiplier:
	# - Thicker materials and higher hardness cause more damage loss
	# - More powerful bullets reduce damage loss
	var damage_multiplier = 1.0 - (thickness_ratio * adjusted_hardness * 0.3)

	# Clamp multiplier to reasonable values (10%-100%)
	return clamp(damage_multiplier, 0.1, 1.0)

func draw_ray(_from: Vector3, _to: Vector3, _color: Color = Color.RED) -> void:
	if not debug_draw:
		return
	
	# NOTE: if you wanna look how it works, download Debug Draw 3D in asset library
	# and uncomment this block
	# NOTE: Remove if not needed and don`t want to bring Debug Draw 3D to project
	
	#var _transform := Transform3D(Basis(), _to).scaled_local(Vector3(0.05, 0.05, 0.05))
	#DebugDraw3D.draw_sphere_xf(_transform, _color, 5.0)
	#DebugDraw3D.draw_line(_from, _to, _color, 5.0)
	pass
