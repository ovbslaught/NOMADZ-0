#!/bin/bash

LOG="/sdcard/WORMHOLE/99_System_Logs/zd_diag_$(date +%Y%m%d_%H%M%S).log"
mkdir -p /sdcard/WORMHOLE/99_System_Logs

echo "=== ZERO-DRIFT DIAGNOSTIC $(date) ===" | tee "$LOG"

# ── 1. rclone version (suppress noisy backend errors) ────────────────────────
echo "[1] rclone version:" | tee -a "$LOG"
rclone version 2>/dev/null | head -3 | tee -a "$LOG"

# ── 2. gdrive reachability ────────────────────────────────────────────────────
echo "[2] gdrive remote ping:" | tee -a "$LOG"
rclone lsd gdrive:WORMHOLE --max-depth 1 2>&1 | tee -a "$LOG"
PING_STATUS=$?

if [ $PING_STATUS -ne 0 ]; then
  echo "[WARN] gdrive unreachable — check token. Run: rclone config reconnect gdrive:" | tee -a "$LOG"
  exit 1
fi

# ── 3. Drift check ────────────────────────────────────────────────────────────
echo "[3] Drift delta:" | tee -a "$LOG"
rclone check /sdcard/WORMHOLE gdrive:WORMHOLE \
  --one-way --log-level INFO 2>&1 | tee -a "$LOG"

echo "=== DIAG COMPLETE ===" | tee -a "$LOG"

# ── 4. Purge stale staging ────────────────────────────────────────────────────
echo "=== STAGING PURGE ===" | tee -a "$LOG"
for STALE in "BRAIN-HOLE" "BRAIN-FOOD"; do
  LOCAL="/sdcard/WORMHOLE/$STALE"
  if [ -d "$LOCAL" ]; then
    rm -rf "$LOCAL"
    echo "[PURGE LOCAL] $LOCAL" | tee -a "$LOG"
  else
    echo "[SKIP] $LOCAL absent locally" | tee -a "$LOG"
  fi
  rclone purge "gdrive:WORMHOLE/$STALE" 2>/dev/null \
    && echo "[PURGE REMOTE] $STALE removed" | tee -a "$LOG" \
    || echo "[INFO] $STALE not on remote — OK" | tee -a "$LOG"
done

# ── 5. Full sync ──────────────────────────────────────────────────────────────
echo "=== ZERO-DRIFT SYNC $(date) ===" | tee -a "$LOG"
rclone sync /sdcard/WORMHOLE gdrive:WORMHOLE \
  --progress \
  --transfers 4 \
  --checkers 8 \
  --drive-chunk-size 32M \
  --log-file "$LOG" \
  --log-level INFO \
  --exclude ".git/**" \
  --exclude "*.tmp" \
  --exclude "__pycache__/**"
echo "=== SYNC COMPLETE $(date) ===" | tee -a "$LOG"

