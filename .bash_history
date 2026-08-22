pillars_json = os.path.join(geo_dir, "registry/pillars.json")
pillars_dir = os.path.join(geo_dir, "pillars")

if os.path.exists(pillars_json):
    try:
        with open(pillars_json, "r", encoding="utf-8") as f:
            data = json.load(f)
        pillars = data.get("pillars", data)
        print(f"  - registry/pillars.json: [EXISTS] ({len(pillars)} pillars registered)")
        if isinstance(pillars, list) and pillars:
            sample = pillars[:3]
            for p in sample:
                name = p.get("name", p.get("id", "Unknown"))
                desc = p.get("scope", p.get("description", p.get("domain", "")))[:70]
                print(f"    * Pillar: {name} -> {desc}")
        elif isinstance(pillars, dict):
            for k in list(pillars.keys())[:3]:
                print(f"    * Pillar {k}: {str(pillars[k])[:70]}")
    except Exception as e:
        print(f"  - Error reading pillars.json: {e}")
else:
    print(f"  - registry/pillars.json: [MISSING] at {pillars_json}")

if os.path.exists(pillars_dir):
    pfiles = [f for f in os.listdir(pillars_dir) if f.endswith((".json", ".md", ".txt"))]
    print(f"  - pillars/ directory: [EXISTS] ({len(pfiles)} definition files)")
    if pfiles:
        sample_path = os.path.join(pillars_dir, pfiles[0])
        size = os.path.getsize(sample_path)
        print(f"    Sample ({pfiles[0]}): {size} bytes")
else:
    print(f"  - pillars/ directory: [MISSING] at {pillars_dir}")

# 4. BACKGROUND DAEMONS & NETWORK HEALTH
print("\n[+] 4. ACTIVE PORT & DAEMON HEALTH CHECK")
services = [
    (8000, "NOMADZ-0 Morphogenesis API"),
    (8080, "VULTURE ULTIMO Backbone"),
    (7424, "SWARM-SUBSTRATE-01 Engine")
]
for port, name in services:
    try:
        res = subprocess.run(["curl", "-s", f"http://127.0.0.1:{port}/health"], capture_output=True, text=True, timeout=2)
        if "ONLINE" in res.stdout:
            print(f"  [ONLINE]  Port {port:<5} | {name}")
        else:
            print(f"  [STANDBY] Port {port:<5} | {name}")
    except Exception:
        print(f"  [STANDBY] Port {port:<5} | {name}")

# 5. RUNNING PROCESSES
print("\n[+] 5. PROCESS MONITOR & ACTIVE ENGINES")
try:
    ps_res = subprocess.run(["ps", "-ef"], capture_output=True, text=True).stdout
    py_procs = [l for l in ps_res.splitlines() if "python" in l and "audit" not in l]
    print(f"  - Active Python processes: {len(py_procs)}")
    for p in py_procs[:3]:
        print(f"    PID Line: {p[:90]}")
except Exception as e:
    print(f"  - Process check notice: {e}")

print("\n" + "=" * 60)
print(" AUDIT SCAN COMPLETE")
print("=" * 60)
EOF

# Execute the audit script
python ~/WORMHOLE/audit_system_clarity.py
# One-liner you can drop directly into your terminal or add to the setup script
cat >> "${MB_DIR}/.gitignore" << 'EOF'
Security/secrets.json
-VAULT-/
*.env
*.env.*
*.key
*.pem
EOF

git -C "${MB_DIR}" add .gitignore
git -C "${MB_DIR}" commit -m "chore: add security exclusions to gitignore"
git -C "${MB_DIR}" push
commit_msg = f"[skip ci] Auto-Sync: {datetime.now(timezone.utc).isoformat()}"
# In mb_daemon.py, change this one line:
if time.time() - last_sync >= 300:  # 5 min instead of 60s
processed = set()
# inside main loop:
for inbox_file in os.listdir(INBOX_DIR):
nano "${MB_DIR}/scripts/mb_daemon.py"
echo "${MB_DIR}"
export MB_DIR="/data/data/com.termux/files/home/storage/shared/WORMHOLE/MOTHER-BRAIN"
find /data/data/com.termux/files/home/storage/shared/WORMHOLE -name "mb_daemon.py" 2>/dev/null
cat << 'PYEOF' > "${MB_DIR}/scripts/mb_daemon.py"
#!/usr/bin/env python3
import os, re, time, json, shutil, subprocess
from datetime import datetime, timezone

