#!/usr/bin/env bash
set -euo pipefail

INBOX_DIR="00_Inbox/TO_PROCESS"
ARCHIVE_DIR="00_Inbox/PROCESSED"

if [ ! -d "$INBOX_DIR" ]; then
    echo "Directory $INBOX_DIR does not exist. Nothing to route."
    exit 0
fi

echo "[+] Routing TO_PROCESS files to target substrate folders..."

# 1. Route Godot Orchestrator / Addons
if [ -d "$INBOX_DIR/NOMADZ-0/addons/godot-orchestrator" ]; then
    mkdir -p WORMHOLE/NOMADZ-0/addons
    cp -ru "$INBOX_DIR/NOMADZ-0/addons/godot-orchestrator" WORMHOLE/NOMADZ-0/addons/
    echo "  -> Synced godot-orchestrator to WORMHOLE/NOMADZ-0/addons/"
fi

# 2. Route Protocol Documents
find "$INBOX_DIR" -maxdepth 2 -type f \( -iname "*protocol*" -o -iname "*wake-up*" \) | while read -r file; do
    mkdir -p WORMHOLE/MOTHER-BRAIN/protocols
    cp -u "$file" WORMHOLE/MOTHER-BRAIN/protocols/
    echo "  -> Moved $file to WORMHOLE/MOTHER-BRAIN/protocols/"
done

# 3. Route Backup Archives & Snapshots
find "$INBOX_DIR" -maxdepth 2 -type f \( -iname "*backup*.zip" -o -iname "*master*.zip" -o -iname "*snapshot*.zip" \) | while read -r file; do
    mkdir -p WORMHOLE/-VAULT-
    cp -u "$file" WORMHOLE/-VAULT-/
    echo "  -> Vaulted $file to WORMHOLE/-VAULT-/"
done

# 4. Route Geo/MPL/Earth Models
find "$INBOX_DIR" -maxdepth 2 -type f \( -iname "*geologos*" -o -iname "*mpl*" -o -iname "*earth*" \) | while read -r file; do
    mkdir -p WORMHOLE/GEO-BRAIN
    cp -u "$file" WORMHOLE/GEO-BRAIN/
    echo "  -> Routed $file to WORMHOLE/GEO-BRAIN/"
done

# 5. Clean up temporary / cache entries
find "$INBOX_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$INBOX_DIR" -type d -name ".git" -exec rm -rf {} + 2>/dev/null || true

echo "[+] Inbox routing pass complete."
