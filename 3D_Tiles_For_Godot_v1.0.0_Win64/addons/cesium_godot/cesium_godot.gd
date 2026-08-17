@tool
extends EditorPlugin

class_name CesiumGodotEditorTool

const editorAddon := preload("res://addons/cesium_godot/panels/cesium_panel.tscn")

const token_panel_popup := preload("res://addons/cesium_godot/panels/token_panel.tscn")

const CESIUM_GLOBE_NAME = "CesiumGeoreference"
const CESIUM_TILESET_NAME = "Cesium3DTileset"

var docked_scene : Control

var add_button : Button
var upload_button : Button
var learn_button : Button
var help_button : Button
var token_button : Button
var sign_out_button : Button
var connect_button : Button
var blank_tileset_button : Button
var dynamic_camera_button : Button
var ion_button_holder : Control

var ion_asset_buttons : Array[Button] = []

var auth_controller_node : OAuthController = null
var cesium_builder_node : CesiumGDAssetBuilder = null
var request_node : HTTPRequest = null


# So, for some reason we cannot have a custom popup because some definitions get lost in instantiation
# We don't really know why this is, but we circunvent it by just storing the data on another class
var token_panel: Popup = null

var token_panel_data : TokenPanelData = null

func _enter_tree() -> void:
	self.set_process(false)
	self.docked_scene = editorAddon.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, self.docked_scene)
	self.set_session_buttons_enabled(false)
	self.auth_controller_node = OAuthController.new()
	self.add_child(self.auth_controller_node)
	self.cesium_builder_node = CesiumGDAssetBuilder.new()
	self.add_child(self.cesium_builder_node)
	self.token_panel = self.token_panel_popup.instantiate()
	self.token_panel_data = TokenPanelData.new()
	self.add_child(self.token_panel)
	self.token_panel.hide()
	self.add_inspector_plugin(CesiumTooltips.new())
	print("Enabled Cesium plugin")
	self.request_node = HTTPRequest.new()
	self.add_child(self.request_node)
	self.init_buttons()


func _exit_tree() -> void:
	print("Disabled Cesium plugin")
	remove_control_from_docks(self.docked_scene)
	self.docked_scene.free()

func init_buttons() -> void:
	self.add_ion_buttons()
	self.add_button = self.docked_scene.find_child("AddButton") as Button
	self.upload_button = self.docked_scene.find_child("UploadButton") as Button
	self.token_button = self.docked_scene.find_child("TokenButton") as Button
	self.learn_button = self.docked_scene.find_child("LearnButton") as Button
	self.help_button = self.docked_scene.find_child("HelpButton") as Button
	self.sign_out_button = self.docked_scene.find_child("SignOutButton") as Button
	self.connect_button = self.docked_scene.find_child("ConnectButton") as Button
	self.blank_tileset_button = self.docked_scene.find_child("BlankTilesetButton") as Button
	self.dynamic_camera_button = self.docked_scene.find_child("DynamicCameraButton") as Button
	self.token_panel_data.initialize_fields(self.token_panel)
	# Connect to their signals
	self.upload_button.pressed.connect(on_upload_pressed)
	self.learn_button.pressed.connect(on_learn_pressed)
	self.help_button.pressed.connect(on_help_pressed)
	self.connect_button.pressed.connect(on_connect_pressed)
	self.sign_out_button.pressed.connect(on_sign_out_pressed)
	self.blank_tileset_button.pressed.connect(add_tileset)
	self.dynamic_camera_button.pressed.connect(create_dynamic_camera)
	self.token_button.pressed.connect(on_token_panel_pressed)

func on_token_panel_pressed() -> void:
	self.token_panel.popup()

func set_session_buttons_enabled(enabled: bool) -> void:
	var utilityButtons := self.get_utility_buttons();
	utilityButtons.append_array(self.ion_asset_buttons)
	for btn in utilityButtons:
		if btn == null: continue
		(btn as Button).disabled = !enabled

func _process(delta: float) -> void:
	if self.auth_controller_node == null:
		return
	if (self.auth_controller_node.is_signed_in):
		connect_button.text = "Connected!"
		connect_button.disabled = true
	self.set_session_buttons_enabled(self.auth_controller_node.is_signed_in)

