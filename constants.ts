
import { Feature, FeatureInfo } from './types';

export const GD_SCRIPT_CODE = `
extends Node3D
# Complete 16-bit No Man's Sky Style Universe Generator
# Single template with galaxy, star systems, planets, and rendering

@export var universe_seed: int = 12345
@export var galaxy_grid_size: int = 100
@export var max_warp_distance: int = 5
@export var render_distance: int = 10

var rng := RandomNumberGenerator.new()
var galaxy_map := {}
var current_system = null
var player_position := Vector2i(0, 0)

# Visual nodes
var star_multimesh: MultiMeshInstance3D
var planet_nodes := []

# 16-bit color palettes
const PLANET_PALETTES := {
	"toxic": [Color8(120, 255, 60), Color8(80, 200, 40), Color8(40, 150, 20)],
	"lush": [Color8(60, 180, 60), Color8(100, 200, 100), Color8(140, 220, 140)],
	"desert": [Color8(220, 180, 100), Color8(200, 160, 80), Color8(180, 140, 60)],
	"frozen": [Color8(200, 220, 255), Color8(150, 180, 220), Color8(100, 140, 180)],
	"volcanic": [Color8(200, 60, 40), Color8(160, 40, 20), Color8(120, 20, 10)],
	"ocean": [Color8(40, 120, 200), Color8(60, 140, 220), Color8(80, 160, 240)],
	"barren": [Color8(140, 120, 100), Color8(120, 100, 80), Color8(100, 80, 60)],
	"exotic": [Color8(255, 60, 200), Color8(200, 40, 160), Color8(160, 20, 120)]
}

func _ready():
	rng.seed = universe_seed
	setup_visuals()
	generate_starting_system()
	render_current_system()
	print_system_info()

func _process(_delta):
	if current_system:
		animate_planets()

func generate_star_system(coords: Vector2i) -> Dictionary:
	var local_rng = RandomNumberGenerator.new()
	local_rng.seed = hash_coords(coords)
	
	var star_type = get_star_type(local_rng)
	var num_planets = local_rng.randi_range(1, 6)
	var planets = []
	
	for i in range(num_planets):
		planets.append(generate_planet(i, local_rng, star_type))
	
	return {
		"coords": coords,
		"name": generate_system_name(local_rng),
		"star_type": star_type,
		"star_color": get_star_color(star_type),
		"planets": planets,
	}

func generate_planet(index: int, local_rng: RandomNumberGenerator, star_type: String) -> Dictionary:
	var biome = get_planet_biome(local_rng, index, star_type)
	var size_class = local_rng.randi_range(1, 3)
	var orbit_radius = 5.0 + (index * 3.0)
	
	return {
		"index": index,
		"name": generate_planet_name(local_rng, biome),
		"biome": biome,
		"palette": PLANET_PALETTES[biome],
		"radius": 0.3 + (size_class * 0.2),
		"orbit_radius": orbit_radius,
		"orbit_speed": 0.5 / (orbit_radius * 0.5),
		"rotation_speed": local_rng.randf_range(0.1, 0.5),
		"orbit_angle": local_rng.randf() * TAU,
		"weather": get_weather(biome, local_rng),
		"has_rings": local_rng.randf() > 0.85,
	}
`;

export const FEATURES: FeatureInfo[] = [
  {
    id: Feature.EXPLAIN_CODE,
    title: 'Explain Code',
    description: 'Get a detailed, step-by-step explanation of what the GDScript does, including its structure, functions, and logic.',
    model: 'gemini-2.5-pro',
  },
  {
    id: Feature.IMAGE_GENERATION,
    title: 'Image Prompt Ideas',
    description: 'Generate creative and detailed art prompts for Imagen based on the procedural generation logic in the script.',
    model: 'gemini-2.5-flash',
  },
  {
    id: Feature.VIDEO_GENERATION,
    title: 'Video Scene Ideas',
    description: 'Brainstorm compelling video scene concepts for Veo, inspired by the dynamic universe this script can create.',
    model: 'gemini-2.5-flash',
  },
  {
    id: Feature.LIVE_API_INTEGRATION,
    title: 'Live API Concepts',
    description: 'Explore innovative ways to integrate real-time voice interaction (Live API) into a game using this script.',
    model: 'gemini-2.5-flash',
  },
  {
    id: Feature.IMAGE_EDITING,
    title: 'In-Game Image Editing',
    description: 'Suggest features for an in-game photo mode that uses Gemini for AI-powered image editing based on text commands.',
    model: 'gemini-2.5-flash-image',
  },
  {
    id: Feature.IMAGE_UNDERSTANDING,
    title: 'Image-Based Generation',
    description: 'How could this script be modified to generate a star system based on the colors and mood of an uploaded image?',
    model: 'gemini-2.5-flash',
  },
  {
    id: Feature.COMPLEX_QUERY,
    title: 'Complex Query (Thinking Mode)',
    description: 'Ask a deep, complex question about refactoring the script for multiplayer scalability and performance.',
    model: 'gemini-2.5-pro',
  },
  {
    id: Feature.SEARCH_GROUNDING,
    title: 'Ground with Search',
    description: 'How can real-world astronomical data be incorporated into this script? Use Google Search for current information.',
    model: 'gemini-2.5-flash',
  },
  {
    id: Feature.LOW_LATENCY_RESPONSE,
    title: 'Low-Latency NPC Banter',
    description: 'Generate ideas for a system that creates dynamic, low-latency NPC dialogue for pilots in this universe.',
    model: 'gemini-2.5-flash-lite',
  },
];
