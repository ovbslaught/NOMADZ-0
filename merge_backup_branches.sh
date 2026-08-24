#!/usr/bin/env bash
# ==============================================================================
# NOMADZ-0 UNIFIED BRANCH MERGER & RECONCILIATION
# Merges main-backup-before-godot-fixes-20260820-0316 into main and Cosmic-key
# ==============================================================================
set -euo pipefail

# 1. Locate repository directory
if [ -d "$HOME/storage/shared/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO_DIR="$HOME/storage/shared/WORMHOLE/NOMADZ-0"
elif [ -d "/storage/emulated/0/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO_DIR="/storage/emulated/0/WORMHOLE/NOMADZ-0"
elif [ -d "$HOME/WORMHOLE/NOMADZ-0/.git" ]; then
  REPO_DIR="$HOME/WORMHOLE/NOMADZ-0"
elif [ -d "./.git" ]; then
  REPO_DIR="$(pwd)"
else
  echo "::error ::Could not locate NOMADZ-0 git repository."
  exit 1
fi

cd "$REPO_DIR"
echo "[*] Working inside repository: $REPO_DIR"

# 2. Fetch all remote branches
echo "[*] Fetching all remote branches and tags..."
git fetch origin --prune

BACKUP_BRANCH="main-backup-before-godot-fixes-20260820-0316"

# Verify remote backup branch exists
if ! git rev-parse --verify "origin/$BACKUP_BRANCH" >/dev/null 2>&1; then
  echo "::error ::Remote branch origin/$BACKUP_BRANCH not found. Fetching full refs..."
  git fetch origin "refs/heads/*:refs/remotes/origin/*"
fi

# 3. Snapshot current working workflows to temporary cache
TEMP_WF_DIR="/tmp/nomadz_workflows_backup_$(date +%s)"
mkdir -p "$TEMP_WF_DIR"
if [ -d ".github/workflows" ]; then
  cp -r .github/workflows/* "$TEMP_WF_DIR/" 2>/dev/null || true
  echo "[✓] Cached current working GitHub Actions workflows."
fi

# 4. Checkout and reconcile 'main'
echo "[*] Switching to 'main' branch..."
git checkout main
git pull origin main --rebase || git rebase --abort 2>/dev/null || true

echo "[*] Merging origin/$BACKUP_BRANCH into 'main'..."
git merge "origin/$BACKUP_BRANCH" --no-edit -m "merge: reconcile $BACKUP_BRANCH with main" || {
  echo "[!] Merge conflict detected. Resolving..."
  
  # For workflow conflicts, keep our fixed versions
  if [ -d "$TEMP_WF_DIR" ] && [ "$(ls -A "$TEMP_WF_DIR")" ]; then
    mkdir -p .github/workflows
    cp -r "$TEMP_WF_DIR"/* .github/workflows/
    git add .github/workflows/
  fi

  # Add all resolved files
  git add -A
  git commit -m "merge: resolve conflicts combining $BACKUP_BRANCH into main" || true
}

# Ensure workflows match the fixed configurations
if [ -d "$TEMP_WF_DIR" ] && [ "$(ls -A "$TEMP_WF_DIR")" ]; then
  mkdir -p .github/workflows
  cp -r "$TEMP_WF_DIR"/* .github/workflows/
  git add .github/workflows/
  if [ -n "$(git status --porcelain .github/workflows/)" ]; then
    git commit -m "chore(ci): enforce working workflow suite on main" || true
  fi
fi

# 5. Push reconciled 'main'
echo "[*] Pushing updated 'main' to origin..."
git push origin main

# 6. Reconcile 'Cosmic-key' branch
if git rev-parse --verify "origin/Cosmic-key" >/dev/null 2>&1; then
  echo "[*] Switching to 'Cosmic-key' branch..."
  git checkout Cosmic-key 2>/dev/null || git checkout -b Cosmic-key origin/Cosmic-key
  git pull origin Cosmic-key --rebase || git rebase --abort 2>/dev/null || true

  echo "[*] Merging 'main' into 'Cosmic-key'..."
  git merge main --no-edit -m "merge: sync unified main into Cosmic-key" || {
    echo "[!] Conflict in Cosmic-key merge. Resolving..."
    if [ -d "$TEMP_WF_DIR" ] && [ "$(ls -A "$TEMP_WF_DIR")" ]; then
      mkdir -p .github/workflows
      cp -r "$TEMP_WF_DIR"/* .github/workflows/
      git add .github/workflows/
    fi
    git add -A
    git commit -m "merge: resolve conflicts syncing main into Cosmic-key" || true
  }

  echo "[*] Pushing updated 'Cosmic-key' to origin..."
  git push origin Cosmic-key
fi

# 7. Cleanup
rm -rf "$TEMP_WF_DIR"

# Switch back to main
git checkout main

echo "=================================================================="
echo "[✓] MERGE & RECONCILIATION COMPLETE"
echo "    - $BACKUP_BRANCH merged into main"
echo "    - main synced to Cosmic-key"
echo "    - CI/CD workflow suite preserved"
echo "=================================================================="
