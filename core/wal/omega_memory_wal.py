#!/usr/bin/env python3
import os, json, sqlite3, threading
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Generator, Dict, Any, List

class OmegaWALManager:
    _local = threading.local()

    def __init__(self, db_path: str = "$DB_PATH", busy_timeout_ms: int = 5000):
        self.db_path = os.path.abspath(db_path)
        self.busy_timeout_ms = busy_timeout_ms
        self._init_db()

    def _get_connection(self) -> sqlite3.Connection:
        if not hasattr(self._local, "conn") or self._local.conn is None:
            conn = sqlite3.connect(self.db_path, timeout=self.busy_timeout_ms / 1000.0)
            conn.execute("PRAGMA journal_mode=WAL;")
            conn.execute("PRAGMA synchronous=NORMAL;")
            conn.execute(f"PRAGMA busy_timeout={self.busy_timeout_ms};")
            self._local.conn = conn
        return self._local.conn

    def _init_db(self) -> None:
        conn = self._get_connection()
        with conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS telemetry (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    ts TEXT NOT NULL,
                    app TEXT NOT NULL,
                    level TEXT NOT NULL,
                    msg TEXT NOT NULL,
                    payload TEXT
                );
            """)

    @contextmanager
    def transaction(self) -> Generator[sqlite3.Cursor, None, None]:
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            conn.execute("BEGIN IMMEDIATE;")
            yield cursor
            conn.commit()
        except Exception:
            conn.rollback()
            raise

    def append(self, app: str, level: str, msg: str, payload: Dict[str, Any] = None) -> int:
        ts = datetime.now(timezone.utc).isoformat()
        with self.transaction() as cur:
            cur.execute(
                "INSERT INTO telemetry (ts, app, level, msg, payload) VALUES (?, ?, ?, ?, ?)",
                (ts, app, level, msg, json.dumps(payload or {}))
            )
            return cur.lastrowid
