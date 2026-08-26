#!/usr/bin/env bash
set -euo pipefail

WORMHOLE_DIR="${HOME}/WORMHOLE"
SCRIPTS_DIR="${WORMHOLE_DIR}/-SCRIPTS-"
VAULT_DIR="${WORMHOLE_DIR}/-VAULT-"
DB_PATH="${WORMHOLE_DIR}/OMEGA-BRAIN/omega_memory.db"
mkdir -p "${SCRIPTS_DIR}" "${VAULT_DIR}" "${WORMHOLE_DIR}/OMEGA-BRAIN"

echo "[+] Initializing WAL SQLite state schema..."
sqlite3 "${DB_PATH}" << 'SQL'
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS asana_tasks (
    gid TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    workspace TEXT,
    coherence REAL,
    notes TEXT,
    completed INTEGER DEFAULT 0,
    due_on TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS voltron_pulse_log (
    pulse_id INTEGER PRIMARY KEY AUTOINCREMENT,
    gid TEXT,
    node_id TEXT,
    vector_clock INTEGER,
    status TEXT,
    synced_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

INSERT OR REPLACE INTO asana_tasks (gid, name, workspace, coherence, notes, completed, due_on, updated_at)
VALUES (
    '1212999214987254',
    'VOLTRON CASCADE: BACKUP-ASANA-PULSE',
    '1212312499108484',
    1.102,
    'BACKUP: rclone sdcardGEOLOGOS→Drive/Obsidian/GitHub (18.7TB). ASANA: GID bootstrap. PULSE: 30min CRDT rehydrate (voltrongossip.py). Paste→Asana task; approve→EXEC.',
    0,
    '2026-02-12',
    CURRENT_TIMESTAMP
);
SQL

echo "[+] Generating voltrongossip.py CRDT rehydrate node..."
cat << 'PYTHON' > "${SCRIPTS_DIR}/voltrongossip.py"
#!/usr/bin/env python3
import sqlite3
import json
import time
import os
import sys

DB_PATH = os.path.expanduser("~/WORMHOLE/OMEGA-BRAIN/omega_memory.db")
NODE_ID = "NOMADZ/OMEGA-BRAIN"

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn

def rehydrate_crdt_state():
    conn = get_db()
    cursor = conn.cursor()
    
    # Retrieve current task state
    cursor.execute("SELECT gid, coherence FROM asana_tasks WHERE gid = ?", ("1212999214987254",))
    row = cursor.fetchone()
    if not row:
        print("[-] Task not found in memory.")
        conn.close()
        return
        
    gid, coherence = row
    
    # Fetch vector clock
    cursor.execute("SELECT MAX(vector_clock) FROM voltron_pulse_log WHERE gid = ?", (gid,))
    v_clock = cursor.fetchone()[0] or 0
    v_clock += 1
    
    cursor.execute(
        "INSERT INTO voltron_pulse_log (gid, node_id, vector_clock, status) VALUES (?, ?, ?, ?)",
        (gid, NODE_ID, v_clock, "CRDT_REHYDRATED")
    )
    conn.commit()
    conn.close()
    print(f"[+] Pulse completed: Node={NODE_ID} | Clock={v_clock} | GID={gid} | Coherence={coherence}")

if __name__ == "__main__":
    rehydrate_crdt_state()
PYTHON
chmod +x "${SCRIPTS_DIR}/voltrongossip.py"

echo "[+] Generating voltron_runner.sh daemon..."
cat << 'RUNNER' > "${SCRIPTS_DIR}/voltron_runner.sh"
#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="/tmp/voltron_pulse.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "[-] Execution locked. Exiting."; exit 1; }

SCRIPTS_DIR="${HOME}/WORMHOLE/-SCRIPTS-"
SDCARD_SRC="/sdcard/GEOLOGOS"

echo "[+] Running CRDT Pulse..."
python3 "${SCRIPTS_DIR}/voltrongossip.py"

if [[ -d "${SDCARD_SRC}" ]]; then
    echo "[+] Running rclone sync to gdrive..."
    rclone sync "${SDCARD_SRC}" "gdrive:WORMHOLE/GEO-BRAIN/GEOLOGOS" \
        --transfers=4 \
        --checkers=8 \
        --fast-list \
        --log-level INFO || echo "[-] Rclone gdrive warning."

    echo "[+] Updating local git/obsidian vault tracking..."
    VAULT_TRACK="${HOME}/WORMHOLE/-VAULT-/OBSIDIAN_SYNC"
    mkdir -p "${VAULT_TRACK}"
    rsync -av --update "${SDCARD_SRC}/" "${VAULT_TRACK}/" || echo "[-] Rsync warning."
else
    echo "[!] Source ${SDCARD_SRC} not found or permission missing. Skipping rclone sync."
fi

echo "[+] Voltron cascade iteration finished."
RUNNER
chmod +x "${SCRIPTS_DIR}/voltron_runner.sh"

echo "[*] Executing initial pulse..."
"${SCRIPTS_DIR}/voltron_runner.sh"
