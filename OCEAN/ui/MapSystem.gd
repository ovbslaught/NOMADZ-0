## MapSystem.gd
## CanvasLayer — NOMADZ: Signal Descent
## Full Metroidvania map: tracks visited rooms, draws grid map,
## shows current position, marks fragments/save points.
## Press M to toggle.
## VultureCode / Sol / NOMADZ Universe

class_name MapSystem
extends CanvasLayer

# ─── CONSTANTS ────────────────────────────────────────────────────────────────
const CELL_SIZE    : int = 20
const CELL_GAP     : int = 2
const MAP_COLS     : int = 12
const MAP_ROWS     : int = 10
const ALPHA_VISITED: float = 0.9
const ALPHA_ADJ    : float = 0.35   ## Adjacent unseen rooms shown dimly

## Room grid positions — [col, row] zero-indexed
## Matches ROOM_REGISTRY keys in Main.gd
const ROOM_GRID : Dictionary = {
	"room_crash_site"            : Vector2i(5, 0),
	"room_bone_shafts_1"         : Vector2i(5, 2),
	"room_bone_shafts_2"         : Vector2i(4, 3),
	"room_signal_relay"          : Vector2i(6, 3),
	"room_luminous_substrate"    : Vector2i(5, 5),
	"room_vulture_eye_antechamber": Vector2i(5, 7),
	"room_vulture_eye_boss"      : Vector2i(5, 8),
	"room_mother_brain_core"     : Vector2i(5, 9),
}

## Cell types
const CELL_COLORS := {
	"default"    : Color(0.15, 0.25, 0.35, 1.0),
	"visited"    : Color(0.2,  0.5,  0.75, 1.0),
	"current"    : Color(0.4,  0.9,  1.0,  1.0),
	"save"       : Color(0.2,  0.9,  0.4,  1.0),
	"boss"       : Color(0.9,  0.15, 0.1,  1.0),
	"fragment"   : Color(0.4,  0.7,  1.0,  1.0),
	"background" : Color(0.02, 0.03, 0.06, 0.95),
}

# ─── NODES ───────────────────────────────────────────────────────────────────
@onready var map_panel : Control     = $MapPanel
@onready var draw_node : Control     = $MapPanel/MapDraw
@onready var close_btn : Button      = $MapPanel/CloseBtn
@onready var legend    : VBoxContainer = $MapPanel/Legend

# ─── STATE ────────────────────────────────────────────────────────────────────
const DEBUG_MODE := false
var _visible     : bool = false

# ─── LIFECYCLE ────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 5
	if is_instance_valid(map_panel):
		map_panel.visible = false
	if is_instance_valid(close_btn):
		close_btn.pressed.connect(_close)
	if is_instance_valid(draw_node):
		draw_node.draw.connect(_draw_map)
	GameManager.room_changed.connect(func(_id): _refresh())
	GameManager.cosmic_fragment_collected.connect(func(_id): _refresh())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if _visible:
			_close()
		else:
			_open()

func _open() -> void:
	_visible = true
	if is_instance_valid(map_panel):
		map_panel.visible = true
	GameManager.set_pause(true)
	_refresh()
	AudioManager.play_sfx("ui_confirm")

func _close() -> void:
	_visible = false
	if is_instance_valid(map_panel):
		map_panel.visible = false
	GameManager.set_pause(false)
	AudioManager.play_sfx("ui_cancel")

func _refresh() -> void:
	if is_instance_valid(draw_node):
		draw_node.queue_redraw()

func _draw_map() -> void:
	if not is_instance_valid(draw_node):
		return

	var current_room := GameManager.current_room_id

	for room_id in ROOM_GRID:
		var grid_pos : Vector2i = ROOM_GRID[room_id]
		var px_x := grid_pos.x * (CELL_SIZE + CELL_GAP)
		var px_y := grid_pos.y * (CELL_SIZE + CELL_GAP)
		var rect  := Rect2(Vector2(px_x, px_y), Vector2(CELL_SIZE, CELL_SIZE))

		var color := CELL_COLORS["default"]
		var alpha  := 0.2

		if room_id == current_room:
			color = CELL_COLORS["current"]
			alpha  = 1.0
		elif room_id in GameManager.visited_rooms:
			color = _get_room_cell_color(room_id)
			alpha  = ALPHA_VISITED
		elif _is_adjacent_to_visited(grid_pos):
			alpha = ALPHA_ADJ

		color.a = alpha
		draw_node.draw_rect(rect, color)

		## Fragment marker
		if _room_has_fragment(room_id) and room_id in GameManager.visited_rooms:
			var center := Vector2(px_x + CELL_SIZE / 2, px_y + CELL_SIZE / 2)
			draw_node.draw_circle(center, 3.0, CELL_COLORS["fragment"])

func _get_room_cell_color(room_id: String) -> Color:
	if "boss" in room_id:
		return CELL_COLORS["boss"]
	if "core" in room_id:
		return CELL_COLORS["save"]
	return CELL_COLORS["visited"]

func _is_adjacent_to_visited(grid_pos: Vector2i) -> bool:
	var neighbors := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for n in neighbors:
		var adj := grid_pos + n
		for room_id in ROOM_GRID:
			if ROOM_GRID[room_id] == adj and room_id in GameManager.visited_rooms:
				return true
	return false

func _room_has_fragment(room_id: String) -> bool:
	## Fragments are named by room in most cases
	for frag_id in GameManager.collected_fragments:
		if room_id.replace("room_", "") in frag_id:
			return true
	return false
