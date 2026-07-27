# AssetPlacer.gd - Procedural asset placement utility
extends Node

@export var asset_scenes: Array[PackedScene] = []
@export var grid_size: float = 2.0
@export var placement_radius: float = 50.0
@export var density: float = 0.3

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var placed_assets: Array[Node3D] = []

func _ready():
    rng.randomize()

func place_assets_around(center: Vector3, seed_val: int = 0) -> void:
    rng.seed = seed_val
    clear_assets()
    var steps = int(placement_radius / grid_size)
    for x in range(-steps, steps):
        for z in range(-steps, steps):
            if rng.randf() > density:
                continue
            if asset_scenes.is_empty():
                continue
            var scene = asset_scenes[rng.randi() % asset_scenes.size()]
            var inst = scene.instantiate() as Node3D
            if inst:
                var pos = center + Vector3(
                    x * grid_size + rng.randf_range(-0.5, 0.5),
                    0.0,
                    z * grid_size + rng.randf_range(-0.5, 0.5)
                )
                inst.position = pos
                inst.rotation.y = rng.randf_range(0, TAU)
                add_child(inst)
                placed_assets.append(inst)

func clear_assets() -> void:
    for a in placed_assets:
        if is_instance_valid(a):
            a.queue_free()
    placed_assets.clear()
