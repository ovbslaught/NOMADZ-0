## SemanticGridView.gd
## Renders a color-coded semantic grid showing gameplay roles (wall, floor,
## ladder, door, hazard, water, etc.). Click a cell to inspect its role data.
## Press-kit reference: "semantic-grid view shows how tile-map colors are
## interpreted as gameplay meanings."
extends Control

@onready var grid_container : Control = $GridContainer
@onready var role_label     : Label   = $RoleLabel

# Role → display color mapping
const ROLE_COLORS := {
	"wall":             Color(0.3, 0.3, 0.35),
	"floor":            Color(0.5, 0.4, 0.2),
	"ladder":           Color(0.2, 0.7, 0.4),
	"door":             Color(0.2, 0.4, 0.9),
	"hazard":           Color(0.9, 0.2, 0.2),
	"water":            Color(0.1, 0.5, 0.9, 0.8),
	"background_shell": Color(0.15, 0.15, 0.2),
	"occluder":         Color(0.0, 0.0, 0.0),
	"unknown":          Color(0.6, 0.0, 0.6),
}

var _cell_size : int = 8
var _sem_cells : Array = []
var _dims      : Vector2i = Vector2i.ZERO

func _ready() -> void:
	OverlayBus.semantic_map_ready.connect(_on_semantic_map_ready)
	OverlayBus.debug_view_mode_changed.connect(_on_mode_changed)

func _on_semantic_map_ready(_level_id: String, semantic_cells: Array) -> void:
	_sem_cells = semantic_cells
	queue_redraw()

func _draw() -> void:
	if _sem_cells.is_empty():
		return
	for cell in _sem_cells:
		var coord : Vector2i = cell.get("coord", Vector2i.ZERO)
		var role  : String   = cell.get("role", "unknown")
		var col   : Color    = ROLE_COLORS.get(role, Color.MAGENTA)
		var rect  := Rect2(coord.x * _cell_size, coord.y * _cell_size,
		                   _cell_size - 1, _cell_size - 1)
		draw_rect(rect, col)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var cell_coord := Vector2i(
			int(event.position.x) / _cell_size,
			int(event.position.y) / _cell_size
		)
		for cell in _sem_cells:
			if cell.get("coord", Vector2i(-1,-1)) == cell_coord:
				OverlayBus.semantic_cell_selected.emit(cell_coord, cell)
				if role_label:
					role_label.text = "(%d,%d) role=%s  subrole=%s  binding=%s" % [
						cell_coord.x, cell_coord.y,
						cell.get("role","?"),
						cell.get("subrole",""),
						cell.get("binding_key","")
					]
				break

func _on_mode_changed(mode: String) -> void:
	visible = (mode == "semantic")
