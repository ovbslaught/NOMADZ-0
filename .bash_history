    print(f"[+] Physical telemetry written -> {packet_path}")

if __name__ == "__main__":
    main()
EOF

chmod +x ~/termux_sensor_ingest.py && python3 ~/termux_sensor_ingest.py
cat << 'EOF' > ~/recursive_healer.py
#!/usr/bin/env python3
"""recursive_healer.py — Closed-loop execution monitor, WAL logger, and auto-patching harness."""

import subprocess
import json
import os
import sys
from pathlib import Path
from datetime import datetime, timezone

MAX_RECURSION_DEPTH = 3
WAL_FILE = Path(os.environ.get("NOMADZ_WAL", "/sdcard/WORMHOLE/nomadz.wal"))

def wal_append(app: str, level: str, msg: str, payload: dict = None):
    try:
        WAL_FILE.parent.mkdir(parents=True, exist_ok=True)
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "app": app,
            "level": level,
            "msg": msg,
            "payload": payload or {}
        }
        with open(WAL_FILE, "a") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception as e:
        print(f"[!] WAL write failed: {e}", file=sys.stderr)

def run_cmd(cmd: list, cwd: str = None) -> dict:
    try:
        res = subprocess.run(
            cmd, cwd=cwd,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, timeout=120
        )
        return {
            "ok": res.returncode == 0,
            "rc": res.returncode,
            "out": res.stdout.strip(),
            "err": res.stderr.strip()
        }
    except Exception as e:
        return {"ok": False, "rc": -1, "out": "", "err": str(e)}

def self_heal_run(target_cmd: list, cwd: str = None, depth: int = 1) -> bool:
    target_name = target_cmd[0]
    wal_append("self_heal", "info", f"Executing target: {' '.join(target_cmd)} (Attempt {depth})")

    res = run_cmd(target_cmd, cwd=cwd)
    if res["ok"]:
        wal_append("self_heal", "ok", f"Execution successful for {target_name}", {"stdout": res["out"]})
        print(f"[+] Success (Attempt {depth}):\n{res['out']}")
        return True

    wal_append("self_heal", "warn", f"Failure in {target_name} (Attempt {depth})", {"stderr": res["err"]})
    print(f"[-] Execution failed on attempt {depth}:\n{res['err']}")

    if depth >= MAX_RECURSION_DEPTH:
        wal_append("self_heal", "error", f"Max recursion depth ({MAX_RECURSION_DEPTH}) reached for {target_name}")
        print(f"[!] Max recursion depth reached for {target_name}. Escalation required.")
        return False

    # Diagnostic Payload Construction for Gemini / Local LLM
    script_path = Path(cwd or ".", target_name)
    source_code = script_path.read_text() if script_path.exists() and script_path.is_file() else "N/A"
    
    diagnostic_packet = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "target": target_name,
        "depth": depth,
        "stderr": res["err"],
        "source": source_code
    }
    
    packet_out = WAL_FILE.parent / f"heal_request_{int(datetime.now().timestamp())}.json"
    packet_out.write_text(json.dumps(diagnostic_packet, indent=2))
    wal_append("self_heal", "info", f"Heal packet generated -> {packet_out.name}")
    print(f"[*] Diagnostic heal request queued -> {packet_out}")
    
    return False

if __name__ == "__main__":
    # Self-test harness against telemetry ingest
    test_target = [sys.executable, str(Path.home() / "termux_sensor_ingest.py")]
    self_heal_run(test_target)
EOF

