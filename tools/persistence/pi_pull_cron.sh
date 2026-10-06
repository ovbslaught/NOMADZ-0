#!/usr/bin/env bash
# pi_pull_cron.sh — Pi 4 mirror job. Pulls git + rclone from Drive, read-only replica.
# crontab: 0 3 * * * /home/pi/bin/pi_pull_cron.sh >> /home/pi/logs/pull.log 2>&1
set -euo pipefail

MIRROR="${PI_MIRROR:-$HOME/NOMADZ-mirror}"
DRIVE_REMOTE="gdrive:WORMHOLE"

mkdir -p "$MIRROR"

if [ -d "$MIRROR/.git" ]; then
    git -C "$MIRROR" fetch --all
    git -C "$MIRROR" reset --hard origin/Cosmic-key
    echo "GIT SYNC OK: $(git -C "$MIRROR" rev-parse --short HEAD)"
else
    git clone -b Cosmic-key git@github-nomadz:ovbslaught/NOMADZ-0.git "$MIRROR"
fi

rclone sync "$DRIVE_REMOTE" "$MIRROR/drive-assets" \
    --checksum \
    --transfers 4 \
    --log-level INFO

git -C "$MIRROR" fsck --strict && echo "FSCK OK"
echo "PI MIRROR SYNC COMPLETE $(date -u +%Y-%m-%dT%H:%M:%SZ)"
