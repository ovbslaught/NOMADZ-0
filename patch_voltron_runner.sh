#!/usr/bin/env bash
set -euo pipefail

SCRIPTS_DIR="${HOME}/WORMHOLE/-SCRIPTS-"
TERMUX_TMP="${PREFIX}/tmp"
mkdir -p "${TERMUX_TMP}" "${SCRIPTS_DIR}"

cat << 'RUNNER' > "${SCRIPTS_DIR}/voltron_runner.sh"
#!/usr/bin/env bash
set -euo pipefail

LOCKFILE="${PREFIX}/tmp/voltron_pulse.lock"
exec 200>"$LOCKFILE"
flock -n 200 || { echo "[-] Execution locked. Exiting."; exit 1; }

SCRIPTS_DIR="${HOME}/WORMHOLE/-SCRIPTS-"
SDCARD_SRC="/sdcard/GEOLOGOS"

echo "[+] Running CRDT Pulse..."
python3 "${SCRIPTS_DIR}/voltrongossip.py"

if [[ -d "${SDCARD_SRC}" ]]; then
    echo "[+] Running rclone sync to gdrive..."
    rclone sync "${SDCARD_SRC}" "gdrive:WORMHOLE/GEO-BRAIN/GEOLOGOS" \
        --transfers=4 \
        --checkers=8 \
        --fast-list \
        --log-level INFO || echo "[-] Rclone gdrive warning."

    echo "[+] Updating local git/obsidian vault tracking..."
    VAULT_TRACK="${HOME}/WORMHOLE/-VAULT-/OBSIDIAN_SYNC"
    mkdir -p "${VAULT_TRACK}"
    rsync -av --update "${SDCARD_SRC}/" "${VAULT_TRACK}/" || echo "[-] Rsync warning."
else
    echo "[!] Source ${SDCARD_SRC} not found or permission missing. Skipping rclone sync."
fi

echo "[+] Voltron cascade iteration finished."
RUNNER
chmod +x "${SCRIPTS_DIR}/voltron_runner.sh"

echo "[*] Executing patched voltron_runner.sh..."
"${SCRIPTS_DIR}/voltron_runner.sh"
