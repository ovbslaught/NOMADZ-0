class_name MainSceneController
extends Node3D

@export var player_node_path: NodePath
@export var suit_controller_path: NodePath
@export var gis_importer_path: NodePath
@export var telemetry_enabled: bool = true

var player_node: CharacterBody3D
var suit_controller: SuitController
var gis_importer: NorfolkGISTerrainImporter

func _ready() -> void:
	_initialize_components()
	_boot_system_sequence()
	
func _initialize_components() -> void:
	if not player_node_path.is_empty():
		player_node = get_node_or_null(player_node_path) as CharacterBody3D
	if not suit_controller_path.is_empty():
		suit_controller = get_node_or_null(suit_controller_path) as SuitController
	if not gis_importer_path.is_empty():
		gis_importer = get_node_or_null(gis_importer_path) as NorfolkGISTerrainImporter

func _boot_system_sequence() -> void:
	print("[MainScene] Booting NOMADZ-0 Master Scene Substrate...")
	
	if gis_importer:
		gis_importer.generate_gis_terrain()
		
	if suit_controller:
		# Default boot form: Meka Heavy Suit using PLAYER-1/meka.glb
		suit_controller.set_suit_form(SuitController.SuitForm.MEKA_HEAVY)
		print("[MainScene] Player initialized with MEKA_HEAVY suit configuration.")
		
	if telemetry_enabled:
		print("[MainScene] AI Telemetry loop active on TCP 127.0.0.1:11033 & WS 127.0.0.1:9080.")
