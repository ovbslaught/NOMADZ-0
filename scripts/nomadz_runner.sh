#!/usr/bin/env bash
set -euo pipefail

REPO="ovbslaught/NOMADZ-0"
INSTALL_DIR="${HOME}/.nomadz/NOMADZ-0"
WAL_PATH="${NOMADZ_WAL:-${HOME}/.nomadz/nomadz.wal}"
mkdir -p "${INSTALL_DIR}" "$(dirname "${WAL_PATH}")"

wal_log() {
  local level="$1"
  local msg="$2"
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "{\"ts\":\"${ts}\",\"app\":\"nomadz_runner\",\"level\":\"${level}\",\"msg\":\"${msg}\"}" >> "${WAL_PATH}"
  echo "[${ts}] [${level}] ${msg}"
}

wal_log "INFO" "Checking latest release from ${REPO}..."

# Query GitHub Releases API for the latest release asset
LATEST_JSON=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" || true)
if [ -z "${LATEST_JSON}" ] || echo "${LATEST_JSON}" | grep -q "Not Found"; then
  wal_log "WARN" "No tagged release found. Checking releases list for recent autobuild..."
  LATEST_JSON=$(curl -s "https://api.github.com/repos/${REPO}/releases" | jq -r '.[0]')
fi

DOWNLOAD_URL=$(echo "${LATEST_JSON}" | jq -r '.assets[] | select(.name | endswith("linux-x86_64.zip")) | .browser_download_url' | head -n 1)

if [ -z "${DOWNLOAD_URL}" ] || [ "${DOWNLOAD_URL}" = "null" ]; then
  wal_log "ERROR" "No Linux release asset found. Aborting."
  exit 1
fi

wal_log "INFO" "Downloading: ${DOWNLOAD_URL}"
curl -sL "${DOWNLOAD_URL}" -o "${INSTALL_DIR}/nomadz_linux.zip"

wal_log "INFO" "Unpacking binary to ${INSTALL_DIR}..."
unzip -q -o "${INSTALL_DIR}/nomadz_linux.zip" -d "${INSTALL_DIR}"
rm -f "${INSTALL_DIR}/nomadz_linux.zip"

BIN_PATH="${INSTALL_DIR}/nomadz_linux.x86_64"
chmod +x "${BIN_PATH}"

wal_log "OK" "Launch ready: ${BIN_PATH}"

# Launch binary (supports headless argument forwarding)
exec "${BIN_PATH}" "$@"
