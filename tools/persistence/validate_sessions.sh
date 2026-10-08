#!/usr/bin/env bash
# validate_sessions.sh — structural verification of session JSON exports (ASH).
set -euo pipefail

DIR="${1:-${NOMADZ_REPO:-$HOME/NOMADZ-0}/session_logs}"
command -v jq >/dev/null || { echo "jq missing. pkg install jq"; exit 1; }

FAIL=0
shopt -s nullglob
for f in "$DIR"/*.json; do
    if ! jq -e '
        has("session_id") and has("timestamp_utc") and
        has("project") and has("status") and has("action")
    ' "$f" >/dev/null 2>&1; then
        echo "INVALID: $f"
        FAIL=1
        continue
    fi
    if jq -e '.session_id == null or .session_id == ""' "$f" >/dev/null 2>&1; then
        echo "INVALID (empty session_id): $f"
        FAIL=1
        continue
    fi
    echo "OK: $(basename "$f")"
done

[ "$FAIL" -eq 0 ] && echo "ASH VERIFICATION PASSED" || { echo "ASH VERIFICATION FAILED"; exit 1; }
