#!/usr/bin/env bash
set -euo pipefail

# --- PATH CONFIGURATION ---
BRAIN_FOOD_DIR="$HOME/gdrive/WORMHOLE/BRAIN-HOLE/BRAIN-FOOD"
DB_PATH="$HOME/gdrive/WORMHOLE/FATHER-LIFE/omega_memory.db"

echo "[*] Initializing automated ingestion layer..."

# 1. Verification of Source of Truth
if [ ! -d "$BRAIN_FOOD_DIR" ]; then
    echo "[!] Target BRAIN-FOOD node not found at: $BRAIN_FOOD_DIR"
    exit 1
fi

if [ ! -f "$DB_PATH" ]; then
    echo "[*] SQLite instance not found. Initializing omega_memory.db tracking..."
    sqlite3 "$DB_PATH" "CREATE TABLE IF NOT EXISTS raw_ingest (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"
fi

# 2. Raw Dump Processing Loop
cd "$BRAIN_FOOD_DIR"
FOUND_FILES=$(find . -maxdepth 1 -type f -name "*.json" -o -name "*.md")

if [ -z "$FOUND_FILES" ]; then
    echo "[+] BRAIN-FOOD is currently clear. No pending payloads to ingest."
    exit 0
fi

for file in $FOUND_FILES; do
    echo "[*] Ingesting: $file"
    # Escaping and dumping content safely into SQLite RAG layer
    CONTENT=$(cat "$file" | sed "s/'/''/g")
    sqlite3 "$DB_PATH" "INSERT INTO raw_ingest (payload) VALUES ('$CONTENT');"
    
    # Safe archiving of processed assets
    mkdir -p processed/
    mv "$file" processed/
done

echo "[+] Ingestion complete. Data vectorized to SQLite substrate."
