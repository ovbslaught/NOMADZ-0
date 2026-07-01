#!/usr/bin/env bash
set -e

###############################################################################
# NOMADZ-0 Monorepo Consolidation Script
# Merges all dependencies (MOTHER-BRAIN, Cosmic-key, NOMADZ-0-WIKI, 
# remotely-save, ocean) into unified NOMADZ-0 structure
###############################################################################

echo "=========================================="
echo "NOMADZ-0 UNIFIED MONOREPO CONSOLIDATION"
echo "=========================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NOMADZ_REPO="https://github.com/ovbslaught/NOMADZ-0.git"
MOTHER_BRAIN_REPO="https://github.com/ovbslaught/MOTHER-BRAIN.git"
COSMIC_KEY_REPO="https://github.com/ovbslaught/Cosmic-key.git"
NOMADZ_WIKI_REPO="https://github.com/ovbslaught/NOMADZ-0-WIKI.git"
REMOTELY_SAVE_REPO="https://github.com/ovbslaught/remotely-save.git"
OCEAN_REPO="https://github.com/ovbslaught/ocean.git"

WORK_DIR=$(pwd)
BRANCH_NAME="consolidate/all-repos-$(date +%s)"

# Function to log messages
log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Ensure we're on main branch
log_info "Step 1: Checking out main branch..."
git checkout main
git pull origin main

# Step 2: Create consolidation branch
log_info "Step 2: Creating consolidation branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME"

# Step 3: Add all repos as remotes
log_info "Step 3: Adding remote repositories..."
git remote remove mother-brain 2>/dev/null || true
git remote remove cosmic-key 2>/dev/null || true
git remote remove nomadz-wiki 2>/dev/null || true
git remote remove remotely-save 2>/dev/null || true
git remote remove ocean 2>/dev/null || true

git remote add mother-brain "$MOTHER_BRAIN_REPO"
git remote add cosmic-key "$COSMIC_KEY_REPO"
git remote add nomadz-wiki "$NOMADZ_WIKI_REPO"
git remote add remotely-save "$REMOTELY_SAVE_REPO"
git remote add ocean "$OCEAN_REPO"

# Step 4: Fetch all remotes
log_info "Step 4: Fetching all remote repositories..."
git fetch mother-brain --depth=1
git fetch cosmic-key --depth=1
git fetch nomadz-wiki --depth=1
git fetch remotely-save --depth=1
git fetch ocean --depth=1

# Step 5: Merge MOTHER-BRAIN as subdirectory
log_info "Step 5: Merging MOTHER-BRAIN/Cosmic-key into MOTHER-BRAIN/ subdirectory..."
git merge -X subtree=MOTHER-BRAIN mother-brain/Cosmic-key \
  --allow-unrelated-histories \
  -m "chore(monorepo): merge MOTHER-BRAIN/Cosmic-key as MOTHER-BRAIN/ subdirectory" \
  || log_warn "MOTHER-BRAIN merge had conflicts; please resolve and continue"

# Step 6: Merge Cosmic-key
log_info "Step 6: Merging Cosmic-key/main into Cosmic-key/ subdirectory..."
git merge -X subtree=Cosmic-key cosmic-key/main \
  --allow-unrelated-histories \
  -m "chore(monorepo): merge Cosmic-key as Cosmic-key/ subdirectory" \
  || log_warn "Cosmic-key merge had conflicts; please resolve and continue"

# Step 7: Merge NOMADZ-0-WIKI
log_info "Step 7: Merging NOMADZ-0-WIKI/main into NOMADZ-0-WIKI/ subdirectory..."
git merge -X subtree=NOMADZ-0-WIKI nomadz-wiki/main \
  --allow-unrelated-histories \
  -m "chore(monorepo): merge NOMADZ-0-WIKI as NOMADZ-0-WIKI/ subdirectory" \
  || log_warn "NOMADZ-0-WIKI merge had conflicts; please resolve and continue"

