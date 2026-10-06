class_name NorfolkWorldStreamer
extends Node3D

@export_group("Coordinates")
@export var norfolk_lat: float = 36.8468
@export var norfolk_lon: float = -76.2852
@export var default_zoom: int = 16

@onready var godotiles: Node = $Godotiles

func _ready() -> void:
if godotiles:
godotiles.set("origin_latitude", norfolk_lat)
godotiles.set("origin_longitude", norfolk_lon)
godotiles.set("zoom_level", default_zoom)
godotiles.call("reload_tiles")
