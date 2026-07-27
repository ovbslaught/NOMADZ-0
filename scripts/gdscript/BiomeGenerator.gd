## BiomeGenerator.gd
## NOMADZ-0 — Procedural world zone / biome system.
## Branch: Cosmic-key
##
## Attach to a WorldEnvironment node (or scene root that owns WorldEnvironment).
##
## Signals:
##   biome_changed(biome_name: String, biome_data: Dictionary)
##   pillar_activated(pillar_id: String)
##
## Biomes: ANTARCTIC, SAHARA, PACIFIC_DEEP, AMAZON, VOLCANIC
##
## Usage:
##   Call generate_world(seed) once to build the grid.
##   Call get_biome_at_position(world_pos) to query any position.
##   The active biome transitions automatically when the player moves.
##   Wire a CharacterBody3D (or any Node3D) to track_node to enable auto-transitions.

class_name BiomeGenerator
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal biome_changed(biome_name: String, biome_data: Dictionary)
signal pillar_activated(pillar_id: String)

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export_group("World Grid")
@export var grid_size: int = 8            ## NxN grid of cells
@export var cell_size_meters: float = 500.0
@export var world_seed: int = 42

@export_group("Scene References")
## Assign the WorldEnvironment node that owns the Environment resource.
@export var world_environment: WorldEnvironment
## Node3D to track for automatic biome transitions (typically the player).
@export var track_node: Node3D
## Transition duration in seconds.
@export var transition_duration: float = 3.0

# ---------------------------------------------------------------------------
# Biome type enum
# ---------------------------------------------------------------------------
enum BiomeType {
	ANTARCTIC,
	SAHARA,
	PACIFIC_DEEP,
	AMAZON,
	VOLCANIC
}

# ---------------------------------------------------------------------------
# Biome definitions
## Each entry is a Dictionary with visual, audio, and gameplay properties.
# ---------------------------------------------------------------------------
const BIOME_DEFS: Dictionary = {
	BiomeType.ANTARCTIC: {
		"name": "ANTARCTIC",
		"sky_color": Color(0.75, 0.88, 1.0),
		"ambient_light_color": Color(0.6, 0.75, 0.95),
		"fog_color": Color(0.90, 0.95, 1.0),
		"fog_density": 0.015,
		"gravity_scale": 1.0,
		"music_layer": "arctic_ambient",
		"tension_multiplier": 0.8,   ## Cold slows enemies' evolution pace
		"pillar_id": "pillar_frost",
		"description": "Ice-cap biome with dense white fog and frozen terrain.",
	},
	BiomeType.SAHARA: {
		"name": "SAHARA",
		"sky_color": Color(1.0, 0.72, 0.28),
		"ambient_light_color": Color(1.0, 0.60, 0.20),
		"fog_color": Color(1.0, 0.55, 0.15),
		"fog_density": 0.008,
		"gravity_scale": 1.0,
		"music_layer": "desert_pulse",
		"tension_multiplier": 1.1,
		"pillar_id": "pillar_sun",
		"description": "Hot arid expanse with orange haze and shifting dunes.",
	},
	BiomeType.PACIFIC_DEEP: {
		"name": "PACIFIC_DEEP",
		"sky_color": Color(0.02, 0.08, 0.30),
		"ambient_light_color": Color(0.05, 0.20, 0.50),
		"fog_color": Color(0.0, 0.12, 0.35),
		"fog_density": 0.035,
		"gravity_scale": 0.6,        ## Buoyancy — reduced gravity underwater
		"music_layer": "deep_biolum",
		"tension_multiplier": 1.3,
		"pillar_id": "pillar_abyss",
		"description": "Dark deep-sea zone with bioluminescent particles and crushing atmosphere.",
	},
	BiomeType.AMAZON: {
		"name": "AMAZON",
		"sky_color": Color(0.15, 0.45, 0.10),
		"ambient_light_color": Color(0.25, 0.55, 0.15),
		"fog_color": Color(0.20, 0.50, 0.12),
		"fog_density": 0.022,
		"gravity_scale": 1.0,
		"music_layer": "jungle_thrum",
		"tension_multiplier": 1.2,
		"pillar_id": "pillar_canopy",
		"description": "Dense jungle canopy with heavy particle fog and layered greenery.",
	},
	BiomeType.VOLCANIC: {
		"name": "VOLCANIC",
		"sky_color": Color(0.25, 0.06, 0.02),
		"ambient_light_color": Color(0.80, 0.28, 0.05),
		"fog_color": Color(0.60, 0.12, 0.00),
		"fog_density": 0.025,
		"gravity_scale": 1.1,        ## Dense volcanic atmosphere — slightly heavier
		"music_layer": "volcanic_tension",
		"tension_multiplier": 1.5,   ## High tension — AI evolves faster here
		"pillar_id": "pillar_magma",
		"description": "Volcanic zone with heat distortion, lava patches, and red/orange sky.",
	},
}

