#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ==============================================================================
# NOMADZ MOTHER-BRAIN HEAL CYCLE
# Target: Autonomous Integrity Check, Storage Verification, & Memory WAL Heal
# ==============================================================================

export HOME="/data/data/com.termux/files/home"
export WORMHOLE_DIR="$HOME/WORMHOLE"
export VAULT_DIR="$WORMHOLE_DIR/-VAULT-"
export LOG_DIR="$VAULT_DIR/LOGS"
export DB_PATH="$VAULT_DIR/omega_memory.db"
export TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
export RUN_ID=$(date -u +"%Y%m%d_%H%M%S")
export LOG_FILE="$LOG_DIR/heal_cycle_${RUN_ID}.log"

# --- 1. DIRECTORY STRUCTURE INITIALIZATION ---
REQUIRED_DIRS=(
  "$WORMHOLE_DIR/-VAULT-"
  "$WORMHOLE_DIR/MOTHER-BRAIN"
  "$WORMHOLE_DIR/OMEGA-BRAIN"
  "$WORMHOLE_DIR/VULTURE-BRAIN"
  "$WORMHOLE_DIR/FATHER-BRAIN"
  "$WORMHOLE_DIR/GEO-BRAIN"
  "$WORMHOLE_DIR/COSMIC-BRAIN"
  "$LOG_DIR"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
done

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$TIMESTAMP] [INFO] Starting NOMADZ Mother-Brain Heal Cycle (Run ID: $RUN_ID)..."

# --- 2. SQLITE WAL INTEGRITY AND HEAL ---
if command -v sqlite3 >/dev/null 2>&1; then
  if [ ! -f "$DB_PATH" ]; then
    echo "[$TIMESTAMP] [WARN] $DB_PATH not found. Initializing database with WAL mode..."
    sqlite3 "$DB_PATH" "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS system_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp TEXT, event TEXT, status TEXT);"
  else
    echo "[$TIMESTAMP] [INFO] Verifying SQLite database integrity at $DB_PATH..."
    INTEGRITY_CHECK=$(sqlite3 "$DB_PATH" "PRAGMA integrity_check;")
    if [ "$INTEGRITY_CHECK" = "ok" ]; then
      echo "[$TIMESTAMP] [INFO] Integrity verified: OK. Checkpointing WAL..."
      sqlite3 "$DB_PATH" "PRAGMA wal_checkpoint(TRUNCATE);"
    else
      echo "[$TIMESTAMP] [ERROR] Database corruption detected: $INTEGRITY_CHECK. Attempting vacuum/recovery..."
      sqlite3 "$DB_PATH" "VACUUM;" || true
    fi
  fi
else
  echo "[$TIMESTAMP] [WARN] sqlite3 binary not found. Skipping SQL WAL maintenance."
fi

# --- 3. STORAGE AND RCLONE SYNC AUDIT ---
if command -v rclone >/dev/null 2>&1; then
  if rclone listremotes | grep -q "^gdrive:"; then
    echo "[$TIMESTAMP] [INFO] Remote 'gdrive' detected. Checking connection..."
    if rclone lsd gdrive:WORMHOLE --max-depth 1 >/dev/null 2>&1; then
      echo "[$TIMESTAMP] [INFO] Remote WORMHOLE link verified."
    else
      echo "[$TIMESTAMP] [WARN] Remote 'gdrive:WORMHOLE' unreachable or uninitialized."
    fi
  else
    echo "[$TIMESTAMP] [WARN] rclone remote 'gdrive' not configured."
  fi
fi

# --- 4. RECORD APPEND-ONLY STATUS ---
APPEND_LOG="$VAULT_DIR/heal_history.jsonl"
cat << JSONENTRY >> "$APPEND_LOG"
{"timestamp": "$TIMESTAMP", "run_id": "$RUN_ID", "status": "COMPLETED", "db_path": "$DB_PATH", "exit_code": 0}
JSONENTRY

echo "[$TIMESTAMP] [INFO] Heal cycle complete. Log: $LOG_FILE"
exit 0
