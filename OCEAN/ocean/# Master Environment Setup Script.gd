# Master Environment Setup Script
# Attach this to your main root node (e.g., a StaticBody3D or Node in 2D/3D).
extends Node

func _ready():
	setup_environment()
	setup_lighting()
	setup_camera()
	setup_player()
	setup_ui()
	setup_terrain()

func setup_environment():
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = ProceduralSky.new()
	var env_res = ResourceLoader.load("res://default_env.tres")
	if env_res: env = env_res
	get_viewport().environment = env

func setup_lighting():
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 0, 0)
	sun.light_energy = 1.5
	sun.name = "Sun"
	add_child(sun)

func setup_camera():
	var camera = Camera3D.new()
	camera.fov = 70
	camera.position = Vector3(0, 10, -20)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	camera.name = "MainCamera"
	add_child(camera)

func setup_player():
	var player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 0)
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	player.add_child(mesh)
	add_child(player)
	# Optional: Attach movement script, Camera follow, etc.

func setup_ui():
	var canvas = CanvasLayer.new()
	var label = Label.new()
	label.text = "Score: 0"
	label.anchor_left = 0.05
	label.anchor_top = 0.05
	label.add_theme_font_size_override("font_size", 32)
	canvas.add_child(label)
	add_child(canvas)

func setup_terrain():
	var terrain = MeshInstance3D.new()
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(100, 100)
	terrain.mesh = mesh
	terrain.position = Vector3(0, 0, 0)
	terrain.name = "Terrain"
	add_child(terrain)
