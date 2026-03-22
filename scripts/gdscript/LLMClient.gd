## LLMClient.gd — NOMADZ-0 Multi-Provider LLM Client
## Autoload as: LLMClient
## Supports: llama.cpp local, Gemini REST, OpenAI-compatible (OpenRouter, etc.)
##
## Usage:
##   LLMClient.complete("your prompt", func(reply): print(reply))
##   LLMClient.complete("your prompt", func(reply): print(reply), {"system": "You are Mother-Brain."})
##
## Configure via @export or by editing PROVIDER / API_KEY below.

extends Node

# ─── PROVIDER CONFIG ────────────────────────────────────────────────────────
enum Provider { LLAMACPP, GEMINI, OPENAI_COMPAT }

## Change this to switch providers
@export var provider: Provider = Provider.LLAMACPP

## llama.cpp / local LLM (phone hotspot IP or localhost)
@export var llamacpp_url: String = "http://192.168.1.40:3002/completion"

## Gemini — get key from aistudio.google.com
## Model options: gemini-2.0-flash, gemini-1.5-pro, gemini-1.5-flash
@export var gemini_api_key: String = ""
@export var gemini_model: String = "gemini-2.0-flash"

## OpenAI-compatible (OpenRouter, local Ollama openai endpoint, etc.)
## OpenRouter: base = "https://openrouter.ai/api/v1"
## Ollama:     base = "http://localhost:11434/v1"
@export var openai_base_url: String = "https://openrouter.ai/api/v1"
@export var openai_api_key: String = ""   # sk-or-... for OpenRouter
@export var openai_model: String = "meta-llama/llama-3.1-8b-instruct:free"

## Default system prompt (Mother-Brain persona)
@export_multiline var default_system_prompt: String = \
	"You are Mother-Brain, the AI copilot of NOMADZ-0. " + \
	"You assist Sol, the player operative. Be concise, tactical, and direct. " + \
	"Respond in plain text only. No markdown, no asterisks."

## Max tokens to generate
@export var max_tokens: int = 256

# ─── SIGNALS ────────────────────────────────────────────────────────────────
signal response_ready(text: String)
signal request_failed(error: String)

# ─── INTERNALS ──────────────────────────────────────────────────────────────
var _http: HTTPRequest
var _pending_callback: Callable
var _busy: bool = false
var _queue: Array = []  # [{prompt, callback, opts}]

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	print("[LLMClient] Ready. Provider: ", Provider.keys()[provider])

# ─── PUBLIC API ──────────────────────────────────────────────────────────────

## complete(prompt, callback, opts)
## opts: {"system": str, "max_tokens": int}
## callback receives a single String argument (the LLM reply)
func complete(prompt: String, callback: Callable, opts: Dictionary = {}) -> void:
	if _busy:
		_queue.append({"prompt": prompt, "callback": callback, "opts": opts})
		return
	_dispatch(prompt, callback, opts)

## One-shot chat with message history
## messages: [{"role": "user"|"assistant"|"system", "content": str}]
func chat(messages: Array, callback: Callable, opts: Dictionary = {}) -> void:
	if _busy:
		_queue.append({"messages": messages, "callback": callback, "opts": opts})
		return
	_dispatch_chat(messages, callback, opts)

# ─── DISPATCH ────────────────────────────────────────────────────────────────

func _dispatch(prompt: String, callback: Callable, opts: Dictionary) -> void:
	_busy = true
	_pending_callback = callback

	var system := opts.get("system", default_system_prompt) as String
	var tokens := opts.get("max_tokens", max_tokens) as int

	match provider:
		Provider.LLAMACPP:
			_send_llamacpp(prompt, system, tokens)
		Provider.GEMINI:
			_send_gemini(prompt, system, tokens)
		Provider.OPENAI_COMPAT:
			_send_openai([
				{"role": "system", "content": system},
				{"role": "user", "content": prompt}
			], tokens)

