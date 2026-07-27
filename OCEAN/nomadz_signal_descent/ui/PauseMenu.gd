## PauseMenu.gd
## CanvasLayer — NOMADZ: Signal Descent
## Pause menu: resume, save, codex, settings, quit.
## VultureCode / Sol / NOMADZ Universe

class_name PauseMenu
extends CanvasLayer

@onready var panel          : Control       = $Panel
@onready var resume_btn     : Button        = $Panel/VBox/ResumeBtn
@onready var save_btn       : Button        = $Panel/VBox/SaveBtn
@onready var codex_btn      : Button        = $Panel/VBox/CodexBtn
@onready var settings_btn   : Button        = $Panel/VBox/SettingsBtn
@onready var quit_btn       : Button        = $Panel/VBox/QuitBtn

@onready var codex_panel    : Control       = $CodexPanel
@onready var codex_list     : ItemList      = $CodexPanel/List
@onready var codex_text     : RichTextLabel = $CodexPanel/Text
@onready var codex_back_btn : Button        = $CodexPanel/BackBtn

@onready var settings_panel : Control       = $SettingsPanel
@onready var master_slider  : HSlider       = $SettingsPanel/MasterSlider
@onready var music_slider   : HSlider       = $SettingsPanel/MusicSlider
@onready var sfx_slider     : HSlider       = $SettingsPanel/SFXSlider
@onready var settings_back  : Button        = $SettingsPanel/BackBtn

const DEBUG_MODE := false

func _ready() -> void:
	layer = 10
	visible = false
	_connect_buttons()
	if is_instance_valid(codex_panel):
		codex_panel.visible = false
	if is_instance_valid(settings_panel):
		settings_panel.visible = false

func _connect_buttons() -> void:
	_safe_connect(resume_btn,    "pressed", _on_resume)
	_safe_connect(save_btn,      "pressed", _on_save)
	_safe_connect(codex_btn,     "pressed", _on_open_codex)
	_safe_connect(settings_btn,  "pressed", _on_open_settings)
	_safe_connect(quit_btn,      "pressed", _on_quit)
	_safe_connect(codex_back_btn,"pressed", _on_close_codex)
	_safe_connect(settings_back, "pressed", _on_close_settings)
	_safe_connect(codex_list,    "item_selected", _on_codex_entry_selected)
	_safe_connect(master_slider, "value_changed", func(v): AudioManager.set_master_volume(v))
	_safe_connect(music_slider,  "value_changed", func(v): AudioManager.set_music_volume(v))
	_safe_connect(sfx_slider,    "value_changed", func(v): AudioManager.set_sfx_volume(v))

func _safe_connect(node: Node, sig: String, callable: Callable) -> void:
	if is_instance_valid(node) and node.has_signal(sig):
		node.connect(sig, callable)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume()
		else:
			_open()

func _open() -> void:
	visible = true
	GameManager.set_pause(true)
	AudioManager.play_sfx("ui_confirm")
	if is_instance_valid(resume_btn):
		resume_btn.grab_focus()

func _on_resume() -> void:
	visible = false
	GameManager.set_pause(false)
	AudioManager.play_sfx("ui_cancel")

func _on_save() -> void:
	GameManager.save_game()
	AudioManager.play_sfx("save_point")
	if is_instance_valid(save_btn):
		save_btn.text = "SYNCED ✓"
		await get_tree().create_timer(1.5).timeout
		save_btn.text = "SYNC TO MOTHER BRAIN"

func _on_open_codex() -> void:
	if not is_instance_valid(codex_panel):
		return
	codex_panel.visible = true
	_populate_codex()
	if is_instance_valid(panel):
		panel.visible = false

func _populate_codex() -> void:
	if not is_instance_valid(codex_list):
		return
	codex_list.clear()
	var discovered := LoreDatabase.get_discovered_entries()
	for entry_id in discovered:
		var entry := LoreDatabase.get_entry(entry_id)
		if entry.is_empty():
			continue
		var idx := codex_list.add_item("[%s] %s" % [entry.get("category", "?"), entry.get("title", "?")])
		codex_list.set_item_metadata(idx, entry_id)
	if discovered.is_empty() and is_instance_valid(codex_text):
		codex_text.text = "[No BRAIN-FOOD logs recovered yet. Explore deeper.]"

func _on_codex_entry_selected(index: int) -> void:
	if not is_instance_valid(codex_list) or not is_instance_valid(codex_text):
		return
	var entry_id : String = codex_list.get_item_metadata(index)
	var entry    := LoreDatabase.get_entry(entry_id)
	if entry.is_empty():
		return
	codex_text.text = "[b]%s[/b]\n[i]%s[/i]\n\n%s" % [
		entry.get("title", "???"),
		entry.get("category", ""),
		entry.get("text", "")
	]

func _on_close_codex() -> void:
	if is_instance_valid(codex_panel):
		codex_panel.visible = false
	if is_instance_valid(panel):
		panel.visible = true

func _on_open_settings() -> void:
	if not is_instance_valid(settings_panel):
		return
	settings_panel.visible = true
	if is_instance_valid(panel):
		panel.visible = false
	## Sync sliders
	if is_instance_valid(master_slider):
		master_slider.value = AudioManager.master_volume
	if is_instance_valid(music_slider):
		music_slider.value  = AudioManager.music_volume
	if is_instance_valid(sfx_slider):
		sfx_slider.value    = AudioManager.sfx_volume

func _on_close_settings() -> void:
	if is_instance_valid(settings_panel):
		settings_panel.visible = false
	if is_instance_valid(panel):
		panel.visible = true

func _on_quit() -> void:
	GameManager.save_game()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
