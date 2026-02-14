# https://developers.google.com/maps/documentation/urls/get-started
extends Node


class Location:
	var query: String
	## https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder
	var place_id: String

	func _init(query := "", place_id := "") -> void:
		self.query = query
		self.place_id = place_id

	func get_parameters(query: String, id: String) -> Dictionary:
		var parameters := {}
		if self.query:
			parameters[query] = self.query
		if self.place_id:
			parameters[id] = self.place_id
		return parameters

	## Create location using latitude and longitude.
	static func from_coord(latitude: float, longitude: float) -> Location:
		return Location.new("%f,%f" % [latitude, longitude])


enum TravelMode {
	DRIVING,
	WALKING,
	BICYCLING,
	TRANSIT,
	NONE,
}

enum BaseMap {
	ROADMAP,
	SATELLITE,
	TERRAIN,
	DEFAULT,
}

enum Layer {
	TRANSIT,
	TRAFFIC,
	BICYCLING,
	NONE,
}

const API_ACTION := {
	Search = "https://www.google.com/maps/search/?",
	Directions = "https://www.google.com/maps/dir/?",
	Display = "https://www.google.com/maps/@?",
	StreetView = "https://www.google.com/maps/@?",
}

const TRAVEL_MODES := [
	"driving",
	"walking",
	"bicycling",
	"tranist",
]

const BASE_MAP := [
	"roadmap",
	"satellite",
	"terrain",
]

const LAYER := [
	"transit",
	"traffic",
	"bicycling",
]


## https://developers.google.com/maps/documentation/urls/get-started#search-action
func search(location: Location) -> int:
	var params := {api = 1}
	params.merge(location.get_parameters("query", "place_id"))
	var uri := API_ACTION.Search + _paramaterise(params)
	return OS.shell_open(uri)


## https://developers.google.com/maps/documentation/urls/get-started#directions-action
func directions(
	origin: Location,
	destination: Location,
	mode := TravelMode.NONE,
	navigate: bool = true,
	waypoints: Array[Location] = [],
	avoid: int = 0
) -> int:
	var params := {api = 1}
	params.merge(origin.get_parameters("origin", "origin_place_id"))
	params.merge(destination.get_parameters("destination", "destination_place_id"))
	if mode != TravelMode.NONE:
		params.merge({travelmode = TRAVEL_MODES[mode]})
	if navigate:
		params.merge({dir_action = "navigate"})
	if waypoints:
		params.merge(_get_waypoints(waypoints))
	if avoid:
		params.merge({avoid = _parse_avoid(avoid)})
	var uri := API_ACTION.Directions + _paramaterise(params)
	return OS.shell_open(uri)


## https://developers.google.com/maps/documentation/urls/get-started#map-action
func map(
	center: Location,
	zoom: int = -1,
	base_map: BaseMap = BaseMap.DEFAULT,
	layer: Layer = Layer.NONE,
) -> int:
	var params := {api = 1, map_action = "map"}
	if center:
		params.merge({center = center.query.uri_encode()})
	if zoom > -1:
		params.merge({zoom = zoom})
	if base_map != BaseMap.DEFAULT:
		params.merge({basemap = BASE_MAP[base_map]})
	if layer != Layer.NONE:
		params.merge({layer = LAYER[layer]})
	var uri := API_ACTION.Display + _paramaterise(params)
	return OS.shell_open(uri)


## https://developers.google.com/maps/documentation/urls/get-started#street-view-action
func street_view(viewpoint: Location, heading := 0, pitch := 0, fov := 0) -> int:
	var params := {api = 1, map_action = "pano"}
	params.merge(viewpoint.get_parameters("viewpoint", "pano"))
	if heading:
		params.merge({heading = heading})
	if pitch:
		params.merge({pitch = pitch})
	if fov:
		params.merge({fov = fov})
	var uri := API_ACTION.StreetView + _paramaterise(params)
	return OS.shell_open(uri)


func get_avoid(ferries := false, highways := false, tolls := false) -> int:
	var avoid := 0
	avoid |= int(ferries) << 1
	avoid |= int(highways) << 2
	avoid |= int(tolls) << 3
	return avoid


## Convert a parameters dictionary to a string.
func _paramaterise(params: Dictionary) -> String:
	var pairs := PackedStringArray()
	for key in params:
		pairs.push_back("%s=%s" % [key, params[key]])
	return "&".join(pairs)


## Convert a list of locations to waypoint parameters.
func _get_waypoints(waypoints: Array[Location]) -> Dictionary:
	var queries := PackedStringArray()
	var ids := PackedStringArray()
	for waypoint in waypoints:
		queries.push_back(waypoint.query)
		ids.push_back(waypoint.place_id)
	return {
		waypoints = ("|".join(queries)).uri_encode(),
		waypoint_place_ids = ("|".join(ids)).uri_encode(),
	}


func _parse_avoid(avoid: int) -> String:
	var avoidances := PackedStringArray()
	if avoid & 1:
		avoidances.push_back("ferries")
	if avoid & 2:
		avoidances.push_back("highways")
	if avoid & 4:
		avoidances.push_back("tolls")
	return (",".join(avoidances)).uri_encode()
