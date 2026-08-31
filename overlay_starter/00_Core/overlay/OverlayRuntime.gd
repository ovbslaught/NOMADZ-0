## OverlayRuntime.gd
## Top-level orchestrator. Attach to the root node of overlay_runtime.tscn.
## Boots adapters, routes normalized state, and owns runtime lifecycle.
extends Node

enum RuntimeState { IDLE, VALIDATING, READY, STREAMING, ERROR }

var state : int = RuntimeState.IDLE
var current_world_state : Dictionary = {}
var current_level_id    : String     = ""

@onready var source_bridge        : Node = $SourceBridge
@onready var semantic_interpreter : Node = $SemanticInterpreter
@onready var level_assembler      : Node = $PresentationRoot/LevelAssembler
@onready var entity_presenter_root: Node = $PresentationRoot/EntitiesRoot
@onready var camera_director      : Node = $PresentationRoot/CameraDirector
@onready var fx_director          : Node = $PresentationRoot/FXDirector

func _ready() -> void:
	OverlayBus.raw_frame_ready.connect(_on_raw_frame_ready)
	OverlayBus.source_import_validated.connect(_on_source_import_validated)
	OverlayBus.source_import_failed.connect(_on_source_import_failed)
	OverlayBus.presentation_rebuild_requested.connect(_on_presentation_rebuild_requested)
	_set_state(RuntimeState.IDLE)
	print("[OverlayRuntime] Ready.")

# ── Public API ────────────────────────────────────────────────────────────────

## Call this to kick off a tile-map import from a file path.
func import_source(path: String) -> void:
	if not OverlayConfig.SOURCE_READ_ONLY:
		push_warning("[OverlayRuntime] SOURCE_READ_ONLY is false — check OverlayConfig.")
	_set_state(RuntimeState.VALIDATING)
	OverlayBus.source_import_requested.emit(path)

## Call this to push a live gameplay frame (from emulator bridge or replay).
func push_frame(frame_id: int, raw_packet: Dictionary) -> void:
	OverlayBus.raw_frame_ready.emit(frame_id, raw_packet)

# ── Internal handlers ─────────────────────────────────────────────────────────

func _on_source_import_validated(meta: Dictionary) -> void:
	current_level_id = meta.get("level_id", "unknown")
	_set_state(RuntimeState.READY)
	print("[OverlayRuntime] Import validated → level: %s" % current_level_id)

func _on_source_import_failed(error_text: String) -> void:
	push_error("[OverlayRuntime] Import failed: %s" % error_text)
	_set_state(RuntimeState.ERROR)

func _on_raw_frame_ready(frame_id: int, raw_packet: Dictionary) -> void:
	_set_state(RuntimeState.STREAMING)
	current_world_state = WorldStateModel.build_from_raw(raw_packet)
	OverlayBus.world_state_built.emit(frame_id, current_world_state)

	var sem_cells := semantic_interpreter.interpret_tiles(
		current_world_state.get("tiles_visual", [])
	)
	current_world_state["tiles_semantic"] = sem_cells
	OverlayBus.semantic_map_ready.emit(current_level_id, sem_cells)
	OverlayBus.presentation_rebuild_requested.emit(current_level_id)

func _on_presentation_rebuild_requested(level_id: String) -> void:
	if level_assembler:
		level_assembler.assemble(current_world_state)
	OverlayBus.presentation_ready.emit(level_id)

func _set_state(next: int) -> void:
	state = next
	OverlayBus.overlay_runtime_state_changed.emit(state)
