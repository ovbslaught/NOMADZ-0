#!/bin/bash
INTERVAL=1800
LOG_DIR="/sdcard/WORMHOLE/99_System_Logs"

while true; do
  STAMP=$(date +%Y%m%d_%H%M%S)
  rclone sync /sdcard/WORMHOLE gdrive:WORMHOLE \
    --transfers 2 --checkers 4 \
    --drive-chunk-size 16M \
    --log-file "$LOG_DIR/sync_$STAMP.log" \
    --log-level NOTICE \
    --exclude ".git/**" --exclude "*.tmp" --exclude "__pycache__/**"
  sleep $INTERVAL
done
