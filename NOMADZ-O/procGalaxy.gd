# ProcGalaxy.gd (Autoload: ProcGalaxy)
# Generates deterministic planetary data based on the Galaxy Seed.

extends Node

# Planetary Biomes for NOMADZ
enum Biome { VOLCANIC, TUNDRA, WASTELAND, CYBER_CITY, NEBULA_VOID }

class PlanetData:
	var id: String
	var biome: Biome
	var gravity: float
	var resource_multiplier: float
	var faction_owner: String
	var signal_strength: int

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = GameManager.galaxy_seed

## Generates data for a specific planet coordinate or ID
func get_planet_stats(planet_id: String) -> PlanetData:
	# Use the planet_id string hash to create a deterministic sub-seed
	var sub_seed = hash(planet_id) + GameManager.galaxy_seed
	_rng.seed = sub_seed
	
	var data = PlanetData.new()
	data.id = planet_id
	data.biome = _rng.randi_range(0, Biome.size() - 1) as Biome
	data.gravity = _rng.randf_range(0.5, 2.0)
	data.resource_multiplier = _rng.randf_range(0.8, 3.5)
	data.signal_strength = _rng.randi_range(1, 100)
	
	# Deterministic Faction Selection
	var factions = ["Nomadz", "Proxy", "VultureCorp", "The Swarm"]
	data.faction_owner = factions[_rng.randi_range(0, factions.size() - 1)]
	
	return data

## Returns visual description based on biome
func get_biome_name(biome_type: Biome) -> String:
	match biome_type:
		Biome.VOLCANIC: return "Ember Fuse"
		Biome.TUNDRA: return "Glacial Core"
		Biome.WASTELAND: return "Dust Meridian"
		Biome.CYBER_CITY: return "Neon Spire"
		Biome.NEBULA_VOID: return "The Great Nothing"
		_: return "Unknown Sector"