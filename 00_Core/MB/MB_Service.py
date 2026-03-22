"""
MB_Service.py — Mother-Brain Central Nervous System
====================================================
FastAPI service layer for NOMADZ-0 colony sim AI copilot.
Port: 7421
Termux path: /storage/shared/Wormhole/NOMADZ-0/00_Core/MB/MB_Service.py

Endpoints
---------
  GET  /pulse              — health check + system stats
  POST /query              — RAG-augmented LLM query
  POST /ingest_snapshot    — ingest a space snapshot into omega_memory.db
  GET  /world_state        — latest WORLD_VARS from omega_memory.db
  POST /world_state        — update WORLD_VARS via new snapshot
  GET  /missions           — active missions/quests from world state
  POST /log                — append entry to ouroboros_chain.jsonl WAL
  WS   /ws/copilot         — real-time streaming copilot (token-by-token)
  GET  /digest             — latest NOMADZ-0 research digest

Architecture
------------
  - FastAPI + uvicorn
  - aiosqlite async SQLite pool
  - httpx async HTTP for LLM calls
  - Background task polls brain-food/ every 60 s for new ingest files
  - Startup: init DB schema if missing, log startup to WAL
  - Shutdown: write shutdown snapshot to WAL
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import time
import uuid
from contextlib import asynccontextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import aiosqlite
import httpx
from fastapi import BackgroundTasks, FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BASE_DIR        = Path(os.getenv("MB_BASE_DIR", "/storage/shared/Wormhole/NOMADZ-0/00_Core/MB"))
DATA_DIR        = BASE_DIR / "Data"
BRAIN_FOOD_DIR  = BASE_DIR / "brain-food"
DB_PATH         = BASE_DIR / "omega_memory.db"
WAL_PATH        = DATA_DIR / "ouroboros_chain.jsonl"
DIGEST_DIR      = Path(os.getenv("MB_DIGEST_DIR", "/tmp/cron_tracking"))
DIGEST_FILE     = DIGEST_DIR / "latest_digest.md"

LLM_URL         = os.getenv("MB_LLM_URL",    "http://localhost:3002/completion")
SEARCH_API_URL  = os.getenv("MB_SEARCH_URL", "http://localhost:7420")

INGEST_POLL_INTERVAL = 60           # seconds between brain-food/ polls
LLM_TIMEOUT          = 90.0         # seconds
LLM_MAX_TOKENS       = int(os.getenv("MB_MAX_TOKENS", "512"))
CONTEXT_LIMIT_DEFAULT = 5

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("mother-brain")

# ---------------------------------------------------------------------------
# Global state
# ---------------------------------------------------------------------------

_startup_time: float = time.time()
_db: aiosqlite.Connection | None = None        # single shared connection (async-safe via queue)
_ingest_task: asyncio.Task | None = None
_http: httpx.AsyncClient | None = None

# ---------------------------------------------------------------------------
# Helpers: directories & DB
# ---------------------------------------------------------------------------

def _ensure_dirs() -> None:
    """Create required directories if they don't exist (Termux-safe)."""
    for d in (DATA_DIR, BRAIN_FOOD_DIR, DIGEST_DIR):
        d.mkdir(parents=True, exist_ok=True)


DB_SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS snapshots (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_id TEXT    UNIQUE NOT NULL,
    created_at  TEXT    NOT NULL,
    source      TEXT,
    metadata    TEXT                        -- JSON blob
);

