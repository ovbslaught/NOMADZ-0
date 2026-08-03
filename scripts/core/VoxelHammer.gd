extends Node3D
class_name VoxelHammer

@export var chunk_size: int = 32
@export var voxel_size: float = 1.0
@export var height_scale: float = 6.0

var noise: FastNoiseLite
var multi_mesh_inst: MultiMeshInstance3D

func _ready() -> void:
    noise = FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.seed = randi()
    
    setup_multimesh()
    generate_chunk()

func setup_multimesh() -> void:
    multi_mesh_inst = MultiMeshInstance3D.new()
    add_child(multi_mesh_inst)
    
    var mesh = BoxMesh.new()
    mesh.size = Vector3(voxel_size, voxel_size, voxel_size)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.15, 0.45, 0.2) # Proto-grass green
    mesh.material = mat
    
    multi_mesh_inst.multimesh = MultiMesh.new()
    multi_mesh_inst.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multi_mesh_inst.multimesh.instance_count = chunk_size * chunk_size

func generate_chunk() -> void:
    var index = 0
    for x in range(chunk_size):
        for z in range(chunk_size):
            # Sample procedural noise
            var y_noise = noise.get_noise_2d(x * 5.0, z * 5.0)
            var y = int((y_noise + 1.0) * 0.5 * height_scale)
            var pos = Vector3(x * voxel_size, y * voxel_size, z * voxel_size)
            
            # Position the mesh instance (very fast render)
            multi_mesh_inst.multimesh.set_instance_transform(index, Transform3D(Basis(), pos))
            index += 1
            
            # Add a collision block so the Player can walk
            var static_body = StaticBody3D.new()
            var col = CollisionShape3D.new()
            var shape = BoxShape3D.new()
            shape.size = Vector3(voxel_size, voxel_size, voxel_size)
            col.shape = shape
            static_body.add_child(col)
            static_body.position = pos
            add_child(static_body)
