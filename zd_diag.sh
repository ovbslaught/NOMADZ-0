#!/bin/bash
set -euo pipefail
LOG="/sdcard/WORMHOLE/99_System_Logs/zd_diag_$(date +%Y%m%d_%H%M%S).log"
echo "=== ZERO-DRIFT DIAGNOSTIC $(date) ===" | tee "$LOG"

echo "[1] rclone version:" | tee -a "$LOG"
rclone version 2>&1 | head -3 | tee -a "$LOG"

echo "[2] gdrive remote ping:" | tee -a "$LOG"
rclone lsd gdrive:WORMHOLE --max-depth 1 2>&1 | tee -a "$LOG"

echo "[3] Drift delta (local → gdrive):" | tee -a "$LOG"
rclone check /sdcard/WORMHOLE gdrive:WORMHOLE \
  --one-way --log-level INFO 2>&1 | tee -a "$LOG"

echo "=== DIAG COMPLETE. Log: $LOG ===" | tee -a "$LOG"