CREATE TABLE IF NOT EXISTS chunks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    snapshot_id TEXT NOT NULL REFERENCES snapshots(snapshot_id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    content     TEXT NOT NULL,
    token_count INTEGER DEFAULT 0,
    created_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS embeddings (
    chunk_id    INTEGER PRIMARY KEY REFERENCES chunks(id) ON DELETE CASCADE,
    vector_json TEXT NOT NULL               -- JSON float array
);

CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
    content,
    chunk_id UNINDEXED,
    snapshot_id UNINDEXED,
    tokenize = 'porter ascii'
);
"""


async def _get_db() -> aiosqlite.Connection:
    """Return the open DB connection, raising if not initialised."""
    global _db
    if _db is None:
        raise RuntimeError("Database not initialised")
    return _db


async def _init_db() -> None:
    """Open DB connection and apply schema (idempotent)."""
    global _db
    log.info("Initialising omega_memory.db at %s", DB_PATH)
    _db = await aiosqlite.connect(str(DB_PATH))
    _db.row_factory = aiosqlite.Row
    await _db.executescript(DB_SCHEMA)
    await _db.commit()
    log.info("omega_memory.db ready")


async def _close_db() -> None:
    global _db
    if _db:
        await _db.close()
        _db = None
        log.info("omega_memory.db connection closed")

# ---------------------------------------------------------------------------
# Helpers: WAL / ouroboros_chain.jsonl
# ---------------------------------------------------------------------------

async def _append_wal(entry: dict[str, Any]) -> None:
    """Append a JSON log entry to ouroboros_chain.jsonl (fire-and-forget safe)."""
    entry.setdefault("timestamp", _now())
    entry.setdefault("id", str(uuid.uuid4()))
    line = json.dumps(entry, ensure_ascii=False)
    loop = asyncio.get_event_loop()
    await loop.run_in_executor(None, _write_line, str(WAL_PATH), line)


def _write_line(path: str, line: str) -> None:
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")

# ---------------------------------------------------------------------------
# Helpers: LLM client
# ---------------------------------------------------------------------------

async def _llm_complete(prompt: str, max_tokens: int = LLM_MAX_TOKENS) -> tuple[str, int]:
    """
    Send a completion request to the local llama.cpp server.

    Returns (answer_text, tokens_used).
    Falls back gracefully if the LLM is unreachable.
    """
    global _http
    if _http is None:
        return "LLM offline — service not yet started.", 0

    payload = {
        "prompt": prompt,
        "n_predict": max_tokens,
        "temperature": 0.7,
        "stop": ["</s>", "Human:", "User:"],
        "stream": False,
    }
    try:
        resp = await _http.post(LLM_URL, json=payload, timeout=LLM_TIMEOUT)
        resp.raise_for_status()
        data = resp.json()
        text   = data.get("content", "").strip()
        tokens = data.get("tokens_evaluated", 0) + data.get("tokens_predicted", 0)
        return text, tokens
    except (httpx.ConnectError, httpx.TimeoutException):
        log.warning("LLM unreachable at %s", LLM_URL)
        return "LLM offline — no response from local model.", 0
    except Exception as exc:  # noqa: BLE001
        log.error("LLM error: %s", exc)
        return f"LLM error: {exc}", 0


async def _llm_reachable() -> bool:
    """Quick liveness probe against the LLM endpoint."""
    global _http
    if _http is None:
        return False
    try:
        r = await _http.get(LLM_URL.replace("/completion", "/health"), timeout=5.0)
        return r.status_code < 500
    except Exception:
        # Try a tiny completion as fallback probe
        try:
            r = await _http.post(
                LLM_URL,
                json={"prompt": "ping", "n_predict": 1, "stream": False},
                timeout=5.0,
            )
            return r.status_code < 500
        except Exception:
            return False

# ---------------------------------------------------------------------------
# Helpers: omega_memory RAG search
# ---------------------------------------------------------------------------

async def _hybrid_search(query: str, limit: int = CONTEXT_LIMIT_DEFAULT) -> list[dict]:
    """
    Hybrid FTS5 + recency search over omega_memory.db.

    Returns list of {chunk_id, content, snapshot_id, created_at, rank}.
    """
    db = await _get_db()
    try:
        # FTS5 BM25 search
        async with db.execute(
            """
            SELECT
                c.id         AS chunk_id,
                c.content,
                c.snapshot_id,
                c.created_at,
                bm25(search_index) AS rank
            FROM search_index si
            JOIN chunks c ON c.id = si.chunk_id
            WHERE search_index MATCH ?
            ORDER BY rank
            LIMIT ?
            """,
            (_fts_escape(query), limit),
        ) as cur:
            rows = await cur.fetchall()
        return [dict(r) for r in rows]
    except Exception as exc:  # noqa: BLE001
        log.warning("FTS search failed (%s), falling back to LIKE", exc)
        # Fallback: simple LIKE search
        pattern = f"%{query[:200]}%"
        async with db.execute(
            """
            SELECT id AS chunk_id, content, snapshot_id, created_at, 0 AS rank
            FROM chunks
            WHERE content LIKE ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (pattern, limit),
        ) as cur:
            rows = await cur.fetchall()
        return [dict(r) for r in rows]


