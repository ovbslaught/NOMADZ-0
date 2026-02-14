extends Node3D
class_name ProceduralPlanet

@export var seed: int
@export var radius: float = 1000.0

func _ready():
\tgenerate_surface()

func generate_surface():
\tvar noise = FastNoiseLite.new()
\tnoise.seed = seed
\tnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX
\t
\tvar surface = MeshInstance3D.new()
\tvar st = SurfaceTool.new()
\tst.begin(Mesh.PRIMITIVE_TRIANGLES)
\t
\tfor i in 10000:
\t\tvar phi = randf() * TAU
\t\tvar theta = acos(2*randf() - 1)
\t\tvar r = radius + noise.get_noise_3d(0,0,0)*100
\t\tvar x = r * sin(theta) * cos(phi)
\t\tvar y = r * sin(theta) * sin(phi)
\t\tvar z = r * cos(theta)
\t\tst.set_normal(Vector3.UP)
\t\tst.add_vertex(Vector3(x,y,z))
\t
\tsurface.mesh = st.commit()
\tadd_child(surface)