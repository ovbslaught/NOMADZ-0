from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional, List
import sqlite3, json, datetime, os, random

app = FastAPI(title="NOMADZ-0 Morphogenesis API", version="0.1.0")

DB_PATH = os.environ.get("OMEGA_DB_PATH", "../omega_memory.db")

ARCHETYPES = [
    "derelict_hull", "sensor_array", "anomaly_rift",
    "resource_cache", "stabilizer_node", "cryptid_trace"
]

class TelemetryPayload(BaseModel):
    session_id: str
    tick: int
    biome: str = "deep_space"
    player: dict
    world: dict
    local_context: Optional[dict] = {}

class SpawnDecision(BaseModel):
    decision: str
    archetype: str
    anchor_id: str
    intensity: float
    biome_modifier: float
    seed: int
    reason_tags: List[str]

@app.get("/")
def root():
    return {"status": "NOMADZ-0 online", "version": "0.1.0"}

@app.get("/world/state")
def world_state():
    return {
        "status": "active",
        "biome": "deep_space",
        "corruption": 0.0,
        "active_entities": 0,
        "timestamp": datetime.datetime.utcnow().isoformat()
    }

@app.post("/world/generate")
def generate(payload: TelemetryPayload):
    archetype = random.choice(ARCHETYPES)
    anchors = payload.local_context.get("reachable_spawn_anchors", ["anchor_01"])
    anchor = random.choice(anchors) if anchors else "anchor_01"
    return SpawnDecision(
        decision="spawn",
        archetype=archetype,
        anchor_id=anchor,
        intensity=round(random.uniform(0.2, 0.6), 2),
        biome_modifier=round(random.uniform(-0.1, 0.1), 3),
        seed=random.randint(100000, 999999),
        reason_tags=["exploration", "fallback_deterministic"]
    )

@app.post("/telemetry/log")
def log_telemetry(payload: TelemetryPayload):
    try:
        conn = sqlite3.connect(DB_PATH, timeout=5)
        conn.execute("PRAGMA journal_mode=WAL;")
        conn.execute("""
            CREATE TABLE IF NOT EXISTS telemetry (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT, session_id TEXT, tick INTEGER, biome TEXT, payload TEXT
            )
        """)
        conn.execute(
            "INSERT INTO telemetry (timestamp,session_id,tick,biome,payload) VALUES (?,?,?,?,?)",
            (datetime.datetime.utcnow().isoformat(),
             payload.session_id, payload.tick, payload.biome, json.dumps(payload.dict()))
        )
        conn.commit()
        conn.close()
        return {"status": "logged"}
    except Exception as e:
        return {"status": "db_unavailable", "error": str(e)}

@app.get("/entity/spawn")
def entity_info():
    return {"archetypes": ARCHETYPES}