def _fts_escape(query: str) -> str:
    """Escape special FTS5 characters in a query string."""
    # Remove characters that break FTS5 syntax
    safe = re.sub(r'[^\w\s]', ' ', query)
    terms = safe.split()
    if not terms:
        return '""'
    return " OR ".join(terms[:10])  # limit to first 10 terms

# ---------------------------------------------------------------------------
# Helpers: snapshot ingest
# ---------------------------------------------------------------------------

async def _ingest_snapshot_data(snapshot: dict[str, Any]) -> int:
    """
    Insert a snapshot + its chunks into omega_memory.db.

    Expects snapshot dict with keys:
      snapshot_id (optional, auto-generated if missing)
      source      (str)
      metadata    (dict, optional)
      content     (str) — raw text OR
      chunks      (list[str]) — pre-split chunks

    Returns number of chunks inserted.
    """
    db = await _get_db()
    snap_id    = snapshot.get("snapshot_id") or str(uuid.uuid4())
    source     = snapshot.get("source", "unknown")
    metadata   = json.dumps(snapshot.get("metadata", {}))
    created_at = _now()

    raw_content = snapshot.get("content", "")
    raw_chunks  = snapshot.get("chunks", [])

    if raw_chunks:
        text_chunks = raw_chunks
    elif raw_content:
        text_chunks = _split_chunks(raw_content)
    else:
        log.warning("Snapshot %s has no content or chunks — skipping", snap_id)
        return 0

    # Upsert snapshot row
    await db.execute(
        """
        INSERT INTO snapshots (snapshot_id, created_at, source, metadata)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(snapshot_id) DO UPDATE SET
            created_at = excluded.created_at,
            source     = excluded.source,
            metadata   = excluded.metadata
        """,
        (snap_id, created_at, source, metadata),
    )

    chunk_count = 0
    for idx, chunk_text in enumerate(text_chunks):
        if not chunk_text.strip():
            continue
        cur = await db.execute(
            """
            INSERT INTO chunks (snapshot_id, chunk_index, content, token_count, created_at)
            VALUES (?, ?, ?, ?, ?)
            """,
            (snap_id, idx, chunk_text.strip(), len(chunk_text.split()), created_at),
        )
        chunk_id = cur.lastrowid
        # FTS index
        await db.execute(
            "INSERT INTO search_index (content, chunk_id, snapshot_id) VALUES (?, ?, ?)",
            (chunk_text.strip(), chunk_id, snap_id),
        )
        chunk_count += 1

    await db.commit()
    log.info("Ingested snapshot %s: %d chunks", snap_id, chunk_count)
    return chunk_count


def _split_chunks(text: str, max_words: int = 200) -> list[str]:
    """Split text into overlapping word chunks (simple, no NLTK dependency)."""
    words  = text.split()
    chunks = []
    step   = max_words - 40  # 40-word overlap
    for i in range(0, max(1, len(words)), step):
        chunk = " ".join(words[i : i + max_words])
        if chunk:
            chunks.append(chunk)
    return chunks

# ---------------------------------------------------------------------------
# Helpers: world state / WORLD_VARS
# ---------------------------------------------------------------------------

WORLD_VAR_KEYS = ("ERA", "BEACON_01", "RING_DECAY", "TIMER", "STATUS")


async def _get_latest_snapshot_meta() -> dict | None:
    """Return metadata dict from the most recent snapshot, or None."""
    db = await _get_db()
    async with db.execute(
        "SELECT metadata FROM snapshots ORDER BY created_at DESC LIMIT 1"
    ) as cur:
        row = await cur.fetchone()
    if not row:
        return None
    try:
        return json.loads(row["metadata"] or "{}")
    except json.JSONDecodeError:
        return {}


async def _get_world_vars() -> dict[str, Any]:
    """Extract WORLD_VARS from the latest snapshot metadata."""
    meta = await _get_latest_snapshot_meta()
    if not meta:
        return {k: None for k in WORLD_VAR_KEYS}
    world = meta.get("WORLD_VARS", meta)
    return {k: world.get(k) for k in WORLD_VAR_KEYS}