# ---------------------------------------------------------------------------
# Internal world grid
# ---------------------------------------------------------------------------

## _grid[row][col] = BiomeType int
var _grid: Array = []

## Which pillars have been activated this session.
var _activated_pillars: Array[String] = []

## Currently active biome data.
var _active_biome: Dictionary = {}

## Last grid cell the tracked node occupied.
var _last_cell: Vector2i = Vector2i(-1, -1)

## Active Tween for environment transitions (stored to kill on new transition).
var _env_tween: Tween = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	generate_world(world_seed)

	# Initial biome at origin.
	var start_biome := get_biome_at_position(Vector3.ZERO)
	_apply_biome_environment(start_biome, true)  # instant=true skips tween on first load
	_active_biome = start_biome


func _process(_delta: float) -> void:
	## Poll tracked node position for biome transition.
	if not track_node:
		return

	var cell := _world_to_cell(track_node.global_position)
	if cell == _last_cell:
		return  # Still in same cell; no work to do.

	_last_cell = cell
	var biome := _get_biome_for_cell(cell)
	if biome.get("name", "") != _active_biome.get("name", ""):
		_active_biome = biome
		biome_changed.emit(biome["name"], biome)
		_apply_biome_environment(biome, false)
		_check_pillar(biome)

		## Notify Director of tension multiplier change so AIAgentBase scales correctly.
		_push_tension_multiplier(biome.get("tension_multiplier", 1.0))


# ---------------------------------------------------------------------------
# World generation
# ---------------------------------------------------------------------------

func generate_world(seed_value: int) -> void:
	## Build the NxN biome grid using seeded RNG. Deterministic for the same seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	_grid.clear()
	var biome_count := BIOME_DEFS.size()  # 5

	for row in range(grid_size):
		var row_data: Array = []
		for col in range(grid_size):
			## Weighted randomness: VOLCANIC is rarer, AMAZON and SAHARA more common.
			var roll := rng.randi_range(0, 99)
			var biome_type: BiomeType
			if roll < 25:
				biome_type = BiomeType.AMAZON
			elif roll < 45:
				biome_type = BiomeType.SAHARA
			elif roll < 62:
				biome_type = BiomeType.ANTARCTIC
			elif roll < 80:
				biome_type = BiomeType.PACIFIC_DEEP
			else:
				biome_type = BiomeType.VOLCANIC
			row_data.append(biome_type)
		_grid.append(row_data)


# ---------------------------------------------------------------------------
# Position queries
# ---------------------------------------------------------------------------

func get_biome_at_position(world_pos: Vector3) -> Dictionary:
	## Returns the biome Dictionary for any world-space position.
	## Out-of-grid positions clamp to nearest edge cell.
	var cell := _world_to_cell(world_pos)
	return _get_biome_for_cell(cell)


func _world_to_cell(world_pos: Vector3) -> Vector2i:
	## Convert world X/Z position to grid cell indices.
	var half := (grid_size * cell_size_meters) * 0.5
	var local_x := world_pos.x + half
	var local_z := world_pos.z + half
	var col := int(local_x / cell_size_meters)
	var row := int(local_z / cell_size_meters)
	col = clampi(col, 0, grid_size - 1)
	row = clampi(row, 0, grid_size - 1)
	return Vector2i(col, row)


func _get_biome_for_cell(cell: Vector2i) -> Dictionary:
	if _grid.is_empty():
		return BIOME_DEFS[BiomeType.SAHARA]  ## fallback
	var row_data: Array = _grid[cell.y]
	var biome_type: BiomeType = row_data[cell.x]
	return BIOME_DEFS[biome_type]


