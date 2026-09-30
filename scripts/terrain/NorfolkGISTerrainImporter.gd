tool
class_name NorfolkGISTerrainImporter
extends Node3D

@export_file("*.png", "*.exr", "*.raw") var heightmap_texture_path: String
@export var terrain_size: Vector2 = Vector2(2048.0, 2048.0)
@export var height_scale: float = 150.0
@export var generate_on_ready: bool = false

func _ready() -> void:
	if generate_on_ready:
		generate_gis_terrain()

func generate_gis_terrain() -> void:
	if heightmap_texture_path.is_empty():
		push_error("[NorfolkGISTerrainImporter] Heightmap texture path is missing.")
		return
	
	var img = Image.load_from_file(heightmap_texture_path)
	if not img:
		push_error("[NorfolkGISTerrainImporter] Failed to load heightmap image.")
		return
	
	print("[NorfolkGISTerrainImporter] Generating GIS Mesh for Region: Norfolk / Bayview / Ocean View...")
	_build_array_mesh(img)

func _build_array_mesh(img: Image) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var width = img.get_width()
	var height = img.get_height()
	
	for y in range(height - 1):
		for x in range(width - 1):
			var u = float(x) / float(width)
			var v = float(y) / float(height)
			var h = img.get_pixel(x, y).r * height_scale
			
			var px = (u - 0.5) * terrain_size.x
			var pz = (v - 0.5) * terrain_size.y
			
			st.set_uv(Vector2(u, v))
			st.add_vertex(Vector3(px, h, pz))
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mesh_node = MeshInstance3D.new()
	mesh_node.name = "NorfolkGISTerrainMesh"
	mesh_node.mesh = mesh
	add_child(mesh_node)
	print("[NorfolkGISTerrainImporter] GIS Terrain Mesh Generation Complete.")
