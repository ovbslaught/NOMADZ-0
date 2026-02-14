extends Node


func _ready() -> void:
	# Searching
	var london := GMap.Location.from_coord(51.507222, -0.1275)
	GMap.search(london)
	# Directions
	var watford := GMap.Location.new("Watford, UK")
	GMap.directions(london, watford)
	get_tree().quit()
	# Map
	var eiffel_tower := GMap.Location.from_coord(48.857832, 2.295226)
	GMap.map(eiffel_tower)
	# Street View
	GMap.street_view(eiffel_tower)
	return
