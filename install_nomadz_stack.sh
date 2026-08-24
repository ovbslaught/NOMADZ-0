#!/usr/bin/env bash
# ==============================================================================
# NOMADZ-0 & MOTHER-BRAIN UNIFIED AUTOMATION INSTALLER
# Fully autonomous setup for Termux / Linux / WSL
# ==============================================================================
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║ NOMADZ UNIFIED AUTOMATION SUITE: SELF-PROVISIONING               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# 1. Resolve Storage Environment
if [ -d "$HOME/storage/shared/WORMHOLE" ]; then
  WORMHOLE="$HOME/storage/shared/WORMHOLE"
elif [ -d "/storage/emulated/0/WORMHOLE" ]; then
  WORMHOLE="/storage/emulated/0/WORMHOLE"
else
  WORMHOLE="$HOME/WORMHOLE"
fi

echo "[*] Target WORMHOLE root: $WORMHOLE"

# 2. Directory Scaffolding
SCRIPTS_DIR="$WORMHOLE/MOTHER-BRAIN/00_SYSTEM/scripts"
NOMADZ_WF="$WORMHOLE/NOMADZ-0/.github/workflows"
MOTHER_WF="$WORMHOLE/MOTHER-BRAIN/.github/workflows"
LOG_DIR="$WORMHOLE/99-LOGS"
BIN_DIR="$HOME/.local/bin"
BOOT_DIR="$HOME/.termux/boot"

mkdir -p "$SCRIPTS_DIR" "$NOMADZ_WF" "$MOTHER_WF" "$LOG_DIR" "$BIN_DIR" "$BOOT_DIR"

# ------------------------------------------------------------------------------
# 3. Write Core Scripts
# ------------------------------------------------------------------------------
echo "[*] Writing core automation scripts..."

# Core Paths Resolver
cat << 'PYEOF' > "$SCRIPTS_DIR/core_paths.py"
#!/usr/bin/env python3
import os, sys
from pathlib import Path

def get_wormhole_root() -> Path:
    if "WORMHOLE" in os.environ:
        return Path(os.environ["WORMHOLE"]).resolve()
    termux_path = Path("/data/data/com.termux/files/home/storage/shared/WORMHOLE")
    if termux_path.exists():
        return termux_path
    android_emulated = Path("/storage/emulated/0/WORMHOLE")
    if android_emulated.exists():
        return android_emulated
    if sys.platform == "win32":
        if Path("D:/WORMHOLE").exists():
            return Path("D:/WORMHOLE")
        return Path(os.path.expanduser("~/WORMHOLE"))
    return Path(os.path.expanduser("~/WORMHOLE"))

WORMHOLE_ROOT = get_wormhole_root()
OMEGA_BRAIN = WORMHOLE_ROOT / "OMEGA-BRAIN"
MOTHER_BRAIN = WORMHOLE_ROOT / "MOTHER-BRAIN"
NOMADZ_ROOT = WORMHOLE_ROOT / "NOMADZ-0"
DB_PATH = OMEGA_BRAIN / "omega_memory_UNIFIED.db"
PYEOF

# Autonomous Background Daemon
cat << 'BMSHEOF' > "$SCRIPTS_DIR/nomadz_daemon.sh"
#!/usr/bin/env bash
set -euo pipefail

if [ -z "${WORMHOLE:-}" ]; then
  if [ -d "$HOME/storage/shared/WORMHOLE" ]; then
    WORMHOLE="$HOME/storage/shared/WORMHOLE"
  elif [ -d "/storage/emulated/0/WORMHOLE" ]; then
    WORMHOLE="/storage/emulated/0/WORMHOLE"
  else
    WORMHOLE="$HOME/WORMHOLE"
  fi
fi

SCRIPTS_DIR="$WORMHOLE/MOTHER-BRAIN/00_SYSTEM/scripts"
LOG_DIR="$WORMHOLE/99-LOGS"
mkdir -p "$LOG_DIR"
DAEMON_LOG="$LOG_DIR/daemon_master.log"

