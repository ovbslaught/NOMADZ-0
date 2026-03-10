extends Node

const LLM_URL := "http://192.168.1.40:3002/completion"  # phone IP + port

@onready var http: HTTPRequest = HTTPRequest.new()

func _ready() -> void:
    add_child(http)

func complete(prompt: String, callback: Callable) -> void:
    var body := {
        "prompt": prompt,
        "n_predict": 256
    }

    if http.request(
        LLM_URL,
        ["Content-Type: application/json"],
        JSON.stringify(body),
        HTTPClient.METHOD_POST
    ) != OK:
        push_error("LLM request failed to start")
        return

    http.request_completed.connect(
        func(result: int, code: int, headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
            http.request_completed.disconnect_all()
            if code != 200:
                callback.call("HTTP error %d" % code)
                return
            var txt := body_bytes.get_string_from_utf8()
            var data = JSON.parse_string(txt)
            var content := ""
            if typeof(data) == TYPE_DICTIONARY and data.has("content"):
                content = str(data["content"])
            else:
                content = txt
            callback.call(content)
    )