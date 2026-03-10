extends Control

@onready var http: HTTPRequest = $HTTPRequest
@onready var input_box: LineEdit = $VBox/Input
@onready var send_button: Button = $VBox/Send
@onready var output_box: RichTextLabel = $VBox/Output

const LLM_URL := "http://127.0.0.1:3100/phone_llm_completion"

func _ready() -> void:
    send_button.pressed.connect(_on_send_pressed)
    http.request_completed.connect(_on_request_completed)

func _on_send_pressed() -> void:
    var prompt := input_box.text.strip_edges()
    if prompt.is_empty():
        return

    send_button.disabled = true
    output_box.append_text("[YOU] " + prompt + "
")

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