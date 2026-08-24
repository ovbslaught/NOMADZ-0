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
