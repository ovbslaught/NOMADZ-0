#!/bin/bash
cd "$(dirname "$0")"

if ! python3 -c "import fastapi" &> /dev/null; then
    echo "[*] Installing Python requirements..."
    pip install fastapi uvicorn
fi

echo "[*] Booting MB_Service.py on port 7421..."
nohup python3 MB_Service.py > mb_daemon.log 2>&1 &
echo "[+] MOTHER-BRAIN is live. Log output to mb_daemon.log"
