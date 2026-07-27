extends VBoxContainer

@onready var prompt_box: TextEdit = $PromptBox
@onready var send_button: Button = $SendButton
@onready var output_box: TextEdit = $OutputBox

var llm_client: Node

func _ready() -> void:
    output_box.readonly = true
    llm_client = LLMClient.new()
    add_child(llm_client)
    send_button.pressed.connect(_on_send_pressed)

func _on_send_pressed() -> void:
    var prompt := prompt_box.text.strip_edges()
    if prompt.is_empty():
        return
    output_box.text += "
[You]
" + prompt + "
"
    output_box.text += "[LLM]
...thinking...
"
    llm_client.complete(prompt, func(reply: String) -> void:
        # replace last placeholder with real reply
        output_box.text = output_box.text.rsplit("[LLM]
", false, 1)[0] + "[LLM]
" + reply + "
"
        output_box.scroll_vertical = output_box.get_line_count()
    )