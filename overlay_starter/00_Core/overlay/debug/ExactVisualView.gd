## ExactVisualView.gd
## Renders a pixel-accurate representation of imported tile-map source data.
## Attach to a TextureRect or SubViewport inside the creator_preview.tscn.
## Press-kit reference: "pixel-for-pixel preview of source data."
extends Control

@onready var texture_rect : TextureRect = $TextureRect
@onready var info_label   : Label       = $InfoLabel

var _current_meta : Dictionary = {}

func _ready() -> void:
	OverlayBus.world_state_built.connect(_on_world_state_built)
	OverlayBus.debug_view_mode_changed.connect(_on_mode_changed)

func _on_world_state_built(_frame_id: int, world_state: Dictionary) -> void:
	_build_exact_image(world_state)

func _build_exact_image(ws: Dictionary) -> void:
	var dims    : Vector2i = ws.get("dimensions", Vector2i(1,1))
	var palette : Array    = ws.get("palette",    [])
	var tiles   : Array    = ws.get("tiles_visual", [])

	if dims.x <= 0 or dims.y <= 0:
		return

	var img := Image.create(dims.x, dims.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)

	for cell in tiles:
		var coord : Vector2i = cell.get("coord", Vector2i.ZERO)
		var pidx  : int      = cell.get("palette_index", 0)
		var col   : Color    = palette[pidx] if pidx < palette.size() else Color.MAGENTA
		if coord.x < dims.x and coord.y < dims.y:
			img.set_pixel(coord.x, coord.y, col)

	var tex := ImageTexture.create_from_image(img)
	texture_rect.texture = tex
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel-accurate

	_current_meta = ws
	_update_info_label(ws, tiles.size())
	OverlayBus.exact_visual_ready.emit(tex, _current_meta)

func _update_info_label(ws: Dictionary, tile_count: int) -> void:
	if info_label:
		var dims : Vector2i = ws.get("dimensions", Vector2i.ZERO)
		info_label.text = "Level: %s  |  Grid: %dx%d  |  Tiles: %d  |  Palette: %d" % [
			ws.get("level_id","?"), dims.x, dims.y,
			tile_count, ws.get("palette",[]).size()
		]

func _on_mode_changed(mode: String) -> void:
	visible = (mode == "exact")
