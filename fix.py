f=open('/data/data/com.termux/files/home/WORMHOLE/OMEGA-BRAIN/DB/omega_engine.py')
lines=f.readlines()
f.close()
lines[20]='        open(FILTER_FILE,"w").write(chr(10).join(rules)+chr(10))
'
open('/data/data/com.termux/files/home/WORMHOLE/OMEGA-BRAIN/DB/omega_engine.py','w').writelines(lines)python3 ~/fix.py && python3 ~/WORMHOLE/OMEGA-BRAIN/DB/omega_engine.py#!/usr/bin/env python3
import sqlite3, json, subprocess, os
from datetime import datetime, timezone

WORMHOLE_ROOT = os.path.expanduser("~/WORMHOLE")
SPINE_DB = os.path.join(WORMHOLE_ROOT, "NOMADZ-SPINE", "omega_memory_LIVE.db")
DRIVE_REMOTE = "gdrive:WORMHOLE"
FILTER_FILE = os.path.join(WORMHOLE_ROOT, "NOMADZ-SPINE", "rclone_filters.txt")

def get_db():
    conn = sqlite3.connect(SPINE_DB, timeout=30.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA busy_timeout=5000;")
    return conn

def ensure_filter_file():
    os.makedirs(os.path.dirname(FILTER_FILE), exist_ok=True)
    if not os.path.exists(FILTER_FILE):
        rules = ["- /-VAULT-/**", "- /.git/**", "- /node_modules/**",
                 "- /*.partial", "- /*.db-wal", "- /*.db-shm", "+ /**"]
        open(FILTER_FILE, "w").write("
".join(rules) + "
")
        print("[FILTER] Written")

def recursive_heal():
    conn = get_db()
    try:
        res = conn.execute("PRAGMA integrity_check;").fetchone()[0]
        if res != "ok":
            print("[HEAL CRITICAL] " + res)
        with conn:
            conn.execute("UPDATE write_back_log SET state='PENDING' WHERE state='FAILED' AND retry_count < 5")
            conn.execute("DELETE FROM facts WHERE rowid NOT IN (SELECT MIN(rowid) FROM facts GROUP BY key)")
        conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
        print("[HEAL] OK")
    finally:
        conn.close()

def sync_to_gdrive():
    recursive_heal()
    ensure_filter_file()
    cmd = ["rclone", "sync", WORMHOLE_ROOT, DRIVE_REMOTE,
           "--filter-from", FILTER_FILE, "--fast-list", "--ignore-errors"]
    try:
        subprocess.run(cmd, check=True)
        print("[SYNC] Done.")
    except subprocess.CalledProcessError as e:
        print("[SYNC ERROR] " + str(e))

if __name__ == "__main__":
    sync_to_gdrive()
