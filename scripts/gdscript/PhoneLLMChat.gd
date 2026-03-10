extends Control

const LLM_URL := "http://127.0.0.1:3100/phone_llm_completion"

var http: HTTPRequest
var input_box: LineEdit
var send_button: Button
var output_box: RichTextLabel

func _ready() -> void:
    # Create UI and HTTP node if they don't exist
    if not has_node("HTTPRequest"):
        http = HTTPRequest.new()
        add_child(http)
        http.name = "HTTPRequest"
    else:
        http = $HTTPRequest

    var vbox: VBoxContainer
    if not has_node("VBox"):
        vbox = VBoxContainer.new()
        vbox.name = "VBox"
        vbox.anchor_left = 0.05
        vbox.anchor_right = 0.95
        vbox.anchor_top = 0.05
        vbox.anchor_bottom = 0.95
        vbox.offset_left = 0
        vbox.offset_right = 0
        vbox.offset_top = 0
        vbox.offset_bottom = 0
        add_child(vbox)

        input_box = LineEdit.new()
        input_box.name = "Input"
        input_box.placeholder_text = "Type prompt and press Enter..."
        vbox.add_child(input_box)

        send_button = Button.new()
        send_button.name = "Send"
        send_button.text = "Send"
        vbox.add_child(send_button)

        output_box = RichTextLabel.new()
        output_box.name = "Output"
        output_box.fit_content_height = true
        output_box.scroll_active = true
        output_box.scroll_following = true
        vbox.add_child(output_box)
    else:
        vbox = $VBox
        input_box = vbox.get_node("Input")
        send_button = vbox.get_node("Send")
        output_box = vbox.get_node("Output")

    send_button.pressed.connect(_on_send_pressed)
    input_box.text_submitted.connect(_on_input_submitted)
    http.request_completed.connect(_on_request_completed)

func _on_input_submitted(text: String) -> void:
    _send_prompt(text)

func _on_send_pressed() -> void:
    _send_prompt(input_box.text)

func _send_prompt(prompt: String) -> void:
    prompt = prompt.strip_edges()
    if prompt.is_empty():
        return

    send_button.disabled = true
    output_box.append_text("[YOU] " + prompt + "
")
    input_box.clear()

    var body := {
        "prompt": prompt,
        "n_predict": 256
    }
    var headers := ["Content-Type: application/json"]
    var err := http.request(
        LLM_URL,
        headers,
        HTTPClient.METHOD_POST,
        JSON.stringify(body)
    )
    if err != OK:
        output_box.append_text("[ERROR] HTTP request failed: %s
" % err)
        send_button.disabled = false

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    send_button.disabled = false

    if result != HTTPRequest.RESULT_SUCCESS:
        output_box.append_text("[ERROR] Request result: %s
" % result)
        return

    if response_code < 200 or response_code >= 300:
        output_box.append_text("[ERROR] HTTP %d
" % response_code)
        return

    var text := body.get_string_from_utf8()
    var json := JSON.new()
    var err := json.parse(text)
    if err != OK:
        output_box.append_text("[ERROR] JSON parse: %s
Raw: %s
" % [err, text])
        return

    var data = json.data
    var reply := ""
    if typeof(data) == TYPE_DICTIONARY and data.has("content"):
        reply = str(data["content"])
    else:
        reply = text

    output_box.append_text("[LLM] " + reply + "

")