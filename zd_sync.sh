#!/bin/bash
set -euo pipefail
LOG="/sdcard/WORMHOLE/99_System_Logs/zd_sync_$(date +%Y%m%d_%H%M%S).log"
echo "=== ZERO-DRIFT SYNC $(date) ===" | tee "$LOG"

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
