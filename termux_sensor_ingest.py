#!/usr/bin/env python3
"""termux_sensor_ingest.py — Captures physical environmental telemetry and snapshots."""

import subprocess
import json
import time
from datetime import datetime, timezone
from pathlib import Path

WORMHOLE_BASE = Path("/sdcard/WORMHOLE")
TELEMETRY_DIR = WORMHOLE_BASE / "TELEMETRY"
TELEMETRY_DIR.mkdir(parents=True, exist_ok=True)

def read_sensors():
    try:
        res = subprocess.run(
            ["termux-sensor", "-s", "accelerometer,light,pressure", "-n", "1"],
            capture_output=True, text=True, timeout=6
        )
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception as e:
        return {"error": str(e)}
    return {}

def read_location():
    try:
        res = subprocess.run(
            ["termux-location", "-p", "network", "-r", "last"],
            capture_output=True, text=True, timeout=6
        )
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception as e:
        return {"error": str(e)}
    return {}

def capture_snapshot():
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    photo_path = TELEMETRY_DIR / f"cam_{timestamp}.jpg"
    try:
        res = subprocess.run(
            ["termux-camera-photo", "-c", "0", str(photo_path)],
            capture_output=True, text=True, timeout=10
        )
        if res.returncode == 0 and photo_path.exists():
            return str(photo_path)
    except Exception as e:
        return f"error: {e}"
    return ""

def main():
    ts = datetime.now(timezone.utc).isoformat()
    telemetry = {
        "timestamp_utc": ts,
        "sensors": read_sensors(),
        "location": read_location(),
        "snapshot_path": capture_snapshot()
    }
    packet_path = TELEMETRY_DIR / f"telemetry_{int(time.time())}.json"
    packet_path.write_text(json.dumps(telemetry, indent=2))
    print(f"[+] Physical telemetry written -> {packet_path}")

if __name__ == "__main__":
    main()
