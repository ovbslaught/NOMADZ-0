@tool
extends PanelContainer

@onready var icon_rect: TextureRect = %Icon
@onready var name_label: Label = %Name
@onready var content_label: RichTextLabel = %Content
@onready var plan_container: VBoxContainer = %PlanContainer
@onready var header: HBoxContainer = %Header

func setup(sender_name: String, icon: Texture2D, content: String, is_user: bool, text_color: Color) -> void:
	if not is_node_ready():
		await ready

	name_label.text = sender_name

	if icon:
		icon_rect.texture = icon
		icon_rect.show()
	else:
		icon_rect.hide()

	# Styling
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10

	if is_user:
		style.bg_color = Color(0.18, 0.25, 0.4, 0.4) # Subtle blueish for user
		content_label.text = content
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 1.0) # Slightly lighter than background
		name_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
		# Use formatted text for bot/system
		content_label.append_text(content)


	add_theme_stylebox_override("panel", style)

func append_text(text: String) -> void:
	content_label.append_text(text)

signal step_clicked(step_data: Dictionary)

func setup_plan(plan: Array[Dictionary]) -> void:
	for child in plan_container.get_children():
		child.queue_free()

	for step in plan:
		var btn = Button.new()
		btn.text = "🔘 " + step.get("title", "Execute tool")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		btn.pressed.connect(func(): step_clicked.emit(step))
		plan_container.add_child(btn)
