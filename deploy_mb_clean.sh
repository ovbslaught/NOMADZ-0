#!/usr/bin/env bash
set -euo pipefail # Fail fast on any error

echo -e "\033[1;32m[*] PURGING OLD LOGIC & INITIALIZING MOTHER-BRAIN CORE...\033[0m"

# 1. Termux Dependencies
if command -v pkg >/dev/null 2>&1; then
    pkg update -y > /dev/null 2>&1 || true
    pkg install python git nodejs sqlite -y > /dev/null 2>&1 || true
fi
python3 -m pip install requests beautifulsoup4 > /dev/null 2>&1 || true

# 2. Dynamic WORMHOLE Pathing (Canonical)
if [ -d "$HOME/storage/shared/WORMHOLE" ]; then
    W_ROOT="$HOME/storage/shared/WORMHOLE"
elif [ -d "/sdcard/WORMHOLE" ]; then
    W_ROOT="/sdcard/WORMHOLE"
elif [ -d "$HOME/WORMHOLE" ]; then
    W_ROOT="$HOME/WORMHOLE"
else
    echo "[!] WORMHOLE not found. Run termux-setup-storage or create WORMHOLE first."
    exit 1
fi

MB_ROOT="$W_ROOT/MOTHER-BRAIN"
KNOWLEDGE_PATH="$MB_ROOT/01_KNOWLEDGE_GRAPH/EXTERNAL_SOURCE"
VAULT_PATH="$W_ROOT/-VAULT-"

echo "[*] Target Coordinates: $MB_ROOT"

# 3. Canonical Architecture
mkdir -p "$MB_ROOT/00_INBOX"
mkdir -p "$KNOWLEDGE_PATH"
mkdir -p "$MB_ROOT/04_RESEARCH"
mkdir -p "$MB_ROOT/99_SYSTEM_LOGS"
mkdir -p "$MB_ROOT/SECURITY"
mkdir -p "$VAULT_PATH"

# 4. Knowledge Injector Engine (Written to MB_ROOT to avoid Android $HOME sandbox)
cat << 'PY_INJECTOR_EOF' > "$MB_ROOT/knowledge_injector.py"
#!/usr/bin/env python3
import os
import subprocess
import json
import sqlite3

MB_ROOT = os.path.dirname(os.path.abspath(__file__))
W_ROOT = os.path.dirname(MB_ROOT)
TARGET_DIR = os.path.join(MB_ROOT, "01_KNOWLEDGE_GRAPH", "EXTERNAL_SOURCE")
DB_PATH = os.path.join(W_ROOT, "-VAULT-", "omega_memory.db")

REPOS = {
    "MCP_Servers": "https://github.com/modelcontextprotocol/servers.git",
    "Awesome_MCP": "https://github.com/punkpeye/awesome-mcp-servers.git",
    "xAI_Grok": "https://github.com/xai-org/grok-1.git"
}

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS repo_sync_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                repo_name TEXT,
                status TEXT,
                target_path TEXT
            );
        """)

def log_sync(repo, status, path):
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute("INSERT INTO repo_sync_log (repo_name, status, target_path) VALUES (?, ?, ?)", (repo, status, path))
    except Exception as e:
        print(f"[!] DB Error: {e}")

def run():
    init_db()
    os.makedirs(TARGET_DIR, exist_ok=True)
    print(f"[*] INJECTING KNOWLEDGE INTO: {TARGET_DIR}")
    
    for name, url in REPOS.items():
        path = os.path.join(TARGET_DIR, name)
        try:
            if os.path.exists(path):
                print(f" [✓] Updating {name}...")
                subprocess.run(["git", "-C", path, "pull"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                log_sync(name, "UPDATED", path)
            else:
                print(f" [⬇] Cloning {name} (Depth 1)...")
                subprocess.run(["git", "clone", "--depth", "1", url, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                log_sync(name, "CLONED", path)
        except subprocess.CalledProcessError:
            print(f" [!] Failed to sync {name}")
            log_sync(name, "ERROR", path)

if __name__ == "__main__":
    run()
PY_INJECTOR_EOF
chmod +x "$MB_ROOT/knowledge_injector.py"

# 5. Non-Destructive Daemon Engine (Locked STRICTLY to 00_INBOX)
cat << 'PY_DAEMON_EOF' > "$MB_ROOT/mother_daemon.py"
#!/usr/bin/env python3
import os
import json
import time
import re
import sqlite3
from datetime import datetime, timezone

MB_ROOT = os.path.dirname(os.path.abspath(__file__))
W_ROOT = os.path.dirname(MB_ROOT)
INBOX = os.path.join(MB_ROOT, "00_INBOX")
SECRETS_FILE = os.path.join(MB_ROOT, "SECURITY", "secrets.json")
DB_PATH = os.path.join(W_ROOT, "-VAULT-", "omega_memory.db")

def init_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS system_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                actor TEXT,
                event_type TEXT,
                details TEXT
            );
        """)

def log_event(msg, event_type="SYSTEM"):
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%SZ")
    print(f"[{ts}] [{event_type}] {msg}")
    try:
        with sqlite3.connect(DB_PATH) as conn:
            conn.execute("INSERT INTO system_events (actor, event_type, details) VALUES (?, ?, ?)", ("MOTHER-DAEMON", event_type, msg))
    except Exception as e:
        print(f"[!] Log Error: {e}")

def scan_inbox():
    if not os.path.exists(INBOX): return
    
    for f in os.listdir(INBOX):
        path = os.path.join(INBOX, f)
        if not os.path.isfile(path): continue
        
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
            
            patterns = {"OPENAI": r"sk-[a-zA-Z0-9]{48}", "GITHUB": r"ghp_[a-zA-Z0-9]{36}"}
            found = {k: re.search(p, content).group(0) for k, p in patterns.items() if re.search(p, content)}
            
            if found:
                secrets = {}
                if os.path.exists(SECRETS_FILE):
                    with open(SECRETS_FILE, "r") as sf: secrets = json.load(sf)
                secrets.update(found)
                with open(SECRETS_FILE, "w") as sf: json.dump(secrets, sf, indent=2)
                log_event(f"Extracted credentials from {f}", "SECURITY")
            
            # Safely remove file ONLY from the 00_INBOX after processing
            os.remove(path)
            log_event(f"Processed and cleared {f}", "INGEST")
            
        except Exception as e:
            log_event(f"Error processing {f}: {e}", "ERROR")

def cycle():
    init_db()
    log_event(f"MOTHER-BRAIN active. STRICTLY watching isolated inbox: {INBOX}")
    while True:
        try:
            scan_inbox()
            time.sleep(5)
        except KeyboardInterrupt:
            print("\n[*] Daemon shutting down smoothly.")
            break
        except Exception as e:
            log_event(f"Daemon loop error: {e}", "CRITICAL")
            time.sleep(10) # Backoff on failure

if __name__ == "__main__":
    cycle()
PY_DAEMON_EOF
chmod +x "$MB_ROOT/mother_daemon.py"

# 6. Execute Setup & Run
echo -e "\033[1;33m[!] PHASE 1: Executing Knowledge Injection...\033[0m"
python3 "$MB_ROOT/knowledge_injector.py"

echo -e "\033[1;32m[SUCCESS] SYSTEM ONLINE AND ERROR HANDLED.\033[0m"
echo " -> Executing Daemon from isolated path..."
python3 "$MB_ROOT/mother_daemon.py"
