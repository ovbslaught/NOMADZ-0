#!/usr/bin/env bash
set -euo pipefail

echo "=== 1. WORMHOLE DIRECTORY INTEGRITY ==="
ls -lah ~/WORMHOLE/
echo ""
echo "=== 2. NOMADZ-0 GIT STATUS ==="
cd ~/WORMHOLE/NOMADZ-0 && git status -s
echo ""
echo "=== 3. SDCARD GEOLOGOS STATUS ==="
ls -lah /sdcard/GEOLOGOS || true
echo ""
echo "=== 4. CRON STATUS ==="
crontab -l
