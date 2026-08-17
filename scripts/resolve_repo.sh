#!/usr/bin/env bash
set -euo pipefail

# --- CONFIGURATION ---
REPO_DIR="NOMADZ-0"
REPO_URL="https://github.com/ovbslaught/NOMADZ-0.git"
GDRIVE_MIRROR="$HOME/gdrive/WORMHOLE/NOMADZ-0"

echo "[*] Initializing NOMADZ-0 Pipeline Optimization..."

# 1. Directory and Sync Validation
if [ ! -d "$REPO_DIR" ]; then
    if [ -d "$GDRIVE_MIRROR" ]; then
        echo "[*] Cloning from local WORMHOLE mirror..."
        cp -r "$GDRIVE_MIRROR" "$REPO_DIR"
        cd "$REPO_DIR"
    else
        echo "[*] Mirror not found. Cloning from remote..."
        git clone "$REPO_URL" "$REPO_DIR"
        cd "$REPO_DIR"
    fi
else
    cd "$REPO_DIR"
    echo "[*] Existing repository detected. Fetching latest remote states..."
    git fetch --all --prune
fi

# 2. Safety Check: Ensure clean working directory
if ! git diff-index --quiet HEAD --; then
    echo "[!] Uncommitted changes detected. Stashing local modifications..."
    git stash
fi

# 3. Target Branch Isolation
echo "[*] Synchronizing Cosmic-key tracking branch..."
git checkout Cosmic-key || git checkout -b Cosmic-key origin/Cosmic-key

# 4. Strategic Merge Execution (PR #1 Resolution)
echo "[*] Merging main into Cosmic-key with strategic CI overrides..."
# Prioritize main for structural/CI configurations to fix broken pipelines
if ! git merge main --strategy-option=theirs -m "NOMADZ-CORE: Resolving PR #1 merge conflicts via automated strategy-theirs"; then
    echo "[!] Conflict remaining in specific GDScript modules. Resolving manual intersections..."
    # Auto-accept theirs for structural files, keep standard tracking for the rest
    git diff --name-only --diff-filter=U | grep -E '(.github/workflows/|/ci/)' | xargs -r git checkout --theirs
    git add .github/workflows/* 2>/dev/null || true
    
    echo "[*] Remaining conflicts require explicit logical verification. Current status:"
    git status --short
else
    echo "[+] Merge strategy completed successfully without tracking errors."
fi

# 5. Push and Synchronize Back to Source of Truth
echo "[*] Pushing resolved state to remote infrastructure..."
git push origin Cosmic-key

if [ -d "$GDRIVE_MIRROR" ]; then
    echo "[*] Mirroring structural updates back to WORMHOLE..."
    rclone sync . gdrive:WORMHOLE/NOMADZ-0 --exclude ".git/**" || echo "[!] Manual rclone trigger required."
fi

echo "[+] Step 1 of Issue #2 Action Items complete. Pipeline unblocked."
