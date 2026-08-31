## OverlayBus.gd
## Autoload singleton — global event hub for the NES Godot Overlay system.
## Add to Project > AutoLoad as "OverlayBus".
extends Node

# ── Import lifecycle ──────────────────────────────────────────────────────────
signal source_import_requested(path: String)
signal source_import_validated(meta: Dictionary)
signal source_import_failed(error_text: String)

# ── Frame streaming ───────────────────────────────────────────────────────────
signal raw_frame_ready(frame_id: int, raw_packet: Dictionary)
signal world_state_built(frame_id: int, world_state: Dictionary)

# ── Semantic pipeline ─────────────────────────────────────────────────────────
signal semantic_map_ready(level_id: String, semantic_cells: Array)

# ── Presentation ──────────────────────────────────────────────────────────────
signal presentation_rebuild_requested(level_id: String)
signal presentation_ready(level_id: String)
signal entity_state_changed(entity_id: String, state: Dictionary)
signal camera_focus_requested(target_id: String, mode: String)
signal fx_event_requested(kind: String, payload: Dictionary)
signal environment_theme_changed(theme_name: String)
signal cinematic_beat_started(beat_name: String)
signal cinematic_beat_finished(beat_name: String)
signal chunk_built(chunk_id: String)
signal entity_presenter_spawned(entity_id: String, presenter_path: String)

# ── Debug / Creator ───────────────────────────────────────────────────────────
signal debug_view_mode_changed(mode: String)          # "exact" | "semantic" | "off"
signal exact_visual_ready(image_texture: ImageTexture, meta: Dictionary)
signal semantic_cell_selected(cell_coord: Vector2i, role_data: Dictionary)
signal semantic_profile_changed(profile_id: String)
signal asset_binding_changed(role_name: String, packed_scene: PackedScene)
signal asset_binding_missing(binding_key: String)
signal validation_warning_added(code: String, details: String)
signal validation_passed(report: Dictionary)

# ── Runtime health ────────────────────────────────────────────────────────────
signal overlay_sync_warning(message: String)
signal overlay_runtime_state_changed(state: int)      # RuntimeState enum from OverlayRuntime
