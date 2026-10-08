# LLMClient.gd — Setup Guide

## Quickstart (3 paths)

---

### PATH 1: Local llama.cpp on your phone (current setup)
Your phone runs llama.cpp server on port 3002. Godot talks to it over LAN.

```
# In LLMClient (autoload):
provider = Provider.LLAMACPP
llamacpp_url = "http://192.168.1.40:3002/completion"
```

**Why it was breaking:** Something was injecting `"stream": true` into the request body.
llama.cpp's `/completion` endpoint does NOT accept a `"stream"` field — streaming
uses a different endpoint (`/completion` with `stream: true` in the body IS actually
valid for newer llama.cpp, but only works with EventSource/SSE, not HTTPRequest).
The fixed client never sends `"stream"` via HTTPRequest.

---

### PATH 2: Gemini (Google AI Studio — free tier)
1. Go to https://aistudio.google.com/app/apikey
2. Create a key, copy it
3. In LLMClient:
```
provider = Provider.GEMINI
gemini_api_key = "AIza..."       # paste your key
gemini_model = "gemini-2.0-flash"  # free + fast
```

**Why it was breaking:** The `"stream"` field doesn't exist in Gemini's
`generateContent` body. For streaming you use a different URL:
`:streamGenerateContent` — but that requires Server-Sent Events which
Godot's HTTPRequest doesn't support natively. The fixed client uses
non-streaming only via HTTPRequest.

Also: Gemini uses `"systemInstruction"` as a TOP-LEVEL key, not inside
`"contents"`. And roles are `"user"` / `"model"`, not `"user"` / `"assistant"`.

---

### PATH 3: OpenRouter (free models, cloud)
Best for development — many free models, no local setup.

1. Go to https://openrouter.ai → sign up → Keys → Create key
2. Free models: `meta-llama/llama-3.1-8b-instruct:free`,
   `mistralai/mistral-7b-instruct:free`, `google/gemini-2.0-flash-exp:free`
3. In LLMClient:
```
provider = Provider.OPENAI_COMPAT
openai_base_url = "https://openrouter.ai/api/v1"
openai_api_key = "sk-or-..."    # your OpenRouter key
openai_model = "meta-llama/llama-3.1-8b-instruct:free"
```

---

## Adding to Godot Project

1. Copy `LLMClient.gd` to `scripts/gdscript/`
2. In Godot: **Project → Project Settings → Autoload**
   - Add `LLMClient.gd`, name it `LLMClient`
3. Use from any script:
```gdscript
# Simple completion
LLMClient.complete("What's the status of Beacon-01?", func(reply):
    mother_brain_say(reply)
)

# With custom system prompt
LLMClient.complete(
    "Scan the perimeter for threats.",
    func(reply): hud.show_copilot(reply),
    {"system": "You are Mother-Brain. Report in 1 sentence. Be terse."}
)

# Chat history (OpenAI/Gemini only)
LLMClient.chat([
    {"role": "system", "content": "You are Mother-Brain."},
    {"role": "user",   "content": "What era are we in?"},
    {"role": "assistant", "content": "Iron Age. Beacon decay at 68%."},
    {"role": "user",   "content": "How long until full collapse?"}
], func(reply): print(reply))
```

## Connecting to MB_Service (recommended)

Instead of calling cloud LLMs directly from Godot, route through MB_Service
on localhost:7421 — it adds RAG context from omega_memory.db automatically:

```gdscript
# In LLMClient, set:
provider = Provider.OPENAI_COMPAT
openai_base_url = "http://localhost:7421"   # MB_Service's OpenAI-compat endpoint
openai_api_key = "nomadz-local"             # any non-empty string
openai_model = "mother-brain"
```

Or use MB_CopilotSocket.gd for the WebSocket streaming path.

## Storing your API key safely

Never hardcode keys in .gd files that get committed to GitHub.
Use one of these patterns:

```gdscript
# Option A: Environment variable (Termux sets these)
func _ready():
    gemini_api_key = OS.get_environment("GEMINI_API_KEY")

# Option B: External config file (not in repo)
func _ready():
    var cfg = ConfigFile.new()
    if cfg.load("user://llm_config.cfg") == OK:
        gemini_api_key = cfg.get_value("llm", "gemini_key", "")
```

On Android/Termux, set env vars in ~/.bashrc or ~/.profile:
```bash
export GEMINI_API_KEY="AIza..."
export OPENROUTER_KEY="sk-or-..."
```
