
#!/bin/bash
# rclone_cron_setup.sh - Sets up rclone sync cron for NOMADZ-0 -> Google Drive
# Usage: bash rclone_cron_setup.sh
set -e

REPO_DIR="/workspaces/NOMADZ-0"
DRIVE_REMOTE="gdrive:NOMADZ-0"
LOG_FILE="/tmp/rclone_sync.log"

# Install rclone if missing
if ! command -v rclone &> /dev/null; then
    echo "Installing rclone..."
    curl https://rclone.org/install.sh | sudo bash
fi

# Create cron entry (every 30 min)
CRONJOB="*/30 * * * * rclone sync $REPO_DIR $DRIVE_REMOTE --exclude .git/** --exclude *.import --log-file=$LOG_FILE 2>&1"

# Add to crontab if not already present
(crontab -l 2>/dev/null | grep -v ouroboros_rclone; echo "$CRONJOB") | crontab -
echo "[RCLONE] Cron job set: sync every 30 min -> $DRIVE_REMOTE"
echo "[RCLONE] Logs: $LOG_FILE"
