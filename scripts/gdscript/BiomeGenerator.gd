# BiomeGenerator.gd - Procedural world zones, elevation + biome blend
extends Node

enum BiomeType { ARCTIC, DESERT, FOREST, VOLCANIC, OCEAN, VOID }

@export var world_seed: int = 42
@export var chunk_size: int = 64
@export var biome_scale: float = 0.05
@export var elevation_scale: float = 0.03

var noise_biome: FastNoiseLite
var noise_elevation: FastNoiseLite
var generated_chunks: Dictionary = {}

func _ready():
    _init_noise()

func _init_noise() -> void:
    noise_biome = FastNoiseLite.new()
    noise_biome.seed = world_seed
    noise_biome.frequency = biome_scale
    noise_biome.fractal_octaves = 3
    
    noise_elevation = FastNoiseLite.new()
    noise_elevation.seed = world_seed + 1000
    noise_elevation.frequency = elevation_scale
    noise_elevation.fractal_octaves = 4

func generate_chunk(chunk_pos: Vector2i) -> Dictionary:
    var chunk_key = "%d,%d" % [chunk_pos.x, chunk_pos.y]
    if chunk_key in generated_chunks:
        return generated_chunks[chunk_key]
    
    var chunk_data = {
        "position": chunk_pos,
        "tiles": [],
        "biome_distribution": {}
    }
    
    for x in chunk_size:
        for z in chunk_size:
            var world_x = chunk_pos.x * chunk_size + x
            var world_z = chunk_pos.y * chunk_size + z
            var tile = _generate_tile(world_x, world_z)
            chunk_data["tiles"].append(tile)
            var biome_name = BiomeType.keys()[tile["biome"]]
            chunk_data["biome_distribution"][biome_name] = chunk_data["biome_distribution"].get(biome_name, 0) + 1
    
    generated_chunks[chunk_key] = chunk_data
    DebugTools.log("BiomeGen: Chunk %s generated" % chunk_key)
    return chunk_data

func _generate_tile(x: int, z: int) -> Dictionary:
    var biome_val = noise_biome.get_noise_2d(float(x), float(z))
    var elev_val = noise_elevation.get_noise_2d(float(x), float(z))
    
    var biome = _determine_biome(biome_val, elev_val)
    var height = _calculate_height(elev_val, biome)
    
    return {
        "pos": Vector2i(x, z),
        "biome": biome,
        "height": height,
        "temperature": _get_temperature(biome),
        "resources": _get_resources(biome)
    }

func _determine_biome(biome_noise: float, elevation: float) -> BiomeType:
    if elevation < -0.3:
        return BiomeType.OCEAN
    elif elevation > 0.6:
        return BiomeType.VOLCANIC if biome_noise > 0.3 else BiomeType.ARCTIC
    elif biome_noise < -0.4:
        return BiomeType.VOID
    elif biome_noise < -0.1:
        return BiomeType.DESERT
    else:
        return BiomeType.FOREST

func _calculate_height(elevation: float, biome: BiomeType) -> float:
    var base_height = (elevation + 1.0) * 50.0
    match biome:
        BiomeType.VOLCANIC:
            return base_height * 1.5
        BiomeType.OCEAN:
            return base_height * 0.3
        BiomeType.VOID:
            return base_height * 0.1
        _:
            return base_height

func _get_temperature(biome: BiomeType) -> float:
    match biome:
        BiomeType.ARCTIC: return -20.0
        BiomeType.VOLCANIC: return 80.0
        BiomeType.DESERT: return 45.0
        BiomeType.FOREST: return 18.0
        BiomeType.OCEAN: return 12.0
        BiomeType.VOID: return -273.0
        _: return 20.0

func _get_resources(biome: BiomeType) -> Array:
    match biome:
        BiomeType.VOLCANIC: return ["uridium_ore", "geothermal_crystal"]
        BiomeType.ARCTIC: return ["ice_shard", "memory_crystal"]
        BiomeType.FOREST: return ["bio_matter", "resonance_wood"]
        BiomeType.VOID: return ["dark_matter", "entropy_fragment"]
        _: return []
