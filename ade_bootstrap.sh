#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ADE_ROOT="${HOME}/ade"
DB_PATH="${ADE_ROOT}/ade_core.db"
WORMHOLE="/sdcard/WORMHOLE"
LOG_FILE="${ADE_ROOT}/logs/bootstrap.log"
mkdir -p "${ADE_ROOT}/logs" "${ADE_ROOT}/state" "${ADE_ROOT}/tmp"
mkdir -p "${WORMHOLE}/ade" 2>/dev/null || true
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ADE-CORE bootstrap started"
trap 'echo "[ERROR] line ${LINENO}"; exit 1' ERR
pkg install -y python git sqlite curl 2>/dev/null || true
cp -f "${HOME}/NOMADZ-0/ade_engine.py" "${ADE_ROOT}/ade_engine.py" 2>/dev/null || \
  cp -f "${HOME}/ade_engine.py" "${ADE_ROOT}/ade_engine.py" 2>/dev/null || true
chmod +x "${ADE_ROOT}/ade_engine.py"
python3 "${ADE_ROOT}/ade_engine.py" init
python3 "${ADE_ROOT}/ade_engine.py" synth --skill omega_probe
python3 "${ADE_ROOT}/ade_engine.py" run   --skill omega_probe
python3 "${ADE_ROOT}/ade_engine.py" audit
python3 "${ADE_ROOT}/ade_engine.py" status
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ADE bootstrap complete."