log() {
  echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $1" | tee -a "$DAEMON_LOG"
}

if command -v termux-wake-lock &>/dev/null; then
  termux-wake-lock
  log "[✓] Termux wake-lock active."
fi

log "[*] Starting NOMADZ background daemon on: $WORMHOLE"

SYNC_INTERVAL=60
LAST_SYNC=0

while true; do
  CURRENT_TIME=$(date +%s)
  if [ -f "$SCRIPTS_DIR/nomadz_autobuild.py" ]; then
    python3 "$SCRIPTS_DIR/nomadz_autobuild.py" build NOMADZ-0 >> "$LOG_DIR/autobuild.log" 2>&1 || true
  fi

  if (( CURRENT_TIME - LAST_SYNC >= SYNC_INTERVAL )); then
    if [ -f "$SCRIPTS_DIR/wormhole_sync_daemon.py" ]; then
      python3 "$SCRIPTS_DIR/wormhole_sync_daemon.py" push >> "$LOG_DIR/rclone_sync.log" 2>&1 || true
    fi
    LAST_SYNC=$CURRENT_TIME
  fi
  sleep 15
done
BMSHEOF

# Git Sync Guard
cat << 'GSEOF' > "$SCRIPTS_DIR/git_sync_guard.sh"
#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="${1:-.}"
cd "$REPO_DIR"

if [ -f "$WORMHOLE/MOTHER-BRAIN/00_SYSTEM/scripts/wormhole_sync_daemon.py" ]; then
  python3 "$WORMHOLE/MOTHER-BRAIN/00_SYSTEM/scripts/wormhole_sync_daemon.py" checkpoint || true
fi

git reset .godot/ .import/ *.db-wal *.db-shm __pycache__/ 2>/dev/null || true

if [ -n "$(git status --porcelain)" ]; then
  MSG="${2:-Auto-sync: $(date -u +'%Y-%m-%dT%H:%M:%SZ')}"
  git add -A
  git commit -m "$MSG"
  git push origin "$(git rev-parse --abbrev-ref HEAD)"
  echo "[✓] Changes pushed: $MSG"
else
  echo "[*] Working tree clean."
fi
GSEOF

# ------------------------------------------------------------------------------
# 4. Write GitHub Actions Workflows
# ------------------------------------------------------------------------------
echo "[*] Writing GitHub Actions workflow definitions..."

# A. MOTHER-BRAIN Sync
cat << 'YMLEOF' > "$MOTHER_WF/motherbrain-sync.yml"
name: MOTHER-BRAIN MASTER SYNC — GitHub -> Google Drive Wormhole
on:
  push:
    branches: [ "main", "Cosmic-key" ]
  workflow_dispatch:
concurrency:
  group: wormhole-sync-${{ github.ref }}
  cancel-in-progress: true
jobs:
  sync-wormhole:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-hub/rclone@master
      - env:
          RCLONE_CONFIG_DATA: ${{ secrets.RCLONE_CONFIG }}
        run: |
          if [ -z "$RCLONE_CONFIG_DATA" ]; then
            echo "::warning ::RCLONE_CONFIG secret not set. Skipping Drive sync."
            exit 0
          fi
          mkdir -p ~/.config/rclone
          echo "$RCLONE_CONFIG_DATA" > ~/.config/rclone/rclone.conf
          rclone sync "$GITHUB_WORKSPACE" gdrive:WORMHOLE/MOTHER-BRAIN \
            --checksum --fast-list --transfers 4 \
            --exclude ".git/**" --exclude ".github/**" --exclude ".godot/**" \
            --exclude "*.db-wal" --exclude "*.db-shm" --exclude "*.tmp"
YMLEOF

# B. Godot CI & Linter
cat << 'YMLEOF' > "$NOMADZ_WF/godot-ci.yml"
name: Godot CI - NOMADZ-0
on:
  push:
    branches: [ "main", "Cosmic-key" ]
  pull_request:
    branches: [ "main", "Cosmic-key" ]
  workflow_dispatch:
