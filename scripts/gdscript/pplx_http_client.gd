# pplx_http_client.gd - Perplexity HTTP client for NOMADZ-0
extends Node

const API_URL = "https://api.perplexity.ai/chat/completions"
var api_key: String = OS.get_environment("PERPLEXITY_API_KEY")

func query(prompt: String, callback: Callable) -> void:
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(func(result, code, headers, body):
        var j = JSON.parse_string(body.get_string_from_utf8())
        callback.call(j.choices[0].message.content)
        http.queue_free()
    )
    var hdrs = ["Authorization: Bearer "+api_key, "Content-Type: application/json"]
    var pl = JSON.stringify({"model":"llama-3.1-sonar-large-128k-online","messages":[{"role":"user","content":prompt}]})
    http.request(API_URL, hdrs, HTTPClient.METHOD_POST, pl)
