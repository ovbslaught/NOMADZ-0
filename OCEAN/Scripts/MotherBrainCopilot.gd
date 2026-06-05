extends Node
# MOTHER-BRAIN Local Copilot Interface
# Ties into the LLM/VULTURE narrative layer

func _ready():
    print("[MOTHER-BRAIN]: SOL Life signs detected. Substrate healthy.")

func log_action(action: String):
    # In a full build, this sends a tensor or log string to the WAL SQLite DB
    print("[MOTHER-BRAIN TELEMETRY]: ", action)

func provide_hint():
    if not GameManager.has_double_jump:
        print("[MOTHER-BRAIN]: Scans indicate a mobility tech cache nearby. Seek higher ground.")