func _dispatch_chat(messages: Array, callback: Callable, opts: Dictionary) -> void:
	_busy = true
	_pending_callback = callback

	var tokens := opts.get("max_tokens", max_tokens) as int

	match provider:
		Provider.LLAMACPP:
			# llama.cpp doesn't support chat format natively — flatten to prompt
			var flat := ""
			for msg in messages:
				flat += "[%s]: %s\n" % [str(msg.get("role", "user")).to_upper(), str(msg.get("content", ""))]
			flat += "[ASSISTANT]:"
			_send_llamacpp(flat, "", tokens)
		Provider.GEMINI:
			_send_gemini_chat(messages, tokens)
		Provider.OPENAI_COMPAT:
			_send_openai(messages, tokens)

# ─── LLAMACPP ────────────────────────────────────────────────────────────────
# API: POST /completion
# Body: {"prompt": str, "n_predict": int}
# NOTE: does NOT accept "stream" field — streaming uses a different endpoint

func _send_llamacpp(prompt: String, system: String, tokens: int) -> void:
	var full_prompt := prompt
	if system.length() > 0:
		full_prompt = "<<SYS>>\n%s\n<</SYS>>\n\n%s" % [system, prompt]

	var body := {
		"prompt": full_prompt,
		"n_predict": tokens,
		"temperature": 0.7,
		"stop": ["[/INST]", "</s>", "[YOU]", "[USER]"]
		# NOTE: "stream" is NOT included — streaming requires EventSource, not HTTPRequest
	}

	_fire_request(llamacpp_url, ["Content-Type: application/json"], body)

# ─── GEMINI ──────────────────────────────────────────────────────────────────
# API: POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}
# Body: {"contents": [{"parts": [{"text": str}]}], "generationConfig": {...}}
# IMPORTANT: "stream" is NOT a field — use :streamGenerateContent endpoint for streaming
# IMPORTANT: system instruction is a separate top-level field, NOT inside contents

func _send_gemini(prompt: String, system: String, tokens: int) -> void:
	if gemini_api_key.is_empty():
		_fail("Gemini API key not set. Add it to LLMClient.gemini_api_key or set GEMINI_API_KEY in env.")
		return

	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" \
		% [gemini_model, gemini_api_key]

	var body: Dictionary = {
		"contents": [
			{
				"role": "user",
				"parts": [{"text": prompt}]
			}
		],
		"generationConfig": {
			"maxOutputTokens": tokens,
			"temperature": 0.7
		}
		# NOTE: "stream" field does NOT exist here — causes 400 INVALID_ARGUMENT
	}

	# System instruction is a separate top-level key (not inside contents)
	if system.length() > 0:
		body["systemInstruction"] = {
			"parts": [{"text": system}]
		}

	var headers := [
		"Content-Type: application/json"
		# No Authorization header needed — key is in URL query param
	]

	_fire_request(url, headers, body)

func _send_gemini_chat(messages: Array, tokens: int) -> void:
	if gemini_api_key.is_empty():
		_fail("Gemini API key not set.")
		return

	var url := "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s" \
		% [gemini_model, gemini_api_key]

	var contents := []
	var system_text := ""

	for msg in messages:
		var role: String = msg.get("role", "user")
		var content: String = msg.get("content", "")
		if role == "system":
			system_text = content  # Gemini handles system separately
			continue
		# Gemini uses "user" and "model" roles (not "assistant")
		var gemini_role := "model" if role == "assistant" else "user"
		contents.append({
			"role": gemini_role,
			"parts": [{"text": content}]
		})

	var body: Dictionary = {
		"contents": contents,
		"generationConfig": {
			"maxOutputTokens": tokens,
			"temperature": 0.7
		}
	}

	if system_text.length() > 0:
		body["systemInstruction"] = {
			"parts": [{"text": system_text}]
		}

	_fire_request(url, ["Content-Type: application/json"], body)

# ─── OPENAI-COMPATIBLE ───────────────────────────────────────────────────────
# API: POST {base}/chat/completions
# Body: {"model": str, "messages": [...], "max_tokens": int}
# Works with: OpenRouter, Ollama /v1, LM Studio, Together AI, etc.

