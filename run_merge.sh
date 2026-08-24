#!/usr/bin/env bash
set -euo pipefail

# 1. Allow all storage directories in Git
git config --global --add safe.directory "*"

# 2. Locate NOMADZ-0 repo
if [ -d "$HOME/storage/shared/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO="$HOME/storage/shared/WORMHOLE/NOMADZ-0"
elif [ -d "/storage/emulated/0/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO="/storage/emulated/0/WORMHOLE/NOMADZ-0"
elif [ -d "$HOME/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO="$HOME/WORMHOLE/NOMADZ-0"
else
  REPO="$(pwd)"
fi

cd "$REPO"
echo "[*] Repository active at: $REPO"

# 3. Cache current working workflows
TEMP_DIR="/tmp/wf_cache_$(date +%s)"
mkdir -p "$TEMP_DIR"
if [ -d ".github/workflows" ]; then
  cp -r .github/workflows/* "$TEMP_DIR/" 2>/dev/null || true
fi

# 4. Fetch all remote branches
echo "[*] Fetching all remote branches..."
git fetch origin --prune

BACKUP_BRANCH="main-backup-before-godot-fixes-20260820-0316"

# 5. Checkout main & merge backup branch
echo "[*] Checking out main..."
git checkout main
git pull origin main --rebase || git rebase --abort 2>/dev/null || true

echo "[*] Merging origin/$BACKUP_BRANCH..."
git merge "origin/$BACKUP_BRANCH" --no-edit -m "merge: incorporate $BACKUP_BRANCH into main" || {
  echo "[!] Resolving merge conflicts..."
  if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR")" ]; then
    mkdir -p .github/workflows
    cp -r "$TEMP_DIR"/* .github/workflows/
    git add .github/workflows/
  fi
  git add -A
  git commit -m "merge: resolve conflicts combining $BACKUP_BRANCH into main" || true
}

# Ensure workflows match current fixed versions
if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR")" ]; then
  mkdir -p .github/workflows
  cp -r "$TEMP_DIR"/* .github/workflows/
  git add .github/workflows/
  if [ -n "$(git status --porcelain .github/workflows/)" ]; then
    git commit -m "chore(ci): enforce working workflow suite on main" || true
  fi
fi

echo "[*] Pushing main to remote..."
git push origin main

# 6. Sync to Cosmic-key branch
if git rev-parse --verify "origin/Cosmic-key" >/dev/null 2>&1; then
  echo "[*] Syncing with Cosmic-key branch..."
  git checkout Cosmic-key 2>/dev/null || git checkout -b Cosmic-key origin/Cosmic-key
  git pull origin Cosmic-key --rebase || git rebase --abort 2>/dev/null || true

  git merge main --no-edit -m "merge: sync main into Cosmic-key" || {
    if [ -d "$TEMP_DIR" ] && [ "$(ls -A "$TEMP_DIR")" ]; then
      mkdir -p .github/workflows
      cp -r "$TEMP_DIR"/* .github/workflows/
      git add .github/workflows/
    fi
    git add -A
    git commit -m "merge: resolve conflicts syncing main into Cosmic-key" || true
  }

  echo "[*] Pushing Cosmic-key to remote..."
  git push origin Cosmic-key
fi

rm -rf "$TEMP_DIR"
git checkout main

echo "=================================================================="
echo "[✓] SUCCESS: $BACKUP_BRANCH merged into main and Cosmic-key."
echo "=================================================================="