chmod +x ~/recursive_healer.py && python3 ~/recursive_healer.py
pkg install nodejs -y
cd ~
npm create vite@latest nomadz-ui -- --template react-ts
npm run dev -- --host
#!/usr/bin/env bash
# ==============================================================================
# NOMADZ AUTOMATION DEPLOYMENT & EXECUTION ENGINE (v2.0)
# Target: WORMHOLE Architecture (PC / Termux / Linux)
# ==============================================================================
set -euo pipefail
# 1. PATH RESOLUTION & DIRECTORY INITIALIZATION
BASE_DIR="${WORMHOLE_DIR:-$HOME/WORMHOLE}"
if [ -d "/storage/emulated/0/WORMHOLE" ]; then     BASE_DIR="/storage/emulated/0/WORMHOLE"; elif [ -d "G:/WORMHOLE" ]; then     BASE_DIR="G:/WORMHOLE"; elif [ -d "D:/WORMHOLE" ]; then     BASE_DIR="D:/WORMHOLE"; fi
export WORMHOLE_DIR="$BASE_DIR"
DIRS=(     "$WORMHOLE_DIR/-VAULT-"     "$WORMHOLE_DIR/FATHER-BRAIN/FATHER-LIFE"     "$WORMHOLE_DIR/MOTHER-BRAIN"     "$WORMHOLE_DIR/OMEGA-BRAIN"     "$WORMHOLE_DIR/COSMIC-BRAIN"     "$WORMHOLE_DIR/GEO-BRAIN"     "$WORMHOLE_DIR/VULTURE-BRAIN"     "$WORMHOLE_DIR/NOMADZ-0/queue"     "$WORMHOLE_DIR/NOMADZ-0/outputs"     "$WORMHOLE_DIR/NOMADZ-0/godot_project" )
for d in "${DIRS[@]}"; do     if [ ! -d "$d" ]; then         mkdir -p "$d";         echo "[INIT] Created directory: $d";     fi; done
# Keep Termux awake if applicable
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
# 2. WRITE-AHEAD LOG & DATABASE INIT (SQLite WAL)
DB_PATH="$WORMHOLE_DIR/OMEGA-BRAIN/omega_memory.db"
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB_PATH" <<'EOF'
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
CREATE TABLE IF NOT EXISTS task_ledger (
    task_id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    payload TEXT,
    result TEXT
);
CREATE TABLE IF NOT EXISTS system_telemetry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    subsystem TEXT NOT NULL,
    metric_key TEXT NOT NULL,
    metric_value REAL
);
EOF
     echo "[INIT] SQLite schema initialized at: $DB_PATH"; fi
# 3. WRITE PRODUCTION ORCHESTRATOR SCRIPT
cat <<'EOF' > "$WORMHOLE_DIR/nomadz_orchestrator.py"
#!/usr/bin/env python3
import os
import sys
import json
import time
import shlex
import sqlite3
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timezone

WORMHOLE_ROOT = Path(os.environ.get("WORMHOLE_DIR", Path.home() / "WORMHOLE"))
QUEUE_DIR = WORMHOLE_ROOT / "NOMADZ-0" / "queue"
OUTPUTS_DIR = WORMHOLE_ROOT / "NOMADZ-0" / "outputs"
DB_PATH = WORMHOLE_ROOT / "OMEGA-BRAIN" / "omega_memory.db"
WAL_LOG = WORMHOLE_ROOT / "nomadz.wal"

