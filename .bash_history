    status TEXT NOT NULL
);

-- Morphogenesis Signal Sigma Branches
CREATE TABLE IF NOT EXISTS sigma_branches (
    branch_id TEXT PRIMARY KEY,
    session_id TEXT,
    parent_id TEXT,
    depth INTEGER,
    node_type TEXT,
    score REAL,
    novelty REAL,
    cost REAL,
    fitness REAL,
    status TEXT,
    payload_json TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Autobuild & System Event Stream
CREATE TABLE IF NOT EXISTS build_history (
    build_id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name TEXT NOT NULL,
    target TEXT NOT NULL,
    commit_hash TEXT,
    status TEXT NOT NULL,
    duration_sec REAL NOT NULL,
    output_log TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_log (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    actor TEXT NOT NULL,
    action TEXT NOT NULL,
    target TEXT NOT NULL,
    status TEXT NOT NULL,
    meta_payload JSON
);
EOF

echo "[+] Schema successfully compiled to omega_memory_LIVE.db"
#!/usr/bin/env bash
echo "=== WORMHOLE HEALTH AUDIT ==="
# Check Database WAL status
if [ -f "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" ]; then   TABLES=$(sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" "SELECT count(*) FROM sqlite_master WHERE type='table';");   echo "[OK] omega_memory_LIVE.db online ($TABLES tables detected)"; else   echo "[FAIL] omega_memory_LIVE.db missing at $HOME/WORMHOLE/NOMADZ-SPINE/"; fi
# Check Ports
echo "--- Port Bindings ---"
for PORT in 8000 7424 7422 8080; do   if ss -tulpn 2>/dev/null | grep -q ":$PORT " || netstat -tuln 2>/dev/null | grep -q ":$PORT "; then     echo "[ONLINE] Port :$PORT is active";   else     echo "[OFFLINE] Port :$PORT is idle";   fi; done
# Check Running Python Daemons
echo "--- Active Daemons ---"
ps aux 2>/dev/null | grep -E "morphogenesis_api|sigma_generator|gravity_validator|ant_router|ultimo" | grep -v grep || echo "No active daemons found in process tree."
# Verify existing tables
sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
# Clean idempotent table patch (safe to run multiple times)
sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" << 'EOF'
CREATE TABLE IF NOT EXISTS knowledge_state (
    file_path TEXT PRIMARY KEY,
    content_hash TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    last_modified REAL NOT NULL,
    chunk_count INTEGER NOT NULL,
    indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS embedding_cache (
    chunk_hash TEXT PRIMARY KEY,
    model TEXT NOT NULL,
    vector_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF

# Generate test Sigma branch (depth 4) into omega_memory_LIVE.db
python3 -c "
import os, sys
from services.morphogenesis.sigma_generator import SigmaGenerator
gen = SigmaGenerator()
tree = gen.generate_tree(depth=4)
count = gen.commit_to_wal(tree, 'TEST-BOOT-001')
print(f'[+] Successfully committed {count} Sigma nodes to omega_memory_LIVE.db')
" 2>/dev/null || echo "[!] Test run: Ensure PYTHONPATH includes the morphogenesis repo root."
echo "=== ACTIVE PROCESSES ==="
ps aux | grep -E "python3|uvicorn" | grep -v grep
echo "=== BOUND PORTS ==="
for PORT in 8000 8080 7424 7422; do   nc -z -v 127.0.0.1 $PORT 2>&1 | grep -q "succeeded" && echo "Port $PORT: ONLINE" || echo "Port $PORT: IDLE"; done
#!/usr/bin/env bash
set -euo pipefail
sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" << 'EOF'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;

-- Zero-Waste RAG State
CREATE TABLE IF NOT EXISTS knowledge_state (
    file_path TEXT PRIMARY KEY,
    content_hash TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    last_modified REAL NOT NULL,
    chunk_count INTEGER NOT NULL,
    indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS memory_chunks (
    chunk_id TEXT PRIMARY KEY,
    file_path TEXT NOT NULL,
    chunk_index INTEGER NOT NULL,
    content TEXT NOT NULL,
    chunk_hash TEXT NOT NULL,
    FOREIGN KEY(file_path) REFERENCES knowledge_state(file_path) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS embedding_cache (
    chunk_hash TEXT PRIMARY KEY,
    model TEXT NOT NULL,
    vector_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
    chunk_id UNINDEXED,
    file_path,
    content,
    tokenize = 'porter unicode61'
);

-- Agent Codex Telemetry
CREATE TABLE IF NOT EXISTS agent_codex_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    agent_id TEXT NOT NULL,
    class_type TEXT NOT NULL,
    status TEXT NOT NULL
);

-- Morphogenesis Signal Sigma Branches
CREATE TABLE IF NOT EXISTS sigma_branches (
    branch_id TEXT PRIMARY KEY,
    session_id TEXT,
    parent_id TEXT,
    depth INTEGER,
    node_type TEXT,
    score REAL,
    novelty REAL,
    cost REAL,
    fitness REAL,
    status TEXT,
    payload_json TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Autobuild & System Event Stream
CREATE TABLE IF NOT EXISTS build_history (
    build_id INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name TEXT NOT NULL,
    target TEXT NOT NULL,
    commit_hash TEXT,
    status TEXT NOT NULL,
    duration_sec REAL NOT NULL,
    output_log TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS event_log (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    actor TEXT NOT NULL,
    action TEXT NOT NULL,
    target TEXT NOT NULL,
    status TEXT NOT NULL,
    meta_payload JSON
);
EOF

echo "[+] Schema successfully compiled to omega_memory_LIVE.db"
#!/usr/bin/env bash
echo "=== WORMHOLE HEALTH AUDIT ==="
# Check Database WAL status
if [ -f "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" ]; then   TABLES=$(sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" "SELECT count(*) FROM sqlite_master WHERE type='table';");   echo "[OK] omega_memory_LIVE.db online ($TABLES tables detected)"; else   echo "[FAIL] omega_memory_LIVE.db missing at $HOME/WORMHOLE/NOMADZ-SPINE/"; fi
# Check Ports
echo "--- Port Bindings ---"
for PORT in 8000 7424 7422 8080; do   if ss -tulpn 2>/dev/null | grep -q ":$PORT " || netstat -tuln 2>/dev/null | grep -q ":$PORT "; then     echo "[ONLINE] Port :$PORT is active";   else     echo "[OFFLINE] Port :$PORT is idle";   fi; done
# Check Running Python Daemons
echo "--- Active Daemons ---"
ps aux 2>/dev/null | grep -E "morphogenesis_api|sigma_generator|gravity_validator|ant_router|ultimo" | grep -v grep || echo "No active daemons found in process tree."
# Verify existing tables
sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
# Clean idempotent table patch (safe to run multiple times)
sqlite3 "$HOME/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db" << 'EOF'
CREATE TABLE IF NOT EXISTS knowledge_state (
    file_path TEXT PRIMARY KEY,
    content_hash TEXT NOT NULL,
    file_size INTEGER NOT NULL,
    last_modified REAL NOT NULL,
    chunk_count INTEGER NOT NULL,
    indexed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS embedding_cache (
    chunk_hash TEXT PRIMARY KEY,
    model TEXT NOT NULL,
    vector_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF

# Generate test Sigma branch (depth 4) into omega_memory_LIVE.db
python3 -c "
import os, sys
from services.morphogenesis.sigma_generator import SigmaGenerator
gen = SigmaGenerator()
tree = gen.generate_tree(depth=4)
count = gen.commit_to_wal(tree, 'TEST-BOOT-001')
print(f'[+] Successfully committed {count} Sigma nodes to omega_memory_LIVE.db')
" 2>/dev/null || echo "[!] Test run: Ensure PYTHONPATH includes the morphogenesis repo root."
echo "=== ACTIVE PROCESSES ==="
ps aux | grep -E "python3|uvicorn" | grep -v grep
echo "=== BOUND PORTS ==="
for PORT in 8000 8080 7424 7422; do   nc -z -v 127.0.0.1 $PORT 2>&1 | grep -q "succeeded" && echo "Port $PORT: ONLINE" || echo "Port $PORT: IDLE"; done
echo "=== LOCATING CORE DAEMONS ==="
find "$HOME" -maxdepth 4 -type f ( \
cat << 'EOF' > "$HOME/WORMHOLE/OMEGA-BRAIN/zero_waste_rag.py"
#!/usr/bin/env python3
"""
zero_waste_rag.py — OMEGA-BRAIN Zero-Waste RAG & Multi-Tier Discovery Engine
"""
import os
import sys
import sqlite3
import hashlib
import re
import time

DB = os.path.expanduser("~/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db")
DEFAULT_ROOT = os.path.expanduser("~/WORMHOLE")

def get_conn():
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    conn = sqlite3.connect(DB, timeout=30.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA busy_timeout=30000;")
    return conn

def execute_with_retry(func, *args, **kwargs):
    for i in range(5):
        try:
            return func(*args, **kwargs)
        except sqlite3.OperationalError as e:
            if "locked" in str(e).lower() or "busy" in str(e).lower():
                time.sleep(0.5 * (2 ** i))
                continue
            raise e

def init_rag_schema():
    def _init():
        conn = get_conn()
        with conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS knowledge_state (
                    file_path TEXT PRIMARY KEY,
                    content_hash TEXT NOT NULL,
                    file_size INTEGER NOT NULL,
                    last_modified REAL NOT NULL,
                    chunk_count INTEGER NOT NULL,
                    indexed_at TEXT DEFAULT (datetime('now'))
                );
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS memory_chunks (
                    chunk_id TEXT PRIMARY KEY,
                    file_path TEXT NOT NULL,
                    chunk_index INTEGER NOT NULL,
                    content TEXT NOT NULL,
                    chunk_hash TEXT NOT NULL
                );
            """)
            conn.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_fts USING fts5(
                    chunk_id UNINDEXED,
                    file_path UNINDEXED,
                    content,
                    tokenize = 'porter unicode61'
                );
            """)
            conn.execute("CREATE TABLE IF NOT EXISTS write_back_log (id INTEGER PRIMARY KEY, msg TEXT, created_at TEXT DEFAULT (datetime('now')));")
            conn.execute("CREATE TABLE IF NOT EXISTS session_logs (id INTEGER PRIMARY KEY, session_id TEXT, action TEXT, status TEXT, timestamp TEXT DEFAULT (datetime('now')));")
            conn.execute("CREATE TABLE IF NOT EXISTS facts (id INTEGER PRIMARY KEY, fact TEXT, category TEXT, created_at TEXT DEFAULT (datetime('now')));")
            conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        conn.close()
    execute_with_retry(_init)

def sanitize_fts5_query(query_str: str) -> str:
    tokens = re.findall(r"[\w\.\-]+", query_str)
    if not tokens:
        return '""'
    return " ".join(f'"{t.replace(chr(34), chr(34)+chr(34))}"' for t in tokens)

def ingest(target_dir=None, prune=True):
    root_dir = os.path.expanduser(target_dir) if target_dir else DEFAULT_ROOT
    if not os.path.exists(root_dir):
        print(f"[!] Error: Target directory does not exist: {root_dir}")
        return

    init_rag_schema()
    conn = get_conn()
    cur = conn.cursor()
    count = 0
    skipped = 0
    print(f"[*] Starting Recursive Zero-Waste Ingest across: {root_dir}")
    
    valid_exts = (".md", ".txt", ".json", ".py", ".gd", ".sh", ".toml", ".yaml", ".yml", ".ini", ".cfg", ".csv", ".tsv")
    excluded_dirs = {".git", ".godot", ".import", "__pycache__", ".tmp", "node_modules", "builds", "build", "venv", ".env", "-VAULT"}
    
    seen_files = set()
    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in excluded_dirs]
        for f in files:
            if f.endswith(valid_exts):
                p = os.path.join(root, f)
                seen_files.add(p)
                try:
                    if os.path.getsize(p) > 10 * 1024 * 1024:
                        continue

                    with open(p, "r", encoding="utf-8", errors="ignore") as fp:
                        txt = fp.read()
                    if not txt.strip():
                        continue
                    
                    h = hashlib.sha256(txt.encode("utf-8")).hexdigest()
                    cur.execute("SELECT content_hash FROM knowledge_state WHERE file_path=?", (p,))
                    row = cur.fetchone()
                    if row and row[0] == h:
                        skipped += 1
                        continue
                    
                    words = txt.split()
                    step = 250
                    chunks = [" ".join(words[i:i+300]) for i in range(0, max(1, len(words)), step)]

                    def _atomic_write():
                        with conn:
                            cur.execute("DELETE FROM knowledge_fts WHERE file_path=?", (p,))
                            cur.execute("DELETE FROM memory_chunks WHERE file_path=?", (p,))
                            cur.execute("DELETE FROM knowledge_state WHERE file_path=?", (p,))
                            cur.execute(
                                "INSERT OR REPLACE INTO knowledge_state (file_path, content_hash, file_size, last_modified, chunk_count, indexed_at) VALUES (?,?,?,?,?,datetime('now'))",
                                (p, h, os.path.getsize(p), os.path.getmtime(p), len(chunks))
                            )
                            for idx, chunk in enumerate(chunks):
                                cid = f"{h[:8]}_{idx}"
                                cur.execute(
                                    "INSERT OR REPLACE INTO memory_chunks VALUES (?,?,?,?,?)",
                                    (cid, p, idx, chunk, hashlib.sha256(chunk.encode('utf-8')).hexdigest())
                                )
                                cur.execute(
                                    "INSERT INTO knowledge_fts (chunk_id, file_path, content) VALUES (?,?,?)",
                                    (cid, p, chunk)
                                )

                    execute_with_retry(_atomic_write)
                    count += 1
                    print(f"[+] Indexed: {f} ({len(chunks)} chunks)")
                except Exception as err:
                    print(f"[!] Warning reading {f}: {err}")

    if prune:
        def _prune():
            with conn:
                cur.execute("SELECT file_path FROM knowledge_state")
                for (fp,) in cur.fetchall():
                    if not os.path.exists(fp):
                        cur.execute("DELETE FROM knowledge_fts WHERE file_path=?", (fp,))
                        cur.execute("DELETE FROM memory_chunks WHERE file_path=?", (fp,))
                        cur.execute("DELETE FROM knowledge_state WHERE file_path=?", (fp,))
                        print(f"[-] Pruned stale file: {os.path.basename(fp)}")
        execute_with_retry(_prune)

    conn.close()
    print(f"[OK] Ingestion complete. Indexed: {count}, Cached/Skipped: {skipped}")

def find(term):
    """Multi-tier search across Facts, Blueprint Chunks, and Session Logs."""
    conn = get_conn()
    cur = conn.cursor()
    safe_term = sanitize_fts5_query(term)
    
    print("\n" + "=" * 55)
    print(f"       OMEGA-BRAIN KNOWLEDGE SEARCH: \"{term}\"")
    print("=" * 55 + "\n")
    
    # 1. Check Facts Table
    try:
        cur.execute("SELECT fact, category FROM facts WHERE fact LIKE ? LIMIT 5;", (f"%{term}%",))
        facts = cur.fetchall()
        if facts:
            print("🧠 [CORE VERIFIED FACTS]")
            for fact, cat in facts:
                cat_label = f"[{cat}] " if cat else ""
                print(f"  • {cat_label}{fact}")
            print()
    except Exception:
        pass

    # 2. Check FTS5 Ranked Chunks
    try:
        cur.execute("""
            SELECT file_path, snippet(knowledge_fts, 2, '>> ', ' <<', '...', 12), rank 
            FROM knowledge_fts 
            WHERE knowledge_fts MATCH ? 
            ORDER BY rank 
            LIMIT 5;
        """, (safe_term,))
        matches = cur.fetchall()
        if matches:
            print("📚 [RELEVANT CODE & BLUEPRINTS]")
            for fp, snip, rank in matches:
                fname = os.path.basename(fp)
                print(f"  📁 {fname}")
                print(f"     Path: {fp}")
                print(f"     Snippet: {snip.strip()}\n")
        else:
            print("📚 [RELEVANT CODE & BLUEPRINTS]\n  (No direct document matches found)\n")
    except Exception as e:
        print(f"[!] Document Search Error: {e}\n")

    # 3. Check Session Logs
    try:
        cur.execute("""
            SELECT session_id, action, status, timestamp 
            FROM session_logs 
            WHERE session_id LIKE ? OR action LIKE ? 
            ORDER BY timestamp DESC 
            LIMIT 3;
        """, (f"%{term}%", f"%{term}%"))
        logs = cur.fetchall()
        if logs:
            print("⚡ [OPERATIONAL HISTORY]")
            for sid, act, stat, ts in logs:
                print(f"  • [{ts}] {sid} -> {act} ({stat})")
            print()
    except Exception:
        pass

    conn.close()

def status():
    conn = get_conn()
    cur = conn.cursor()
    print("=== OMEGA-BRAIN DATABASE STATUS ===")
    for t in ["knowledge_state", "memory_chunks", "knowledge_fts", "write_back_log", "session_logs", "facts"]:
        try:
            cur.execute(f"SELECT count(*) FROM {t}")
            print(f"  * {t:<18}: {cur.fetchone()[0]:>5} rows")
        except Exception as e:
            print(f"  * {t:<18}: (Table missing or error: {e})")
    conn.close()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd in ("find", "query", "search"):
            q = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else "NOMADZ"
            find(q)
        elif cmd == "status":
            status()
        elif cmd == "ingest":
            target = sys.argv[2] if len(sys.argv) > 2 else None
            ingest(target)
        else:
            print(f"Usage: zero_waste_rag.py [ingest <dir> | find <term> | status]")
    else:
        ingest()
EOF

#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="$(pwd)"
WORMHOLE_DIR="${REPO_ROOT}/WORMHOLE"
COSMIC_DIR="${WORMHOLE_DIR}/COSMIC-BRAIN"
echo "=== [1/4] Initializing Git Workspace & Tracking ==="
if [ ! -d ".git" ]; then     git init;     git branch -M main; fi
# Configure Git for large data pipelines and submodules
git config core.fileMode true
git config core.ignorecase false
git config pull.rebase true
echo "=== [2/4] Verifying WORMHOLE Substrate & COSMIC-BRAIN Subfolder ==="
mkdir -p "${COSMIC_DIR}/DB" "${COSMIC_DIR}/dropzone" "${COSMIC_DIR}/scripts"
mkdir -p "${WORMHOLE_DIR}/GEO-BRAIN" "${WORMHOLE_DIR}/MOTHER-BRAIN" "${WORMHOLE_DIR}/-VAULT/KEYS"
# If COSMIC-BRAIN is tracked as a submodule or sparse-checkout
if [ -f ".gitmodules" ] && grep -q "COSMIC-BRAIN" .gitmodules; then     echo "[GIT] Initializing and updating COSMIC-BRAIN submodule...";     git submodule update --init --recursive "WORMHOLE/COSMIC-BRAIN"; else
    echo "[GIT] Configuring cone sparse-checkout for COSMIC-BRAIN...";     git sparse-checkout init --cone;     git sparse-checkout set WORMHOLE/COSMIC-BRAIN WORMHOLE/GEO-BRAIN WORMHOLE/MOTHER-BRAIN; fi
# Ensure .gitkeep files exist so empty dropzones persist in Git
touch "${COSMIC_DIR}/.gitkeep" "${COSMIC_DIR}/DB/.gitkeep" "${COSMIC_DIR}/dropzone/.gitkeep"
echo "=== [3/4] Validating COSMIC-BRAIN State ==="
if [ -d "${COSMIC_DIR}" ]; then     echo "✅ COSMIC-BRAIN correctly checked out at: ${COSMIC_DIR}";     ls -la "${COSMIC_DIR}"; else     echo "❌ ERROR: COSMIC-BRAIN directory missing." >&2;     exit 1; fi
echo "=== [4/4] Workspace Automation Ready ==="
# Ingest raw source into Bronze Layer
python WORMHOLE/GEO-BRAIN/TOOLS/geologosctl.py ingest --pillar pillar-01-physics --dataset cern001 --source /data/cern_events.txt
