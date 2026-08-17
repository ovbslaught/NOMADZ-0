#!/bin/bash
# git_autopush.sh - Auto-commit and push all changes to Cosmic-key
# Called by daemon_runner.py every 6 hours
set -e
cd /workspaces/NOMADZ-0
git add -A
CHANGED=$(git diff --cached --name-only | wc -l)
if [ "$CHANGED" -gt 0 ]; then
    TS=$(date '+%Y-%m-%d %H:%M:%S')
    git commit -m "chore: auto-sync [$TS] - $CHANGED files updated"
    git push origin Cosmic-key
    echo "[GITPUSH] Pushed $CHANGED files at $TS"
else
    echo "[GITPUSH] No changes to push"
fi
