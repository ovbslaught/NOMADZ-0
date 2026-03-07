
#!/usr/bin/env python3
# ouroboros_snapshot.py - Auto-snapshot NOMADZ-0 state to Drive/Obsidian
import os, shutil, json
from datetime import datetime

REPO = os.environ.get("NOMADZ_REPO", "/workspaces/NOMADZ-0")
SNAPSHOT_DIR = os.environ.get("SNAPSHOT_DIR", "/tmp/ouroboros_snapshots")
os.makedirs(SNAPSHOT_DIR, exist_ok=True)

def snapshot():
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    snap_path = os.path.join(SNAPSHOT_DIR, f"nomadz0_{ts}")
    shutil.copytree(REPO, snap_path, dirs_exist_ok=True,
        ignore=shutil.ignore_patterns(".git", "*.import", "*.png", "*.svg"))
    manifest = {
        "timestamp": ts,
        "source": REPO,
        "snapshot": snap_path,
        "files": sum(len(f) for _, _, f in os.walk(snap_path))
    }
    with open(os.path.join(snap_path, "SNAPSHOT_MANIFEST.json"), "w") as mf:
        json.dump(manifest, mf, indent=2)
    print(f"[OUROBOROS] Snapshot saved: {snap_path} ({manifest[chr(102)+chr(105)+chr(108)+chr(101)+chr(115)]} files)")
    return snap_path

if __name__ == "__main__":
    snapshot()
