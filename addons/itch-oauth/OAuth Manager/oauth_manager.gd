extends CanvasLayer

@onready var popup: Control = $Popup

var _continue_button: Button
var _cancel_button: Button
var _key_line: LineEdit

var current_user: ItchUser = null

signal user_logged_in
signal user_logged_out
signal login_failed

var _failed := false

func _ready() -> void:
	_continue_button = popup.get_node("%ContinueButton")
	_cancel_button = popup.get_node("%CancelButton")
	_key_line = popup.get_node("%KeyLine")
	
	_continue_button.pressed.connect(_complete_popup)
	_cancel_button.pressed.connect(_hide_popup)

func login_user(client_id: String) -> void:
	if current_user != null:
		push_error("Only one user can be logged in at a time")
		return
	_failed = false
	OS.shell_open("https://itch.io/user/oauth?client_id=" + client_id + "&scope=profile%3Ame&response_type=token&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob")
	_show_popup()

func logout_current_user():
	current_user = null
	user_logged_out.emit()

func update_user_data(user: ItchUser):
	var request := HTTPRequest.new()
	request.request_completed.connect(_handle_response.bind(user, request))
	add_child(request)
	request.request("https://itch.io/api/1/%s/me" % user.access_token)

func _handle_response(result, response_code, headers, body, user: ItchUser, request: HTTPRequest):
	var _success = user._handle_response(result, response_code, headers, body)
	if _success != OK:
		_failed = true
	_emit_signals(user)
	request.queue_free()

func _show_popup() -> void:
	popup.get_node("AnimationPlayer").play("popup")

func _hide_popup() -> void:
	popup.get_node("AnimationPlayer").play_backwards("popup")
	_key_line.text = ""

func _complete_popup() -> void:
	var token := _key_line.text
	if token == "": return
	_hide_popup()
	_handle_token(token)

func _emit_signals(user):
	if _failed:
		push_error("OAuth login failed")
		login_failed.emit()
	else:
		current_user = user
		user_logged_in.emit()

func _handle_token(token: String) -> void:
	var new_user = ItchUser.new()
	new_user.access_token = token
	update_user_data(new_user)