def log_event(subsystem: str, action: str, status: str, payload: dict = None, result: dict = None):
    now = datetime.now(timezone.utc).isoformat()
    record = {
        "timestamp": now,
        "subsystem": subsystem,
        "action": action,
        "status": status,
        "payload": payload or {},
        "result": result or {}
    }
    
    # Append to plain WAL file
    WAL_LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(WAL_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")
        
    # Append to SQLite task ledger
    try:
        with sqlite3.connect(str(DB_PATH), timeout=10.0) as conn:
            conn.execute("PRAGMA journal_mode = WAL;")
            conn.execute("PRAGMA busy_timeout = 5000;")
            cursor = conn.cursor()
            task_id = payload.get("task_id", f"AUTO_{int(time.time()*1000)}") if payload else f"SYS_{int(time.time()*1000)}"
            cursor.execute(
                "INSERT OR REPLACE INTO task_ledger (task_id, timestamp, action, status, payload, result) VALUES (?, ?, ?, ?, ?, ?)",
                (task_id, now, action, status, json.dumps(payload or {}), json.dumps(result or {}))
            )
            conn.commit()
    except Exception as db_err:
        with open(WAL_LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({"timestamp": now, "subsystem": "DB_ERROR", "error": str(db_err)}) + "\n")

def run_cmd(cmd: list, cwd: Path = None, timeout: int = 600) -> dict:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        return {
            "ok": proc.returncode == 0,
            "rc": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip()
        }
    except Exception as e:
        return {"ok": False, "rc": -1, "stdout": "", "stderr": str(e)}

def dispatch_task(task_path: Path):
    try:
        data = json.loads(task_path.read_text(encoding="utf-8"))
    except Exception as err:
        log_event("DISPATCHER", "PARSE_MANIFEST", "FAILED", {"file": task_path.name}, {"error": str(err)})
        task_path.unlink(missing_ok=True)
        return

    task_id = data.get("task_id", task_path.stem)
    action = data.get("action", "UNKNOWN")
    params = data.get("params", {})

    log_event("DISPATCHER", action, "RUNNING", {"task_id": task_id, "params": params})
    res = {"ok": False, "msg": f"Unsupported action: {action}"}

    try:
        if action == "SYNC_GDRIVE":
            res = run_cmd(["rclone", "sync", str(WORMHOLE_ROOT), "gdrive:WORMHOLE", "--exclude", "*.tmp", "--transfers=4", "--checkers=8"])
        elif action == "GODOT_IMPORT":
            proj = Path(params.get("project_path", WORMHOLE_ROOT / "NOMADZ-0" / "godot_project"))
            res = run_cmd(["godot", "--headless", "--import"], cwd=proj)
        elif action == "SHELL_EXEC":
            raw_cmd = params.get("command", [])
            if isinstance(raw_cmd, str):
                cmd_list = shlex.split(raw_cmd)
            else:
                cmd_list = raw_cmd
            res = run_cmd(cmd_list, cwd=WORMHOLE_ROOT)
    except Exception as exec_err:
        res = {"ok": False, "rc": -1, "stdout": "", "stderr": str(exec_err)}
    finally:
        final_status = "SUCCESS" if res.get("ok") else "FAILED"
        log_event("DISPATCHER", action, final_status, {"task_id": task_id, "params": params}, res)

        OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
        out_file = OUTPUTS_DIR / f"{task_id}_result.json"
        out_file.write_text(json.dumps({"task_id": task_id, "status": final_status, "result": res}, indent=2), encoding="utf-8")
        task_path.unlink(missing_ok=True)

def run_loop(poll_interval: int = 5):
    print(f"[*] NOMADZ Orchestrator Active. Root: {WORMHOLE_ROOT}")
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    while True:
        manifests = sorted(QUEUE_DIR.glob("*.json"))
        for m in manifests:
            if m.is_file():
                dispatch_task(m)
        time.sleep(poll_interval)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Headless NOMADZ Engine")
    parser.add_argument("--daemon", action="store_true", help="Start polling loop")
    parser.add_argument("--sync", action="store_true", help="Direct gdrive sync")
    args = parser.parse_args()

    if args.sync:
        res = run_cmd(["rclone", "sync", str(WORMHOLE_ROOT), "gdrive:WORMHOLE", "--exclude", "*.tmp"])
        log_event("CLI", "SYNC_GDRIVE", "SUCCESS" if res["ok"] else "FAILED", {}, res)
        print(json.dumps(res, indent=2))
    else:
        run_loop()
EOF

chmod +x "$WORMHOLE_DIR/nomadz_orchestrator.py"
# 4. INJECT INITIAL TEST/SYNC TASK
INIT_TASK="$WORMHOLE_DIR/NOMADZ-0/queue/task_init_sync.json"
cat <<'EOF' > "$INIT_TASK"
{
  "task_id": "TASK_INIT_SYNC_001",
  "action": "SYNC_GDRIVE",
  "params": {
    "source": "LOCAL_WORMHOLE",
    "target": "gdrive:WORMHOLE"
  }
}
EOF

# 5. START DAEMON BACKGROUND PROCESS (Unbuffered)
python3 -u "$WORMHOLE_DIR/nomadz_orchestrator.py" --daemon > "$WORMHOLE_DIR/nomadz_daemon.log" 2>&1 &
PID=$!
echo "[ONLINE] NOMADZ Orchestrator daemon running with PID: $PID (Log: $WORMHOLE_DIR/nomadz_daemon.log)"
#!/usr/bin/env bash
# ==============================================================================
# NOMADZ AUTOMATION DEPLOYMENT & EXECUTION ENGINE (v2.0)
# Target: WORMHOLE Architecture (PC / Termux / Linux)
# ==============================================================================
set -euo pipefail
# 1. PATH RESOLUTION & DIRECTORY INITIALIZATION
BASE_DIR="${WORMHOLE_DIR:-$HOME/WORMHOLE}"
if [ -d "/storage/emulated/0/WORMHOLE" ]; then     BASE_DIR="/storage/emulated/0/WORMHOLE"; elif [ -d "G:/WORMHOLE" ]; then     BASE_DIR="G:/WORMHOLE"; elif [ -d "D:/WORMHOLE" ]; then     BASE_DIR="D:/WORMHOLE"; fi
export WORMHOLE_DIR="$BASE_DIR"
DIRS=(     "$WORMHOLE_DIR/-VAULT-"     "$WORMHOLE_DIR/FATHER-BRAIN/FATHER-LIFE"     "$WORMHOLE_DIR/MOTHER-BRAIN"     "$WORMHOLE_DIR/OMEGA-BRAIN"     "$WORMHOLE_DIR/COSMIC-BRAIN"     "$WORMHOLE_DIR/GEO-BRAIN"     "$WORMHOLE_DIR/VULTURE-BRAIN"     "$WORMHOLE_DIR/NOMADZ-0/queue"     "$WORMHOLE_DIR/NOMADZ-0/outputs"     "$WORMHOLE_DIR/NOMADZ-0/godot_project" )
for d in "${DIRS[@]}"; do     if [ ! -d "$d" ]; then         mkdir -p "$d";         echo "[INIT] Created directory: $d";     fi; done
# Keep Termux awake if applicable
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock
# 2. WRITE-AHEAD LOG & DATABASE INIT (SQLite WAL)
DB_PATH="$WORMHOLE_DIR/OMEGA-BRAIN/omega_memory.db"
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$DB_PATH" <<'EOF'
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
CREATE TABLE IF NOT EXISTS task_ledger (
    task_id TEXT PRIMARY KEY,
    timestamp TEXT NOT NULL,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    payload TEXT,
    result TEXT
);
CREATE TABLE IF NOT EXISTS system_telemetry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    subsystem TEXT NOT NULL,
    metric_key TEXT NOT NULL,
    metric_value REAL
);
EOF
     echo "[INIT] SQLite schema initialized at: $DB_PATH"; fi
