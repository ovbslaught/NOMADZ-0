#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# start_mb.sh — Mother-Brain Service Launcher (Termux)
# =============================================================================
# Starts MB_Service.py on port 7421.
# Also ensures search_api.py (port 7420) is running.
# Run from NOMADZ-0/00_Core/MB/ or set MB_DIR below.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MB_DIR="${MB_DIR:-/storage/shared/Wormhole/NOMADZ-0/00_Core/MB}"
MB_SERVICE="${MB_DIR}/MB_Service.py"
SEARCH_API="${MB_DIR}/search_api.py"
LOG_DIR="${MB_DIR}/logs"
MB_LOG="${LOG_DIR}/mb_service.log"
SEARCH_LOG="${LOG_DIR}/search_api.log"
PID_DIR="${MB_DIR}/run"
MB_PID="${PID_DIR}/mb_service.pid"
SEARCH_PID="${PID_DIR}/search_api.pid"

MB_PORT=7421
SEARCH_PORT=7420

# Export for MB_Service.py config
export MB_BASE_DIR="${MB_DIR}"
export MB_DIGEST_DIR="/tmp/cron_tracking"
export MB_LLM_URL="http://localhost:3002/completion"
export MB_SEARCH_URL="http://localhost:${SEARCH_PORT}"
export MB_MAX_TOKENS="512"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERR]${NC}   $*"; }
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }

is_port_open() {
    local port="$1"
    # Try curl first (available in Termux), then nc
    if command -v curl &>/dev/null; then
        curl -s --max-time 2 "http://localhost:${port}" >/dev/null 2>&1
        return $?
    elif command -v nc &>/dev/null; then
        nc -z localhost "${port}" 2>/dev/null
        return $?
    fi
    return 1
}