# ---------------------------------------------------------------------------
# Helpers: GitHub last push (best-effort, cached)
# ---------------------------------------------------------------------------

_github_cache: dict = {"ts": 0.0, "value": "unknown"}
GITHUB_CACHE_TTL = 300  # 5 min


async def _get_github_last_push() -> str:
    global _github_cache, _http
    now = time.time()
    if now - _github_cache["ts"] < GITHUB_CACHE_TTL:
        return _github_cache["value"]
    if _http is None:
        return "unknown"
    try:
        url = "https://api.github.com/repos/ovbslaught/NOMADZ-0/branches/Cosmic-key"
        r   = await _http.get(url, timeout=10.0, headers={"Accept": "application/vnd.github+json"})
        if r.status_code == 200:
            data  = r.json()
            value = data.get("commit", {}).get("commit", {}).get("author", {}).get("date", "unknown")
            _github_cache = {"ts": now, "value": value}
            return value
    except Exception as exc:
        log.debug("GitHub check failed: %s", exc)
    return _github_cache["value"]

# ---------------------------------------------------------------------------
# Helpers: omega_memory stats
# ---------------------------------------------------------------------------

async def _db_stats() -> dict[str, Any]:
    db = await _get_db()
    async with db.execute("SELECT COUNT(*) AS n FROM snapshots") as cur:
        snap_count = (await cur.fetchone())["n"]
    async with db.execute("SELECT COUNT(*) AS n FROM chunks") as cur:
        chunk_count = (await cur.fetchone())["n"]
    async with db.execute(
        "SELECT MAX(created_at) AS t FROM snapshots"
    ) as cur:
        last_snap = (await cur.fetchone())["t"]
    return {
        "snapshot_count":    snap_count,
        "chunk_count":       chunk_count,
        "last_snapshot_time": last_snap,
    }

# ---------------------------------------------------------------------------
# Helpers: brain-food/ auto-ingest background task
# ---------------------------------------------------------------------------

async def _brain_food_worker() -> None:
    """Background coroutine: poll brain-food/ every 60 s and ingest new JSON files."""
    log.info("brain-food watcher started (interval=%ds)", INGEST_POLL_INTERVAL)
    while True:
        try:
            await _process_brain_food()
        except Exception as exc:  # noqa: BLE001
            log.error("brain-food worker error: %s", exc)
        await asyncio.sleep(INGEST_POLL_INTERVAL)


async def _process_brain_food() -> None:
    """Ingest any .json files found in brain-food/ then move to brain-food/processed/."""
    processed_dir = BRAIN_FOOD_DIR / "processed"
    processed_dir.mkdir(exist_ok=True)

    json_files = list(BRAIN_FOOD_DIR.glob("*.json"))
    if not json_files:
        return

    log.info("brain-food: found %d file(s) to ingest", len(json_files))
    for fpath in json_files:
        try:
            text = fpath.read_text(encoding="utf-8")
            data = json.loads(text)
            if isinstance(data, list):
                for item in data:
                    await _ingest_snapshot_data(item)
            elif isinstance(data, dict):
                await _ingest_snapshot_data(data)
            dest = processed_dir / fpath.name
            fpath.rename(dest)
            log.info("brain-food: ingested and moved %s", fpath.name)
        except Exception as exc:  # noqa: BLE001
            log.error("brain-food: failed to ingest %s: %s", fpath.name, exc)

# ---------------------------------------------------------------------------
# Helpers: misc
# ---------------------------------------------------------------------------

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ok(data: Any) -> dict:
    return {"status": "ok", "data": data, "timestamp": _now()}


def _err(msg: str, code: int = 500) -> JSONResponse:
    return JSONResponse(
        status_code=code,
        content={"status": "error", "data": {"message": msg}, "timestamp": _now()},
    )