WORMHOLE_ROOT = os.environ.get("WORMHOLE_DIR", "/data/data/com.termux/files/home/storage/shared/WORMHOLE")
MB_ROOT       = os.environ.get("MB_DIR", os.path.join(WORMHOLE_ROOT, "MOTHER-BRAIN"))
INBOX_DIR     = os.path.join(MB_ROOT, "00_Inbox")
SECRETS_FILE  = os.path.join(MB_ROOT, "Security", "secrets.json")
LOG_FILE      = os.path.join(MB_ROOT, "99_System_Logs", "daemon.log")

VAULT_EXCLUDE = {"-VAULT-", ".env", ".env.local", "secrets.json"}

API_PATTERNS = {
    "openai":   r"sk-[a-zA-Z0-9]{32,51}",
    "github":   r"gh[pousr]-[A-Za-z0-9_]{36,255}",
    "firecrawl":r"fc-[a-zA-Z0-9]{32,}"
}

def log(msg):
    entry = f"[{datetime.now(timezone.utc).isoformat()}] {msg}"
    print(entry)
    with open(LOG_FILE, "a") as f:
        f.write(entry + "
")

def scan_creds(path):
    try:
        content = open(path, "r", errors="ignore").read()
        found = {p: list(set(re.findall(r, content))) for p, r in API_PATTERNS.items() if re.findall(r, content)}
        if not found:
            return
        log(f"[SECURITY] Keys found in {os.path.basename(path)}: {list(found.keys())}")
        store = {}
        if os.path.exists(SECRETS_FILE):
            try: store = json.load(open(SECRETS_FILE))
            except: pass
        for p, keys in found.items():
            store[p] = list(set(store.get(p, []) + keys))
        json.dump(store, open(SECRETS_FILE, "w"), indent=2)
        if "key" in os.path.basename(path).lower():
            os.remove(path)
            log(f"[SECURITY] Purged {path}")
    except Exception as e:
        log(f"[ERROR] scan_creds: {e}")

def ingest():
    try:
        for entry in os.listdir(WORMHOLE_ROOT):
            if entry in VAULT_EXCLUDE or entry.startswith(".") or entry == "MOTHER-BRAIN":
                continue
            full = os.path.join(WORMHOLE_ROOT, entry)
            if os.path.isfile(full):
                dest = os.path.join(INBOX_DIR, entry)
                shutil.move(full, dest)
                log(f"[INBOX] {entry}")
                scan_creds(dest)
    except Exception as e:
        log(f"[ERROR] ingest: {e}")

def git_sync():
    try:
        status = subprocess.run(["git","-C",MB_ROOT,"status","--porcelain"], capture_output=True, text=True)
        if status.stdout.strip():
            subprocess.run(["git","-C",MB_ROOT,"add","."], check=True)
            subprocess.run(["git","-C",MB_ROOT,"commit","-m",f"[skip ci] NOMADZ-0 sync {datetime.now(timezone.utc).isoformat()}"], check=True)
            subprocess.run(["git","-C",MB_ROOT,"push"], check=False)
            log("[GIT] Sync pushed.")
    except Exception as e:
        log(f"[ERROR] git_sync: {e}")

def main():
    log("[START] NOMADZ-0 MOTHER-BRAIN daemon online.")
    processed = set()
    last_sync = time.time()
    while True:
        ingest()
        for f in os.listdir(INBOX_DIR):
            if f in processed: continue
            fp = os.path.join(INBOX_DIR, f)
            if os.path.isfile(fp):
                scan_creds(fp)
                processed.add(f)
        if time.time() - last_sync >= 300:
            git_sync()
            last_sync = time.time()
        time.sleep(5)

if __name__ == "__main__":
    main()
PYEOF

chmod +x "${MB_DIR}/scripts/mb_daemon.py"
echo "[✓] mb_daemon.py written"
cat "${MB_DIR}/scripts/mb_daemon.py" | head -5
cat << 'PYEOF' > "${MB_DIR}/scripts/mb_daemon.py"
#!/usr/bin/env python3
import os, re, time, json, shutil, subprocess
from datetime import datetime, timezone

WORMHOLE_ROOT = os.environ.get("WORMHOLE_DIR", "/data/data/com.termux/files/home/storage/shared/WORMHOLE")
MB_ROOT       = os.environ.get("MB_DIR", os.path.join(WORMHOLE_ROOT, "MOTHER-BRAIN"))
INBOX_DIR     = os.path.join(MB_ROOT, "00_Inbox")
SECRETS_FILE  = os.path.join(MB_ROOT, "Security", "secrets.json")
LOG_FILE      = os.path.join(MB_ROOT, "99_System_Logs", "daemon.log")

VAULT_EXCLUDE = {"-VAULT-", ".env", ".env.local", "secrets.json"}

API_PATTERNS = {
    "openai":   r"sk-[a-zA-Z0-9]{32,51}",
    "github":   r"gh[pousr]-[A-Za-z0-9_]{36,255}",
    "firecrawl":r"fc-[a-zA-Z0-9]{32,}"
}

def log(msg):
    entry = f"[{datetime.now(timezone.utc).isoformat()}] {msg}"
    print(entry)
    with open(LOG_FILE, "a") as f:
        f.write(entry + "
")

def scan_creds(path):
    try:
        content = open(path, "r", errors="ignore").read()
        found = {p: list(set(re.findall(r, content))) for p, r in API_PATTERNS.items() if re.findall(r, content)}
        if not found:
            return
        log(f"[SECURITY] Keys found in {os.path.basename(path)}: {list(found.keys())}")
        store = {}
        if os.path.exists(SECRETS_FILE):
            try: store = json.load(open(SECRETS_FILE))
            except: pass
        for p, keys in found.items():
            store[p] = list(set(store.get(p, []) + keys))
        json.dump(store, open(SECRETS_FILE, "w"), indent=2)
        if "key" in os.path.basename(path).lower():
            os.remove(path)
            log(f"[SECURITY] Purged {path}")
    except Exception as e:
        log(f"[ERROR] scan_creds: {e}")

def ingest():
    try:
        for entry in os.listdir(WORMHOLE_ROOT):
            if entry in VAULT_EXCLUDE or entry.startswith(".") or entry == "MOTHER-BRAIN":
                continue
            full = os.path.join(WORMHOLE_ROOT, entry)
            if os.path.isfile(full):
                dest = os.path.join(INBOX_DIR, entry)
                shutil.move(full, dest)
                log(f"[INBOX] {entry}")
                scan_creds(dest)
    except Exception as e:
        log(f"[ERROR] ingest: {e}")

def git_sync():
    try:
        status = subprocess.run(["git","-C",MB_ROOT,"status","--porcelain"], capture_output=True, text=True)
        if status.stdout.strip():
            subprocess.run(["git","-C",MB_ROOT,"add","."], check=True)
            subprocess.run(["git","-C",MB_ROOT,"commit","-m",f"[skip ci] NOMADZ-0 sync {datetime.now(timezone.utc).isoformat()}"], check=True)
            subprocess.run(["git","-C",MB_ROOT,"push"], check=False)
            log("[GIT] Sync pushed.")
    except Exception as e:
        log(f"[ERROR] git_sync: {e}")

def main():
    log("[START] NOMADZ-0 MOTHER-BRAIN daemon online.")
    processed = set()
    last_sync = time.time()
    while True:
        ingest()
        for f in os.listdir(INBOX_DIR):
            if f in processed: continue
            fp = os.path.join(INBOX_DIR, f)
            if os.path.isfile(fp):
                scan_creds(fp)
                processed.add(f)
        if time.time() - last_sync >= 300:
            git_sync()
            last_sync = time.time()
        time.sleep(5)

if __name__ == "__main__":
    main()
PYEOF

chmod +x "${MB_DIR}/scripts/mb_daemon.py"
echo "[✓] mb_daemon.py written"
cat "${MB_DIR}/scripts/mb_daemon.py" | head -5
#!/usr/bin/env bash
set -euo pipefail
TARGET_BRANCH="Cosmic-key"
FAILED_COMMIT="bb4f398"
DB_PATH="omega_memory.db"
echo "[1/5] Checking Git working tree state..."
git status --short
echo "[2/5] Verifying branch and commit context..."
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then     echo "Switching to target branch: $TARGET_BRANCH";     git checkout "$TARGET_BRANCH"; fi
#!/usr/bin/env bash
set -e
# 1. Setup Termux shared storage link if missing
if [ ! -d "$HOME/storage/shared" ]; then     echo "[*] Initializing termux storage...";     termux-setup-storage;     sleep 2; fi
# 2. Define canonical paths targeting external shared storage
W_ROOT="$HOME/storage/shared/WORMHOLE"
VAULT_PATH="$W_ROOT/-VAULT-"
OMEGA_ROOT="$W_ROOT/OMEGA-BRAIN"
MB_ROOT="$W_ROOT/MOTHER-BRAIN"
# 3. Create all canonical directory trees
mkdir -p "$VAULT_PATH"
mkdir -p "$OMEGA_ROOT"
mkdir -p "$MB_ROOT/00_INBOX"
mkdir -p "$MB_ROOT/01_KNOWLEDGE_GRAPH/EXTERNAL_SOURCE"
mkdir -p "$MB_ROOT/04_RESEARCH"
mkdir -p "$MB_ROOT/SECURITY"
# 4. Write pure ingestion engine directly to shared WORMHOLE node
cat << 'PY_EOF' > "$OMEGA_ROOT/ingest_engine.py"
import os
import sys
import json
import sqlite3
import hashlib
from datetime import datetime, timezone

HOME_DIR = os.path.expanduser("~")
W_ROOT = os.path.join(HOME_DIR, "storage", "shared", "WORMHOLE")
VAULT_DIR = os.path.join(W_ROOT, "-VAULT-")
DB_PATH = os.path.join(VAULT_DIR, "omega_memory.db")

def init_db():
    os.makedirs(VAULT_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=15.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    with conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS system_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            actor TEXT,
            event_type TEXT,
            details TEXT
        );
        CREATE TABLE IF NOT EXISTS notebook_memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cell_hash TEXT UNIQUE NOT NULL,
            file_path TEXT NOT NULL,
            notebook_name TEXT NOT NULL,
            cell_index INTEGER NOT NULL,
            cell_type TEXT NOT NULL,
            source_content TEXT NOT NULL,
            ingested_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_nb_hash ON notebook_memory(cell_hash);
        """)
    return conn

def hash_payload(filepath: str, idx: int, content: str) -> str:
    raw = f"{filepath}:{idx}:{content}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def ingest_notebooks(conn):
    ingested = 0
    skipped = 0
    now_iso = datetime.now(timezone.utc).isoformat()
    cursor = conn.cursor()

    for root, _, files in os.walk(W_ROOT):
        for f in files:
            if f.endswith(".ipynb") and not f.startswith(".ipynb_checkpoints"):
                full_path = os.path.join(root, f)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as nbf:
                        data = json.load(nbf)
                    cells = data.get("cells", [])
                    for idx, cell in enumerate(cells):
                        cell_type = cell.get("cell_type", "unknown")
                        src = "".join(cell.get("source", []))
                        if not src.strip():
                            continue
                        chash = hash_payload(full_path, idx, src)
                        try:
                            cursor.execute(
                                """
                                INSERT INTO notebook_memory 
                                (cell_hash, file_path, notebook_name, cell_index, cell_type, source_content, ingested_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?)
                                """,
                                (chash, full_path, f, idx, cell_type, src, now_iso)
                            )
                            ingested += 1
                        except sqlite3.IntegrityError:
                            skipped += 1
                except Exception as err:
                    print(f"[ERROR] Skipping corrupt notebook {f}: {err}")

    conn.commit()
    print(f"[INGEST COMPLETE] Processed cells -> Imported: {ingested} | Existing: {skipped}")

if __name__ == "__main__":
    db_conn = init_db()
    ingest_notebooks(db_conn)
    db_conn.close()
PY_EOF

# 5. Execute engine via python3 binary
python3 "$OMEGA_ROOT/ingest_engine.py"
# 6. Verify SQLite tables and WAL state
sqlite3 "$VAULT_PATH/omega_memory.db" "PRAGMA journal_mode;"
sqlite3 "$VAULT_PATH/omega_memory.db" "SELECT name FROM sqlite_master WHERE type='table';"
sqlite3 "$VAULT_PATH/omega_memory.db" "SELECT COUNT(*) FROM notebook_memory;"
# 1. Ingest across both shared storage and local Termux home
python3 -c '
import os
import json
import sqlite3
import hashlib
from datetime import datetime, timezone

HOME_DIR = os.path.expanduser("~")
DB_PATH = os.path.join(HOME_DIR, "storage", "shared", "WORMHOLE", "-VAULT-", "omega_memory.db")

SEARCH_PATHS = [
    os.path.join(HOME_DIR, "storage", "shared"),
    HOME_DIR
]

def hash_payload(filepath: str, idx: int, content: str) -> str:
    raw = f"{filepath}:{idx}:{content}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

conn = sqlite3.connect(DB_PATH, timeout=15.0)
conn.execute("PRAGMA journal_mode=WAL;")
cursor = conn.cursor()

ingested = 0
skipped = 0
now_iso = datetime.now(timezone.utc).isoformat()

for base in SEARCH_PATHS:
    if not os.path.exists(base):
        continue
    for root, _, files in os.walk(base):
        # Skip hidden git and cache trees
        if "/.git" in root or "/.cache" in root or "-VAULT-" in root:
            continue
        for f in files:
            if f.endswith(".ipynb") and not f.startswith(".ipynb_checkpoints"):
                full_path = os.path.join(root, f)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as nbf:
                        data = json.load(nbf)
                    cells = data.get("cells", [])
                    for idx, cell in enumerate(cells):
                        cell_type = cell.get("cell_type", "unknown")
                        src = "".join(cell.get("source", []))
                        if not src.strip():
                            continue
                        chash = hash_payload(full_path, idx, src)
                        try:
                            cursor.execute(
                                """
                                INSERT INTO notebook_memory
                                (cell_hash, file_path, notebook_name, cell_index, cell_type, source_content, ingested_at)
                                VALUES (?, ?, ?, ?, ?, ?, ?)
                                """,
                                (chash, full_path, f, idx, cell_type, src, now_iso)
                            )
                            ingested += 1
                        except sqlite3.IntegrityError:
                            skipped += 1
                except Exception as err:
                    print(f"[ERROR] Corrupt file {full_path}: {err}")

conn.commit()
conn.close()
print(f"[GLOBAL INGEST COMPLETE] Imported: {ingested} | Existing: {skipped}")
'
# 2. Check updated database records
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT COUNT(*) FROM notebook_memory;"
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT DISTINCT notebook_name FROM notebook_memory;"
# Query breakdown by cell type across all ingested notebooks
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT cell_type, COUNT(*) FROM notebook_memory GROUP BY cell_type;"
# Check SQLite WAL checkpoint integrity
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "PRAGMA wal_checkpoint(TRUNCATE);"
# Verify sample notebook code blocks from OMEGA_SPACE.ipynb
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT cell_index, substr(source_content, 1, 120) FROM notebook_memory WHERE notebook_name='OMEGA_SPACE.ipynb' AND cell_type='code' LIMIT 5;"
# Check full schema definition including indexes
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" ".schema"
# Verify top 5 largest code notebooks by cell volume
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT notebook_name, COUNT(*) as cell_count FROM notebook_memory WHERE cell_type='code' GROUP BY notebook_name ORDER BY cell_count DESC LIMIT 5;"
# Set up FTS5 full-text search table for fast retrieval of scripts and cells
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" << 'EOF'
CREATE VIRTUAL TABLE IF NOT EXISTS notebook_search USING fts5(
    notebook_name,
    cell_type,
    source_content,
    content='notebook_memory',
    content_rowid='id'
);

-- Populate search index
INSERT INTO notebook_search(rowid, notebook_name, cell_type, source_content)
SELECT id, notebook_name, cell_type, source_content FROM notebook_memory;
EOF

# Test keyword query across all ingested notebook cells (e.g. 'torch' or 'sqlite3')
sqlite3 "$HOME/storage/shared/WORMHOLE/-VAULT-/omega_memory.db" "SELECT notebook_name, cell_index, substr(source_content, 1, 80) FROM notebook_search WHERE notebook_search MATCH 'sqlite3' LIMIT 5;"
