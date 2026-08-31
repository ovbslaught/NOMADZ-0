## SemanticInterpreter.gd
## Translates raw visual tiles into semantic cells (role, subrole, tags, etc.)
## via a swappable SemanticRuleProfile resource.
extends Node

## Export in editor to assign a SemanticRuleProfile .tres resource.
@export var rule_profile_path : String = "res://00_Core/overlay/semantic/default_profile.tres"

var _profile : Resource = null

# Role constants — match the press-kit semantic grid vocabulary exactly.
const ROLE_FLOOR    := "floor"
const ROLE_WALL     := "wall"
const ROLE_LADDER   := "ladder"
const ROLE_DOOR     := "door"
const ROLE_HAZARD   := "hazard"
const ROLE_WATER    := "water"
const ROLE_BG_SHELL := "background_shell"
const ROLE_OCCLUDER := "occluder"
const ROLE_UNKNOWN  := "unknown"

func _ready() -> void:
	if ResourceLoader.exists(rule_profile_path):
		_profile = load(rule_profile_path)
		print("[SemanticInterpreter] Profile loaded: %s" % rule_profile_path)
	else:
		push_warning("[SemanticInterpreter] No profile found at %s — using built-in defaults." % rule_profile_path)

## Main entry: returns Array[Dictionary] of semantic cells from raw tile array.
func interpret_tiles(raw_tiles: Array) -> Array:
	var out : Array = []
	for cell in raw_tiles:
		out.append(_interpret_cell(cell))
	return out

func _interpret_cell(cell: Dictionary) -> Dictionary:
	var tile_id      : int = cell.get("tile_id", -1)
	var palette_idx  : int = cell.get("palette_index", 0)
	var coord        : Vector2i = cell.get("coord", Vector2i.ZERO)
	var role         : String = _resolve_role(tile_id, palette_idx)

	return {
		"coord":         coord,
		"raw_tile_id":   tile_id,
		"palette_index": palette_idx,
		"role":          role,
		"subrole":       _resolve_subrole(role, cell),
		"collision":     role in [ROLE_WALL, ROLE_FLOOR, ROLE_DOOR, ROLE_LADDER],
		"height_hint":   _height_hint(role),
		"theme_tags":    _theme_tags(role),
		"binding_key":   "env/%s/default" % role
	}

func _resolve_role(tile_id: int, palette_idx: int) -> String:
	# If a profile resource exposes a lookup, use it.
	if _profile and _profile.has_method("role_for_tile"):
		return _profile.role_for_tile(tile_id, palette_idx)
	# Built-in fallback heuristics (override with a real profile resource).
	match palette_idx:
		0: return ROLE_FLOOR
		1: return ROLE_WALL
		2: return ROLE_LADDER
		3: return ROLE_DOOR
		4: return ROLE_HAZARD
		5: return ROLE_WATER
		_: return ROLE_UNKNOWN

func _resolve_subrole(role: String, _cell: Dictionary) -> String:
	match role:
		ROLE_LADDER:  return "climbable_vertical"
		ROLE_DOOR:    return "transition_door"
		ROLE_HAZARD:  return "spike"
		ROLE_WATER:   return "surface_water"
		_:            return ""

func _height_hint(role: String) -> float:
	match role:
		ROLE_WALL:  return 2.0
		ROLE_FLOOR: return 0.25
		_:          return 1.0

func _theme_tags(role: String) -> Array:
	match role:
		ROLE_WALL:    return ["solid", "environmental"]
		ROLE_WATER:   return ["liquid", "animated"]
		ROLE_LADDER:  return ["metal", "traversal"]
		_:            return []
