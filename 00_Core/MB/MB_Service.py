import sqlite3
import json
import time
import os
from fastapi import FastAPI, Request, BackgroundTasks
import uvicorn

app = FastAPI(title="MOTHER-BRAIN", version="0.1.0")

DB_PATH = os.path.expanduser("~/NOMADZ-0/WORMHOLE/MOTHER-BRAIN/omegamemory.db")

def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS vcn_ledger (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            node TEXT,
            pillar INTEGER,
            event TEXT,
            payload TEXT,
            hash TEXT
        )
    """)
    conn.commit()
    conn.close()
    print("[*] OMEGA DB Initialized in WAL Mode")

@app.on_event("startup")
def startup_event():
    init_db()

@app.post("/gossip")
async def receive_gossip(request: Request, background_tasks: BackgroundTasks):
    packet = await request.json()
    
    ts = packet.get("ts", time.strftime("%Y-%m-%dT%H:%M:%SZ"))
    node = packet.get("node", "UNKNOWN")
    pillar = packet.get("pillar", 0)
    event = packet.get("event", "UNKNOWN_EVENT")
    payload = json.dumps(packet.get("data", {}))
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO vcn_ledger (timestamp, node, pillar, event, payload)
        VALUES (?, ?, ?, ?, ?)
    """, (ts, node, pillar, event, payload))
    conn.commit()
    conn.close()
    
    return {"status": "ACK", "recorded_ts": ts}

if __name__ == "__main__":
    print("[*] Starting MOTHER-BRAIN on 0.0.0.0:7421")
    uvicorn.run(app, host="0.0.0.0", port=7421)
