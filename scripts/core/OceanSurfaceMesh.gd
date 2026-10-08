# =====================================================================
#                 NOMADZ NODE COMPLIANCE ENGINE SCRIPT
# =====================================================================
@tool
extends MeshInstance3D

@export var regenerate_system_mesh: bool = false : 
	set(val):
		_generate_ocean_surface()

func _ready() -> void:
	if not mesh:
		_generate_ocean_surface()

func _generate_ocean_surface() -> void:
	# Error Handled Generation: Avoid crashing active thread space
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(500, 500)
	plane_mesh.subdivisions_width = 250
	plane_mesh.subdivisions_depth = 250
	
	self.mesh = plane_mesh
	
	# Verify and verify materials paths safely
	var shader_material = get_active_material(0) as ShaderMaterial
	if not shader_material:
		shader_material = ShaderMaterial.new()
		var shader_res = load("res://WORMHOLE/NOMADZ-0/Shaders/deep_ocean.gdshader")
		if shader_res:
			shader_material.shader = shader_res
			# Create fall-through texture parameters safely
			var img = Image.create(256, 256, false, Image.FORMAT_RF)
			img.fill(Color(0.5, 0.5, 0.5, 1.0))
			var noise_tex = ImageTexture.create_from_image(img)
			shader_material.set_shader_parameter("noise_texture", noise_tex)
			self.set_surface_override_material(0, shader_material)
		else:
			push_error("[NOMADZ CRYP] Core shader resource path missing or unreachable.")
