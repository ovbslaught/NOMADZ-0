#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "[1/5] Ensuring dependencies are present..."
pkg install -y -q python rclone cronie git wget

if [ ! -d "$HOME/storage" ]; then
    termux-setup-storage || true
fi

echo "[2/5] Allocating WORMHOLE directory tree..."
WORMHOLE_ROOT="$HOME/WORMHOLE"
mkdir -p \
    "$WORMHOLE_ROOT/-VAULT-" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/FATHER-LIFE" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/PULSE-LOGS" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/WEIGHTS" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/MODELS" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/PERSONAS" \
    "$WORMHOLE_ROOT/FATHER-BRAIN/PROMPTS" \
    "$WORMHOLE_ROOT/VULTURE-BRAIN" \
    "$WORMHOLE_ROOT/NOMADZ-0" \
    "$WORMHOLE_ROOT/MOTHER-BRAIN" \
    "$WORMHOLE_ROOT/OMEGA-BRAIN" \
    "$WORMHOLE_ROOT/COSMIC-BRAIN" \
    "$WORMHOLE_ROOT/GEO-BRAIN"

echo "[3/5] Deploying mb_daemon.py and cloud_intake.sh..."
cat << 'PYEOF' > "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS/mb_daemon.py"
#!/usr/bin/env python3
import os, sys, shutil, time
from pathlib import Path

WORMHOLE_ROOT = Path(os.path.expanduser("~/WORMHOLE"))

ROUTING_MAP = {
    "FATHER-BRAIN": WORMHOLE_ROOT / "FATHER-BRAIN" / "FATHER-LIFE",
    "PULSE-LOGS": WORMHOLE_ROOT / "FATHER-BRAIN" / "PULSE-LOGS",
    "WEIGHTS": WORMHOLE_ROOT / "FATHER-BRAIN" / "WEIGHTS",
    "MODELS": WORMHOLE_ROOT / "FATHER-BRAIN" / "MODELS",
    "PERSONAS": WORMHOLE_ROOT / "FATHER-BRAIN" / "PERSONAS",
    "PROMPTS": WORMHOLE_ROOT / "FATHER-BRAIN" / "PROMPTS",
    "COSMIC-BRAIN": WORMHOLE_ROOT / "COSMIC-BRAIN",
    "GEO-BRAIN": WORMHOLE_ROOT / "GEO-BRAIN",
    "VULTURE-BRAIN": WORMHOLE_ROOT / "VULTURE-BRAIN",
    "MOTHER-BRAIN": WORMHOLE_ROOT / "MOTHER-BRAIN",
    "OMEGA-BRAIN": WORMHOLE_ROOT / "OMEGA-BRAIN",
    "NOMADZ-0": WORMHOLE_ROOT / "NOMADZ-0",
}

def analyze_and_route_file(file_path: Path):
    if not file_path.is_file() or file_path.name.startswith('.'):
        return

    content_sample = ""
    try:
        if file_path.suffix in ['.txt', '.md', '.json', '.py', '.gd']:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                content_sample = f.read(4096)
    except Exception as e:
        print(f"[ERROR] Read failure: {e}")

    target_node = "MOTHER-BRAIN"
    content_lower = content_sample.lower()
    name_lower = file_path.name.lower()

    if "gdscript" in content_lower or "extends" in content_lower or name_lower.endswith('.gd') or "godot" in content_lower:
        target_node = "NOMADZ-0"
    elif "pulse_log" in name_lower or "heartbeat" in name_lower or "session_log" in content_lower:
        target_node = "PULSE-LOGS"
    elif "persona" in name_lower or "system_prompt" in name_lower:
        target_node = "PERSONAS"
    elif name_lower.endswith('.weights') or name_lower.endswith('.pkl') or "ppo" in content_lower:
        target_node = "WEIGHTS"
    elif "uap" in content_lower or "geologos" in content_lower or "virginia" in content_lower:
        target_node = "GEO-BRAIN"
    elif "lore" in content_lower or "fictional" in content_lower or "blog" in content_lower:
        target_node = "COSMIC-BRAIN"
    elif "swarm" in content_lower or "agent_loop" in content_lower:
        target_node = "VULTURE-BRAIN"
    elif name_lower.endswith('.db') or name_lower.endswith('.sqlite') or "wal" in content_lower:
        target_node = "OMEGA-BRAIN"

    dest_dir = ROUTING_MAP[target_node]
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_path = dest_dir / file_path.name

    if dest_path.exists():
        dest_path = dest_dir / f"{file_path.stem}_{int(time.time())}{file_path.suffix}"

    try:
        shutil.move(str(file_path), str(dest_path))
        print(f"[SUCCESS] Routed {file_path.name} -> {dest_path}")
    except Exception as e:
        print(f"[ERROR] Relocation error: {e}")

def continuous_sweep():
    print(f"[LAUNCH] Ingestion Engine online. Watching root: {WORMHOLE_ROOT}/")
    for path in ROUTING_MAP.values():
        path.mkdir(parents=True, exist_ok=True)

    while True:
        try:
            for item in WORMHOLE_ROOT.iterdir():
                if item.is_file():
                    analyze_and_route_file(item)
        except Exception as e:
            print(f"[LOOP EXCEPTION] {e}")
        time.sleep(5)

if __name__ == "__main__":
    if not WORMHOLE_ROOT.exists():
        sys.exit(1)
    continuous_sweep()
PYEOF
chmod +x "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS/mb_daemon.py"

cat << 'SHEOF' > "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS/cloud_intake.sh"
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

RCLONE_REMOTE="gdrive"
LOCAL_WORMHOLE="$HOME/WORMHOLE"

if [ ! -d "$LOCAL_WORMHOLE" ]; then
    exit 1
fi

rclone move "${RCLONE_REMOTE}:" "$LOCAL_WORMHOLE/" \
    --max-depth 1 \
    --exclude "/WORMHOLE/**" \
    --no-traverse \
    -q
SHEOF
chmod +x "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS/cloud_intake.sh"

echo "[4/5] Registering crontab and starting cron service..."
(crontab -l 2>/dev/null | grep -v "cloud_intake.sh" | grep -v "mb_daemon.py" || true
 echo "*/2 * * * * bash $HOME/WORMHOLE/FATHER-BRAIN/SCRIPTS/cloud_intake.sh > /dev/null 2>&1"
 echo "*/5 * * * * pgrep -f mb_daemon.py > /dev/null || python3 $HOME/WORMHOLE/FATHER-BRAIN/SCRIPTS/mb_daemon.py &"
) | crontab -

crond || true

echo "[5/5] Launching background processes..."
pkill -f "mb_daemon.py" || true
python3 "$WORMHOLE_ROOT/FATHER-BRAIN/SCRIPTS/mb_daemon.py" > /dev/null 2>&1 &

echo "=========================================="
echo "NOMADZ SUBSTRATE RECOVERY COMPLETE"
echo "=========================================="
