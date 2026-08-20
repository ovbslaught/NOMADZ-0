import sys
import json
import time
import sqlite3

DB_PATH = "/data/data/com.termux/files/home/WORMHOLE/NOMADZ-SPINE/omega_memory_LIVE.db"

def flush_outbox():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM write_back_log WHERE state = 'PENDING' ORDER BY wbl_id ASC")
    rows = cursor.fetchall()
    processed_count = 0

    for row in rows:
        wbl_id = row["wbl_id"]
        session_id = row["session_id"]
        target_table = row["target_table"]
        record_key = row["record_key"]
        retry_count = row["retry_count"]

        try:
            payload = json.loads(row["payload"])
        except Exception:
            payload = {"raw_payload": row["payload"]}

        try:
            if target_table == "session_logs":
                actor = payload.get("actor", "JAX_CORE")
                action = payload.get("action", "CHAT_TURN" if "prompt" in payload else "LOG_EVENT")
                targets = payload.get("targets", record_key)
                status = payload.get("status", "SYNCED")
                event_time = payload.get("event_time", None)
                export_directive = payload.get("export_directive", "AUTO_EXPORT_TO_DOCS")

                cursor.execute(
                    "INSERT INTO session_logs "
                    "(session_id, actor, action, targets, status, payload, event_time, export_directive, created_at) "
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)",
                    (session_id, actor, action, targets, status, json.dumps(payload, default=str), event_time, export_directive)
                )

            elif target_table == "facts":
                key = record_key or payload.get("key")
                value = payload.get("value", json.dumps(payload))
                cursor.execute(
                    "INSERT INTO facts (key, value, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP) "
                    "ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP",
                    (key, str(value))
                )

            else:
                raise ValueError(f"Unsupported target_table: {target_table}")

            cursor.execute(
                "UPDATE write_back_log SET state = 'SYNCED', synced_at = CURRENT_TIMESTAMP WHERE wbl_id = ?",
                (wbl_id,)
            )
            conn.commit()
            processed_count += 1
            print(f"[FLUSHER] wbl_id={wbl_id} -> {target_table} (SYNCED)")

        except Exception as err:
            conn.rollback()
            new_retries = retry_count + 1
            new_state = "FAILED" if new_retries >= 5 else "PENDING"
            cursor.execute(
                "UPDATE write_back_log SET retry_count = ?, state = ? WHERE wbl_id = ?",
                (new_retries, new_state, wbl_id)
            )
            conn.commit()
            print(f"[FLUSHER ERROR] wbl_id={wbl_id} failed ({err}). Retries: {new_retries}, State: {new_state}")

    conn.close()
    return processed_count

def daemon_loop(interval=5):
    print(f"[*] Starting Outbox Flusher Daemon (poll interval: {interval}s)...")
    try:
        while True:
            drained = flush_outbox()
            if drained > 0:
                print(f"[*] Batch complete. Drained {drained} events.")
            time.sleep(interval)
    except KeyboardInterrupt:
        print("Flusher stopped.")

if __name__ == "__main__":
    if "--daemon" in sys.argv:
        daemon_loop()
    else:
        print("[*] Running single-pass outbox flush...")
        count = flush_outbox()
        print(f"[*] Done. Drained {count} pending events.")