func _send_openai(messages: Array, tokens: int) -> void:
	var url := openai_base_url.rstrip("/") + "/chat/completions"

	var body := {
		"model": openai_model,
		"messages": messages,
		"max_tokens": tokens,
		"temperature": 0.7
		# NOTE: "stream" is intentionally omitted — streaming not supported via HTTPRequest
	}

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + openai_api_key
	]

	# OpenRouter requires these headers for usage tracking
	if "openrouter" in openai_base_url:
		headers.append("HTTP-Referer: https://github.com/ovbslaught/NOMADZ-0")
		headers.append("X-Title: NOMADZ-0")

	_fire_request(url, headers, body)

# ─── CORE HTTP ───────────────────────────────────────────────────────────────

func _fire_request(url: String, headers: Array, body: Dictionary) -> void:
	var json_body := JSON.stringify(body)
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		_fail("HTTPRequest.request() error code: %d" % err)

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body_bytes: PackedByteArray
) -> void:
	var callback := _pending_callback
	_busy = false
	_pending_callback = Callable()

	# Drain queue
	if _queue.size() > 0:
		var next = _queue.pop_front()
		if next.has("messages"):
			_dispatch_chat(next.messages, next.callback, next.opts)
		else:
			_dispatch(next.prompt, next.callback, next.opts)

	if result != HTTPRequest.RESULT_SUCCESS:
		var err := "Network error (result=%d)" % result
		push_error("[LLMClient] %s" % err)
		request_failed.emit(err)
		if callback.is_valid():
			callback.call("[ERROR] %s" % err)
		return

	var raw := body_bytes.get_string_from_utf8()

	if response_code < 200 or response_code >= 300:
		var err := "HTTP %d: %s" % [response_code, raw.substr(0, 200)]
		push_error("[LLMClient] %s" % err)
		request_failed.emit(err)
		if callback.is_valid():
			callback.call("[ERROR] HTTP %d — check API key / model name" % response_code)
		return

	var text := _parse_response(raw)
	response_ready.emit(text)
	if callback.is_valid():
		callback.call(text)

func _parse_response(raw: String) -> String:
	var data = JSON.parse_string(raw)
	if data == null:
		return raw  # Not JSON, return raw

	if typeof(data) != TYPE_DICTIONARY:
		return raw

	# llama.cpp format: {"content": "..."}
	if data.has("content"):
		return str(data["content"])

	# OpenAI format: {"choices": [{"message": {"content": "..."}}]}
	if data.has("choices"):
		var choices = data["choices"]
		if typeof(choices) == TYPE_ARRAY and choices.size() > 0:
			var first = choices[0]
			if typeof(first) == TYPE_DICTIONARY:
				if first.has("message") and typeof(first["message"]) == TYPE_DICTIONARY:
					return str(first["message"].get("content", ""))
				if first.has("text"):  # older completions endpoint
					return str(first["text"])

	# Gemini format: {"candidates": [{"content": {"parts": [{"text": "..."}]}}]}
	if data.has("candidates"):
		var candidates = data["candidates"]
		if typeof(candidates) == TYPE_ARRAY and candidates.size() > 0:
			var c = candidates[0]
			if typeof(c) == TYPE_DICTIONARY and c.has("content"):
				var content = c["content"]
				if typeof(content) == TYPE_DICTIONARY and content.has("parts"):
					var parts = content["parts"]
					if typeof(parts) == TYPE_ARRAY and parts.size() > 0:
						return str(parts[0].get("text", ""))

	# Error format from Gemini/OpenAI
	if data.has("error"):
		var e = data["error"]
		if typeof(e) == TYPE_DICTIONARY:
			return "[LLM ERROR] %s" % str(e.get("message", e))
		return "[LLM ERROR] %s" % str(e)

	return raw  # Fallback

func _fail(msg: String) -> void:
	push_error("[LLMClient] %s" % msg)
	request_failed.emit(msg)
	_busy = false
	if _pending_callback.is_valid():
		_pending_callback.call("[ERROR] %s" % msg)
	_pending_callback = Callable()