# 3. WRITE PRODUCTION ORCHESTRATOR SCRIPT
cat <<'EOF' > "$WORMHOLE_DIR/nomadz_orchestrator.py"
#!/usr/bin/env python3
import os
import sys
import json
import time
import shlex
import sqlite3
import argparse
import subprocess
from pathlib import Path
from datetime import datetime, timezone

WORMHOLE_ROOT = Path(os.environ.get("WORMHOLE_DIR", Path.home() / "WORMHOLE"))
QUEUE_DIR = WORMHOLE_ROOT / "NOMADZ-0" / "queue"
OUTPUTS_DIR = WORMHOLE_ROOT / "NOMADZ-0" / "outputs"
DB_PATH = WORMHOLE_ROOT / "OMEGA-BRAIN" / "omega_memory.db"
WAL_LOG = WORMHOLE_ROOT / "nomadz.wal"

def log_event(subsystem: str, action: str, status: str, payload: dict = None, result: dict = None):
    now = datetime.now(timezone.utc).isoformat()
    record = {
        "timestamp": now,
        "subsystem": subsystem,
        "action": action,
        "status": status,
        "payload": payload or {},
        "result": result or {}
    }
    
    # Append to plain WAL file
    WAL_LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(WAL_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")
        
    # Append to SQLite task ledger
    try:
        with sqlite3.connect(str(DB_PATH), timeout=10.0) as conn:
            conn.execute("PRAGMA journal_mode = WAL;")
            conn.execute("PRAGMA busy_timeout = 5000;")
            cursor = conn.cursor()
            task_id = payload.get("task_id", f"AUTO_{int(time.time()*1000)}") if payload else f"SYS_{int(time.time()*1000)}"
            cursor.execute(
                "INSERT OR REPLACE INTO task_ledger (task_id, timestamp, action, status, payload, result) VALUES (?, ?, ?, ?, ?, ?)",
                (task_id, now, action, status, json.dumps(payload or {}), json.dumps(result or {}))
            )
            conn.commit()
    except Exception as db_err:
        with open(WAL_LOG, "a", encoding="utf-8") as f:
            f.write(json.dumps({"timestamp": now, "subsystem": "DB_ERROR", "error": str(db_err)}) + "\n")

def run_cmd(cmd: list, cwd: Path = None, timeout: int = 600) -> dict:
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout
        )
        return {
            "ok": proc.returncode == 0,
            "rc": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip()
        }
    except Exception as e:
        return {"ok": False, "rc": -1, "stdout": "", "stderr": str(e)}

