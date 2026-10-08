#!/usr/bin/env bash
# nomadz_commit.sh — session-end commit ritual. Usage: nomadz_commit.sh "session summary"
set -euo pipefail

REPO="${NOMADZ_REPO:-$HOME/NOMADZ-0}"
MSG="${1:-"session $(date -u +%Y-%m-%dT%H:%M:%SZ)"}"

cd "$REPO"

# 1. Verify repo integrity before writing more history
git fsck --strict || { echo "FATAL: repo corruption detected. Abort."; exit 1; }

# 2. Stage everything
git add -A

# 3. Validate session JSON exports before committing (ASH)
~/bin/validate_sessions.sh || { echo "FATAL: failed JSON validation. Commit blocked."; exit 1; }

# 4. Commit
if [ -n "$(git diff --cached --name-only)" ]; then
    git commit -m "$MSG"
    echo "COMMIT OK: $MSG"
else
    echo "Nothing to commit. Repo clean."
fi

# 5. Push. If auth is broken this is loud, not silent.
if git push origin Cosmic-key 2>/dev/null; then
    echo "PUSH OK -> origin/Cosmic-key"
else
    echo "WARNING: push failed. Commits are local-only. Run: git push origin Cosmic-key"
    exit 2
fi
