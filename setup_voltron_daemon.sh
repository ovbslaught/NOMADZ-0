#!/usr/bin/env bash
set -euo pipefail

# Ensure Termux shared storage symlinks exist
if [[ ! -d "${HOME}/storage" ]]; then
    echo "[+] Requesting Termux storage permissions..."
    termux-setup-storage
fi

# Ensure base directory exists on internal storage
SDCARD_DIR="/sdcard/GEOLOGOS"
mkdir -p "${SDCARD_DIR}"
echo "[+] Initialized directory at: ${SDCARD_DIR}"

SCRIPTS_DIR="${HOME}/WORMHOLE/-SCRIPTS-"
CRON_DIR="${HOME}/.cron"
mkdir -p "${CRON_DIR}"

# Write dedicated 30-minute cron entry
CRON_JOB="*/30 * * * * ${SCRIPTS_DIR}/voltron_runner.sh >> ${HOME}/WORMHOLE/OMEGA-BRAIN/voltron_daemon.log 2>&1"

# Ensure cronie is installed
if ! command -v crond &> /dev/null; then
    echo "[+] Installing cronie..."
    pkg install -y cronie
fi

# Install and start crontab if not already present
( crontab -l 2>/dev/null | grep -Fv "voltron_runner.sh" ; echo "${CRON_JOB}" ) | crontab -

if ! pgrep -x "crond" > /dev/null; then
    echo "[+] Starting background crond service..."
    crond
else
    echo "[+] crond is active."
fi

echo "[*] Triggering test execution..."
"${SCRIPTS_DIR}/voltron_runner.sh"