is_pid_running() {
    local pid="$1"
    [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
}

stop_service() {
    local name="$1" pid_file="$2"
    if [[ -f "${pid_file}" ]]; then
        local pid
        pid=$(<"${pid_file}")
        if is_pid_running "${pid}"; then
            info "Stopping ${name} (PID ${pid})…"
            kill "${pid}" 2>/dev/null && rm -f "${pid_file}"
        else
            warn "${name} PID file exists but process is not running — cleaning up"
            rm -f "${pid_file}"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   NOMADZ-0 Mother-Brain Launcher v2.0    ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# Verify Python
if ! command -v python3 &>/dev/null; then
    err "python3 not found. Install via: pkg install python"
    exit 1
fi
ok "Python3: $(python3 --version)"

# Verify MB_Service.py exists
if [[ ! -f "${MB_SERVICE}" ]]; then
    err "MB_Service.py not found at: ${MB_SERVICE}"
    err "Set MB_DIR env var or copy MB_Service.py to the correct location."
    exit 1
fi
ok "MB_Service.py found at ${MB_SERVICE}"

# Check FastAPI / uvicorn available
if ! python3 -c "import fastapi, uvicorn, aiosqlite, httpx" 2>/dev/null; then
    warn "Required Python packages missing. Installing…"
    pip install --quiet fastapi "uvicorn[standard]" aiosqlite httpx websockets python-multipart
fi

# Create runtime directories
mkdir -p "${LOG_DIR}" "${PID_DIR}"

# ---------------------------------------------------------------------------
# Handle restart flag
# ---------------------------------------------------------------------------

if [[ "${1:-}" == "--restart" ]]; then
    info "Restart requested — stopping existing services…"
    stop_service "search_api" "${SEARCH_PID}"
    stop_service "MB_Service"  "${MB_PID}"
    sleep 1
fi

# ---------------------------------------------------------------------------
# Start search_api.py (port 7420) if not already running
# ---------------------------------------------------------------------------

echo ""
info "Checking search_api (port ${SEARCH_PORT})…"

if is_port_open "${SEARCH_PORT}"; then
    ok "search_api already listening on port ${SEARCH_PORT}"
else
    if [[ ! -f "${SEARCH_API}" ]]; then
        warn "search_api.py not found at ${SEARCH_API} — skipping"
    else
        info "Starting search_api.py on port ${SEARCH_PORT}…"
        nohup python3 "${SEARCH_API}" \
            --port "${SEARCH_PORT}" \
            >> "${SEARCH_LOG}" 2>&1 &
        SEARCH_API_PID=$!
        echo "${SEARCH_API_PID}" > "${SEARCH_PID}"

        # Wait up to 8s for it to come up
        for i in $(seq 1 8); do
            sleep 1
            if is_port_open "${SEARCH_PORT}"; then
                ok "search_api started (PID ${SEARCH_API_PID})"
                break
            fi
            if [[ $i -eq 8 ]]; then
                warn "search_api did not come up in time — MB_Service will start without it"
            fi
        done
    fi
fi

# ---------------------------------------------------------------------------
# Start MB_Service.py (port 7421)
# ---------------------------------------------------------------------------

echo ""
info "Checking MB_Service (port ${MB_PORT})…"

if is_port_open "${MB_PORT}" && [[ "${1:-}" != "--restart" ]]; then
    ok "MB_Service already listening on port ${MB_PORT}"
    echo ""
    info "Use './start_mb.sh --restart' to force a restart"
else
    # Stop any stale instance
    stop_service "MB_Service" "${MB_PID}"

    info "Starting MB_Service.py on port ${MB_PORT}…"
    nohup python3 -m uvicorn MB_Service:app \
        --app-dir "${MB_DIR}" \
        --host 0.0.0.0 \
        --port "${MB_PORT}" \
        --log-level info \
        --no-access-log \
        >> "${MB_LOG}" 2>&1 &
    MB_PID_VAL=$!
    echo "${MB_PID_VAL}" > "${MB_PID}"

    # Wait up to 10s for MB_Service to respond
    STARTED=false
    for i in $(seq 1 10); do
        sleep 1
        if is_port_open "${MB_PORT}"; then
            STARTED=true
            ok "MB_Service started (PID ${MB_PID_VAL})"
            break
        fi
    done

    if [[ "${STARTED}" == "false" ]]; then
        err "MB_Service did not start within 10 seconds"
        err "Check logs: tail -f ${MB_LOG}"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Status summary
# ---------------------------------------------------------------------------

echo ""
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}              STATUS SUMMARY              ${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}"
echo ""

# Pulse check
PULSE_RESP=$(curl -s --max-time 5 "http://localhost:${MB_PORT}/pulse" 2>/dev/null || echo "{}")
if echo "${PULSE_RESP}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    data = d.get('data', {})
    print(f\"  Uptime    : {data.get('uptime_s', '?')}s\")
    om = data.get('omega_memory', {})
    print(f\"  Snapshots : {om.get('snapshot_count', '?')}\")
    print(f\"  Chunks    : {om.get('chunk_count', '?')}\")
    print(f\"  LLM       : {data.get('llm_status', '?')}\")
    print(f\"  GH push   : {data.get('github_last_push', '?')}\")
except: print('  (pulse data unavailable)')
" 2>/dev/null; then
    ok "Pulse OK"
else
    warn "Pulse endpoint not yet responding"
fi

echo ""
printf "  %-20s %s\n" "MB_Service log:"    "${MB_LOG}"
printf "  %-20s %s\n" "search_api log:"    "${SEARCH_LOG}"
printf "  %-20s %s\n" "WAL:"               "${MB_DIR}/Data/ouroboros_chain.jsonl"
printf "  %-20s %s\n" "omega_memory.db:"   "${MB_DIR}/omega_memory.db"
echo ""
ok "Mother-Brain online → http://localhost:${MB_PORT}/pulse"
ok "API docs          → http://localhost:${MB_PORT}/docs"
echo ""
