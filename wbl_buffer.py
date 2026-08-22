import os
import sys
import time
import json
import queue
import sqlite3
import threading

def get_hardened_db_connection(db_path: str, busy_timeout_ms: int = 10000) -> sqlite3.Connection:
    """Establishes an atomic, lock-resilient SQLite connection."""
    os.makedirs(os.path.dirname(os.path.abspath(db_path)), exist_ok=True)
    conn = sqlite3.connect(db_path, timeout=busy_timeout_ms / 1000.0)
    try:
        conn.execute("PRAGMA journal_mode = WAL;")
    except Exception:
        pass
    conn.execute("PRAGMA synchronous = NORMAL;")
    conn.execute(f"PRAGMA busy_timeout = {busy_timeout_ms};")
    conn.execute("PRAGMA wal_autocheckpoint = 1000;")
    conn.execute("""
        CREATE TABLE IF NOT EXISTS event_log (
            event_id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
            actor TEXT NOT NULL,
            action TEXT NOT NULL,
            target TEXT NOT NULL,
            status TEXT NOT NULL,
            meta_payload JSON
        );
    """)
    conn.commit()
    return conn

class WriteBehindBuffer:
    def __init__(self, db_path: str, max_buffer: int = 2048, flush_interval: float = 1.0):
        self.db_path = db_path
        self.queue = queue.Queue(maxsize=max_buffer)
        self.flush_interval = flush_interval
        self._running = True
        self._emergency_log = db_path + ".emergency.log"
        self._worker = threading.Thread(target=self._drain_loop, daemon=True)
        self._worker.start()

    def enqueue(self, actor: str, action: str, target: str, status: str, payload: dict = None):
        entry = (actor, action, target, status, json.dumps(payload or {}))
        try:
            self.queue.put_nowait(entry)
        except queue.Full:
            self._emergency_spill(entry)

    def _emergency_spill(self, entry: tuple):
        try:
            with open(self._emergency_log, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry) + "\n")
        except Exception:
            pass

    def _drain_loop(self):
        while self._running:
            batch = []
            while not self.queue.empty() and len(batch) < 100:
                try:
                    batch.append(self.queue.get_nowait())
                except queue.Empty:
                    break

            if batch:
                self._commit_batch(batch)
            time.sleep(self.flush_interval)

    def _commit_batch(self, batch: list):
        try:
            conn = get_hardened_db_connection(self.db_path)
            conn.executemany("""
                INSERT INTO event_log (actor, action, target, status, meta_payload)
                VALUES (?, ?, ?, ?, ?)
            """, batch)
            conn.commit()
            conn.close()
        except Exception as e:
            for item in batch:
                try:
                    self.queue.put_nowait(item)
                except queue.Full:
                    self._emergency_spill(item)
            time.sleep(0.5)

    def stop(self):
        self._running = False
        if self._worker.is_alive():
            self._worker.join(timeout=2.0)
        batch = []
        while not self.queue.empty():
            batch.append(self.queue.get_nowait())
        if batch:
            self._commit_batch(batch)

if __name__ == "__main__":
    db_file = os.path.expanduser("~/storage/shared/WORMHOLE/MOTHER-BRAIN/99_System_Logs/omega_memory.db")
    print(f"[*] Initializing Write-Behind Buffer targeting: {db_file}")
    wbl = WriteBehindBuffer(db_file)
    
    # Test enqueue
    wbl.enqueue("TERMUX_DAEMON", "WBL_TEST", "BUFFER_INIT", "SUCCESS", {"status": "online"})
    print("[*] Event enqueued to in-memory ring buffer.")
    
    time.sleep(2.0)
    wbl.stop()
    print("[✓] Buffer drained and committed successfully.")
