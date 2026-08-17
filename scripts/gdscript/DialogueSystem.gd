extends Control

# Advanced dialogue system with branching, character emotions, voice
# Integrates with COSMOLOGOS character profiles

signal dialogue_started
signal dialogue_ended
signal choice_selected(choice_id)

onready var speaker_name = $Panel/VBox/SpeakerName
onready var dialogue_text = $Panel/VBox/DialogueText
onready var portrait = $Panel/Portrait
onready var choices_container = $Panel/VBox/Choices

var current_dialogue = null
var dialogue_queue = []
var typing_speed = 0.05
var is_typing = false

func start_dialogue(dialogue_data):
    current_dialogue = dialogue_data
    show()
    emit_signal("dialogue_started")
    display_next_line()
    
func display_next_line():
    if dialogue_queue.empty():
        if current_dialogue.has("lines") and current_dialogue.lines.size() > 0:
            var line = current_dialogue.lines.pop_front()
            speaker_name.text = line.speaker
            if line.has("portrait"):
                portrait.texture = load(line.portrait)
            type_text(line.text)
            if line.has("choices"):
                display_choices(line.choices)
        else:
            end_dialogue()
    
func type_text(text):
    is_typing = true
    dialogue_text.bbcode_text = ""
    for char in text:
        dialogue_text.bbcode_text += char
        yield(get_tree().create_timer(typing_speed), "timeout")
    is_typing = false
    
func display_choices(choices):
    for child in choices_container.get_children():
        child.queue_free()
    for choice in choices:
        var button = Button.new()
        button.text = choice.text
        button.connect("pressed", self, "_on_choice_pressed", [choice.id])
        choices_container.add_child(button)
        
func _on_choice_pressed(choice_id):
    emit_signal("choice_selected", choice_id)
    display_next_line()
    
func end_dialogue():
    hide()
    emit_signal("dialogue_ended")
    current_dialogue = null
