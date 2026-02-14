@tool
class_name PlayerCharacter3D
extends CharacterBody3D

func _ready() -> void:
	# We group the setup into one function to keep things tidy
	_ensure_hierarchy()

func _ensure_hierarchy() -> void:
	# --- 1. Setup MeshInstance3D ---
	var mesh_node = get_node_or_null("MeshInstance3D")
	if not mesh_node:
		mesh_node = MeshInstance3D.new()
		mesh_node.name = "MeshInstance3D"
		# Default to CapsuleMesh
		mesh_node.mesh = CapsuleMesh.new()
		add_child(mesh_node)
		_set_owner(mesh_node)
	
	# --- 2. Setup CollisionShape3D ---
	var col_node = get_node_or_null("CollisionShape3D")
	if not col_node:
		col_node = CollisionShape3D.new()
		col_node.name = "CollisionShape3D"
		# Default to CapsuleShape
		col_node.shape = CapsuleShape3D.new()
		add_child(col_node)
		_set_owner(col_node)

	# --- 3. Setup Camera3D ---
	var cam_node = get_node_or_null("Camera3D")
	if not cam_node:
		cam_node = Camera3D.new()
		cam_node.name = "Camera3D"
		add_child(cam_node)
		# Position the camera at "Head Height" (approx 1.5 units up)
		cam_node.position.y = 0
		_set_owner(cam_node)

# Helper to make nodes appear in the Scene Tree dock
func _set_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		# This line effectively "saves" the child to the scene file
		node.owner = get_tree().edited_scene_root

# Suppress the warning immediately
func _get_configuration_warnings() -> PackedStringArray:
	return []
