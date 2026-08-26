#!/bin/bash
set -euo pipefail
LOG="/sdcard/WORMHOLE/99_System_Logs/zd_purge_$(date +%Y%m%d_%H%M%S).log"
echo "=== STAGING PURGE $(date) ===" | tee "$LOG"

for STALE in "BRAIN-HOLE" "BRAIN-FOOD"; do
  LOCAL="/sdcard/WORMHOLE/$STALE"
  if [ -d "$LOCAL" ]; then
    echo "[PURGE LOCAL] $LOCAL" | tee -a "$LOG"
    rm -rf "$LOCAL"
  else
    echo "[SKIP] $LOCAL not found locally" | tee -a "$LOG"
  fi

  echo "[PURGE REMOTE] gdrive:WORMHOLE/$STALE" | tee -a "$LOG"
  rclone purge "gdrive:WORMHOLE/$STALE" 2>&1 | tee -a "$LOG" || \
    echo "[INFO] Remote path absent — OK" | tee -a "$LOG"
done

echo "=== STAGING PURGE COMPLETE ===" | tee -a "$LOG"
