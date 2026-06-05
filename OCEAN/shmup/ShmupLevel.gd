class_name ShmupLevel
extends Node2D

signal level_completed(score: int)
signal player_died()

@onready var player := $Player
@onready var enemy_spawner := $EnemySpawner
@onready var parallax_bg := $ParallaxBackground
@onready var scroll_speed := 100.0

var level_time := 0.0
var is_active := false

func _ready() -> void:
	if player:
		player.add_to_group("player")
	GameManager.enter_room("shmup_level")

func start_level() -> void:
	is_active = true

func _process(delta: float) -> void:
	if not is_active: return
	level_time += delta
	if parallax_bg:
		parallax_bg.scroll_offset.y -= scroll_speed * delta

func _on_player_died() -> void:
	is_active = false
	player_died.emit()

func _on_level_end_triggered() -> void:
	is_active = false
	var score := player.score if player else 0
	level_completed.emit(score)