# ---------------------------------------------------------------------------
# Lifespan (startup / shutdown)
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """FastAPI lifespan: startup init and shutdown teardown."""
    global _ingest_task, _http, _startup_time

    _startup_time = time.time()
    log.info("Mother-Brain starting up...")
    _ensure_dirs()

    _http = httpx.AsyncClient(follow_redirects=True)
    await _init_db()

    await _append_wal({
        "event":   "startup",
        "service": "MB_Service",
        "port":    7421,
        "message": "Mother-Brain online",
    })

    _ingest_task = asyncio.create_task(_brain_food_worker())
    log.info("Mother-Brain ready on port 7421")

    yield  # ← application runs here

    # --- Shutdown ---
    log.info("Mother-Brain shutting down...")
    if _ingest_task:
        _ingest_task.cancel()
        try:
            await _ingest_task
        except asyncio.CancelledError:
            pass

    await _append_wal({
        "event":   "shutdown",
        "service": "MB_Service",
        "uptime_s": round(time.time() - _startup_time, 1),
        "message": "Mother-Brain going offline",
    })

    await _close_db()
    if _http:
        await _http.aclose()
    log.info("Mother-Brain shutdown complete")

# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Mother-Brain Service",
    description="NOMADZ-0 AI copilot central nervous system",
    version="2.0.0",
    lifespan=lifespan,
)

# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class QueryRequest(BaseModel):
    query:         str = Field(..., min_length=1, max_length=4096, description="Natural-language query")
    context_limit: int = Field(default=CONTEXT_LIMIT_DEFAULT, ge=1, le=20, description="Max RAG chunks to include")


class IngestSnapshotRequest(BaseModel):
    snapshot_id: str | None = Field(default=None, description="Optional UUID; auto-generated if omitted")
    source:      str         = Field(default="godot", description="Source identifier")
    metadata:    dict        = Field(default_factory=dict, description="Arbitrary metadata (WORLD_VARS etc.)")
    content:     str | None  = Field(default=None, description="Raw text content to chunk and ingest")
    chunks:      list[str]   = Field(default_factory=list, description="Pre-split text chunks")


class WorldStateUpdateRequest(BaseModel):
    ERA:       str | None = None
    BEACON_01: str | None = None
    RING_DECAY: str | None = None
    TIMER:     str | None = None
    STATUS:    str | None = None
    extra:     dict       = Field(default_factory=dict, description="Additional world-state keys")


class LogRequest(BaseModel):
    event:   str         = Field(..., description="Event type / name")
    message: str         = Field(default="", description="Human-readable log message")
    payload: dict        = Field(default_factory=dict, description="Arbitrary structured data")

# ---------------------------------------------------------------------------
# GET /pulse
# ---------------------------------------------------------------------------

