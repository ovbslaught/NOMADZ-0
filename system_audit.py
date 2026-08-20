#!/usr/bin/env python3
import os
import sys
import sqlite3
import shutil
import json
from datetime import datetime, timezone

VAULT_BASE = os.path.expanduser("~/WORMHOLE/-VAULT-")
DB_PATH = os.path.join(VAULT_BASE, "OMEGA-BRAIN", "omega_memory_LIVE.db")
SUB_BRAINS = [
    "VULTURE-BRAIN",
    "FATHER-BRAIN",
    "OMEGA-BRAIN",
    "GEO-BRAIN",
    "MOTHER-BRAIN",
    "COSMIC-BRAIN"
]

def run_audit():
    report = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "vault_base": VAULT_BASE,
        "dirs_checked": {},
        "db_status": {},
        "rclone_status": "NOT_CONFIGURED"
    }

    # 1. Directory Tree Integrity & Scaffolding
    for brain in SUB_BRAINS:
        brain_path = os.path.join(VAULT_BASE, brain)
        os.makedirs(brain_path, exist_ok=True)
        file_count = sum(len(files) for _, _, files in os.walk(brain_path))
        report["dirs_checked"][brain] = {"status": "READY", "file_count": file_count}

    # 2. SQLite Database Concurrency & Schema Audit
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    try:
        conn = sqlite3.connect(DB_PATH, timeout=10.0)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("PRAGMA busy_timeout=5000;")
        
        # Verify / Initialize Core Tables
        with conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS system_telemetry (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    module_name TEXT NOT NULL,
                    status TEXT NOT NULL,
                    payload TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            conn.execute("""
                CREATE TABLE IF NOT EXISTS knowledge_fts_meta (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    doc_hash TEXT UNIQUE NOT NULL,
                    source_path TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
        
        # Check active locks / integrity
        integrity = conn.execute("PRAGMA integrity_check;").fetchone()[0]
        journal_mode = conn.execute("PRAGMA journal_mode;").fetchone()[0]
        conn.close()

        report["db_status"] = {
            "path": DB_PATH,
            "journal_mode": journal_mode,
            "integrity": integrity,
            "status": "OPERATIONAL"
        }
    except Exception as e:
        report["db_status"] = {
            "path": DB_PATH,
            "error": str(e),
            "status": "FAILED"
        }

    # 3. Rclone Gdrive Remote Check
    if shutil.which("rclone"):
        report["rclone_status"] = "INSTALLED"
    else:
        report["rclone_status"] = "NOT_FOUND"

    # Print Clean Output
    print(json.dumps(report, indent=2))

if __name__ == "__main__":
    run_audit()
