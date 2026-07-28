import sqlite3
import json
from datetime import datetime
from fastapi import FastAPI, Request
import uvicorn

app = FastAPI()
DB_PATH = "omegamemory.db"

def init_db():
    # Initialize the omegamemory database with WAL mode for concurrency
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS vcn_ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            node TEXT,
            pillar INTEGER,
            event TEXT,
            payload TEXT
        )
    """)
    conn.commit()
    conn.close()

@app.post("/gossip")
async def receive_gossip(request: Request):
    try:
        data = await request.json()
        
        # Extract the VCN packet data sent by Godot
        ts = data.get("ts", datetime.utcnow().isoformat())
        node = data.get("node", "UNKNOWN_NODE")
        pillar = data.get("pillar", 0)
        event = data.get("event", "unspecified_event")
        payload = json.dumps(data.get("data", {}))
        
        # Write to SQLite
        conn = sqlite3.connect(DB_PATH)
        conn.execute("PRAGMA journal_mode=WAL;")
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO vcn_ledger (timestamp, node, pillar, event, payload) VALUES (?, ?, ?, ?, ?)",
            (ts, node, pillar, event, payload)
        )
        conn.commit()
        conn.close()
        
        print(f"[GOSSIP] Logged event '{event}' from '{node}' into omegamemory.db (WAL)")
        return {"status": "success", "recorded_ts": ts}
        
    except Exception as e:
        print(f"[GOSSIP] ERROR handling packet: {str(e)}")
        return {"status": "error", "reason": str(e)}

if __name__ == "__main__":
    print("[*] Initializing omegamemory.db...")
    init_db()
    print("[*] VCN Gossip Daemon listening on http://127.0.0.1:7331/gossip")
    uvicorn.run(app, host="127.0.0.1", port=7331, log_level="warning")