@app.get("/pulse", summary="Health check and system stats")
async def pulse():
    """
    Return Mother-Brain service health and key metrics.

    Includes:
    - Current timestamp and uptime in seconds
    - omega_memory.db stats (snapshot count, chunk count, last snapshot time)
    - LLM reachability status
    - GitHub last push timestamp for NOMADZ-0/Cosmic-key branch
    """
    try:
        stats      = await _db_stats()
        llm_up     = await _llm_reachable()
        gh_push    = await _get_github_last_push()
        uptime_s   = round(time.time() - _startup_time, 1)

        return _ok({
            "uptime_s":          uptime_s,
            "omega_memory":      stats,
            "last_snapshot_time": stats["last_snapshot_time"],
            "llm_status":        "reachable" if llm_up else "unreachable",
            "github_last_push":  gh_push,
        })
    except Exception as exc:
        log.error("/pulse error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# POST /query
# ---------------------------------------------------------------------------

@app.post("/query", summary="RAG-augmented LLM query")
async def query(req: QueryRequest, background_tasks: BackgroundTasks):
    """
    Search omega_memory.db for relevant context, build an augmented prompt,
    and return a streamed (non-streaming here) LLM answer plus source metadata.

    Request body:
      query         — natural-language question
      context_limit — max number of memory chunks to include (default 5)

    Response data:
      answer       — LLM-generated response (or offline fallback)
      sources      — list of chunk metadata used as context
      tokens_used  — estimated tokens consumed
    """
    try:
        chunks = await _hybrid_search(req.query, req.context_limit)

        context_text = "\n\n---\n\n".join(
            f"[Source {i+1} | snapshot:{c['snapshot_id']} | chunk:{c['chunk_id']}]\n{c['content']}"
            for i, c in enumerate(chunks)
        ) if chunks else "No relevant memory found."

        prompt = (
            "You are Mother-Brain, the AI copilot of the NOMADZ-0 colony simulator.\n"
            "Use the memory context below to answer the operator's query concisely and accurately.\n"
            "If the context doesn't contain enough information, say so honestly.\n\n"
            f"=== MEMORY CONTEXT ===\n{context_text}\n\n"
            f"=== OPERATOR QUERY ===\n{req.query}\n\n"
            "=== MOTHER-BRAIN RESPONSE ===\n"
        )

        answer, tokens = await _llm_complete(prompt)

        sources = [
            {
                "chunk_id":    c["chunk_id"],
                "snapshot_id": c["snapshot_id"],
                "created_at":  c["created_at"],
                "preview":     c["content"][:200],
            }
            for c in chunks
        ]

        background_tasks.add_task(
            _append_wal,
            {
                "event":    "query",
                "query":    req.query[:300],
                "chunks":   len(chunks),
                "tokens":   tokens,
            },
        )

        return _ok({"answer": answer, "sources": sources, "tokens_used": tokens})

    except Exception as exc:
        log.error("/query error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# POST /ingest_snapshot
# ---------------------------------------------------------------------------

@app.post("/ingest_snapshot", summary="Ingest a space snapshot into omega_memory.db")
async def ingest_snapshot(req: IngestSnapshotRequest, background_tasks: BackgroundTasks):
    """
    Accept a JSON snapshot from Godot or any external source and store it in
    omega_memory.db, making it available for RAG queries.

    Provide either:
      content  — raw text (auto-chunked on ingest)
      chunks   — pre-split list of strings

    WORLD_VARS and other game state should go in metadata.
    """
    try:
        data = req.model_dump()
        chunk_count = await _ingest_snapshot_data(data)

        if chunk_count == 0:
            return _err("No content or chunks provided — nothing ingested", code=400)

        background_tasks.add_task(
            _append_wal,
            {
                "event":       "ingest_snapshot",
                "snapshot_id": data.get("snapshot_id"),
                "chunk_count": chunk_count,
                "source":      data.get("source"),
            },
        )

        return _ok({"chunk_count": chunk_count, "snapshot_id": data.get("snapshot_id")})

    except Exception as exc:
        log.error("/ingest_snapshot error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# GET /world_state
# ---------------------------------------------------------------------------

@app.get("/world_state", summary="Read current WORLD_VARS from omega_memory.db")
async def get_world_state():
    """
    Return the WORLD_VARS dictionary extracted from the most recent snapshot
    metadata stored in omega_memory.db.

    WORLD_VARS keys: ERA, BEACON_01, RING_DECAY, TIMER, STATUS
    Values are None if no snapshot has been ingested yet.
    """
    try:
        world_vars = await _get_world_vars()
        meta       = await _get_latest_snapshot_meta()

        db = await _get_db()
        async with db.execute(
            "SELECT snapshot_id, created_at, source FROM snapshots ORDER BY created_at DESC LIMIT 1"
        ) as cur:
            row = await cur.fetchone()

        snapshot_info = dict(row) if row else None
        return _ok({"WORLD_VARS": world_vars, "latest_snapshot": snapshot_info, "raw_meta": meta})

    except Exception as exc:
        log.error("/world_state GET error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# POST /world_state
# ---------------------------------------------------------------------------

@app.post("/world_state", summary="Update WORLD_VARS by writing a new snapshot")
async def post_world_state(req: WorldStateUpdateRequest, background_tasks: BackgroundTasks):
    """
    Merge the supplied WORLD_VARS fields with the current world state and
    persist a new snapshot entry in omega_memory.db.

    Partial updates are supported — only provided fields overwrite existing values.
    """
    try:
        current_vars = await _get_world_vars()

        new_vars = {**current_vars}
        update_dict = req.model_dump(exclude_none=True, exclude={"extra"})
        new_vars.update(update_dict)
        new_vars.update(req.extra)

        snapshot = {
            "source":   "world_state_update",
            "metadata": {"WORLD_VARS": new_vars},
            "content":  f"World state update at {_now()}: " + ", ".join(
                f"{k}={v}" for k, v in new_vars.items() if v is not None
            ),
        }
        chunk_count = await _ingest_snapshot_data(snapshot)

        background_tasks.add_task(
            _append_wal,
            {"event": "world_state_update", "WORLD_VARS": new_vars},
        )

        return _ok({"WORLD_VARS": new_vars, "chunk_count": chunk_count})

    except Exception as exc:
        log.error("/world_state POST error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# GET /missions
# ---------------------------------------------------------------------------

@app.get("/missions", summary="Return active missions/quests from world state")
async def get_missions():
    """
    Extract mission and quest data from the latest snapshot metadata.

    Looks for keys: missions, quests, active_missions, objectives in metadata.
    Returns an empty list if the world state contains no mission data.
    """
    try:
        meta = await _get_latest_snapshot_meta()
        if not meta:
            return _ok({"missions": [], "note": "No world state found"})

        missions = (
            meta.get("missions")
            or meta.get("quests")
            or meta.get("active_missions")
            or []
        )

        # Flatten objectives if nested
        if isinstance(missions, dict):
            missions = [{"name": k, **v} if isinstance(v, dict) else {"name": k, "data": v}
                        for k, v in missions.items()]

        objectives = meta.get("objectives", [])
        return _ok({"missions": missions, "objectives": objectives})

    except Exception as exc:
        log.error("/missions error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# POST /log
# ---------------------------------------------------------------------------

@app.post("/log", summary="Append an operational log entry to ouroboros_chain.jsonl")
async def append_log(req: LogRequest):
    """
    Append a structured log entry to the ouroboros_chain.jsonl write-ahead log.

    This is the persistent audit trail for all Mother-Brain operations.
    Entries are newline-delimited JSON, each with a UUID and ISO8601 timestamp.
    """
    try:
        entry = {
            "event":   req.event,
            "message": req.message,
            **req.payload,
        }
        await _append_wal(entry)
        return _ok({"logged": True, "event": req.event})

    except Exception as exc:
        log.error("/log error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# GET /digest
# ---------------------------------------------------------------------------

@app.get("/digest", summary="Return the latest NOMADZ-0 research digest")
async def get_digest():
    """
    Return the most recent research digest document.

    Reads from:
      1. /tmp/cron_tracking/latest_digest.md  (primary)
      2. Any .md or .txt file in /tmp/cron_tracking/ (fallback, most recent)
      3. Returns 'No digest available' message if none found.
    """
    try:
        # Primary path
        if DIGEST_FILE.exists():
            content = DIGEST_FILE.read_text(encoding="utf-8")
            return _ok({"digest": content, "source": str(DIGEST_FILE)})

        # Fallback: scan for any markdown/text file
        candidates = sorted(
            list(DIGEST_DIR.glob("*.md")) + list(DIGEST_DIR.glob("*.txt")),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        ) if DIGEST_DIR.exists() else []

        if candidates:
            content = candidates[0].read_text(encoding="utf-8")
            return _ok({"digest": content, "source": str(candidates[0])})

        return _ok({"digest": None, "note": "No digest available"})

    except Exception as exc:
        log.error("/digest error: %s", exc)
        return _err(str(exc))

# ---------------------------------------------------------------------------
# WebSocket /ws/copilot  — streaming Mother-Brain copilot
# ---------------------------------------------------------------------------

class CopilotSession:
    """Manages a single WebSocket copilot session with streaming LLM output."""

    def __init__(self, ws: WebSocket):
        self.ws      = ws
        self.session_id = str(uuid.uuid4())[:8]

    async def send_json(self, data: dict) -> None:
        try:
            await self.ws.send_json(data)
        except Exception:
            pass  # Connection may have dropped

    async def stream_llm(self, prompt: str) -> str:
        """
        Stream LLM response token by token over the WebSocket.

        Falls back to a single non-streaming call if the LLM doesn't
        support streaming or is offline.
        """
        global _http
        if _http is None:
            msg = "LLM offline — Mother-Brain cannot connect to local model."
            await self.send_json({"type": "token",    "token": msg})
            await self.send_json({"type": "complete", "text":  msg})
            return msg

        payload = {
            "prompt":    prompt,
            "n_predict": LLM_MAX_TOKENS,
            "temperature": 0.7,
            "stop":      ["</s>", "Human:", "User:"],
            "stream":    True,
        }

        full_text = ""
        try:
            async with _http.stream("POST", LLM_URL, json=payload, timeout=LLM_TIMEOUT) as resp:
                resp.raise_for_status()
                async for raw_line in resp.aiter_lines():
                    if not raw_line.strip():
                        continue
                    # llama.cpp server-sent events: "data: {...}"
                    line = raw_line.removeprefix("data:").strip()
                    if line == "[DONE]":
                        break
                    try:
                        chunk = json.loads(line)
                        token = chunk.get("content", "")
                        if token:
                            full_text += token
                            await self.send_json({"type": "token", "token": token})
                        if chunk.get("stop", False):
                            break
                    except json.JSONDecodeError:
                        continue

        except (httpx.ConnectError, httpx.TimeoutException):
            full_text = "LLM offline — no response from local model."
            await self.send_json({"type": "token", "token": full_text})

        except Exception as exc:
            full_text = f"LLM error: {exc}"
            await self.send_json({"type": "error", "message": full_text})

        await self.send_json({"type": "complete", "text": full_text})
        return full_text

    async def run(self) -> None:
        """Main session loop: receive commands, build prompt, stream response."""
        log.info("Copilot session %s opened", self.session_id)
        await self.send_json({
            "type":    "connected",
            "session": self.session_id,
            "message": "Mother-Brain copilot online. Send {\"query\": \"...\"}",
        })

        try:
            while True:
                raw = await self.ws.receive_text()
                try:
                    msg = json.loads(raw)
                except json.JSONDecodeError:
                    msg = {"query": raw}

                query_text = msg.get("query") or msg.get("text") or str(msg)
                ctx_limit  = int(msg.get("context_limit", CONTEXT_LIMIT_DEFAULT))

                await self.send_json({"type": "ack", "query": query_text})

                # RAG context retrieval
                try:
                    chunks = await _hybrid_search(query_text, ctx_limit)
                    context_text = "\n\n---\n\n".join(
                        f"[Memory {i+1}]\n{c['content']}" for i, c in enumerate(chunks)
                    ) if chunks else "No relevant memory."
                except Exception as exc:
                    context_text = f"Memory retrieval failed: {exc}"
                    chunks = []

                prompt = (
                    "You are Mother-Brain, the AI copilot of the NOMADZ-0 colony simulator.\n"
                    "Be concise, strategic, and speak with calm authority.\n\n"
                    f"=== MEMORY CONTEXT ===\n{context_text}\n\n"
                    f"=== OPERATOR COMMAND ===\n{query_text}\n\n"
                    "=== MOTHER-BRAIN ===\n"
                )

                full_response = await self.stream_llm(prompt)

                await _append_wal({
                    "event":    "copilot_query",
                    "session":  self.session_id,
                    "query":    query_text[:300],
                    "chunks":   len(chunks),
                    "response_len": len(full_response),
                })

        except WebSocketDisconnect:
            log.info("Copilot session %s disconnected", self.session_id)
        except Exception as exc:
            log.error("Copilot session %s error: %s", self.session_id, exc)
            try:
                await self.send_json({"type": "error", "message": str(exc)})
            except Exception:
                pass


@app.websocket("/ws/copilot")
async def ws_copilot(websocket: WebSocket):
    """
    Real-time Mother-Brain copilot WebSocket endpoint.

    Protocol (JSON messages):
      Client → Server:
        {"query": "...", "context_limit": 5}

      Server → Client:
        {"type": "connected", "session": "...", "message": "..."}
        {"type": "ack",       "query": "..."}
        {"type": "token",     "token": "..."}      ← streamed tokens
        {"type": "complete",  "text":  "..."}      ← full response
        {"type": "error",     "message": "..."}
    """
    await websocket.accept()
    session = CopilotSession(websocket)
    await session.run()

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "MB_Service:app",
        host="0.0.0.0",
        port=7421,
        log_level="info",
        reload=False,
        ws_ping_interval=30,
        ws_ping_timeout=10,
    )