# All of the buttons that become available once the user logs in
func get_utility_buttons() -> Array[Button]:
	return [self.add_button, self.upload_button, self.sign_out_button]

func on_upload_pressed() -> void:
	const url := "https://ion.cesium.com/addasset?"	
	OS.shell_open(url)

func on_learn_pressed() -> void:
	CesiumGDPanel.open_learn_page()

func on_help_pressed() -> void:
	CesiumGDPanel.open_help_page()

func on_connect_pressed() -> void:
	#Open the browser with a TCP server, or show the URL
	if self.auth_controller_node.is_connecting:
		self.auth_controller_node.cancel_connection()
		self.connect_button.text = "Connect to Cesium ION"
		return
	self.auth_controller_node.get_auth_code()
	self.connect_button.text = "Cancel Connecting"

func on_sign_out_pressed():
	self.auth_controller_node.sign_out()
	self.connect_button.disabled = false
	self.connect_button.text = "Connect to Cesium ION"

func on_georef_checked(is_checked: bool) -> void:
	self.cesium_builder_node.use_georeferences = is_checked

func add_tileset():
	self.cesium_builder_node.instantiate_tileset(CesiumAssetBuilder.TILESET_TYPE.Blank, "")

func create_dynamic_camera():
	print("Create dynamic camera!")
	self.cesium_builder_node.instantiate_dynamic_cam()

func add_ion_buttons() -> void:
	self.ion_button_holder = self.docked_scene.find_child("IonAssetButtonHolder") as Control
	for child in self.ion_button_holder.get_children():
		self.ion_button_holder.remove_child(child)
	
	const url := "https://api.cesium.com/v1/defaults";
	var token : String = CesiumGDConfig.get_singleton(self).accessToken;
	var headers: PackedStringArray = ["Authorization: Bearer " + token]
	var error: int = self.request_node.request(url, headers, HTTPClient.Method.METHOD_GET)
	if (error != OK):
		push_error("Error getting the asset list from Cesium: " + error_string(error))
		return
	var response = await self.request_node.request_completed
	var status = response[1]
	var bodyBytes := response[3] as PackedByteArray
	var body := JSON.parse_string(bodyBytes.get_string_from_utf8()) as Dictionary

	self.set_process(true)
	if (status >= HTTPClient.ResponseCode.RESPONSE_BAD_REQUEST):
		push_error("Error connecting to the Cesium API for assets, try signing in manually, server responded with: " + str(status) + "\nBody: " + str(body))
		return
	# For each one of the assets, parse and create a button
	var items := body.get("quickAddAssets") as Array
	if (items == null):
		push_error("Failed to parse request, in body expected \"items\", found: " + str(body))
		return
	for item in items:
		item = item as Dictionary
		var id := int(item.get("assetId"))
		var name = item.get("name")
		var type = item.get("type")
		self.ion_asset_buttons.append(self.create_ion_button(id, name, type))
		
func is_http_request_busy(http_request: HTTPRequest) -> bool:
	return http_request.get_http_client_status() in [
		HTTPClient.STATUS_CONNECTING,
		HTTPClient.STATUS_REQUESTING,
		HTTPClient.STATUS_BODY
	]

func create_ion_button(assetId: int, name: String, type: String) -> Button:
	# Create a button
	var hbox := HBoxContainer.new()
	var margin := MarginContainer.new()
	margin.custom_minimum_size.x = 10
	margin.size_flags_horizontal = Control.SizeFlags.SIZE_EXPAND_FILL 
	var label := Label.new()
	var button := Button.new()
	button.text = "Add"
	button.set_meta("ion_name", name)
	button.custom_minimum_size.x = 60
	label.text = name
	
	self.ion_button_holder.add_child(hbox)
	hbox.add_child(label)
	hbox.add_child(margin)
	hbox.add_child(button)
	# Connect with the signal
	button.pressed.connect(func():
		self.cesium_builder_node.instantiate_tileset(assetId, type)
	)
	return button