# ---------------------------------------------------------------------------
# Environment transition
# ---------------------------------------------------------------------------

func apply_biome_environment(biome: Dictionary) -> void:
	## Public wrapper — smooth tween transition to given biome.
	_apply_biome_environment(biome, false)


func _apply_biome_environment(biome: Dictionary, instant: bool) -> void:
	## Apply sky, ambient, and fog properties to the WorldEnvironment.
	## Uses Tween for smooth blending unless instant == true.
	if not world_environment or not world_environment.environment:
		push_warning("BiomeGenerator: WorldEnvironment or Environment resource not assigned.")
		return

	var env := world_environment.environment

	if instant:
		_set_env_direct(env, biome)
		return

	# Kill any in-progress transition before starting a new one.
	if _env_tween and _env_tween.is_running():
		_env_tween.kill()

	_env_tween = create_tween()
	_env_tween.set_parallel(true)  ## All property tweens run simultaneously.

	var dur := transition_duration

	# Sky background color (ProceduralSkyMaterial or Sky background color).
	# Godot 4 WorldEnvironment: use environment.background_color for solid color.
	_env_tween.tween_property(env, "background_color", biome["sky_color"], dur)

	# Ambient light.
	_env_tween.tween_property(env, "ambient_light_color", biome["ambient_light_color"], dur)

	# Fog — VolumetricFog (if enabled) or classic FogEnvironment.
	if env.volumetric_fog_enabled:
		_env_tween.tween_property(env, "volumetric_fog_albedo", biome["fog_color"], dur)
		_env_tween.tween_property(env, "volumetric_fog_density", biome["fog_density"], dur)
	else:
		# Fallback: depth fog (fog_enabled flag must be true on Environment).
		_env_tween.tween_property(env, "fog_light_color", biome["fog_color"], dur)


func _set_env_direct(env: Environment, biome: Dictionary) -> void:
	## Instantly assign all biome environment properties (no tween).
	env.background_color = biome["sky_color"]
	env.ambient_light_color = biome["ambient_light_color"]
	if env.volumetric_fog_enabled:
		env.volumetric_fog_albedo = biome["fog_color"]
		env.volumetric_fog_density = biome["fog_density"]
	else:
		env.fog_light_color = biome["fog_color"]


# ---------------------------------------------------------------------------
# Pillar system
# ---------------------------------------------------------------------------

func _check_pillar(biome: Dictionary) -> void:
	## Emit pillar_activated the FIRST TIME the player enters a biome (per session).
	var pillar_id: String = biome.get("pillar_id", "")
	if pillar_id.is_empty():
		return
	if pillar_id in _activated_pillars:
		return  ## Already triggered this session.

	_activated_pillars.append(pillar_id)
	pillar_activated.emit(pillar_id)


func is_pillar_activated(pillar_id: String) -> bool:
	return pillar_id in _activated_pillars


func get_all_pillar_ids() -> Array[String]:
	## Returns all pillar IDs defined across biomes (useful for save state).
	var ids: Array[String] = []
	for biome_data in BIOME_DEFS.values():
		var pid: String = biome_data.get("pillar_id", "")
		if not pid.is_empty() and pid not in ids:
			ids.append(pid)
	return ids


# ---------------------------------------------------------------------------
# Director tension integration
# ---------------------------------------------------------------------------

func _push_tension_multiplier(multiplier: float) -> void:
	## Inform Director that the biome's tension multiplier has changed.
	## AIAgentBase uses tension_multiplier to scale evolution speed.
	if not Engine.has_singleton("Director"):
		return
	var director = Engine.get_singleton("Director")
	if director.has_signal("biome_tension_multiplier_changed"):
		director.emit_signal("biome_tension_multiplier_changed", multiplier)


# ---------------------------------------------------------------------------
# Debug / utility
# ---------------------------------------------------------------------------

func print_grid() -> void:
	## Print the generated grid to the Godot output log (debug use).
	for row in range(grid_size):
		var row_str := ""
		for col in range(grid_size):
			var biome_type: BiomeType = _grid[row][col]
			row_str += BIOME_DEFS[biome_type]["name"].substr(0, 3) + " "
		print(row_str)


func get_active_biome() -> Dictionary:
	return _active_biome
