import os
import json
import time
import sqlite3
import uuid
import urllib.request
import urllib.error
from datetime import datetime, timezone

class JaxCoreDB:
    def __init__(self, db_path=None):
        self.system_instruction = (
            "JAX - NOMADZ Cohesion Loop Anchor. "
            "Prioritize: memory, speed, encryption, SQL ledger."
        )
        self.api_key = os.getenv("GROK_API_KEY", "xai-dummy-key")
        self.model = "grok-4"
        self.base_url = "https://api.x.ai/v1/chat/completions"
        self.session_id = f"jax_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
        self.db_path = db_path or "/data/data/com.termux/files/home/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db"
        self.memory = []
        self.max_memory = 13
        self.backoff = 1
        self.cache = {}

        os.makedirs(os.path.dirname(self.db_path), exist_ok=True)
        self._init_schema()
        self._log_session_start()

    def _get_db_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    def _init_schema(self):
        with self._get_db_connection() as conn:
            conn.executescript("""
            CREATE TABLE IF NOT EXISTS write_back_log (
                wbl_id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                operation TEXT NOT NULL,
                target_table TEXT NOT NULL,
                record_key TEXT NOT NULL,
                payload TEXT NOT NULL,
                state TEXT DEFAULT 'PENDING',
                retry_count INTEGER DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                synced_at DATETIME
            );

            CREATE TABLE IF NOT EXISTS session_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                actor TEXT NOT NULL,
                action TEXT NOT NULL,
                targets TEXT,
                status TEXT,
                payload TEXT,
                event_time TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                export_directive TEXT DEFAULT 'AUTO_EXPORT_TO_DOCS'
            );

            CREATE TABLE IF NOT EXISTS facts (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );
            """)
            conn.commit()

    def queue_write_back(self, operation, target_table, record_key, payload):
        try:
            with self._get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO write_back_log
                    (session_id, operation, target_table, record_key, payload, state)
                    VALUES (?, ?, ?, ?, ?, 'PENDING')
                    """,
                    (
                        self.session_id,
                        operation.upper(),
                        target_table,
                        record_key,
                        json.dumps(payload, default=str)
                    )
                )
                conn.commit()
                return cursor.lastrowid
        except Exception as e:
            print(f"[JAX DB ERROR] Queue write-back failed: {e}")
            return -1

    def _log_session_start(self):
        self.queue_write_back(
            operation="INSERT",
            target_table="session_logs",
            record_key=self.session_id,
            payload={
                "actor": "JAX_v3_CORE",
                "action": "SESSION_INIT",
                "targets": "omega_memory_LIVE.db",
                "status": "ONLINE",
                "event_time": datetime.now(timezone.utc).isoformat()
            }
        )

    def generate_content(self, prompt):
        result = f"[MOCK JAX ECHO] Processed: '{prompt}'"
        event_time = datetime.now(timezone.utc).isoformat()
        turn_data = {
            "prompt": prompt,
            "response": result,
            "event_time": event_time
        }

        self.memory.append(turn_data)
        if len(self.memory) > self.max_memory:
            self.memory.pop(0)

        turn_key = f"{self.session_id}_turn_{len(self.memory)}"
        self.queue_write_back(
            operation="INSERT",
            target_table="session_logs",
            record_key=turn_key,
            payload=turn_data
        )
        return result

if __name__ == "__main__":
    print("==================================================")
    print("JAX v3.0 DB-WIRED | OUTBOX ENGINE INITIALIZING...")
    print("==================================================")
    jax = JaxCoreDB()
    print(f"[*] Session ID: {jax.session_id}")
    print("[*] Testing queue_write_back...")
    test_response = jax.generate_content("NOMADZ outbox test turn 001")
    print(f"[*] JAX Output: {test_response}")
    print("[*] Turn successfully pushed to write_back_log.")
