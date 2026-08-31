## OverlayConfig.gd
## Autoload singleton — constants, feature flags, platform quality tiers.
## Add to Project > AutoLoad as "OverlayConfig".
extends Node

# ── Chunk geometry ────────────────────────────────────────────────────────────
const CHUNK_SIZE_TILES : int   = 16      # cells per chunk edge
const TILE_WORLD_UNIT  : float = 1.0     # 1 tile = 1 Godot unit

# ── Debug / Creator flags ─────────────────────────────────────────────────────
var debug_show_semantic_grid : bool = false
var debug_show_exact_visual  : bool = false
var debug_inspector_open     : bool = false

# ── Source safety ─────────────────────────────────────────────────────────────
const SOURCE_READ_ONLY       : bool = true   # never write to source data
const MAX_IMPORT_FILE_MB     : float = 32.0

# ── Quality tiers  (set at boot based on OS.get_name()) ──────────────────────
enum QualityTier { LOW, MEDIUM, HIGH }
var quality_tier : int = QualityTier.HIGH

func _ready() -> void:
	var platform := OS.get_name()
	if platform in ["Android", "iOS"]:
		quality_tier = QualityTier.LOW
	elif platform == "Web":
		quality_tier = QualityTier.MEDIUM
	else:
		quality_tier = QualityTier.HIGH
	print("[OverlayConfig] Platform: %s  Quality: %d" % [platform, quality_tier])

# ── Dynamic light budget based on tier ───────────────────────────────────────
func max_dynamic_lights() -> int:
	match quality_tier:
		QualityTier.LOW:    return 2
		QualityTier.MEDIUM: return 6
		_:                  return 16
