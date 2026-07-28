extends Node3D
class_name GalaxyGenerator

@export var seed: int = 926
@export var planet_count: int = 100
@export var galaxy_radius: float = 10000.0

func _ready():
\tNoise.set_seed(seed)
\tgenerate_galaxy()

func generate_galaxy():
\tfor i in planet_count:
\t\tvar angle = randf() * TAU
\t\tvar radius = randf() * galaxy_radius
\t\tvar pos = Vector3(cos(angle) * radius, (randf()-0.5)*2000, sin(angle) * radius)
\t\tvar planet = preload("res://scenes/Planet.tscn").instantiate()
\t\tplanet.position = pos
\t\tplanet.seed = hash(pos)
\t\tadd_child(planet)