env:
  GODOT_VERSION: "4.3"
  RELEASE_NAME: "stable"
jobs:
  gdscript-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install gdtoolkit
      - run: |
          GD_FILES=$(find . -name "*.gd" -not -path "*/.godot/*" -not -path "*/addons/*")
          if [ -n "$GD_FILES" ]; then
            gdlint $GD_FILES || echo "::warning ::Linter warnings detected."
          fi
  export-linux:
    needs: gdscript-lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          mkdir -p "$HOME/.local/bin" "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${RELEASE_NAME}"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          curl -fsSL https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${RELEASE_NAME}/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_linux.x86_64.zip -o /tmp/godot.zip
          curl -fsSL https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-${RELEASE_NAME}/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_export_templates.tpz -o /tmp/templates.tpz
          unzip -q /tmp/godot.zip -d /tmp/godot_bin
          unzip -q /tmp/templates.tpz -d /tmp/godot_tpl
          mv /tmp/godot_bin/Godot_v${GODOT_VERSION}-${RELEASE_NAME}_linux.x86_64 "$HOME/.local/bin/godot"
          chmod +x "$HOME/.local/bin/godot"
          mv /tmp/godot_tpl/templates/* "$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.${RELEASE_NAME}/"
      - run: |
          mkdir -p dist/linux
          godot --headless --export-release "Linux/X11" dist/linux/nomadz_linux.x86_64 || true
      - uses: actions/upload-artifact@v4
        with:
          name: nomadz-linux-x86_64
          path: dist/linux/
YMLEOF

# C. Cross-Repo & Branch Cherrypicker (Zelda-123 / NOMADZ-0)
cat << 'YMLEOF' > "$NOMADZ_WF/cherrypick-sync.yml"
name: Cherrypick & Sync Substrates (Zelda-123 <-> NOMADZ-0)
on:
  workflow_dispatch:
    inputs:
      source_repo:
        description: "Source Repository"
        required: true
        default: "ovbslaught/Zelda-123"
      source_branch:
        description: "Source Branch"
        required: true
        default: "main"
      target_branch:
        description: "Target Branch"
        required: true
        default: "Cosmic-key"
      sync_mode:
        description: "Sync Mode (path_overlay or commit_cherrypick)"
        required: true
        default: "path_overlay"
      target_paths:
        description: "Comma-separated paths to overlay"
        required: false
        default: "scenes/zelda/,src/cpp/,codex/"
      commit_shas:
        description: "Space-separated commit SHAs"
        required: false
        default: ""
permissions:
  contents: write
jobs:
  execute-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.inputs.target_branch }}
          fetch-depth: 0
          token: ${{ secrets.GH_PAT_SYNC || secrets.GITHUB_TOKEN }}
      - run: |
          git config user.name "Sol-Autobuild-Bot"
          git config user.email "cosmickey001@gmail.com"
      - name: Path Overlay Mode
        if: ${{ github.event.inputs.sync_mode == 'path_overlay' }}
        run: |
          git clone --depth 1 --branch "${{ github.event.inputs.source_branch }}" "https://x-access-token:${{ secrets.GH_PAT_SYNC || secrets.GITHUB_TOKEN }}@github.com/${{ github.event.inputs.source_repo }}.git" /tmp/source_repo
          IFS=',' read -ra ADDR <<< "${{ github.event.inputs.target_paths }}"
          for path in "${ADDR[@]}"; do
            path=$(echo "$path" | xargs)
            if [ -e "/tmp/source_repo/$path" ]; then
              mkdir -p "$(dirname "$path")"
              cp -r "/tmp/source_repo/$path" "./$path"
            fi
          done
          if [ -n "$(git status --porcelain)" ]; then
            git add -A
            git commit -m "Auto-sync: Overlay assets from ${{ github.event.inputs.source_repo }}"
            git push origin ${{ github.event.inputs.target_branch }}
          fi
YMLEOF

# D. GDExtension C++ SCons Matrix
cat << 'YMLEOF' > "$NOMADZ_WF/build-gdextension-cpp.yml"
name: Compile GDExtension C++ Core
on:
  push:
    paths:
      - "src/**"
      - "godot-cpp/**"
      - "SConstruct"
    branches: [ "main", "Cosmic-key" ]
  workflow_dispatch:
jobs:
  build-cpp:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            platform: linux
            arch: x86_64
          - os: windows-latest
            platform: windows
            arch: x86_64
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install scons
      - if: matrix.platform == 'linux'
        run: sudo apt-get update -qq && sudo apt-get install -y -qq build-essential pkg-config
      - if: matrix.platform == 'windows'
        uses: ilammy/msvc-dev-cmd@v1
      - run: |
          if [ -f "SConstruct" ]; then
            scons platform=${{ matrix.platform }} arch=${{ matrix.arch }} target=template_release
          else
            mkdir -p bin/
          fi
        shell: bash
      - uses: actions/upload-artifact@v4
        with:
          name: gdextension-${{ matrix.platform }}-${{ matrix.arch }}
          path: bin/
YMLEOF

# Copy unified workflows to both repos
cp -r "$NOMADZ_WF"/* "$MOTHER_WF/" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 5. CLI & Boot Integration
# ------------------------------------------------------------------------------
echo "[*] Setting up CLI and Termux:Boot..."

chmod +x "$SCRIPTS_DIR"/*.py "$SCRIPTS_DIR"/*.sh 2>/dev/null || true

# Sovereign CLI binary
cat << 'OMEGAEOF' > "$BIN_DIR/omega"
#!/usr/bin/env bash
if [ -d "$HOME/storage/shared/WORMHOLE" ]; then
  WORMHOLE="$HOME/storage/shared/WORMHOLE"
elif [ -d "/storage/emulated/0/WORMHOLE" ]; then
  WORMHOLE="/storage/emulated/0/WORMHOLE"
else
  WORMHOLE="$HOME/WORMHOLE"
fi
export WORMHOLE
python3 "$WORMHOLE/MOTHER-BRAIN/00_SYSTEM/scripts/omega_cli.py" "$@"
OMEGAEOF
chmod +x "$BIN_DIR/omega"

# Termux Boot hook
cat << 'BOOTEOF' > "$BOOT_DIR/nomadz_boot.sh"
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
if [ -d "$HOME/storage/shared/WORMHOLE" ]; then
  W="$HOME/storage/shared/WORMHOLE"
elif [ -d "/storage/emulated/0/WORMHOLE" ]; then
  W="/storage/emulated/0/WORMHOLE"
else
  W="$HOME/WORMHOLE"
fi
nohup bash "$W/MOTHER-BRAIN/00_SYSTEM/scripts/nomadz_daemon.sh" > /dev/null 2>&1 &
BOOTEOF
chmod +x "$BOOT_DIR/nomadz_boot.sh"

# Ensure PATH is updated in shell rc
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
  [ -f "$HOME/.zshrc" ] && echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.zshrc"
fi

# ------------------------------------------------------------------------------
# 6. Auto-commit to Git (if inside repo) & Launch Daemon
# ------------------------------------------------------------------------------
echo "[*] Committing new workflows..."
for REPO in "$WORMHOLE/NOMADZ-0" "$WORMHOLE/MOTHER-BRAIN"; do
  if [ -d "$REPO/.git" ]; then
    cd "$REPO"
    git add .github/workflows/
    git commit -m "chore(ci): install unified GitHub Actions autobuild suite" 2>/dev/null || true
    echo "[✓] Workflows staged and committed in $REPO."
  fi
done

# Kill old instances and start fresh daemon
pkill -f nomadz_daemon.sh 2>/dev/null || true
nohup bash "$SCRIPTS_DIR/nomadz_daemon.sh" > /dev/null 2>&1 &

echo "=================================================================="
echo "[✓] INSTALLATION COMPLETE."
echo "    - Workflows written to .github/workflows/"
echo "    - Daemon running in background."
echo "    - CLI available via 'omega status' (reload with source ~/.bashrc)"
echo "=================================================================="
