@tool
extends EditorScript

func _run() -> void:
var root: Node3D = Node3D.new()
root.name = "StarterLevel"

var env: WorldEnvironment = WorldEnvironment.new()
env.name = "WorldEnvironment"
root.add_child(env)
env.owner = root

var light: DirectionalLight3D = DirectionalLight3D.new()
light.name = "DirectionalLight3D"
light.position = Vector3(0, 10, 0)
light.rotation_degrees = Vector3(-45, 45, 0)
light.shadow_enabled = true
root.add_child(light)
light.owner = root

var floor_body: StaticBody3D = StaticBody3D.new()
floor_body.name = "Floor"
var floor_mesh: MeshInstance3D = MeshInstance3D.new()
var box: BoxMesh = BoxMesh.new()
box.size = Vector3(30, 0.5, 30)
floor_mesh.mesh = box
floor_body.add_child(floor_mesh)
floor_mesh.owner = root

var floor_col: CollisionShape3D = CollisionShape3D.new()
var shape: BoxShape3D = BoxShape3D.new()
shape.size = Vector3(30, 0.5, 30)
floor_col.shape = shape
floor_body.add_child(floor_col)
floor_col.owner = root

root.add_child(floor_body)
floor_body.owner = root

var player_path: String = "res://addons/cogito/PackedScenes/cogito_player.tscn"
if ResourceLoader.exists(player_path):
var player_scene: PackedScene = load(player_path)
var player: Node3D = player_scene.instantiate()
player.name = "CogitoPlayer"
player.position = Vector3(0, 1, 0)
root.add_child(player)
player.owner = root

var packed: PackedScene = PackedScene.new()
if packed.pack(root) == OK:
var dir: DirAccess = DirAccess.open("res://")
if not dir.dir_exists("scenes"):
dir.make_dir("scenes")
ResourceSaver.save(packed, "res://scenes/StarterLevel.tscn")
print("[COGITO] Scene saved to res://scenes/StarterLevel.tscn")
