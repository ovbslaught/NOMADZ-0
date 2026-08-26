class_name ItchUser
extends Resource

@export var username: String
@export var gamer: bool
@export var display_name: String
@export var cover_url: String
@export var user_url: String
@export var press_user: bool
@export var developer: bool
@export var id: int

var access_token: String

func _handle_response(result, response_code, _headers, body) -> Error:
	if (result != 0) or (response_code != 200):
		push_error("Failed to update user data. Response code %s; Result code %s" % [response_code, result])
		return ERR_CANT_CONNECT
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response: Dictionary = json.get_data()
	if response.has("errors"):
		return ERR_INVALID_DATA
	var user_data = response.user
	
	username = user_data.username
	gamer = user_data.gamer
	display_name = user_data.display_name
	cover_url = user_data.cover_url
	user_url = user_data.url
	press_user = user_data.press_user
	developer = user_data.developer
	id = user_data.id
	return OK