# Step 8: Merge remotely-save
log_info "Step 8: Merging remotely-save/master into remotely-save/ subdirectory..."
git merge -X subtree=remotely-save remotely-save/master \
  --allow-unrelated-histories \
  -m "chore(monorepo): merge remotely-save as remotely-save/ subdirectory" \
  || log_warn "remotely-save merge had conflicts; please resolve and continue"

# Step 9: Merge ocean (if separate)
log_info "Step 9: Merging ocean/main into OCEAN/ subdirectory..."
git merge -X subtree=OCEAN ocean/main \
  --allow-unrelated-histories \
  -m "chore(monorepo): merge ocean as OCEAN/ subdirectory" \
  || log_warn "ocean merge had conflicts; please resolve and continue"

# Step 10: Create unified root README
log_info "Step 10: Creating unified root README..."
cat > README.md <<'EOF'
# NOMADZ-0: Unified Monorepo

Consolidated game engine + infrastructure repository containing:
- **OCEAN/** - Main Godot 4 game (2D/3D hybrid)
- **MOTHER-BRAIN/** - Knowledge base, sync pipeline, automation
- **Cosmic-key/** - Models, lore, dashboards
- **NOMADZ-0-WIKI/** - Documentation & signalverse lore
- **remotely-save/** - Cross-platform sync tools
- **scripts/** - Root-level utilities & orchestration

## Quick Start

### Run the Game
```bash
godot --path OCEAN
```

### MOTHER-BRAIN Setup
```bash
cd MOTHER-BRAIN
python setup.py
```

### Available Sub-Projects
- `OCEAN/` - Main gameplay (Godot 4)
- `Cosmic-key/` - World/character/model data (C# + media)
- `MOTHER-BRAIN/` - Knowledge hub + sync (Python)

## Monorepo Structure
```
NOMADZ-0/
├── OCEAN/              # Main game
├── MOTHER-BRAIN/       # Knowledge + sync
├── Cosmic-key/         # Models + lore
├── NOMADZ-0-WIKI/      # Documentation
├── remotely-save/      # Sync tools
├── scripts/            # Root orchestration
└── README.md           # This file
```

## Workflows

**Sync all sub-repos:**
```bash
bash scripts/consolidate-monorepo.sh
```

**Run unified feeder:**
```bash
.github/workflows/monorepo-sync.yml (automated)
```

---
Created: 2026-07-01 | License: MIT
EOF

git add README.md

# Step 11: Create root .gitignore
log_info "Step 11: Creating unified .gitignore..."
cat > .gitignore <<'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
dist/
build/

# Node
node_modules/
npm-debug.log

# Godot
.godot/
*.import
*.scn~
.DS_Store

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
Thumbs.db
.DS_Store

# Build artifacts
*.o
*.a
*.so
*.dylib

# Temporary
*.tmp
*.log
wormhole-sync/
.env
.env.local

# Large files (use git-lfs)
*.zip
*.tar.gz
*.7z
EOF

git add .gitignore

# Step 12: Summary and next steps
log_info "Step 12: Consolidation Complete!"
echo ""
echo -e "${GREEN}========== CONSOLIDATION STATUS ==========${NC}"
echo "Branch:  $BRANCH_NAME"
echo "Status:  Ready for PR"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review merge conflicts (if any):"
echo "   $ git status"
echo ""
echo "2. If conflicts exist, resolve them:"
echo "   $ git add <resolved-files>"
echo "   $ git commit --no-edit"
echo ""
echo "3. Push to GitHub:"
echo "   $ git push -u origin $BRANCH_NAME"
echo ""
echo "4. Create Pull Request on GitHub:"
echo "   - Base: main"
echo "   - Compare: $BRANCH_NAME"
echo ""
echo "5. After PR merge, all repos are consolidated into NOMADZ-0 main!"
echo ""
echo -e "${GREEN}========================================${NC}"
