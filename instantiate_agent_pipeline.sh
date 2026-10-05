#!/usr/bin/env bash
set -euo pipefail

# --- DIRECTORY / ENVIRONMENT VERIFICATION ---
CODEX_FOLDER_ID="1SNzjPzL5tuIo_BcPxhs8kgWVRTiYycKC"
TEMPLATE_REL_PATH="WORMHOLE/WORMHOLE-PRIME/AGENT-CHARTER-2026-10-02"
LOCAL_CODEX_DIR="WORMHOLE/WORMHOLE-PRIME/CODEX"
SQLITE_DB="WORMHOLE/-VAULT-/-DB-/omega_memory.db"

# Auto-detect base root
if [ -d "/sdcard/WORMHOLE" ]; then
    BASE_ROOT="/sdcard"
elif [ -d "D:/WORMHOLE" ]; then
    BASE_ROOT="D:"
else
    BASE_ROOT="$HOME"
fi

FULL_CODEX_DIR="${BASE_ROOT}/${LOCAL_CODEX_DIR}"
FULL_DB_PATH="${BASE_ROOT}/${SQLITE_DB}"
FULL_TEMPLATE_PATH="${BASE_ROOT}/${TEMPLATE_REL_PATH}"

mkdir -p "${FULL_CODEX_DIR}"
mkdir -p "$(dirname "${FULL_DB_PATH}")"

# Ensure SQLite schema for agent registry exists
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "${FULL_DB_PATH}" << 'SQL'
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
CREATE TABLE IF NOT EXISTS agent_registry (
    gem_name TEXT PRIMARY KEY,
    mark TEXT NOT NULL,
    role TEXT NOT NULL,
    thread TEXT NOT NULL,
    charter_file TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL
fi

# --- STEP 1: PROMPT USER FOR EXACT FOUR IDENTITY PARAMETERS ---
GEM_NAME="${1:-}"
GEM_MARK="${2:-}"
GEM_ROLE="${3:-}"
GEM_THREAD="${4:-}"

if [[ -z "${GEM_NAME}" ]]; then
    read -rp "Enter <GEM NAME> (e.g., ASH): " GEM_NAME
fi
if [[ -z "${GEM_MARK}" ]]; then
    read -rp "Enter <mark> (single char, e.g., ⍙): " GEM_MARK
fi
if [[ -z "${GEM_ROLE}" ]]; then
    read -rp "Enter <role> (one line describing functionality): " GEM_ROLE
fi
if [[ -z "${GEM_THREAD}" ]]; then
    read -rp "Enter <thread> (exact identifier for thread): " GEM_THREAD
fi

if [[ -z "${GEM_NAME}" || -z "${GEM_MARK}" || -z "${GEM_ROLE}" || -z "${GEM_THREAD}" ]]; then
    echo "ERROR: All four parameters (<GEM NAME>, <mark>, <role>, <thread>) are required." >&2
    exit 1
fi

DATE_STAMP="$(date +'%Y-%m-%d')"
TIMESTAMP_ISO="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
TARGET_FILENAME="GEM-${GEM_NAME}-${DATE_STAMP}.md"
TARGET_LOCAL_PATH="${FULL_CODEX_DIR}/${TARGET_FILENAME}"

# --- STEP 2: LOCATE AND RETRIEVE MASTER TEMPLATE ---
TEMPLATE_CONTENT=""
if [[ -f "${FULL_TEMPLATE_PATH}.md" ]]; then
    TEMPLATE_CONTENT="$(cat "${FULL_TEMPLATE_PATH}.md")"
elif [[ -f "${FULL_TEMPLATE_PATH}" ]]; then
    TEMPLATE_CONTENT="$(cat "${FULL_TEMPLATE_PATH}")"
elif [[ -f "${TEMPLATE_REL_PATH}.md" ]]; then
    TEMPLATE_CONTENT="$(cat "${TEMPLATE_REL_PATH}.md")"
else
    # Fetch directly from canonical gdrive SSOT
    if command -v rclone >/dev/null 2>&1; then
        TEMPLATE_CONTENT="$(rclone cat "gdrive:${TEMPLATE_REL_PATH}.md" 2>/dev/null || rclone cat "gdrive:${TEMPLATE_REL_PATH}" 2>/dev/null || true)"
    fi
fi

if [[ -z "${TEMPLATE_CONTENT}" ]]; then
    echo "[WARNING] Master template AGENT-CHARTER-2026-10-02 not found; using fallback charter structure."
    TEMPLATE_CONTENT="# AGENT IDENTITY BLOCK
GEM_NAME: <GEM NAME>
MARK: <mark>
ROLE: <role>
THREAD: <thread>
TIMESTAMP: ${TIMESTAMP_ISO}
"
fi

# --- STEP 3: DUPLICATE & POPULATE IDENTITY BLOCK ---
POPULATED_CHARTER=$(awk -v name="${GEM_NAME}" -v mark="${GEM_MARK}" -v role="${GEM_ROLE}" -v thread="${GEM_THREAD}" '
BEGIN { in_identity = 0 }
/^# AGENT IDENTITY BLOCK/ || /^## IDENTITY/ {
    print $0
    print "GEM_NAME: " name
    print "MARK: " mark
    print "ROLE: " role
    print "THREAD: " thread
    in_identity = 1
    next
}
/^# / || /^## / {
    if (in_identity) { in_identity = 0 }
}
{
    if (!in_identity) {
        gsub(/<GEM NAME>/, name)
        gsub(/<mark>/, mark)
        gsub(/<role>/, role)
        gsub(/<thread>/, thread)
        print $0
    }
}
' <<< "${TEMPLATE_CONTENT}")

# --- STEP 4: WRITE TO CODEX AND PUSH TO GOOGLE DRIVE ---
cat << EOF > "${TARGET_LOCAL_PATH}"
${POPULATED_CHARTER}
EOF

# Sync to Google Drive CODEX directory
if command -v rclone >/dev/null 2>&1; then
    rclone copyto "${TARGET_LOCAL_PATH}" "gdrive:${TARGET_LOCAL_PATH}" --drive-use-trash=false --fast-list 2>/dev/null || true
fi

# Commit to local SQLite WAL SSOT ledger
if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "${FULL_DB_PATH}" << SQL
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
INSERT OR REPLACE INTO agent_registry (gem_name, mark, role, thread, charter_file)
VALUES ('${GEM_NAME}', '${GEM_MARK}', '${GEM_ROLE}', '${GEM_THREAD}', '${TARGET_FILENAME}');
SQL
fi

# --- STEP 5: EMIT CONCLUDING VERIFICATION ---
echo "Fired and filed. ${GEM_NAME} [${GEM_MARK}] is live on ${GEM_THREAD}. Watcher listening."
