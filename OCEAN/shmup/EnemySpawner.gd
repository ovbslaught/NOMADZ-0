class_name EnemySpawner
extends Node2D

@export var spawn_interval := 1.5
@export var enemy_scene: PackedScene
@export var spawn_area: Rect2 = Rect2(50, -600, 700, 100)

@onready var spawn_timer := $SpawnTimer

var difficulty_mult := 1.0
var _spawn_count := 0

func _ready() -> void:
	_ensure_timer("SpawnTimer", spawn_interval, false)
	if spawn_timer:
		spawn_timer.timeout.connect(_spawn_enemy)

func _ensure_timer(name: String, wait: float, one_shot: bool) -> void:
	if not has_node(name):
		var t := Timer.new()
		t.name = name
		t.wait_time = wait
		t.one_shot = one_shot
		add_child(t)

func start_spawning() -> void:
	if spawn_timer:
		spawn_timer.start()

func stop_spawning() -> void:
	if spawn_timer:
		spawn_timer.stop()

func _spawn_enemy() -> void:
	var x := randf_range(spawn_area.position.x, spawn_area.end.x)
	var y := randf_range(spawn_area.position.y, spawn_area.end.y)
	if enemy_scene:
		var enemy := enemy_scene.instantiate()
		enemy.global_position = Vector2(x, y)
		add_child(enemy)
	_spawn_count += 1
	spawn_timer.wait_time = maxf(0.3, spawn_interval - (_spawn_count * 0.01) * difficulty_mult)
