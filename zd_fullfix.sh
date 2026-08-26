#!/bin/bash
set -euo pipefail

# ── 1. Recreate missing WORMHOLE skeleton ─────────────────────────────────────
echo "[INIT] Creating WORMHOLE directory skeleton..."
mkdir -p /sdcard/WORMHOLE/99_System_Logs
mkdir -p /sdcard/WORMHOLE/OMEGA-BRAIN/agent_substrate/{db,python_agent,logs}
mkdir -p /sdcard/WORMHOLE/MOTHER-BRAIN
mkdir -p /sdcard/WORMHOLE/VULTURE-BRAIN
mkdir -p /sdcard/WORMHOLE/COSMIC-BRAIN
mkdir -p /sdcard/WORMHOLE/GEO-BRAIN
mkdir -p /sdcard/WORMHOLE/NOMADZ-0
mkdir -p /sdcard/WORMHOLE/-VAULT-

LOG="/sdcard/WORMHOLE/99_System_Logs/zd_diag_$(date +%Y%m%d_%H%M%S).log"
echo "[OK] Skeleton created. Log target: $LOG"

# ── 2. Diagnostic ─────────────────────────────────────────────────────────────
echo "=== ZERO-DRIFT DIAGNOSTIC $(date) ===" | tee "$LOG"

echo "[1] rclone version:" | tee -a "$LOG"
rclone version 2>&1 | head -3 | tee -a "$LOG"

echo "[2] gdrive remote ping:" | tee -a "$LOG"
rclone lsd gdrive:WORMHOLE --max-depth 1 2>&1 | tee -a "$LOG"

echo "[3] Drift delta (local → gdrive):" | tee -a "$LOG"
rclone check /sdcard/WORMHOLE gdrive:WORMHOLE \
  --one-way --log-level INFO 2>&1 | tee -a "$LOG"

echo "=== DIAG COMPLETE ===" | tee -a "$LOG"

# ── 3. Purge stale staging layers ─────────────────────────────────────────────
echo "=== STAGING PURGE $(date) ===" | tee -a "$LOG"
for STALE in "BRAIN-HOLE" "BRAIN-FOOD"; do
  LOCAL="/sdcard/WORMHOLE/$STALE"
  [ -d "$LOCAL" ] && rm -rf "$LOCAL" && echo "[PURGE LOCAL] $LOCAL" | tee -a "$LOG" \
    || echo "[SKIP] $LOCAL absent locally" | tee -a "$LOG"
  rclone purge "gdrive:WORMHOLE/$STALE" 2>&1 | tee -a "$LOG" \
    || echo "[INFO] $STALE not on remote — OK" | tee -a "$LOG"
done
echo "=== STAGING PURGE COMPLETE ===" | tee -a "$LOG"

# ── 4. Full sync — local is SSOT ──────────────────────────────────────────────
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

