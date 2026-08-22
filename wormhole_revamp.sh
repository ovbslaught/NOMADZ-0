#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

WORMHOLE="$HOME/WORMHOLE"
echo "=== [1/5] Starting WORMHOLE Deep Normalization ==="

# 1. Excise and Prune Deprecated Directories
echo "[CLEANUP] Removing deprecated BRAIN-FOOD & BRAIN-HOLE artifacts..."
rm -rf "$WORMHOLE/BRAIN-HOLE" "$WORMHOLE/BRAIN-FOOD" "$WORMHOLE/ROOT" || true
rm -rf "$WORMHOLE/SPINE" 2>/dev/null || true

# 2. Standardize Hyphenated Folders
echo "[STANDARDIZE] Normalizing directory names..."
# Standardize VAULT
if [ -d "$WORMHOLE/-VAULT-" ]; then
    mkdir -p "$WORMHOLE/VAULT"
    cp -rn "$WORMHOLE/-VAULT-"/* "$WORMHOLE/VAULT/" 2>/dev/null || true
    rm -rf "$WORMHOLE/-VAULT-"
fi
if [ -d "$WORMHOLE/-VAULT" ]; then
    mkdir -p "$WORMHOLE/VAULT"
    cp -rn "$WORMHOLE/-VAULT"/* "$WORMHOLE/VAULT/" 2>/dev/null || true
    rm -rf "$WORMHOLE/-VAULT"
fi

# Standardize DOCS (absorbs -AI-PDF-)
mkdir -p "$WORMHOLE/DOCS" "$WORMHOLE/SKILLS"
if [ -d "$WORMHOLE/-AI-PDF-" ]; then
    cp -rn "$WORMHOLE/-AI-PDF-"/* "$WORMHOLE/DOCS/" 2>/dev/null || true
    rm -rf "$WORMHOLE/-AI-PDF-"
fi

# 3. Ensure Canonical Lobe Hierarchy
echo "[SCAFFOLD] Verifying clean substrate lobes..."
mkdir -p "$WORMHOLE/VAULT/KEYS"
mkdir -p "$WORMHOLE/COSMIC-BRAIN/DB" "$WORMHOLE/COSMIC-BRAIN/dropzone" "$WORMHOLE/COSMIC-BRAIN/scripts"
mkdir -p "$WORMHOLE/GEO-BRAIN/registry" "$WORMHOLE/GEO-BRAIN/pillars" "$WORMHOLE/GEO-BRAIN/TOOLS"
mkdir -p "$WORMHOLE/GEO-BRAIN/VAULT/datasets/bronze" "$WORMHOLE/GEO-BRAIN/VAULT/datasets/silver" "$WORMHOLE/GEO-BRAIN/VAULT/datasets/gold"
mkdir -p "$WORMHOLE/MOTHER-BRAIN/snapshots"
mkdir -p "$WORMHOLE/OMEGA-BRAIN/DB"
mkdir -p "$WORMHOLE/VULTURE-BRAIN/DB"
mkdir -p "$WORMHOLE/FATHER-LIFE"
mkdir -p "$WORMHOLE/NOMADZ-0"

# Maintain .gitkeep files for tracking
for dir in VAULT/KEYS COSMIC-BRAIN/DB COSMIC-BRAIN/dropzone GEO-BRAIN/pillars MOTHER-BRAIN/snapshots OMEGA-BRAIN/DB VULTURE-BRAIN/DB FATHER-LIFE DOCS SKILLS; do
    touch "$WORMHOLE/$dir/.gitkeep"
done

# 4. Update sync-all.py Path References
echo "[PATCH] Updating sync-all.py path bindings..."
sed -i 's|WORMHOLE/-VAULT-|WORMHOLE/VAULT|g' "$WORMHOLE/GEO-BRAIN/TOOLS/sync-all.py" 2>/dev/null || true
sed -i 's|WORMHOLE/-VAULT|WORMHOLE/VAULT|g' "$WORMHOLE/GEO-BRAIN/TOOLS/sync-all.py" 2>/dev/null || true

# 5. Git Stage & Master Sync
echo "=== [5/5] Staging Normalized Hierarchy to Git & Drive ==="
cd "$HOME"
git add -u  # Stages deletions of deprecated folders
git add WORMHOLE/
git commit -m "GEOLOGOS: Substrate normalization (excise BRAIN-FOOD/BRAIN-HOLE, standardize VAULT/DOCS)" || true

python "$WORMHOLE/GEO-BRAIN/TOOLS/sync-all.py" --target all

echo "============================================================"
echo "✅ WORMHOLE REVAMP COMPLETE: Substrate fully normalized."
echo "============================================================"