def dispatch_task(task_path: Path):
    try:
        data = json.loads(task_path.read_text(encoding="utf-8"))
    except Exception as err:
        log_event("DISPATCHER", "PARSE_MANIFEST", "FAILED", {"file": task_path.name}, {"error": str(err)})
        task_path.unlink(missing_ok=True)
        return

    task_id = data.get("task_id", task_path.stem)
    action = data.get("action", "UNKNOWN")
    params = data.get("params", {})

    log_event("DISPATCHER", action, "RUNNING", {"task_id": task_id, "params": params})
    res = {"ok": False, "msg": f"Unsupported action: {action}"}

    try:
        if action == "SYNC_GDRIVE":
            res = run_cmd(["rclone", "sync", str(WORMHOLE_ROOT), "gdrive:WORMHOLE", "--exclude", "*.tmp", "--transfers=4", "--checkers=8"])
        elif action == "GODOT_IMPORT":
            proj = Path(params.get("project_path", WORMHOLE_ROOT / "NOMADZ-0" / "godot_project"))
            res = run_cmd(["godot", "--headless", "--import"], cwd=proj)
        elif action == "SHELL_EXEC":
            raw_cmd = params.get("command", [])
            if isinstance(raw_cmd, str):
                cmd_list = shlex.split(raw_cmd)
            else:
                cmd_list = raw_cmd
            res = run_cmd(cmd_list, cwd=WORMHOLE_ROOT)
    except Exception as exec_err:
        res = {"ok": False, "rc": -1, "stdout": "", "stderr": str(exec_err)}
    finally:
        final_status = "SUCCESS" if res.get("ok") else "FAILED"
        log_event("DISPATCHER", action, final_status, {"task_id": task_id, "params": params}, res)

        OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)
        out_file = OUTPUTS_DIR / f"{task_id}_result.json"
        out_file.write_text(json.dumps({"task_id": task_id, "status": final_status, "result": res}, indent=2), encoding="utf-8")
        task_path.unlink(missing_ok=True)

def run_loop(poll_interval: int = 5):
    print(f"[*] NOMADZ Orchestrator Active. Root: {WORMHOLE_ROOT}")
    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    while True:
        manifests = sorted(QUEUE_DIR.glob("*.json"))
        for m in manifests:
            if m.is_file():
                dispatch_task(m)
        time.sleep(poll_interval)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Headless NOMADZ Engine")
    parser.add_argument("--daemon", action="store_true", help="Start polling loop")
    parser.add_argument("--sync", action="store_true", help="Direct gdrive sync")
    args = parser.parse_args()

    if args.sync:
        res = run_cmd(["rclone", "sync", str(WORMHOLE_ROOT), "gdrive:WORMHOLE", "--exclude", "*.tmp"])
        log_event("CLI", "SYNC_GDRIVE", "SUCCESS" if res["ok"] else "FAILED", {}, res)
        print(json.dumps(res, indent=2))
    else:
        run_loop()
EOF

chmod +x "$WORMHOLE_DIR/nomadz_orchestrator.py"
# 4. INJECT INITIAL TEST/SYNC TASK
INIT_TASK="$WORMHOLE_DIR/NOMADZ-0/queue/task_init_sync.json"
cat <<'EOF' > "$INIT_TASK"
{
  "task_id": "TASK_INIT_SYNC_001",
  "action": "SYNC_GDRIVE",
  "params": {
    "source": "LOCAL_WORMHOLE",
    "target": "gdrive:WORMHOLE"
  }
}
EOF

# 5. START DAEMON BACKGROUND PROCESS (Unbuffered)
python3 -u "$WORMHOLE_DIR/nomadz_orchestrator.py" --daemon > "$WORMHOLE_DIR/nomadz_daemon.log" 2>&1 &
PID=$!
echo "[ONLINE] NOMADZ Orchestrator daemon running with PID: $PID (Log: $WORMHOLE_DIR/nomadz_daemon.log)"
# Initialize git if not already tracked
git init
# Verify or link the remote upstream repository
git remote remove origin 2>/dev/null
git remote add origin https://github.com/ovbslaught/NOMADZ-0.git
# Pull latest state to avoid merge conflicts
git pull origin main --rebase || true
# Stage core manifests, schemas, GDScripts, and config files
git add .
# Commit system snapshot
git commit -m "feat(nomadz-0): sync engine scripts, manifests, and export pipelines"
# Set branch to main and push
git branch -M main
git push -u origin main
cd
#!/usr/bin/env bash
set -euo pipefail
# Ensure remote is set
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/ovbslaught/NOMADZ-0.git
# Stage all files, commit snapshot, and push
git add -A
